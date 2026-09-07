import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/ziva_theme.dart';
import '../../../models/envelope_model.dart';
import '../../../services/sqlite_service.dart';

enum AnalyticsPeriod { d30, d90, ytd, custom }
enum ChartMode { netWorth, cashFlow, envelopeRunRate }

class AnalyticsHubSection extends StatefulWidget {
  const AnalyticsHubSection({super.key});

  @override
  State<AnalyticsHubSection> createState() => _AnalyticsHubSectionState();
}

class _AnalyticsHubSectionState extends State<AnalyticsHubSection> {
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.d30;
  ChartMode _chartMode = ChartMode.netWorth;
  String? _selectedEnvelopeId;
  List<EnvelopeModel> _envelopes = [];
  bool _isLoading = true;

  // Hover state for interactive tooltips
  int? _hoveredDataIndex;

  // Custom date range state
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final envelopes = await SqliteService.instance.getEnvelopes();
    if (mounted) {
      setState(() {
        _envelopes = envelopes;
        if (envelopes.isNotEmpty && _selectedEnvelopeId == null) {
          _selectedEnvelopeId = envelopes.first.categoryId;
        }
        _isLoading = false;
      });
    }
  }

  String get _periodLabel {
    switch (_selectedPeriod) {
      case AnalyticsPeriod.d30:
        return 'Last 30 Days';
      case AnalyticsPeriod.d90:
        return 'Last 90 Days';
      case AnalyticsPeriod.ytd:
        return 'Year to Date (2026)';
      case AnalyticsPeriod.custom:
        if (_customDateRange != null) {
          return '${_customDateRange!.start.month}/${_customDateRange!.start.day} - ${_customDateRange!.end.month}/${_customDateRange!.end.day}';
        }
        return 'Custom Range';
    }
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2027, 1, 1),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 60)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: ZivaTheme.gold400,
              onPrimary: Colors.black,
              surface: ZivaTheme.bgSurface,
              onSurface: ZivaTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = AnalyticsPeriod.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 350,
        decoration: BoxDecoration(
          color: ZivaTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZivaTheme.borderCard),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: ZivaTheme.gold400, strokeWidth: 2),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ZivaTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZivaTheme.borderCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Period Filter Controls
          _buildControlHeader(),
          const SizedBox(height: 18),

          // Cash Flow Summary Strip
          _buildCashFlowSummaryBar(),
          const SizedBox(height: 20),

          // Main Interactive Time-Series Canvas
          _buildMainChartContainer(),
          const SizedBox(height: 24),

          const Divider(color: ZivaTheme.borderCard, height: 1),
          const SizedBox(height: 20),

          // Supporting Breakdown Row: Donut Chart & Top 5 Expense Categories
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 850) {
                return Column(
                  children: [
                    _buildDonutBreakdownCard(),
                    const SizedBox(height: 16),
                    _buildTop5ExpensesCard(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildDonutBreakdownCard()),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: _buildTop5ExpensesCard()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ZivaTheme.gold400.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ZivaTheme.gold400.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: ZivaTheme.gold400, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXECUTIVE ANALYTICS & TREND MODELING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ZivaTheme.gold400,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Time-Series Trajectory & Predictive Run-Rates',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ZivaTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Controls Row: Chart Mode Buttons & Period Selectors
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Chart Mode Buttons
                _buildModeTab(ChartMode.netWorth, 'Net Worth', Icons.show_chart_rounded),
                _buildModeTab(ChartMode.cashFlow, 'Cash Flow In/Out', Icons.bar_chart_rounded),
                _buildModeTab(ChartMode.envelopeRunRate, 'Envelope Run-Rate', Icons.speed_rounded),

                if (!isNarrow) const SizedBox(width: 16),

                // Period Pills
                _buildPeriodPill(AnalyticsPeriod.d30, '30D'),
                _buildPeriodPill(AnalyticsPeriod.d90, '90D'),
                _buildPeriodPill(AnalyticsPeriod.ytd, 'YTD'),
                InkWell(
                  onTap: _selectCustomRange,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedPeriod == AnalyticsPeriod.custom ? ZivaTheme.gold400.withValues(alpha: 0.2) : ZivaTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedPeriod == AnalyticsPeriod.custom ? ZivaTheme.gold400 : ZivaTheme.borderCard,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.date_range_rounded,
                          size: 13,
                          color: _selectedPeriod == AnalyticsPeriod.custom ? ZivaTheme.gold400 : ZivaTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedPeriod == AnalyticsPeriod.custom ? _periodLabel : 'Custom',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _selectedPeriod == AnalyticsPeriod.custom ? ZivaTheme.gold400 : ZivaTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeTab(ChartMode mode, String title, IconData icon) {
    final isSelected = _chartMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _chartMode = mode;
          _hoveredDataIndex = null;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? ZivaTheme.gold400 : ZivaTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? ZivaTheme.gold400 : ZivaTheme.borderCard),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.black : ZivaTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.black : ZivaTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodPill(AnalyticsPeriod period, String label) {
    final isSelected = _selectedPeriod == period;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
          _hoveredDataIndex = null;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ZivaTheme.gold400.withValues(alpha: 0.2) : ZivaTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? ZivaTheme.gold400 : ZivaTheme.borderCard),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? ZivaTheme.gold400 : ZivaTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildCashFlowSummaryBar() {
    const income = 195400.0;
    const expenses = 88200.0;
    const netSavings = income - expenses;
    const savingsRate = (netSavings / income) * 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          final items = [
            _buildFlowMetric('TOTAL INFLOWS', 'R ${income.toStringAsFixed(0)}', ZivaTheme.emerald400, Icons.arrow_downward_rounded),
            _buildFlowMetric('TOTAL OUTFLOWS', 'R ${expenses.toStringAsFixed(0)}', ZivaTheme.rose400, Icons.arrow_upward_rounded),
            _buildFlowMetric('NET SAVINGS SURPLUS', 'R ${netSavings.toStringAsFixed(0)}', ZivaTheme.gold400, Icons.savings_rounded),
            _buildFlowMetric('SAVINGS RATE', '${savingsRate.toStringAsFixed(1)}%', ZivaTheme.emerald400, Icons.pie_chart_rounded),
          ];

          if (isNarrow) {
            return Wrap(
              spacing: 16,
              runSpacing: 10,
              children: items.map((i) => SizedBox(width: (constraints.maxWidth - 20) / 2, child: i)).toList(),
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: items.map((i) => Expanded(child: i)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildFlowMetric(String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ZivaTheme.textMuted, letterSpacing: 0.5),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainChartContainer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart Header Info + Optional Envelope Selector
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getChartTitle(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getChartSubtitle(),
                    style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (_chartMode == ChartMode.envelopeRunRate && _envelopes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: ZivaTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ZivaTheme.gold400.withValues(alpha: 0.4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedEnvelopeId,
                    dropdownColor: ZivaTheme.bgSurface,
                    icon: const Icon(Icons.arrow_drop_down, color: ZivaTheme.gold400),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ZivaTheme.textPrimary),
                    items: _envelopes.map((env) {
                      return DropdownMenuItem<String>(
                        value: env.categoryId,
                        child: Row(
                          children: [
                            const Icon(Icons.markunread_mailbox_rounded, size: 14, color: ZivaTheme.gold400),
                            const SizedBox(width: 8),
                            Text('${env.categoryName} (R ${env.currentBalanceZar.toStringAsFixed(0)})'),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedEnvelopeId = val;
                          _hoveredDataIndex = null;
                        });
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Interactive Canvas
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            color: ZivaTheme.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZivaTheme.borderCard),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MouseRegion(
              onHover: (event) {
                final localX = event.localPosition.dx;
                final totalPoints = _getDataPoints().length;
                if (totalPoints > 1) {
                  final fraction = (localX / 700).clamp(0.0, 1.0);
                  final idx = (fraction * (totalPoints - 1)).round().clamp(0, totalPoints - 1);
                  if (idx != _hoveredDataIndex) {
                    setState(() => _hoveredDataIndex = idx);
                  }
                }
              },
              onExit: (_) {
                setState(() => _hoveredDataIndex = null);
              },
              child: CustomPaint(
                painter: _ExecutiveTimeSeriesPainter(
                  mode: _chartMode,
                  points: _getDataPoints(),
                  hoveredIndex: _hoveredDataIndex,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getChartTitle() {
    switch (_chartMode) {
      case ChartMode.netWorth:
        return 'CONSOLIDATED NET WORTH TRAJECTORY';
      case ChartMode.cashFlow:
        return 'CASH FLOW DYNAMICS: INFLOWS VS OUTFLOWS';
      case ChartMode.envelopeRunRate:
        return 'ENVELOPE BURN RATE & ESTIMATED RUNWAY';
    }
  }

  String _getChartSubtitle() {
    switch (_chartMode) {
      case ChartMode.netWorth:
        return 'Liquid Accounts + Asset Equity - Unsettled Debt Obligations (30-day projection)';
      case ChartMode.cashFlow:
        return 'Monthly liquidity velocity and retained surplus across all accounts';
      case ChartMode.envelopeRunRate:
        if (_envelopes.isEmpty) return 'No budget envelopes configured';
        final env = _envelopes.firstWhere((e) => e.categoryId == _selectedEnvelopeId, orElse: () => _envelopes.first);
        final dailyBurn = env.plannedAmountZar / 30.0;
        final daysLeft = dailyBurn > 0 ? (env.currentBalanceZar / dailyBurn).floor() : 0;
        return 'Burn rate: ~R ${dailyBurn.toStringAsFixed(0)}/day • Projected depletion in $daysLeft days';
    }
  }

  List<_DataPoint> _getDataPoints() {
    switch (_chartMode) {
      case ChartMode.netWorth:
        return [
          _DataPoint(label: 'Aug 08', value1: 33800000),
          _DataPoint(label: 'Aug 15', value1: 34100000),
          _DataPoint(label: 'Aug 22', value1: 34050000),
          _DataPoint(label: 'Aug 29', value1: 34600000),
          _DataPoint(label: 'Sep 01', value1: 34950000),
          _DataPoint(label: 'Sep 04', value1: 35120000),
          _DataPoint(label: 'Today', value1: 35245800),
        ];
      case ChartMode.cashFlow:
        return [
          _DataPoint(label: 'Week 1', value1: 52000, value2: 18400),
          _DataPoint(label: 'Week 2', value1: 44000, value2: 26000),
          _DataPoint(label: 'Week 3', value1: 68000, value2: 19500),
          _DataPoint(label: 'Week 4', value1: 31400, value2: 24300),
        ];
      case ChartMode.envelopeRunRate:
        if (_envelopes.isEmpty) {
          return [_DataPoint(label: 'Day 1', value1: 0)];
        }
        final env = _envelopes.firstWhere((e) => e.categoryId == _selectedEnvelopeId, orElse: () => _envelopes.first);
        final start = env.plannedAmountZar;
        final curr = env.currentBalanceZar;
        return [
          _DataPoint(label: 'Day 1', value1: start),
          _DataPoint(label: 'Day 8', value1: start * 0.82),
          _DataPoint(label: 'Day 15', value1: start * 0.65),
          _DataPoint(label: 'Day 22', value1: start * 0.48),
          _DataPoint(label: 'Current', value1: curr),
          _DataPoint(label: 'Projected', value1: math.max(0, curr - (start * 0.2))),
        ];
    }
  }

  Widget _buildDonutBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.donut_large_rounded, color: ZivaTheme.gold400, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ENVELOPE CAPITAL ALLOCATION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ZivaTheme.gold400, letterSpacing: 0.8),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Donut and Legend with responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 280;
              final donutWidget = SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    slices: const [
                      _DonutSlice(value: 40, color: ZivaTheme.gold400),
                      _DonutSlice(value: 25, color: ZivaTheme.emerald400),
                      _DonutSlice(value: 20, color: Colors.blueAccent),
                      _DonutSlice(value: 15, color: Colors.purpleAccent),
                    ],
                  ),
                ),
              );

              final legendWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendRow('Housing & Ops (40%)', ZivaTheme.gold400, 'R 40,000'),
                  const SizedBox(height: 6),
                  _buildLegendRow('Emergency Fund (25%)', ZivaTheme.emerald400, 'R 25,000'),
                  const SizedBox(height: 6),
                  _buildLegendRow('Tax & Retainers (20%)', Colors.blueAccent, 'R 20,000'),
                  const SizedBox(height: 6),
                  _buildLegendRow('Discretionary (15%)', Colors.purpleAccent, 'R 15,000'),
                ],
              );

              if (isVeryNarrow) {
                return Column(
                  children: [
                    Center(child: donutWidget),
                    const SizedBox(height: 12),
                    legendWidget,
                  ],
                );
              }

              return Row(
                children: [
                  donutWidget,
                  const SizedBox(width: 14),
                  Expanded(child: legendWidget),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String title, Color color, String amount) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 11, color: ZivaTheme.textPrimary, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          amount,
          style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildTop5ExpensesCard() {
    const topCategories = [
      {'name': 'Executive Housing & Rates', 'amount': 28500.0, 'pct': 0.32},
      {'name': 'Vehicle Finance & Fleet Ops', 'amount': 18400.0, 'pct': 0.21},
      {'name': 'Business & Software Infrastructure', 'amount': 14200.0, 'pct': 0.16},
      {'name': 'Dining & Executive Lifestyle', 'amount': 11800.0, 'pct': 0.13},
      {'name': 'Healthcare & Medical Aid', 'amount': 9500.0, 'pct': 0.11},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.leaderboard_rounded, color: ZivaTheme.rose400, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TOP 5 EXPENDITURE CATEGORIES',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ZivaTheme.rose400, letterSpacing: 0.8),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Column(
            children: topCategories.map((cat) {
              final pct = cat['pct'] as double;
              final amount = cat['amount'] as double;
              final name = cat['name'] as String;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ZivaTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'R ${amount.toStringAsFixed(0)} (${(pct * 100).toInt()}%)',
                          style: const TextStyle(fontSize: 11, color: ZivaTheme.textMuted, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor: ZivaTheme.borderCard,
                        valueColor: const AlwaysStoppedAnimation<Color>(ZivaTheme.gold400),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DataPoint {
  final String label;
  final double value1;
  final double? value2;

  _DataPoint({required this.label, required this.value1, this.value2});
}

class _ExecutiveTimeSeriesPainter extends CustomPainter {
  final ChartMode mode;
  final List<_DataPoint> points;
  final int? hoveredIndex;

  _ExecutiveTimeSeriesPainter({
    required this.mode,
    required this.points,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const padding = EdgeInsets.only(left: 50, right: 30, top: 30, bottom: 40);
    final chartW = size.width - padding.left - padding.right;
    final chartH = size.height - padding.top - padding.bottom;

    // Determine max value
    double maxVal = 0;
    for (final p in points) {
      if (p.value1 > maxVal) maxVal = p.value1;
      if (p.value2 != null && p.value2! > maxVal) maxVal = p.value2!;
    }
    if (maxVal == 0) maxVal = 1;
    maxVal *= 1.15; // headspace

    // Grid lines
    final gridPaint = Paint()
      ..color = ZivaTheme.borderCard.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const gridSteps = 4;
    for (int i = 0; i <= gridSteps; i++) {
      final y = padding.top + chartH - (i / gridSteps) * chartH;
      canvas.drawLine(Offset(padding.left, y), Offset(size.width - padding.right, y), gridPaint);

      // Y-axis label
      final val = (maxVal * (i / gridSteps));
      final label = val >= 1000000
          ? 'R ${(val / 1000000).toStringAsFixed(1)}M'
          : 'R ${(val / 1000).toStringAsFixed(0)}k';

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(color: ZivaTheme.textMuted.withValues(alpha: 0.7), fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(padding.left - textPainter.width - 8, y - 6));
    }

    if (mode == ChartMode.cashFlow) {
      _paintCashFlowBars(canvas, size, padding, chartW, chartH, maxVal, textPainter);
    } else {
      _paintContinuousLine(canvas, size, padding, chartW, chartH, maxVal, textPainter);
    }
  }

  void _paintCashFlowBars(
    Canvas canvas,
    Size size,
    EdgeInsets padding,
    double chartW,
    double chartH,
    double maxVal,
    TextPainter textPainter,
  ) {
    final groupCount = points.length;
    final groupW = chartW / groupCount;
    final barW = math.min(18.0, groupW * 0.25);

    for (int i = 0; i < groupCount; i++) {
      final p = points[i];
      final centerX = padding.left + i * groupW + groupW / 2;

      // Inflow bar (emerald)
      final h1 = (p.value1 / maxVal) * chartH;
      final rect1 = Rect.fromLTWH(centerX - barW - 2, padding.top + chartH - h1, barW, h1);
      final rrect1 = RRect.fromRectAndRadius(rect1, const Radius.circular(4));
      canvas.drawRRect(rrect1, Paint()..color = ZivaTheme.emerald400);

      // Outflow bar (rose)
      if (p.value2 != null) {
        final h2 = (p.value2! / maxVal) * chartH;
        final rect2 = Rect.fromLTWH(centerX + 2, padding.top + chartH - h2, barW, h2);
        final rrect2 = RRect.fromRectAndRadius(rect2, const Radius.circular(4));
        canvas.drawRRect(rrect2, Paint()..color = ZivaTheme.rose400);
      }

      // X Label
      textPainter.text = TextSpan(
        text: p.label,
        style: const TextStyle(color: ZivaTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, size.height - padding.bottom + 10));

      // Tooltip if hovered
      if (hoveredIndex == i) {
        _drawTooltip(canvas, Offset(centerX, padding.top + 20), [
          'Inflow: R ${p.value1.toStringAsFixed(0)}',
          if (p.value2 != null) 'Outflow: R ${p.value2!.toStringAsFixed(0)}',
        ]);
      }
    }
  }

  void _paintContinuousLine(
    Canvas canvas,
    Size size,
    EdgeInsets padding,
    double chartW,
    double chartH,
    double maxVal,
    TextPainter textPainter,
  ) {
    final count = points.length;
    final stepX = chartW / (count - 1);

    final path = Path();
    final fillPath = Path();

    final linePaint = Paint()
      ..color = ZivaTheme.gold400
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final offsets = <Offset>[];

    for (int i = 0; i < count; i++) {
      final x = padding.left + i * stepX;
      final y = padding.top + chartH - (points[i].value1 / maxVal) * chartH;
      offsets.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, padding.top + chartH);
        fillPath.lineTo(x, y);
      } else {
        // Smooth cubic bezier
        final prev = offsets[i - 1];
        final controlX = (prev.dx + x) / 2;
        path.cubicTo(controlX, prev.dy, controlX, y, x, y);
        fillPath.cubicTo(controlX, prev.dy, controlX, y, x, y);
      }

      // X Label
      textPainter.text = TextSpan(
        text: points[i].label,
        style: TextStyle(
          color: hoveredIndex == i ? ZivaTheme.gold400 : ZivaTheme.textMuted,
          fontSize: 10,
          fontWeight: hoveredIndex == i ? FontWeight.w800 : FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - padding.bottom + 10));
    }

    fillPath.lineTo(offsets.last.dx, padding.top + chartH);
    fillPath.close();

    // Gradient fill under the curve
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        ZivaTheme.gold400.withValues(alpha: 0.25),
        ZivaTheme.gold400.withValues(alpha: 0.0),
      ],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(padding.left, padding.top, chartW, chartH))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Data points & Hover interaction
    for (int i = 0; i < offsets.length; i++) {
      final pt = offsets[i];
      final isHovered = hoveredIndex == i;

      // Glow circle
      canvas.drawCircle(
        pt,
        isHovered ? 7 : 4,
        Paint()..color = isHovered ? ZivaTheme.gold300 : ZivaTheme.gold400,
      );
      canvas.drawCircle(
        pt,
        isHovered ? 4 : 2,
        Paint()..color = Colors.black,
      );

      if (isHovered) {
        _drawTooltip(canvas, pt, [
          points[i].label,
          'R ${points[i].value1.toStringAsFixed(0)}',
        ]);
      }
    }
  }

  void _drawTooltip(Canvas canvas, Offset target, List<String> lines) {
    final tpList = lines.map((line) {
      final tp = TextPainter(
        text: TextSpan(
          text: line,
          style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    }).toList();

    double maxW = 0;
    double totalH = 0;
    for (final tp in tpList) {
      if (tp.width > maxW) maxW = tp.width;
      totalH += tp.height + 2;
    }

    const pad = 8.0;
    final boxW = maxW + pad * 2;
    final boxH = totalH + pad * 2;

    var boxX = target.dx - boxW / 2;
    var boxY = target.dy - boxH - 12;
    if (boxY < 10) boxY = target.dy + 16;

    final boxRect = Rect.fromLTWH(boxX, boxY, boxW, boxH);
    final rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(8));

    canvas.drawRRect(rrect, Paint()..color = ZivaTheme.gold400);

    double currY = boxY + pad;
    for (final tp in tpList) {
      tp.paint(canvas, Offset(boxX + pad, currY));
      currY += tp.height + 2;
    }
  }

  @override
  bool shouldRepaint(covariant _ExecutiveTimeSeriesPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.points != points ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}

class _DonutSlice {
  final double value;
  final Color color;

  const _DonutSlice({required this.value, required this.color});
}

class _DonutChartPainter extends CustomPainter {
  final List<_DonutSlice> slices;

  _DonutChartPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0.0, (sum, s) => sum + s.value);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.45;

    double startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweepAngle = (slice.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - 0.04, // slight slice separator gap
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
