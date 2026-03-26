import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/models/race_status.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/services/export_service.dart';

void main() {
  group('ExportService', () {
    test('creates the expected CSV header and row content', () {
      const service = ExportService();
      final race = Race(
        id: 10,
        name: 'Saturday Park Run',
        raceDate: DateTime.utc(2026, 3, 7),
        gunTime: DateTime.utc(2026, 3, 7, 7, 59, 0),
        endTime: null,
        status: RaceStatus.running,
        seriesName: 'Spring Series',
        createdAt: DateTime.utc(2026, 3, 7, 5),
        entryFeeMinor: 0,
        currencyCode: 'USD',
      );
      final csv = service.buildCsv(
        race: race,
        rows: [
          RaceResultRow(
            entryId: 1,
            runnerId: 1,
            raceId: 10,
            runnerName: 'Taylor Smith',
            barcodeValue: '10-1-1',
            checkedInAt: DateTime.utc(2026, 3, 7, 7, 45, 0),
            startTime: DateTime.utc(2026, 3, 7, 7, 45, 0),
            earlyStart: true,
            finishTime: DateTime.utc(2026, 3, 7, 8, 0, 15),
            elapsedTimeMs: 75234,
            paymentStatus: PaymentStatus.pending,
          ),
        ],
      );

      expect(
        csv,
        contains(
          'Race Name,Race Date,Runner Name,Barcode,Payment Status,Start Time,Finish Time,Elapsed Time,Early Start,Status,Check-In Time',
        ),
      );
      expect(
        csv,
        contains(
          'Saturday Park Run,2026-03-07,Taylor Smith,10-1-1,Pending,2026-03-07T13:15:00.000',
        ),
      );
      expect(csv, contains(',Yes,'));
      expect(csv, contains('01:15.23'));
    });

    test(
      'uses the global gun time when a runner does not have an early start',
      () {
        const service = ExportService();
        final race = Race(
          id: 11,
          name: 'Saturday Park Run',
          raceDate: DateTime.utc(2026, 3, 14),
          gunTime: DateTime.utc(2026, 3, 14, 8, 0, 0),
          endTime: null,
          status: RaceStatus.running,
          seriesName: 'Spring Series',
          createdAt: DateTime.utc(2026, 3, 14, 5),
          entryFeeMinor: 0,
          currencyCode: 'USD',
        );

        final csv = service.buildCsv(
          race: race,
          rows: [
            RaceResultRow(
              entryId: 1,
              runnerId: 1,
              raceId: 11,
              runnerName: 'Morgan Diaz',
              barcodeValue: 'RT-000001',
              checkedInAt: DateTime.utc(2026, 3, 14, 7, 45, 0),
              startTime: null,
              earlyStart: false,
              finishTime: DateTime.utc(2026, 3, 14, 8, 33, 0),
              elapsedTimeMs: 1980000,
            ),
          ],
        );

        expect(
          csv,
          contains('Morgan Diaz,RT-000001,Paid,2026-03-14T13:30:00.000'),
        );
        expect(csv, contains(',No,Race Completed,'));
        expect(csv, contains('33:00.00'));
      },
    );

    test('builds a file name that includes the race date and identifier', () {
      const service = ExportService();
      final race = Race(
        id: 22,
        name: 'Saturday Park Run',
        raceDate: DateTime.utc(2026, 3, 19),
        gunTime: null,
        endTime: null,
        status: RaceStatus.pending,
        seriesName: 'Spring Series',
        createdAt: DateTime.utc(2026, 3, 19, 5),
        entryFeeMinor: 0,
        currencyCode: 'USD',
      );

      final fileName = service.buildFileName(
        race,
        exportedAt: DateTime.utc(2026, 3, 19, 8),
      );

      expect(fileName, contains('20260319'));
      expect(fileName, contains('saturday_park_run'));
      expect(fileName, contains('race-22'));
      expect(fileName, endsWith('.csv'));
    });
  });
}
