class FinishScanResult {
  const FinishScanResult({
    required this.status,
    required this.message,
    this.runnerName,
    this.barcodeValue,
    this.isEarlyStarter = false,
    this.startTime,
    this.finishTime,
    this.elapsedTimeMs,
  });

  final FinishScanStatus status;
  final String message;
  final String? runnerName;
  final String? barcodeValue;
  final bool isEarlyStarter;
  final DateTime? startTime;
  final DateTime? finishTime;
  final int? elapsedTimeMs;

  bool get isSuccess =>
      status == FinishScanStatus.success ||
      status == FinishScanStatus.raceStarted ||
      status == FinishScanStatus.earlyStartRecorded;

  factory FinishScanResult.idle() {
    return const FinishScanResult(
      status: FinishScanStatus.idle,
      message: 'Scanner is ready.',
    );
  }

  factory FinishScanResult.success({
    required String runnerName,
    required String barcodeValue,
    bool isEarlyStarter = false,
    required DateTime finishTime,
    required int elapsedTimeMs,
  }) {
    return FinishScanResult(
      status: FinishScanStatus.success,
      message: 'Finisher recorded successfully.',
      runnerName: runnerName,
      barcodeValue: barcodeValue,
      isEarlyStarter: isEarlyStarter,
      finishTime: finishTime,
      elapsedTimeMs: elapsedTimeMs,
    );
  }

  factory FinishScanResult.raceStarted({required DateTime gunTime}) {
    return FinishScanResult(
      status: FinishScanStatus.raceStarted,
      message: 'Race started successfully.',
      startTime: gunTime,
    );
  }

  factory FinishScanResult.awaitingEarlyStartRunner() {
    return const FinishScanResult(
      status: FinishScanStatus.awaitingEarlyStartRunner,
      message: 'Early start mode is ready. Scan the runner barcode now.',
    );
  }

  factory FinishScanResult.earlyStartRecorded({
    required String runnerName,
    required String barcodeValue,
    required DateTime startTime,
  }) {
    return FinishScanResult(
      status: FinishScanStatus.earlyStartRecorded,
      message: 'Early start recorded successfully.',
      runnerName: runnerName,
      barcodeValue: barcodeValue,
      startTime: startTime,
    );
  }

  factory FinishScanResult.validationError(String message) {
    return FinishScanResult(
      status: FinishScanStatus.validationError,
      message: message,
    );
  }

  factory FinishScanResult.raceNotStarted() {
    return const FinishScanResult(
      status: FinishScanStatus.raceNotStarted,
      message: 'Start the race before scanning finishers.',
    );
  }

  factory FinishScanResult.unknownBarcode(String barcodeValue) {
    return FinishScanResult(
      status: FinishScanStatus.unknownBarcode,
      message:
          'Barcode "$barcodeValue" is not in the active race roster. Please check the label and try again.',
      barcodeValue: barcodeValue,
    );
  }

  factory FinishScanResult.duplicateScan({
    required String runnerName,
    required String barcodeValue,
    bool isEarlyStarter = false,
    DateTime? finishTime,
    int? elapsedTimeMs,
  }) {
    return FinishScanResult(
      status: FinishScanStatus.duplicateScan,
      message:
          '$runnerName was already recorded. The first finish time was kept.',
      runnerName: runnerName,
      barcodeValue: barcodeValue,
      isEarlyStarter: isEarlyStarter,
      finishTime: finishTime,
      elapsedTimeMs: elapsedTimeMs,
    );
  }

  factory FinishScanResult.failure(String message) {
    return FinishScanResult(status: FinishScanStatus.failure, message: message);
  }
}

enum FinishScanStatus {
  idle,
  success,
  raceStarted,
  awaitingEarlyStartRunner,
  earlyStartRecorded,
  unknownBarcode,
  duplicateScan,
  raceNotStarted,
  validationError,
  failure,
}
