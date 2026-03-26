import 'package:race_timer/models/race_status.dart';

class Race {
  const Race({
    required this.id,
    required this.name,
    required this.raceDate,
    required this.gunTime,
    required this.endTime,
    required this.status,
    required this.seriesName,
    required this.createdAt,
    required this.entryFeeMinor,
    required this.currencyCode,
  });

  final int id;
  final String name;
  final DateTime raceDate;
  final DateTime? gunTime;
  final DateTime? endTime;
  final RaceStatus status;
  final String? seriesName;
  final DateTime createdAt;
  final int entryFeeMinor;
  final String currencyCode;

  bool get isPending => status == RaceStatus.pending;
  bool get isRunning => status == RaceStatus.running;
  bool get isFinished => status == RaceStatus.finished;
  String get statusLabel => status.label;
  int? get totalElapsedTimeMs {
    if (gunTime == null || endTime == null) {
      return null;
    }

    final elapsedTimeMs = endTime!.difference(gunTime!).inMilliseconds;
    return elapsedTimeMs < 0 ? 0 : elapsedTimeMs;
  }

  Race copyWith({
    int? id,
    String? name,
    DateTime? raceDate,
    DateTime? gunTime,
    bool clearGunTime = false,
    DateTime? endTime,
    bool clearEndTime = false,
    RaceStatus? status,
    String? seriesName,
    bool clearSeriesName = false,
    DateTime? createdAt,
    int? entryFeeMinor,
    String? currencyCode,
  }) {
    return Race(
      id: id ?? this.id,
      name: name ?? this.name,
      raceDate: raceDate ?? this.raceDate,
      gunTime: clearGunTime ? null : gunTime ?? this.gunTime,
      endTime: clearEndTime ? null : endTime ?? this.endTime,
      status: status ?? this.status,
      seriesName: clearSeriesName ? null : seriesName ?? this.seriesName,
      createdAt: createdAt ?? this.createdAt,
      entryFeeMinor: entryFeeMinor ?? this.entryFeeMinor,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'race_date': raceDate.toUtc().millisecondsSinceEpoch,
      'gun_time': gunTime?.toUtc().millisecondsSinceEpoch,
      'end_time': endTime?.toUtc().millisecondsSinceEpoch,
      'status': status.dbValue,
      'series_name': seriesName,
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      'entry_fee_minor': entryFeeMinor,
      'currency_code': currencyCode,
    };
  }

  factory Race.fromMap(Map<String, Object?> map) {
    return Race(
      id: map['id'] as int,
      name: map['name'] as String,
      raceDate: map['race_date'] == null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['created_at'] as int,
              isUtc: true,
            )
          : DateTime.fromMillisecondsSinceEpoch(
              map['race_date'] as int,
              isUtc: true,
            ),
      gunTime: map['gun_time'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['gun_time'] as int,
              isUtc: true,
            ),
      endTime: map['end_time'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['end_time'] as int,
              isUtc: true,
            ),
      status: RaceStatusX.fromDb(map['status'] as String),
      seriesName: map['series_name'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
        isUtc: true,
      ),
      entryFeeMinor: map['entry_fee_minor'] as int,
      currencyCode: map['currency_code'] as String,
    );
  }
}
