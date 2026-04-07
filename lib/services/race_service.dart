import 'package:intl/intl.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/bulk_race_creation_result.dart';
import 'package:race_timer/models/check_in_match.dart';
import 'package:race_timer/models/check_in_result.dart';
import 'package:race_timer/models/finish_scan_result.dart';
import 'package:race_timer/models/import_result.dart';
import 'package:race_timer/models/overall_runner_points_summary.dart';
import 'package:race_timer/models/printer_status.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_distance_config.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/models/race_schedule_import.dart';
import 'package:race_timer/models/race_status.dart';
import 'package:race_timer/models/roster_import.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/models/runner_points_summary.dart';
import 'package:race_timer/models/scan_event_log.dart';
import 'package:race_timer/services/barcode_service.dart';
import 'package:race_timer/services/database_service.dart';
import 'package:race_timer/services/printer_service.dart';
import 'package:race_timer/services/settings_service.dart';

class RaceService {
  RaceService({
    required DatabaseService databaseService,
    required BarcodeService barcodeService,
    required PrinterService printerService,
    required SettingsService settingsService,
  }) : _databaseService = databaseService,
       _barcodeService = barcodeService,
       _printerService = printerService,
       _settingsService = settingsService;

  final DatabaseService _databaseService;
  final BarcodeService _barcodeService;
  final PrinterService _printerService;
  final SettingsService _settingsService;

  Future<Race?> getCurrentRace() => _databaseService.getCurrentRace();

  Future<Race?> getRunningRace() => _databaseService.getRunningRace();

  Future<List<Race>> listRaces() => _databaseService.listRaces();

  Future<Runner?> getRunner(int id) => _databaseService.getRunner(id);

  Future<Race?> getRace(int id) => _databaseService.getRace(id);

  Future<List<RaceDistanceConfig>> listRaceDistanceConfigs(int raceId) {
    return _databaseService.listRaceDistanceConfigs(raceId);
  }

  Future<Race> createRace({
    required String name,
    DateTime? raceDate,
    String? seriesName,
    int entryFeeMinor = 0,
    String currencyCode = 'USD',
  }) {
    return _databaseService.createRace(
      name: name,
      raceDate: raceDate,
      seriesName: seriesName,
      entryFeeMinor: entryFeeMinor,
      currencyCode: currencyCode,
    );
  }

  Future<RaceDistanceConfig> saveRaceDistanceConfig({
    int? id,
    required int raceId,
    required String name,
    required double distanceMiles,
    bool isPrimary = false,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('Distance name cannot be empty.');
    }
    if (distanceMiles <= 0) {
      throw const FormatException('Distance must be greater than zero.');
    }

    if (id == null) {
      return _databaseService.createRaceDistanceConfig(
        raceId: raceId,
        name: trimmedName,
        distanceMiles: distanceMiles,
        isPrimary: isPrimary,
      );
    }

    return _databaseService.updateRaceDistanceConfig(
      id: id,
      raceId: raceId,
      name: trimmedName,
      distanceMiles: distanceMiles,
      isPrimary: isPrimary,
    );
  }

  Future<void> deleteRaceDistanceConfig(int id) {
    return _databaseService.deleteRaceDistanceConfig(id);
  }

  Future<Race?> getRaceScheduledForDate(DateTime date) async {
    return _databaseService.getRaceScheduledForDate(date);
  }

