import 'package:intl/intl.dart';
import 'package:race_timer/models/roster_import.dart';
import 'package:race_timer/models/diagnostics_report.dart';
import 'package:race_timer/services/database_service.dart';
import 'package:race_timer/services/race_service.dart';
import 'package:race_timer/services/printer_service.dart';
import 'package:race_timer/services/settings_service.dart';

class DiagnosticsService {
  DiagnosticsService({
    required DatabaseService databaseService,
    required RaceService raceService,
    required PrinterService printerService,
    required SettingsService settingsService,
  }) : _databaseService = databaseService,
       _raceService = raceService,
       _printerService = printerService,
       _settingsService = settingsService;

  final DatabaseService _databaseService;
  final RaceService _raceService;
  final PrinterService _printerService;
  final SettingsService _settingsService;

  Future<DiagnosticsReport> run() async {
    final databaseHealthy = await _databaseService.runQuickCheck();
    final printerStatus = await _printerService.getStatus();
    final settings = await _settingsService.loadSettings();
    final currentRace = await _raceService.getCurrentRace();
    final recentScanEvents = await _databaseService.listScanEvents(
      raceId: currentRace?.id,
      limit: 3,
    );
    final scannerMessage = settings.lastScannerCheckAt == null
        ? 'Scanner not confirmed yet. Open Organizer Tools and run Scanner Check.'
        : 'Scanner last confirmed at ${DateFormat('MMM d, h:mm a').format(settings.lastScannerCheckAt!.toLocal())}${settings.lastScannerCheckValue == null || settings.lastScannerCheckValue!.isEmpty ? '.' : ' using ${settings.lastScannerCheckValue}.'}';

    final messages = <String>[
      databaseHealthy
          ? 'Database quick check passed.'
          : 'Database quick check failed.',
      printerStatus.message,
      scannerMessage,
      recentScanEvents.isEmpty
          ? 'No scan warnings or errors have been logged for this race.'
          : '${recentScanEvents.length} recent scan warning(s) or error(s) are logged for this race.',
      if (settings.dryRunMode) 'Dry run mode is enabled.',
      if (currentRace != null) 'Current race: ${currentRace.name}.',
    ];

    return DiagnosticsReport(
      databaseHealthy: databaseHealthy,
      scannerReady: settings.hasVerifiedScanner,
      scannerMessage: scannerMessage,
      scanEventCount: recentScanEvents.length,
      recentScanIssues: recentScanEvents
          .map(
            (event) =>
                '${DateFormat('MMM d, h:mm a').format(event.createdAt.toLocal())}: ${event.message}',
          )
          .toList(growable: false),
      printerStatus: printerStatus,
      dryRunMode: settings.dryRunMode,
      messages: messages,
      currentRaceName: currentRace?.name,
    );
  }

  Future<void> seedDryRunData() async {
    var currentRace = await _raceService.resolveSelectedRace();
    currentRace ??= await _raceService.createRace(
      name: 'Practice Race ${DateTime.now().year}',
    );

    final sampleNames = <String>[
      'Test Runner 1',
      'Test Runner 2',
      'Test Runner 3',
      'Test Runner 4',
      'Test Runner 5',
    ];

    await _raceService.importRoster(
      RosterImport(
        sourceName: 'dry-run-seed',
        runners: sampleNames
            .map((name) => ImportedRunnerData(name: name))
            .toList(growable: false),
      ),
    );
  }

  Future<void> clearDryRunData() => _databaseService.clearDryRunData();
}
