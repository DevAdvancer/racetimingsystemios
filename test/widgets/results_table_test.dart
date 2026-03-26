import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/widgets/results_table.dart';

void main() {
  testWidgets('ResultsTable shows only finishers in finish order', (
    tester,
  ) async {
    final rows = <RaceResultRow>[
      const RaceResultRow(
        entryId: 1,
        runnerId: 1,
        raceId: 1,
        runnerName: 'Registered Runner',
        barcodeValue: 'RT-000001',
        checkedInAt: null,
        startTime: null,
        earlyStart: false,
        finishTime: null,
        elapsedTimeMs: null,
      ),
      RaceResultRow(
        entryId: 2,
        runnerId: 2,
        raceId: 1,
        runnerName: 'First Finisher',
        barcodeValue: 'RT-000002',
        checkedInAt: DateTime.utc(2026, 3, 24, 0, 0, 1),
        startTime: DateTime.utc(2026, 3, 24, 0, 0, 1),
        earlyStart: false,
        finishTime: DateTime.utc(2026, 3, 24, 0, 25, 1),
        elapsedTimeMs: 1500000,
      ),
      RaceResultRow(
        entryId: 3,
        runnerId: 3,
        raceId: 1,
        runnerName: 'Early Starter',
        barcodeValue: 'RT-000003',
        checkedInAt: DateTime.utc(2026, 3, 24, 0, 0, 1),
        startTime: DateTime.utc(2026, 3, 24, 0, 0, 1),
        earlyStart: true,
        finishTime: DateTime.utc(2026, 3, 24, 0, 30, 1),
        elapsedTimeMs: 1800000,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 500, child: ResultsTable(results: rows)),
        ),
      ),
    );

    expect(find.text('Registered Runner'), findsNothing);
    expect(find.text('First Finisher'), findsOneWidget);
    expect(find.text('Early Starter'), findsOneWidget);
    expect(find.text('Early Start'), findsOneWidget);
  });
}
