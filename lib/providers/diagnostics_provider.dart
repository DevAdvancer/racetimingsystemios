import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/models/diagnostics_report.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/settings_provider.dart';
import 'package:race_timer/services/diagnostics_service.dart';

final diagnosticsServiceProvider = Provider<DiagnosticsService>((ref) {
  return DiagnosticsService(
    databaseService: ref.watch(databaseServiceProvider),
    raceService: ref.watch(raceServiceProvider),
    printerService: ref.watch(printerServiceProvider),
    settingsService: ref.watch(settingsServiceProvider),
  );
});

final diagnosticsProvider =
    AsyncNotifierProvider<DiagnosticsController, DiagnosticsReport>(
      DiagnosticsController.new,
    );

class DiagnosticsController extends AsyncNotifier<DiagnosticsReport> {
  DiagnosticsService get _diagnosticsService =>
      ref.read(diagnosticsServiceProvider);

  @override
  FutureOr<DiagnosticsReport> build() {
    return _diagnosticsService.run();
  }

  Future<DiagnosticsReport> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_diagnosticsService.run);
    return state.requireValue;
  }

  Future<void> seedDryRunData() async {
    await _diagnosticsService.seedDryRunData();
    await refresh();
    ref.invalidate(raceListProvider);
    ref.invalidate(currentRaceProvider);
  }

  Future<void> clearDryRunData() async {
    await _diagnosticsService.clearDryRunData();
    await refresh();
    ref.invalidate(raceListProvider);
    ref.invalidate(currentRaceProvider);
  }
}
