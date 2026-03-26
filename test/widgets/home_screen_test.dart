import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/models/app_settings.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_status.dart';
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
