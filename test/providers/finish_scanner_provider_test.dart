import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/database/database_helper.dart';
import 'package:race_timer/models/finish_scan_result.dart';
import 'package:race_timer/models/app_settings.dart';
import 'package:race_timer/models/discovered_printer.dart';
import 'package:race_timer/models/printer_status.dart';
import 'package:race_timer/models/roster_import.dart';
import 'package:race_timer/providers/finish_scanner_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/settings_provider.dart';
import 'package:race_timer/services/barcode_service.dart';
import 'package:race_timer/services/database_service.dart';
import 'package:race_timer/services/printer_service.dart';
import 'package:race_timer/services/race_service.dart';
import 'package:race_timer/services/settings_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePrinterService implements PrinterService {
  @override
  Future<PrinterStatus> configure() async => PrinterStatus.ready();

  @override
  Future<List<DiscoveredPrinter>> discoverPrinters({
    required PrinterConnectionType connectionType,
  }) async => const [];

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
    settingsService = await SettingsService.create();
    raceService = RaceService(
      databaseService: DatabaseService(helper),
      barcodeService: const BarcodeService(),
      printerService: _FakePrinterService(),
      settingsService: settingsService,
    );
  });

  tearDown(() async {
    await helper.close();
  });

  test(
    'finish scanner stores an early start first and then the finisher time',
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

      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(currentRaceProvider.notifier).selectRace(race.id);
      await container.read(currentRaceProvider.future);

      final controller = container.read(finishScannerProvider.notifier);
      final earlyStartResult = await controller.submitBuffer(barcode);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await raceService.startRace(race.id);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final finishResult = await controller.submitBuffer(barcode);
      final results = await raceService.getResults(race.id);
      final scannerState = container.read(finishScannerProvider);

      expect(scannerState.awaitingEarlyStartRunner, isFalse);
      expect(earlyStartResult.status, FinishScanStatus.earlyStartRecorded);
      expect(finishResult.status, FinishScanStatus.success);
      expect(finishResult.isEarlyStarter, isTrue);
      expect(results.single.earlyStart, isTrue);
      expect(
        results.single.startTime?.millisecondsSinceEpoch,
        earlyStartResult.startTime?.millisecondsSinceEpoch,
      );
      expect(
        finishResult.elapsedTimeMs,
        inInclusiveRange(
          finishResult.finishTime!
                  .difference(earlyStartResult.startTime!)
                  .inMilliseconds -
              5,
          finishResult.finishTime!
                  .difference(earlyStartResult.startTime!)
                  .inMilliseconds +
              5,
        ),
      );
    },
  );
}
