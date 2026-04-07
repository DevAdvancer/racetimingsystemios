import 'package:race_timer/models/runner.dart';

class RaceResultRow {
  const RaceResultRow({
    required this.entryId,
    required this.runnerId,
    required this.raceId,
    required this.runnerName,
    required this.barcodeValue,
    required this.checkedInAt,
    required this.startTime,
    required this.earlyStart,
    required this.finishTime,
    required this.elapsedTimeMs,
    this.raceDistanceId,
    this.distanceName,
    this.distanceMiles,
    this.paceOverride,
    this.paymentStatus = PaymentStatus.paid,
    this.membershipStatus = MembershipStatus.unknown,
    this.city,
    this.bibNumber,
    this.age,
    this.gender,
  });

  final int entryId;
  final int runnerId;
  final int raceId;
  final String runnerName;
  final String barcodeValue;
  final DateTime? checkedInAt;
  final DateTime? startTime;
  final bool earlyStart;
  final DateTime? finishTime;
  final int? elapsedTimeMs;
  final int? raceDistanceId;
  final String? distanceName;
  final double? distanceMiles;
  final String? paceOverride;
  final PaymentStatus paymentStatus;
  final MembershipStatus membershipStatus;
  final String? city;
  final String? bibNumber;
  final int? age;
  final String? gender;

  String get statusLabel {
    if (finishTime != null) {
      return 'Race Completed';
    }
    if (checkedInAt != null) {
      return 'In Race';
    }
    return 'Registered';
  }

  factory RaceResultRow.fromMap(Map<String, Object?> map) {
    return RaceResultRow(
      entryId: map['entry_id'] as int,
      runnerId: map['runner_id'] as int,
      raceId: map['race_id'] as int,
      runnerName: map['runner_name'] as String,
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
      distanceName: map['distance_name'] as String?,
      distanceMiles: (map['distance_miles'] as num?)?.toDouble(),
      paceOverride: map['pace_override'] as String?,
      paymentStatus: PaymentStatusX.fromDb(
        map['runner_payment_status'] as String?,
        legacyPaid: map['runner_paid'],
      ),
      membershipStatus: MembershipStatusX.fromDb(
        map['runner_membership_status'] as String?,
      ),
      city: map['runner_city'] as String?,
      bibNumber: map['bib_number'] as String?,
      age: map['age'] as int?,
      gender: map['runner_gender'] as String?,
    );
  }
}
