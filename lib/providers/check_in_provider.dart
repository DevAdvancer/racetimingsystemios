import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/models/check_in_match.dart';
import 'package:race_timer/models/check_in_result.dart';
import 'package:race_timer/models/check_in_state.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/providers/race_provider.dart';

final checkInProvider = AsyncNotifierProvider<CheckInController, CheckInState>(
  CheckInController.new,
);

class CheckInController extends AsyncNotifier<CheckInState> {
  @override
  FutureOr<CheckInState> build() async {
    final race = await ref.watch(currentRaceProvider.future);
    return _buildState(
      race: race,
      lastResult: race == null
          ? CheckInResult.noActiveRace()
          : CheckInResult.idle(),
    );
  }

  Future<CheckInState> refresh({CheckInResult? lastResult}) async {
    final current = state.asData?.value ?? CheckInState.initial();
    state = AsyncData(current.copyWith(isBusy: true));
    final race = await ref.read(currentRaceProvider.future);
    final refreshed = await _buildState(
      race: race,
      lastResult:
          lastResult ??
          (race == null ? CheckInResult.noActiveRace() : current.lastResult),
    );
    state = AsyncData(refreshed);
    return refreshed;
  }

  Future<CheckInState> printMatch(CheckInMatch match) async {
    final current = state.asData?.value ?? CheckInState.initial();
    state = AsyncData(current.copyWith(isBusy: true));
    final result = await ref.read(raceServiceProvider).printCheckInMatch(match);
    return refresh(lastResult: result);
  }

  Future<CheckInState> printMatches(List<CheckInMatch> matches) async {
    final current = state.asData?.value ?? CheckInState.initial();
    state = AsyncData(current.copyWith(isBusy: true));
    final result = await ref
        .read(raceServiceProvider)
        .printCheckInMatches(matches);
    return refresh(lastResult: result);
  }

  Future<CheckInState> reprintLastLabel() async {
    final current = state.asData?.value ?? CheckInState.initial();
    final match = current.lastResult.selectedMatch;
    if (match == null) {
      final updated = current.copyWith(
        lastResult: CheckInResult.failure(
          'Print a rider label before attempting a reprint.',
        ),
        isBusy: false,
      );
      state = AsyncData(updated);
      return updated;
    }

    state = AsyncData(current.copyWith(isBusy: true));
    final printerStatus = await ref
        .read(raceServiceProvider)
        .reprintLabel(match);
    return refresh(
      lastResult: CheckInResult.printed(
        match: match,
        printerStatus: printerStatus,
      ),
    );
  }

  void clearFeedback() {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(lastResult: CheckInResult.idle()));
  }

  Future<CheckInState> _buildState({
    required Race? race,
    required CheckInResult lastResult,
  }) async {
    if (race == null) {
      return CheckInState.noActiveRace().copyWith(lastResult: lastResult);
    }

    final roster = await ref.read(raceServiceProvider).listCheckInRoster(race);
    return CheckInState(
      race: race,
      roster: roster,
      lastResult: lastResult,
      isBusy: false,
    );
  }
}
