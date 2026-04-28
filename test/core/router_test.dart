import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/core/router.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/providers/points_provider.dart';
import 'package:race_timer/providers/race_provider.dart';

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
}
