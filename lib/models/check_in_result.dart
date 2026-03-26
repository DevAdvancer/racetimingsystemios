import 'package:race_timer/models/check_in_match.dart';
import 'package:race_timer/models/printer_status.dart';
import 'package:race_timer/models/race.dart';

enum CheckInOutcome {
  idle,
  ready,
  multipleMatches,
  notFound,
  printed,
  printerWarning,
  validationError,
  noActiveRace,
  failure,
}

class CheckInResult {
  const CheckInResult({
    required this.outcome,
    required this.message,
    this.race,
    this.matches = const <CheckInMatch>[],
    this.selectedMatch,
    this.printerStatus,
    this.printedCount = 0,
    this.warningCount = 0,
  });

  final CheckInOutcome outcome;
  final String message;
  final Race? race;
  final List<CheckInMatch> matches;
  final CheckInMatch? selectedMatch;
  final PrinterStatus? printerStatus;
  final int printedCount;
  final int warningCount;

  bool get hasMatches => matches.isNotEmpty;

  factory CheckInResult.idle() {
    return const CheckInResult(
      outcome: CheckInOutcome.idle,
      message:
          'Review the imported race roster, then print labels as riders arrive.',
    );
  }

  factory CheckInResult.noActiveRace() {
    return const CheckInResult(
      outcome: CheckInOutcome.noActiveRace,
      message: 'Create and import a race roster before checking runners in.',
    );
  }

  factory CheckInResult.validationError(String message) {
    return CheckInResult(
      outcome: CheckInOutcome.validationError,
      message: message,
    );
  }

  factory CheckInResult.failure(String message) {
    return CheckInResult(outcome: CheckInOutcome.failure, message: message);
  }

  factory CheckInResult.notFound({required Race race, required String query}) {
    return CheckInResult(
      outcome: CheckInOutcome.notFound,
      race: race,
      message:
          'No runner matched "$query" for ${race.name}. Check the spelling or add this runner now.',
    );
  }

  factory CheckInResult.matchesFound({
    required Race race,
    required List<CheckInMatch> matches,
  }) {
    final outcome = matches.length == 1
        ? CheckInOutcome.ready
        : CheckInOutcome.multipleMatches;
    final message = matches.length == 1
        ? 'Runner found. Print the saved barcode label.'
        : 'Multiple runners match this name. Pick the correct one to print.';

    return CheckInResult(
      outcome: outcome,
      race: race,
      message: message,
      matches: matches,
      selectedMatch: matches.length == 1 ? matches.first : null,
    );
  }

  factory CheckInResult.printed({
    required CheckInMatch match,
    required PrinterStatus printerStatus,
  }) {
    final outcome = printerStatus.isSuccess
        ? CheckInOutcome.printed
        : CheckInOutcome.printerWarning;
    final message = printerStatus.isSuccess
        ? 'The label was printed for ${match.runner.name}.'
        : 'We found ${match.runner.name}, but the label did not print. Please check the printer and try again.';

    return CheckInResult(
      outcome: outcome,
      message: message,
      race: match.race,
      matches: <CheckInMatch>[match],
      selectedMatch: match,
      printerStatus: printerStatus,
      printedCount: printerStatus.isSuccess ? 1 : 0,
      warningCount: printerStatus.isSuccess ? 0 : 1,
    );
  }

  factory CheckInResult.bulkPrinted({
    required Race race,
    required List<CheckInMatch> matches,
    required int printedCount,
    required int warningCount,
    PrinterStatus? printerStatus,
  }) {
    final outcome = warningCount == 0
        ? CheckInOutcome.printed
        : CheckInOutcome.printerWarning;
    final totalCount = printedCount + warningCount;
    final message = warningCount == 0
        ? 'Printed $printedCount ${printedCount == 1 ? 'label' : 'labels'} row by row for ${race.name}.'
        : 'Processed $totalCount labels for ${race.name}. $warningCount ${warningCount == 1 ? 'label needs' : 'labels need'} attention.';

    return CheckInResult(
      outcome: outcome,
      message: message,
      race: race,
      matches: matches,
      selectedMatch: matches.isEmpty ? null : matches.last,
      printerStatus: printerStatus,
      printedCount: printedCount,
      warningCount: warningCount,
    );
  }
}
