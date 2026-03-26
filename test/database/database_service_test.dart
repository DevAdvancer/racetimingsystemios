import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/database/database_helper.dart';
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
}
