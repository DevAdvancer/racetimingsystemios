import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:race_timer/models/race_schedule_import.dart';
import 'package:race_timer/models/roster_import.dart';
import 'package:race_timer/models/runner.dart';

class ImportService {
  const ImportService();

  static const List<XTypeGroup> supportedTypeGroups = <XTypeGroup>[
    XTypeGroup(
      label: 'Excel and CSV Files',
      extensions: <String>['xlsx', 'csv'],
      mimeTypes: <String>[
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/csv',
      ],
      uniformTypeIdentifiers: <String>[
        'org.openxmlformats.spreadsheetml.sheet',
        'public.comma-separated-values-text',
      ],
      webWildCards: <String>['.xlsx', '.csv'],
    ),
  ];

  Future<RosterImport?> pickRoster() async {
    final file = await openFile(acceptedTypeGroups: supportedTypeGroups);
    if (file == null) {
      return null;
    }

    return parseRosterFile(
      fileName: file.name,
      bytes: await file.readAsBytes(),
    );
  }

  Future<RaceScheduleImport?> pickRaceSchedule() async {
    final file = await openFile(acceptedTypeGroups: supportedTypeGroups);
    if (file == null) {
      return null;
    }

    return parseRaceScheduleFile(
      fileName: file.name,
      bytes: await file.readAsBytes(),
    );
  }

  @visibleForTesting
  RosterImport parseRosterFile({
    required String fileName,
    required Uint8List bytes,
  }) {
    final rows = _loadRows(fileName: fileName, bytes: bytes);
    final parsed = _extractRunnerRows(rows);

    return RosterImport(
      sourceName: fileName,
      runners: parsed.runners,
      invalidRowCount: parsed.invalidRowCount,
    );
  }

  @visibleForTesting
  RaceScheduleImport parseRaceScheduleFile({
    required String fileName,
    required Uint8List bytes,
  }) {
    final rows = _loadRows(fileName: fileName, bytes: bytes);
    final parsed = _extractRaceScheduleRows(rows);
    return RaceScheduleImport(
      sourceName: fileName,
      entries: parsed.entries,
      invalidRowCount: parsed.invalidRowCount,
    );
  }