  List<DateTime> parseBulkRaceDates(String rawDates) {
    final tokens = rawDates
        .split(RegExp(r'[\n;]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    if (tokens.isEmpty) {
      throw const FormatException(
        'Enter at least one race date before creating the series.',
      );
    }

    final formats = <DateFormat>[
      DateFormat('yyyy-MM-dd'),
      DateFormat('M/d/yyyy'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('MMM d, y'),
      DateFormat('MMMM d, y'),
    ];

    final uniqueDates = <DateTime>[];
    final seen = <String>{};

    for (final token in tokens) {
      DateTime? parsed;
      for (final format in formats) {
        try {
          final candidate = format.parseStrict(token);
          parsed = DateTime(candidate.year, candidate.month, candidate.day);
          break;
        } catch (_) {
          // Try the next supported format.
        }
      }

      if (parsed == null) {
        throw FormatException(
          'Could not read "$token". Use YYYY-MM-DD or MM/DD/YYYY.',
        );
      }

      final key =
          '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
      if (seen.add(key)) {
        uniqueDates.add(parsed);
      }
    }

    uniqueDates.sort();
    return uniqueDates;
  }

  Future<BulkRaceCreationResult> createRacesFromDates({
    required String namePrefix,
    String? seriesName,
    required List<DateTime> dates,
    int entryFeeMinor = 0,
    String currencyCode = 'USD',
  }) async {
    final trimmedNamePrefix = namePrefix.trim();
    if (trimmedNamePrefix.isEmpty) {
      throw const FormatException(
        'Enter a race title before creating a race series.',
      );
    }

    if (dates.isEmpty) {
      throw const FormatException(
        'Enter at least one race date before creating the series.',
      );
    }

    final normalizedSeriesName = seriesName?.trim().isEmpty == true
        ? null
        : seriesName?.trim();
    final existingRaces = await listRaces();
    final createdRaces = <Race>[];
    var skippedCount = 0;

    for (final date in dates) {
      final raceName = _buildBulkRaceName(
        namePrefix: trimmedNamePrefix,
        date: date,
      );
      final duplicateExists = existingRaces.any((race) {
        return race.name == raceName && _isSameLocalDate(race.raceDate, date);
      });

      if (duplicateExists) {
        skippedCount += 1;
        continue;
      }

      final createdRace = await createRace(
        name: raceName,
        raceDate: DateTime(date.year, date.month, date.day),
        seriesName: normalizedSeriesName,
        entryFeeMinor: entryFeeMinor,
        currencyCode: currencyCode,
      );
      existingRaces.add(createdRace);
      createdRaces.add(createdRace);
    }

    return BulkRaceCreationResult(
      createdRaces: createdRaces,
      skippedCount: skippedCount,
    );
  }

  Future<BulkRaceCreationResult> createRacesFromSchedule({
    required List<ImportedRaceScheduleEntry> entries,
    String? fallbackNamePrefix,
    String? fallbackSeriesName,
    int entryFeeMinor = 0,
    String currencyCode = 'USD',
  }) async {
    if (entries.isEmpty) {
      throw const FormatException(
        'Import a file with at least one race date before creating the season.',
      );
    }

    final trimmedFallbackNamePrefix = fallbackNamePrefix?.trim() ?? '';
    final normalizedFallbackSeriesName =
        fallbackSeriesName?.trim().isEmpty == true
        ? null
        : fallbackSeriesName?.trim();

    if (trimmedFallbackNamePrefix.isEmpty &&
        entries.any((entry) => (entry.raceName?.trim().isEmpty ?? true))) {
      throw const FormatException(
        'Add a race title prefix or include a race name column in the schedule file.',
      );
    }

    final existingRaces = await listRaces();
    final createdRaces = <Race>[];
    var skippedCount = 0;

    for (final entry in entries) {
      final resolvedDate = DateTime(
        entry.raceDate.year,
        entry.raceDate.month,
        entry.raceDate.day,
      );
      final resolvedName = (entry.raceName?.trim().isNotEmpty ?? false)
          ? entry.raceName!.trim()
          : _buildBulkRaceName(
              namePrefix: trimmedFallbackNamePrefix,
              date: resolvedDate,
            );
      final resolvedSeriesName = entry.seriesName?.trim().isNotEmpty ?? false
          ? entry.seriesName!.trim()
          : normalizedFallbackSeriesName;

      final duplicateExists = existingRaces.any((race) {
        return race.name == resolvedName &&
            _isSameLocalDate(race.raceDate, resolvedDate);
      });

      if (duplicateExists) {
        skippedCount += 1;
        continue;
      }

      final createdRace = await createRace(
        name: resolvedName,
        raceDate: resolvedDate,
        seriesName: resolvedSeriesName,
        entryFeeMinor: entryFeeMinor,
        currencyCode: currencyCode,
      );
      existingRaces.add(createdRace);
      createdRaces.add(createdRace);
    }

    return BulkRaceCreationResult(
      createdRaces: createdRaces,
      skippedCount: skippedCount,
    );
  }

  Future<Race> startRace(int raceId) async {
    final race = await _databaseService.getRace(raceId);
    if (race == null) {
      throw StateError('Race not found.');
    }
    if (race.isFinished) {
      throw StateError('Finished races cannot be restarted.');
    }
    if (race.isRunning && race.gunTime != null) {
      return race;
    }
    final updated = race.copyWith(
      status: RaceStatus.running,
      gunTime: DateTime.now().toUtc(),
      clearEndTime: true,
    );
    return _databaseService.updateRace(updated);
  }

  Future<Race> endRace(int raceId) async {
    final race = await _databaseService.getRace(raceId);
    if (race == null) {
      throw StateError('Race not found.');
    }
    if (race.isFinished) {
      return race;
    }
    if (!race.isRunning) {
      throw StateError('Only a running race can be ended.');
    }
    final endedAt = DateTime.now().toUtc();
    final finalizedEndTime =
        race.gunTime != null && endedAt.isBefore(race.gunTime!)
        ? race.gunTime!
        : endedAt;

    return _databaseService.updateRace(
      race.copyWith(status: RaceStatus.finished, endTime: finalizedEndTime),
    );
  }

  Future<FinishScanResult> startCurrentRaceFromScanner() async {
    final race = await resolveSelectedRace();
    if (race == null) {
      return FinishScanResult.validationError(
        'Select or create today\'s race before starting the clock.',
      );
    }

    try {
      final startedRace = await startRace(race.id);
      return FinishScanResult.raceStarted(
        gunTime: startedRace.gunTime ?? DateTime.now().toUtc(),
      );
    } catch (error) {
      return FinishScanResult.failure(
        userFacingErrorMessage(
          error,
          fallback: 'The race could not be started right now.',
        ),
      );
    }
  }

  Future<List<RaceResultRow>> getResults(int raceId) {
    return _databaseService.getRaceResults(raceId);
  }

  Future<List<RunnerPointsSummary>> listRaceRunnerPointsSummaries(int raceId) {
    return _databaseService.listRaceRunnerPointsSummaries(raceId);
  }

  Future<List<OverallRunnerPointsSummary>> listOverallRunnerPointsSummaries() {
    return _databaseService.listOverallRunnerPointsSummaries();
  }

  Future<RunnerPointsSummary> awardPointsToRunner({
    required int raceId,
    required int runnerId,
    required int points,
  }) async {
    if (points <= 0) {
      throw const FormatException(
        'Enter a whole number greater than zero for the points to add.',
      );
    }

    final updatedSummary = await _databaseService.transaction((db) async {
      final entry = await _databaseService.getRaceEntryForRunner(
        runnerId: runnerId,
        raceId: raceId,
        executor: db,
      );
      if (entry == null) {
        throw StateError('That racer is not registered in the selected race.');
      }

      await _databaseService.awardRunnerPoints(
        runnerId: runnerId,
        raceId: raceId,
        points: points,
        executor: db,
      );

      final summary = await _databaseService.getRaceRunnerPointsSummary(
        raceId: raceId,
        runnerId: runnerId,
        executor: db,
      );
      if (summary == null) {
        throw StateError('The updated points total could not be loaded.');
      }
      return summary;
    });

    return updatedSummary;
  }

  Future<OverallRunnerPointsSummary> adjustRunnerPoints({
    required int raceId,
    required int runnerId,
    required int pointsDelta,
  }) async {
    if (pointsDelta == 0) {
      throw const FormatException(
        'Enter a positive or negative number so the total can be adjusted.',
      );
    }

    final updatedSummary = await _databaseService.transaction((db) async {
      final entry = await _databaseService.getRaceEntryForRunner(
        runnerId: runnerId,
        raceId: raceId,
        executor: db,
      );
      if (entry == null) {
        throw StateError('That racer is not registered in the selected race.');
      }

      await _databaseService.awardRunnerPoints(
        runnerId: runnerId,
        raceId: raceId,
        points: pointsDelta,
        executor: db,
      );

      final summary = await _databaseService.getOverallRunnerPointsSummary(
        runnerId: runnerId,
        executor: db,
      );
      if (summary == null) {
        throw StateError('The updated overall points could not be loaded.');
      }
      return summary;
    });

    return updatedSummary;
  }

  Future<Race?> resolveSelectedRace() async {
    final runningRace = await getRunningRace();
    if (runningRace != null) {
      return runningRace;
    }

    final todayRace = await getRaceScheduledForDate(DateTime.now());
    if (todayRace != null) {
      return todayRace;
    }

    final settings = await _settingsService.loadSettings();
    final selectedRaceId = settings.selectedRaceId;
    if (selectedRaceId != null) {
      final selectedRace = await _databaseService.getRace(selectedRaceId);
      if (selectedRace != null) {
        return selectedRace;
      }
    }
    return _databaseService.getCurrentRace();
  }

  Future<CheckInResult> lookupRunnerForCheckIn(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      return CheckInResult.validationError(
        'Enter a runner name before printing a label.',
      );
    }

    final race = await resolveSelectedRace();
    if (race == null) {
      return CheckInResult.noActiveRace();
    }

    final matches = await _databaseService.searchCheckInMatches(
      race: race,
      query: name,
    );
    if (matches.isEmpty) {
      return CheckInResult.notFound(race: race, query: name);
    }

    final resolvedMatches = _resolvePreferredCheckInMatches(
      rawName: name,
      matches: matches,
    );
    return CheckInResult.matchesFound(race: race, matches: resolvedMatches);
  }

  Future<CheckInResult> createAdHocRunnerAndPrint(
    String rawName, {
    PaymentStatus paymentStatus = PaymentStatus.pending,
    int? raceDistanceId,
  }) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      return CheckInResult.validationError(
        'Enter a runner name before adding a new runner.',
      );
    }

