class AppConstants {
  const AppConstants._();

  static const appName = 'RaceTimerApp';
  static const logoAsset = 'assets/branding/roxbury_races_mark.png';
  static const databaseName = 'race_timer.db';
  static const printerChannel = 'com.racetimer/printer';

  static const defaultCurrencyCode = 'USD';
  static const defaultEntryFeeMinor = 0;
  static const defaultPrinterMedia = '62mm';
  static const defaultPrinterHost = 'QL-820NWB1997';
  static const resultsFilePrefix = 'racetimerapp_results';
  static const resultsPdfFilePrefix = 'racetimerapp_results_sheet';
  static const qrPacketPdfFilePrefix = 'racetimerapp_barcode_packet';
  static const pointsFilePrefix = 'racetimerapp_points';
  static const overallPointsFilePrefix = 'racetimerapp_overall_points';
  static const rosterTemplateFilePrefix = 'racetimerapp_roster_template';

  static const settingsDryRunKey = 'settings.dryRunMode';
  static const settingsThemeModeKey = 'settings.themeMode';
  static const settingsPrinterHostKey = 'settings.printerHost';
  static const settingsPrinterMediaKey = 'settings.printerMedia';
  static const settingsPrinterConnectionTypeKey =
      'settings.printerConnectionType';
  static const settingsSelectedRaceIdKey = 'settings.selectedRaceId';
  static const settingsScannerLastCheckAtKey = 'settings.scannerLastCheckAt';
  static const settingsScannerLastCheckValueKey =
      'settings.scannerLastCheckValue';
  static const settingsAdminPasscodeKey = 'settings.adminPasscode';
}

class AppRoutes {
  const AppRoutes._();

  static const home = '/';
  static const adminHome = '/admin';
  static const raceDashboard = '/race-dashboard';
  static const rosterTools = '/roster-tools';
  static const registration = '/register';
  static const raceControl = '/race-control';
  static const scanner = '/scan';
  static const results = '/results';
  static const export = '/export';
  static const overallPoints = '/overall-points';
  static const diagnostics = '/diagnostics';
  static const setup = '/setup';
}
