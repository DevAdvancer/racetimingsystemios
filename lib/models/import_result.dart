enum ImportOutcome {
  idle,
  success,
  canceled,
  noActiveRace,
  validationError,
  failure,
}

class ImportResult {
  const ImportResult({
    required this.outcome,
    required this.message,
    this.sourceName,
    this.importedCount = 0,
    this.reusedRunnerCount = 0,
    this.newRunnerCount = 0,
    this.duplicateCount = 0,
    this.invalidRowCount = 0,
    this.skippedCount = 0,
  });

  final ImportOutcome outcome;
  final String message;
  final String? sourceName;
  final int importedCount;
  final int reusedRunnerCount;
  final int newRunnerCount;
  final int duplicateCount;
  final int invalidRowCount;
  final int skippedCount;

  bool get isSuccess => outcome == ImportOutcome.success;

  factory ImportResult.idle() {
    return const ImportResult(
      outcome: ImportOutcome.idle,
      message: 'Import an Excel or CSV roster into the active race.',
    );
  }

  factory ImportResult.canceled() {
    return const ImportResult(
      outcome: ImportOutcome.canceled,
      message: 'Import canceled.',
    );
  }

  factory ImportResult.noActiveRace() {
    return const ImportResult(
      outcome: ImportOutcome.noActiveRace,
      message: 'Create a race before importing a roster.',
    );
  }

  factory ImportResult.validationError(String message) {
    return ImportResult(
      outcome: ImportOutcome.validationError,
      message: message,
    );
  }

  factory ImportResult.failure(String message) {
    return ImportResult(outcome: ImportOutcome.failure, message: message);
  }

  factory ImportResult.success({
    required String sourceName,
    required int importedCount,
    required int reusedRunnerCount,
    required int newRunnerCount,
    required int duplicateCount,
    required int invalidRowCount,
  }) {
    final skippedCount = duplicateCount + invalidRowCount;
    return ImportResult(
      outcome: ImportOutcome.success,
      sourceName: sourceName,
      importedCount: importedCount,
      reusedRunnerCount: reusedRunnerCount,
      newRunnerCount: newRunnerCount,
      duplicateCount: duplicateCount,
      invalidRowCount: invalidRowCount,
      skippedCount: skippedCount,
      message: _buildSuccessMessage(
        sourceName: sourceName,
        importedCount: importedCount,
        reusedRunnerCount: reusedRunnerCount,
        newRunnerCount: newRunnerCount,
        duplicateCount: duplicateCount,
        invalidRowCount: invalidRowCount,
      ),
    );
  }
}

String _buildSuccessMessage({
  required String sourceName,
  required int importedCount,
  required int reusedRunnerCount,
  required int newRunnerCount,
  required int duplicateCount,
  required int invalidRowCount,
}) {
  final sentences = <String>[
    'Imported $importedCount runners from $sourceName.',
    'Reused $reusedRunnerCount saved barcodes and created $newRunnerCount new runner records.',
  ];

  if (duplicateCount > 0) {
    sentences.add('Skipped $duplicateCount duplicate roster rows.');
  }
  if (invalidRowCount > 0) {
    sentences.add(
      'Ignored $invalidRowCount invalid rows with missing or conflicting data.',
    );
  }

  return sentences.join(' ');
}
