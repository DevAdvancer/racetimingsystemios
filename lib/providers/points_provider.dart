import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/models/overall_runner_points_summary.dart';
import 'package:race_timer/models/runner_points_summary.dart';
import 'package:race_timer/providers/race_provider.dart';

final racePointsProvider =
    FutureProvider.family<List<RunnerPointsSummary>, int>((ref, raceId) async {
      return ref
          .watch(raceServiceProvider)
          .listRaceRunnerPointsSummaries(raceId);
    });

final overallPointsProvider = FutureProvider<List<OverallRunnerPointsSummary>>((
  ref,
) async {
  return ref.watch(raceServiceProvider).listOverallRunnerPointsSummaries();
});