    final race = await resolveSelectedRace();
    if (race == null) {
      return CheckInResult.noActiveRace();
    }

    try {
      final match = await _databaseService.transaction((db) async {
        final normalizedName = DatabaseService.normalizeName(name);
        var runner = await _databaseService.getRunnerByNormalizedName(
          normalizedName,
          executor: db,
        );

        if (runner == null) {
          runner = await _databaseService.createRunner(
            name: name,
            paymentStatus: paymentStatus,
            executor: db,
          );
          if (runner.barcodeValue.startsWith('pending-')) {
            runner = await _databaseService.updateRunnerBarcode(
              runnerId: runner.id,
              barcodeValue: _barcodeService.buildRunnerBarcode(runner.id),
              executor: db,
            );
          }
        }

        var entry = await _databaseService.getRaceEntryForRunner(
          runnerId: runner.id,
          raceId: race.id,
          executor: db,
        );
        if (entry == null) {
          entry = await _databaseService.createRaceEntry(
            runnerId: runner.id,
            raceId: race.id,
            barcodeValue: runner.barcodeValue,
            raceDistanceId: raceDistanceId,
            executor: db,
          );
        } else if (raceDistanceId != null &&
            entry.raceDistanceId != raceDistanceId) {
          entry = await _databaseService.updateRaceEntryDetails(
            entryId: entry.id,
            raceDistanceId: raceDistanceId,
            clearRaceDistanceId: false,
            executor: db,
          );
        }

        return CheckInMatch(runner: runner, entry: entry, race: race);
      });

      return printCheckInMatch(match);
    } catch (error) {
      return CheckInResult.failure(
        userFacingErrorMessage(
          error,
          fallback:
              'The new runner could not be added right now. Please try again.',
        ),
      );
    }
  }

  Future<List<CheckInMatch>> listCheckInRoster(Race race) {
    return _databaseService.listCheckInMatches(race: race);
  }

  Future<void> updateRosterEntry({
    required int runnerId,
    required int entryId,
    required String name,
    required String barcodeValue,
    required PaymentStatus paymentStatus,
    MembershipStatus membershipStatus = MembershipStatus.unknown,
    String? city,
    String? gender,
    String? bibNumber,
    int? age,
    int? raceDistanceId,
    int? elapsedTimeMs,
    String? paceOverride,
  }) async {
    final trimmedName = name.trim();
    final trimmedBarcode = barcodeValue.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('Runner name cannot be empty.');
    }
    if (trimmedBarcode.isEmpty) {
      throw const FormatException('Barcode cannot be empty.');
    }
    if (age != null && age < 0) {
      throw const FormatException('Age must be zero or greater.');
    }
    if (elapsedTimeMs != null && elapsedTimeMs < 0) {
      throw const FormatException('Elapsed time cannot be negative.');
    }

    await _databaseService.transaction((db) async {
      await _databaseService.updateRunnerDetails(
        runnerId: runnerId,
        name: trimmedName,
        barcodeValue: trimmedBarcode,
        paymentStatus: paymentStatus,
        membershipStatus: membershipStatus,
        city: city,
        gender: gender,
        executor: db,
      );
      await _databaseService.updateRaceEntryDetails(
        entryId: entryId,
        bibNumber: bibNumber,
        clearBibNumber: bibNumber == null || bibNumber.trim().isEmpty,
        age: age,
        clearAge: age == null,
        raceDistanceId: raceDistanceId,
        clearRaceDistanceId: raceDistanceId == null,
        elapsedTimeMs: elapsedTimeMs,
        clearElapsedTime: elapsedTimeMs == null,
        paceOverride: paceOverride,
        clearPaceOverride: paceOverride == null || paceOverride.trim().isEmpty,
        executor: db,
      );
    });
  }

  Future<CheckInResult> printCheckInMatch(CheckInMatch match) async {
    final checkedInMatch = await _ensureCheckedInMatch(match);
    final printerStatus = await _printerService.printLabel(
      _barcodeService.buildLabelDocument(
        race: checkedInMatch.race,
        runner: checkedInMatch.runner,
        entry: checkedInMatch.entry,
      ),
    );

    return CheckInResult.printed(
      match: checkedInMatch,
      printerStatus: printerStatus,
    );
  }

  Future<PrinterStatus> printStartRaceCommandLabel() async {
    final race = await resolveSelectedRace();
    if (race == null) {
      return PrinterStatus.error(
        message:
            'Create or select today\'s race before printing the start barcode.',
      );
    }

    return _printerService.printLabel(
      _barcodeService.buildCommandLabelDocument(
        label: 'START RACE',
        barcodeValue: BarcodeService.startRaceCommand,
        raceId: race.id,
        raceName: race.name,
      ),
    );
  }

  Future<PrinterStatus> printEarlyStartCommandLabel() async {
    final race = await resolveSelectedRace();
    if (race == null) {
      return PrinterStatus.error(
        message:
            'Create or select today\'s race before printing the early start barcode.',
      );
    }

    return _printerService.printLabel(
      _barcodeService.buildCommandLabelDocument(
        label: 'EARLY START',
        barcodeValue: BarcodeService.earlyStartCommand,
        raceId: race.id,
        raceName: race.name,
      ),
    );
  }

  Future<CheckInResult> printCheckInMatches(List<CheckInMatch> matches) async {
    if (matches.isEmpty) {
      return CheckInResult.validationError(
        'There are no runners ready to print in this list.',
      );
    }

    final updatedMatches = <CheckInMatch>[];
    var printedCount = 0;
    var warningCount = 0;
    PrinterStatus? lastPrinterStatus;

    for (final match in matches) {
      final checkedInMatch = await _ensureCheckedInMatch(match);
      updatedMatches.add(checkedInMatch);
      lastPrinterStatus = await _printerService.printLabel(
        _barcodeService.buildLabelDocument(
          race: checkedInMatch.race,
          runner: checkedInMatch.runner,
          entry: checkedInMatch.entry,
        ),
      );
      if (lastPrinterStatus.isSuccess) {
        printedCount += 1;
      } else {
        warningCount += 1;
      }
    }

    return CheckInResult.bulkPrinted(
      race: matches.first.race,
      matches: updatedMatches,
      printedCount: printedCount,
      warningCount: warningCount,
      printerStatus: lastPrinterStatus,
    );
  }

  Future<FinishScanResult> recordRunnerScan(String rawBarcode) async {
    final barcode = _barcodeService.normalizeScannedBarcode(rawBarcode);
    if (barcode.isEmpty) {
      final result = FinishScanResult.validationError(
        'Scan a runner barcode first.',
      );
      await _logScanOutcome(barcodeValue: rawBarcode, result: result);
      return result;
    }

    final race = await resolveSelectedRace();
    if (race == null) {
      final result = FinishScanResult.validationError(
        'Create or select today\'s race before scanning runners.',
      );
      await _logScanOutcome(barcodeValue: barcode, result: result);
      return result;
    }
    if (race.isFinished) {
      final result = FinishScanResult.failure(
        'This race is already finished. Runner scans can no longer be recorded.',
      );
      await _logScanOutcome(
        raceId: race.id,
        barcodeValue: barcode,
        result: result,
      );
      return result;
    }
    if (race.isRunning) {
      if (race.gunTime == null) {
        final result = FinishScanResult.failure(
          'The global start time is missing. Please return to Race Control.',
        );
        await _logScanOutcome(
          raceId: race.id,
          barcodeValue: barcode,
          result: result,
        );
        return result;
      }
      return recordFinish(barcode);
    }

    return recordEarlyStart(barcode);
  }

  Future<ImportResult> importRoster(RosterImport roster) async {
    final race = await resolveSelectedRace();
    if (race == null) {
      return ImportResult.noActiveRace();
    }
    if (roster.runners.isEmpty) {
      return ImportResult.validationError(
        'The selected file does not contain any runner names.',
      );
    }

    var importedCount = 0;
    var reusedRunnerCount = 0;
    var newRunnerCount = 0;
    var duplicateCount = 0;
    var invalidRowCount = roster.invalidRowCount;
    final seenNames = <String>{};

    try {
      await _databaseService.transaction((db) async {
        final distanceConfigs = await _databaseService.listRaceDistanceConfigs(
          race.id,
          executor: db,
        );
        final defaultDistance = _findPrimaryDistanceConfig(distanceConfigs);
        for (final importedRunner in roster.runners) {
          final trimmedName = importedRunner.name.trim();
          final normalizedName = DatabaseService.normalizeName(trimmedName);
          final importedBarcode = importedRunner.barcodeValue?.trim();
          final importedDistance = importedRunner.distance?.trim();
          if (trimmedName.isEmpty || normalizedName.isEmpty) {
            invalidRowCount += 1;
            continue;
          }
          if (!seenNames.add(normalizedName)) {
            duplicateCount += 1;
            continue;
          }

          final resolvedDistanceConfig =
              importedDistance == null || importedDistance.isEmpty
              ? defaultDistance
              : _resolveImportedDistanceConfig(
                  importedDistance,
                  distanceConfigs,
                );
          if (importedDistance != null &&
              importedDistance.isNotEmpty &&
              resolvedDistanceConfig == null) {
            invalidRowCount += 1;
            continue;
          }
          final resolvedDistanceId = resolvedDistanceConfig?.id;

          var runner = await _databaseService.getRunnerByNormalizedName(
            normalizedName,
            executor: db,
          );
          if (runner == null &&
              importedBarcode != null &&
              importedBarcode.isNotEmpty) {
            final barcodeOwner = await _databaseService.getRunnerByBarcode(
              importedBarcode,
              executor: db,
            );
            if (barcodeOwner != null) {
              final barcodeOwnerName = DatabaseService.normalizeName(
                barcodeOwner.name,
              );
              if (barcodeOwnerName != normalizedName) {
                invalidRowCount += 1;
                continue;
              }
              runner = barcodeOwner;
            }
          }

          if (runner == null) {
            runner = await _databaseService.createRunner(
              name: trimmedName,
              barcodeValue: importedBarcode == null || importedBarcode.isEmpty
                  ? null
                  : importedBarcode,
              paymentStatus: importedRunner.paymentStatus,
              membershipStatus:
                  importedRunner.membershipStatus ?? MembershipStatus.unknown,
              city: importedRunner.city,
              gender: importedRunner.gender,
              executor: db,
            );

            if (runner.barcodeValue.startsWith('pending-')) {
              runner = await _databaseService.updateRunnerBarcode(
                runnerId: runner.id,
                barcodeValue: _barcodeService.buildRunnerBarcode(runner.id),
                executor: db,
              );
            }
            newRunnerCount += 1;
          } else {
            if (importedRunner.paymentStatus != null ||
                importedRunner.membershipStatus != null ||
                importedRunner.city != null ||
                importedRunner.gender != null ||
                runner.name != trimmedName) {
              runner = await _databaseService.updateRunnerDetails(
                runnerId: runner.id,
                name: trimmedName,
                barcodeValue: runner.barcodeValue,
                paymentStatus:
                    importedRunner.paymentStatus ?? runner.paymentStatus,
                membershipStatus:
                    importedRunner.membershipStatus ?? runner.membershipStatus,
                city: importedRunner.city ?? runner.city,
                gender: importedRunner.gender ?? runner.gender,
                executor: db,
              );
            }
            reusedRunnerCount += 1;
          }

          final existingEntry = await _databaseService.getRaceEntryForRunner(
            runnerId: runner.id,
            raceId: race.id,
            executor: db,
          );
          if (existingEntry != null) {
            final targetDistanceId =
                resolvedDistanceId ??
                existingEntry.raceDistanceId ??
                defaultDistance?.id;
            if (importedRunner.bibNumber != null ||
                importedRunner.age != null ||
                targetDistanceId != existingEntry.raceDistanceId) {
              await _databaseService.updateRaceEntryDetails(
                entryId: existingEntry.id,
                bibNumber: importedRunner.bibNumber,
                clearBibNumber: false,
                age: importedRunner.age,
                clearAge: false,
                raceDistanceId: targetDistanceId,
                clearRaceDistanceId: false,
                executor: db,
              );
            }
            duplicateCount += 1;
            continue;
          }

          await _databaseService.createRaceEntry(
            runnerId: runner.id,
            raceId: race.id,
            barcodeValue: runner.barcodeValue,
            bibNumber: importedRunner.bibNumber,
            age: importedRunner.age,
            raceDistanceId: resolvedDistanceId,
            executor: db,
          );
          importedCount += 1;
        }
      });
    } catch (error) {
      return ImportResult.failure(
        userFacingErrorMessage(
          error,
          fallback:
              'The roster could not be imported. Please check the file and try again.',
        ),
      );
    }

    return ImportResult.success(
      sourceName: roster.sourceName,
      importedCount: importedCount,
      reusedRunnerCount: reusedRunnerCount,
      newRunnerCount: newRunnerCount,
      duplicateCount: duplicateCount,
      invalidRowCount: invalidRowCount,
    );
  }

  Future<PrinterStatus> reprintLabel(CheckInMatch match) {
    return _printerService.printLabel(
      _barcodeService.buildLabelDocument(
        race: match.race,
        runner: match.runner,
        entry: match.entry,
      ),
    );
  }

  Future<FinishScanResult> recordFinish(String rawBarcode) async {
    final barcode = _barcodeService.normalizeScannedBarcode(rawBarcode);
    if (barcode.isEmpty) {
      final result = FinishScanResult.validationError('Scan a barcode first.');
      await _logScanOutcome(barcodeValue: rawBarcode, result: result);
      return result;
    }

    final race = await resolveSelectedRace();
    if (race == null || !race.isRunning || race.gunTime == null) {
      final result = FinishScanResult.raceNotStarted();
      await _logScanOutcome(
        raceId: race?.id,
        barcodeValue: barcode,
        result: result,
      );
      return result;
    }

    int? runnerId;
    int? entryId;

    try {
      final result = await _databaseService.transaction((db) async {
        final entry = await _databaseService.getEntryByBarcodeForRace(
          raceId: race.id,
          barcodeValue: barcode,
          executor: db,
        );
        if (entry == null) {
          return FinishScanResult.unknownBarcode(barcode);
        }
        entryId = entry.id;

        final runner = await _databaseService.getRunner(
          entry.runnerId,
          executor: db,
        );
        if (runner == null) {
          return FinishScanResult.failure('Runner record could not be found.');
        }
        runnerId = runner.id;

        if (entry.isFinished) {
          return FinishScanResult.duplicateScan(
            runnerName: runner.name,
            barcodeValue: barcode,
            finishTime: entry.finishTime,
            elapsedTimeMs: entry.elapsedTimeMs,
          );
        }

        final finishTime = DateTime.now().toUtc();
        final startTime = entry.earlyStart && entry.startTime != null
            ? entry.startTime!
            : race.gunTime!;
        final elapsedTimeMs = finishTime.difference(startTime).inMilliseconds;

        await _databaseService.finishRaceEntry(
          entryId: entry.id,
          finishTime: finishTime,
          elapsedTimeMs: elapsedTimeMs < 0 ? 0 : elapsedTimeMs,
          executor: db,
        );

        return FinishScanResult.success(
          runnerName: runner.name,
          barcodeValue: barcode,
          finishTime: finishTime,
          elapsedTimeMs: elapsedTimeMs < 0 ? 0 : elapsedTimeMs,
        );
      });
      await _logScanOutcome(
        raceId: race.id,
        runnerId: runnerId,
        entryId: entryId,
        barcodeValue: barcode,
        result: result,
      );
      return result;
    } catch (error) {
      final result = FinishScanResult.failure(
        userFacingErrorMessage(
          error,
          fallback:
              'The finisher could not be recorded. Please scan the barcode again.',
        ),
      );
      await _logScanOutcome(
        raceId: race.id,
        runnerId: runnerId,
        entryId: entryId,
        barcodeValue: barcode,
        result: result,
      );
      return result;
    }
  }

  Future<FinishScanResult> recordEarlyStart(String rawBarcode) async {
    final barcode = _barcodeService.normalizeScannedBarcode(rawBarcode);
    if (barcode.isEmpty) {
      final result = FinishScanResult.validationError(
        'Scan a runner barcode first.',
      );
      await _logScanOutcome(barcodeValue: rawBarcode, result: result);
      return result;
    }

    final race = await resolveSelectedRace();
    if (race == null) {
      final result = FinishScanResult.validationError(
        'Create or select today\'s race before recording an early start.',
      );
      await _logScanOutcome(barcodeValue: barcode, result: result);
      return result;
    }
    if (race.isFinished) {
      final result = FinishScanResult.failure(
        'This race is already finished. Early starts can no longer be recorded.',
      );
      await _logScanOutcome(
        raceId: race.id,
        barcodeValue: barcode,
        result: result,
      );
      return result;
    }
    if (race.isRunning && race.gunTime != null) {
      final result = FinishScanResult.validationError(
        'The official race has already started. Early starts must be recorded before gun time.',
      );
      await _logScanOutcome(
        raceId: race.id,
        barcodeValue: barcode,
        result: result,
      );
      return result;
    }

    int? runnerId;
    int? entryId;

    try {
      final result = await _databaseService.transaction((db) async {
        final entry = await _databaseService.getEntryByBarcodeForRace(
          raceId: race.id,
          barcodeValue: barcode,
          executor: db,
        );
        if (entry == null) {
          return FinishScanResult.unknownBarcode(barcode);
        }
        entryId = entry.id;

        final runner = await _databaseService.getRunner(
          entry.runnerId,
          executor: db,
        );
        if (runner == null) {
          return FinishScanResult.failure('Runner record could not be found.');
        }
        runnerId = runner.id;
        if (entry.isFinished) {
          return FinishScanResult.failure(
            '${runner.name} is already marked as finished.',
          );
        }
        if (entry.earlyStart && entry.startTime != null) {
          return FinishScanResult.validationError(
            '${runner.name} already has an early start time.',
          );
        }

        final startTime = DateTime.now().toUtc();
        await _databaseService.markEarlyStart(
          entryId: entry.id,
          startTime: startTime,
          executor: db,
        );

        return FinishScanResult.earlyStartRecorded(
          runnerName: runner.name,
          barcodeValue: barcode,
          startTime: startTime,
        );
      });
      await _logScanOutcome(
        raceId: race.id,
        runnerId: runnerId,
        entryId: entryId,
        barcodeValue: barcode,
        result: result,
      );
      return result;
    } catch (error) {
      final result = FinishScanResult.failure(
        userFacingErrorMessage(
          error,
          fallback:
              'The early start could not be recorded. Please scan the runner again.',
        ),
      );
      await _logScanOutcome(
        raceId: race.id,
        runnerId: runnerId,
        entryId: entryId,
        barcodeValue: barcode,
        result: result,
      );
      return result;
    }
  }

  Future<FinishScanResult> simulateNextFinish() async {
    final race = await resolveSelectedRace();
    if (race == null || !race.isRunning) {
      return FinishScanResult.raceNotStarted();
    }

    final unfinished = await _databaseService.listUnfinishedEntries(race.id);
    if (unfinished.isEmpty) {
      return FinishScanResult.validationError(
        'No unfinished runners remain in this race.',
      );
    }

    return recordFinish(unfinished.first.barcodeValue);
  }

  static String formatElapsed(int? elapsedTimeMs) {
    if (elapsedTimeMs == null) {
      return '--';
    }

    final duration = Duration(
      milliseconds: elapsedTimeMs < 0 ? 0 : elapsedTimeMs,
    );
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hundredths = (duration.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds.$hundredths';
    }
    return '$minutes:$seconds.$hundredths';
  }

  static int? parseElapsed(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parts = trimmed.split(':');
    if (parts.length < 2 || parts.length > 3) {
      throw const FormatException(
        'Time must look like MM:SS, MM:SS.S, or H:MM:SS.S',
      );
    }

    final hourPart = parts.length == 3 ? int.tryParse(parts[0]) : 0;
    final minutePart = int.tryParse(parts[parts.length - 2]);
    final secondPart = double.tryParse(parts.last);
    if (hourPart == null || minutePart == null || secondPart == null) {
      throw const FormatException(
        'Time must use only numbers, colons, and an optional decimal.',
      );
    }
    if (minutePart < 0 || secondPart < 0 || secondPart >= 60) {
      throw const FormatException('Minutes and seconds must be valid values.');
    }

    final totalMilliseconds =
        (((hourPart * 60) + minutePart) * 60 * 1000) +
        (secondPart * 1000).round();
    return totalMilliseconds;
  }

  static String formatElapsedInput(int? elapsedTimeMs) {
    return elapsedTimeMs == null ? '' : formatElapsed(elapsedTimeMs);
  }

  static RaceDistanceConfig? _findPrimaryDistanceConfig(
    List<RaceDistanceConfig> configs,
  ) {
    if (configs.isEmpty) {
      return null;
    }
    for (final config in configs) {
      if (config.isPrimary) {
        return config;
      }
    }
    return configs.first;
  }

  static RaceDistanceConfig? _resolveImportedDistanceConfig(
    String rawValue,
    List<RaceDistanceConfig> configs,
  ) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty || configs.isEmpty) {
      return null;
    }

    final normalized = _normalizeDistanceValue(trimmed);
    if (normalized.isNotEmpty) {
      for (final config in configs) {
        if (_normalizeDistanceValue(config.sectionLabel) == normalized) {
          return config;
        }
      }
      for (final config in configs) {
        if (_normalizeDistanceValue(config.name) == normalized) {
          return config;
        }
      }
    }

    final parsedMiles = _parseDistanceMilesValue(trimmed);
    if (parsedMiles == null) {
      return null;
    }

    RaceDistanceConfig? matchedConfig;
    for (final config in configs) {
      if ((config.distanceMiles - parsedMiles).abs() > 0.01) {
        continue;
      }
      if (matchedConfig != null) {
        return null;
      }
      matchedConfig = config;
    }
    return matchedConfig;
  }

  static String _normalizeDistanceValue(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static double? _parseDistanceMilesValue(String value) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(value);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1)!);
  }

  static String formatDistanceMiles(double? distanceMiles) {
    if (distanceMiles == null) {
      return 'Distance not set';
    }
    if (distanceMiles == distanceMiles.roundToDouble()) {
      return '${distanceMiles.toStringAsFixed(0)} miles';
    }
    if ((distanceMiles * 10) == (distanceMiles * 10).roundToDouble()) {
      return '${distanceMiles.toStringAsFixed(1)} miles';
    }
    return '${distanceMiles.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\\.$'), '')} miles';
  }

  static String buildDistanceLabel(String? name, double? distanceMiles) {
    if (name == null || name.trim().isEmpty) {
      return formatDistanceMiles(distanceMiles);
    }
    if (distanceMiles == null) {
      return name.trim();
    }
    return '${name.trim()} - ${formatDistanceMiles(distanceMiles)}';
  }

  static String formatPace({
    required int? elapsedTimeMs,
    required double? distanceMiles,
    String? paceOverride,
  }) {
    final trimmedOverride = paceOverride?.trim();
    if (trimmedOverride != null && trimmedOverride.isNotEmpty) {
      return trimmedOverride;
    }
    if (elapsedTimeMs == null || distanceMiles == null || distanceMiles <= 0) {
      return '';
    }

    final paceMilliseconds = (elapsedTimeMs / distanceMiles).round();
    final duration = Duration(
      milliseconds: paceMilliseconds < 0 ? 0 : paceMilliseconds,
    );
    final hours = duration.inHours;
    final minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(hours > 0 ? 2 : 1, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds/M';
    }
    return '$minutes:$seconds/M';
  }

  static String formatFinishTime(DateTime? timestamp) {
    if (timestamp == null) {
      return '--';
    }
    return DateFormat('HH:mm:ss.SS').format(timestamp.toLocal());
  }

  Future<void> _logScanOutcome({
    int? raceId,
    int? runnerId,
    int? entryId,
    String? barcodeValue,
    required FinishScanResult result,
  }) async {
    final event = switch (result.status) {
      FinishScanStatus.validationError => (
        type: ScanEventType.validationError,
        severity: ScanEventSeverity.warning,
      ),
      FinishScanStatus.raceNotStarted => (
        type: ScanEventType.raceNotStarted,
        severity: ScanEventSeverity.warning,
      ),
      FinishScanStatus.unknownBarcode => (
        type: ScanEventType.unknownBarcode,
        severity: ScanEventSeverity.warning,
      ),
      FinishScanStatus.duplicateScan => (
        type: ScanEventType.duplicateScan,
        severity: ScanEventSeverity.warning,
      ),
      FinishScanStatus.failure => (
        type: ScanEventType.failure,
        severity: ScanEventSeverity.error,
      ),
      FinishScanStatus.idle ||
      FinishScanStatus.success ||
      FinishScanStatus.raceStarted ||
      FinishScanStatus.awaitingEarlyStartRunner ||
      FinishScanStatus.earlyStartRecorded => null,
    };

    if (event == null) {
      return;
    }

    try {
      await _databaseService.logScanEvent(
        raceId: raceId,
        runnerId: runnerId,
        entryId: entryId,
        barcodeValue: barcodeValue ?? result.barcodeValue,
        eventType: event.type,
        severity: event.severity,
        message: result.message,
      );
    } catch (_) {
      // Logging should never block timing operations.
    }
  }

  Future<CheckInMatch> _ensureCheckedInMatch(CheckInMatch match) async {
    if (match.entry.isCheckedIn) {
      return match;
    }

    final updatedEntry = await _databaseService.checkInRaceEntry(
      entryId: match.entry.id,
      checkedInAt: DateTime.now().toUtc(),
    );
    return match.copyWith(entry: updatedEntry);
  }

  List<CheckInMatch> _resolvePreferredCheckInMatches({
    required String rawName,
    required List<CheckInMatch> matches,
  }) {
    if (matches.length <= 1) {
      return matches;
    }

    final normalizedName = DatabaseService.normalizeName(rawName);
    final exactMatches = matches
        .where((match) {
          return DatabaseService.normalizeName(match.runner.name) ==
              normalizedName;
        })
        .toList(growable: false);

    if (exactMatches.isNotEmpty) {
      return exactMatches;
    }

    return matches;
  }

  bool _isSameLocalDate(DateTime left, DateTime right) {
    final leftLocal = left.toLocal();
    final rightLocal = right.toLocal();
    return leftLocal.year == rightLocal.year &&
        leftLocal.month == rightLocal.month &&
        leftLocal.day == rightLocal.day;
  }

  String _buildBulkRaceName({
    required String namePrefix,
    required DateTime date,
  }) {
    return '$namePrefix - ${DateFormat('MMM d, y').format(date)}';
  }
}
