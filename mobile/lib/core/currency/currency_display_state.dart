import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_types.dart';

/// Centralized Global Display Currency State
///
/// Manages the user's active reporting/display currency across all
/// dashboard tiles and conversion flows without altering stored source values.
class CurrencyDisplayState extends ChangeNotifier {
  static final CurrencyDisplayState instance = CurrencyDisplayState._internal();
  CurrencyDisplayState._internal() {
    _loadPersistedCurrency();
  }

  static const String _prefKey = 'ziva_global_display_currency';

  // Default reporting currency is ZAR (as implicitly used)
  String _currentDisplayCurrency = 'ZAR';

  /// Current active display currency: "USD", "ZWG", or "ZAR"
  String get currentDisplayCurrency => _currentDisplayCurrency;

  /// ValueNotifier for convenient integration with ValueListenableBuilder
  final ValueNotifier<String> currencyNotifier = ValueNotifier<String>('ZAR');

  Future<void> _loadPersistedCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && isSupportedCurrency(saved)) {
        final effective = getEffectiveCurrencyCode(saved);
        if (_currentDisplayCurrency != effective) {
          _currentDisplayCurrency = effective;
          currencyNotifier.value = effective;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[CurrencyDisplayState] Error loading persisted currency: $e');
    }
  }

  /// Sets the global display currency and persists the preference
  Future<void> setDisplayCurrency(String newCurrency) async {
    final effective = getEffectiveCurrencyCode(newCurrency);
    if (_currentDisplayCurrency == effective) return;

    _currentDisplayCurrency = effective;
    currencyNotifier.value = effective;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, effective);
    } catch (e) {
      debugPrint('[CurrencyDisplayState] Error persisting currency preference: $e');
    }
  }
}
