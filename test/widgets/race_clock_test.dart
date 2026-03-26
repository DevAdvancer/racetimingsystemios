import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/widgets/race_clock.dart';

void main() {
  testWidgets('race clock stops advancing once the race ends', (tester) async {
    final gunTime = DateTime.utc(2026, 3, 12, 10, 0, 0);
    var now = DateTime.utc(2026, 3, 12, 10, 0, 10);

    Widget buildClock({required bool isRunning}) {
      return MaterialApp(
        home: Scaffold(
          body: RaceClock(
            gunTime: gunTime,
            endTime: isRunning ? null : now,
            isRunning: isRunning,
            now: () => now,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildClock(isRunning: true));

    expect(find.text('00:10.00'), findsOneWidget);

    now = DateTime.utc(2026, 3, 12, 10, 0, 10, 500);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('00:10.50'), findsOneWidget);

    await tester.pumpWidget(buildClock(isRunning: false));
    await tester.pump();

    expect(find.text('00:10.50'), findsOneWidget);
    expect(find.textContaining('Clock stopped at'), findsOneWidget);

    now = DateTime.utc(2026, 3, 12, 10, 0, 20);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('00:10.50'), findsOneWidget);
  });
}
