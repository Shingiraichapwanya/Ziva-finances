import 'package:intl/intl.dart';

enum MasterCurrency { zar, usd, zig }

class CurrencyFormatter {
  static String formatAmount(double amount, {String currency = 'ZAR'}) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formattedNum = formatter.format(amount.abs());
    final sign = amount < 0 ? '-' : '';

    switch (currency.toUpperCase()) {
      case 'ZAR':
        return '$sign' 'R $formattedNum';
      case 'USD':
        return '$sign' '\$ $formattedNum';
      case 'ZIG':
        return '$sign' 'ZiG $formattedNum';
      default:
        return '$sign$currency $formattedNum';
    }
  }

  static String format(double amount, String currency) {
    return formatAmount(amount, currency: currency);
  }

  // Cross currency conversion using effective standard rates
  static double convert({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
    double usdToZar = 18.25,
    double zarToZig = 1.3425,
  }) {
    if (fromCurrency.toUpperCase() == toCurrency.toUpperCase()) {
      return amount;
    }

    // Convert from source to ZAR first
    double amountInZar;
    switch (fromCurrency.toUpperCase()) {
      case 'ZAR':
        amountInZar = amount;
        break;
      case 'USD':
        amountInZar = amount * usdToZar;
        break;
      case 'ZIG':
        amountInZar = amount / zarToZig;
        break;
      default:
        amountInZar = amount;
    }

    // Convert ZAR to target
    switch (toCurrency.toUpperCase()) {
      case 'ZAR':
        return amountInZar;
      case 'USD':
        return amountInZar / usdToZar;
      case 'ZIG':
        return amountInZar * zarToZig;
      default:
        return amountInZar;
    }
  }
}
