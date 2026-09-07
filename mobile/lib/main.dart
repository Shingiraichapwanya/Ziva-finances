import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/config/app_environment.dart';
import 'core/theme/ziva_theme.dart';
import 'core/utils/url_anchor_helper.dart';
import 'features/assets/asset_registry_screen.dart';
import 'features/auth/access_guard_screen.dart';
import 'features/auth/privacy_shield.dart';
import 'features/common/quick_add_fab.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/desktop/desktop_sidebar.dart';
import 'features/ledger/ledger_screen.dart';
import 'features/settings/developer_settings_screen.dart';
import 'services/biometric_service.dart';
import 'services/sync_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce dark system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ZivaTheme.bgCore,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Mount UI immediately on first frame to prevent startup thread blocking
  runApp(const ZivaFinanceMobileApp());

  // Asynchronously initialize background sync engine without blocking UI
  _initBackgroundServices();
}

void _initBackgroundServices() async {
  try {
    await SyncEngine.instance.initialize().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('[Startup] SyncEngine background initialization timed out. Safe fallback active.');
      },
    );
  } catch (e) {
    debugPrint('[Startup] Non-blocking SyncEngine initialization warning: $e');
  }
}

class ZivaFinanceMobileApp extends StatelessWidget {
  const ZivaFinanceMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppEnvironment.isStaging ? 'Ziva Finance (Staging)' : 'Ziva Finance',
      debugShowCheckedModeBanner: AppEnvironment.isStaging,
      theme: ZivaTheme.darkTheme,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> with WidgetsBindingObserver {
  // Always start locked to enforce Access Guard in Live environment
  bool _isUnlocked = false;
  bool _isBackgroundMasked = false;
  int _currentTabIndex = 0;
  String _selectedCurrency = 'ZAR';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTabFromUrl();
  }

  void _initTabFromUrl() {
    final anchor = getUrlAnchor().toLowerCase();
    if (anchor.contains('asset')) {
      _currentTabIndex = 1;
    } else if (anchor.contains('ledger')) {
      _currentTabIndex = 2;
    } else if (anchor.contains('settings') || anchor.contains('dev')) {
      _currentTabIndex = 3;
    } else {
      _currentTabIndex = 0;
    }
  }

