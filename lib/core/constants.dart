class AppConstants {
  const AppConstants._();

  static const appName = 'RaceTimer';
  static const databaseName = 'race_timer.db';
  static const printerChannel = 'com.racetimer/printer';

  static const defaultCurrencyCode = 'USD';
  static const defaultEntryFeeMinor = 0;
  static const defaultPrinterMedia = '62mm continuous';
  static const resultsFilePrefix = 'racetimer_results';

  static const settingsDryRunKey = 'settings.dryRunMode';
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
  static const registration = '/register';
  static const raceControl = '/race-control';
  static const scanner = '/scan';
  static const results = '/results';
  static const export = '/export';
  static const diagnostics = '/diagnostics';
  static const setup = '/setup';
}
