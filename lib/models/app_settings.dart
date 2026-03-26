import 'package:race_timer/core/constants.dart';

enum PrinterConnectionType {
  bluetooth,
  network;

  String get label => switch (this) {
    PrinterConnectionType.bluetooth => 'Bluetooth',
    PrinterConnectionType.network => 'Wi-Fi / Network',
  };

  String get storageValue => name;

  String get targetFieldLabel => switch (this) {
    PrinterConnectionType.bluetooth => 'Printer Bluetooth name or MAC address',
    PrinterConnectionType.network => 'Printer IP address or hostname',
  };

  String get targetHelpText => switch (this) {
    PrinterConnectionType.bluetooth =>
      'Use the paired Brother QL-820NWB Bluetooth name or MAC address.',
    PrinterConnectionType.network =>
      'Use the Brother printer IP address or hostname.',
  };

  static PrinterConnectionType fromStorage(String? value) {
    return PrinterConnectionType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => PrinterConnectionType.bluetooth,
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.dryRunMode,
    required this.printerHost,
    required this.printerMedia,
    required this.printerConnectionType,
    required this.adminPasscode,
    required this.selectedRaceId,
    required this.lastScannerCheckAt,
    required this.lastScannerCheckValue,
  });

  final bool dryRunMode;
  final String printerHost;
  final String printerMedia;
  final PrinterConnectionType printerConnectionType;
  final String adminPasscode;
  final int? selectedRaceId;
  final DateTime? lastScannerCheckAt;
  final String? lastScannerCheckValue;

  bool get hasPrinterConfigured => printerHost.trim().isNotEmpty;
  bool get hasVerifiedScanner => lastScannerCheckAt != null;

  factory AppSettings.defaults() {
    return const AppSettings(
      dryRunMode: false,
      printerHost: '',
      printerMedia: AppConstants.defaultPrinterMedia,
      printerConnectionType: PrinterConnectionType.bluetooth,
      adminPasscode: '123',
      selectedRaceId: null,
      lastScannerCheckAt: null,
      lastScannerCheckValue: null,
    );
  }

  AppSettings copyWith({
    bool? dryRunMode,
    String? printerHost,
    String? printerMedia,
    PrinterConnectionType? printerConnectionType,
    String? adminPasscode,
    int? selectedRaceId,
    DateTime? lastScannerCheckAt,
    String? lastScannerCheckValue,
    bool clearSelectedRaceId = false,
    bool clearScannerCheck = false,
  }) {
    return AppSettings(
      dryRunMode: dryRunMode ?? this.dryRunMode,
      printerHost: printerHost ?? this.printerHost,
      printerMedia: printerMedia ?? this.printerMedia,
      printerConnectionType:
          printerConnectionType ?? this.printerConnectionType,
      adminPasscode: adminPasscode ?? this.adminPasscode,
      selectedRaceId: clearSelectedRaceId
          ? null
          : selectedRaceId ?? this.selectedRaceId,
      lastScannerCheckAt: clearScannerCheck
          ? null
          : lastScannerCheckAt ?? this.lastScannerCheckAt,
      lastScannerCheckValue: clearScannerCheck
          ? null
          : lastScannerCheckValue ?? this.lastScannerCheckValue,
    );
  }
}
