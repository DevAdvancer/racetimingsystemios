import 'package:race_timer/database/database_helper.dart';
import 'package:race_timer/models/check_in_match.dart';
import 'package:race_timer/models/overall_runner_points_summary.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_distance_config.dart';
import 'package:race_timer/models/race_entry.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/models/race_status.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/models/runner_points_summary.dart';
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

  static int? _readFirstInt(List<Map<String, Object?>> rows) {
    if (rows.isEmpty || rows.first.isEmpty) {
      return null;
    }
    final value = rows.first.values.first;
    return (value as num?)?.toInt();
  }

  Future<List<Race>> listRaces() async {
    final db = await _helper.database;
    final rows = await db.query('races', orderBy: 'created_at DESC');
    return rows.map(Race.fromMap).toList();
  }

  Future<List<RaceDistanceConfig>> listRaceDistanceConfigs(
    int raceId, {
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final rows = await db.query(
      'race_distance_configs',
      where: 'race_id = ?',
      whereArgs: <Object?>[raceId],
      orderBy: 'is_primary DESC, sort_order ASC, created_at ASC',
    );
    return rows.map(RaceDistanceConfig.fromMap).toList();
  }

  Future<RaceDistanceConfig?> getPrimaryRaceDistanceConfig(
    int raceId, {
    DatabaseExecutor? executor,
  }) async {
    final configs = await listRaceDistanceConfigs(raceId, executor: executor);
    if (configs.isEmpty) {
      return null;
    }
    for (final config in configs) {
      if (config.isPrimary) {
        return config;
      }
    }
    return configs.first;
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

  Future<Race?> getRaceScheduledForDate(DateTime date) async {
    final db = await _helper.database;
    final localStart = DateTime(date.year, date.month, date.day);
    final localEnd = localStart.add(const Duration(days: 1));
    final rows = await db.query(
      'races',
      where: 'race_date >= ? AND race_date < ?',
      whereArgs: <Object?>[
        localStart.toUtc().millisecondsSinceEpoch,
        localEnd.toUtc().millisecondsSinceEpoch,
      ],
      orderBy: 'race_date ASC, created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Race.fromMap(rows.first);
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

  Future<RaceDistanceConfig> createRaceDistanceConfig({
    required int raceId,
    required String name,
    required double distanceMiles,
    bool isPrimary = false,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final createdAt = DateTime.now().toUtc();
    final normalizedName = name.trim();
    final nextSortOrder =
        _readFirstInt(
          await db.rawQuery(
            'SELECT COALESCE(MAX(sort_order), -1) + 1 FROM race_distance_configs WHERE race_id = ?',
            <Object?>[raceId],
          ),
        ) ??
        0;

    if (isPrimary) {
      await db.update(
        'race_distance_configs',
        <String, Object?>{'is_primary': 0},
        where: 'race_id = ?',
        whereArgs: <Object?>[raceId],
      );
    }

    final id = await db.insert('race_distance_configs', <String, Object?>{
      'race_id': raceId,
      'name': normalizedName,
      'distance_miles': distanceMiles,
      'sort_order': nextSortOrder,
      'is_primary': isPrimary ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    });

    if (!isPrimary) {
      final count = _readFirstInt(
        await db.rawQuery(
          'SELECT COUNT(*) FROM race_distance_configs WHERE race_id = ?',
          <Object?>[raceId],
        ),
      );
      if (count == 1) {
        await db.update(
          'race_distance_configs',
          <String, Object?>{'is_primary': 1},
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        return RaceDistanceConfig(
          id: id,
          raceId: raceId,
          name: normalizedName,
          distanceMiles: distanceMiles,
          sortOrder: nextSortOrder,
          isPrimary: true,
          createdAt: createdAt,
        );
      }
    }

    return RaceDistanceConfig(
      id: id,
      raceId: raceId,
      name: normalizedName,
      distanceMiles: distanceMiles,
      sortOrder: nextSortOrder,
      isPrimary: isPrimary,
      createdAt: createdAt,
    );
  }

  Future<RaceDistanceConfig> updateRaceDistanceConfig({
    required int id,
    required int raceId,
    required String name,
    required double distanceMiles,
    required bool isPrimary,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final existingRows = await db.query(
      'race_distance_configs',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (existingRows.isEmpty) {
      throw StateError('Race distance config not found.');
    }
    final existing = RaceDistanceConfig.fromMap(existingRows.first);

    if (isPrimary) {
      await db.update(
        'race_distance_configs',
        <String, Object?>{'is_primary': 0},
        where: 'race_id = ?',
        whereArgs: <Object?>[raceId],
      );
    }

    await db.update(
      'race_distance_configs',
      <String, Object?>{
        'name': name.trim(),
        'distance_miles': distanceMiles,
        'is_primary': isPrimary ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );

    return existing.copyWith(
      name: name.trim(),
      distanceMiles: distanceMiles,
      isPrimary: isPrimary,
    );
  }

  Future<void> deleteRaceDistanceConfig(
    int id, {
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final existingRows = await db.query(
      'race_distance_configs',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (existingRows.isEmpty) {
      return;
    }
    final existing = RaceDistanceConfig.fromMap(existingRows.first);

    await db.update(
      'race_entries',
      <String, Object?>{'race_distance_id': null},
      where: 'race_distance_id = ?',
      whereArgs: <Object?>[id],
    );
    await db.delete(
      'race_distance_configs',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );

    if (!existing.isPrimary) {
      return;
    }

    final remaining = await listRaceDistanceConfigs(
      existing.raceId,
      executor: db,
    );
    if (remaining.isEmpty) {
      return;
    }
    await db.update(
      'race_distance_configs',
      <String, Object?>{'is_primary': 1},
      where: 'id = ?',
      whereArgs: <Object?>[remaining.first.id],
    );
  }

  Future<Runner> createRunner({
    required String name,
    String? barcodeValue,
    String? stripePaymentId,
    bool paid = true,
    PaymentStatus? paymentStatus,
    MembershipStatus membershipStatus = MembershipStatus.unknown,
    String? city,
    String? gender,
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
      'city': _normalizeOptionalText(city),
      'gender': _normalizeOptionalText(gender),
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
      city: _normalizeOptionalText(city),
      gender: _normalizeOptionalText(gender),
    );
  }

  Future<Runner> updateRunnerDetails({
    required int runnerId,
    required String name,
    required PaymentStatus paymentStatus,
    required MembershipStatus membershipStatus,
    String? city,
    String? gender,
    String? barcodeValue,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final runner = await getRunner(runnerId, executor: db);
    if (runner == null) {
      throw StateError('Runner record could not be found.');
    }

    final trimmedName = name.trim();
    final trimmedBarcode = barcodeValue == null || barcodeValue.trim().isEmpty
        ? runner.barcodeValue
        : barcodeValue.trim();

    await db.update(
      'runners',
      <String, Object?>{
        'name': trimmedName,
        'normalized_name': normalizeName(trimmedName),
        'barcode_value': trimmedBarcode,
        'paid': paymentStatus.countsAsPaid ? 1 : 0,
        'payment_status': paymentStatus.dbValue,
        'membership_status': membershipStatus.dbValue,
        'city': _normalizeOptionalText(city),
        'gender': _normalizeOptionalText(gender),
      },
      where: 'id = ?',
      whereArgs: <Object?>[runnerId],
    );

    await db.update(
      'race_entries',
      <String, Object?>{'barcode_value': trimmedBarcode},
      where: 'runner_id = ?',
      whereArgs: <Object?>[runnerId],
    );

    return (await getRunner(runnerId, executor: db))!;
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
    await db.update(
      'race_entries',
      <String, Object?>{'barcode_value': barcodeValue},
      where: 'runner_id = ?',
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
    String? bibNumber,
    int? age,
    int? raceDistanceId,
    String? paceOverride,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final id = await db.insert('race_entries', <String, Object?>{
      'runner_id': runnerId,
      'race_id': raceId,
      'barcode_value': barcodeValue,
      'bib_number': _normalizeOptionalText(bibNumber),
      'age': age,
      'race_distance_id': raceDistanceId,
      'checked_in_at': null,
      'start_time': null,
      'early_start': 0,
      'finish_time': null,
      'elapsed_time_ms': null,
      'pace_override': _normalizeOptionalText(paceOverride),
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
      raceDistanceId: raceDistanceId,
      paceOverride: _normalizeOptionalText(paceOverride),
      bibNumber: _normalizeOptionalText(bibNumber),
      age: age,
    );
  }

  Future<RaceEntry> updateRaceEntryDetails({
    required int entryId,
    String? bibNumber,
    bool clearBibNumber = false,
    int? age,
    bool clearAge = false,
    int? raceDistanceId,
    bool clearRaceDistanceId = false,
    int? elapsedTimeMs,
    bool clearElapsedTime = false,
    String? paceOverride,
    bool clearPaceOverride = false,
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
        'bib_number': clearBibNumber
            ? null
            : _normalizeOptionalText(bibNumber) ?? existing.bibNumber,
        'age': clearAge ? null : age ?? existing.age,
        'race_distance_id': clearRaceDistanceId
            ? null
            : raceDistanceId ?? existing.raceDistanceId,
        'elapsed_time_ms': clearElapsedTime
            ? null
            : elapsedTimeMs ?? existing.elapsedTimeMs,
        'pace_override': clearPaceOverride
            ? null
            : _normalizeOptionalText(paceOverride) ?? existing.paceOverride,
      },
      where: 'id = ?',
      whereArgs: <Object?>[entryId],
    );

    return (await getEntry(entryId, executor: db))!;
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

  Future<void> awardRunnerPoints({
    required int runnerId,
    required int raceId,
    required int points,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    await db.insert('runner_points', <String, Object?>{
      'runner_id': runnerId,
      'race_id': raceId,
      'points': points,
      'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    });
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

  Future<List<RunnerPointsSummary>> listRaceRunnerPointsSummaries(
    int raceId,
  ) async {
    final db = await _helper.database;
    final rows = await _queryRaceRunnerPointsSummaries(db, raceId: raceId);
    return rows.map(RunnerPointsSummary.fromMap).toList();
  }

  Future<List<OverallRunnerPointsSummary>>
  listOverallRunnerPointsSummaries() async {
    final db = await _helper.database;
    final rows = await _queryOverallRunnerPointsSummaries(db);
    return rows.map(OverallRunnerPointsSummary.fromMap).toList();
  }

  Future<RunnerPointsSummary?> getRaceRunnerPointsSummary({
    required int raceId,
    required int runnerId,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final rows = await _queryRaceRunnerPointsSummaries(
      db,
      raceId: raceId,
      runnerId: runnerId,
    );
    if (rows.isEmpty) {
      return null;
    }
    return RunnerPointsSummary.fromMap(rows.first);
  }

  Future<OverallRunnerPointsSummary?> getOverallRunnerPointsSummary({
    required int runnerId,
    DatabaseExecutor? executor,
  }) async {
    final db = await _resolveExecutor(executor);
    final rows = await _queryOverallRunnerPointsSummaries(
      db,
      runnerId: runnerId,
    );
    if (rows.isEmpty) {
      return null;
    }
    return OverallRunnerPointsSummary.fromMap(rows.first);
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
        race_entries.race_distance_id AS entry_race_distance_id,
        race_entries.pace_override AS entry_pace_override,
        runners.id AS runner_id,
        runners.name AS runner_name,
        runners.barcode_value AS runner_barcode_value,
        runners.stripe_payment_id AS runner_stripe_payment_id,
        runners.paid AS runner_paid,
        runners.payment_status AS runner_payment_status,
        runners.membership_status AS runner_membership_status,
        runners.created_at AS runner_created_at,
        runners.city AS runner_city,
        runners.gender AS runner_gender,
        race_entries.bib_number AS entry_bib_number,
        race_entries.age AS entry_age
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
        city: row['runner_city'] as String?,
        gender: row['runner_gender'] as String?,
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
        raceDistanceId: row['entry_race_distance_id'] as int?,
        paceOverride: row['entry_pace_override'] as String?,
        bibNumber: row['entry_bib_number'] as String?,
        age: row['entry_age'] as int?,
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
        race_entries.race_distance_id AS entry_race_distance_id,
        race_entries.pace_override AS entry_pace_override,
        runners.id AS runner_id,
        runners.name AS runner_name,
        runners.barcode_value AS runner_barcode_value,
        runners.stripe_payment_id AS runner_stripe_payment_id,
        runners.paid AS runner_paid,
        runners.payment_status AS runner_payment_status,
        runners.membership_status AS runner_membership_status,
        runners.created_at AS runner_created_at,
        runners.city AS runner_city,
        runners.gender AS runner_gender,
        race_entries.bib_number AS entry_bib_number,
        race_entries.age AS entry_age
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
        city: row['runner_city'] as String?,
        gender: row['runner_gender'] as String?,
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
        raceDistanceId: row['entry_race_distance_id'] as int?,
        paceOverride: row['entry_pace_override'] as String?,
        bibNumber: row['entry_bib_number'] as String?,
        age: row['entry_age'] as int?,
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
        runners.membership_status AS runner_membership_status,
        runners.city AS runner_city,
        runners.gender AS runner_gender,
        race_entries.barcode_value AS barcode_value,
        race_entries.bib_number AS bib_number,
        race_entries.age AS age,
        race_entries.race_distance_id AS race_distance_id,
        race_entries.pace_override AS pace_override,
        race_distance_configs.name AS distance_name,
        race_distance_configs.distance_miles AS distance_miles,
        race_entries.checked_in_at AS checked_in_at,
        race_entries.start_time AS start_time,
        race_entries.early_start AS early_start,
        race_entries.finish_time AS finish_time,
        race_entries.elapsed_time_ms AS elapsed_time_ms
      FROM race_entries
      INNER JOIN runners ON runners.id = race_entries.runner_id
      LEFT JOIN race_distance_configs
        ON race_distance_configs.id = race_entries.race_distance_id
      WHERE race_entries.race_id = ?
      ORDER BY race_entries.finish_time ASC, race_entries.id ASC;
      ''',
      <Object?>[raceId],
    );
    return rows.map(RaceResultRow.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> _queryRaceRunnerPointsSummaries(
    DatabaseExecutor db, {
    required int raceId,
    int? runnerId,
  }) {
    return db.rawQuery(
      '''
      SELECT
        runners.id AS runner_id,
        race_entries.race_id AS race_id,
        runners.name AS runner_name,
        runners.barcode_value AS barcode_value,
        COALESCE(total_points.total_points, 0) AS total_points,
        COALESCE(race_points.points_in_race, 0) AS points_in_race,
        COALESCE(total_points.award_count, 0) AS award_count,
        total_points.last_awarded_at AS last_awarded_at
      FROM race_entries
      INNER JOIN runners ON runners.id = race_entries.runner_id
      LEFT JOIN (
        SELECT
          runner_id,
          SUM(points) AS total_points,
          COUNT(*) AS award_count,
          MAX(created_at) AS last_awarded_at
        FROM runner_points
        GROUP BY runner_id
      ) total_points ON total_points.runner_id = runners.id
      LEFT JOIN (
        SELECT
          runner_id,
          race_id,
          SUM(points) AS points_in_race
        FROM runner_points
        GROUP BY runner_id, race_id
      ) race_points
        ON race_points.runner_id = runners.id
       AND race_points.race_id = race_entries.race_id
      WHERE race_entries.race_id = ?
        ${runnerId == null ? '' : 'AND runners.id = ?'}
      ORDER BY
        COALESCE(total_points.total_points, 0) DESC,
        runners.name ASC,
        race_entries.id ASC;
      ''',
      <Object?>[raceId, ?runnerId],
    );
  }

  Future<List<Map<String, Object?>>> _queryOverallRunnerPointsSummaries(
    DatabaseExecutor db, {
    int? runnerId,
  }) {
    return db.rawQuery(
      '''
      SELECT
        runners.id AS runner_id,
        runners.name AS runner_name,
        runners.barcode_value AS barcode_value,
        SUM(runner_points.points) AS total_points,
        COUNT(runner_points.id) AS award_count,
        MAX(runner_points.created_at) AS last_awarded_at,
        latest_race.id AS latest_race_id,
        latest_race.name AS latest_race_name
      FROM runner_points
      INNER JOIN runners ON runners.id = runner_points.runner_id
      LEFT JOIN races latest_race ON latest_race.id = (
        SELECT rp_latest.race_id
        FROM runner_points rp_latest
        WHERE rp_latest.runner_id = runners.id
        ORDER BY rp_latest.created_at DESC, rp_latest.id DESC
        LIMIT 1
      )
      ${runnerId == null ? '' : 'WHERE runners.id = ?'}
      GROUP BY
        runners.id,
        runners.name,
        runners.barcode_value,
        latest_race.id,
        latest_race.name
      ORDER BY
        SUM(runner_points.points) DESC,
        MAX(runner_points.created_at) DESC,
        runners.name ASC;
      ''',
      <Object?>[?runnerId],
    );
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
