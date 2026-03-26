import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/providers/race_provider.dart';

final runnerProvider = FutureProvider.family<Runner?, int>((ref, runnerId) {
  return ref.watch(raceServiceProvider).getRunner(runnerId);
});
