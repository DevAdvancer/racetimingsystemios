import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/database/database_helper.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_distance_config.dart';
import 'package:race_timer/services/barcode_service.dart';
import 'package:race_timer/services/database_service.dart';
import 'package:race_timer/services/import_service.dart';
import 'package:race_timer/services/printer_service.dart';
import 'package:race_timer/services/race_service.dart';
import 'package:race_timer/services/settings_service.dart';
import 'package:race_timer/providers/settings_provider.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  throw UnimplementedError(
    'databaseHelperProvider must be overridden in main().',
  );
});

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService(ref.watch(databaseHelperProvider));
});

final barcodeServiceProvider = Provider<BarcodeService>((ref) {
  return const BarcodeService();
});

final importServiceProvider = Provider<ImportService>((ref) {
  return const ImportService();
});

final printerServiceProvider = Provider<PrinterService>((ref) {
  return MethodChannelPrinterService(ref.watch(settingsServiceProvider));
});

final raceServiceProvider = Provider<RaceService>((ref) {
  return RaceService(
    databaseService: ref.watch(databaseServiceProvider),
    barcodeService: ref.watch(barcodeServiceProvider),
    printerService: ref.watch(printerServiceProvider),
    settingsService: ref.watch(settingsServiceProvider),
  );
});

final raceListProvider = FutureProvider<List<Race>>((ref) {
  return ref.watch(raceServiceProvider).listRaces();
});

final raceDistanceConfigsProvider =
    FutureProvider.family<List<RaceDistanceConfig>, int>((ref, raceId) {
      return ref.watch(raceServiceProvider).listRaceDistanceConfigs(raceId);
    });

final currentRaceProvider = AsyncNotifierProvider<CurrentRaceController, Race?>(
  CurrentRaceController.new,
);

class CurrentRaceController extends AsyncNotifier<Race?> {
  RaceService get _raceService => ref.read(raceServiceProvider);
  SettingsService get _settingsService => ref.read(settingsServiceProvider);

  @override
  FutureOr<Race?> build() async {
    final runningRace = await _raceService.getRunningRace();
    if (runningRace != null) {
      return runningRace;
    }

    final todayRace = await _raceService.getRaceScheduledForDate(
      DateTime.now(),
    );
    if (todayRace != null) {
      return todayRace;
    }

    final settings = await _settingsService.loadSettings();
    final selectedRaceId = settings.selectedRaceId;
    if (selectedRaceId != null) {
      final selectedRace = await _raceService.getRace(selectedRaceId);
      if (selectedRace != null) {
        return selectedRace;
      }
    }
    return _raceService.getCurrentRace();
  }

  Future<Race?> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => await build());
    ref.invalidate(raceListProvider);
    return state.asData?.value;
  }

  Future<Race> createRace({
    required String name,
    int entryFeeMinor = 0,
    String currencyCode = 'USD',
  }) async {
    final created = await _raceService.createRace(
      name: name,
      entryFeeMinor: entryFeeMinor,
      currencyCode: currencyCode,
    );
    await selectRace(created.id);
    await refresh();
    return created;
  }

  Future<void> selectRace(int raceId) async {
    final settings = await _settingsService.loadSettings();
    await _settingsService.saveSettings(
      settings.copyWith(selectedRaceId: raceId),
    );
    await refresh();
  }

  Future<void> clearSelectedRace() async {
    final settings = await _settingsService.loadSettings();
    await _settingsService.saveSettings(
      settings.copyWith(clearSelectedRaceId: true),
    );
    await refresh();
  }

  Future<Race> startRace(int raceId) async {
    final race = await _raceService.startRace(raceId);
    await refresh();
    return race;
  }

  Future<Race> endRace(int raceId) async {
    final race = await _raceService.endRace(raceId);
    await refresh();
    return race;
  }
}
