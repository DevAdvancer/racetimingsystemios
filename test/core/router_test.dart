import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/core/router.dart';
import 'package:race_timer/providers/race_provider.dart';

void main() {
  testWidgets('app launches on the start screen instead of the kiosk', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRaceProvider.overrideWithBuild((ref, notifier) async => null),
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

    expect(find.text('Print Barcode'), findsOneWidget);
    expect(find.text('Organizer Dashboard'), findsOneWidget);
    expect(find.text('Runner Check-In'), findsNothing);
  });
}
