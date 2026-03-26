import 'package:race_timer/models/printer_status.dart';

class DiagnosticsReport {
  const DiagnosticsReport({
    required this.databaseHealthy,
    required this.scannerReady,
    required this.scannerMessage,
    required this.scanEventCount,
    required this.recentScanIssues,
    required this.printerStatus,
    required this.dryRunMode,
    required this.messages,
    this.currentRaceName,
  });

  final bool databaseHealthy;
  final bool scannerReady;
  final String scannerMessage;
  final int scanEventCount;
  final List<String> recentScanIssues;
  final PrinterStatus printerStatus;
  final bool dryRunMode;
  final List<String> messages;
  final String? currentRaceName;

  factory DiagnosticsReport.initial() {
    return DiagnosticsReport(
      databaseHealthy: false,
      scannerReady: false,
      scannerMessage: 'Run the scanner check in Organizer Tools.',
      scanEventCount: 0,
      recentScanIssues: const <String>[],
      printerStatus: PrinterStatus.notConfigured(),
      dryRunMode: false,
      messages: const <String>['Run diagnostics to verify the device.'],
    );
  }
}
