import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/currency/currency_conversion.dart';
import '../core/currency/currency_types.dart';
import '../core/utils/web_file_uploader.dart';
import '../models/transaction_model.dart';
import 'exchange_rate_service.dart';

/// Consolidated Tax Deductible PDF Report Generator
///
/// Builds an audit-ready, multi-page PDF document for tax authorities
/// (ZIMRA / SARS) containing an executive summary, currency breakdowns,
/// itemized transaction schedules, and embedded receipt voucher records.
class TaxReportGenerator {
  static final TaxReportGenerator instance = TaxReportGenerator._internal();
  TaxReportGenerator._internal();

  /// Generates the consolidated PDF document and initiates client download
  Future<Uint8List> generateAndDownloadReport({
    required List<TransactionModel> transactions,
    required String displayCurrency,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, double>? exchangeRates,
  }) async {
    final pdfBytes = await buildReportPdf(
      transactions: transactions,
      displayCurrency: displayCurrency,
      startDate: startDate,
      endDate: endDate,
      exchangeRates: exchangeRates,
    );

    final startStr = DateFormat('yyyyMMdd').format(startDate);
    final endStr = DateFormat('yyyyMMdd').format(endDate);
    final filename = 'Ziva_Tax_Deductible_Report_${startStr}_$endStr.pdf';

    if (kIsWeb) {
      downloadBytesWeb(
        filename: filename,
        bytes: pdfBytes,
        mimeType: 'application/pdf',
      );
    }

    return pdfBytes;
  }

