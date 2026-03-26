import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_entry.dart';
import 'package:race_timer/models/runner.dart';

enum CheckInRosterStatus { registered, inRace, raceCompleted }

extension CheckInRosterStatusX on CheckInRosterStatus {
  String get label => switch (this) {
    CheckInRosterStatus.registered => 'Registered',
    CheckInRosterStatus.inRace => 'In Race',
    CheckInRosterStatus.raceCompleted => 'Race Completed',
  };
}

class CheckInMatch {
  const CheckInMatch({
    required this.runner,
    required this.entry,
    required this.race,
  });

  final Runner runner;
  final RaceEntry entry;
  final Race race;

  CheckInMatch copyWith({Runner? runner, RaceEntry? entry, Race? race}) {
    return CheckInMatch(
      runner: runner ?? this.runner,
      entry: entry ?? this.entry,
      race: race ?? this.race,
    );
  }

  CheckInRosterStatus get rosterStatus {
    if (entry.isFinished || (race.isFinished && entry.isCheckedIn)) {
      return CheckInRosterStatus.raceCompleted;
    }
    if (entry.isCheckedIn) {
      return CheckInRosterStatus.inRace;
    }
    return CheckInRosterStatus.registered;
  }

  String get rosterStatusLabel => rosterStatus.label;
}
