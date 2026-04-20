import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/core/router.dart';
import 'package:race_timer/providers/race_provider.dart';

void main() {
  testWidgets('app launches on the choose race page', (tester) async {
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

    expect(find.text('Choose Race'), findsAtLeastNWidgets(1));
    expect(find.text('Create Race'), findsAtLeastNWidgets(1));
    expect(find.text('Print Barcode'), findsNothing);
    expect(find.text('Runner Check-In'), findsNothing);
  });
}