  _ParsedRunnerRows _extractRunnerRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      return const _ParsedRunnerRows(
        runners: <ImportedRunnerData>[],
        invalidRowCount: 0,
      );
    }

    final header = rows.first.map((cell) => '$cell'.trim()).toList();
    final detectedNameIndex = _detectNameColumn(header);
    final detectedFirstNameIndex = _detectFirstNameColumn(header);
    final detectedLastNameIndex = _detectLastNameColumn(header);
    final detectedBarcodeIndex = _detectBarcodeColumn(header);
    final detectedCityIndex = _detectCityColumn(header);
    final detectedBibNumberIndex = _detectBibNumberColumn(header);
    final detectedAgeIndex = _detectAgeColumn(header);
    final detectedGenderIndex = _detectGenderColumn(header);
    final detectedDistanceIndex = _detectDistanceColumn(header);
    final detectedPaymentStatusIndex = _detectPaymentStatusColumn(header);
    final detectedMembershipStatusIndex = _detectMembershipStatusColumn(header);
    final hasHeader = _looksLikeHeader(header);

    final runners = <ImportedRunnerData>[];
    var invalidRowCount = 0;

    for (final row in rows.skip(hasHeader ? 1 : 0)) {
      final name = _buildRunnerName(
        row,
        detectedNameIndex: detectedNameIndex,
        detectedFirstNameIndex: detectedFirstNameIndex,
        detectedLastNameIndex: detectedLastNameIndex,
      ).trim();
      if (name.isEmpty) {
        invalidRowCount += 1;
        continue;
      }

      final barcodeValue = detectedBarcodeIndex == null
          ? null
          : _readColumn(row, detectedBarcodeIndex);
      final city = detectedCityIndex == null
          ? null
          : _readOptionalColumn(row, detectedCityIndex);
      final bibNumber = detectedBibNumberIndex == null
          ? null
          : _readOptionalColumn(row, detectedBibNumberIndex);
      final age = detectedAgeIndex == null
          ? null
          : _parseAge(_readColumn(row, detectedAgeIndex));
      final gender = detectedGenderIndex == null
          ? null
          : _readOptionalColumn(row, detectedGenderIndex);
      final distance = detectedDistanceIndex == null
          ? null
          : _readOptionalColumn(row, detectedDistanceIndex);
      final paymentStatus = detectedPaymentStatusIndex == null
          ? null
          : _parsePaymentStatus(_readColumn(row, detectedPaymentStatusIndex));
      final membershipStatus = detectedMembershipStatusIndex == null
          ? null
          : _parseMembershipStatus(
              _readColumn(row, detectedMembershipStatusIndex),
            );

      runners.add(
        ImportedRunnerData(
          name: name,
          barcodeValue: barcodeValue == null || barcodeValue.isEmpty
              ? null
              : barcodeValue,
          paymentStatus: paymentStatus,
          membershipStatus: membershipStatus,
          distance: distance,
          city: city,
          bibNumber: bibNumber,
          age: age,
          gender: gender,
        ),
      );
    }

    return _ParsedRunnerRows(
      runners: runners,
      invalidRowCount: invalidRowCount,
    );
  }

  _ParsedRaceScheduleRows _extractRaceScheduleRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      return const _ParsedRaceScheduleRows(
        entries: <ImportedRaceScheduleEntry>[],
        invalidRowCount: 0,
      );
    }

    final header = rows.first.map((cell) => '$cell'.trim()).toList();
    final detectedDateIndex = _detectRaceDateColumn(header);
    final detectedNameIndex = _detectRaceTitleColumn(header);
    final detectedSeriesNameIndex = _detectSeriesNameColumn(header);
    final hasHeader =
        detectedDateIndex != null ||
        detectedNameIndex != null ||
        detectedSeriesNameIndex != null;

    final entries = <ImportedRaceScheduleEntry>[];
    var invalidRowCount = 0;

    for (final row in rows.skip(hasHeader ? 1 : 0)) {
      final rawDate = _readColumn(row, detectedDateIndex ?? 0);
      final parsedDate = _parseScheduleDate(rawDate);
      if (parsedDate == null) {
        invalidRowCount += 1;
        continue;
      }

      final raceName = detectedNameIndex == null
          ? (hasHeader ? null : _readOptionalColumn(row, 1))
          : _readOptionalColumn(row, detectedNameIndex);
      final seriesName = detectedSeriesNameIndex == null
          ? null
          : _readOptionalColumn(row, detectedSeriesNameIndex);

      entries.add(
        ImportedRaceScheduleEntry(
          raceDate: parsedDate,
          raceName: raceName,
          seriesName: seriesName,
        ),
      );
    }

    return _ParsedRaceScheduleRows(
      entries: entries,
      invalidRowCount: invalidRowCount,
    );
  }

  bool _looksLikeHeader(List<String> cells) {
    return _detectNameColumn(cells) != null ||
        _detectFirstNameColumn(cells) != null ||
        _detectLastNameColumn(cells) != null ||
        _detectBarcodeColumn(cells) != null ||
        _detectCityColumn(cells) != null ||
        _detectBibNumberColumn(cells) != null ||
        _detectAgeColumn(cells) != null ||
        _detectGenderColumn(cells) != null ||
        _detectDistanceColumn(cells) != null ||
        _detectPaymentStatusColumn(cells) != null ||
        _detectMembershipStatusColumn(cells) != null;
  }

  int? _detectNameColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'name' ||
          normalized == 'runnername' ||
          normalized == 'fullname' ||
          normalized == 'participantname' ||
          normalized == 'participant') {
        return index;
      }
    }
    return null;
  }

  int? _detectFirstNameColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'firstname' ||
          normalized == 'givenname' ||
          normalized == 'forename' ||
          normalized == 'participantfirstname' ||
          normalized == 'runnerfirstname') {
        return index;
      }
    }
    return null;
  }

  int? _detectLastNameColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'lastname' ||
          normalized == 'surname' ||
          normalized == 'familyname' ||
          normalized == 'participantlastname' ||
          normalized == 'runnerlastname') {
        return index;
      }
    }
    return null;
  }

  int? _detectBarcodeColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'barcode' ||
          normalized == 'barcodevalue' ||
          normalized == 'code') {
        return index;
      }
    }
    return null;
  }

  int? _detectCityColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'city' ||
          normalized == 'town' ||
          normalized == 'location' ||
          normalized == 'hometown') {
        return index;
      }
    }
    return null;
  }

  int? _detectBibNumberColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'bib' ||
          normalized == 'bibnumber' ||
          normalized == 'bibno' ||
          normalized == 'bib#' ||
          normalized == 'bibnum') {
        return index;
      }
    }
    return null;
  }

  int? _detectAgeColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'age' ||
          normalized == 'runnerage' ||
          normalized == 'participantage') {
        return index;
      }
    }
    return null;
  }

  int? _detectGenderColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'gender' ||
          normalized == 'gend' ||
          normalized == 'sex' ||
          normalized == 'runnergender') {
        return index;
      }
    }
    return null;
  }

  int? _detectDistanceColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'distance' ||
          normalized == 'racedistance' ||
          normalized == 'distancename' ||
          normalized == 'distancecategory' ||
          normalized == 'distancegroup') {
        return index;
      }
    }
    return null;
  }

  int? _detectPaymentStatusColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'paymentstatus' ||
          normalized == 'payment' ||
          normalized == 'paidstatus' ||
          normalized == 'paid') {
        return index;
      }
    }
    return null;
  }

  int? _detectMembershipStatusColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'membershipstatus' ||
          normalized == 'membership' ||
          normalized == 'memberstatus' ||
          normalized == 'clubmembership') {
        return index;
      }
    }
    return null;
  }

  int? _detectRaceDateColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'date' ||
          normalized == 'racedate' ||
          normalized == 'eventdate' ||
          normalized == 'day' ||
          normalized == 'scheduleddate') {
        return index;
      }
    }
    return null;
  }

  int? _detectRaceTitleColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'race' ||
          normalized == 'racename' ||
          normalized == 'title' ||
          normalized == 'racetitle' ||
          normalized == 'eventname') {
        return index;
      }
    }
    return null;
  }

  int? _detectSeriesNameColumn(List<String> cells) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized = _normalizeHeader(cells[index]);
      if (normalized == 'series' ||
          normalized == 'seriesname' ||
          normalized == 'season' ||
          normalized == 'leaguename') {
        return index;
      }
    }
    return null;
  }

  String _normalizeHeader(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _readColumn(List<dynamic> row, int index) {
    if (index >= row.length) {
      return '';
    }
    return '${row[index]}'.trim();
  }

  String? _readOptionalColumn(List<dynamic> row, int index) {
    final value = _readColumn(row, index).trim();
    return value.isEmpty ? null : value;
  }

  String _buildRunnerName(
    List<dynamic> row, {
    required int? detectedNameIndex,
    required int? detectedFirstNameIndex,
    required int? detectedLastNameIndex,
  }) {
    if (detectedNameIndex != null) {
      return _readColumn(row, detectedNameIndex);
    }

    final firstName = detectedFirstNameIndex == null
        ? ''
        : _readColumn(row, detectedFirstNameIndex);
    final lastName = detectedLastNameIndex == null
        ? ''
        : _readColumn(row, detectedLastNameIndex);
    final combined = <String>[
      firstName,
      lastName,
    ].where((value) => value.trim().isNotEmpty).join(' ').trim();
    if (combined.isNotEmpty) {
      return combined;
    }

    return _readColumn(row, 0);
  }

  PaymentStatus? _parsePaymentStatus(String rawValue) {
    final normalized = _normalizeHeader(rawValue);
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'paid' ||
        normalized == 'yes' ||
        normalized == 'y' ||
        normalized == 'true' ||
        normalized == 'complete' ||
        normalized == 'completed') {
      return PaymentStatus.paid;
    }
    if (normalized == 'pending' ||
        normalized == 'unpaid' ||
        normalized == 'no' ||
        normalized == 'n' ||
        normalized == 'false') {
      return PaymentStatus.pending;
    }
    if (normalized == 'waived' ||
        normalized == 'comped' ||
        normalized == 'complimentary') {
      return PaymentStatus.waived;
    }
    if (normalized == 'refunded' || normalized == 'refund') {
      return PaymentStatus.refunded;
    }
    return null;
  }

  MembershipStatus? _parseMembershipStatus(String rawValue) {
    final normalized = _normalizeHeader(rawValue);
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'member' ||
        normalized == 'active' ||
        normalized == 'current') {
      return MembershipStatus.member;
    }
    if (normalized == 'nonmember' ||
        normalized == 'guest' ||
        normalized == 'visitor') {
      return MembershipStatus.nonMember;
    }
    if (normalized == 'expired' ||
        normalized == 'inactive' ||
        normalized == 'lapsed') {
      return MembershipStatus.expired;
    }
    return MembershipStatus.unknown;
  }

  int? _parseAge(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final numericValue = num.tryParse(trimmed);
    if (numericValue == null) {
      return null;
    }
    return numericValue.round();
  }

  DateTime? _parseScheduleDate(String rawValue) {
    final trimmedValue = rawValue.trim();
    if (trimmedValue.isEmpty) {
      return null;
    }

    final formats = <DateFormat>[
      DateFormat('yyyy-MM-dd'),
      DateFormat('M/d/yyyy'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('MMM d, y'),
      DateFormat('MMMM d, y'),
    ];

    for (final format in formats) {
      try {
        final candidate = format.parseStrict(trimmedValue);
        return DateTime(candidate.year, candidate.month, candidate.day);
      } catch (_) {
        // Try the next supported date format.
      }
    }

    return null;
  }

  List<List<dynamic>> _loadRows({
    required String fileName,
    required Uint8List bytes,
  }) {
    final extension = path.extension(fileName).toLowerCase();
    return switch (extension) {
      '.xlsx' => _loadExcelRows(bytes),
      '.csv' => _loadCsvRows(bytes),
      _ => throw const FormatException(
        'Unsupported file type. Please use a .xlsx or .csv file.',
      ),
    };
  }

  List<List<dynamic>> _loadCsvRows(Uint8List bytes) {
    return const CsvDecoder(
      dynamicTyping: false,
    ).convert(_decodeTextBytes(bytes));
  }

  List<List<dynamic>> _loadExcelRows(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final table = workbook.tables.isEmpty ? null : workbook.tables.values.first;
    if (table == null) {
      return const <List<dynamic>>[];
    }

    return table.rows
        .map(
          (row) => row
              .map((cell) => _stringifyExcelCell(cell))
              .toList(growable: false),
        )
        .toList(growable: false);
  }

  String _decodeTextBytes(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2), Endian.little);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2), Endian.big);
    }

    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  String _decodeUtf16(Uint8List bytes, Endian endian) {
    final byteData = ByteData.sublistView(bytes);
    final codeUnits = <int>[];
    for (var index = 0; index + 1 < bytes.length; index += 2) {
      codeUnits.add(byteData.getUint16(index, endian));
    }
    return String.fromCharCodes(codeUnits).trim();
  }

  String _stringifyExcelCell(Object? cell) {
    if (cell == null) {
      return '';
    }

    final dynamic dynamicCell = cell;
    final dynamic value = dynamicCell.value;
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }
}

class _ParsedRunnerRows {
  const _ParsedRunnerRows({
    required this.runners,
    required this.invalidRowCount,
  });

  final List<ImportedRunnerData> runners;
  final int invalidRowCount;
}

class _ParsedRaceScheduleRows {
  const _ParsedRaceScheduleRows({
    required this.entries,
    required this.invalidRowCount,
  });

  final List<ImportedRaceScheduleEntry> entries;
  final int invalidRowCount;
}
