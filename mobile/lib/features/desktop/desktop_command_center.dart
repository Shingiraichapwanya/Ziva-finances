import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_environment.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/account_model.dart';
import '../../models/transaction_model.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_engine.dart';
import '../ledger/quick_entry_sheet.dart';

class DesktopCommandCenter extends StatefulWidget {
  final VoidCallback onLogTransaction;

  const DesktopCommandCenter({super.key, required this.onLogTransaction});

  @override
  State<DesktopCommandCenter> createState() => _DesktopCommandCenterState();
}

class _DesktopCommandCenterState extends State<DesktopCommandCenter> {
  int _selectedNavIndex = 0;
  String _selectedCurrency = 'ZAR';
  List<AccountModel> _accounts = [];
  List<TransactionModel> _transactions = [];
  List<Map<String, dynamic>> _debts = [];
  List<Map<String, dynamic>> _balances = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await SqliteService.instance.getLocalAccounts();
      final txs = await SqliteService.instance.getTransactions(limit: 100);

      // Load debts & balances from backend if available
      List<Map<String, dynamic>> debtsData = [];
      List<Map<String, dynamic>> balancesData = [];
      final baseUrl = ApiConstants.defaultBaseUrl;

      if (baseUrl.isNotEmpty) {
        try {
          final resDebts = await http.get(Uri.parse('$baseUrl/api/debts')).timeout(const Duration(seconds: 4));
          if (resDebts.statusCode == 200) {
            debtsData = List<Map<String, dynamic>>.from(jsonDecode(resDebts.body));
          }
          final resBal = await http.get(Uri.parse('$baseUrl/api/debts/balances')).timeout(const Duration(seconds: 4));
          if (resBal.statusCode == 200) {
            balancesData = List<Map<String, dynamic>>.from(jsonDecode(resBal.body));
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _accounts = accounts;
          _transactions = txs;
          _debts = debtsData;
          _balances = balancesData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DesktopCommandCenter] Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _settleDebt(String debtId) async {
    final baseUrl = ApiConstants.defaultBaseUrl;
    if (baseUrl.isNotEmpty) {
      try {
        await http.patch(Uri.parse('$baseUrl/api/debts/$debtId/settle'));
        await _loadAllData();
      } catch (e) {
        debugPrint('Error settling debt: $e');
      }
    }
  }

  void _openQuickEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickEntryBottomSheet(
        onTransactionLogged: (tx) {
          _loadAllData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      body: Row(
        children: [
          // 1. Desktop Persistent Left Sidebar
          _buildDesktopSidebar(),

          // 2. Main Desktop Content Area
          Expanded(
            child: Column(
              children: [
                _buildDesktopTopBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: ZivaTheme.gold500))
                      : _buildSelectedTabContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: ZivaTheme.bgSurface,
        border: Border(right: BorderSide(color: ZivaTheme.borderCard)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ZivaTheme.gold500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: Icon(Icons.diamond_outlined, color: ZivaTheme.gold400, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ZIVA FINANCE',
                      style: TextStyle(
                        color: ZivaTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'COMMAND CENTER',
                      style: TextStyle(
                        color: ZivaTheme.gold400,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Environment Badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppEnvironment.badgeBgColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppEnvironment.badgeBorderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 13, color: AppEnvironment.accentColor),
                  const SizedBox(width: 8),
                  Text(
                    AppEnvironment.badgeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppEnvironment.accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: ZivaTheme.borderCard, height: 1),
          const SizedBox(height: 12),

          // Nav Items
          _sidebarNavItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard Overview'),
          _sidebarNavItem(1, Icons.handshake_outlined, Icons.handshake_rounded, 'Debt & Credit Ledger'),
          _sidebarNavItem(2, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Transactions Ledger'),
          _sidebarNavItem(3, Icons.pie_chart_outline, Icons.pie_chart_rounded, 'Zero-Based Budgets'),
          _sidebarNavItem(4, Icons.tune_outlined, Icons.tune_rounded, 'Dev & Cloud Status'),

          const Spacer(),

          // Warehouse Telemetry Footer
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ZivaTheme.bgCore,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZivaTheme.borderCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'BigQuery Warehouse',
                      style: TextStyle(color: ZivaTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'budget-tracker-507418 (africa-south1)',
                  style: TextStyle(color: ZivaTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarNavItem(int index, IconData unselectedIcon, IconData selectedIcon, String title) {
    final isSelected = _selectedNavIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedNavIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? ZivaTheme.gold500.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.3)) : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              size: 18,
              color: isSelected ? ZivaTheme.gold400 : ZivaTheme.textMuted,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? ZivaTheme.textPrimary : ZivaTheme.textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: ZivaTheme.bgSurface,
        border: Border(bottom: BorderSide(color: ZivaTheme.borderCard)),
      ),
      child: Row(
        children: [
          // View Title
          Text(
            _selectedNavIndex == 0
                ? 'EXECUTIVE FINANCIAL COMMAND CENTER'
                : _selectedNavIndex == 1
                    ? 'DEBT & CREDIT LEDGER (PEER-TO-PEER)'
                    : _selectedNavIndex == 2
                        ? 'TRANSACTIONS & CASH FLOW AUDIT'
                        : _selectedNavIndex == 3
                            ? 'ZERO-BASED BUDGET ENVELOPES'
                            : 'SYSTEM TELEMETRY',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: ZivaTheme.textPrimary,
            ),
          ),
          const Spacer(),

          // Currency Switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: ZivaTheme.bgCore,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ZivaTheme.borderCard),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                dropdownColor: ZivaTheme.bgSurface,
                style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 'ZAR', child: Text('ZAR (R)')),
                  DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCurrency = val);
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Refresh Action
          IconButton(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh, size: 18, color: ZivaTheme.textMuted),
            tooltip: 'Sync with BigQuery',
          ),

          const SizedBox(width: 12),

          // Quick Entry Button
          ElevatedButton.icon(
            onPressed: _openQuickEntry,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Log Transaction'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ZivaTheme.gold500,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedNavIndex) {
      case 1:
        return _buildDebtCreditView();
      case 2:
        return _buildTransactionsView();
      case 3:
      case 4:
      case 0:
      default:
        return _buildOverviewDashboard();
    }
  }

  Widget _buildOverviewDashboard() {
    double totalZar = 0;
    for (var acc in _accounts) {
      if (acc.primaryCurrency == 'ZAR') totalZar += acc.nativeBalance;
      if (acc.primaryCurrency == 'USD') totalZar += acc.nativeBalance * 18.25;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4-Card Widescreen KPI Grid
          Row(
            children: [
              Expanded(child: _kpiCard('Net Liquid Wealth', CurrencyFormatter.format(totalZar, 'ZAR'), 'Consolidated across active tiers', Icons.account_balance_wallet_outlined, const Color(0xFF10B981))),
              const SizedBox(width: 16),
              Expanded(child: _kpiCard('Peer Receivables (Owed to You)', '\$${_calculateTotalOwedToMe().toStringAsFixed(2)}', '${_balances.where((b) => (b['totalOwedToMe'] ?? 0) > 0).length} debtors active', Icons.arrow_downward, const Color(0xFF10B981))),
              const SizedBox(width: 16),
              Expanded(child: _kpiCard('Peer Payables (You Owe)', '\$${_calculateTotalOwedByMe().toStringAsFixed(2)}', '${_balances.where((b) => (b['totalOwedByMe'] ?? 0) > 0).length} creditors active', Icons.arrow_upward, const Color(0xFFEF4444))),
              const SizedBox(width: 16),
              Expanded(child: _kpiCard('Pending Sync Queue', '${SyncEngine.instance.pendingCount.value} items', 'Offline SQLite mutation buffer', Icons.cloud_sync_outlined, ZivaTheme.gold400)),
            ],
          ),

          const SizedBox(height: 24),

          // Multi-Column Split: Left = Accounts, Right = Recent Activity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Accounts Breakdown
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZivaTheme.borderCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ACTIVE FINANCIAL INSTITUTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: ZivaTheme.textMuted)),
                      const SizedBox(height: 16),
                      if (_accounts.isEmpty)
                        const Padding(padding: EdgeInsets.all(20), child: Text('No accounts registered.', style: TextStyle(color: ZivaTheme.textMuted)))
                      else
                        ..._accounts.map((acc) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: ZivaTheme.gold500.withValues(alpha: 0.1),
                            child: Icon(Icons.account_balance, color: ZivaTheme.gold400, size: 18),
                          ),
                          title: Text(acc.accountName, style: const TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('${acc.financialInstitution} • ${acc.accountType}', style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                          trailing: Text(CurrencyFormatter.format(acc.nativeBalance, acc.primaryCurrency), style: const TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        )),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Right: Recent Movements
              Expanded(
                flex: 7,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZivaTheme.borderCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('RECENT LEDGER MOVEMENTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: ZivaTheme.textMuted)),
                          TextButton(onPressed: () => setState(() => _selectedNavIndex = 2), child: const Text('View All', style: TextStyle(fontSize: 12, color: ZivaTheme.gold400))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_transactions.isEmpty)
                        const Padding(padding: EdgeInsets.all(20), child: Text('No recent transactions recorded.', style: TextStyle(color: ZivaTheme.textMuted)))
                      else
                        ..._transactions.take(5).map((tx) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: tx.transactionType == 'INCOME' ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                            child: Icon(tx.transactionType == 'INCOME' ? Icons.arrow_downward : Icons.arrow_upward, color: tx.transactionType == 'INCOME' ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 16),
                          ),
                          title: Text(tx.merchantOrPayee, style: const TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text('${tx.transactionDate.toIso8601String().split('T')[0]} • ${tx.categoryId}', style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11)),
                          trailing: Text(CurrencyFormatter.format(tx.originalAmount, tx.originalCurrency), style: TextStyle(color: tx.transactionType == 'INCOME' ? const Color(0xFF10B981) : ZivaTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                        )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCreditView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INDIVIDUAL NET BALANCES (debt_credit_balances View)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: ZivaTheme.textMuted)),
          const SizedBox(height: 14),

          if (_balances.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ZivaTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ZivaTheme.borderCard),
              ),
              child: const Center(child: Text('All peer debts and credits are settled. No outstanding balances!', style: TextStyle(color: ZivaTheme.textMuted))),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _balances.map((b) {
                final net = (b['netBalance'] ?? b['net_balance'] ?? 0).toDouble();
                final isPositive = net > 0;
                final isNegative = net < 0;
                return Container(
                  width: 320,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isPositive ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(b['personName'] ?? b['person_name'] ?? 'Unknown', style: const TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPositive ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPositive ? 'THEY OWE YOU' : isNegative ? 'YOU OWE' : 'SETTLED',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${isPositive ? '+' : ''}\$${net.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 32),

          const Text('FULL LEDGER RECORDS (debt_credit_ledger Table)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: ZivaTheme.textMuted)),
          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: ZivaTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZivaTheme.borderCard),
            ),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date', style: TextStyle(color: ZivaTheme.textMuted))),
                DataColumn(label: Text('Person', style: TextStyle(color: ZivaTheme.textMuted))),
                DataColumn(label: Text('Direction', style: TextStyle(color: ZivaTheme.textMuted))),
                DataColumn(label: Text('Notes', style: TextStyle(color: ZivaTheme.textMuted))),
                DataColumn(label: Text('Amount', style: TextStyle(color: ZivaTheme.textMuted))),
                DataColumn(label: Text('Status', style: TextStyle(color: ZivaTheme.textMuted))),
                DataColumn(label: Text('Action', style: TextStyle(color: ZivaTheme.textMuted))),
              ],
              rows: _debts.map((d) {
                final isPending = (d['status'] ?? '') == 'Pending';
                return DataRow(cells: [
                  DataCell(Text(d['date'] ?? '—', style: const TextStyle(color: ZivaTheme.textPrimary))),
                  DataCell(Text(d['personName'] ?? d['person_name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary))),
                  DataCell(Text(d['direction'] == 'owed_to_me' ? 'Owed to Me' : 'Owed by Me', style: TextStyle(color: d['direction'] == 'owed_to_me' ? const Color(0xFF10B981) : const Color(0xFFEF4444)))),
                  DataCell(Text(d['notes'] ?? '—', style: const TextStyle(color: ZivaTheme.textMuted))),
                  DataCell(Text('\$${(d['amount'] ?? 0).toDouble().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary))),
                  DataCell(Text(d['status'] ?? '—', style: TextStyle(color: isPending ? ZivaTheme.gold400 : ZivaTheme.textMuted))),
                  DataCell(
                    isPending
                        ? TextButton(
                            onPressed: () => _settleDebt(d['id']),
                            child: const Text('Mark Settled', style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
                          )
                        : const SizedBox.shrink(),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FILTERABLE & SORTABLE TRANSACTION REPOSITORIES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: ZivaTheme.textMuted)),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: ZivaTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZivaTheme.borderCard),
            ),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date', style: TextStyle(color: ZivaTheme.textMuted))),
                DataColumn(label: Text('Payee / Merchant', style: TextStyle(color: ZivaTheme.textMuted))),
                DataColumn(label: Text('Account', style: TextStyle(color: ZivaTheme.textMuted))),
                DataColumn(label: Text('Category', style: TextStyle(color: ZivaTheme.textMuted))),
                DataColumn(label: Text('Type', style: TextStyle(color: ZivaTheme.textMuted))),
                DataColumn(label: Text('Amount', style: TextStyle(color: ZivaTheme.textMuted))),
              ],
              rows: _transactions.map((tx) {
                return DataRow(cells: [
                  DataCell(Text(tx.transactionDate.toIso8601String().split('T')[0], style: const TextStyle(color: ZivaTheme.textPrimary))),
                  DataCell(Text(tx.merchantOrPayee, style: const TextStyle(fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary))),
                  DataCell(Text(tx.accountId, style: const TextStyle(color: ZivaTheme.textMuted))),
                  DataCell(Text(tx.categoryId, style: const TextStyle(color: ZivaTheme.textMuted))),
                  DataCell(Text(tx.transactionType, style: TextStyle(color: tx.transactionType == 'INCOME' ? const Color(0xFF10B981) : const Color(0xFFEF4444)))),
                  DataCell(Text(CurrencyFormatter.format(tx.originalAmount, tx.originalCurrency), style: const TextStyle(fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value, String subtitle, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
              Icon(icon, size: 18, color: accentColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  double _calculateTotalOwedToMe() {
    double total = 0;
    for (var b in _balances) {
      total += (b['totalOwedToMe'] ?? b['total_owed_to_me'] ?? 0).toDouble();
    }
    return total;
  }

  double _calculateTotalOwedByMe() {
    double total = 0;
    for (var b in _balances) {
      total += (b['totalOwedByMe'] ?? b['total_owed_by_me'] ?? 0).toDouble();
    }
    return total;
  }
}
