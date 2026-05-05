import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/models/finish_scan_result.dart';
import 'package:race_timer/widgets/finish_scan_keyboard_listener.dart';

Future<void> _scanBarcode(WidgetTester tester, String barcode) async {
  for (final character in barcode.characters) {
    await _sendCharacter(tester, character);
  }
  await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  await tester.pump();
}

Future<void> _typeBarcode(WidgetTester tester, String barcode) async {
  for (final character in barcode.characters) {
    await _sendCharacter(tester, character);
  }
}

Future<void> _sendCharacter(WidgetTester tester, String character) async {
  final key = switch (character) {
    'R' => LogicalKeyboardKey.keyR,
    'T' => LogicalKeyboardKey.keyT,
    '-' => LogicalKeyboardKey.minus,
    '0' => LogicalKeyboardKey.digit0,
    '1' => LogicalKeyboardKey.digit1,
    '2' => LogicalKeyboardKey.digit2,
    '3' => LogicalKeyboardKey.digit3,
    '4' => LogicalKeyboardKey.digit4,
    '5' => LogicalKeyboardKey.digit5,
    '6' => LogicalKeyboardKey.digit6,
    '7' => LogicalKeyboardKey.digit7,
    '8' => LogicalKeyboardKey.digit8,
    '9' => LogicalKeyboardKey.digit9,
    _ => throw UnsupportedError('Unsupported barcode character: $character'),
  };
  await tester.sendKeyDownEvent(key, character: character);
  await tester.sendKeyUpEvent(key);
}

void main() {
  testWidgets('keyboard listener auto-submits a scan and shows a short popup', (
    tester,
  ) async {
    final submittedScans = <String>[];
    final startTime = DateTime.utc(2026, 3, 24, 12);

    await tester.pumpWidget(
      MaterialApp(
        home: FinishScanKeyboardListener(
          onScan: (scanValue) async {
            submittedScans.add(scanValue);
            return FinishScanResult.earlyStartRecorded(
              runnerName: 'Morgan',
              barcodeValue: scanValue,
              startTime: startTime,
            );
          },
          child: const Scaffold(body: Text('Race Timing')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await _scanBarcode(tester, 'RT-000001');

    expect(submittedScans, <String>['RT-000001']);
    expect(find.textContaining('Morgan early start scanned'), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 1),
    );
  });

  testWidgets('keyboard listener submits after the debounce without a suffix', (
    tester,
  ) async {
    final submittedScans = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: FinishScanKeyboardListener(
          debounceDuration: const Duration(milliseconds: 180),
          onScan: (scanValue) async {
            submittedScans.add(scanValue);
            return FinishScanResult.success(
              runnerName: 'Morgan',
              barcodeValue: scanValue,
              finishTime: DateTime.utc(2026, 3, 24, 12, 5),
              elapsedTimeMs: 300000,
            );
          },
          child: const Scaffold(body: Text('Race Timing')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await _typeBarcode(tester, 'RT-000001');
    await tester.pump(const Duration(milliseconds: 179));

    expect(submittedScans, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));

    expect(submittedScans, <String>['RT-000001']);
  });
}
