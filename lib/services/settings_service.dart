import 'package:race_timer/core/constants.dart';
import 'package:race_timer/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._(this._preferences);

  final SharedPreferences _preferences;

  static Future<SettingsService> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SettingsService._(preferences);
  }

  Future<AppSettings> loadSettings() async {
    return AppSettings(
      themeMode: AppThemeMode.fromStorage(
        _preferences.getString(AppConstants.settingsThemeModeKey),
      ),
      dryRunMode: _preferences.getBool(AppConstants.settingsDryRunKey) ?? false,
      printerHost:
          _preferences.getString(AppConstants.settingsPrinterHostKey) ?? '',
      printerMedia:
          _preferences.getString(AppConstants.settingsPrinterMediaKey) ??
          AppConstants.defaultPrinterMedia,
      printerConnectionType: PrinterConnectionType.fromStorage(
        _preferences.getString(AppConstants.settingsPrinterConnectionTypeKey),
      ),
      adminPasscode:
          _preferences.getString(AppConstants.settingsAdminPasscodeKey) ??
          AppSettings.defaults().adminPasscode,
      selectedRaceId: _preferences.getInt(
        AppConstants.settingsSelectedRaceIdKey,
      ),
      lastScannerCheckAt:
          _preferences.getInt(AppConstants.settingsScannerLastCheckAtKey) ==
              null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              _preferences.getInt(AppConstants.settingsScannerLastCheckAtKey)!,
              isUtc: true,
            ),
      lastScannerCheckValue: _preferences.getString(
        AppConstants.settingsScannerLastCheckValueKey,
      ),
    );
  }

  Future<AppSettings> saveSettings(AppSettings settings) async {
    await _preferences.setString(
      AppConstants.settingsThemeModeKey,
      settings.themeMode.storageValue,
    );
    await _preferences.setBool(
      AppConstants.settingsDryRunKey,
      settings.dryRunMode,
    );
    await _preferences.setString(
      AppConstants.settingsPrinterHostKey,
      settings.printerHost,
    );
    await _preferences.setString(
      AppConstants.settingsPrinterMediaKey,
      settings.printerMedia,
    );
    await _preferences.setString(
      AppConstants.settingsPrinterConnectionTypeKey,
      settings.printerConnectionType.storageValue,
    );
    await _preferences.setString(
      AppConstants.settingsAdminPasscodeKey,
      settings.adminPasscode,
    );
    if (settings.selectedRaceId == null) {
      await _preferences.remove(AppConstants.settingsSelectedRaceIdKey);
    } else {
      await _preferences.setInt(
        AppConstants.settingsSelectedRaceIdKey,
        settings.selectedRaceId!,
      );
    }
    if (settings.lastScannerCheckAt == null) {
      await _preferences.remove(AppConstants.settingsScannerLastCheckAtKey);
    } else {
      await _preferences.setInt(
        AppConstants.settingsScannerLastCheckAtKey,
        settings.lastScannerCheckAt!.toUtc().millisecondsSinceEpoch,
      );
    }
    if (settings.lastScannerCheckValue == null ||
        settings.lastScannerCheckValue!.trim().isEmpty) {
      await _preferences.remove(AppConstants.settingsScannerLastCheckValueKey);
    } else {
      await _preferences.setString(
        AppConstants.settingsScannerLastCheckValueKey,
        settings.lastScannerCheckValue!,
      );
    }
    return settings;
  }
}
