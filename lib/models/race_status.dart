enum RaceStatus { pending, running, finished }

extension RaceStatusX on RaceStatus {
  String get dbValue => name;

  String get label => switch (this) {
    RaceStatus.pending => 'Pending',
    RaceStatus.running => 'Running',
    RaceStatus.finished => 'Finished',
  };

  static RaceStatus fromDb(String value) {
    return RaceStatus.values.firstWhere(
      (status) => status.dbValue == value,
      orElse: () => RaceStatus.pending,
    );
  }
}
