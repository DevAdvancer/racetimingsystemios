enum PrinterHealth { ready, success, notConfigured, unsupported, error }

class PrinterStatus {
  const PrinterStatus({required this.health, required this.message, this.host});

  final PrinterHealth health;
  final String message;
  final String? host;

  bool get isReady =>
      health == PrinterHealth.ready || health == PrinterHealth.success;
  bool get isSuccess => health == PrinterHealth.success;
  bool get hasIssue => !isReady;

  factory PrinterStatus.ready({String? host, String? message}) {
    return PrinterStatus(
      health: PrinterHealth.ready,
      message: message ?? 'Printer is ready.',
      host: host,
    );
  }

  factory PrinterStatus.success({String? host, String? message}) {
    return PrinterStatus(
      health: PrinterHealth.success,
      message: message ?? 'Label printed successfully.',
      host: host,
    );
  }

  factory PrinterStatus.notConfigured({String? message}) {
    return PrinterStatus(
      health: PrinterHealth.notConfigured,
      message: message ?? 'Printer host is not configured.',
    );
  }

  factory PrinterStatus.unsupported({String? message}) {
    return PrinterStatus(
      health: PrinterHealth.unsupported,
      message:
          message ??
          'Direct Brother printing is only available on iPad in this build.',
    );
  }

  factory PrinterStatus.error({String? host, required String message}) {
    return PrinterStatus(
      health: PrinterHealth.error,
      message: message,
      host: host,
    );
  }

  factory PrinterStatus.fromMap(Map<Object?, Object?> map) {
    final rawHealth = (map['health'] as String?) ?? PrinterHealth.error.name;
    final health = PrinterHealth.values.firstWhere(
      (value) => value.name == rawHealth,
      orElse: () => PrinterHealth.error,
    );
    return PrinterStatus(
      health: health,
      message: (map['message'] as String?) ?? 'Unknown printer status.',
      host: map['host'] as String?,
    );
  }
}
