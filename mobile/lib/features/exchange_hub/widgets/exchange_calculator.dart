import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/currency/currency_conversion.dart';
import '../../../core/currency/currency_types.dart';
import '../../../core/theme/ziva_theme.dart';

/// Live Conversion Calculator
///
/// Self-contained currency conversion calculator supporting real-time
/// multi-currency evaluation across USD, ZWG, and ZAR using ExchangeRate-API.
class ExchangeCalculator extends StatefulWidget {
  const ExchangeCalculator({super.key});

  @override
  State<ExchangeCalculator> createState() => _ExchangeCalculatorState();
}

class _ExchangeCalculatorState extends State<ExchangeCalculator> {
  final TextEditingController _amountController = TextEditingController(text: '1000');
  String _fromCurrency = 'USD';
  String _toCurrency = 'ZAR';
  double _convertedValue = 18250.0;
  double _currentRate = 18.25;
  bool _isReversing = false;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final rawAmount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    final converted = convertAmount(
      amount: rawAmount,
      fromCurrency: _fromCurrency,
      toCurrency: _toCurrency,
    );
    final unitRate = convertAmount(
      amount: 1.0,
      fromCurrency: _fromCurrency,
      toCurrency: _toCurrency,
    );

    setState(() {
      _convertedValue = converted;
      _currentRate = unitRate;
    });
  }

  void _swapCurrencies() {
    setState(() {
      _isReversing = true;
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
    });
    _recalculate();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _isReversing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formattedResult = formatter.format(_convertedValue);
    final fromSymbol = getCurrencySymbol(_fromCurrency);
    final toSymbol = getCurrencySymbol(_toCurrency);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZivaTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZivaTheme.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                child: const Icon(Icons.calculate_rounded, color: ZivaTheme.gold400, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Conversion Calculator',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ZivaTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Real-time forex pricing via ExchangeRate-API',
                      style: TextStyle(fontSize: 10, color: ZivaTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Amount Input Field
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: ZivaTheme.textPrimary,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              labelText: 'Amount to Convert',
              prefixText: '$fromSymbol ',
              prefixStyle: const TextStyle(
                color: ZivaTheme.gold400,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: ZivaTheme.borderCard),
              ),
              filled: true,
              fillColor: ZivaTheme.bgCore,
            ),
            onChanged: (_) => _recalculate(),
          ),

          const SizedBox(height: 14),

          // Currency Dropdowns & Swap Button
          Row(
            children: [
              // From Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('from_$_fromCurrency'),
                  initialValue: _fromCurrency,
                  decoration: const InputDecoration(labelText: 'From Currency'),
                  dropdownColor: ZivaTheme.bgCard,
                  items: supportedCurrencies.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _fromCurrency = val);
                      _recalculate();
                    }
                  },
                ),
              ),

              // Swap Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: AnimatedRotation(
                  turns: _isReversing ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IconButton.filledTonal(
                    onPressed: _swapCurrencies,
                    icon: const Icon(Icons.swap_horiz_rounded, color: ZivaTheme.gold400),
                    style: IconButton.styleFrom(
                      backgroundColor: ZivaTheme.bgCore,
                      side: const BorderSide(color: ZivaTheme.borderCard),
                    ),
                    tooltip: 'Swap Currencies',
                  ),
                ),
              ),

              // To Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('to_$_toCurrency'),
                  initialValue: _toCurrency,
                  decoration: const InputDecoration(labelText: 'To Currency'),
                  dropdownColor: ZivaTheme.bgCard,
                  items: supportedCurrencies.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _toCurrency = val);
                      _recalculate();
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Result Callout Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ZivaTheme.gold500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZivaTheme.gold500.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONVERTED VALUE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: ZivaTheme.gold400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$toSymbol$formattedResult',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: ZivaTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '1 $_fromCurrency = ${_currentRate.toStringAsFixed(4)} $_toCurrency • Live Interbank Baseline',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ZivaTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
