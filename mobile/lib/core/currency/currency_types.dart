/// Centralized Currency Types & Multi-Currency Standards for Ziva Finance
///
/// Ensures every monetary value preserves its original transaction currency
/// (USD, ZWG, ZAR) as the immutable source of truth.
library;

/// Enumeration of official supported currencies in Ziva Finance
enum SupportedCurrency {
  usd('USD', 'US Dollar', '\$'),
  zwg('ZWG', 'Zimbabwe Gold', 'ZWG '),
  zar('ZAR', 'South African Rand', 'R ');

  final String code;
  final String displayName;
  final String symbol;

  const SupportedCurrency(this.code, this.displayName, this.symbol);

  static SupportedCurrency fromCode(String? code, {SupportedCurrency fallback = SupportedCurrency.zar}) {
    if (code == null || code.trim().isEmpty) return fallback;
    final clean = code.trim().toUpperCase();
    // Backward compatibility: map legacy 'ZIG' to official ISO code 'ZWG'
    if (clean == 'ZIG' || clean == 'ZWG') return SupportedCurrency.zwg;
    if (clean == 'USD') return SupportedCurrency.usd;
    if (clean == 'ZAR') return SupportedCurrency.zar;
    return fallback;
  }
}

/// List of all supported currency codes
const List<String> supportedCurrencies = ['USD', 'ZWG', 'ZAR'];

/// Helper type guard to check if a code is valid and supported
bool isSupportedCurrency(String? code) {
  if (code == null) return false;
  final clean = code.trim().toUpperCase();
  return clean == 'USD' || clean == 'ZWG' || clean == 'ZAR' || clean == 'ZIG';
}

/// Backward compatibility helper:
/// Resolves the effective currency code from a record or string.
/// - If null, empty, or undefined: returns the legacy base currency ('ZAR').
/// - If 'ZiG' (legacy temporary symbol): returns 'ZWG' (official ISO 4217 code).
/// - Otherwise returns the uppercase validated code, or fallback 'ZAR'.
String getEffectiveCurrencyCode(dynamic value, {String fallback = 'ZAR'}) {
  if (value == null) return fallback;

  String? raw;
  if (value is String) {
    raw = value;
  } else if (value is Map) {
    raw = (value['currency_code'] ??
            value['currencyCode'] ??
            value['original_currency'] ??
            value['originalCurrency'] ??
            value['currency'])
        ?.toString();
  } else {
    // If it's an object with dynamic properties
    try {
      raw = (value.currencyCode ?? value.originalCurrency ?? value.currency)?.toString();
    } catch (_) {
      raw = null;
    }
  }

  if (raw == null || raw.trim().isEmpty) return fallback;
  final clean = raw.trim().toUpperCase();
  if (clean == 'ZIG' || clean == 'ZWG') return 'ZWG';
  if (clean == 'USD') return 'USD';
  if (clean == 'ZAR') return 'ZAR';
  return fallback;
}

/// Returns standard display symbol for given currency code
String getCurrencySymbol(String? currencyCode) {
  final code = getEffectiveCurrencyCode(currencyCode);
  switch (code) {
    case 'USD':
      return '\$';
    case 'ZWG':
      return 'ZWG ';
    case 'ZAR':
    default:
      return 'R ';
  }
}

/// Returns descriptive label for given currency code
String getCurrencyLabel(String? currencyCode) {
  final code = getEffectiveCurrencyCode(currencyCode);
  switch (code) {
    case 'USD':
      return 'US Dollar (USD)';
    case 'ZWG':
      return 'Zimbabwe Gold (ZWG)';
    case 'ZAR':
    default:
      return 'South African Rand (ZAR)';
  }
}
