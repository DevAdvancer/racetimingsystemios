import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/models/overall_runner_points_summary.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/models/race_status.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/models/runner_points_summary.dart';
import 'package:race_timer/services/export_service.dart';

void main() {
  group('ExportService', () {
    test(
      'includes the optional Distance column in the sample roster template',
      () {
        expect(
          ExportService.rosterTemplateHeaders,
          containsAllInOrder(<String>[
            'Name',
            'City',
            'Bib No',
            'Age',
            'Gend',
            'Barcode',
            'Payment Status',
            'Membership Status',
            'Distance',
          ]),
        );
      },
    );

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
            city: 'Southbury',
            bibNumber: '822',
            age: 39,
            gender: 'M',
            barcodeValue: '10-1-1',
            checkedInAt: DateTime.utc(2026, 3, 7, 7, 45, 0),
            startTime: DateTime.utc(2026, 3, 7, 7, 45, 0),
            earlyStart: true,
            finishTime: DateTime.utc(2026, 3, 7, 8, 0, 15),
            elapsedTimeMs: 75234,
            distanceName: 'Full Distance',
            distanceMiles: 5,
            paymentStatus: PaymentStatus.pending,
          ),
        ],
      );

      expect(csv, contains('Full Distance - 5 miles'));
      expect(
        csv,
        contains(
          'Overall,Name,City,Bib No,Age,Gend,Barcode,Payment Status,Check-In Time,Start Time,Finish Time,Time,Pace,Early Start,Status',
        ),
      );
      expect(csv, contains('Race Name,Saturday Park Run'));
      expect(csv, contains('Race Date,2026-03-07'));
      expect(
        csv,
        contains(
          '1,Taylor Smith,Southbury,822,39,M,10-1-1,Pending,2026-03-07T13:15:00.000,2026-03-07T13:15:00.000,2026-03-07T13:30:15.000,01:15.23,0:15/M,Yes,Race Completed',
        ),
      );
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
              distanceName: 'Full Distance',
              distanceMiles: 5,
            ),
          ],
        );

        expect(
          csv,
          contains(
            '1,Morgan Diaz,,,,,RT-000001,Paid,2026-03-14T13:15:00.000,2026-03-14T13:30:00.000,2026-03-14T14:03:00.000,33:00.00,6:36/M,No,Race Completed',
          ),
        );
      },
    );

    test(
      'builds a printable PDF byte stream with sample race-day columns',
      () async {
        const service = ExportService();
        final race = Race(
          id: 12,
          name: 'Saturday Park Run',
          raceDate: DateTime.utc(2026, 3, 15),
          gunTime: DateTime.utc(2026, 3, 15, 8),
          endTime: null,
          status: RaceStatus.running,
          seriesName: 'Spring Series',
          createdAt: DateTime.utc(2026, 3, 15, 5),
          entryFeeMinor: 0,
          currencyCode: 'USD',
        );

        final bytes = await service.buildResultsPdfBytes(
          race: race,
          rows: const <RaceResultRow>[
            RaceResultRow(
              entryId: 1,
              runnerId: 1,
              raceId: 12,
              runnerName: 'Jordan Lee',
              city: 'New Milford',
              bibNumber: '31',
              age: 26,
              gender: 'M',
              barcodeValue: 'RT-000001',
              checkedInAt: null,
              startTime: null,
              earlyStart: false,
              finishTime: null,
              elapsedTimeMs: null,
              distanceName: 'Alternate Distance',
              distanceMiles: 4.4,
            ),
          ],
        );

        expect(bytes, isNotEmpty);
      },
    );

    test('groups CSV output into multiple distance sections', () {
      const service = ExportService();
      final race = Race(
        id: 13,
        name: 'Squire Road (clockwise)',
        raceDate: DateTime.utc(2026, 3, 15),
        gunTime: DateTime.utc(2026, 3, 15, 8),
        endTime: null,
        status: RaceStatus.running,
        seriesName: 'Spring Series',
        createdAt: DateTime.utc(2026, 3, 15, 5),
        entryFeeMinor: 0,
        currencyCode: 'USD',
      );

      final csv = service.buildCsv(
        race: race,
        rows: const <RaceResultRow>[
          RaceResultRow(
            entryId: 1,
            runnerId: 1,
            raceId: 13,
            runnerName: 'Jordan Lee',
            barcodeValue: 'RT-000001',
            checkedInAt: null,
            startTime: null,
            earlyStart: false,
            finishTime: null,
            elapsedTimeMs: null,
            distanceName: 'Full Distance',
            distanceMiles: 5,
          ),
          RaceResultRow(
            entryId: 2,
            runnerId: 2,
            raceId: 13,
            runnerName: 'Casey Dunn',
            barcodeValue: 'RT-000002',
            checkedInAt: null,
            startTime: null,
            earlyStart: false,
            finishTime: null,
            elapsedTimeMs: null,
            distanceName: 'Alternate Distance',
            distanceMiles: 3.4,
          ),
        ],
      );

      expect(csv, contains('Full Distance - 5 miles'));
      expect(csv, contains('Alternate Distance - 3.4 miles'));
    });

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

    test('creates a racer points CSV with totals and race points', () {
      const service = ExportService();
      final race = Race(
        id: 30,
        name: 'Saturday Park Run',
        raceDate: DateTime.utc(2026, 3, 21),
        gunTime: null,
        endTime: null,
        status: RaceStatus.pending,
        seriesName: 'Spring Series',
        createdAt: DateTime.utc(2026, 3, 21, 5),
        entryFeeMinor: 0,
        currencyCode: 'USD',
      );

      final csv = service.buildPointsCsv(
        race: race,
        rows: [
          RunnerPointsSummary(
            runnerId: 1,
            raceId: 30,
            runnerName: 'Taylor Smith',
            barcodeValue: 'RT-000001',
            totalPoints: 25,
            pointsInRace: 10,
            awardCount: 3,
            lastAwardedAt: DateTime.utc(2026, 3, 21, 8),
          ),
        ],
      );

      expect(
        csv,
        contains(
          'Race Name,Race Date,Runner Name,Barcode,Points This Race,Total Points,Award Count,Last Awarded At',
        ),
      );
      expect(
        csv,
        contains(
          'Saturday Park Run,2026-03-21,Taylor Smith,RT-000001,10,25,3,2026-03-21T13:30:00.000',
        ),
      );
    });

    test('creates an overall points CSV with dashboard summary data', () {
      const service = ExportService();

      final csv = service.buildOverallPointsCsv(
        latestRaceName: 'Week 4',
        totalRaceCount: 12,
        rows: [
          OverallRunnerPointsSummary(
            runnerId: 1,
            runnerName: 'Taylor Smith',
            barcodeValue: 'RT-000001',
            totalPoints: 25,
            awardCount: 3,
            lastAwardedAt: DateTime.utc(2026, 3, 21, 8),
            latestRaceId: 4,
            latestRaceName: 'Week 4',
          ),
        ],
      );

      expect(csv, contains('Latest Race,Week 4'));
      expect(csv, contains('Total Races,12'));
      expect(
        csv,
        contains(
          'Runner Name,Barcode,Total Points,Award Count,Latest Points Race,Last Awarded At',
        ),
      );
      expect(
        csv,
        contains('Taylor Smith,RT-000001,25,3,Week 4,2026-03-21T13:30:00.000'),
      );
    });
  });
}
