import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/database/database_helper.dart';
import 'package:race_timer/models/app_settings.dart';
import 'package:race_timer/models/check_in_match.dart';
import 'package:race_timer/models/check_in_result.dart';
import 'package:race_timer/models/finish_scan_result.dart';
import 'package:race_timer/models/printer_status.dart';
import 'package:race_timer/models/race_schedule_import.dart';
import 'package:race_timer/models/roster_import.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/models/scan_event_log.dart';
import 'package:race_timer/services/barcode_service.dart';
import 'package:race_timer/services/database_service.dart';
import 'package:race_timer/services/printer_service.dart';
import 'package:race_timer/services/race_service.dart';
import 'package:race_timer/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakePrinterService implements PrinterService {
  FakePrinterService(this.status);

  PrinterStatus status;

  @override
  Future<PrinterStatus> configure() async => status;

  @override
  Future<PrinterStatus> getStatus() async => status;

  @override
  Future<PrinterStatus> printLabel(document) async => status;

  @override
  Future<PrinterStatus> testPrint() async => status;
}

void main() {
  late DatabaseHelper helper;
  late DatabaseService databaseService;
  late FakePrinterService printerService;
  late RaceService raceService;
  late SettingsService settingsService;

  setUp(() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    helper = DatabaseHelper.forTesting(databaseFactory: databaseFactoryFfi);
    await helper.ensureInitialized();
    databaseService = DatabaseService(helper);
    printerService = FakePrinterService(PrinterStatus.success());
    settingsService = await SettingsService.create();
    raceService = RaceService(
      databaseService: databaseService,
      barcodeService: const BarcodeService(),
      printerService: printerService,
      settingsService: settingsService,
    );
  });

  tearDown(() async {
    await helper.close();
  });

  test('importRoster creates local runners and stable barcodes', () async {
    await raceService.createRace(name: 'Spring 5K');

    final importResult = await raceService.importRoster(
      const RosterImport(
        sourceName: 'spring.xlsx',
        runners: <ImportedRunnerData>[
          ImportedRunnerData(name: 'Jordan'),
          ImportedRunnerData(name: 'Casey'),
        ],
      ),
    );

    final lookup = await raceService.lookupRunnerForCheckIn('Jordan');

    expect(importResult.isSuccess, isTrue);
    expect(importResult.newRunnerCount, 2);
    expect(lookup.outcome, CheckInOutcome.ready);
    expect(lookup.selectedMatch?.entry.barcodeValue, 'RT-000001');
  });

  test('importRoster reports duplicates and invalid rows separately', () async {
    await raceService.createRace(name: 'Spring 5K');

    final importResult = await raceService.importRoster(
      const RosterImport(
        sourceName: 'spring.xlsx',
        invalidRowCount: 1,
        runners: <ImportedRunnerData>[
          ImportedRunnerData(name: 'Jordan'),
          ImportedRunnerData(name: 'Jordan'),
          ImportedRunnerData(name: 'Casey'),
        ],
      ),
    );

    expect(importResult.isSuccess, isTrue);
    expect(importResult.importedCount, 2);
    expect(importResult.duplicateCount, 1);
    expect(importResult.invalidRowCount, 1);
    expect(importResult.skippedCount, 2);
    expect(importResult.message, contains('Skipped 1 duplicate roster rows.'));
    expect(
      importResult.message,
      contains('Ignored 1 invalid rows with missing or conflicting data.'),
    );
  });

  test(
    'importRoster skips conflicting imported barcodes to protect data',
    () async {
      final weekOne = await raceService.createRace(name: 'Week 1');
      await raceService.importRoster(
        const RosterImport(
          sourceName: 'week1.xlsx',
          runners: <ImportedRunnerData>[
            ImportedRunnerData(name: 'Jordan', barcodeValue: 'RT-009999'),
          ],
        ),
      );

      await raceService.createRace(name: 'Week 2');
      final importResult = await raceService.importRoster(
        const RosterImport(
          sourceName: 'week2.xlsx',
          runners: <ImportedRunnerData>[
            ImportedRunnerData(name: 'Casey', barcodeValue: 'RT-009999'),
          ],
        ),
      );

      final jordan = await databaseService.getRunnerByNormalizedName('jordan');
      final casey = await databaseService.getRunnerByNormalizedName('casey');
      final jordanWeekOneEntry = await databaseService.getRaceEntryForRunner(
        runnerId: jordan!.id,
        raceId: weekOne.id,
      );

      expect(importResult.isSuccess, isTrue);
      expect(importResult.importedCount, 0);
      expect(importResult.invalidRowCount, 1);
      expect(jordanWeekOneEntry?.barcodeValue, 'RT-009999');
      expect(casey, isNull);
    },
  );

  test('importRoster preserves an imported barcode for a new runner', () async {
    await raceService.createRace(name: 'Spring 5K');

    final importResult = await raceService.importRoster(
      const RosterImport(
        sourceName: 'spring.xlsx',
        runners: <ImportedRunnerData>[
          ImportedRunnerData(name: 'Jordan', barcodeValue: 'RT-009999'),
        ],
      ),
    );

    final lookup = await raceService.lookupRunnerForCheckIn('Jordan');

    expect(importResult.isSuccess, isTrue);
    expect(lookup.selectedMatch?.entry.barcodeValue, 'RT-009999');
  });

  test(
    'importRoster reuses a returning runner barcode in a later race',
    () async {
      await raceService.createRace(name: 'Week 1');
      await raceService.importRoster(
        const RosterImport(
          sourceName: 'week1.xlsx',
          runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Jordan')],
        ),
      );

      final weekOneLookup = await raceService.lookupRunnerForCheckIn('Jordan');

      await raceService.createRace(name: 'Week 2');
      await raceService.importRoster(
        const RosterImport(
          sourceName: 'week2.xlsx',
          runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Jordan')],
        ),
      );

      final weekTwoLookup = await raceService.lookupRunnerForCheckIn('Jordan');

      expect(
        weekTwoLookup.selectedMatch?.entry.barcodeValue,
        weekOneLookup.selectedMatch?.entry.barcodeValue,
      );
    },
  );

  test(
    'importRoster stores sample race-day fields on the runner and entry',
    () async {
      final race = await raceService.createRace(name: 'Week 1');
      await raceService.importRoster(
        const RosterImport(
          sourceName: 'week1.xlsx',
          runners: <ImportedRunnerData>[
            ImportedRunnerData(
              name: 'Jordan',
              city: 'Southbury',
              bibNumber: '822',
              age: 39,
              gender: 'M',
              paymentStatus: PaymentStatus.paid,
            ),
          ],
        ),
      );

      final results = await raceService.getResults(race.id);

      expect(results.single.city, 'Southbury');
      expect(results.single.bibNumber, '822');
      expect(results.single.age, 39);
      expect(results.single.gender, 'M');
      expect(results.single.paymentStatus, PaymentStatus.paid);
    },
  );

  test(
    'updateRosterEntry edits racer data and keeps the barcode synced',
    () async {
      final raceA = await raceService.createRace(name: 'Week 1');
      await raceService.importRoster(
        const RosterImport(
          sourceName: 'week1.xlsx',
          runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Jordan')],
        ),
      );
      final weekOneLookup = await raceService.lookupRunnerForCheckIn('Jordan');

      await raceService.createRace(name: 'Week 2');
      await raceService.importRoster(
        const RosterImport(
          sourceName: 'week2.xlsx',
          runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Jordan')],
        ),
      );

      await raceService.updateRosterEntry(
        runnerId: weekOneLookup.selectedMatch!.runner.id,
        entryId: weekOneLookup.selectedMatch!.entry.id,
        name: 'Jordan Lee',
        barcodeValue: 'RT-009999',
        paymentStatus: PaymentStatus.pending,
        city: 'Southbury',
        gender: 'M',
        bibNumber: '822',
        age: 39,
      );

      final weekOneResults = await raceService.getResults(raceA.id);
      final weekTwoLookup = await raceService.lookupRunnerForCheckIn(
        'Jordan Lee',
      );

      expect(weekOneResults.single.runnerName, 'Jordan Lee');
      expect(weekOneResults.single.city, 'Southbury');
      expect(weekOneResults.single.bibNumber, '822');
      expect(weekOneResults.single.barcodeValue, 'RT-009999');
      expect(weekOneResults.single.paymentStatus, PaymentStatus.pending);
      expect(weekTwoLookup.selectedMatch?.entry.barcodeValue, 'RT-009999');
    },
  );

  test(
    'importRoster assigns the primary alternate distance by default',
    () async {
      final race = await raceService.createRace(name: 'Squire Road');
      await raceService.saveRaceDistanceConfig(
        raceId: race.id,
        name: 'Full Distance',
        distanceMiles: 5,
        isPrimary: true,
      );
      await raceService.saveRaceDistanceConfig(
        raceId: race.id,
        name: 'Alternate Distance',
        distanceMiles: 3.4,
      );

      await raceService.importRoster(
        const RosterImport(
          sourceName: 'week1.xlsx',
          runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Jordan')],
        ),
      );

      final results = await raceService.getResults(race.id);

      expect(results.single.distanceName, 'Full Distance');
      expect(results.single.distanceMiles, 5);
      expect(
        RaceService.formatPace(
          elapsedTimeMs: results.single.elapsedTimeMs,
          distanceMiles: results.single.distanceMiles,
          paceOverride: results.single.paceOverride,
        ),
        '',
      );
    },
  );

  test(
    'importRoster assigns an alternate distance from the optional import column',
    () async {
      final race = await raceService.createRace(name: 'Squire Road');
      await raceService.saveRaceDistanceConfig(
        raceId: race.id,
        name: 'Full Distance',
        distanceMiles: 5,
        isPrimary: true,
      );
      await raceService.saveRaceDistanceConfig(
        raceId: race.id,
        name: 'Alternate Distance',
        distanceMiles: 3.4,
      );

      final importResult = await raceService.importRoster(
        const RosterImport(
          sourceName: 'week1.xlsx',
          runners: <ImportedRunnerData>[
            ImportedRunnerData(
              name: 'Jordan',
              distance: 'Alternate Distance - 3.4 miles',
            ),
          ],
        ),
      );

      final results = await raceService.getResults(race.id);

      expect(importResult.isSuccess, isTrue);
      expect(importResult.importedCount, 1);
      expect(importResult.invalidRowCount, 0);
      expect(results.single.distanceName, 'Alternate Distance');
      expect(results.single.distanceMiles, 3.4);
    },
  );

  test(
    'importRoster skips rows with an unknown imported distance value',
    () async {
      final race = await raceService.createRace(name: 'Squire Road');
      await raceService.saveRaceDistanceConfig(
        raceId: race.id,
        name: 'Full Distance',
        distanceMiles: 5,
        isPrimary: true,
      );

      final importResult = await raceService.importRoster(
        const RosterImport(
          sourceName: 'week1.xlsx',
          runners: <ImportedRunnerData>[
            ImportedRunnerData(name: 'Jordan', distance: 'Alternate Distance'),
          ],
        ),
      );

      final results = await raceService.getResults(race.id);
      final lookup = await raceService.lookupRunnerForCheckIn('Jordan');

      expect(importResult.isSuccess, isTrue);
      expect(importResult.importedCount, 0);
      expect(importResult.invalidRowCount, 1);
      expect(results, isEmpty);
      expect(lookup.outcome, CheckInOutcome.notFound);
    },
  );

  test(
    'updateRosterEntry saves alternate distance, elapsed time, and pace override',
    () async {
      final race = await raceService.createRace(name: 'Squire Road');
      final fullDistance = await raceService.saveRaceDistanceConfig(
        raceId: race.id,
        name: 'Full Distance',
        distanceMiles: 5,
        isPrimary: true,
      );
      final alternateDistance = await raceService.saveRaceDistanceConfig(
        raceId: race.id,
        name: 'Alternate Distance',
        distanceMiles: 3.4,
      );

      await raceService.importRoster(
        const RosterImport(
          sourceName: 'week1.xlsx',
          runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Jordan')],
        ),
      );
      final lookup = await raceService.lookupRunnerForCheckIn('Jordan');

      await raceService.updateRosterEntry(
        runnerId: lookup.selectedMatch!.runner.id,
        entryId: lookup.selectedMatch!.entry.id,
        name: 'Jordan',
        barcodeValue: lookup.selectedMatch!.entry.barcodeValue,
        paymentStatus: PaymentStatus.paid,
        raceDistanceId: alternateDistance.id,
        elapsedTimeMs: RaceService.parseElapsed('44:12.0'),
        paceOverride: '13:00/M',
      );

      final results = await raceService.getResults(race.id);

      expect(results.single.distanceName, 'Alternate Distance');
      expect(results.single.distanceMiles, 3.4);
      expect(results.single.paceOverride, '13:00/M');
      expect(results.single.elapsedTimeMs, RaceService.parseElapsed('44:12.0'));
      expect(fullDistance.sectionLabel, 'Full Distance - 5 miles');
    },
  );

  test(
    'printCheckInMatch returns a printer warning but keeps the barcode',
    () async {
      await raceService.createRace(name: 'Spring 5K');
      await raceService.importRoster(
        const RosterImport(
          sourceName: 'spring.xlsx',
          runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Casey')],
        ),
      );
      printerService.status = PrinterStatus.error(message: 'Printer offline');

      final lookup = await raceService.lookupRunnerForCheckIn('Casey');
      final result = await raceService.printCheckInMatch(lookup.selectedMatch!);
      final race = await raceService.getCurrentRace();
      final roster = await raceService.listCheckInRoster(race!);

      expect(result.outcome, CheckInOutcome.printerWarning);
      expect(result.selectedMatch?.entry.barcodeValue, isNotEmpty);
      expect(roster.single.rosterStatus, CheckInRosterStatus.inRace);
    },
  );

  test('lookupRunnerForCheckIn prefers a unique exact-name match', () async {
    await raceService.createRace(name: 'Spring 5K');
    await raceService.importRoster(
      const RosterImport(
        sourceName: 'spring.xlsx',
        runners: <ImportedRunnerData>[
          ImportedRunnerData(name: 'Jordan'),
          ImportedRunnerData(name: 'Jordan Lee'),
        ],
      ),
    );

    final lookup = await raceService.lookupRunnerForCheckIn('Jordan');

    expect(lookup.outcome, CheckInOutcome.ready);
    expect(lookup.selectedMatch?.runner.name, 'Jordan');
  });

  test('createAdHocRunnerAndPrint creates a runner and race entry', () async {
    await raceService.createRace(name: 'Spring 5K');

    final result = await raceService.createAdHocRunnerAndPrint('Morgan Diaz');
    final lookup = await raceService.lookupRunnerForCheckIn('Morgan Diaz');

    expect(result.outcome, CheckInOutcome.printed);
    expect(lookup.selectedMatch?.runner.name, 'Morgan Diaz');
    expect(lookup.selectedMatch?.entry.barcodeValue, 'RT-000001');
  });

  test('awardPointsToRunner adds to an existing saved total', () async {
    final race = await raceService.createRace(name: 'Week 1');
    await raceService.importRoster(
      const RosterImport(
        sourceName: 'week1.xlsx',
        runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Casey Lee')],
      ),
    );
    final lookup = await raceService.lookupRunnerForCheckIn('Casey Lee');

    final firstAward = await raceService.awardPointsToRunner(
      raceId: race.id,
      runnerId: lookup.selectedMatch!.runner.id,
      points: 10,
    );
    final secondAward = await raceService.awardPointsToRunner(
      raceId: race.id,
      runnerId: lookup.selectedMatch!.runner.id,
      points: 5,
    );
    final summaries = await raceService.listRaceRunnerPointsSummaries(race.id);

    expect(firstAward.totalPoints, 10);
    expect(secondAward.totalPoints, 15);
    expect(secondAward.pointsInRace, 15);
    expect(summaries.single.totalPoints, 15);
  });

  test(
    'adjustRunnerPoints can add and subtract from the overall total',
    () async {
      final race = await raceService.createRace(name: 'Week 1');
      await raceService.importRoster(
        const RosterImport(
          sourceName: 'week1.xlsx',
          runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Casey Lee')],
        ),
      );
      final lookup = await raceService.lookupRunnerForCheckIn('Casey Lee');
      final runnerId = lookup.selectedMatch!.runner.id;

      final added = await raceService.adjustRunnerPoints(
        raceId: race.id,
        runnerId: runnerId,
        pointsDelta: 12,
      );
      final removed = await raceService.adjustRunnerPoints(
        raceId: race.id,
        runnerId: runnerId,
        pointsDelta: -5,
      );

      expect(added.totalPoints, 12);
      expect(removed.totalPoints, 7);
    },
  );

  test(
    'createAdHocRunnerAndPrint reuses an existing runner barcode in a new race',
    () async {
      await raceService.createRace(name: 'Week 1');
      await raceService.importRoster(
        const RosterImport(
          sourceName: 'week1.xlsx',
          runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Casey Lee')],
        ),
      );
      final firstLookup = await raceService.lookupRunnerForCheckIn('Casey Lee');

      await raceService.createRace(name: 'Week 2');
      final result = await raceService.createAdHocRunnerAndPrint('Casey Lee');
      final secondLookup = await raceService.lookupRunnerForCheckIn(
        'Casey Lee',
      );

      expect(result.outcome, CheckInOutcome.printed);
      expect(
        secondLookup.selectedMatch?.entry.barcodeValue,
        firstLookup.selectedMatch?.entry.barcodeValue,
      );
    },
  );

  test('parseBulkRaceDates reads and deduplicates common date formats', () {
    final dates = raceService.parseBulkRaceDates(
      '2026-03-28\n03/28/2026\nApr 4, 2026',
    );

    expect(dates, hasLength(2));
    expect(dates.first, DateTime(2026, 3, 28));
    expect(dates.last, DateTime(2026, 4, 4));
  });

  test('createRacesFromDates creates races and skips duplicates', () async {
    final dates = raceService.parseBulkRaceDates('2026-03-28\n2026-04-04');

    final firstResult = await raceService.createRacesFromDates(
      namePrefix: 'Saturday Park Run',
      seriesName: 'Spring Series',
      dates: dates,
    );
    final secondResult = await raceService.createRacesFromDates(
      namePrefix: 'Saturday Park Run',
      seriesName: 'Spring Series',
      dates: dates,
    );

    expect(firstResult.createdCount, 2);
    expect(firstResult.skippedCount, 0);
    expect(secondResult.createdCount, 0);
    expect(secondResult.skippedCount, 2);
  });

  test(
    'createRacesFromSchedule creates races from imported file rows and fallback names',
    () async {
      final result = await raceService.createRacesFromSchedule(
        fallbackNamePrefix: 'Saturday Park Run',
        fallbackSeriesName: 'Spring Series',
        entries: <ImportedRaceScheduleEntry>[
          ImportedRaceScheduleEntry(
            raceDate: DateTime(2026, 3, 28),
            raceName: 'Opening Day 5K',
          ),
          ImportedRaceScheduleEntry(raceDate: DateTime(2026, 4, 4)),
        ],
      );

      final races = await raceService.listRaces();

      expect(result.createdCount, 2);
      expect(races.any((race) => race.name == 'Opening Day 5K'), isTrue);
      expect(
        races.any((race) => race.name == 'Saturday Park Run - Apr 4, 2026'),
        isTrue,
      );
      expect(races.every((race) => race.seriesName == 'Spring Series'), isTrue);
    },
  );

  test('getRaceScheduledForDate finds the race on that day', () async {
    final marchRace = await raceService.createRace(
      name: 'Saturday Park Run - Mar 28, 2026',
      raceDate: DateTime(2026, 3, 28),
    );
    await raceService.createRace(
      name: 'Saturday Park Run - Apr 4, 2026',
      raceDate: DateTime(2026, 4, 4),
    );

    final selectedRace = await raceService.getRaceScheduledForDate(
      DateTime(2026, 3, 28, 15),
    );

    expect(selectedRace?.id, marchRace.id);
  });

  test('startCurrentRaceFromScanner starts the selected race', () async {
    final race = await raceService.createRace(name: 'Spring 5K');
    await settingsService.saveSettings(
      AppSettings.defaults().copyWith(selectedRaceId: race.id),
    );

    final result = await raceService.startCurrentRaceFromScanner();

    expect(result.status, FinishScanStatus.raceStarted);
    expect(result.startTime, isNotNull);
  });

  test('printCheckInMatches prints the roster row by row', () async {
    final race = await raceService.createRace(name: 'Spring 5K');
    await raceService.importRoster(
      const RosterImport(
        sourceName: 'spring.xlsx',
        runners: <ImportedRunnerData>[
          ImportedRunnerData(name: 'Casey'),
          ImportedRunnerData(name: 'Jordan'),
        ],
      ),
    );

    final rosterBefore = await raceService.listCheckInRoster(race);
    final result = await raceService.printCheckInMatches(rosterBefore);
    final rosterAfter = await raceService.listCheckInRoster(race);

    expect(result.outcome, CheckInOutcome.printed);
    expect(result.printedCount, 2);
    expect(result.warningCount, 0);
    expect(
      rosterAfter.every(
        (match) => match.rosterStatus == CheckInRosterStatus.inRace,
      ),
      isTrue,
    );
  });

  test('recordFinish requires the race to be started', () async {
    await raceService.createRace(name: 'Spring 5K');
    await raceService.importRoster(
      const RosterImport(
        sourceName: 'spring.xlsx',
        runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Morgan')],
      ),
    );
    final lookup = await raceService.lookupRunnerForCheckIn('Morgan');

    final result = await raceService.recordFinish(
      lookup.selectedMatch!.entry.barcodeValue,
    );

    expect(result.status, FinishScanStatus.raceNotStarted);
  });

  test(
    'recordRunnerScan treats a pre-start runner scan as an early start',
    () async {
      final race = await raceService.createRace(name: 'Spring 5K');
      await raceService.importRoster(
        const RosterImport(
          sourceName: 'spring.xlsx',
          runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Morgan')],
        ),
      );
      final lookup = await raceService.lookupRunnerForCheckIn('Morgan');
      final barcode = lookup.selectedMatch!.entry.barcodeValue;

      final earlyStart = await raceService.recordRunnerScan(barcode);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await raceService.startRace(race.id);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final finish = await raceService.recordRunnerScan(barcode);
      final results = await raceService.getResults(race.id);

      expect(earlyStart.status, FinishScanStatus.earlyStartRecorded);
      expect(finish.status, FinishScanStatus.success);
      expect(results.single.earlyStart, isTrue);
      expect(
        results.single.startTime?.millisecondsSinceEpoch,
        earlyStart.startTime?.millisecondsSinceEpoch,
      );
      final expectedElapsed = finish.finishTime!
          .difference(earlyStart.startTime!)
          .inMilliseconds;
      expect(
        finish.elapsedTimeMs,
        inInclusiveRange(expectedElapsed - 5, expectedElapsed + 5),
      );
    },
  );

  test(
    'recordEarlyStart stores a personal start used for finish timing',
    () async {
      final race = await raceService.createRace(name: 'Spring 5K');
      await raceService.importRoster(
        const RosterImport(
          sourceName: 'spring.xlsx',
          runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Morgan')],
        ),
      );
      final lookup = await raceService.lookupRunnerForCheckIn('Morgan');
      final barcode = lookup.selectedMatch!.entry.barcodeValue;

      final earlyStart = await raceService.recordEarlyStart(barcode);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await raceService.startRace(race.id);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final finish = await raceService.recordFinish(barcode);
      final results = await raceService.getResults(race.id);

      expect(earlyStart.status, FinishScanStatus.earlyStartRecorded);
      expect(finish.status, FinishScanStatus.success);
      expect(results.single.earlyStart, isTrue);
      expect(
        results.single.startTime?.millisecondsSinceEpoch,
        earlyStart.startTime?.millisecondsSinceEpoch,
      );
      final expectedElapsed = finish.finishTime!
          .difference(earlyStart.startTime!)
          .inMilliseconds;
      expect(
        finish.elapsedTimeMs,
        inInclusiveRange(expectedElapsed - 5, expectedElapsed + 5),
      );
    },
  );

  test('global start does not overwrite existing early starts', () async {
    final race = await raceService.createRace(name: 'Spring 5K');
    await raceService.importRoster(
      const RosterImport(
        sourceName: 'spring.xlsx',
        runners: <ImportedRunnerData>[
          ImportedRunnerData(name: 'Morgan'),
          ImportedRunnerData(name: 'Riley'),
        ],
      ),
    );
    final earlyLookup = await raceService.lookupRunnerForCheckIn('Morgan');
    final regularLookup = await raceService.lookupRunnerForCheckIn('Riley');
    final earlyBarcode = earlyLookup.selectedMatch!.entry.barcodeValue;
    final regularBarcode = regularLookup.selectedMatch!.entry.barcodeValue;

    final earlyStart = await raceService.recordRunnerScan(earlyBarcode);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final startedRace = await raceService.startRace(race.id);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final earlyFinish = await raceService.recordRunnerScan(earlyBarcode);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final regularFinish = await raceService.recordRunnerScan(regularBarcode);
    final results = await raceService.getResults(race.id);
    final earlyRow = results.firstWhere((row) => row.runnerName == 'Morgan');
    final regularRow = results.firstWhere((row) => row.runnerName == 'Riley');

    expect(earlyStart.status, FinishScanStatus.earlyStartRecorded);
    expect(earlyFinish.status, FinishScanStatus.success);
    expect(regularFinish.status, FinishScanStatus.success);
    expect(earlyRow.earlyStart, isTrue);
    expect(
      earlyRow.startTime?.millisecondsSinceEpoch,
      earlyStart.startTime?.millisecondsSinceEpoch,
    );
    final expectedEarlyElapsed = earlyFinish.finishTime!
        .difference(earlyStart.startTime!)
        .inMilliseconds;
    expect(
      earlyFinish.elapsedTimeMs,
      inInclusiveRange(expectedEarlyElapsed - 5, expectedEarlyElapsed + 5),
    );

    final expectedRegularElapsed = regularFinish.finishTime!
        .difference(startedRace.gunTime!)
        .inMilliseconds;
    expect(regularRow.earlyStart, isFalse);
    expect(
      regularFinish.elapsedTimeMs,
      inInclusiveRange(expectedRegularElapsed - 5, expectedRegularElapsed + 5),
    );
  });

  test('recordFinish rejects duplicate scans', () async {
    final race = await raceService.createRace(name: 'Spring 5K');
    await raceService.importRoster(
      const RosterImport(
        sourceName: 'spring.xlsx',
        runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Riley')],
      ),
    );
    final lookup = await raceService.lookupRunnerForCheckIn('Riley');
    await raceService.startRace(race.id);

    final firstScan = await raceService.recordFinish(
      lookup.selectedMatch!.entry.barcodeValue,
    );
    final secondScan = await raceService.recordFinish(
      lookup.selectedMatch!.entry.barcodeValue,
    );

    expect(firstScan.status, FinishScanStatus.success);
    expect(secondScan.status, FinishScanStatus.duplicateScan);

    final events = await databaseService.listScanEvents(raceId: race.id);
    expect(events.first.eventType, ScanEventType.duplicateScan);
    expect(events.first.message, contains('first finish time was kept'));
  });

  test(
    'recordFinish accepts barcode scans with different letter casing',
    () async {
      final race = await raceService.createRace(name: 'Spring 5K');
      await raceService.importRoster(
        const RosterImport(
          sourceName: 'spring.xlsx',
          runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Skyler')],
        ),
      );
      await raceService.startRace(race.id);

      final result = await raceService.recordFinish('rt-000001');

      expect(result.status, FinishScanStatus.success);
      expect(result.runnerName, 'Skyler');
    },
  );

  test('recordFinish warns and logs unknown barcodes', () async {
    final race = await raceService.createRace(name: 'Spring 5K');
    await raceService.startRace(race.id);

    final result = await raceService.recordFinish('RT-404');
    final events = await databaseService.listScanEvents(raceId: race.id);

    expect(result.status, FinishScanStatus.unknownBarcode);
    expect(result.message, contains('RT-404'));
    expect(events.first.eventType, ScanEventType.unknownBarcode);
  });

  test('recordFinish updates the rider status to race completed', () async {
    final race = await raceService.createRace(name: 'Spring 5K');
    await raceService.importRoster(
      const RosterImport(
        sourceName: 'spring.xlsx',
        runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Riley')],
      ),
    );
    final lookup = await raceService.lookupRunnerForCheckIn('Riley');
    await raceService.startRace(race.id);

    await raceService.recordFinish(lookup.selectedMatch!.entry.barcodeValue);
    final roster = await raceService.listCheckInRoster(race);

    expect(roster.single.rosterStatus, CheckInRosterStatus.raceCompleted);
  });

  test('endRace stores a final total when volunteers stop the timer', () async {
    final race = await raceService.createRace(name: 'Spring 5K');
    await raceService.startRace(race.id);

    final endedRace = await raceService.endRace(race.id);

    expect(endedRace.isFinished, isTrue);
    expect(endedRace.gunTime, isNotNull);
    expect(endedRace.endTime, isNotNull);
    expect(endedRace.totalElapsedTimeMs, isNotNull);
    expect(endedRace.totalElapsedTimeMs, greaterThanOrEqualTo(0));
  });

  test('ending the race shows checked-in riders as race completed', () async {
    final race = await raceService.createRace(name: 'Spring 5K');
    await raceService.importRoster(
      const RosterImport(
        sourceName: 'spring.xlsx',
        runners: <ImportedRunnerData>[ImportedRunnerData(name: 'Taylor')],
      ),
    );
    final lookup = await raceService.lookupRunnerForCheckIn('Taylor');
    await raceService.printCheckInMatch(lookup.selectedMatch!);
    await raceService.startRace(race.id);

    final endedRace = await raceService.endRace(race.id);
    final roster = await raceService.listCheckInRoster(endedRace);

    expect(roster.single.rosterStatus, CheckInRosterStatus.raceCompleted);
  });
}
