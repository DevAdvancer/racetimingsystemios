import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/core/theme.dart';
import 'package:race_timer/models/check_in_match.dart';
import 'package:race_timer/models/check_in_result.dart';
import 'package:race_timer/models/check_in_state.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_entry.dart';
import 'package:race_timer/models/race_status.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/providers/check_in_provider.dart';
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
    tester.view.physicalSize = const Size(1366, 834);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRaceProvider.overrideWithBuild(
            (ref, notifier) async => sampleRace,
          ),
        ],
        child: MaterialApp(
          theme: buildRoxburyRacesLightTheme(),
          darkTheme: buildRoxburyRacesDarkTheme(),
          home: const RegistrationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Runner Check-In'), findsOneWidget);
    expect(find.text('Saturday Park Run'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Kiosk keyboard'), findsOneWidget);
    expect(find.text('Print Barcode'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    expect(find.text('Reset Filters'), findsNothing);
    expect(find.text('Print All'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('Registered'), findsNothing);
  });

  testWidgets(
    'registration screen places the keyboard below the print action on wide layouts',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRaceProvider.overrideWithBuild(
              (ref, notifier) async => sampleRace,
            ),
          ],
          child: MaterialApp(
            theme: buildRoxburyRacesLightTheme(),
            darkTheme: buildRoxburyRacesDarkTheme(),
            home: const RegistrationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final keyboardTop = tester.getTopLeft(find.text('Kiosk keyboard')).dy;
      final printBottom = tester.getBottomLeft(find.text('Print Barcode')).dy;

      expect(keyboardTop, greaterThan(printBottom));
    },
  );

  testWidgets(
    'registration screen suggests matching names from the first keyboard letter and previews the barcode',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final jordan = Runner(
        id: 1,
        name: 'Jordan Lee',
        barcodeValue: 'RT-000321',
        stripePaymentId: null,
        paymentStatus: PaymentStatus.paid,
        membershipStatus: MembershipStatus.member,
        createdAt: DateTime.utc(2026, 3, 21, 8),
      );
      final casey = Runner(
        id: 2,
        name: 'Casey Morgan',
        barcodeValue: 'RT-000654',
        stripePaymentId: null,
        paymentStatus: PaymentStatus.paid,
        membershipStatus: MembershipStatus.member,
        createdAt: DateTime.utc(2026, 3, 21, 8, 5),
      );
      final roster = <CheckInMatch>[
        CheckInMatch(
          runner: jordan,
          entry: const RaceEntry(
            id: 11,
            runnerId: 1,
            raceId: 9,
            barcodeValue: 'RT-000321',
            checkedInAt: null,
            startTime: null,
            earlyStart: false,
            finishTime: null,
            elapsedTimeMs: null,
          ),
          race: sampleRace,
        ),
        CheckInMatch(
          runner: casey,
          entry: const RaceEntry(
            id: 12,
            runnerId: 2,
            raceId: 9,
            barcodeValue: 'RT-000654',
            checkedInAt: null,
            startTime: null,
            earlyStart: false,
            finishTime: null,
            elapsedTimeMs: null,
          ),
          race: sampleRace,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRaceProvider.overrideWithBuild(
              (ref, notifier) async => sampleRace,
            ),
            checkInProvider.overrideWithBuild(
              (ref, notifier) async => CheckInState(
                race: sampleRace,
                roster: roster,
                lastResult: CheckInResult.idle(),
                isBusy: false,
              ),
            ),
          ],
          child: MaterialApp(
            theme: buildRoxburyRacesLightTheme(),
            darkTheme: buildRoxburyRacesDarkTheme(),
            home: const RegistrationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('J').first);
      await tester.pumpAndSettle();

      expect(find.text('Tap your name from the list'), findsOneWidget);
      expect(find.text('Jordan Lee'), findsAtLeastNWidgets(1));

      await tester.tap(find.text('Jordan Lee').first);
      await tester.pumpAndSettle();

      expect(find.text('Barcode preview for Jordan Lee'), findsOneWidget);
      expect(find.text('Jordan Lee'), findsAtLeastNWidgets(2));
      expect(find.text('RT-000321'), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'registration screen keeps the name field active before a race is selected',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRaceProvider.overrideWithBuild(
              (ref, notifier) async => null,
            ),
          ],
          child: MaterialApp(
            theme: buildRoxburyRacesLightTheme(),
            darkTheme: buildRoxburyRacesDarkTheme(),
            home: const RegistrationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('J').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('O').first);
      await tester.pumpAndSettle();

      expect(find.text('Jo'), findsOneWidget);
      expect(
        find.text(
          'Select today\'s race in organizer setup to load the runner roster.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('registration screen renders with the app dark theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 834);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRaceProvider.overrideWithBuild(
            (ref, notifier) async => sampleRace,
          ),
        ],
        child: MaterialApp(
          theme: buildRoxburyRacesLightTheme(),
          darkTheme: buildRoxburyRacesDarkTheme(),
          themeMode: ThemeMode.dark,
          home: const RegistrationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Runner Check-In'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Print Barcode'), findsOneWidget);
  });
}
