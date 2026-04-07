class RaceEntry {
  const RaceEntry({
    required this.id,
    required this.runnerId,
    required this.raceId,
    required this.barcodeValue,
    required this.checkedInAt,
    required this.startTime,
    required this.earlyStart,
    required this.finishTime,
    required this.elapsedTimeMs,
    this.raceDistanceId,
    this.paceOverride,
    this.bibNumber,
    this.age,
  });

  final int id;
  final int runnerId;
  final int raceId;
  final String barcodeValue;
  final DateTime? checkedInAt;
  final DateTime? startTime;
  final bool earlyStart;
  final DateTime? finishTime;
  final int? elapsedTimeMs;
  final int? raceDistanceId;
  final String? paceOverride;
  final String? bibNumber;
  final int? age;

  bool get isCheckedIn => checkedInAt != null;
  bool get isFinished => finishTime != null;

  RaceEntry copyWith({
    int? id,
    int? runnerId,
    int? raceId,
    String? barcodeValue,
    DateTime? checkedInAt,
    bool clearCheckedInAt = false,
    DateTime? startTime,
    bool clearStartTime = false,
    bool? earlyStart,
    DateTime? finishTime,
    bool clearFinishTime = false,
    int? elapsedTimeMs,
    bool clearElapsedTime = false,
    int? raceDistanceId,
    bool clearRaceDistanceId = false,
    String? paceOverride,
    bool clearPaceOverride = false,
    String? bibNumber,
    bool clearBibNumber = false,
    int? age,
    bool clearAge = false,
  }) {
    return RaceEntry(
      id: id ?? this.id,
      runnerId: runnerId ?? this.runnerId,
      raceId: raceId ?? this.raceId,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      checkedInAt: clearCheckedInAt ? null : checkedInAt ?? this.checkedInAt,
      startTime: clearStartTime ? null : startTime ?? this.startTime,
      earlyStart: earlyStart ?? this.earlyStart,
      finishTime: clearFinishTime ? null : finishTime ?? this.finishTime,
      elapsedTimeMs: clearElapsedTime
          ? null
          : elapsedTimeMs ?? this.elapsedTimeMs,
      raceDistanceId: clearRaceDistanceId
          ? null
          : raceDistanceId ?? this.raceDistanceId,
      paceOverride: clearPaceOverride
          ? null
          : paceOverride ?? this.paceOverride,
      bibNumber: clearBibNumber ? null : bibNumber ?? this.bibNumber,
      age: clearAge ? null : age ?? this.age,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'runner_id': runnerId,
      'race_id': raceId,
      'barcode_value': barcodeValue,
      'checked_in_at': checkedInAt?.toUtc().millisecondsSinceEpoch,
      'start_time': startTime?.toUtc().millisecondsSinceEpoch,
      'early_start': earlyStart ? 1 : 0,
      'finish_time': finishTime?.toUtc().millisecondsSinceEpoch,
      'elapsed_time_ms': elapsedTimeMs,
      'race_distance_id': raceDistanceId,
      'pace_override': paceOverride,
      'bib_number': bibNumber,
      'age': age,
    };
  }

  factory RaceEntry.fromMap(Map<String, Object?> map) {
    return RaceEntry(
      id: map['id'] as int,
      runnerId: map['runner_id'] as int,
      raceId: map['race_id'] as int,
      barcodeValue: map['barcode_value'] as String,
      checkedInAt: map['checked_in_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['checked_in_at'] as int,
              isUtc: true,
            ),
      startTime: map['start_time'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['start_time'] as int,
              isUtc: true,
            ),
      earlyStart: (map['early_start'] as int? ?? 0) == 1,
      finishTime: map['finish_time'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['finish_time'] as int,
              isUtc: true,
            ),
      elapsedTimeMs: map['elapsed_time_ms'] as int?,
      raceDistanceId: map['race_distance_id'] as int?,
      paceOverride: map['pace_override'] as String?,
      bibNumber: map['bib_number'] as String?,
      age: map['age'] as int?,
    );
  }
}
