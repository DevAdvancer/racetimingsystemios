import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/models/runner.dart';

void main() {
  RaceResultRow buildRow({
    DateTime? checkedInAt,
    DateTime? startTime,
    DateTime? finishTime,
    int? elapsedTimeMs,
  }) {
    return RaceResultRow(
      entryId: 1,
      runnerId: 1,
      raceId: 1,
      runnerName: 'Abhirup Kumar',
      barcodeValue: 'RT-000001',
      checkedInAt: checkedInAt,
      startTime: startTime,
      earlyStart: startTime != null,
      finishTime: finishTime,
      elapsedTimeMs: elapsedTimeMs,
      paymentStatus: PaymentStatus.paid,
    );
  }

  test('editable status shows started when a runner has a start scan', () {
    final row = buildRow(
      checkedInAt: DateTime.utc(2026, 4, 16, 8),
      startTime: DateTime.utc(2026, 4, 16, 8, 5),
    );

    expect(row.editableStatusLabel, 'Started');
  });

  test('editable status shows ended when a runner has a finish time', () {
    final row = buildRow(
      checkedInAt: DateTime.utc(2026, 4, 16, 8),
      startTime: DateTime.utc(2026, 4, 16, 8, 5),
      finishTime: DateTime.utc(2026, 4, 16, 8, 45),
      elapsedTimeMs: 2400000,
    );

    expect(row.editableStatusLabel, 'Ended');
  });
}
