import 'package:race_timer/core/constants.dart';

enum AppThemeMode {
  light,
  dark;

  String get label => switch (this) {
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
  };

  String get storageValue => name;

  static AppThemeMode fromStorage(String? value) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => AppThemeMode.light,
    );
  }
}

enum PrinterConnectionType {
  bluetooth,
  network;

  String get label => switch (this) {
    PrinterConnectionType.bluetooth => 'Bluetooth',
    PrinterConnectionType.network => 'Wi-Fi / Network',
  };

  String get storageValue => name;

  String get targetFieldLabel => switch (this) {
    PrinterConnectionType.bluetooth =>
      'Printer Bluetooth name, serial number, or MAC address',
    PrinterConnectionType.network =>
      'Printer IP address, hostname, or discovery name',
  };

  String get targetHelpText => switch (this) {
    PrinterConnectionType.bluetooth =>
      'Enter the Brother QL-820NWB Bluetooth name, serial number, or MAC address manually. Discovery names such as QL-820NWB1997 still map to the QL-820NWB model.',
    PrinterConnectionType.network =>
      'Use Wi-Fi first. Enter the Brother printer IP address or hostname, or leave it blank so the iPad can auto-discover the current QL-820NWB printer on the local network.',
  };

  bool get allowsAutoDiscovery => this == PrinterConnectionType.network;

  static PrinterConnectionType fromStorage(String? value) {
    return PrinterConnectionType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => PrinterConnectionType.network,
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.dryRunMode,
    required this.printerHost,
    required this.printerMedia,
    required this.printerConnectionType,
    required this.adminPasscode,
    required this.selectedRaceId,
    required this.lastScannerCheckAt,
    required this.lastScannerCheckValue,
  });

  final AppThemeMode themeMode;
  final bool dryRunMode;
  final String printerHost;
  final String printerMedia;
  final PrinterConnectionType printerConnectionType;
  final String adminPasscode;
  final int? selectedRaceId;
  final DateTime? lastScannerCheckAt;
  final String? lastScannerCheckValue;

  bool get hasPrinterConfigured =>
      printerHost.trim().isNotEmpty ||
      printerConnectionType.allowsAutoDiscovery;
  bool get hasVerifiedScanner => lastScannerCheckAt != null;

  factory AppSettings.defaults() {
    return const AppSettings(
      themeMode: AppThemeMode.light,
      dryRunMode: false,
      printerHost: AppConstants.defaultPrinterHost,
      printerMedia: AppConstants.defaultPrinterMedia,
      printerConnectionType: PrinterConnectionType.network,
      adminPasscode: '123',
      selectedRaceId: null,
      lastScannerCheckAt: null,
      lastScannerCheckValue: null,
    );
  }

  AppSettings copyWith({
    AppThemeMode? themeMode,
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
      themeMode: themeMode ?? this.themeMode,
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
