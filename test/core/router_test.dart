import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:race_timer/core/app_navigation.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/router.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/providers/points_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/results_provider.dart';
import 'package:race_timer/screens/race_dashboard_screen.dart';
import 'package:race_timer/screens/scanner_screen.dart';

void main() {
  testWidgets('app launches on the choose race page', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          raceListProvider.overrideWith((ref) async => const <Race>[]),
          currentRaceProvider.overrideWithBuild((ref, notifier) async => null),
          overallPointsProvider.overrideWith((ref) async => const []),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose Race'), findsAtLeastNWidgets(1));
    expect(find.text('Create Race'), findsAtLeastNWidgets(1));
    expect(find.text('Print Barcode'), findsNothing);
    expect(find.text('Runner Check-In'), findsNothing);
  });

  testWidgets('runner kiosk button opens print page without router reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          raceListProvider.overrideWith((ref) async => const <Race>[]),
          currentRaceProvider.overrideWithBuild((ref, notifier) async => null),
          overallPointsProvider.overrideWith((ref) async => const []),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Runner Kiosk'));
    await tester.pumpAndSettle();

    expect(find.text('Print Barcode'), findsOneWidget);
    expect(find.text('Choose active Race'), findsNothing);
  });

  testWidgets('roster tools back button returns to race dashboard', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.rosterTools,
      routes: [
        GoRoute(
          path: AppRoutes.raceDashboard,
          builder: (context, state) => const RaceDashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.rosterTools,
          builder: (context, state) => const RosterToolsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRaceProvider.overrideWithBuild((ref, notifier) async => null),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Roster Tools'), findsAtLeastNWidgets(1));

    await tester.tap(find.byTooltip('Back to Race Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Race Day Console'), findsAtLeastNWidgets(1));
  });

  testWidgets('scanner back button returns to race dashboard', (tester) async {
    tester.view.physicalSize = const Size(2388, 1668);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      navigatorKey: appNavigatorKey,
      initialLocation: AppRoutes.scanner,
      routes: [
        GoRoute(
          path: AppRoutes.raceDashboard,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Race Dashboard'))),
        ),
        GoRoute(
          path: AppRoutes.scanner,
          builder: (context, state) => const ScannerScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [resultsProvider.overrideWith((ref) async => const [])],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Result Table'), findsOneWidget);
    expect(find.text('Scanner listening'), findsOneWidget);
    expect(find.text('Race Dashboard'), findsOneWidget);
    expect(find.text('No runners in this race yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Back to Race Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Race Dashboard'), findsOneWidget);
  });

  testWidgets('race dashboard back button returns to choose race', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.raceDashboard,
      routes: [
        GoRoute(
          path: AppRoutes.adminHome,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Choose Race'))),
        ),
        GoRoute(
          path: AppRoutes.raceDashboard,
          builder: (context, state) => const RaceDashboardScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRaceProvider.overrideWithBuild((ref, notifier) async => null),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Race Day Console'), findsAtLeastNWidgets(1));

    await tester.tap(find.byTooltip('Back to Choose Race'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Race'), findsOneWidget);
  });
}
