import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/models/finish_scan_result.dart';
import 'package:race_timer/providers/check_in_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/results_provider.dart';

class FinishScannerState {
  const FinishScannerState({
    required this.lastResult,
    required this.isSubmitting,
    required this.awaitingEarlyStartRunner,
  });

  final FinishScanResult lastResult;
  final bool isSubmitting;
  final bool awaitingEarlyStartRunner;

  factory FinishScannerState.initial() {
    return FinishScannerState(
      lastResult: FinishScanResult.idle(),
      isSubmitting: false,
      awaitingEarlyStartRunner: false,
    );
  }

  FinishScannerState copyWith({
    FinishScanResult? lastResult,
    bool? isSubmitting,
    bool? awaitingEarlyStartRunner,
  }) {
    return FinishScannerState(
      lastResult: lastResult ?? this.lastResult,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      awaitingEarlyStartRunner:
          awaitingEarlyStartRunner ?? this.awaitingEarlyStartRunner,
    );
  }
}

final finishScannerProvider =
    NotifierProvider<FinishScannerController, FinishScannerState>(
      FinishScannerController.new,
    );

class FinishScannerController extends Notifier<FinishScannerState> {
  @override
  FinishScannerState build() {
    return FinishScannerState.initial();
  }

  Future<FinishScanResult> submitBuffer([String? value]) async {
    final barcode = ref
        .read(barcodeServiceProvider)
        .normalizeScannedBarcode(value ?? '');
    state = state.copyWith(isSubmitting: true);

    final result = await ref
        .read(raceServiceProvider)
        .recordRunnerScan(barcode);

    ref.invalidate(checkInProvider);
    ref.invalidate(resultsProvider);
    await ref.read(currentRaceProvider.notifier).refresh();

    state = state.copyWith(
      isSubmitting: false,
      lastResult: result,
      awaitingEarlyStartRunner: false,
    );
    return result;
  }

  Future<FinishScanResult> simulateNextScan() async {
    state = state.copyWith(isSubmitting: true);
    final result = await ref.read(raceServiceProvider).simulateNextFinish();
    state = state.copyWith(
      isSubmitting: false,
      lastResult: result,
      awaitingEarlyStartRunner: false,
    );
    ref.invalidate(resultsProvider);
    ref.invalidate(checkInProvider);
    await ref.read(currentRaceProvider.notifier).refresh();
    return result;
  }

  void clearResult() {
    state = state.copyWith(
      lastResult: FinishScanResult.idle(),
      awaitingEarlyStartRunner: false,
    );
  }
}
