class RunnerPointsSummary {
  const RunnerPointsSummary({
    required this.runnerId,
    required this.raceId,
    required this.runnerName,
    required this.barcodeValue,
    required this.totalPoints,
    required this.pointsInRace,
    required this.awardCount,
    required this.lastAwardedAt,
  });

  final int runnerId;
  final int raceId;
  final String runnerName;
  final String barcodeValue;
  final int totalPoints;
  final int pointsInRace;
  final int awardCount;
  final DateTime? lastAwardedAt;

  factory RunnerPointsSummary.fromMap(Map<String, Object?> map) {
    return RunnerPointsSummary(
      runnerId: map['runner_id'] as int,
      raceId: map['race_id'] as int,
      runnerName: map['runner_name'] as String,
      barcodeValue: map['barcode_value'] as String,
      totalPoints: map['total_points'] as int? ?? 0,
      pointsInRace: map['points_in_race'] as int? ?? 0,
      awardCount: map['award_count'] as int? ?? 0,
      lastAwardedAt: map['last_awarded_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['last_awarded_at'] as int,
              isUtc: true,
            ),
    );
  }
}
