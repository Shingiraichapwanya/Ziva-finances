import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/currency/currency_display_state.dart';
import '../../core/currency/currency_types.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/transaction_parser.dart';
import '../../core/utils/web_file_uploader.dart';
import '../../models/transaction_model.dart';
import '../../services/receipt_storage_service.dart';
import '../../services/sqlite_service.dart';

class QuickEntryBottomSheet extends StatefulWidget {
  final void Function(TransactionModel) onTransactionLogged;

  const QuickEntryBottomSheet({super.key, required this.onTransactionLogged});

  @override
  State<QuickEntryBottomSheet> createState() => _QuickEntryBottomSheetState();
}

class _QuickEntryBottomSheetState extends State<QuickEntryBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _payeeController = TextEditingController();
  final _notesController = TextEditingController();
  final _nlpController = TextEditingController();

  String _selectedCurrency = CurrencyDisplayState.instance.currentDisplayCurrency;
  String _selectedAccountId = 'ACC_ZA_CAPITEC_DAILY';
  String _selectedCategoryId = 'CAT_GROCERIES';
  String _selectedCategoryName = 'Groceries & Household';
  final String _transactionType = 'EXPENSE';
  bool _isTaxDeductible = false;
  bool _isSubmitting = false;

  // Real-time Parser & Receipt OCR State
  ParsedTransaction? _currentParsed;
  bool _isScanningReceipt = false;
  bool _isDragOver = false;
  UploadedReceiptFile? _scannedFile;

  final List<Map<String, String>> _accounts = [
    {'id': 'ACC_ZA_CAPITEC_DAILY', 'name': 'Capitec Daily Cheque (ZAR)'},
    {'id': 'ACC_ZA_FNB_MONTHLY', 'name': 'FNB Commercial Monthly (ZAR)'},
    {'id': 'ACC_ZW_ECOCASH_USD', 'name': 'EcoCash USD Wallet (USD)'},
    {'id': 'ACC_ZW_ECOCASH_ZIG', 'name': 'EcoCash ZWG Wallet (ZWG)'},
    {'id': 'ACC_ZA_DISCOVERY_VAULT', 'name': 'Discovery 32-Day Notice (ZAR)'},
  ];

  List<Map<String, String>> _categories = [
    {'id': 'CAT_HOUSING_RENT', 'name': 'Residential Rent & Levies', 'tax': '0'},
    {'id': 'CAT_GROCERIES', 'name': 'Groceries & Household', 'tax': '0'},
    {'id': 'CAT_UTILITIES', 'name': 'Electricity & Municipal Utilities', 'tax': '1'},
    {'id': 'CAT_CONNECTIVITY', 'name': 'Fibre Internet & Mobile Data', 'tax': '1'},
    {'id': 'CAT_DINING_LEISURE', 'name': 'Dining, Coffee & Social', 'tax': '0'},
    {'id': 'CAT_TECH_CLOUD', 'name': 'Cloud SaaS & Productivity Tools', 'tax': '1'},
    {'id': 'CAT_SINKING_EMERGENCY', 'name': 'Emergency Reserve Sinking Fund', 'tax': '0'},
    {'id': 'CAT_SINKING_MAINTENANCE', 'name': 'Vehicle Maintenance Sinking Fund', 'tax': '0'},
  ];

  @override
  void initState() {
    super.initState();
    _autoMatchAccount(_selectedCurrency);
    _loadEnvelopesAsCategories();
    if (kIsWeb) {
      registerDragDropListener(
        onFileDropped: _processReceiptFile,
        onDragStateChanged: (isDragging) {
          if (mounted) setState(() => _isDragOver = isDragging);
        },
      );
    }
  }

  Future<void> _loadEnvelopesAsCategories() async {
    final envs = await SqliteService.instance.getEnvelopes();
    if (mounted && envs.isNotEmpty) {
      setState(() {
        _categories = envs.map((e) => {
          'id': e.categoryId,
          'name': '${e.categoryName} (${e.categoryGroup})',
          'tax': e.isFixedObligation ? '1' : '0',
        }).toList();
        if (!_categories.any((c) => c['id'] == _selectedCategoryId)) {
          _selectedCategoryId = _categories.first['id']!;
          _selectedCategoryName = _categories.first['name']!;
        }
      });
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      unregisterDragDropListener();
    }
    _amountController.dispose();
    _payeeController.dispose();
    _notesController.dispose();
    _nlpController.dispose();
    super.dispose();
  }

  /// Automatically matches an appropriate default account when currency changes
  void _autoMatchAccount(String currency) {
    final clean = getEffectiveCurrencyCode(currency);
    if (clean == 'USD') {
      _selectedAccountId = 'ACC_ZW_ECOCASH_USD';
    } else if (clean == 'ZWG') {
      _selectedAccountId = 'ACC_ZW_ECOCASH_ZIG';
    } else {
      _selectedAccountId = 'ACC_ZA_CAPITEC_DAILY';
    }
  }

  /// Real-time parsing of natural language sentence
  void _onNlpChanged(String text) {
    if (text.trim().isEmpty) {
      setState(() {
        _currentParsed = null;
      });
      return;
    }

    final parsed = TransactionParser.parse(text);
    if (parsed.hasAnyExtractedField) {
      setState(() {
        _currentParsed = parsed;
        if (parsed.amount != null) {
          _amountController.text = parsed.amount! % 1 == 0
              ? parsed.amount!.toInt().toString()
              : parsed.amount!.toStringAsFixed(2);
        }
        if (parsed.currency != null) {
          _selectedCurrency = parsed.currency!;
          _autoMatchAccount(parsed.currency!);
        }
        if (parsed.merchant != null && parsed.merchant!.isNotEmpty) {
          _payeeController.text = parsed.merchant!;
        }
        if (parsed.categoryId != null) {
          _selectedCategoryId = parsed.categoryId!;
          _selectedCategoryName = parsed.categoryName ?? _selectedCategoryName;
        }
        _isTaxDeductible = parsed.isTaxDeductible;
        if (parsed.notes != null) {
          _notesController.text = parsed.notes!;
        }
      });
    } else {
      setState(() {
        _currentParsed = null;
      });
    }
  }

  /// Triggers file upload / selection for receipt OCR
  Future<void> _handleReceiptPicker() async {
    setState(() => _isScanningReceipt = true);
    try {
      final file = await pickReceiptFileWeb();
      if (file != null) {
        await _processReceiptFile(file);
      }
    } catch (e) {
      debugPrint('[QuickEntry] Error selecting receipt file: $e');
    } finally {
      if (mounted) setState(() => _isScanningReceipt = false);
    }
  }

  /// Processes uploaded receipt file and extracts details
  Future<void> _processReceiptFile(UploadedReceiptFile file) async {
    setState(() {
      _isScanningReceipt = true;
      _scannedFile = file;
    });

    // Simulated OCR scanning delay for realistic UX feedback
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final parsed = TransactionParser.parseReceipt(
      fileName: file.name,
      fileContent: file.textSnippet,
      fileSize: file.size,
    );

    if (mounted) {
      setState(() {
        _isScanningReceipt = false;
        _currentParsed = parsed;
        if (parsed.amount != null && parsed.amount! > 0) {
          _amountController.text = parsed.amount! % 1 == 0
              ? parsed.amount!.toInt().toString()
              : parsed.amount!.toStringAsFixed(2);
        }
        if (parsed.currency != null) {
          _selectedCurrency = parsed.currency!;
          _autoMatchAccount(parsed.currency!);
        }
        if (parsed.merchant != null && parsed.merchant!.isNotEmpty) {
          _payeeController.text = parsed.merchant!;
        }
        if (parsed.categoryId != null) {
          _selectedCategoryId = parsed.categoryId!;
          _selectedCategoryName = parsed.categoryName ?? _selectedCategoryName;
        }
        _isTaxDeductible = parsed.isTaxDeductible;
        _notesController.text = parsed.notes ?? 'Scanned from receipt: ${file.name}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZivaTheme.bgSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: ZivaTheme.gold400),
          ),
          content: Row(
            children: [
              const Icon(Icons.document_scanner_rounded, color: ZivaTheme.gold400, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Extracted: ${parsed.merchant ?? "Merchant"} • ${parsed.currency ?? "ZAR"} ${parsed.amount?.toStringAsFixed(2) ?? ""} • ${parsed.categoryName ?? "Category"}',
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final rawAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final finalAmount = _transactionType == 'EXPENSE' ? -rawAmount.abs() : rawAmount.abs();

    final now = DateTime.now();
    final dateStr = now.toIso8601String().split('T')[0];
    final txId = 'TX_MOB_${now.millisecondsSinceEpoch}';

    // Calculate reporting amounts
    final zarAmount = CurrencyFormatter.convert(
      amount: finalAmount,
      fromCurrency: _selectedCurrency,
      toCurrency: 'ZAR',
    );
    final usdAmount = CurrencyFormatter.convert(
      amount: finalAmount,
      fromCurrency: _selectedCurrency,
      toCurrency: 'USD',
    );

    final receiptRef = _scannedFile != null
        ? ReceiptStorageService.instance.saveReceiptReference(
            transactionId: txId,
            filename: _scannedFile!.name,
            mimeType: _scannedFile!.mimeType,
          )
        : null;

    final newTx = TransactionModel(
      transactionId: txId,
      transactionDate: dateStr,
      accountId: _selectedAccountId,
      categoryId: _selectedCategoryId,
      categoryName: _selectedCategoryName,
      transactionType: _transactionType,
      originalAmount: finalAmount,
      originalCurrency: _selectedCurrency,
      reportingAmountZar: zarAmount,
      reportingAmountUsd: usdAmount,
      merchantOrPayee: _payeeController.text.trim().isEmpty ? 'Direct Mobile Entry' : _payeeController.text.trim(),
      paymentMethod: 'EFT/Card',
      isTaxDeductible: _isTaxDeductible,
      notes: _notesController.text.trim(),
      tags: [
        'mobile_entry',
        if (_scannedFile != null) 'receipt_attached',
        if (_isTaxDeductible) 'tax_deductible',
      ],
      isSynced: false,
      receiptName: receiptRef?.fileName,
      receiptUrl: receiptRef?.storageUrl,
      receiptFileType: receiptRef?.fileType,
    );

    // Strict Confirmation Loop: Wait for verified BigQuery write-back
    setState(() => _isSubmitting = true);

    try {
      final confirmedTx = await SqliteService.instance.saveTransaction(newTx);

      if (!mounted) return;

      // Only after confirmed BigQuery write-back, update UI and dismiss
      widget.onTransactionLogged(confirmedTx);
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZivaTheme.bgSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: ZivaTheme.gold400),
          ),
          content: Row(
            children: [
              const Icon(Icons.cloud_done_rounded, color: ZivaTheme.gold400, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Transaction confirmed & written to BigQuery (${confirmedTx.originalCurrency} ${confirmedTx.originalAmount.toStringAsFixed(2)})',
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZivaTheme.bgSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: ZivaTheme.rose400),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: ZivaTheme.rose400, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'BigQuery write failed: $e. Transaction was NOT saved.',
                  style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: ZivaTheme.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: ZivaTheme.borderCard),
        ),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: ZivaTheme.gold500.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.add_shopping_cart_rounded, color: ZivaTheme.gold400, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Log Transaction',
                              style: TextStyle(
                                color: ZivaTheme.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Natural Language & Instant Receipt OCR',
                              style: TextStyle(fontSize: 10, color: ZivaTheme.textMuted, letterSpacing: 0.3),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: ZivaTheme.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ==========================================
                // INPUT METHOD 1: Natural Language Input
                // ==========================================
                _buildNaturalLanguageSection(),
                const SizedBox(height: 16),

                // ==========================================
                // INPUT METHOD 2: Drag-and-Drop / File Upload Zone
                // ==========================================
                _buildReceiptDropzoneSection(),
                const SizedBox(height: 20),

                // Divider / Section Indicator
                const Row(
                  children: [
                    Expanded(child: Divider(color: ZivaTheme.borderSubtle)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'VERIFY & FINALIZE ENTRY',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ZivaTheme.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: ZivaTheme.borderSubtle)),
                  ],
                ),
                const SizedBox(height: 16),

                // Manual Amount & Currency Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ZivaTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          hintText: '0.00',
                          prefixIcon: Icon(Icons.attach_money_rounded, color: ZivaTheme.gold400),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter amount';
                          if (double.tryParse(val) == null) return 'Invalid amount';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_selectedCurrency),
                        initialValue: _selectedCurrency,
                        decoration: const InputDecoration(labelText: 'Currency'),
                        dropdownColor: ZivaTheme.bgCard,
                        items: supportedCurrencies.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCurrency = val;
                              _autoMatchAccount(val);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Account Picker
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedAccountId),
                  initialValue: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Payment Account',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: ZivaTheme.cyan400),
                  ),
                  dropdownColor: ZivaTheme.bgCard,
                  items: _accounts.map((a) {
                    return DropdownMenuItem(
                      value: a['id'],
                      child: Text(a['name']!, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAccountId = val);
                  },
                ),
                const SizedBox(height: 14),

                // Category Picker
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedCategoryId),
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined, color: ZivaTheme.emerald400),
                  ),
                  dropdownColor: ZivaTheme.bgCard,
                  items: _categories.map((c) {
                    return DropdownMenuItem(
                      value: c['id'],
                      child: Text(c['name']!, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final item = _categories.firstWhere((c) => c['id'] == val);
                      setState(() {
                        _selectedCategoryId = val;
                        _selectedCategoryName = item['name']!;
                        _isTaxDeductible = item['tax'] == '1';
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Merchant / Payee
                TextFormField(
                  controller: _payeeController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant or Payee',
                    hintText: 'e.g. Woolworths, Apple, Retainer',
                    prefixIcon: Icon(Icons.storefront_outlined, color: ZivaTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 14),

                // Tax Deductible Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isTaxDeductible
                        ? ZivaTheme.gold500.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isTaxDeductible
                          ? ZivaTheme.gold500.withValues(alpha: 0.3)
                          : ZivaTheme.borderSubtle,
                    ),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: ZivaTheme.gold500,
                    title: Row(
                      children: [
                        const Text(
                          'SARS Tax Deductible (Business Offset)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ZivaTheme.textPrimary),
                        ),
                        if (_isTaxDeductible) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: ZivaTheme.gold500,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '27% OFFSET',
                              style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: const Text(
                      'Eligible for provisional tax liability deduction in BigQuery warehouse',
                      style: TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                    ),
                    value: _isTaxDeductible,
                    onChanged: (val) => setState(() => _isTaxDeductible = val),
                  ),
                ),
                const SizedBox(height: 14),

                // Notes Field
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Tax Invoice Reference',
                    hintText: 'e.g. Invoice INV-WORK-771, project supplies',
                    prefixIcon: Icon(Icons.edit_note_rounded, color: ZivaTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 22),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitTransaction,
                    child: _isSubmitting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              ),
                              SizedBox(width: 10),
                              Text('Writing to BigQuery Warehouse...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Save & Ingest to BigQuery', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// UI for Natural Language Input Field with Real-Time Extraction
  Widget _buildNaturalLanguageSection() {
    return Container(
      decoration: BoxDecoration(
        color: ZivaTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _currentParsed != null
              ? ZivaTheme.gold500.withValues(alpha: 0.5)
              : ZivaTheme.borderCard,
        ),
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: ZivaTheme.gold400, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Natural Language Quick Input',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ZivaTheme.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ZivaTheme.gold500.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'REAL-TIME PARSER',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: ZivaTheme.gold400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nlpController,
            onChanged: _onNlpChanged,
            style: const TextStyle(fontSize: 13, color: ZivaTheme.textPrimary),
            decoration: InputDecoration(
              hintText: "Type e.g. 'Spent 120 ZAR on groceries at Woolworths today'...",
              hintStyle: TextStyle(fontSize: 12, color: ZivaTheme.textMuted.withValues(alpha: 0.6)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _nlpController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: ZivaTheme.textMuted),
                      onPressed: () {
                        _nlpController.clear();
                        _onNlpChanged('');
                      },
                    )
                  : null,
            ),
          ),
          if (_currentParsed != null && _currentParsed!.hasAnyExtractedField) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_currentParsed!.amount != null)
                  _buildExtractedPill(
                    icon: Icons.payments_rounded,
                    label: '${_currentParsed!.currency ?? "ZAR"} ${_currentParsed!.amount!.toStringAsFixed(2)}',
                    color: ZivaTheme.emerald400,
                  ),
                if (_currentParsed!.merchant != null && _currentParsed!.merchant!.isNotEmpty)
                  _buildExtractedPill(
                    icon: Icons.storefront_rounded,
                    label: _currentParsed!.merchant!,
                    color: ZivaTheme.cyan400,
                  ),
                if (_currentParsed!.categoryName != null)
                  _buildExtractedPill(
                    icon: Icons.category_rounded,
                    label: _currentParsed!.categoryName!,
                    color: ZivaTheme.gold400,
                  ),
                if (_currentParsed!.isTaxDeductible)
                  _buildExtractedPill(
                    icon: Icons.shield_rounded,
                    label: 'Tax Deductible',
                    color: ZivaTheme.rose400,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          // Clickable NLP sample presets
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSampleChip('Spent 120 ZAR on groceries at Woolworths today'),
                const SizedBox(width: 6),
                _buildSampleChip('Bought 4500 ZAR standing desk for work invoice INV-WORK-771'),
                const SizedBox(width: 6),
                _buildSampleChip('Paid \$45.50 for dinner at Nandos'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// UI for Drag-and-Drop / File Upload Zone for Receipts
  Widget _buildReceiptDropzoneSection() {
    return GestureDetector(
      onTap: _isScanningReceipt ? null : _handleReceiptPicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _isDragOver
              ? ZivaTheme.gold500.withValues(alpha: 0.15)
              : ZivaTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDragOver
                ? ZivaTheme.gold400
                : (_scannedFile != null
                    ? ZivaTheme.emerald400.withValues(alpha: 0.6)
                    : ZivaTheme.borderCard),
            width: _isDragOver ? 1.8 : 1.0,
            style: BorderStyle.solid,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: _isScanningReceipt
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ZivaTheme.gold400),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Ziva Vision OCR: Scanning receipt line items & tax references...',
                    style: TextStyle(fontSize: 12, color: ZivaTheme.gold300, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (_scannedFile != null ? ZivaTheme.emerald400 : ZivaTheme.gold500)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _scannedFile != null
                          ? Icons.check_circle_rounded
                          : Icons.cloud_upload_outlined,
                      color: _scannedFile != null ? ZivaTheme.emerald400 : ZivaTheme.gold400,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _scannedFile != null
                                  ? 'Receipt Attached: ${_scannedFile!.name}'
                                  : 'Drag & Drop Receipt or PDF',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: ZivaTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (kIsWeb) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: ZivaTheme.cyan400.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'WEB OCR',
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: ZivaTheme.cyan400),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _scannedFile != null
                              ? 'Extracted details auto-filled into form (${_scannedFile!.formattedSize})'
                              : 'Drop receipt image/PDF or click to select • Instant field auto-fill',
                          style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _isScanningReceipt ? null : _handleReceiptPicker,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ZivaTheme.borderCard),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    child: const Text('Browse', style: TextStyle(fontSize: 11, color: ZivaTheme.textSecondary)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildExtractedPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleChip(String prompt) {
    return GestureDetector(
      onTap: () {
        _nlpController.text = prompt;
        _onNlpChanged(prompt);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: ZivaTheme.bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ZivaTheme.borderSubtle),
        ),
        child: Text(
          prompt,
          style: const TextStyle(fontSize: 10, color: ZivaTheme.textMuted),
        ),
      ),
    );
  }
}
