import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/debt_model.dart';
import '../../models/envelope_model.dart';
import '../../models/transaction_model.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_engine.dart';
import '../../services/tax_export_service.dart';
import 'quick_entry_sheet.dart';
import 'receipt_viewer_sheet.dart';

class LedgerScreen extends StatefulWidget {
  final int initialTabIndex;

  const LedgerScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Transactions State
  List<TransactionModel> _transactions = [];
  bool _isLoadingTxs = true;
  String _activeTxFilter = 'ALL';

  // Debts State
  List<DebtModel> _debts = [];
  List<EnvelopeModel> _envelopes = [];
  bool _isLoadingDebts = true;
  String _debtStatusFilter = 'ALL'; // ALL, ACTIVE, OVERDUE, PAID_OFF

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadLocalLedger(),
      _loadDebtsAndEnvelopes(),
    ]);
  }

  Future<void> _loadLocalLedger() async {
    setState(() => _isLoadingTxs = true);
    final txs = await SqliteService.instance.getTransactions(limit: 100);
    if (mounted) {
      setState(() {
        _transactions = txs;
        _isLoadingTxs = false;
      });
    }
  }

  Future<void> _loadDebtsAndEnvelopes() async {
    setState(() => _isLoadingDebts = true);
    final debts = await SqliteService.instance.getDebts();
    final envs = await SqliteService.instance.getEnvelopes();
    if (mounted) {
      setState(() {
        _debts = debts;
        _envelopes = envs;
        _isLoadingDebts = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await SyncEngine.instance.processQueue();
    await SyncEngine.instance.refreshFromBigQuery();
    await _loadAllData();
  }

  // =========================================================================
  // TRANSACTIONS TAB HELPERS
  // =========================================================================

  void _openQuickEntry() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickEntryBottomSheet(
        onTransactionLogged: (newTx) {
          setState(() {
            _transactions.insert(0, newTx);
          });
        },
      ),
    );
  }

  void _showReceiptViewer(TransactionModel tx) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReceiptViewerSheet(transaction: tx),
    );
  }

  void _exportTaxReport() {
    final result = TaxExportService.instance.exportAndDownload(
      transactions: _transactions,
      taxYear: 2026,
    );

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
            const Icon(Icons.file_download_done_rounded, color: ZivaTheme.gold400, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tax Audit Report Downloaded: ${result.filename} (${result.recordCount} items, R ${result.estimatedTaxSavingZar.toStringAsFixed(2)} allowable offset)',
                style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(TransactionModel tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZivaTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ZivaTheme.borderCard),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ZivaTheme.roseBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: ZivaTheme.rose400, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Delete Transaction',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete this transaction?',
              style: TextStyle(color: ZivaTheme.textMuted.withValues(alpha: 0.9), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZivaTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ZivaTheme.borderCard),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.merchantOrPayee,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary, fontSize: 13),
                        ),
                        Text(
                          '${tx.categoryName} • ${tx.transactionDate}',
                          style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatAmount(tx.originalAmount, currency: tx.originalCurrency),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: ZivaTheme.rose400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This action will immediately remove the entry from your ledger and execute a hard DELETE query on the BigQuery warehouse.',
              style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: ZivaTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ZivaTheme.rose400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteTransaction(TransactionModel tx) async {
    final deletedId = tx.transactionId;
    setState(() {
      _transactions.removeWhere((t) => t.transactionId == deletedId);
    });

    try {
      await SqliteService.instance.deleteTransaction(deletedId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZivaTheme.bgSurface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: ZivaTheme.borderCard),
            ),
            content: Row(
              children: [
                const Icon(Icons.delete_sweep_rounded, color: ZivaTheme.rose400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Deleted ${tx.merchantOrPayee} from ledger & BigQuery.',
                    style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to delete transaction: $e');
    }
  }

  List<TransactionModel> get _filteredTransactions {
    if (_activeTxFilter == 'EXPENSES') {
      return _transactions.where((t) => t.originalAmount < 0).toList();
    } else if (_activeTxFilter == 'INCOME') {
      return _transactions.where((t) => t.originalAmount > 0).toList();
    } else if (_activeTxFilter == 'TAX') {
      return _transactions.where((t) => t.isTaxDeductible).toList();
    }
    return _transactions;
  }

  double get _totalTaxDeductibleZar {
    return _transactions
        .where((t) => t.isTaxDeductible)
        .fold<double>(0.0, (sum, t) => sum + t.reportingAmountZar.abs());
  }

  // =========================================================================
  // SETTLE UP & DEBT ACTIONS
  // =========================================================================

  void _openSettleUpModal(DebtModel debt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SettleUpSheet(
        debt: debt,
        envelopes: _envelopes,
        onSettled: () async {
          await _loadDebtsAndEnvelopes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: ZivaTheme.bgSurface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: ZivaTheme.emerald400),
                ),
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: ZivaTheme.emerald400, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Settlement logged for ${debt.counterparty}. Net worth and envelope balance updated.',
                        style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _openAddDebtModal({DebtDirection direction = DebtDirection.owedByMe}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DebtFormSheet(
        initialDirection: direction,
        envelopes: _envelopes,
        onSaved: () async {
          await _loadDebtsAndEnvelopes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: ZivaTheme.bgSurface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: ZivaTheme.gold400),
                ),
                content: const Text(
                  'Debt record successfully saved and synchronized.',
                  style: TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteDebt(DebtModel debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZivaTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ZivaTheme.borderCard),
        ),
        title: const Text('Delete Debt Record', style: TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove the debt entry with ${debt.counterparty}? This will delete all logged repayments and adjust your net worth.',
          style: const TextStyle(color: ZivaTheme.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.rose400),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SqliteService.instance.deleteDebt(debt.id);
      await _loadDebtsAndEnvelopes();
    }
  }

  void _showRepaymentsHistoryModal(DebtModel debt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: ZivaTheme.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ZivaTheme.gold400.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history_rounded, color: ZivaTheme.gold400, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Repayments: ${debt.counterparty}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary),
                      ),
                      Text(
                        'Outstanding: R ${debt.currentOutstandingBalanceZar.toStringAsFixed(0)} of R ${debt.originalPrincipalZar.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: ZivaTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: ZivaTheme.textMuted),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: ZivaTheme.borderCard),
            const SizedBox(height: 10),
            Expanded(
              child: debt.repayments.isEmpty
                  ? const Center(
                      child: Text('No repayments recorded yet.', style: TextStyle(color: ZivaTheme.textMuted)),
                    )
                  : ListView.separated(
                      itemCount: debt.repayments.length,
                      separatorBuilder: (_, __) => const Divider(color: ZivaTheme.borderCard, height: 1),
                      itemBuilder: (context, idx) {
                        final rep = debt.repayments[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ZivaTheme.emerald400.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, color: ZivaTheme.emerald400, size: 16),
                          ),
                          title: Text(
                            'R ${rep.amountZar.toStringAsFixed(0)} via ${rep.paymentMethod}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary),
                          ),
                          subtitle: Text(
                            '${DateFormat('yyyy-MM-dd HH:mm').format(rep.paymentDate)}${rep.sourceEnvelopeName != null ? ' • Envelope: ${rep.sourceEnvelopeName}' : ''}${rep.notes.isNotEmpty ? ' • ${rep.notes}' : ''}',
                            style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // MAIN BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      appBar: AppBar(
        title: const Text('Ledger & Debt Settlement Core'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: ZivaTheme.gold400,
          labelColor: ZivaTheme.gold400,
          unselectedLabelColor: ZivaTheme.textMuted,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Transactions & Sync'),
            Tab(icon: Icon(Icons.arrow_outward_rounded, size: 18), text: 'Debts I Owe (Liabilities)'),
            Tab(icon: Icon(Icons.call_received_rounded, size: 18), text: 'Debts Owed to Me (Receivables)'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined, color: ZivaTheme.gold400),
            tooltip: 'Download SARS Tax Audit Report (CSV & Receipts)',
            onPressed: _exportTaxReport,
          ),
          ValueListenableBuilder<int>(
            valueListenable: SyncEngine.instance.pendingCount,
            builder: (context, count, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: SyncEngine.instance.isSyncing,
                builder: (context, isSyncing, _) {
                  return IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          isSyncing ? Icons.sync_rounded : (count > 0 ? Icons.cloud_queue_rounded : Icons.cloud_done_rounded),
                          color: count > 0 ? ZivaTheme.gold400 : ZivaTheme.emerald400,
                        ),
                        if (count > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: ZivaTheme.rose500,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: _onRefresh,
                    tooltip: count > 0 ? '$count items queued offline. Tap to sync.' : 'All synced to BigQuery',
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _openQuickEntry();
          } else if (_tabController.index == 1) {
            _openAddDebtModal(direction: DebtDirection.owedByMe);
          } else {
            _openAddDebtModal(direction: DebtDirection.owedToMe);
          }
        },
        backgroundColor: ZivaTheme.gold500,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _tabController.index == 0 ? 'Add Entry' : (_tabController.index == 1 ? 'Add Liability' : 'Add Receivable'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionsTab(),
          _buildDebtsTab(DebtDirection.owedByMe),
          _buildDebtsTab(DebtDirection.owedToMe),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: TRANSACTIONS
  // =========================================================================

  Widget _buildTransactionsTab() {
    return Column(
      children: [
        // Filter Tabs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTxFilterChip('ALL', 'All Entries'),
                const SizedBox(width: 8),
                _buildTxFilterChip('EXPENSES', 'Expenses'),
                const SizedBox(width: 8),
                _buildTxFilterChip('INCOME', 'Inflows'),
                const SizedBox(width: 8),
                _buildTxFilterChip('TAX', 'Tax Deductible'),
              ],
            ),
          ),
        ),

        // Tax Audit Report Banner
        if (_activeTxFilter == 'TAX')
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZivaTheme.gold500.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: ZivaTheme.gold400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SARS Provisional Tax Deductions',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary),
                      ),
                      Text(
                        'R ${(_totalTaxDeductibleZar * 0.27).toStringAsFixed(2)} estimated 27% cashflow offset (R ${_totalTaxDeductibleZar.toStringAsFixed(2)} allowable gross)',
                        style: const TextStyle(fontSize: 11, color: ZivaTheme.gold300),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: _exportTaxReport,
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Export Tax Report', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZivaTheme.gold500,
                    foregroundColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

        // Transactions Feed
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: ZivaTheme.gold500,
            backgroundColor: ZivaTheme.bgSurface,
            child: _isLoadingTxs
                ? const Center(child: CircularProgressIndicator(color: ZivaTheme.gold500))
                : _filteredTransactions.isEmpty
                    ? _buildEmptyTransactionsState()
                    : ListView.separated(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
                        itemCount: _filteredTransactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final tx = _filteredTransactions[index];
                          final isExpense = tx.originalAmount < 0;

                          return Dismissible(
                            key: Key(tx.transactionId),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              return await _showDeleteConfirmationDialog(tx);
                            },
                            onDismissed: (direction) {
                              _deleteTransaction(tx);
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20.0),
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              decoration: BoxDecoration(
                                color: ZivaTheme.roseBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: ZivaTheme.rose400.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.delete_forever_rounded, color: ZivaTheme.rose400, size: 22),
                                  SizedBox(width: 6),
                                  Text(
                                    'DELETE',
                                    style: TextStyle(
                                      color: ZivaTheme.rose400,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            child: Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _showReceiptViewer(tx),
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isExpense ? ZivaTheme.roseBg : ZivaTheme.emeraldBg,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          isExpense ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                                          color: isExpense ? ZivaTheme.rose400 : ZivaTheme.emerald400,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    tx.merchantOrPayee,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (tx.isTaxDeductible) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: ZivaTheme.gold400.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: ZivaTheme.gold400.withValues(alpha: 0.4)),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.shield_outlined, size: 10, color: ZivaTheme.gold400),
                                                        SizedBox(width: 3),
                                                        Text(
                                                          'SARS TAX',
                                                          style: TextStyle(
                                                            color: ZivaTheme.gold400,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  tx.transactionDate,
                                                  style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11),
                                                ),
                                                const SizedBox(width: 6),
                                                const Text('•', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11)),
                                                const SizedBox(width: 6),
                                                Text(
                                                  tx.categoryName,
                                                  style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            CurrencyFormatter.formatAmount(tx.originalAmount, currency: tx.originalCurrency),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              fontFamily: 'monospace',
                                              color: isExpense ? ZivaTheme.textPrimary : ZivaTheme.emerald400,
                                            ),
                                          ),
                                          if (tx.hasReceipt)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.receipt_long_rounded,
                                                    size: 13,
                                                    color: tx.receiptUrl != null ? ZivaTheme.gold400 : ZivaTheme.textMuted,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    tx.receiptUrl != null ? 'Cloud Receipt' : 'Local Blob',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: tx.receiptUrl != null ? ZivaTheme.gold400 : ZivaTheme.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildTxFilterChip(String filterKey, String label) {
    final isSelected = _activeTxFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _activeTxFilter = filterKey);
        }
      },
      selectedColor: ZivaTheme.gold400,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : ZivaTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: ZivaTheme.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? ZivaTheme.gold400 : ZivaTheme.borderCard,
        ),
      ),
    );
  }

  Widget _buildEmptyTransactionsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: ZivaTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No transactions found for "$_activeTxFilter"',
            style: const TextStyle(color: ZivaTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TABS 2 & 3: DEBTS I OWE & DEBTS OWED TO ME
  // =========================================================================

  Widget _buildDebtsTab(DebtDirection direction) {
    if (_isLoadingDebts) {
      return const Center(child: CircularProgressIndicator(color: ZivaTheme.gold400));
    }

    final isOwedByMe = direction == DebtDirection.owedByMe;
    final debtsList = _debts.where((d) => d.direction == direction).toList();

    // Filter by status
    final filteredDebts = debtsList.where((d) {
      if (_debtStatusFilter == 'ACTIVE') return !d.isPaidOff;
      if (_debtStatusFilter == 'OVERDUE') return d.isOverdue;
      if (_debtStatusFilter == 'PAID_OFF') return d.isPaidOff;
      return true;
    }).toList();

    final totalOutstanding = debtsList.fold<double>(0.0, (sum, d) => sum + d.currentOutstandingBalanceZar);
    final totalPrincipal = debtsList.fold<double>(0.0, (sum, d) => sum + d.originalPrincipalZar);
    final totalRepaid = totalPrincipal - totalOutstanding;
    final pctSettled = totalPrincipal > 0 ? (totalRepaid / totalPrincipal * 100).clamp(0.0, 100.0) : 100.0;

    return Column(
      children: [
        // Top KPI Strip
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ZivaTheme.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZivaTheme.borderCard),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final tiles = [
                _buildDebtKpiTile('TOTAL PRINCIPAL', totalPrincipal, ZivaTheme.textPrimary),
                _buildDebtKpiTile('OUTSTANDING BALANCE', totalOutstanding, isOwedByMe ? ZivaTheme.rose400 : ZivaTheme.emerald400),
                _buildDebtKpiTile('TOTAL SETTLED', totalRepaid, ZivaTheme.gold400),
                _buildDebtKpiTile('PERCENTAGE SETTLED', pctSettled, ZivaTheme.emerald400, isPct: true),
              ];

              if (isNarrow) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: tiles.map((t) => SizedBox(width: (constraints.maxWidth - 20) / 2, child: t)).toList(),
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: tiles.map((t) => Expanded(child: t)).toList(),
              );
            },
          ),
        ),

        // Status Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDebtFilterChip('ALL', 'All Positions (${debtsList.length})'),
                const SizedBox(width: 8),
                _buildDebtFilterChip('ACTIVE', 'Active & Current'),
                const SizedBox(width: 8),
                _buildDebtFilterChip('OVERDUE', 'Overdue'),
                const SizedBox(width: 8),
                _buildDebtFilterChip('PAID_OFF', 'Fully Settled'),
              ],
            ),
          ),
        ),

        // Debts List
        Expanded(
          child: filteredDebts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.handshake_outlined, size: 64, color: ZivaTheme.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        isOwedByMe ? 'No liabilities recorded.' : 'No receivables recorded.',
                        style: const TextStyle(color: ZivaTheme.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _openAddDebtModal(direction: direction),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(isOwedByMe ? 'Record a Liability' : 'Record a Receivable'),
                        style: ElevatedButton.styleFrom(backgroundColor: ZivaTheme.gold400, foregroundColor: Colors.black),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 6, bottom: 80),
                  itemCount: filteredDebts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final debt = filteredDebts[idx];
                    return _buildDebtCard(debt);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDebtKpiTile(String label, double amount, Color color, {bool isPct = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 3),
        Text(
          isPct ? '${amount.toStringAsFixed(1)}%' : 'R ${amount.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildDebtFilterChip(String key, String label) {
    final isSelected = _debtStatusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _debtStatusFilter = key);
        }
      },
      selectedColor: ZivaTheme.gold400,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : ZivaTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      backgroundColor: ZivaTheme.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? ZivaTheme.gold400 : ZivaTheme.borderCard),
      ),
    );
  }

  Widget _buildDebtCard(DebtModel debt) {
    final isOwedByMe = debt.direction == DebtDirection.owedByMe;
    final themeColor = isOwedByMe ? ZivaTheme.rose400 : ZivaTheme.emerald400;

    return Container(
      decoration: BoxDecoration(
        color: ZivaTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: debt.isOverdue ? ZivaTheme.rose400.withValues(alpha: 0.6) : ZivaTheme.borderCard),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Counterparty & Badges
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isOwedByMe ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                  color: themeColor,
                  size: 18,
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
                          debt.counterparty,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isOwedByMe ? 'LIABILITY' : 'RECEIVABLE',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: themeColor),
                          ),
                        ),
                        if (debt.isPaidOff) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ZivaTheme.emerald400.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PAID OFF',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ZivaTheme.emerald400),
                            ),
                          ),
                        ] else if (debt.isOverdue) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ZivaTheme.rose400.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'OVERDUE',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ZivaTheme.rose400),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${debt.typeLabel}${debt.dueDate != null ? ' • Due ${DateFormat('yyyy-MM-dd').format(debt.dueDate!)}' : ''}${debt.interestRatePercent != null ? ' • ${debt.interestRatePercent}% APR' : ''}',
                      style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R ${debt.currentOutstandingBalanceZar.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: themeColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'Orig: R ${debt.originalPrincipalZar.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 10, color: ZivaTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (debt.pctSettled / 100.0).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: ZivaTheme.bgSurface,
                    valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${debt.pctSettled.toInt()}% Settled',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons: Settle Up, View Repayments, Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (debt.repayments.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showRepaymentsHistoryModal(debt),
                  icon: const Icon(Icons.history_rounded, size: 14, color: ZivaTheme.textMuted),
                  label: Text(
                    '${debt.repayments.length} Repayments',
                    style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: ZivaTheme.rose400),
                tooltip: 'Delete Record',
                onPressed: () => _deleteDebt(debt),
              ),
              const SizedBox(width: 6),
              if (!debt.isPaidOff)
                ElevatedButton.icon(
                  onPressed: () => _openSettleUpModal(debt),
                  icon: const Icon(Icons.payments_outlined, size: 14),
                  label: const Text('Settle Up', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZivaTheme.gold400,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SETTLE UP BOTTOM SHEET
// ===========================================================================

class _SettleUpSheet extends StatefulWidget {
  final DebtModel debt;
  final List<EnvelopeModel> envelopes;
  final VoidCallback onSettled;

  const _SettleUpSheet({
    required this.debt,
    required this.envelopes,
    required this.onSettled,
  });

  @override
  State<_SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<_SettleUpSheet> {
  bool _isFullPayoff = true;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = 'EFT Wire';
  String? _selectedEnvelopeId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.debt.currentOutstandingBalanceZar.toStringAsFixed(2);
    if (widget.envelopes.isNotEmpty) {
      _selectedEnvelopeId = widget.debt.linkedEnvelopeId ?? widget.envelopes.first.categoryId;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitSettlement() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;

    setState(() => _isSaving = true);

    try {
      await SqliteService.instance.recordDebtRepayment(
        debtId: widget.debt.id,
        amountZar: amount,
        paymentMethod: _paymentMethod,
        sourceEnvelopeId: _selectedEnvelopeId,
        notes: _notesController.text.trim().isEmpty
            ? (_isFullPayoff ? 'Full Payoff Settle Up' : 'Partial Payment')
            : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSettled();
      }
    } catch (e) {
      debugPrint('Settlement error: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = widget.debt.currentOutstandingBalanceZar;
    final isOwedByMe = widget.debt.direction == DebtDirection.owedByMe;

    return Container(
      decoration: const BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: ZivaTheme.borderCard, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ZivaTheme.gold400.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.handshake_rounded, color: ZivaTheme.gold400, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOwedByMe ? 'Settle Up: ${widget.debt.counterparty}' : 'Receive Payment: ${widget.debt.counterparty}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary),
                      ),
                      Text(
                        'Outstanding: R ${outstanding.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: ZivaTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: ZivaTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Payoff Type Toggle (Full vs Partial)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text('Full Settlement (R ${outstanding.toStringAsFixed(0)})')),
                    selected: _isFullPayoff,
                    selectedColor: ZivaTheme.gold400,
                    labelStyle: TextStyle(
                      color: _isFullPayoff ? Colors.black : ZivaTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _isFullPayoff = true;
                          _amountController.text = outstanding.toStringAsFixed(2);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Partial Payment')),
                    selected: !_isFullPayoff,
                    selectedColor: ZivaTheme.gold400,
                    labelStyle: TextStyle(
                      color: !_isFullPayoff ? Colors.black : ZivaTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _isFullPayoff = false;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount Input (editable if partial)
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_isFullPayoff,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Settlement Amount (ZAR)',
                prefixText: 'R ',
                prefixStyle: const TextStyle(color: ZivaTheme.gold400, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: ZivaTheme.bgCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
              ),
            ),
            const SizedBox(height: 14),

            // Source Envelope Selection
            if (widget.envelopes.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedEnvelopeId,
                dropdownColor: ZivaTheme.bgSurface,
                decoration: InputDecoration(
                  labelText: isOwedByMe ? 'Deduct from Envelope' : 'Deposit into Envelope',
                  filled: true,
                  fillColor: ZivaTheme.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                ),
                items: widget.envelopes.map((env) {
                  return DropdownMenuItem<String>(
                    value: env.categoryId,
                    child: Text('${env.categoryName} (R ${env.remainingAmountZar.toStringAsFixed(0)} available)'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedEnvelopeId = val),
              ),
              const SizedBox(height: 14),
            ],

            // Payment Method & Notes
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    dropdownColor: ZivaTheme.bgSurface,
                    decoration: InputDecoration(
                      labelText: 'Payment Method',
                      filled: true,
                      fillColor: ZivaTheme.bgCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'EFT Wire', child: Text('EFT Wire')),
                      DropdownMenuItem(value: 'Instant Card', child: Text('Debit/Credit Card')),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Crypto (BTC/USDC)', child: Text('Crypto Asset')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _paymentMethod = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes & Settlement Reference',
                hintText: 'e.g. Split dinner, invoice #8841...',
                filled: true,
                fillColor: ZivaTheme.bgCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ZivaTheme.borderCard)),
              ),
            ),
            const SizedBox(height: 20),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submitSettlement,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _isSaving ? 'Processing...' : 'Confirm & Settle Up',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZivaTheme.gold400,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// ADD / EDIT DEBT SHEET
// ===========================================================================

class _DebtFormSheet extends StatefulWidget {
  final DebtDirection initialDirection;
  final List<EnvelopeModel> envelopes;
  final VoidCallback onSaved;

  const _DebtFormSheet({
    required this.initialDirection,
    required this.envelopes,
    required this.onSaved,
  });

  @override
  State<_DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends State<_DebtFormSheet> {
  late DebtDirection _direction;
  DebtType _debtType = DebtType.personalLoan;
  final _counterpartyCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _dueDate;
  String? _linkedEnvelopeId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection;
    if (widget.envelopes.isNotEmpty) {
      _linkedEnvelopeId = widget.envelopes.first.categoryId;
    }
  }

  @override
  void dispose() {
    _counterpartyCtrl.dispose();
    _amountCtrl.dispose();
    _interestRateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _counterpartyCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (name.isEmpty || amount <= 0) return;

    setState(() => _isSaving = true);

    final debt = DebtModel(
      id: 'DEBT_${DateTime.now().millisecondsSinceEpoch}',
      counterparty: name,
      direction: _direction,
      debtType: _debtType,
      originalPrincipalZar: amount,
      currentOutstandingBalanceZar: amount,
      interestRatePercent: double.tryParse(_interestRateCtrl.text),
      dueDate: _dueDate,
      linkedEnvelopeId: _linkedEnvelopeId,
      linkedEnvelopeName: (_linkedEnvelopeId != null && widget.envelopes.isNotEmpty)
          ? widget.envelopes.firstWhere((e) => e.categoryId == _linkedEnvelopeId, orElse: () => widget.envelopes.first).categoryName
          : null,
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await SqliteService.instance.saveDebt(debt);
    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: ZivaTheme.borderCard, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _direction == DebtDirection.owedByMe ? 'Record New Liability (Money I Owe)' : 'Record New Receivable (Owed to Me)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZivaTheme.textPrimary),
            ),
            const SizedBox(height: 14),

            // Direction Toggle
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('I Owe (Liability)')),
                    selected: _direction == DebtDirection.owedByMe,
                    selectedColor: ZivaTheme.rose400,
                    labelStyle: TextStyle(
                      color: _direction == DebtDirection.owedByMe ? Colors.white : ZivaTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _direction = DebtDirection.owedByMe);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Owed to Me (Receivable)')),
                    selected: _direction == DebtDirection.owedToMe,
                    selectedColor: ZivaTheme.emerald400,
                    labelStyle: TextStyle(
                      color: _direction == DebtDirection.owedToMe ? Colors.white : ZivaTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _direction = DebtDirection.owedToMe);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _counterpartyCtrl,
              decoration: InputDecoration(
                labelText: 'Counterparty (Person / Institution)',
                hintText: 'e.g. Kudzai Venture, FNB Finance, Apex Client...',
                filled: true,
                fillColor: ZivaTheme.bgCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Principal Amount (ZAR)',
                      prefixText: 'R ',
                      filled: true,
                      fillColor: ZivaTheme.bgCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _interestRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Interest Rate % (Optional)',
                      suffixText: '%',
                      filled: true,
                      fillColor: ZivaTheme.bgCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<DebtType>(
              initialValue: _debtType,
              dropdownColor: ZivaTheme.bgSurface,
              decoration: InputDecoration(
                labelText: 'Debt Category',
                filled: true,
                fillColor: ZivaTheme.bgCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: DebtType.values.map((t) {
                return DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _debtType = val);
              },
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: 'Notes & Context',
                filled: true,
                fillColor: ZivaTheme.bgCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZivaTheme.gold400,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(_isSaving ? 'Saving...' : 'Save Debt Record', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
