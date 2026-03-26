import 'package:race_timer/models/check_in_match.dart';
import 'package:race_timer/models/check_in_result.dart';
import 'package:race_timer/models/race.dart';

class CheckInState {
  const CheckInState({
    required this.race,
    required this.roster,
    required this.lastResult,
    required this.isBusy,
  });

  final Race? race;
  final List<CheckInMatch> roster;
  final CheckInResult lastResult;
  final bool isBusy;

  bool get hasActiveRace => race != null;

  factory CheckInState.initial() {
    return CheckInState(
      race: null,
      roster: const <CheckInMatch>[],
      lastResult: CheckInResult.idle(),
      isBusy: false,
    );
  }

  factory CheckInState.noActiveRace() {
    return CheckInState(
      race: null,
      roster: const <CheckInMatch>[],
      lastResult: CheckInResult.noActiveRace(),
      isBusy: false,
    );
  }

  CheckInState copyWith({
    Race? race,
    bool clearRace = false,
    List<CheckInMatch>? roster,
    CheckInResult? lastResult,
    bool? isBusy,
  }) {
    return CheckInState(
      race: clearRace ? null : race ?? this.race,
      roster: roster ?? this.roster,
      lastResult: lastResult ?? this.lastResult,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}
