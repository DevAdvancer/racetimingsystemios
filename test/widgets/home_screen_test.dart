import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/models/app_settings.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_status.dart';
import 'package:race_timer/providers/points_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/settings_provider.dart';
import 'package:race_timer/screens/home_screen.dart';
import 'package:race_timer/screens/race_dashboard_screen.dart';

void main() {
  final sampleRace = Race(
    id: 7,
    name: 'Saturday Park Run',
    raceDate: DateTime.utc(2026, 3, 11),
    gunTime: null,
    endTime: null,
    status: RaceStatus.pending,
    seriesName: 'Spring Series',
    createdAt: DateTime.utc(2026, 3, 11, 10),
    entryFeeMinor: 0,
    currencyCode: 'USD',
  );

  testWidgets('home screen shows create race and available races', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          raceListProvider.overrideWith((ref) async => [sampleRace]),
          currentRaceProvider.overrideWithBuild(
            (ref, notifier) async => sampleRace,
          ),
          settingsProvider.overrideWithBuild(
            (ref, notifier) =>
                AppSettings.defaults().copyWith(selectedRaceId: sampleRace.id),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Race'), findsAtLeastNWidgets(1));
    expect(find.text('Available Races'), findsOneWidget);
    expect(find.text('Saturday Park Run'), findsOneWidget);
    expect(find.text('Open Selected Race'), findsOneWidget);
  });

  testWidgets(
    'home screen does not overflow with empty overall points on iPad',
    (tester) async {
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            raceListProvider.overrideWith((ref) async => [sampleRace]),
            currentRaceProvider.overrideWithBuild(
              (ref, notifier) async => sampleRace,
            ),
            overallPointsProvider.overrideWith((ref) async => const []),
            settingsProvider.overrideWithBuild(
              (ref, notifier) => AppSettings.defaults().copyWith(
                selectedRaceId: sampleRace.id,
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dashboardScrollView = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('No overall points yet'),
        300,
        scrollable: dashboardScrollView,
      );

      expect(find.text('No overall points yet'), findsOneWidget);
      expect(find.text('Adjust Overall Points'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home screen does not overflow in wide layout when overall points are empty',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            raceListProvider.overrideWith((ref) async => [sampleRace]),
            currentRaceProvider.overrideWithBuild(
              (ref, notifier) async => sampleRace,
            ),
            overallPointsProvider.overrideWith((ref) async => const []),
            settingsProvider.overrideWithBuild(
              (ref, notifier) => AppSettings.defaults().copyWith(
                selectedRaceId: sampleRace.id,
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dashboardScrollView = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.textContaining('No overall points yet'),
        300,
        scrollable: dashboardScrollView,
      );

      expect(find.textContaining('No overall points yet'), findsOneWidget);
      expect(find.text('Export Overall Points'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('create race dialog cancels without throwing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          raceListProvider.overrideWith((ref) async => const <Race>[]),
          currentRaceProvider.overrideWithBuild((ref, notifier) async => null),
          settingsProvider.overrideWithBuild(
            (ref, notifier) => AppSettings.defaults(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Race').first);
    await tester.pumpAndSettle();

    expect(find.text('Create a New Race'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Create a New Race'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bulk race creation dialog scrolls without overflow on shorter screens',
    (tester) async {
      tester.view.physicalSize = const Size(820, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            raceListProvider.overrideWith((ref) async => [sampleRace]),
            currentRaceProvider.overrideWithBuild(
              (ref, notifier) async => sampleRace,
            ),
            settingsProvider.overrideWithBuild(
              (ref, notifier) => AppSettings.defaults().copyWith(
                selectedRaceId: sampleRace.id,
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import Race Schedule').first);
      await tester.pumpAndSettle();

      expect(find.text('Bulk Race Creation'), findsOneWidget);
      expect(find.text('Upload Race Schedule File'), findsOneWidget);
      expect(find.text('Create From Typed Dates'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('race dashboard shows the three primary volunteer actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRaceProvider.overrideWithBuild(
            (ref, notifier) async => sampleRace,
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const RaceDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dashboardScrollView = find.byType(Scrollable).first;

    expect(find.text('Runner Kiosk'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Start Race'),
      300,
      scrollable: dashboardScrollView,
    );
    expect(find.text('Start Race'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Scan Runners'),
      300,
      scrollable: dashboardScrollView,
    );
    expect(find.text('Scan Runners'), findsOneWidget);
  });
}
