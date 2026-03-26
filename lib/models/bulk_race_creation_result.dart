import 'package:race_timer/models/race.dart';

class BulkRaceCreationResult {
  const BulkRaceCreationResult({
    required this.createdRaces,
    required this.skippedCount,
  });

  final List<Race> createdRaces;
  final int skippedCount;

  int get createdCount => createdRaces.length;
}
