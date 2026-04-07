import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/platform_support.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/overall_runner_points_summary.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/models/runner_points_summary.dart';
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

  static const List<String> rosterTemplateHeaders = <String>[
    'Name',
    'City',
    'Bib No',
    'Age',
    'Gend',
    'Barcode',
    'Payment Status',
    'Membership Status',
    'Distance',
  ];

  String buildCsv({required Race race, required List<RaceResultRow> rows}) {
    final sections = _buildDistanceSections(race: race, rows: rows);
    final data = <List<dynamic>>[
      <String>['Race Name', race.name],
      <String>['Race Date', _formatDateOnly(race.raceDate)],
      <String>[],
    ];

    for (final section in sections) {
      data.add(<String>[section.title]);
      data.add(<String>[
        'Overall',
        'Name',
        'City',
        'Bib No',
        'Age',
        'Gend',
        'Barcode',
        'Payment Status',
        'Check-In Time',
        'Start Time',
        'Finish Time',
        'Time',
        'Pace',
        'Early Start',
        'Status',
      ]);
      data.addAll(
        section.rows.map(
          (row) => <String>[
            row.overallPlace,
            row.runnerName,
            row.city,
            row.bibNumber,
            row.age,
            row.gender,
            row.barcodeValue,
            row.paymentStatus,
            row.checkInTime,
            row.startTime,
            row.finishTime,
            row.time,
            row.pace,
            row.earlyStart,
            row.status,
          ],
        ),
      );
      data.add(<String>[]);
    }

    return const CsvEncoder().convert(data);
  }

  String buildFileName(Race race, {DateTime? exportedAt}) {
    final exportMoment = exportedAt ?? DateTime.now();
    final raceDate = DateFormat('yyyyMMdd').format(race.raceDate.toLocal());
    final raceName = _slugify(race.name);
    return '${AppConstants.resultsFilePrefix}_${raceDate}_${raceName}_race-${race.id}_${exportMoment.millisecondsSinceEpoch}.csv';
  }

  String buildPdfFileName(Race race, {DateTime? exportedAt}) {
    final exportMoment = exportedAt ?? DateTime.now();
    final raceDate = DateFormat('yyyyMMdd').format(race.raceDate.toLocal());
    final raceName = _slugify(race.name);
    return '${AppConstants.resultsPdfFilePrefix}_${raceDate}_${raceName}_race-${race.id}_${exportMoment.millisecondsSinceEpoch}.pdf';
  }

  String buildPointsCsv({
    required Race race,
    required List<RunnerPointsSummary> rows,
  }) {
    final data = <List<dynamic>>[
      <String>[
        'Race Name',
        'Race Date',
        'Runner Name',
        'Barcode',
        'Points This Race',
        'Total Points',
        'Award Count',
        'Last Awarded At',
      ],
      ...rows.map(
        (row) => <String>[
          race.name,
          _formatDateOnly(race.raceDate),
          row.runnerName,
          row.barcodeValue,
          row.pointsInRace.toString(),
          row.totalPoints.toString(),
          row.awardCount.toString(),
          _formatTimestamp(row.lastAwardedAt),
        ],
      ),
    ];
    return const CsvEncoder().convert(data);
  }

  String buildPointsFileName(Race race, {DateTime? exportedAt}) {
    final exportMoment = exportedAt ?? DateTime.now();
    final raceDate = DateFormat('yyyyMMdd').format(race.raceDate.toLocal());
    final raceName = _slugify(race.name);
    return '${AppConstants.pointsFilePrefix}_${raceDate}_${raceName}_race-${race.id}_${exportMoment.millisecondsSinceEpoch}.csv';
  }

  String buildOverallPointsCsv({
    required String? latestRaceName,
    required int totalRaceCount,
    required List<OverallRunnerPointsSummary> rows,
  }) {
    final data = <List<dynamic>>[
      <String>['Latest Race', latestRaceName ?? ''],
      <String>['Total Races', totalRaceCount.toString()],
      <String>[],
      <String>[
        'Runner Name',
        'Barcode',
        'Total Points',
        'Award Count',
        'Latest Points Race',
        'Last Awarded At',
      ],
      ...rows.map(
        (row) => <String>[
          row.runnerName,
          row.barcodeValue,
          row.totalPoints.toString(),
          row.awardCount.toString(),
          row.latestRaceName ?? '',
          _formatTimestamp(row.lastAwardedAt),
        ],
      ),
    ];
    return const CsvEncoder().convert(data);
  }

  String buildOverallPointsFileName({
    required String? latestRaceName,
    DateTime? exportedAt,
  }) {
    final exportMoment = exportedAt ?? DateTime.now();
    final latestRaceSlug = _slugify(latestRaceName ?? 'overall');
    return '${AppConstants.overallPointsFilePrefix}_${latestRaceSlug}_${exportMoment.millisecondsSinceEpoch}.csv';
  }

  String buildRosterTemplateFileName({DateTime? exportedAt}) {
    final exportMoment = exportedAt ?? DateTime.now();
    return '${AppConstants.rosterTemplateFilePrefix}_${exportMoment.millisecondsSinceEpoch}.xlsx';
  }

  Future<ExportResult> exportResults({
    required Race race,
    required List<RaceResultRow> rows,
  }) async {
    return _exportTextFile(
      fileName: buildFileName(race),
      contents: buildCsv(race: race, rows: rows),
      successMessage:
          'Results CSV for ${race.name} (${_formatRaceDate(race.raceDate)}) saved successfully.',
      saveFailureFallback:
          'The results CSV could not be saved. Please choose a different location and try again.',
      shareText: 'Race results for ${race.name}',
      shareSubject: '${AppConstants.appName} Results Export',
      shareReadyMessage: 'Results CSV is ready to share.',
      shareFallbackMessage:
          'Results CSV for ${race.name} (${_formatRaceDate(race.raceDate)}) was saved on this device even though the share sheet could not open here.',
    );
  }

  Future<ExportResult> exportResultsPdf({
    required Race race,
    required List<RaceResultRow> rows,
  }) async {
    return _exportBinaryFile(
      fileName: buildPdfFileName(race),
      bytes: await buildResultsPdfBytes(race: race, rows: rows),
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'PDF', extensions: <String>['pdf']),
      ],
      successMessage:
          'Results PDF for ${race.name} (${_formatRaceDate(race.raceDate)}) saved successfully.',
      saveFailureFallback:
          'The results PDF could not be saved. Please choose a different location and try again.',
      shareText: 'Race results sheet for ${race.name}',
      shareSubject: '${AppConstants.appName} Results PDF Export',
      shareReadyMessage: 'Results PDF is ready to share.',
      shareFallbackMessage:
          'Results PDF for ${race.name} (${_formatRaceDate(race.raceDate)}) was saved on this device even though the share sheet could not open here.',
    );
  }

  Future<ExportResult> exportPoints({
    required Race race,
    required List<RunnerPointsSummary> rows,
  }) {
    return _exportTextFile(
      fileName: buildPointsFileName(race),
      contents: buildPointsCsv(race: race, rows: rows),
      successMessage:
          'Points CSV for ${race.name} (${_formatRaceDate(race.raceDate)}) saved successfully.',
      saveFailureFallback:
          'The points CSV could not be saved. Please choose a different location and try again.',
      shareText: 'Race points for ${race.name}',
      shareSubject: '${AppConstants.appName} Points Export',
      shareReadyMessage: 'Points CSV is ready to share.',
      shareFallbackMessage:
          'Points CSV for ${race.name} (${_formatRaceDate(race.raceDate)}) was saved on this device even though the share sheet could not open here.',
    );
  }

  Future<ExportResult> exportOverallPoints({
    required String? latestRaceName,
    required int totalRaceCount,
    required List<OverallRunnerPointsSummary> rows,
  }) {
    return _exportTextFile(
      fileName: buildOverallPointsFileName(latestRaceName: latestRaceName),
      contents: buildOverallPointsCsv(
        latestRaceName: latestRaceName,
        totalRaceCount: totalRaceCount,
        rows: rows,
      ),
      successMessage: 'Overall points CSV saved successfully.',
      saveFailureFallback:
          'The overall points CSV could not be saved. Please choose a different location and try again.',
      shareText: 'Overall race points standings',
      shareSubject: '${AppConstants.appName} Overall Points Export',
      shareReadyMessage: 'Overall points CSV is ready to share.',
      shareFallbackMessage:
          'Overall points CSV was saved on this device even though the share sheet could not open here.',
    );
  }

  Future<ExportResult> exportRosterTemplate() async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Roster Template'];
    for (var index = 0; index < rosterTemplateHeaders.length; index += 1) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: index, rowIndex: 0))
          .value = TextCellValue(
        rosterTemplateHeaders[index],
      );
    }

    return _exportBinaryFile(
      fileName: buildRosterTemplateFileName(),
      bytes: Uint8List.fromList(workbook.save()!),
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'Excel',
          extensions: <String>['xlsx'],
          mimeTypes: <String>[
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ],
        ),
      ],
      successMessage: 'Roster Excel template saved successfully.',
      saveFailureFallback:
          'The roster Excel template could not be saved. Please choose a different location and try again.',
      shareText: '${AppConstants.appName} roster template',
      shareSubject: '${AppConstants.appName} Roster Template',
      shareReadyMessage: 'Roster Excel template is ready to share.',
      shareFallbackMessage:
          'The roster Excel template was saved on this device even though the share sheet could not open here.',
    );
  }

  static String _formatTimestamp(DateTime? value) {
    return value?.toLocal().toIso8601String() ?? '';
  }

  static String _formatDateOnly(DateTime value) {
    return DateFormat('yyyy-MM-dd').format(value.toLocal());
  }

  Future<Uint8List> buildResultsPdfBytes({
    required Race race,
    required List<RaceResultRow> rows,
  }) async {
    final document = pw.Document();
    final sections = _buildDistanceSections(race: race, rows: rows);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => <pw.Widget>[
          pw.Text(
            _formatRaceDateLong(race.raceDate),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            race.name,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Overall Finish List',
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(height: 18),
          if (sections.isEmpty)
            pw.Text(
              'No roster rows were available for export.',
              style: const pw.TextStyle(fontSize: 12),
            )
          else
            ...sections.expand((section) sync* {
              yield pw.Text(
                section.title,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              );
              yield pw.SizedBox(height: 8);
              yield pw.TableHelper.fromTextArray(
                headers: const <String>[
                  'Overall',
                  'Name',
                  'City',
                  'Bib No',
                  'Age',
                  'Gend',
                  'Time',
                  'Pace',
                ],
                data: section.rows
                    .map(
                      (row) => <String>[
                        row.overallPlace,
                        row.runnerName,
                        row.city,
                        row.bibNumber,
                        row.age,
                        row.gender,
                        row.time,
                        row.pace,
                      ],
                    )
                    .toList(growable: false),
                headerStyle: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
              );
              yield pw.SizedBox(height: 16);
            }),
        ],
      ),
    );

    return document.save();
  }

  Future<File> _writeMobileTextFile(String fileName, String contents) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(path.join(directory.path, fileName));
    await file.writeAsString(contents);
    return file;
  }

  Future<File> _writeMobileBinaryFile(String fileName, Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(path.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<ExportResult> _exportTextFile({
    required String fileName,
    required String contents,
    required String successMessage,
    required String saveFailureFallback,
    required String shareText,
    required String shareSubject,
    required String shareReadyMessage,
    required String shareFallbackMessage,
  }) async {
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
        await file.writeAsString(contents);
        return ExportResult.success(file.path, successMessage);
      } catch (error) {
        return ExportResult.failure(
          userFacingErrorMessage(error, fallback: saveFailureFallback),
        );
      }
    }

    try {
      final file = await _writeMobileTextFile(fileName, contents);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: shareText,
          subject: shareSubject,
        ),
      );
      return ExportResult.success(file.path, shareReadyMessage);
    } catch (_) {
      final file = await _writeMobileTextFile(fileName, contents);
      return ExportResult.success(file.path, shareFallbackMessage);
    }
  }

  Future<ExportResult> _exportBinaryFile({
    required String fileName,
    required Uint8List bytes,
    required List<XTypeGroup> acceptedTypeGroups,
    required String successMessage,
    required String saveFailureFallback,
    required String shareText,
    required String shareSubject,
    required String shareReadyMessage,
    required String shareFallbackMessage,
  }) async {
    if (PlatformSupport.prefersSaveDialogForExport) {
      try {
        final location = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: acceptedTypeGroups,
        );
        if (location == null) {
          return ExportResult.failure('Export canceled.');
        }

        final file = File(location.path);
        await file.writeAsBytes(bytes, flush: true);
        return ExportResult.success(file.path, successMessage);
      } catch (error) {
        return ExportResult.failure(
          userFacingErrorMessage(error, fallback: saveFailureFallback),
        );
      }
    }

    try {
      final file = await _writeMobileBinaryFile(fileName, bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: shareText,
          subject: shareSubject,
        ),
      );
      return ExportResult.success(file.path, shareReadyMessage);
    } catch (_) {
      final file = await _writeMobileBinaryFile(fileName, bytes);
      return ExportResult.success(file.path, shareFallbackMessage);
    }
  }

  String _formatRaceDate(DateTime value) {
    return DateFormat('MMM d, y').format(value.toLocal());
  }

  String _formatRaceDateLong(DateTime value) {
    return DateFormat('MMMM d, y').format(value.toLocal());
  }

  String _slugify(String value) {
    final cleaned = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'race' : cleaned;
  }

  List<_DistanceExportSection> _buildDistanceSections({
    required Race race,
    required List<RaceResultRow> rows,
  }) {
    if (rows.isEmpty) {
      return const <_DistanceExportSection>[];
    }

    final grouped = <String, List<RaceResultRow>>{};
    final titlesInOrder = <String>[];

    for (final row in rows) {
      final title = row.distanceName == null && row.distanceMiles == null
          ? race.name
          : RaceService.buildDistanceLabel(row.distanceName, row.distanceMiles);
      if (!grouped.containsKey(title)) {
        grouped[title] = <RaceResultRow>[];
        titlesInOrder.add(title);
      }
      grouped[title]!.add(row);
    }

    return titlesInOrder
        .map((title) {
          final sectionRows = grouped[title]!.toList(growable: false)
            ..sort((left, right) {
              final leftElapsed = left.elapsedTimeMs;
              final rightElapsed = right.elapsedTimeMs;
              if (leftElapsed == null && rightElapsed == null) {
                return _compareNullableDate(left.finishTime, right.finishTime);
              }
              if (leftElapsed == null) {
                return 1;
              }
              if (rightElapsed == null) {
                return -1;
              }
              final byElapsed = leftElapsed.compareTo(rightElapsed);
              if (byElapsed != 0) {
                return byElapsed;
              }
              return _compareNullableDate(left.finishTime, right.finishTime);
            });

          var overallPlace = 0;
          final exportRows = sectionRows
              .map((row) {
                final hasFinish =
                    row.finishTime != null || row.elapsedTimeMs != null;
                final placement = hasFinish ? (++overallPlace).toString() : '';
                return _ExportResultRow(
                  overallPlace: placement,
                  runnerName: row.runnerName,
                  city: row.city ?? '',
                  bibNumber: row.bibNumber ?? '',
                  age: row.age?.toString() ?? '',
                  gender: row.gender ?? '',
                  barcodeValue: row.barcodeValue,
                  paymentStatus: row.paymentStatus.label,
                  checkInTime: _formatTimestamp(row.checkedInAt),
                  startTime: _formatTimestamp(row.startTime ?? race.gunTime),
                  finishTime: _formatTimestamp(row.finishTime),
                  time: RaceService.formatElapsed(row.elapsedTimeMs),
                  pace: RaceService.formatPace(
                    elapsedTimeMs: row.elapsedTimeMs,
                    distanceMiles: row.distanceMiles,
                    paceOverride: row.paceOverride,
                  ),
                  earlyStart: row.earlyStart ? 'Yes' : 'No',
                  status: row.statusLabel,
                );
              })
              .toList(growable: false);

          return _DistanceExportSection(title: title, rows: exportRows);
        })
        .toList(growable: false);
  }

  int _compareNullableDate(DateTime? left, DateTime? right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return left.compareTo(right);
  }
}

class _DistanceExportSection {
  const _DistanceExportSection({required this.title, required this.rows});

  final String title;
  final List<_ExportResultRow> rows;
}

class _ExportResultRow {
  const _ExportResultRow({
    required this.overallPlace,
    required this.runnerName,
    required this.city,
    required this.bibNumber,
    required this.age,
    required this.gender,
    required this.barcodeValue,
    required this.paymentStatus,
    required this.checkInTime,
    required this.startTime,
    required this.finishTime,
    required this.time,
    required this.pace,
    required this.earlyStart,
    required this.status,
  });

  final String overallPlace;
  final String runnerName;
  final String city;
  final String bibNumber;
  final String age;
  final String gender;
  final String barcodeValue;
  final String paymentStatus;
  final String checkInTime;
  final String startTime;
  final String finishTime;
  final String time;
  final String pace;
  final String earlyStart;
  final String status;
}
