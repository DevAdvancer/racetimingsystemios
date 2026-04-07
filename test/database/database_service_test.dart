import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/database/database_helper.dart';
import 'package:race_timer/models/overall_runner_points_summary.dart';
import 'package:race_timer/models/race_status.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/models/scan_event_log.dart';
import 'package:race_timer/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseHelper helper;
  late DatabaseService service;

  setUp(() async {
    sqfliteFfiInit();
    helper = DatabaseHelper.forTesting(databaseFactory: databaseFactoryFfi);
    await helper.ensureInitialized();
    service = DatabaseService(helper);
  });

  tearDown(() async {
    await helper.close();
  });

  test('prefers a running race over a pending race as current race', () async {
    final pending = await service.createRace(name: 'Morning 5K');
    final running = await service.createRace(name: 'Evening 5K');

    await service.updateRace(
      running.copyWith(
        status: RaceStatus.running,
        gunTime: DateTime.now().toUtc(),
      ),
    );

    final currentRace = await service.getCurrentRace();

    expect(currentRace?.id, running.id);
    expect(currentRace?.name, isNot(pending.name));
  });

  test('persists a finished race end time and total duration', () async {
    final race = await service.createRace(name: 'Morning 5K');
    final gunTime = DateTime.utc(2026, 3, 18, 10, 0, 0);
    final endTime = DateTime.utc(2026, 3, 18, 10, 42, 15, 500);

    await service.updateRace(
      race.copyWith(
        status: RaceStatus.finished,
        gunTime: gunTime,
        endTime: endTime,
      ),
    );

    final storedRace = await service.getRace(race.id);

    expect(storedRace?.endTime, endTime);
    expect(storedRace?.totalElapsedTimeMs, 2535500);
  });

  test('stores race dates and series metadata locally', () async {
    final raceDate = DateTime.utc(2026, 3, 19);
    final race = await service.createRace(
      name: 'Morning 5K',
      raceDate: raceDate,
      seriesName: 'City Series',
    );

    final storedRace = await service.getRace(race.id);

    expect(storedRace?.raceDate, raceDate);
    expect(storedRace?.seriesName, 'City Series');
  });

  test('finds a race scheduled for a specific local day directly', () async {
    await service.createRace(name: 'Week 1', raceDate: DateTime(2026, 3, 28));
    final weekTwo = await service.createRace(
      name: 'Week 2',
      raceDate: DateTime(2026, 4, 4),
    );

    final scheduledRace = await service.getRaceScheduledForDate(
      DateTime(2026, 4, 4, 17, 30),
    );

    expect(scheduledRace?.id, weekTwo.id);
  });

  test('enforces unique barcodes at the runner level', () async {
    await service.createRunner(name: 'Alice', barcodeValue: 'RT-000001');

    expect(
      () => service.createRunner(name: 'Bob', barcodeValue: 'RT-000001'),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'allows the same runner barcode to be reused across race entries',
    () async {
      final raceA = await service.createRace(name: 'Race A');
      final raceB = await service.createRace(name: 'Race B');
      final runner = await service.createRunner(
        name: 'Alice',
        barcodeValue: 'RT-000001',
      );

      await service.createRaceEntry(
        runnerId: runner.id,
        raceId: raceA.id,
        barcodeValue: runner.barcodeValue,
      );

      final secondEntry = await service.createRaceEntry(
        runnerId: runner.id,
        raceId: raceB.id,
        barcodeValue: runner.barcodeValue,
      );

      expect(secondEntry.barcodeValue, runner.barcodeValue);
    },
  );

  test('persists payment and membership status for runners', () async {
    final runner = await service.createRunner(
      name: 'Alice',
      barcodeValue: 'RT-000010',
      paymentStatus: PaymentStatus.pending,
      membershipStatus: MembershipStatus.member,
    );

    final storedRunner = await service.getRunner(runner.id);

    expect(storedRunner?.paymentStatus, PaymentStatus.pending);
    expect(storedRunner?.membershipStatus, MembershipStatus.member);
    expect(storedRunner?.paid, isFalse);
  });

  test('persists extended racer profile and race entry fields', () async {
    final race = await service.createRace(name: 'Race A');
    final runner = await service.createRunner(
      name: 'Alice',
      barcodeValue: 'RT-000010',
      city: 'Southbury',
      gender: 'F',
      paymentStatus: PaymentStatus.pending,
    );

    await service.createRaceEntry(
      runnerId: runner.id,
      raceId: race.id,
      barcodeValue: runner.barcodeValue,
      bibNumber: '822',
      age: 39,
    );

    final storedRunner = await service.getRunner(runner.id);
    final results = await service.getRaceResults(race.id);

    expect(storedRunner?.city, 'Southbury');
    expect(storedRunner?.gender, 'F');
    expect(results.single.bibNumber, '822');
    expect(results.single.age, 39);
  });

  test(
    'updating a runner barcode propagates to all saved race entries',
    () async {
      final raceA = await service.createRace(name: 'Race A');
      final raceB = await service.createRace(name: 'Race B');
      final runner = await service.createRunner(
        name: 'Alice',
        barcodeValue: 'RT-000001',
      );

      await service.createRaceEntry(
        runnerId: runner.id,
        raceId: raceA.id,
        barcodeValue: runner.barcodeValue,
      );
      await service.createRaceEntry(
        runnerId: runner.id,
        raceId: raceB.id,
        barcodeValue: runner.barcodeValue,
      );

      await service.updateRunnerBarcode(
        runnerId: runner.id,
        barcodeValue: 'RT-009999',
      );

      final firstEntry = await service.getRaceEntryForRunner(
        runnerId: runner.id,
        raceId: raceA.id,
      );
      final secondEntry = await service.getRaceEntryForRunner(
        runnerId: runner.id,
        raceId: raceB.id,
      );

      expect(firstEntry?.barcodeValue, 'RT-009999');
      expect(secondEntry?.barcodeValue, 'RT-009999');
    },
  );

  test('stores scan event logs in the local database', () async {
    final race = await service.createRace(name: 'Race A');

    await service.logScanEvent(
      raceId: race.id,
      barcodeValue: 'RT-404',
      eventType: ScanEventType.unknownBarcode,
      severity: ScanEventSeverity.warning,
      message: 'Barcode "RT-404" is not in the active race roster.',
    );

    final events = await service.listScanEvents(raceId: race.id);

    expect(events, hasLength(1));
    expect(events.single.eventType, ScanEventType.unknownBarcode);
    expect(events.single.message, contains('RT-404'));
  });

  test(
    'stores alternate distance configs and links them to race entries',
    () async {
      final race = await service.createRace(name: 'Squire Road');
      final fullDistance = await service.createRaceDistanceConfig(
        raceId: race.id,
        name: 'Full Distance',
        distanceMiles: 5,
        isPrimary: true,
      );
      await service.createRaceDistanceConfig(
        raceId: race.id,
        name: 'Alternate Distance',
        distanceMiles: 3.4,
      );
      final runner = await service.createRunner(
        name: 'Alice',
        barcodeValue: 'RT-000010',
      );

      await service.createRaceEntry(
        runnerId: runner.id,
        raceId: race.id,
        barcodeValue: runner.barcodeValue,
        raceDistanceId: fullDistance.id,
        paceOverride: '8:05/M',
      );

      final configs = await service.listRaceDistanceConfigs(race.id);
      final results = await service.getRaceResults(race.id);

      expect(configs, hasLength(2));
      expect(configs.first.isPrimary, isTrue);
      expect(results.single.distanceName, 'Full Distance');
      expect(results.single.distanceMiles, 5);
      expect(results.single.paceOverride, '8:05/M');
    },
  );

  test('stores cumulative runner points and race-specific totals', () async {
    final race = await service.createRace(name: 'Race A');
    final laterRace = await service.createRace(name: 'Race B');
    final runner = await service.createRunner(
      name: 'Alice',
      barcodeValue: 'RT-000001',
    );

    await service.createRaceEntry(
      runnerId: runner.id,
      raceId: race.id,
      barcodeValue: runner.barcodeValue,
    );
    await service.createRaceEntry(
      runnerId: runner.id,
      raceId: laterRace.id,
      barcodeValue: runner.barcodeValue,
    );

    await service.awardRunnerPoints(
      runnerId: runner.id,
      raceId: race.id,
      points: 10,
    );
    await service.awardRunnerPoints(
      runnerId: runner.id,
      raceId: race.id,
      points: 5,
    );
    await service.awardRunnerPoints(
      runnerId: runner.id,
      raceId: laterRace.id,
      points: 7,
    );

    final raceSummary = await service.getRaceRunnerPointsSummary(
      raceId: race.id,
      runnerId: runner.id,
    );
    final laterRaceSummary = await service.getRaceRunnerPointsSummary(
      raceId: laterRace.id,
      runnerId: runner.id,
    );

    expect(raceSummary?.pointsInRace, 15);
    expect(raceSummary?.totalPoints, 22);
    expect(raceSummary?.awardCount, 3);
    expect(raceSummary?.lastAwardedAt, isNotNull);
    expect(laterRaceSummary?.pointsInRace, 7);
    expect(laterRaceSummary?.totalPoints, 22);
  });

  test('lists overall runner points across all races', () async {
    final race = await service.createRace(name: 'Race A');
    final latestRace = await service.createRace(name: 'Race B');
    final runner = await service.createRunner(
      name: 'Alice',
      barcodeValue: 'RT-000001',
    );

    await service.createRaceEntry(
      runnerId: runner.id,
      raceId: race.id,
      barcodeValue: runner.barcodeValue,
    );
    await service.createRaceEntry(
      runnerId: runner.id,
      raceId: latestRace.id,
      barcodeValue: runner.barcodeValue,
    );

    await service.awardRunnerPoints(
      runnerId: runner.id,
      raceId: race.id,
      points: 4,
    );
    await service.awardRunnerPoints(
      runnerId: runner.id,
      raceId: latestRace.id,
      points: 9,
    );

    final summaries = await service.listOverallRunnerPointsSummaries();
    final summary = summaries.single;

    expect(summaries, isA<List<OverallRunnerPointsSummary>>());
    expect(summary.totalPoints, 13);
    expect(summary.awardCount, 2);
    expect(summary.latestRaceName, 'Race B');
    expect(summary.lastAwardedAt, isNotNull);
  });
}
