import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_status.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/screens/registration_screen.dart';

void main() {
  final sampleRace = Race(
    id: 9,
    name: 'Saturday Park Run',
    raceDate: DateTime.utc(2026, 3, 21),
    gunTime: null,
    endTime: null,
    status: RaceStatus.pending,
    seriesName: 'Spring Series',
    createdAt: DateTime.utc(2026, 3, 21, 9),
    entryFeeMinor: 0,
    currencyCode: 'USD',
  );

  testWidgets('registration screen shows the kiosk-only runner flow', (
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
          home: const RegistrationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Runner Check-In'), findsOneWidget);
    expect(find.text('Saturday Park Run'), findsOneWidget);
    expect(find.text('Type your name'), findsOneWidget);
    expect(find.text('Print Barcode'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    expect(find.text('Reset Filters'), findsNothing);
    expect(find.text('Print All'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('Registered'), findsNothing);
  });
}