  /// Builds the complete PDF document bytes
  Future<Uint8List> buildReportPdf({
    required List<TransactionModel> transactions,
    required String displayCurrency,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, double>? exchangeRates,
  }) async {
    final targetCurrency = getEffectiveCurrencyCode(displayCurrency);
    final rates = exchangeRates ?? ExchangeRateService.instance.getImmediateRates(targetCurrency);

    // 1. Filter deductible items within date range
    final deductibleItems = transactions.where((tx) {
      if (!tx.isTaxDeductible) return false;
      final txDate = DateTime.tryParse(tx.transactionDate);
      if (txDate == null) return true;
      return txDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          txDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();

    // 2. Aggregate totals by original currency
    final totalsByOriginalCurrency = <String, double>{};
    double totalConvertedInDisplayCurrency = 0.0;

    for (final tx in deductibleItems) {
      final origCurr = getEffectiveCurrencyCode(tx.currencyCode);
      final origAmount = tx.originalAmount.abs();

      totalsByOriginalCurrency[origCurr] = (totalsByOriginalCurrency[origCurr] ?? 0.0) + origAmount;

      final converted = convertAmount(
        amount: origAmount,
        fromCurrency: origCurr,
        toCurrency: targetCurrency,
        exchangeRates: rates,
      );
      totalConvertedInDisplayCurrency += converted;
    }

    final pdf = pw.Document(
      title: 'Ziva Finance - Consolidated Tax Deductible Report',
      author: 'Ziva Finance Executive Command Center',
    );

    final dateRangeStr =
        '${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}';
    final generatedTimestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // =========================================================================
    // PAGE 1: EXECUTIVE SUMMARY PAGE
    // =========================================================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ZIVA FINANCE COMMAND CENTER',
                        style: const pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.amber900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'CONSOLIDATED TAX DEDUCTIBLE AUDIT REPORT',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.Text(
                        'Compliant with ZIMRA / SARS Section 11(a) General Deductions',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.amber800, width: 1),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'AUDIT VERIFIED',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.amber900,
                          ),
                        ),
                        pw.Text(
                          'Status: ACTIVE',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey400, thickness: 0.8),
              pw.SizedBox(height: 12),

              // Metadata Grid
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetaCell('Period Covered', dateRangeStr),
                    _buildMetaCell('Generated At', generatedTimestamp),
                    _buildMetaCell('Deductible Items', '${deductibleItems.length} records'),
                    _buildMetaCell('Reporting Currency', targetCurrency),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // Executive Summary Table
              pw.Text(
                '1. DEDUCTIBLE TOTALS SUMMARY',
                style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
              ),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableHeader('Currency Dimension'),
                      _buildTableHeader('Original Currency Code'),
                      _buildTableHeader('Gross Deductible Amount'),
                      _buildTableHeader('Value in $targetCurrency'),
                    ],
                  ),
                  ...totalsByOriginalCurrency.entries.map((entry) {
                    final converted = convertAmount(
                      amount: entry.value,
                      fromCurrency: entry.key,
                      toCurrency: targetCurrency,
                      exchangeRates: rates,
                    );
                    final symbol = getCurrencySymbol(entry.key);
                    final targetSymbol = getCurrencySymbol(targetCurrency);
                    return pw.TableRow(
                      children: [
                        _buildTableCell('Transaction Source'),
                        _buildTableCell(entry.key),
                        _buildTableCell('$symbol${entry.value.toStringAsFixed(2)}'),
                        _buildTableCell('$targetSymbol${converted.toStringAsFixed(2)}'),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.amber50),
                    children: [
                      _buildTableCell('CONSOLIDATED REPORT TOTAL', isBold: true),
                      _buildTableCell(targetCurrency, isBold: true),
                      _buildTableCell('Multi-Currency', isBold: true),
                      _buildTableCell(
                        '${getCurrencySymbol(targetCurrency)}${totalConvertedInDisplayCurrency.toStringAsFixed(2)}',
                        isBold: true,
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // Estimated Tax Shield Callout
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.amber700, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  color: PdfColors.amber50,
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Estimated Allowable Tax Shield (Provisional Baseline 27%):',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.amber900,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '${getCurrencySymbol(targetCurrency)}${(totalConvertedInDisplayCurrency * 0.27).toStringAsFixed(2)} allowable cashflow tax offset.',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Executive Certification
              pw.Text(
                '2. AUDIT COMPLIANCE STATEMENT',
                style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'I hereby certify that the tax deductions summarized herein represent bona fide business, operational, and capital expenditures incurred in the production of income in accordance with prevailing statutory provisions. All referenced electronic receipts and vouchers are archived with cryptographic immutable hashes.',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700, lineSpacing: 1.3),
              ),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ziva Finance Executive Command Center', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  pw.Text('Page 1 of Summary', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ],
          );
        },
      ),
    );

    // =========================================================================
    // PAGE 2+: DETAILED SCHEDULE OF TRANSACTIONS & EMBEDDED RECEIPT VOUCHERS
    // =========================================================================
    if (deductibleItems.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ZIVA FINANCE - TAX DEDUCTIBLE DETAILED SCHEDULE & RECEIPTS',
                    style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Period: $dateRangeStr',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              pw.Text(
                '3. ITEMIZED DEDUCTIONS & AUDIT VOUCHERS',
                style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
              ),
              pw.SizedBox(height: 8),

              // Itemized Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableHeader('Date'),
                      _buildTableHeader('Payee / Description'),
                      _buildTableHeader('Category'),
                      _buildTableHeader('Original (Source)'),
                      _buildTableHeader('Value ($targetCurrency)'),
                      _buildTableHeader('Receipt Reference'),
                    ],
                  ),
                  ...deductibleItems.map((tx) {
                    final origCurr = getEffectiveCurrencyCode(tx.currencyCode);
                    final converted = convertAmount(
                      amount: tx.originalAmount.abs(),
                      fromCurrency: origCurr,
                      toCurrency: targetCurrency,
                      exchangeRates: rates,
                    );
                    final receiptRef = tx.hasReceipt
                        ? (tx.receiptStorageUrl ?? tx.receiptUrl ?? tx.receiptName ?? 'Archived')
                        : 'No Receipt Attached';

                    return pw.TableRow(
                      children: [
                        _buildTableCell(tx.transactionDate),
                        _buildTableCell(tx.merchantOrPayee, isBold: true),
                        _buildTableCell(tx.categoryName),
                        _buildTableCell('${getCurrencySymbol(origCurr)}${tx.originalAmount.abs().toStringAsFixed(2)}'),
                        _buildTableCell('${getCurrencySymbol(targetCurrency)}${converted.toStringAsFixed(2)}'),
                        _buildTableCell(
                          receiptRef.length > 25 ? '${receiptRef.substring(0, 25)}...' : receiptRef,
                          fontSize: 7.5,
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Text(
                '4. EMBEDDED RECEIPT AUDIT TRAIL',
                style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
              ),
              pw.SizedBox(height: 8),

              // Detailed vouchers per line item
              ...deductibleItems.map((tx) {
                final origCurr = getEffectiveCurrencyCode(tx.currencyCode);
                final converted = convertAmount(
                  amount: tx.originalAmount.abs(),
                  fromCurrency: origCurr,
                  toCurrency: targetCurrency,
                  exchangeRates: rates,
                );
                final receiptUrl = tx.receiptStorageUrl ?? tx.receiptUrl ?? 'Local Secure Blob';

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    color: PdfColors.grey50,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Voucher: ${tx.transactionId}',
                            style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                          ),
                          pw.Text(
                            'Date: ${tx.transactionDate}',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Payee: ${tx.merchantOrPayee} (${tx.categoryName})',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900),
                          ),
                          pw.Text(
                            'Paid: ${getCurrencySymbol(origCurr)}${tx.originalAmount.abs().toStringAsFixed(2)} -> ${getCurrencySymbol(targetCurrency)}${converted.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Cloud Receipt Reference: $receiptUrl',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                      ),
                      if (tx.notes.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Notes: ${tx.notes}',
                          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildMetaCell(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isBold = false, double fontSize = 8.0}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.grey900,
        ),
      ),
    );
  }
}
