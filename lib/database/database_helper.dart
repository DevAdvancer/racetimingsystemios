import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/platform_support.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  DatabaseHelper._(this._databaseFactory, {this.databasePathOverride});

  static const _databaseVersion = 10;

  final DatabaseFactory _databaseFactory;
  final String? databasePathOverride;
  Database? _database;
  String? _resolvedDatabasePath;

  static Future<DatabaseHelper> create() async {
    if (PlatformSupport.usesFfiDatabase) {
      sqfliteFfiInit();
      return DatabaseHelper._(databaseFactoryFfi);
    }

    return DatabaseHelper._(sqflite.databaseFactory);
  }

  factory DatabaseHelper.forTesting({
    required DatabaseFactory databaseFactory,
    String databasePath = inMemoryDatabasePath,
  }) {
    return DatabaseHelper._(
      databaseFactory,
      databasePathOverride: databasePath,
    );
  }

  Future<void> ensureInitialized() async {
    await database;
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasePath = databasePathOverride ?? await _resolveDatabasePath();
    _resolvedDatabasePath = databasePath;

    _database = await _databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _migrateToV2(db);
          }
          if (oldVersion < 3) {
            await _migrateToV3(db);
          }
          if (oldVersion < 4) {
            await _migrateToV4(db);
          }
          if (oldVersion < 5) {
            await _migrateToV5(db);
          }
          if (oldVersion < 6) {
            await _migrateToV6(db);
          }
          if (oldVersion < 7) {
            await _migrateToV7(db);
          }
          if (oldVersion < 8) {
            await _migrateToV8(db);
          }
          if (oldVersion < 9) {
            await _migrateToV9(db);
          }
          if (oldVersion < 10) {
            await _migrateToV10(db);
          }
        },
      ),
    );

    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE runners (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        normalized_name TEXT NOT NULL,
        barcode_value TEXT NOT NULL,
        stripe_payment_id TEXT,
        paid INTEGER NOT NULL DEFAULT 1,
        payment_status TEXT NOT NULL DEFAULT 'paid',
        membership_status TEXT NOT NULL DEFAULT 'unknown',
        created_at INTEGER NOT NULL,
        city TEXT,
        gender TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE races (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        race_date INTEGER NOT NULL,
        gun_time INTEGER,
        end_time INTEGER,
        status TEXT NOT NULL,
        series_name TEXT,
        created_at INTEGER NOT NULL,
        entry_fee_minor INTEGER NOT NULL DEFAULT 0,
        currency_code TEXT NOT NULL DEFAULT 'USD'
      );
    ''');

    await db.execute('''
      CREATE TABLE race_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        runner_id INTEGER NOT NULL,
        race_id INTEGER NOT NULL,
        barcode_value TEXT NOT NULL,
        bib_number TEXT,
        age INTEGER,
        race_distance_id INTEGER,
        checked_in_at INTEGER,
        start_time INTEGER,
        early_start INTEGER NOT NULL DEFAULT 0,
        finish_time INTEGER,
        elapsed_time_ms INTEGER,
        pace_override TEXT,
        FOREIGN KEY (runner_id) REFERENCES runners(id) ON DELETE CASCADE,
        FOREIGN KEY (race_id) REFERENCES races(id) ON DELETE CASCADE,
        FOREIGN KEY (race_distance_id) REFERENCES race_distance_configs(id) ON DELETE SET NULL
      );
    ''');

    await _createSupportTables(db);
    await _createIndexes(db);
  }

  Future<void> _createSupportTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS runner_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        runner_id INTEGER NOT NULL,
        race_id INTEGER NOT NULL,
        points INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (runner_id) REFERENCES runners(id) ON DELETE CASCADE,
        FOREIGN KEY (race_id) REFERENCES races(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS scan_event_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_id INTEGER,
        runner_id INTEGER,
        entry_id INTEGER,
        barcode_value TEXT,
        event_type TEXT NOT NULL,
        severity TEXT NOT NULL,
        message TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (race_id) REFERENCES races(id) ON DELETE SET NULL,
        FOREIGN KEY (runner_id) REFERENCES runners(id) ON DELETE SET NULL,
        FOREIGN KEY (entry_id) REFERENCES race_entries(id) ON DELETE SET NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS age_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        label TEXT NOT NULL,
        min_age INTEGER,
        max_age INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS race_entry_splits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_entry_id INTEGER NOT NULL,
        split_code TEXT NOT NULL,
        split_name TEXT NOT NULL,
        distance_meters INTEGER,
        recorded_at INTEGER,
        elapsed_time_ms INTEGER,
        FOREIGN KEY (race_entry_id) REFERENCES race_entries(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS race_entry_rankings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_entry_id INTEGER NOT NULL,
        ranking_type TEXT NOT NULL,
        category_code TEXT,
        placement INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (race_entry_id) REFERENCES race_entries(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS race_distance_configs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        distance_miles REAL NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_primary INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (race_id) REFERENCES races(id) ON DELETE CASCADE
      );
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_runners_barcode ON runners(barcode_value);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_runners_normalized_name ON runners(normalized_name);',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_race_entries_runner_race ON race_entries(runner_id, race_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_race_entries_race_finish ON race_entries(race_id, finish_time);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_race_entries_race_barcode ON race_entries(race_id, barcode_value);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_races_status_created ON races(status, created_at DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_races_created_at ON races(created_at DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_races_race_date ON races(race_date DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_scan_event_logs_race_created ON scan_event_logs(race_id, created_at DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_scan_event_logs_type_created ON scan_event_logs(event_type, created_at DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_runner_points_runner_created ON runner_points(runner_id, created_at DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_runner_points_race_runner ON runner_points(race_id, runner_id);',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_age_groups_code ON age_groups(code);',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_race_distance_configs_order ON race_distance_configs(race_id, sort_order);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_race_distance_configs_primary ON race_distance_configs(race_id, is_primary DESC, sort_order ASC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_race_entries_race_distance_finish ON race_entries(race_id, race_distance_id, finish_time);',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_race_entry_splits_entry_code ON race_entry_splits(race_entry_id, split_code);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_race_entry_rankings_entry_type ON race_entry_rankings(race_entry_id, ranking_type, category_code);',
    );
  }

  Future<void> _migrateToV2(Database db) async {
    if (!await _tableHasColumn(db, 'runners', 'normalized_name')) {
      await db.execute('ALTER TABLE runners ADD COLUMN normalized_name TEXT;');
    }
    if (!await _tableHasColumn(db, 'runners', 'barcode_value')) {
      await db.execute('ALTER TABLE runners ADD COLUMN barcode_value TEXT;');
    }

    final runners = await db.query('runners');
    for (final runner in runners) {
      final runnerId = runner['id'] as int;
      final name = (runner['name'] as String?) ?? '';
      final existingEntry = await db.query(
        'race_entries',
        columns: <String>['barcode_value'],
        where: 'runner_id = ?',
        whereArgs: <Object?>[runnerId],
        orderBy: 'id ASC',
        limit: 1,
      );
      final existingBarcode = (runner['barcode_value'] as String?)?.trim();
      final barcode = existingBarcode != null && existingBarcode.isNotEmpty
          ? existingBarcode
          : existingEntry.isNotEmpty
          ? existingEntry.first['barcode_value'] as String
          : _fallbackRunnerBarcode(runnerId);

      await db.update(
        'runners',
        <String, Object?>{
          'normalized_name': _normalizeName(name),
          'barcode_value': barcode,
        },
        where: 'id = ?',
        whereArgs: <Object?>[runnerId],
      );
    }

    final raceEntriesOldExists = await _tableExists(db, 'race_entries_old');
    final raceEntriesHasUniqueBarcodeIndex = await _indexExists(
      db,
      'sqlite_autoindex_race_entries_1',
    );

    if (!raceEntriesOldExists && raceEntriesHasUniqueBarcodeIndex) {
      await db.execute('ALTER TABLE race_entries RENAME TO race_entries_old;');
    }

    if (await _tableExists(db, 'race_entries_old')) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS race_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          runner_id INTEGER NOT NULL,
          race_id INTEGER NOT NULL,
          barcode_value TEXT NOT NULL,
          finish_time INTEGER,
          elapsed_time_ms INTEGER,
          FOREIGN KEY (runner_id) REFERENCES runners(id) ON DELETE CASCADE,
          FOREIGN KEY (race_id) REFERENCES races(id) ON DELETE CASCADE
        );
      ''');

      await db.execute('DELETE FROM race_entries;');
      await db.execute('''
        INSERT INTO race_entries (
          id,
          runner_id,
          race_id,
          barcode_value,
          finish_time,
          elapsed_time_ms
        )
        SELECT
          race_entries_old.id,
          race_entries_old.runner_id,
          race_entries_old.race_id,
          COALESCE(runners.barcode_value, race_entries_old.barcode_value),
          race_entries_old.finish_time,
          race_entries_old.elapsed_time_ms
        FROM race_entries_old
        INNER JOIN runners ON runners.id = race_entries_old.runner_id;
      ''');

      await db.execute('DROP TABLE race_entries_old;');
    }

    await _createIndexes(db);
  }

  Future<void> _migrateToV3(Database db) async {
    if (!await _tableHasColumn(db, 'races', 'end_time')) {
      await db.execute('ALTER TABLE races ADD COLUMN end_time INTEGER;');
    }

    await db.execute('''
      UPDATE races
      SET end_time = COALESCE(
        (
          SELECT MAX(finish_time)
          FROM race_entries
          WHERE race_entries.race_id = races.id
            AND finish_time IS NOT NULL
        ),
        gun_time
      )
      WHERE status = 'finished'
        AND end_time IS NULL;
    ''');
  }

  Future<void> _migrateToV4(Database db) async {
    if (!await _tableHasColumn(db, 'race_entries', 'checked_in_at')) {
      await db.execute(
        'ALTER TABLE race_entries ADD COLUMN checked_in_at INTEGER;',
      );
    }

    await db.execute('''
      UPDATE race_entries
      SET checked_in_at = finish_time
      WHERE checked_in_at IS NULL
        AND finish_time IS NOT NULL;
    ''');
  }

  Future<void> _migrateToV5(Database db) async {
    if (!await _tableHasColumn(db, 'runners', 'payment_status')) {
      await db.execute(
        "ALTER TABLE runners ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'paid';",
      );
    }
    if (!await _tableHasColumn(db, 'runners', 'membership_status')) {
      await db.execute(
        "ALTER TABLE runners ADD COLUMN membership_status TEXT NOT NULL DEFAULT 'unknown';",
      );
    }
    if (!await _tableHasColumn(db, 'races', 'race_date')) {
      await db.execute('ALTER TABLE races ADD COLUMN race_date INTEGER;');
    }
    if (!await _tableHasColumn(db, 'races', 'series_name')) {
      await db.execute('ALTER TABLE races ADD COLUMN series_name TEXT;');
    }

    await db.execute('''
      UPDATE runners
      SET payment_status = CASE
        WHEN paid = 1 THEN 'paid'
        ELSE 'pending'
      END
      WHERE payment_status IS NULL
         OR payment_status = ''
         OR (paid = 0 AND payment_status = 'paid');
    ''');

    await db.execute('''
      UPDATE runners
      SET membership_status = 'unknown'
      WHERE membership_status IS NULL
         OR membership_status = '';
    ''');

    await db.execute('''
      UPDATE races
      SET race_date = COALESCE(race_date, gun_time, created_at)
      WHERE race_date IS NULL;
    ''');

    await _createSupportTables(db);
    await _createIndexes(db);
  }

  Future<void> _migrateToV6(Database db) async {
    if (!await _tableHasColumn(db, 'race_entries', 'start_time')) {
      await db.execute(
        'ALTER TABLE race_entries ADD COLUMN start_time INTEGER;',
      );
    }
    if (!await _tableHasColumn(db, 'race_entries', 'early_start')) {
      await db.execute(
        "ALTER TABLE race_entries ADD COLUMN early_start INTEGER NOT NULL DEFAULT 0;",
      );
    }
  }

  Future<void> _migrateToV7(Database db) async {
    await _createSupportTables(db);
    await _createIndexes(db);
  }

  Future<void> _migrateToV8(Database db) async {
    await _createIndexes(db);
  }

  Future<void> _migrateToV9(Database db) async {
    if (!await _tableHasColumn(db, 'runners', 'city')) {
      await db.execute('ALTER TABLE runners ADD COLUMN city TEXT;');
    }
    if (!await _tableHasColumn(db, 'runners', 'gender')) {
      await db.execute('ALTER TABLE runners ADD COLUMN gender TEXT;');
    }
    if (!await _tableHasColumn(db, 'race_entries', 'bib_number')) {
      await db.execute('ALTER TABLE race_entries ADD COLUMN bib_number TEXT;');
    }
    if (!await _tableHasColumn(db, 'race_entries', 'age')) {
      await db.execute('ALTER TABLE race_entries ADD COLUMN age INTEGER;');
    }

    await _createIndexes(db);
  }

  Future<void> _migrateToV10(Database db) async {
    if (!await _tableHasColumn(db, 'race_entries', 'race_distance_id')) {
      await db.execute(
        'ALTER TABLE race_entries ADD COLUMN race_distance_id INTEGER;',
      );
    }
    if (!await _tableHasColumn(db, 'race_entries', 'pace_override')) {
      await db.execute(
        'ALTER TABLE race_entries ADD COLUMN pace_override TEXT;',
      );
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS race_distance_configs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        distance_miles REAL NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_primary INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (race_id) REFERENCES races(id) ON DELETE CASCADE
      );
    ''');

    await _createIndexes(db);
  }

  Future<bool> _tableHasColumn(
    Database db,
    String tableName,
    String columnName,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($tableName);');
    return rows.any((row) => row['name'] == columnName);
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final rows = await db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name = ?;
      ''',
      <Object?>[tableName],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _indexExists(Database db, String indexName) async {
    final rows = await db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'index' AND name = ?;
      ''',
      <Object?>[indexName],
    );
    return rows.isNotEmpty;
  }

  static String _normalizeName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _fallbackRunnerBarcode(int runnerId) {
    return 'RT-${runnerId.toString().padLeft(6, '0')}';
  }

  Future<String> _resolveDatabasePath() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return path.join(directory.path, AppConstants.databaseName);
  }

  Future<void> resetDatabase() async {
    final databasePath =
        _resolvedDatabasePath ??
        databasePathOverride ??
        await _resolveDatabasePath();
    await close();
    if (databasePath == inMemoryDatabasePath) {
      return;
    }
    await _databaseFactory.deleteDatabase(databasePath);
    _resolvedDatabasePath = databasePath;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
