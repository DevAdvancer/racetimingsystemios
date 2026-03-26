import 'package:race_timer/database/database_helper.dart';
import 'package:race_timer/models/check_in_match.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_entry.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/models/race_status.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/models/scan_event_log.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  DatabaseService(this._helper);

  final DatabaseHelper _helper;

  Future<T> transaction<T>(
    Future<T> Function(DatabaseExecutor executor) action,
  ) async {
    final db = await _helper.database;
    return db.transaction(action);
  }

  Future<DatabaseExecutor> _resolveExecutor(DatabaseExecutor? executor) async {
    if (executor != null) {
      return executor;
    }
    return _helper.database;
  }

  Future<bool> runQuickCheck() async {
    final db = await _helper.database;
    final result = await db.rawQuery('PRAGMA quick_check;');
    return result.isNotEmpty && result.first.values.first == 'ok';
  }

  Future<void> resetAllData() => _helper.resetDatabase();

  static String normalizeName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<List<Race>> listRaces() async {
    final db = await _helper.database;
    final rows = await db.query('races', orderBy: 'created_at DESC');
    return rows.map(Race.fromMap).toList();
  }

  Future<Race?> getCurrentRace() async {
    final db = await _helper.database;

    final running = await db.query(
      'races',
      where: 'status = ?',
      whereArgs: <Object?>[RaceStatus.running.dbValue],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (running.isNotEmpty) {
      return Race.fromMap(running.first);
    }

    final pending = await db.query(
      'races',
      where: 'status = ?',
      whereArgs: <Object?>[RaceStatus.pending.dbValue],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (pending.isEmpty) {
      return null;
    }
    return Race.fromMap(pending.first);
  }

  Future<Race?> getRunningRace() async {
    final db = await _helper.database;
    final rows = await db.query(
      'races',
      where: 'status = ?',
      whereArgs: <Object?>[RaceStatus.running.dbValue],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Race.fromMap(rows.first);
  }

  Future<Race?> getRace(int id) async {
    final db = await _helper.database;
    final rows = await db.query(
      'races',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Race.fromMap(rows.first);
  }

  Future<Race> createRace({
    required String name,
    DateTime? raceDate,
    String? seriesName,
    int entryFeeMinor = 0,
    String currencyCode = 'USD',
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final createdAt = DateTime.now().toUtc();
    final resolvedRaceDate = (raceDate ?? createdAt).toUtc();
    final id = await db.insert('races', <String, Object?>{
      'name': name,
      'race_date': resolvedRaceDate.millisecondsSinceEpoch,
      'gun_time': null,
      'end_time': null,
      'status': RaceStatus.pending.dbValue,
      'series_name': _normalizeOptionalText(seriesName),
      'created_at': createdAt.millisecondsSinceEpoch,
      'entry_fee_minor': entryFeeMinor,
      'currency_code': currencyCode.toUpperCase(),
    });
    return Race(
      id: id,
      name: name,
      raceDate: resolvedRaceDate,
      gunTime: null,
      endTime: null,
      status: RaceStatus.pending,
      seriesName: _normalizeOptionalText(seriesName),
      createdAt: createdAt,
      entryFeeMinor: entryFeeMinor,
      currencyCode: currencyCode.toUpperCase(),
    );
  }

  Future<Race> updateRace(Race race, {DatabaseExecutor? executor}) async {
    final db = await _resolveExecutor(executor);
    await db.update(
      'races',
      <String, Object?>{
        'name': race.name,
        'race_date': race.raceDate.toUtc().millisecondsSinceEpoch,
        'gun_time': race.gunTime?.toUtc().millisecondsSinceEpoch,
        'end_time': race.endTime?.toUtc().millisecondsSinceEpoch,
        'status': race.status.dbValue,
        'series_name': _normalizeOptionalText(race.seriesName),
        'created_at': race.createdAt.toUtc().millisecondsSinceEpoch,
        'entry_fee_minor': race.entryFeeMinor,
        'currency_code': race.currencyCode.toUpperCase(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[race.id],
    );
    return race;
  }

  Future<Runner> createRunner({
    required String name,
    String? barcodeValue,
    String? stripePaymentId,
    bool paid = true,
    PaymentStatus? paymentStatus,
    MembershipStatus membershipStatus = MembershipStatus.unknown,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final createdAt = DateTime.now().toUtc();
    final resolvedPaymentStatus =
        paymentStatus ?? (paid ? PaymentStatus.paid : PaymentStatus.pending);
    final id = await db.insert('runners', <String, Object?>{
      'name': name.trim(),
      'normalized_name': normalizeName(name),
      'barcode_value':
          barcodeValue ??
          'pending-${createdAt.millisecondsSinceEpoch}-${name.hashCode}',
      'stripe_payment_id': stripePaymentId,
      'paid': resolvedPaymentStatus.countsAsPaid ? 1 : 0,
      'payment_status': resolvedPaymentStatus.dbValue,
      'membership_status': membershipStatus.dbValue,
      'created_at': createdAt.millisecondsSinceEpoch,
    });
    return Runner(
      id: id,
      name: name.trim(),
      barcodeValue:
          barcodeValue ??
          'pending-${createdAt.millisecondsSinceEpoch}-${name.hashCode}',
      stripePaymentId: stripePaymentId,
      paymentStatus: resolvedPaymentStatus,
      membershipStatus: membershipStatus,
      createdAt: createdAt,
    );
  }

  Future<Runner> updateRunnerStatuses({
    required int runnerId,
    PaymentStatus? paymentStatus,
    MembershipStatus? membershipStatus,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final runner = await getRunner(runnerId, executor: db);
    if (runner == null) {
      throw StateError('Runner record could not be found.');
    }

    final resolvedPaymentStatus = paymentStatus ?? runner.paymentStatus;
    final resolvedMembershipStatus =
        membershipStatus ?? runner.membershipStatus;

    await db.update(
      'runners',
      <String, Object?>{
        'paid': resolvedPaymentStatus.countsAsPaid ? 1 : 0,
        'payment_status': resolvedPaymentStatus.dbValue,
        'membership_status': resolvedMembershipStatus.dbValue,
      },
      where: 'id = ?',
      whereArgs: <Object?>[runnerId],
    );
    return (await getRunner(runnerId, executor: db))!;
  }

  Future<Runner> updateRunnerBarcode({
    required int runnerId,
    required String barcodeValue,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    await db.update(
      'runners',
      <String, Object?>{'barcode_value': barcodeValue},
      where: 'id = ?',
      whereArgs: <Object?>[runnerId],
    );
    final runner = await getRunner(runnerId, executor: db);
    return runner!;
  }

  Future<Runner?> getRunner(int id, {DatabaseExecutor? executor}) async {
    final db = await _resolveExecutor(executor);
    final rows = await db.query(
      'runners',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Runner.fromMap(rows.first);
  }

  Future<Runner?> getRunnerByNormalizedName(
    String normalizedName, {
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final rows = await db.query(
      'runners',
      where: 'normalized_name = ?',
      whereArgs: <Object?>[normalizeName(normalizedName)],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Runner.fromMap(rows.first);
  }

  Future<Runner?> getRunnerByBarcode(
    String barcodeValue, {
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final trimmedBarcode = barcodeValue.trim();
    if (trimmedBarcode.isEmpty) {
      return null;
    }

    var rows = await db.query(
      'runners',
      where: 'barcode_value = ?',
      whereArgs: <Object?>[trimmedBarcode],
      limit: 1,
    );
    if (rows.isEmpty) {
      rows = await db.query(
        'runners',
        where: 'UPPER(barcode_value) = ?',
        whereArgs: <Object?>[trimmedBarcode.toUpperCase()],
        limit: 1,
      );
    }
    if (rows.isEmpty) {
      return null;
    }
    return Runner.fromMap(rows.first);
  }

  Future<RaceEntry> createRaceEntry({
    required int runnerId,
    required int raceId,
    required String barcodeValue,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final id = await db.insert('race_entries', <String, Object?>{
      'runner_id': runnerId,
      'race_id': raceId,
      'barcode_value': barcodeValue,
      'checked_in_at': null,
      'start_time': null,
      'early_start': 0,
      'finish_time': null,
      'elapsed_time_ms': null,
    });
    return RaceEntry(
      id: id,
      runnerId: runnerId,
      raceId: raceId,
      barcodeValue: barcodeValue,
      checkedInAt: null,
      startTime: null,
      earlyStart: false,
      finishTime: null,
      elapsedTimeMs: null,
    );
  }

  Future<RaceEntry> updateEntryBarcode({
    required int entryId,
    required String barcodeValue,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    await db.update(
      'race_entries',
      <String, Object?>{'barcode_value': barcodeValue},
      where: 'id = ?',
      whereArgs: <Object?>[entryId],
    );
    final entry = await getEntry(entryId, executor: db);
    return entry!;
  }

  Future<RaceEntry?> getEntry(int id, {DatabaseExecutor? executor}) async {
    final db = await _resolveExecutor(executor);
    final rows = await db.query(
      'race_entries',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return RaceEntry.fromMap(rows.first);
  }

  Future<RaceEntry?> getEntryByBarcodeForRace({
    required int raceId,
    required String barcodeValue,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final trimmedBarcode = barcodeValue.trim();
    var rows = await db.query(
      'race_entries',
      where: 'race_id = ? AND barcode_value = ?',
      whereArgs: <Object?>[raceId, trimmedBarcode],
      limit: 1,
    );
    if (rows.isEmpty) {
      rows = await db.query(
        'race_entries',
        where: 'race_id = ? AND UPPER(barcode_value) = ?',
        whereArgs: <Object?>[raceId, trimmedBarcode.toUpperCase()],
        limit: 1,
      );
    }
    if (rows.isEmpty) {
      return null;
    }
    return RaceEntry.fromMap(rows.first);
  }

  Future<RaceEntry?> getRaceEntryForRunner({
    required int runnerId,
    required int raceId,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final rows = await db.query(
      'race_entries',
      where: 'runner_id = ? AND race_id = ?',
      whereArgs: <Object?>[runnerId, raceId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return RaceEntry.fromMap(rows.first);
  }

  Future<RaceEntry> finishRaceEntry({
    required int entryId,
    required DateTime finishTime,
    required int elapsedTimeMs,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final existing = await getEntry(entryId, executor: db);
    if (existing == null) {
      throw StateError('Race entry not found.');
    }
    await db.update(
      'race_entries',
      <String, Object?>{
        'checked_in_at':
            existing.checkedInAt?.toUtc().millisecondsSinceEpoch ??
            finishTime.toUtc().millisecondsSinceEpoch,
        'finish_time': finishTime.toUtc().millisecondsSinceEpoch,
        'elapsed_time_ms': elapsedTimeMs,
      },
      where: 'id = ?',
      whereArgs: <Object?>[entryId],
    );
    final updated = await getEntry(entryId, executor: db);
    return updated!;
  }

  Future<RaceEntry> checkInRaceEntry({
    required int entryId,
    DateTime? checkedInAt,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final existing = await getEntry(entryId, executor: db);
    if (existing == null) {
      throw StateError('Race entry not found.');
    }
    if (existing.checkedInAt != null) {
      return existing;
    }

    final timestamp = checkedInAt ?? DateTime.now().toUtc();
    await db.update(
      'race_entries',
      <String, Object?>{
        'checked_in_at': timestamp.toUtc().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[entryId],
    );
    final updated = await getEntry(entryId, executor: db);
    return updated!;
  }

  Future<RaceEntry> markEarlyStart({
    required int entryId,
    required DateTime startTime,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final existing = await getEntry(entryId, executor: db);
    if (existing == null) {
      throw StateError('Race entry not found.');
    }

    await db.update(
      'race_entries',
      <String, Object?>{
        'checked_in_at':
            existing.checkedInAt?.toUtc().millisecondsSinceEpoch ??
            startTime.toUtc().millisecondsSinceEpoch,
        'start_time': startTime.toUtc().millisecondsSinceEpoch,
        'early_start': 1,
      },
      where: 'id = ?',
      whereArgs: <Object?>[entryId],
    );

    final updated = await getEntry(entryId, executor: db);
    return updated!;
  }

  Future<List<RaceEntry>> listUnfinishedEntries(int raceId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'race_entries',
      where: 'race_id = ? AND finish_time IS NULL',
      whereArgs: <Object?>[raceId],
      orderBy: 'id ASC',
    );
    return rows.map(RaceEntry.fromMap).toList();
  }

  Future<List<CheckInMatch>> searchCheckInMatches({
    required Race race,
    required String query,
  }) async {
    final db = await _helper.database;
    final normalizedQuery = normalizeName(query);
    if (normalizedQuery.isEmpty) {
      return const <CheckInMatch>[];
    }

    final rows = await db.rawQuery(
      '''
      SELECT
        race_entries.id AS entry_id,
        race_entries.runner_id AS entry_runner_id,
        race_entries.race_id AS entry_race_id,
        race_entries.barcode_value AS entry_barcode_value,
        race_entries.checked_in_at AS entry_checked_in_at,
        race_entries.start_time AS entry_start_time,
        race_entries.early_start AS entry_early_start,
        race_entries.finish_time AS entry_finish_time,
        race_entries.elapsed_time_ms AS entry_elapsed_time_ms,
        runners.id AS runner_id,
        runners.name AS runner_name,
        runners.barcode_value AS runner_barcode_value,
        runners.stripe_payment_id AS runner_stripe_payment_id,
        runners.paid AS runner_paid,
        runners.payment_status AS runner_payment_status,
        runners.membership_status AS runner_membership_status,
        runners.created_at AS runner_created_at
      FROM race_entries
      INNER JOIN runners ON runners.id = race_entries.runner_id
      WHERE race_entries.race_id = ?
        AND runners.normalized_name LIKE ?
      ORDER BY
        CASE
          WHEN runners.normalized_name = ? THEN 0
          WHEN runners.normalized_name LIKE ? THEN 1
          ELSE 2
        END,
        runners.name ASC,
        race_entries.id ASC
      LIMIT 25;
      ''',
      <Object?>[
        race.id,
        '%$normalizedQuery%',
        normalizedQuery,
        '$normalizedQuery%',
      ],
    );

    return rows.map((row) {
      final runner = Runner(
        id: row['runner_id'] as int,
        name: row['runner_name'] as String,
        barcodeValue: row['runner_barcode_value'] as String,
        stripePaymentId: row['runner_stripe_payment_id'] as String?,
        paymentStatus: PaymentStatusX.fromDb(
          row['runner_payment_status'] as String?,
          legacyPaid: row['runner_paid'],
        ),
        membershipStatus: MembershipStatusX.fromDb(
          row['runner_membership_status'] as String?,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['runner_created_at'] as int,
          isUtc: true,
        ),
      );
      final entry = RaceEntry(
        id: row['entry_id'] as int,
        runnerId: row['entry_runner_id'] as int,
        raceId: row['entry_race_id'] as int,
        barcodeValue: row['entry_barcode_value'] as String,
        checkedInAt: row['entry_checked_in_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['entry_checked_in_at'] as int,
                isUtc: true,
              ),
        startTime: row['entry_start_time'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['entry_start_time'] as int,
                isUtc: true,
              ),
        earlyStart: (row['entry_early_start'] as int? ?? 0) == 1,
        finishTime: row['entry_finish_time'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['entry_finish_time'] as int,
                isUtc: true,
              ),
        elapsedTimeMs: row['entry_elapsed_time_ms'] as int?,
      );
      return CheckInMatch(runner: runner, entry: entry, race: race);
    }).toList();
  }

  Future<List<CheckInMatch>> listCheckInMatches({required Race race}) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        race_entries.id AS entry_id,
        race_entries.runner_id AS entry_runner_id,
        race_entries.race_id AS entry_race_id,
        race_entries.barcode_value AS entry_barcode_value,
        race_entries.checked_in_at AS entry_checked_in_at,
        race_entries.start_time AS entry_start_time,
        race_entries.early_start AS entry_early_start,
        race_entries.finish_time AS entry_finish_time,
        race_entries.elapsed_time_ms AS entry_elapsed_time_ms,
        runners.id AS runner_id,
        runners.name AS runner_name,
        runners.barcode_value AS runner_barcode_value,
        runners.stripe_payment_id AS runner_stripe_payment_id,
        runners.paid AS runner_paid,
        runners.payment_status AS runner_payment_status,
        runners.membership_status AS runner_membership_status,
        runners.created_at AS runner_created_at
      FROM race_entries
      INNER JOIN runners ON runners.id = race_entries.runner_id
      WHERE race_entries.race_id = ?
      ORDER BY runners.name ASC, race_entries.id ASC;
      ''',
      <Object?>[race.id],
    );

    return rows.map((row) {
      final runner = Runner(
        id: row['runner_id'] as int,
        name: row['runner_name'] as String,
        barcodeValue: row['runner_barcode_value'] as String,
        stripePaymentId: row['runner_stripe_payment_id'] as String?,
        paymentStatus: PaymentStatusX.fromDb(
          row['runner_payment_status'] as String?,
          legacyPaid: row['runner_paid'],
        ),
        membershipStatus: MembershipStatusX.fromDb(
          row['runner_membership_status'] as String?,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['runner_created_at'] as int,
          isUtc: true,
        ),
      );
      final entry = RaceEntry(
        id: row['entry_id'] as int,
        runnerId: row['entry_runner_id'] as int,
        raceId: row['entry_race_id'] as int,
        barcodeValue: row['entry_barcode_value'] as String,
        checkedInAt: row['entry_checked_in_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['entry_checked_in_at'] as int,
                isUtc: true,
              ),
        startTime: row['entry_start_time'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['entry_start_time'] as int,
                isUtc: true,
              ),
        earlyStart: (row['entry_early_start'] as int? ?? 0) == 1,
        finishTime: row['entry_finish_time'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['entry_finish_time'] as int,
                isUtc: true,
              ),
        elapsedTimeMs: row['entry_elapsed_time_ms'] as int?,
      );
      return CheckInMatch(runner: runner, entry: entry, race: race);
    }).toList();
  }

  Future<List<RaceResultRow>> getRaceResults(int raceId) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        race_entries.id AS entry_id,
        race_entries.runner_id AS runner_id,
        race_entries.race_id AS race_id,
        runners.name AS runner_name,
        runners.paid AS runner_paid,
        runners.payment_status AS runner_payment_status,
        race_entries.barcode_value AS barcode_value,
        race_entries.checked_in_at AS checked_in_at,
        race_entries.start_time AS start_time,
        race_entries.early_start AS early_start,
        race_entries.finish_time AS finish_time,
        race_entries.elapsed_time_ms AS elapsed_time_ms
      FROM race_entries
      INNER JOIN runners ON runners.id = race_entries.runner_id
      WHERE race_entries.race_id = ?
      ORDER BY race_entries.finish_time ASC, race_entries.id ASC;
      ''',
      <Object?>[raceId],
    );
    return rows.map(RaceResultRow.fromMap).toList();
  }

  Future<void> logScanEvent({
    int? raceId,
    int? runnerId,
    int? entryId,
    String? barcodeValue,
    required ScanEventType eventType,
    required ScanEventSeverity severity,
    required String message,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    await db.insert('scan_event_logs', <String, Object?>{
      'race_id': raceId,
      'runner_id': runnerId,
      'entry_id': entryId,
      'barcode_value': _normalizeOptionalText(barcodeValue),
      'event_type': eventType.dbValue,
      'severity': severity.dbValue,
      'message': message.trim(),
      'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    });
  }

  Future<List<ScanEventLog>> listScanEvents({
    int? raceId,
    int limit = 50,
  }) async {
    final db = await _helper.database;
    final rows = await db.query(
      'scan_event_logs',
      where: raceId == null ? null : 'race_id = ?',
      whereArgs: raceId == null ? null : <Object?>[raceId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ScanEventLog.fromMap).toList();
  }

  Future<void> clearDryRunData() async {
    await transaction((db) async {
      await db.delete(
        'races',
        where: 'name LIKE ?',
        whereArgs: <Object?>['Practice Race%'],
      );
      await db.delete(
        'runners',
        where: 'name LIKE ?',
        whereArgs: <Object?>['Test Runner %'],
      );
    });
  }

  String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
