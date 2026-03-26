import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/models/finish_scan_result.dart';
import 'package:race_timer/providers/check_in_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/results_provider.dart';

class FinishScannerState {
  const FinishScannerState({
    required this.buffer,
    required this.lastResult,
    required this.isSubmitting,
  });

  final String buffer;
  final FinishScanResult lastResult;
  final bool isSubmitting;

  factory FinishScannerState.initial() {
    return FinishScannerState(
      buffer: '',
      lastResult: FinishScanResult.idle(),
      isSubmitting: false,
    );
  }

  FinishScannerState copyWith({
    String? buffer,
    FinishScanResult? lastResult,
    bool? isSubmitting,
  }) {
    return FinishScannerState(
      buffer: buffer ?? this.buffer,
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

  void updateBuffer(String value) {
    state = state.copyWith(buffer: value);
  }

  Future<FinishScanResult> submitBuffer([String? value]) async {
    final barcode = (value ?? state.buffer).trim();
    state = state.copyWith(buffer: '', isSubmitting: true);

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
    state = state.copyWith(isSubmitting: false, lastResult: result, buffer: '');
    ref.invalidate(resultsProvider);
    ref.invalidate(checkInProvider);
    return result;
  }

  void clearResult() {
    state = state.copyWith(lastResult: FinishScanResult.idle());
  }
}
