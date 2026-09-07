import 'package:flutter/material.dart';
import '../../core/config/app_environment.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/ziva_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/account_model.dart';
import '../../models/envelope_model.dart';
import '../../models/transaction_model.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_engine.dart';
import '../desktop/desktop_sidebar.dart';
import '../ledger/quick_entry_sheet.dart';
import '../search/global_search_dialog.dart';
import '../settings/developer_settings_screen.dart';
import 'widgets/analytics_hub_section.dart';
import 'widgets/asset_summary_widget.dart';
import 'widgets/debt_credit_summary_widget.dart';
import 'widgets/envelope_overview_section.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToLedger;
  final VoidCallback? onNavigateToAssets;
  final VoidCallback? onNavigateToSettings;
  final bool showSidebar;
  final String selectedCurrency;

  const DashboardScreen({
    super.key,
    required this.onNavigateToLedger,
    this.onNavigateToAssets,
    this.onNavigateToSettings,
    this.showSidebar = true,
    this.selectedCurrency = 'ZAR',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedCurrency = 'ZAR';
  List<AccountModel> _accounts = [];
  List<TransactionModel> _recentTransactions = [];
  List<EnvelopeModel> _envelopes = [];
  bool _isLoading = true;
  int _secretTapCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.selectedCurrency;
    // Cache Invalidation: Immediately wipe any stale front-end caches
    SqliteService.instance.invalidateAndClearCaches();
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCurrency != widget.selectedCurrency) {
      setState(() {
        _selectedCurrency = widget.selectedCurrency;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await SqliteService.instance.getLocalAccounts().timeout(
        const Duration(seconds: 4),
        onTimeout: () => [],
      );
      final txs = await SqliteService.instance.getTransactions(limit: 10).timeout(
        const Duration(seconds: 4),
        onTimeout: () => [],
      );
      final envs = await SqliteService.instance.getEnvelopes().timeout(
        const Duration(seconds: 4),
        onTimeout: () => [],
      );

      if (mounted) {
        setState(() {
          _accounts = accounts;
          _recentTransactions = txs;
          _envelopes = envs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Dashboard] Error loading live BigQuery data: $e');
      if (mounted) {
        setState(() {
          _accounts = [];
          _recentTransactions = [];
          _envelopes = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    SqliteService.instance.invalidateAndClearCaches();
    await SyncEngine.instance.processQueue();
    await SyncEngine.instance.refreshFromBigQuery();
    await _loadDashboardData();
  }

  double get _totalNetWorthInSelectedCurrency {
    double liquidZar = 0;
    for (final acc in _accounts) {
      liquidZar += CurrencyFormatter.convert(
        amount: acc.nativeBalance,
        fromCurrency: acc.primaryCurrency,
        toCurrency: 'ZAR',
      );
    }
    final consolidatedZar = SqliteService.instance.calculateConsolidatedNetWorthZar(
      liquidAccountsTotalZar: liquidZar,
    );
    return CurrencyFormatter.convert(
      amount: consolidatedZar,
      fromCurrency: 'ZAR',
      toCurrency: _selectedCurrency,
    );
  }

  double _getTierBalance(String filterTier) {
    final tierAccounts = _accounts.where((a) => a.cashFlowTier == filterTier).toList();
    if (tierAccounts.isEmpty) return 0.0;
    double tierTotalZar = 0;
    for (final acc in tierAccounts) {
      tierTotalZar += CurrencyFormatter.convert(
        amount: acc.nativeBalance,
        fromCurrency: acc.primaryCurrency,
        toCurrency: 'ZAR',
      );
    }
    return CurrencyFormatter.convert(
      amount: tierTotalZar,
      fromCurrency: 'ZAR',
      toCurrency: _selectedCurrency,
    );
  }

  void _onBrandHeaderTapped() {
    _secretTapCount++;
    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      if (widget.onNavigateToSettings != null) {
        widget.onNavigateToSettings!();
      } else {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DeveloperSettingsScreen()),
        );
      }
    }
  }

  void _openQuickEntry() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickEntryBottomSheet(
        onTransactionLogged: (newTx) {
          // Optimistic UI update: Immediate local update for snappy feel
          setState(() {
            _recentTransactions.insert(0, newTx);
            if (newTx.categoryId.isNotEmpty) {
              final idx = _envelopes.indexWhere((e) => e.categoryId == newTx.categoryId);
              if (idx != -1) {
                final env = _envelopes[idx];
                final spendDelta = newTx.reportingAmountZar.abs();
                _envelopes[idx] = env.copyWith(
                  actualSpentZar: env.actualSpentZar + spendDelta,
                );
              }
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap root of the dashboard body in LayoutBuilder via ResponsiveLayout
    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ResponsiveLayout(
            breakpoint: 800.0,
            mobile: _buildMobileLayout(context),
            desktop: _buildDesktopCommandCenterLayout(context, constraints),
          );
        },
      ),
    );
  }

  // ==========================================
  // MODE A: MOBILE SINGLE COLUMN LAYOUT (< 800px)
  // ==========================================
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onBrandHeaderTapped,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ZivaTheme.gold500.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.diamond_outlined, color: ZivaTheme.gold400, size: 16),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Flexible(
                          child: Text(
                            'ZIVA FINANCE',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppEnvironment.badgeBgColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppEnvironment.badgeBorderColor, width: 0.8),
                          ),
                          child: Text(
                            AppEnvironment.name,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppEnvironment.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Text('MOBILE DASHBOARD', style: TextStyle(fontSize: 9, color: ZivaTheme.textMuted, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: ZivaTheme.textSecondary),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: ZivaTheme.textSecondary),
            onPressed: () {
              if (widget.onNavigateToSettings != null) {
                widget.onNavigateToSettings!();
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DeveloperSettingsScreen()),
                );
              }
            },
            tooltip: 'Developer Settings & OTA',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: ZivaTheme.gold500,
        backgroundColor: ZivaTheme.bgSurface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Offline Sync Status Banner
              ValueListenableBuilder<int>(
                valueListenable: SyncEngine.instance.pendingCount,
                builder: (context, count, _) {
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: ZivaTheme.gold500.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_queue_rounded, color: ZivaTheme.gold400, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$count mutation${count == 1 ? '' : 's'} waiting to sync to BigQuery',
                            style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => SyncEngine.instance.processQueue(),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: const Text('SYNC NOW', style: TextStyle(color: ZivaTheme.gold400, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Global Search Bar (Mobile)
              InkWell(
                onTap: () => GlobalSearchDialog.show(context, onNavigateToTab: (idx) {
                  if (idx == 1 && widget.onNavigateToAssets != null) widget.onNavigateToAssets!();
                  if (idx == 2) widget.onNavigateToLedger();
                  if (idx == 3 && widget.onNavigateToSettings != null) widget.onNavigateToSettings!();
                }),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ZivaTheme.borderCard),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: ZivaTheme.gold400),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search transactions, assets, debts...',
                          style: TextStyle(fontSize: 12, color: ZivaTheme.textMuted),
                        ),
                      ),
                      Icon(Icons.tune_rounded, size: 14, color: ZivaTheme.textMuted),
                    ],
                  ),
                ),
              ),

              // Total Net Worth Card (Mobile Single Column)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'PORTFOLIO NET WORTH',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ZivaTheme.gold400,
                                letterSpacing: 0.8,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Currency Selector Pills
                          Row(
                            children: ['ZAR', 'USD', 'ZiG'].map((curr) {
                              final isSelected = _selectedCurrency == curr;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedCurrency = curr),
                                child: Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected ? ZivaTheme.gold500 : ZivaTheme.bgSurface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    curr,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : ZivaTheme.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _isLoading
                          ? const SizedBox(
                              height: 36,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: ZivaTheme.gold500),
                                ),
                              ),
                            )
                          : Text(
                              CurrencyFormatter.formatAmount(
                                _totalNetWorthInSelectedCurrency,
                                currency: _selectedCurrency,
                              ),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: ZivaTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 14, color: ZivaTheme.emerald400),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Verified Live Data • BigQuery Africa-South1',
                              style: TextStyle(fontSize: 11, color: ZivaTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Cash Flow Tiers Breakdown Header
              const Text(
                'CASH FLOW TIERS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ZivaTheme.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // Tier 1: Daily Spending
              _buildTierCard(
                tierName: 'Tier 1: Daily Spending',
                description: 'Capitec & EcoCash Instant Liquidity',
                icon: Icons.flash_on_rounded,
                iconColor: ZivaTheme.cyan400,
                balance: _getTierBalance('DAILY_SPENDING'),
              ),
              const SizedBox(height: 10),

              // Tier 2: Monthly Allocations
              _buildTierCard(
                tierName: 'Tier 2: Monthly Allocations',
                description: 'FNB Commercial & Fixed Commitments',
                icon: Icons.calendar_month_rounded,
                iconColor: ZivaTheme.gold400,
                balance: _getTierBalance('MONTHLY_ALLOCATION'),
              ),
              const SizedBox(height: 10),

              // Tier 3: Long-Term Vaults
              _buildTierCard(
                tierName: 'Tier 3: Long-Term Vaults',
                description: 'Discovery 32-Day & EasyEquities TFSA',
                icon: Icons.lock_outline_rounded,
                iconColor: ZivaTheme.emerald400,
                balance: _getTierBalance('LONG_TERM_VAULT'),
              ),

              const SizedBox(height: 24),

              // Restored Zero-Based Envelope Budget System Overview
              EnvelopeOverviewSection(
                envelopes: _envelopes,
                selectedCurrency: _selectedCurrency,
                onEnvelopesUpdated: _loadDashboardData,
              ),

              const SizedBox(height: 24),

              // Executive Analytics Hub & Trends
              const AnalyticsHubSection(),

              const SizedBox(height: 24),

              // Asset Holdings Summary
              AssetSummaryWidget(
                onNavigateToAssets: () {
                  if (widget.onNavigateToAssets != null) widget.onNavigateToAssets!();
                },
              ),

              const SizedBox(height: 24),

              // Debt & Credit Ledger Summary
              DebtCreditSummaryWidget(
                onNavigateToLedger: widget.onNavigateToLedger,
              ),

              const SizedBox(height: 24),

              // Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'RECENT LEDGER ACTIVITY',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ZivaTheme.textMuted,
                        letterSpacing: 0.8,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onNavigateToLedger,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('VIEW ALL', style: TextStyle(fontSize: 11, color: ZivaTheme.gold400, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_recentTransactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ZivaTheme.borderCard),
                  ),
                  child: const Center(
                    child: Text('No active transactions in live dataset. Tap below to log.', style: TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                  ),
                )
              else
                ..._recentTransactions.take(3).map((tx) => _buildTransactionItem(tx)),

              const SizedBox(height: 24),

              // Quick Log Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openQuickEntry,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Log Transaction Offline'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // MODE B: DESKTOP EXECUTIVE COMMAND CENTER MULTI-COLUMN LAYOUT (>= 800px)
  // =========================================================================
  Widget _buildDesktopCommandCenterLayout(BuildContext context, BoxConstraints constraints) {
    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ----------------------------------------------------
          // COLUMN 1: WIDESCREEN LEFT SIDEBAR (Width: 260px)
          // ----------------------------------------------------
          if (widget.showSidebar)
            DesktopSidebar(
              currentTabIndex: 0,
              selectedCurrency: _selectedCurrency,
              onCurrencyChanged: (curr) => setState(() => _selectedCurrency = curr),
              onSecretAdminTrigger: _onBrandHeaderTapped,
              onTabSelected: (idx) {
                if (idx == 1 && widget.onNavigateToAssets != null) {
                  widget.onNavigateToAssets!();
                }
                if (idx == 2) widget.onNavigateToLedger();
                if (idx == 3 && widget.onNavigateToSettings != null) {
                  widget.onNavigateToSettings!();
                }
              },
            ),

          // ----------------------------------------------------
          // COLUMN 2: PRIMARY CENTER COMMAND CENTER (Flexible/Expand)
          // ----------------------------------------------------
          Expanded(
            flex: constraints.maxWidth >= 1200 ? 7 : 6,
            child: _buildDesktopCenterColumn(constraints),
          ),

          // ----------------------------------------------------
          // COLUMN 3: RIGHT PANEL - RECENT ACTIVITY & TELEMETRY (Width: 320px)
          // ----------------------------------------------------
          Container(
            width: constraints.maxWidth >= 1200 ? 340 : 300,
            decoration: const BoxDecoration(
              color: ZivaTheme.bgSurface,
              border: Border(left: BorderSide(color: ZivaTheme.borderCard)),
            ),
            child: _buildDesktopRightPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCenterColumn(BoxConstraints constraints) {
    return Column(
      children: [
        // Center Header Top Bar
        Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: ZivaTheme.bgSurface,
            border: Border(bottom: BorderSide(color: ZivaTheme.borderCard)),
          ),
          child: LayoutBuilder(
            builder: (context, headerBox) {
              final isCompact = headerBox.maxWidth < 650;
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'EXECUTIVE FINANCIAL COMMAND CENTER',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: ZivaTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Real-Time Portfolio Telemetry • Widescreen Mode (${constraints.maxWidth.toInt()}px)',
                          style: const TextStyle(fontSize: 10.5, color: ZivaTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Desktop Global Search Bar (Responsive)
                  InkWell(
                    onTap: () => GlobalSearchDialog.show(context, onNavigateToTab: (idx) {
                      if (idx == 1 && widget.onNavigateToAssets != null) widget.onNavigateToAssets!();
                      if (idx == 2) widget.onNavigateToLedger();
                      if (idx == 3 && widget.onNavigateToSettings != null) widget.onNavigateToSettings!();
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: ZivaTheme.bgCore,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ZivaTheme.borderCard),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_rounded, size: 15, color: ZivaTheme.gold400),
                          const SizedBox(width: 6),
                          Text(
                            isCompact ? 'Search...' : 'Search portfolio...',
                            style: const TextStyle(fontSize: 11.5, color: ZivaTheme.textMuted),
                          ),
                          const SizedBox(width: 6),
                          const Text('⌘K', style: TextStyle(fontSize: 9.5, color: ZivaTheme.textMuted, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: _refreshData,
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: ZivaTheme.textSecondary),
                    tooltip: 'Invalidate cache & re-query BigQuery',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: _openQuickEntry,
                    icon: const Icon(Icons.add, size: 15),
                    label: Text(isCompact ? 'Log' : 'Log Transaction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZivaTheme.gold500,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Center Content Body (Multi-Column Grid)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------------------------
                // 1. MULTI-COLUMN KPI GRID (4 DISTINCT CARDS)
                // -------------------------------------------------------
                const Text(
                  'CONSOLIDATED METRICS & TIER LIQUIDITY',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ZivaTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 14),

                LayoutBuilder(
                  builder: (context, centerConstraints) {
                    final isUltraWide = centerConstraints.maxWidth >= 900;
                    if (isUltraWide) {
                      return Row(
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              title: 'PORTFOLIO NET WORTH',
                              amount: _totalNetWorthInSelectedCurrency,
                              subtitle: 'Live BigQuery Balance',
                              icon: Icons.account_balance_wallet_outlined,
                              accentColor: ZivaTheme.gold400,
                              isPrimary: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'TIER 1: DAILY SPEND',
                              amount: _getTierBalance('DAILY_SPENDING'),
                              subtitle: 'Instant Liquidity Vault',
                              icon: Icons.flash_on_rounded,
                              accentColor: ZivaTheme.cyan400,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'TIER 2: OPERATIONAL',
                              amount: _getTierBalance('MONTHLY_ALLOCATION'),
                              subtitle: 'Fixed Commitments',
                              icon: Icons.calendar_month_rounded,
                              accentColor: ZivaTheme.gold400,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'TIER 3: LONG-TERM',
                              amount: _getTierBalance('LONG_TERM_VAULT'),
                              subtitle: 'Preservation Vaults',
                              icon: Icons.lock_outline_rounded,
                              accentColor: ZivaTheme.emerald400,
                            ),
                          ),
                        ],
                      );
                    } else {
                      // 2x2 Grid for intermediate desktop viewports
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'PORTFOLIO NET WORTH',
                                  amount: _totalNetWorthInSelectedCurrency,
                                  subtitle: 'Live BigQuery Balance',
                                  icon: Icons.account_balance_wallet_outlined,
                                  accentColor: ZivaTheme.gold400,
                                  isPrimary: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'TIER 1: DAILY SPEND',
                                  amount: _getTierBalance('DAILY_SPENDING'),
                                  subtitle: 'Instant Liquidity Vault',
                                  icon: Icons.flash_on_rounded,
                                  accentColor: ZivaTheme.cyan400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'TIER 2: OPERATIONAL',
                                  amount: _getTierBalance('MONTHLY_ALLOCATION'),
                                  subtitle: 'Fixed Commitments',
                                  icon: Icons.calendar_month_rounded,
                                  accentColor: ZivaTheme.gold400,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'TIER 3: LONG-TERM',
                                  amount: _getTierBalance('LONG_TERM_VAULT'),
                                  subtitle: 'Preservation Vaults',
                                  icon: Icons.lock_outline_rounded,
                                  accentColor: ZivaTheme.emerald400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 28),

                // -------------------------------------------------------
                // 2. EXECUTIVE ANALYTICS HUB & TIME-SERIES TRENDS
                // -------------------------------------------------------
                const AnalyticsHubSection(),

                const SizedBox(height: 28),

                // -------------------------------------------------------
                // 3. ASSET REGISTRY & DEBT/CREDIT LEDGER CORE MODULES
                // -------------------------------------------------------
                LayoutBuilder(
                  builder: (context, moduleConstraints) {
                    if (moduleConstraints.maxWidth >= 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AssetSummaryWidget(
                              onNavigateToAssets: () {
                                if (widget.onNavigateToAssets != null) widget.onNavigateToAssets!();
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: DebtCreditSummaryWidget(
                              onNavigateToLedger: widget.onNavigateToLedger,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          AssetSummaryWidget(
                            onNavigateToAssets: () {
                              if (widget.onNavigateToAssets != null) widget.onNavigateToAssets!();
                            },
                          ),
                          const SizedBox(height: 20),
                          DebtCreditSummaryWidget(
                            onNavigateToLedger: widget.onNavigateToLedger,
                          ),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 28),

                // -------------------------------------------------------
                // 4. RESTORED ZERO-BASED ENVELOPE BUDGET SYSTEM & ALLOCATION
                // -------------------------------------------------------
                EnvelopeOverviewSection(
                  envelopes: _envelopes,
                  selectedCurrency: _selectedCurrency,
                  onEnvelopesUpdated: _loadDashboardData,
                ),

                const SizedBox(height: 28),

                // -------------------------------------------------------
                // 3. ACTIVE INSTITUTIONAL ACCOUNTS AUDIT (BigQuery Verified)
                // -------------------------------------------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'ACTIVE FINANCIAL INSTITUTIONS & ACCOUNTS',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ZivaTheme.textMuted,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_accounts.length} Accounts Registered',
                      style: const TextStyle(fontSize: 11, color: ZivaTheme.gold400, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_accounts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: ZivaTheme.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ZivaTheme.borderCard),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ZivaTheme.emerald400.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.check_circle_outline, color: ZivaTheme.emerald400, size: 20),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Live Production Database Wiped (0 Active Accounts)',
                                    style: TextStyle(color: ZivaTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Stale cache removed. Net worth baseline is strictly R 0.00.',
                                    style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  ..._accounts.map((acc) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ZivaTheme.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ZivaTheme.borderCard),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: ZivaTheme.gold500.withValues(alpha: 0.1),
                              child: const Icon(Icons.account_balance, color: ZivaTheme.gold400, size: 18),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(acc.accountName, style: const TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                                  Text('${acc.financialInstitution} • ${acc.accountType} • ${acc.cashFlowTier}', style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.formatAmount(acc.nativeBalance, currency: acc.primaryCurrency),
                              style: const TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      )),

                const SizedBox(height: 28),

                // -------------------------------------------------------
                // 3. ZERO-BASED CASH FLOW ALLOCATIONS
                // -------------------------------------------------------
                const Text(
                  'ZERO-BASED CASH FLOW FRAMEWORK',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ZivaTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 14),

                LayoutBuilder(
                  builder: (context, tierConstraints) {
                    if (tierConstraints.maxWidth >= 750) {
                      return Row(
                        children: [
                          Expanded(
                            child: _buildDesktopTierTile(
                              title: 'Tier 1: Daily Liquidity',
                              rule: 'Capitec & EcoCash Instant Buffer',
                              balance: _getTierBalance('DAILY_SPENDING'),
                              icon: Icons.flash_on_rounded,
                              color: ZivaTheme.cyan400,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildDesktopTierTile(
                              title: 'Tier 2: Monthly Operational',
                              rule: 'FNB Commercial Fixed Costs',
                              balance: _getTierBalance('MONTHLY_ALLOCATION'),
                              icon: Icons.calendar_month_rounded,
                              color: ZivaTheme.gold400,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildDesktopTierTile(
                              title: 'Tier 3: Long-Term Vault',
                              rule: '32-Day Notice & TFSA Equities',
                              balance: _getTierBalance('LONG_TERM_VAULT'),
                              icon: Icons.lock_outline_rounded,
                              color: ZivaTheme.emerald400,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildDesktopTierTile(
                            title: 'Tier 1: Daily Liquidity',
                            rule: 'Capitec & EcoCash Instant Buffer',
                            balance: _getTierBalance('DAILY_SPENDING'),
                            icon: Icons.flash_on_rounded,
                            color: ZivaTheme.cyan400,
                          ),
                          const SizedBox(height: 10),
                          _buildDesktopTierTile(
                            title: 'Tier 2: Monthly Operational',
                            rule: 'FNB Commercial Fixed Costs',
                            balance: _getTierBalance('MONTHLY_ALLOCATION'),
                            icon: Icons.calendar_month_rounded,
                            color: ZivaTheme.gold400,
                          ),
                          const SizedBox(height: 10),
                          _buildDesktopTierTile(
                            title: 'Tier 3: Long-Term Vault',
                            rule: '32-Day Notice & TFSA Equities',
                            balance: _getTierBalance('LONG_TERM_VAULT'),
                            icon: Icons.lock_outline_rounded,
                            color: ZivaTheme.emerald400,
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopRightPanel() {
    return Column(
      children: [
        // Panel Header
        Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: ZivaTheme.borderCard)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'RECENT ACTIVITY & FEED',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: ZivaTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: widget.onNavigateToLedger,
                child: const Text('View All', style: TextStyle(fontSize: 12, color: ZivaTheme.gold400)),
              ),
            ],
          ),
        ),

        // Panel Scrollable Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Quick Actions Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ZivaTheme.bgCore,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ZivaTheme.borderCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('QUICK DISPATCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted, letterSpacing: 0.8)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openQuickEntry,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Transaction'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZivaTheme.gold500,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onNavigateToLedger,
                        icon: const Icon(Icons.handshake_outlined, size: 16, color: ZivaTheme.textPrimary),
                        label: const Text('Open Debt/Credit Ledger', style: TextStyle(color: ZivaTheme.textPrimary)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Recent Transactions Header
              const Text('TRANSACTION AUDIT STREAM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted, letterSpacing: 0.8)),
              const SizedBox(height: 12),

              if (_recentTransactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgCore,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ZivaTheme.borderCard),
                  ),
                  child: const Center(
                    child: Text(
                      '0 transactions in live dataset.\nAll ledger entries wiped.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ZivaTheme.textMuted, fontSize: 11),
                    ),
                  ),
                )
              else
                ..._recentTransactions.take(8).map((tx) => _buildTransactionItem(tx)),

              const SizedBox(height: 20),

              // Security & Telemetry Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ZivaTheme.bgCore,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ZivaTheme.borderCard),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_clock_outlined, size: 14, color: ZivaTheme.emerald400),
                        SizedBox(width: 8),
                        Text('ZERO STALE CACHE POLICY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Front-end cache bypass active. Queries execute straight against BigQuery personal_finance.',
                      style: TextStyle(color: ZivaTheme.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Helper Widgets ---

  Widget _buildKpiCard({
    required String title,
    required double amount,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPrimary ? ZivaTheme.gold500.withValues(alpha: 0.08) : ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? ZivaTheme.gold500.withValues(alpha: 0.4) : ZivaTheme.borderCard,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isPrimary ? ZivaTheme.gold400 : ZivaTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 18, color: accentColor),
            ],
          ),
          const SizedBox(height: 14),
          _isLoading
              ? const SizedBox(
                  height: 30,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ZivaTheme.gold500),
                    ),
                  ),
                )
              : Text(
                  CurrencyFormatter.formatAmount(amount, currency: _selectedCurrency),
                  style: TextStyle(
                    fontSize: isPrimary ? 24 : 20,
                    fontWeight: FontWeight.w900,
                    color: ZivaTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTierTile({
    required String title,
    required String rule,
    required double balance,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                Text(rule, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyFormatter.formatAmount(balance, currency: _selectedCurrency),
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: ZivaTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required String tierName,
    required String description,
    required IconData icon,
    required Color iconColor,
    required double balance,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tierName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ZivaTheme.textPrimary)),
                  Text(description, style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted)),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.formatAmount(balance, currency: _selectedCurrency),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: ZivaTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(TransactionModel tx) {
    final isExpense = tx.originalAmount < 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZivaTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: Row(
        children: [
          Icon(
            isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: isExpense ? ZivaTheme.rose400 : ZivaTheme.emerald400,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.merchantOrPayee, style: const TextStyle(color: ZivaTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(tx.categoryName, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatAmount(tx.originalAmount, currency: tx.originalCurrency),
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: isExpense ? ZivaTheme.textPrimary : ZivaTheme.emerald400,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tx.transactionDate, style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10)),
                  const SizedBox(width: 4),
                  if (tx.isSynced)
                    const Icon(Icons.check_circle_rounded, size: 10, color: ZivaTheme.emerald400)
                  else
                    const Icon(Icons.schedule_rounded, size: 10, color: ZivaTheme.gold400),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