  void _selectTab(int index) {
    setState(() {
      _currentTabIndex = index;
      if (index == 0) {
        setUrlAnchor('command-center');
      } else if (index == 1) {
        setUrlAnchor('assets');
      } else if (index == 2) {
        setUrlAnchor('ledger');
      } else if (index == 3) {
        setUrlAnchor('settings');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Monitor iOS/Android app lifecycle transitions
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Browser tab switching should not blur or lock the web session
    if (kIsWeb) return;

    debugPrint('[LifecycleObserver] AppLifecycleState changed to: $state');

    // 1. When app is backgrounded or becoming inactive (user swipes up for App Switcher)
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      setState(() {
        // Instantly mask the app UI with the privacy blur shield
        _isBackgroundMasked = true;
      });
    }

    // 2. When app resumes to foreground from background
    if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  Future<void> _handleAppResume() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _isBackgroundMasked = false;
          _isUnlocked = true;
        });
      }
      return;
    }

    // If the app was unlocked, lock it and prompt for Face ID re-authentication
    if (_isUnlocked) {
      final authenticated = await BiometricService.instance.authenticate(
        reason: 'Re-authenticate with Face ID to resume your Ziva Finance session',
      );

      if (mounted) {
        setState(() {
          if (authenticated) {
            _isBackgroundMasked = false;
            _isUnlocked = true;
          } else {
            // Keep locked and show biometric lock screen
            _isBackgroundMasked = false;
            _isUnlocked = false;
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isBackgroundMasked = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main App Shell or Startup Access Guard Gate
        if (!_isUnlocked)
          AccessGuardScreen(
            onAuthenticated: () {
              setState(() {
                _isUnlocked = true;
                _isBackgroundMasked = false;
              });
            },
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 800;

              final mainContent = Column(
                children: [
                  // Top Staging Advisory Banner
                  if (AppEnvironment.isStaging)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      color: const Color(0xFFF59E0B),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 14, color: Colors.black),
                          SizedBox(width: 8),
                          Text(
                            'STAGING SANDBOX ENVIRONMENT • MOCK TELEMETRY ACTIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: _currentTabIndex,
                      children: [
                        DashboardScreen(
                          showSidebar: false,
                          selectedCurrency: _selectedCurrency,
                          onNavigateToAssets: () => _selectTab(1),
                          onNavigateToLedger: () => _selectTab(2),
                          onNavigateToSettings: () => _selectTab(3),
                        ),
                        AssetRegistryScreen(
                          onBackToDashboard: () => _selectTab(0),
                        ),
                        const LedgerScreen(),
                        const DeveloperSettingsScreen(),
                      ],
                    ),
                  ),
                ],
              );

              return Scaffold(
                body: isDesktop
                    ? Row(
                        children: [
                          DesktopSidebar(
                            currentTabIndex: _currentTabIndex,
                            selectedCurrency: _selectedCurrency,
                            onCurrencyChanged: (curr) => setState(() => _selectedCurrency = curr),
                            onSecretAdminTrigger: () => _selectTab(3),
                            onTabSelected: _selectTab,
                          ),
                          Expanded(child: mainContent),
                        ],
                      )
                    : mainContent,
                floatingActionButton: QuickAddFab(
                  onNavigateToTab: _selectTab,
                  onDataMutated: () => setState(() {}),
                ),
                bottomNavigationBar: isDesktop
                    ? null
                    : Container(
                        decoration: const BoxDecoration(
                          color: ZivaTheme.bgSurface,
                          border: Border(top: BorderSide(color: ZivaTheme.borderCard)),
                        ),
                        child: NavigationBar(
                          selectedIndex: _currentTabIndex,
                          backgroundColor: ZivaTheme.bgSurface,
                          indicatorColor: ZivaTheme.gold500.withValues(alpha: 0.2),
                          onDestinationSelected: _selectTab,
                          destinations: [
                            const NavigationDestination(
                              icon: Icon(Icons.dashboard_outlined, color: ZivaTheme.textMuted),
                              selectedIcon: Icon(Icons.dashboard_rounded, color: ZivaTheme.gold400),
                              label: 'Command',
                            ),
                            const NavigationDestination(
                              icon: Icon(Icons.account_balance_outlined, color: ZivaTheme.textMuted),
                              selectedIcon: Icon(Icons.account_balance_rounded, color: ZivaTheme.gold400),
                              label: 'Assets',
                            ),
                            NavigationDestination(
                              icon: ValueListenableBuilder<int>(
                                valueListenable: SyncEngine.instance.pendingCount,
                                builder: (context, count, _) {
                                  return Badge(
                                    isLabelVisible: count > 0,
                                    label: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    backgroundColor: ZivaTheme.gold500,
                                    textColor: Colors.black,
                                    child: const Icon(Icons.receipt_long_outlined, color: ZivaTheme.textMuted),
                                  );
                                },
                              ),
                              selectedIcon: const Icon(Icons.receipt_long_rounded, color: ZivaTheme.gold400),
                              label: 'Ledger',
                            ),
                            const NavigationDestination(
                              icon: Icon(Icons.tune_outlined, color: ZivaTheme.textMuted),
                              selectedIcon: Icon(Icons.tune_rounded, color: ZivaTheme.gold400),
                              label: 'Settings',
                            ),
                          ],
                        ),
                      ),
              );
            },
          ),

        // iOS Multitasking App Switcher Privacy Masking Shield
        if (_isBackgroundMasked)
          const PrivacyShield(),
      ],
    );
  }
}
