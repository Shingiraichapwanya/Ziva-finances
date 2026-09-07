import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/config/app_environment.dart';
import 'core/theme/ziva_theme.dart';
import 'features/auth/access_guard_screen.dart';
import 'features/auth/privacy_shield.dart';
import 'features/dashboard/dashboard_screen.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

              return Scaffold(
                body: Column(
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
                            onNavigateToLedger: () => setState(() => _currentTabIndex = 1),
                            onNavigateToSettings: () => setState(() => _currentTabIndex = 2),
                          ),
                          const LedgerScreen(),
                          const DeveloperSettingsScreen(),
                        ],
                      ),
                    ),
                  ],
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
                          onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
                          destinations: [
                            const NavigationDestination(
                              icon: Icon(Icons.dashboard_outlined, color: ZivaTheme.textMuted),
                              selectedIcon: Icon(Icons.dashboard_rounded, color: ZivaTheme.gold400),
                              label: 'Dashboard',
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
                              label: 'Dev & OTA',
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
