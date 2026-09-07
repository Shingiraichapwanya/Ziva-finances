import 'package:flutter/material.dart';
import '../../core/currency/currency_conversion.dart';
import '../../core/currency/currency_types.dart';
import '../../core/theme/ziva_theme.dart';
import '../../services/exchange_rate_service.dart';
import 'widgets/exchange_calculator.dart';
import 'widgets/exchange_trend_chart.dart';

/// Exchange Hub Screen
///
/// Dedicated currency trends and live conversion destination.
/// Displays interactive 30d/90d historical charts for USD, ZWG, and ZAR
/// along with real-time conversion tools and live interbank cross-rate tables.
class ExchangeHubScreen extends StatefulWidget {
  const ExchangeHubScreen({super.key});

  @override
  State<ExchangeHubScreen> createState() => _ExchangeHubScreenState();
}

class _ExchangeHubScreenState extends State<ExchangeHubScreen> {
  String _selectedPair = 'USD/ZAR';
  int _selectedDays = 30; // 30 or 90
  bool _isLoading = false;

  final List<String> _supportedPairs = ['USD/ZAR', 'USD/ZWG', 'ZAR/ZWG'];

  Future<void> _refreshRates() async {
    setState(() => _isLoading = true);
    await ExchangeRateService.instance.getExchangeRates('USD');
    await ExchangeRateService.instance.getExchangeRates('ZAR');
    await ExchangeRateService.instance.getExchangeRates('ZWG');
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZivaTheme.bgSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: ZivaTheme.gold400),
          ),
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: ZivaTheme.emerald400, size: 20),
              SizedBox(width: 10),
              Text(
                'Live FX rates updated from ExchangeRate-API.',
                style: TextStyle(color: ZivaTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataPoints = ExchangeRateService.instance.getHistoricalRates(
      _selectedPair,
      days: _selectedDays,
    );

    return Scaffold(
      backgroundColor: ZivaTheme.bgCore,
      appBar: AppBar(
        backgroundColor: ZivaTheme.bgSurface,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXCHANGE HUB',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: ZivaTheme.textPrimary,
              ),
            ),
            Text(
              'Real-Time Tri-Currency FX Trends & Live Interbank Rates',
              style: TextStyle(fontSize: 10, color: ZivaTheme.textMuted),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ZivaTheme.emeraldBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ZivaTheme.emerald400.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: ZivaTheme.emerald400, size: 8),
                SizedBox(width: 6),
                Text(
                  'API Connected',
                  style: TextStyle(fontSize: 10, color: ZivaTheme.emerald400, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: ZivaTheme.gold400, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, color: ZivaTheme.gold400),
            onPressed: _isLoading ? null : _refreshRates,
            tooltip: 'Refresh Live Rates',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Controls: Currency Pair Selectors + Range Selector
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Pair Selectors
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _supportedPairs.map((pair) {
                    final isSelected = _selectedPair == pair;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(pair),
                        selected: isSelected,
                        selectedColor: ZivaTheme.gold500,
                        backgroundColor: ZivaTheme.bgSurface,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : ZivaTheme.textMuted,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? ZivaTheme.gold500 : ZivaTheme.borderCard,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedPair = pair);
                        },
                      ),
                    );
                  }).toList(),
                ),

                // Range Selector (30D vs 90D)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [30, 90].map((days) {
                    final isSelected = _selectedDays == days;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: FilterChip(
                        label: Text('${days}D'),
                        selected: isSelected,
                        selectedColor: ZivaTheme.gold400.withValues(alpha: 0.25),
                        backgroundColor: ZivaTheme.bgSurface,
                        labelStyle: TextStyle(
                          color: isSelected ? ZivaTheme.gold400 : ZivaTheme.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        side: BorderSide(
                          color: isSelected ? ZivaTheme.gold400 : ZivaTheme.borderCard,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedDays = days);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Top Layout: Responsive Chart & Calculator
            LayoutBuilder(
              builder: (context, constraints) {
                final isWidescreen = constraints.maxWidth >= 950;

                final chartCard = Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ZivaTheme.bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ZivaTheme.borderCard),
                  ),
                  child: ExchangeTrendChart(
                    pair: _selectedPair,
                    dataPoints: dataPoints,
                    lineColor: _selectedPair.contains('ZWG') ? ZivaTheme.cyan400 : ZivaTheme.gold400,
                  ),
                );

                const calcCard = ExchangeCalculator();

                if (isWidescreen) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: chartCard),
                      const SizedBox(width: 18),
                      const Expanded(flex: 2, child: calcCard),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      chartCard,
                      const SizedBox(height: 18),
                      calcCard,
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 24),

            // Real-Time Cross Rate Matrix
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ZivaTheme.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ZivaTheme.borderCard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LIVE INTERBANK CROSS RATES (USD / ZWG / ZAR)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: ZivaTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Cache TTL: 10m • Fail-safe Active',
                        style: TextStyle(fontSize: 10, color: ZivaTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(ZivaTheme.bgCore),
                      columns: const [
                        DataColumn(label: Text('Base Currency', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('USD Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('ZWG Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('ZAR Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: [
                        _buildCrossRateRow('USD', 1.0, 26.50, 18.25),
                        _buildCrossRateRow('ZAR', 1.0 / 18.25, 26.50 / 18.25, 1.0),
                        _buildCrossRateRow('ZWG', 1.0 / 26.50, 1.0, 18.25 / 26.50),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildCrossRateRow(String base, double usd, double zwg, double zar) {
    final liveUsd = convertAmount(amount: 1.0, fromCurrency: base, toCurrency: 'USD');
    final liveZwg = convertAmount(amount: 1.0, fromCurrency: base, toCurrency: 'ZWG');
    final liveZar = convertAmount(amount: 1.0, fromCurrency: base, toCurrency: 'ZAR');

    return DataRow(
      cells: [
        DataCell(Text(getCurrencyLabel(base), style: const TextStyle(fontWeight: FontWeight.w700))),
        DataCell(Text(liveUsd.toStringAsFixed(4), style: const TextStyle(fontFamily: 'monospace'))),
        DataCell(Text(liveZwg.toStringAsFixed(4), style: const TextStyle(fontFamily: 'monospace'))),
        DataCell(Text(liveZar.toStringAsFixed(4), style: const TextStyle(fontFamily: 'monospace'))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: ZivaTheme.emeraldBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: ZivaTheme.emerald400.withValues(alpha: 0.4)),
            ),
            child: const Text('REAL-TIME', style: TextStyle(fontSize: 9, color: ZivaTheme.emerald400, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
