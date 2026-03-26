import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_entry.dart';
import 'package:race_timer/models/runner.dart';

class LabelDocument {
  const LabelDocument({
    required this.runnerName,
    required this.barcodeValue,
    required this.raceId,
    required this.raceName,
  });

  final String runnerName;
  final String barcodeValue;
  final int raceId;
  final String raceName;

  Map<String, Object?> toMap({
    required String printerHost,
    required String printerMedia,
  }) {
    return <String, Object?>{
      'runnerName': runnerName,
      'barcodeValue': barcodeValue,
      'raceId': raceId,
      'raceName': raceName,
      'printerHost': printerHost,
      'printerMedia': printerMedia,
    };
  }
}

class BarcodeService {
  const BarcodeService();

  static const startRaceCommand = 'START RACE';
  static const earlyStartCommand = 'EARLY START';

  String normalizeScannedBarcode(String rawValue) {
    return rawValue.trim().toUpperCase();
  }

  bool isStartRaceCommand(String rawValue) {
    return normalizeScannedBarcode(rawValue) == startRaceCommand;
  }

  bool isEarlyStartCommand(String rawValue) {
    return normalizeScannedBarcode(rawValue) == earlyStartCommand;
  }

  String buildRunnerBarcode(int runnerId) {
    return 'RT-${runnerId.toString().padLeft(6, '0')}';
  }

  LabelDocument buildLabelDocument({
    required Race race,
    required Runner runner,
    required RaceEntry entry,
  }) {
    return LabelDocument(
      runnerName: runner.name,
      barcodeValue: entry.barcodeValue,
      raceId: race.id,
      raceName: race.name,
    );
  }

  LabelDocument buildCommandLabelDocument({
    required String label,
    required String barcodeValue,
    required int raceId,
    required String raceName,
  }) {
    return LabelDocument(
      runnerName: label,
      barcodeValue: barcodeValue,
      raceId: raceId,
      raceName: raceName,
    );
  }
}
