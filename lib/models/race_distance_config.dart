class RaceDistanceConfig {
  const RaceDistanceConfig({
    required this.id,
    required this.raceId,
    required this.name,
    required this.distanceMiles,
    required this.sortOrder,
    required this.isPrimary,
    required this.createdAt,
  });

  final int id;
  final int raceId;
  final String name;
  final double distanceMiles;
  final int sortOrder;
  final bool isPrimary;
  final DateTime createdAt;

  String get sectionLabel {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '${_formatDistanceMiles(distanceMiles)} miles';
    }
    return '$trimmed - ${_formatDistanceMiles(distanceMiles)} miles';
  }

  RaceDistanceConfig copyWith({
    int? id,
    int? raceId,
    String? name,
    double? distanceMiles,
    int? sortOrder,
    bool? isPrimary,
    DateTime? createdAt,
  }) {
    return RaceDistanceConfig(
      id: id ?? this.id,
      raceId: raceId ?? this.raceId,
      name: name ?? this.name,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'race_id': raceId,
      'name': name,
      'distance_miles': distanceMiles,
      'sort_order': sortOrder,
      'is_primary': isPrimary ? 1 : 0,
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
    };
  }

  factory RaceDistanceConfig.fromMap(Map<String, Object?> map) {
    return RaceDistanceConfig(
      id: map['id'] as int,
      raceId: map['race_id'] as int,
      name: map['name'] as String,
      distanceMiles: (map['distance_miles'] as num).toDouble(),
      sortOrder: map['sort_order'] as int? ?? 0,
      isPrimary: (map['is_primary'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
        isUtc: true,
      ),
    );
  }

  static String _formatDistanceMiles(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    if ((value * 10) == (value * 10).roundToDouble()) {
      return value.toStringAsFixed(1);
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
