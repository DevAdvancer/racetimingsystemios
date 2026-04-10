import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/database/database_helper.dart';
import 'package:race_timer/models/printer_status.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/settings_provider.dart';
import 'package:race_timer/services/barcode_service.dart';
import 'package:race_timer/services/database_service.dart';
import 'package:race_timer/services/printer_service.dart';
import 'package:race_timer/services/race_service.dart';
import 'package:race_timer/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePrinterService implements PrinterService {
  @override
  Future<PrinterStatus> configure() async => PrinterStatus.ready();

  @override
  Future<PrinterStatus> getStatus() async => PrinterStatus.ready();

  @override
  Future<PrinterStatus> printLabel(LabelDocument document) async =>
      PrinterStatus.success();

  @override
  Future<PrinterStatus> testPrint() async => PrinterStatus.success();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper helper;
  late DatabaseService databaseService;
  late SettingsService settingsService;
  late RaceService raceService;

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        databaseHelperProvider.overrideWithValue(helper),
        settingsServiceProvider.overrideWithValue(settingsService),
        raceServiceProvider.overrideWithValue(raceService),
      ],
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sqfliteFfiInit();
    helper = DatabaseHelper.forTesting(databaseFactory: databaseFactoryFfi);
    await helper.ensureInitialized();
    databaseService = DatabaseService(helper);
    settingsService = await SettingsService.create();
    raceService = RaceService(
      databaseService: databaseService,
      barcodeService: const BarcodeService(),
      printerService: _FakePrinterService(),
      settingsService: settingsService,
    );
  });

  tearDown(() async {
    await helper.close();
  });

  test('does not auto-select a stale saved race when no race is today', () async {
    final oldRace = await databaseService.createRace(
      name: 'Saved Race',
      raceDate: DateTime(2026, 3, 21),
    );
    await settingsService.saveSettings(
      (await settingsService.loadSettings()).copyWith(selectedRaceId: oldRace.id),
    );

    final container = buildContainer();
    addTearDown(container.dispose);

    final selectedRace = await container.read(currentRaceProvider.future);

    expect(selectedRace, isNull);
  });

  test('auto-selects the race scheduled for today', () async {
    final now = DateTime.now();
    final todayRace = await databaseService.createRace(
      name: 'Today Race',
      raceDate: DateTime(now.year, now.month, now.day),
    );

    final container = buildContainer();
    addTearDown(container.dispose);

    final selectedRace = await container.read(currentRaceProvider.future);

    expect(selectedRace?.id, todayRace.id);
  });

  test('keeps an organizer-selected race active after selection', () async {
    final chosenRace = await databaseService.createRace(
      name: 'Manual Race',
      raceDate: DateTime(2026, 3, 21),
    );

    final container = buildContainer();
    addTearDown(container.dispose);

    await container.read(currentRaceProvider.notifier).selectRace(chosenRace.id);
    final selectedRace = await container.read(currentRaceProvider.future);

    expect(selectedRace?.id, chosenRace.id);
  });
}
