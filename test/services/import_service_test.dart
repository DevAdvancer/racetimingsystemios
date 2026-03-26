import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/services/import_service.dart';

void main() {
  group('ImportService', () {
    const service = ImportService();

    test('exposes iOS-safe type groups for csv and xlsx import', () {
      expect(ImportService.supportedTypeGroups, isNotEmpty);

      final group = ImportService.supportedTypeGroups.single;
      expect(group.extensions, containsAll(<String>['csv', 'xlsx']));
      expect(
        group.uniformTypeIdentifiers,
        containsAll(<String>[
          'public.comma-separated-values-text',
          'org.openxmlformats.spreadsheetml.sheet',
        ]),
      );
    });

    test('parses csv files with a utf8 bom and barcode column', () {
      final bytes = Uint8List.fromList(<int>[
        0xEF,
        0xBB,
        0xBF,
        ...'Name,Barcode\nJordan Lee,RT-000777\n'.codeUnits,
      ]);

      final roster = service.parseRosterFile(
        fileName: 'roster.csv',
        bytes: bytes,
      );

      expect(roster.runners, hasLength(1));
      expect(roster.runners.first.name, 'Jordan Lee');
      expect(roster.runners.first.barcodeValue, 'RT-000777');
    });

    test('combines first and last name columns from utf16 csv exports', () {
      final bytes = _utf16LeWithBom(
        'First Name,Last Name,Barcode\nTaylor,Smith,RT-000888\n',
      );

      final roster = service.parseRosterFile(
        fileName: 'utf16-roster.csv',
        bytes: bytes,
      );

      expect(roster.runners, hasLength(1));
      expect(roster.runners.first.name, 'Taylor Smith');
      expect(roster.runners.first.barcodeValue, 'RT-000888');
    });

    test('parses xlsx files with a Name column', () {
      final workbook = Excel.createExcel();
      final sheet = workbook['Sheet1'];
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Name');
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'Morgan Diaz',
      );

      final roster = service.parseRosterFile(
        fileName: 'race-day.xlsx',
        bytes: Uint8List.fromList(workbook.save()!),
      );

      expect(roster.runners, hasLength(1));
      expect(roster.runners.first.name, 'Morgan Diaz');
    });

    test('parses payment and membership status columns when present', () {
      final bytes = Uint8List.fromList(
        'Name,Barcode,Paid,Membership Status\nJordan Lee,RT-000777,No,Member\n'
            .codeUnits,
      );

      final roster = service.parseRosterFile(
        fileName: 'roster.csv',
        bytes: bytes,
      );

      expect(roster.runners, hasLength(1));
      expect(roster.runners.first.paymentStatus, PaymentStatus.pending);
      expect(roster.runners.first.membershipStatus, MembershipStatus.member);
    });

    test('tracks invalid rows with missing runner names', () {
      final bytes = Uint8List.fromList(
        'Name,Barcode\nJordan Lee,RT-000777\n,RT-000888\n'.codeUnits,
      );

      final roster = service.parseRosterFile(
        fileName: 'roster.csv',
        bytes: bytes,
      );

      expect(roster.runners, hasLength(1));
      expect(roster.invalidRowCount, 1);
    });

    test('parses race schedule files with date, race, and series columns', () {
      final bytes = Uint8List.fromList(
        'Race Date,Race Name,Series Name\n2026-03-28,Saturday Park Run - Mar 28,Spring Series\n'
            .codeUnits,
      );

      final schedule = service.parseRaceScheduleFile(
        fileName: 'schedule.csv',
        bytes: bytes,
      );

      expect(schedule.entries, hasLength(1));
      expect(schedule.entries.first.raceDate, DateTime(2026, 3, 28));
      expect(schedule.entries.first.raceName, 'Saturday Park Run - Mar 28');
      expect(schedule.entries.first.seriesName, 'Spring Series');
    });

    test('tracks invalid rows in imported race schedules', () {
      final bytes = Uint8List.fromList(
        'Date,Race Name\n2026-03-28,Saturday Park Run - Mar 28\nnot-a-date,Week 2\n'
            .codeUnits,
      );

      final schedule = service.parseRaceScheduleFile(
        fileName: 'schedule.csv',
        bytes: bytes,
      );

      expect(schedule.entries, hasLength(1));
      expect(schedule.invalidRowCount, 1);
    });
  });
}

Uint8List _utf16LeWithBom(String value) {
  final bytes = BytesBuilder();
  bytes.add(const <int>[0xFF, 0xFE]);
  for (final codeUnit in value.codeUnits) {
    bytes.add(<int>[codeUnit & 0xFF, (codeUnit >> 8) & 0xFF]);
  }
  return bytes.toBytes();
}
