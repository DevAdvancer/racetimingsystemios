import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/models/overall_runner_points_summary.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_status.dart';
import 'package:race_timer/providers/points_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/screens/overall_points_screen.dart';

void main() {
  final sampleRace = Race(
    id: 11,
    name: 'City League Race',
    raceDate: DateTime.utc(2026, 3, 23),
    gunTime: null,
    endTime: null,
    status: RaceStatus.pending,
    seriesName: 'City Series',
    createdAt: DateTime.utc(2026, 3, 23, 9),
    entryFeeMinor: 0,
    currencyCode: 'USD',
  );

  final sampleRows = <OverallRunnerPointsSummary>[
    OverallRunnerPointsSummary(
      runnerId: 1,
      runnerName: 'Alice Green',
      barcodeValue: 'A100',
      totalPoints: 24,
      awardCount: 4,
      lastAwardedAt: DateTime.utc(2026, 3, 22, 8, 30),
      latestRaceId: 11,
      latestRaceName: 'City League Race',
    ),
    OverallRunnerPointsSummary(
      runnerId: 2,
      runnerName: 'Bob Stone',
      barcodeValue: 'B200',
      totalPoints: 16,
      awardCount: 3,
      lastAwardedAt: DateTime.utc(2026, 3, 21, 8, 30),
      latestRaceId: 11,
      latestRaceName: 'City League Race',
    ),
  ];

  testWidgets('overall points page filters the table by runner name', (
    tester,
  ) async {
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
          overallPointsProvider.overrideWith((ref) async => sampleRows),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const OverallPointsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice Green'), findsOneWidget);
    expect(find.text('Bob Stone'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search racer name'),
      'alice',
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice Green'), findsOneWidget);
    expect(find.text('Bob Stone'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
