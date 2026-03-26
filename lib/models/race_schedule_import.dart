class ImportedRaceScheduleEntry {
  const ImportedRaceScheduleEntry({
    required this.raceDate,
    this.raceName,
    this.seriesName,
  });

  final DateTime raceDate;
  final String? raceName;
  final String? seriesName;
}

class RaceScheduleImport {
  const RaceScheduleImport({
    required this.sourceName,
    required this.entries,
    this.invalidRowCount = 0,
  });

  final String sourceName;
  final List<ImportedRaceScheduleEntry> entries;
  final int invalidRowCount;
}
