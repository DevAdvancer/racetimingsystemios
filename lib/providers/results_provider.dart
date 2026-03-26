import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/services/export_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return const ExportService();
});

final raceResultsProvider = FutureProvider.family<List<RaceResultRow>, int>((
  ref,
  raceId,
) async {
  return ref.watch(raceServiceProvider).getResults(raceId);
});

final resultsProvider = FutureProvider<List<RaceResultRow>>((ref) async {
  final race = await ref.watch(currentRaceProvider.future);
  if (race == null) {
    return const <RaceResultRow>[];
  }
  return ref.watch(raceResultsProvider(race.id).future);
});
