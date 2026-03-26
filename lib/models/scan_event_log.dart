enum ScanEventType {
  validationError,
  raceNotStarted,
  unknownBarcode,
  duplicateScan,
  failure,
}

extension ScanEventTypeX on ScanEventType {
  String get dbValue => switch (this) {
    ScanEventType.validationError => 'validation_error',
    ScanEventType.raceNotStarted => 'race_not_started',
    ScanEventType.unknownBarcode => 'unknown_barcode',
    ScanEventType.duplicateScan => 'duplicate_scan',
    ScanEventType.failure => 'failure',
  };

  static ScanEventType fromDb(String value) {
    return switch (value) {
      'validation_error' => ScanEventType.validationError,
      'race_not_started' => ScanEventType.raceNotStarted,
      'unknown_barcode' => ScanEventType.unknownBarcode,
      'duplicate_scan' => ScanEventType.duplicateScan,
      _ => ScanEventType.failure,
    };
  }
}

enum ScanEventSeverity { info, warning, error }

extension ScanEventSeverityX on ScanEventSeverity {
  String get dbValue => switch (this) {
    ScanEventSeverity.info => 'info',
    ScanEventSeverity.warning => 'warning',
    ScanEventSeverity.error => 'error',
  };

  static ScanEventSeverity fromDb(String value) {
    return switch (value) {
      'info' => ScanEventSeverity.info,
      'warning' => ScanEventSeverity.warning,
      _ => ScanEventSeverity.error,
    };
  }
}

class ScanEventLog {
  const ScanEventLog({
    required this.id,
    required this.raceId,
    required this.runnerId,
    required this.entryId,
    required this.barcodeValue,
    required this.eventType,
    required this.severity,
    required this.message,
    required this.createdAt,
  });

  final int id;
  final int? raceId;
  final int? runnerId;
  final int? entryId;
  final String? barcodeValue;
  final ScanEventType eventType;
  final ScanEventSeverity severity;
  final String message;
  final DateTime createdAt;

  factory ScanEventLog.fromMap(Map<String, Object?> map) {
    return ScanEventLog(
      id: map['id'] as int,
      raceId: map['race_id'] as int?,
      runnerId: map['runner_id'] as int?,
      entryId: map['entry_id'] as int?,
      barcodeValue: map['barcode_value'] as String?,
      eventType: ScanEventTypeX.fromDb(map['event_type'] as String),
      severity: ScanEventSeverityX.fromDb(map['severity'] as String),
      message: map['message'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
        isUtc: true,
      ),
    );
  }
}
