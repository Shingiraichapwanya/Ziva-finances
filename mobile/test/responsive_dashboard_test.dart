import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ziva_finance/core/layout/responsive_layout.dart';
import 'package:ziva_finance/features/dashboard/dashboard_screen.dart';
import 'package:ziva_finance/services/sqlite_service.dart';
import 'test_api_helper.dart';

void main() {
  setUp(() {
    SqliteService.instance.setApiForTesting(createMockApiService());
    SqliteService.instance.invalidateAndClearCaches();
  });

  group('ResponsiveLayout Unit & Widget Tests', () {
    testWidgets('Renders mobile widget when width < 800px', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveLayout(
            breakpoint: 800,
            mobile: Text('MOBILE_VIEW_ACTIVE'),
            desktop: Text('DESKTOP_COMMAND_CENTER_ACTIVE'),
          ),
        ),
      );

      expect(find.text('MOBILE_VIEW_ACTIVE'), findsOneWidget);
      expect(find.text('DESKTOP_COMMAND_CENTER_ACTIVE'), findsNothing);
    });

    testWidgets('Renders desktop widget when width >= 800px (1024px)', (tester) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveLayout(
            breakpoint: 800,
            mobile: Text('MOBILE_VIEW_ACTIVE'),
            desktop: Text('DESKTOP_COMMAND_CENTER_ACTIVE'),
          ),
        ),
      );

      expect(find.text('DESKTOP_COMMAND_CENTER_ACTIVE'), findsOneWidget);
      expect(find.text('MOBILE_VIEW_ACTIVE'), findsNothing);
    });
  });

  group('DashboardScreen Responsive & Cache Tests', () {
    testWidgets('Widescreen (1200px) mounts Desktop Command Center with Multi-Column KPIs', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            onNavigateToLedger: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('EXECUTIVE FINANCIAL COMMAND CENTER'), findsOneWidget);
      expect(find.text('PORTFOLIO NET WORTH'), findsOneWidget);
      expect(find.text('TIER 1: DAILY SPEND'), findsOneWidget);
      expect(find.text('TIER 2: OPERATIONAL'), findsOneWidget);
      expect(find.text('TIER 3: LONG-TERM'), findsOneWidget);
      expect(find.text('RECENT ACTIVITY & FEED'), findsOneWidget);

      // Verify no stale R799,150 net worth exists in widget tree
      expect(find.textContaining('799,150'), findsNothing);
    });

    testWidgets('Mobile screen (400px) mounts Single Column Mobile Layout', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            onNavigateToLedger: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('MOBILE DASHBOARD'), findsOneWidget);
      expect(find.text('Log Transaction Offline'), findsOneWidget);
      expect(find.textContaining('799,150'), findsNothing);
    });
  });
}
