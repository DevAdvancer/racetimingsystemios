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
    PrinterConnectionType.bluetooth => 'Printer Bluetooth name or MAC address',
    PrinterConnectionType.network => 'Printer IP address or hostname',
  };

  String get targetHelpText => switch (this) {
    PrinterConnectionType.bluetooth =>
      'Enter the Brother QL-820NWB Bluetooth name or MAC address manually. This saves the target for this iPad.',
    PrinterConnectionType.network =>
      'Use the Brother printer IP address or hostname. The app can check whether the printer is reachable on the current Wi-Fi network.',
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

  bool get hasPrinterConfigured => printerHost.trim().isNotEmpty;
  bool get hasVerifiedScanner => lastScannerCheckAt != null;

  factory AppSettings.defaults() {
    return const AppSettings(
      themeMode: AppThemeMode.light,
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
