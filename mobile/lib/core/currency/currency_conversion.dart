import '../../services/exchange_rate_service.dart';
import 'currency_types.dart';

/// Pure Currency Conversion Helper
///
/// Converts a monetary value between any two supported currencies
/// using provided exchange rates or the latest cached rates from ExchangeRateService.
/// Never modifies source stored values.
double convertAmount({
  required double amount,
  required String fromCurrency,
  required String toCurrency,
  Map<String, double>? exchangeRates,
}) {
  if (amount == 0.0) return 0.0;

  final from = getEffectiveCurrencyCode(fromCurrency);
  final to = getEffectiveCurrencyCode(toCurrency);

  if (from == to) return amount;

  // 1. If explicit rates for `from` base are passed in, use them directly
  if (exchangeRates != null && exchangeRates.containsKey(to)) {
    final rate = exchangeRates[to] ?? 1.0;
    return amount * rate;
  }

  // 2. Otherwise consult ExchangeRateService cached/immediate rates
  final rates = ExchangeRateService.instance.getImmediateRates(from);
  if (rates.containsKey(to)) {
    final rate = rates[to] ?? 1.0;
    return amount * rate;
  }

  // 3. Fallback triangulating via USD or ZAR
  if (from == 'USD' && to == 'ZAR') return amount * 18.25;
  if (from == 'USD' && to == 'ZWG') return amount * 26.50;
  if (from == 'ZAR' && to == 'USD') return amount / 18.25;
  if (from == 'ZAR' && to == 'ZWG') return (amount / 18.25) * 26.50;
  if (from == 'ZWG' && to == 'USD') return amount / 26.50;
  if (from == 'ZWG' && to == 'ZAR') return (amount / 26.50) * 18.25;

  return amount;
}
