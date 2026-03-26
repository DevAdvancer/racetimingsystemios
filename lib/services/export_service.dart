import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/platform_support.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/services/race_service.dart';
import 'package:share_plus/share_plus.dart';

class ExportResult {
  const ExportResult({
    required this.succeeded,
    required this.message,
    this.filePath,
  });

  final bool succeeded;
  final String message;
  final String? filePath;

  factory ExportResult.success(String path, String message) {
    return ExportResult(succeeded: true, message: message, filePath: path);
  }

  factory ExportResult.failure(String message) {
    return ExportResult(succeeded: false, message: message);
  }
}

class ExportService {
  const ExportService();

  String buildCsv({required Race race, required List<RaceResultRow> rows}) {
    final data = <List<dynamic>>[
      <String>[
        'Race Name',
        'Race Date',
        'Runner Name',
        'Barcode',
        'Payment Status',
        'Start Time',
        'Finish Time',
        'Elapsed Time',
        'Early Start',
        'Status',
        'Check-In Time',
      ],
      ...rows.map(
        (row) => <String>[
          race.name,
          _formatDateOnly(race.raceDate),
          row.runnerName,
          row.barcodeValue,
          row.paymentStatus.label,
          _formatTimestamp(row.startTime ?? race.gunTime),
          _formatTimestamp(row.finishTime),
          RaceService.formatElapsed(row.elapsedTimeMs),
          row.earlyStart ? 'Yes' : 'No',
          row.statusLabel,
          _formatTimestamp(row.checkedInAt),
        ],
      ),
    ];
    return const CsvEncoder().convert(data);
  }

  String buildFileName(Race race, {DateTime? exportedAt}) {
    final exportMoment = exportedAt ?? DateTime.now();
    final raceDate = DateFormat('yyyyMMdd').format(race.raceDate.toLocal());
    final raceName = _slugify(race.name);
    return '${AppConstants.resultsFilePrefix}_${raceDate}_${raceName}_race-${race.id}_${exportMoment.millisecondsSinceEpoch}.csv';
  }

  Future<ExportResult> exportResults({
    required Race race,
    required List<RaceResultRow> rows,
  }) async {
    final fileName = buildFileName(race);
    final csv = buildCsv(race: race, rows: rows);

    if (PlatformSupport.prefersSaveDialogForExport) {
      try {
        final location = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: const <XTypeGroup>[
            XTypeGroup(label: 'CSV', extensions: <String>['csv']),
          ],
        );
        if (location == null) {
          return ExportResult.failure('Export canceled.');
        }

        final file = File(location.path);
        await file.writeAsString(csv);
        return ExportResult.success(
          file.path,
          'Results CSV for ${race.name} (${_formatRaceDate(race.raceDate)}) saved successfully.',
        );
      } catch (error) {
        return ExportResult.failure(
          userFacingErrorMessage(
            error,
            fallback:
                'The results CSV could not be saved. Please choose a different location and try again.',
          ),
        );
      }
    }

    try {
      final file = await _writeMobileExportFile(fileName, csv);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: 'Race results for ${race.name}',
          subject: 'RaceTimer Results Export',
        ),
      );
      return ExportResult.success(file.path, 'Results CSV is ready to share.');
    } catch (error) {
      final file = await _writeMobileExportFile(fileName, csv);
      return ExportResult.success(
        file.path,
        'Results CSV for ${race.name} (${_formatRaceDate(race.raceDate)}) was saved on this device even though the share sheet could not open here.',
      );
    }
  }

  static String _formatTimestamp(DateTime? value) {
    return value?.toLocal().toIso8601String() ?? '';
  }

  static String _formatDateOnly(DateTime value) {
    return DateFormat('yyyy-MM-dd').format(value.toLocal());
  }

  Future<File> _writeMobileExportFile(String fileName, String csv) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(path.join(directory.path, fileName));
    await file.writeAsString(csv);
    return file;
  }

  String _formatRaceDate(DateTime value) {
    return DateFormat('MMM d, y').format(value.toLocal());
  }

  String _slugify(String value) {
    final cleaned = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'race' : cleaned;
  }
}
