class OverallRunnerPointsSummary {
  const OverallRunnerPointsSummary({
    required this.runnerId,
    required this.runnerName,
    required this.barcodeValue,
    required this.totalPoints,
    required this.awardCount,
    required this.lastAwardedAt,
    required this.latestRaceId,
    required this.latestRaceName,
  });

  final int runnerId;
  final String runnerName;
  final String barcodeValue;
  final int totalPoints;
  final int awardCount;
  final DateTime? lastAwardedAt;
  final int? latestRaceId;
  final String? latestRaceName;

  factory OverallRunnerPointsSummary.fromMap(Map<String, Object?> map) {
    return OverallRunnerPointsSummary(
      runnerId: map['runner_id'] as int,
      runnerName: map['runner_name'] as String,
      barcodeValue: map['barcode_value'] as String,
      totalPoints: map['total_points'] as int? ?? 0,
      awardCount: map['award_count'] as int? ?? 0,
      lastAwardedAt: map['last_awarded_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['last_awarded_at'] as int,
              isUtc: true,
            ),
      latestRaceId: map['latest_race_id'] as int?,
      latestRaceName: map['latest_race_name'] as String?,
    );
  }
}
