import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/models/finish_scan_result.dart';
import 'package:race_timer/providers/check_in_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/results_provider.dart';

class FinishScannerState {
  const FinishScannerState({
    required this.lastResult,
    required this.isSubmitting,
  });

  final FinishScanResult lastResult;
  final bool isSubmitting;

  factory FinishScannerState.initial() {
    return FinishScannerState(
      lastResult: FinishScanResult.idle(),
      isSubmitting: false,
    );
  }

  FinishScannerState copyWith({
    FinishScanResult? lastResult,
    bool? isSubmitting,
  }) {
    return FinishScannerState(
      lastResult: lastResult ?? this.lastResult,
      isSubmitting: isSubmitting ?? this.isSubmitting,
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
    final barcode = (value ?? '').trim();
    state = state.copyWith(isSubmitting: true);

    final result = await ref
        .read(raceServiceProvider)
        .recordRunnerScan(barcode);
    ref.invalidate(checkInProvider);
    ref.invalidate(resultsProvider);

    state = state.copyWith(isSubmitting: false, lastResult: result);
    return result;
  }

  Future<FinishScanResult> simulateNextScan() async {
    state = state.copyWith(isSubmitting: true);
    final result = await ref.read(raceServiceProvider).simulateNextFinish();
    state = state.copyWith(isSubmitting: false, lastResult: result);
    ref.invalidate(resultsProvider);
    ref.invalidate(checkInProvider);
    return result;
  }

  void clearResult() {
    state = state.copyWith(lastResult: FinishScanResult.idle());
  }
}
