import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ziva_finance/core/config/app_environment.dart';
import 'package:ziva_finance/features/auth/access_guard_screen.dart';

void main() {
  group('AppEnvironment Unit Tests', () {
    tearDown(() {
      AppEnvironment.setOverride(null);
    });

    test('defaults to Live environment with emerald badge', () {
      AppEnvironment.setOverride(AppEnv.live);
      expect(AppEnvironment.isLive, isTrue);
      expect(AppEnvironment.isStaging, isFalse);
      expect(AppEnvironment.name, equals('LIVE'));
      expect(AppEnvironment.badgeLabel, equals('LIVE TERMINAL'));
      expect(AppEnvironment.accentColor, equals(const Color(0xFF10B981)));
    });

    test('switches to Staging environment with amber badge and advisory banner', () {
      AppEnvironment.setOverride(AppEnv.staging);
      expect(AppEnvironment.isLive, isFalse);
      expect(AppEnvironment.isStaging, isTrue);
      expect(AppEnvironment.name, equals('STAGING'));
      expect(AppEnvironment.badgeLabel, equals('STAGING SANDBOX'));
      expect(AppEnvironment.accentColor, equals(const Color(0xFFF59E0B)));
      expect(AppEnvironment.stagingNotice, contains('STAGING SANDBOX ENVIRONMENT'));
    });
  });

  group('AccessGuardScreen Widget Tests', () {
    testWidgets('Mobile (< 800px): renders executive PIN pad and handles correct passcode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool authenticated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AccessGuardScreen(
            onAuthenticated: () {
              authenticated = true;
            },
          ),
        ),
      );

      // Verify title & brand
      expect(find.text('ZIVA FINANCE'), findsOneWidget);
      expect(find.text('Executive Financial Terminal Access'), findsOneWidget);

      // Enter default master PIN on mobile touch keypad: 2, 0, 2, 6
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('6'));
      await tester.pump();

      expect(authenticated, isTrue);
    });

    testWidgets('Mobile (< 800px): rejects invalid passcode and presents error message', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool authenticated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AccessGuardScreen(
            onAuthenticated: () {
              authenticated = true;
            },
          ),
        ),
      );

      // Enter invalid PIN: 1, 1, 1, 1
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      expect(authenticated, isFalse);
      expect(find.text('Invalid Passcode. Access Denied.'), findsOneWidget);
    });

    testWidgets('Desktop (>= 800px): renders masked TextFormField with Enter submission', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool authenticated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AccessGuardScreen(
            onAuthenticated: () {
              authenticated = true;
            },
          ),
        ),
      );

      expect(find.text('Executive Financial Terminal • Desktop Access'), findsOneWidget);
      expect(find.text('Unlock Terminal'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);

      // Enter correct passcode '2026' and submit
      await tester.enterText(find.byType(TextFormField), '2026');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(authenticated, isTrue);
    });
  });
}
