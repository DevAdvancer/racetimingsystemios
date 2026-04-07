import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/models/app_settings.dart';
import 'package:race_timer/services/settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  throw UnimplementedError(
    'settingsServiceProvider must be overridden in main().',
  );
});

final settingsProvider = AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends AsyncNotifier<AppSettings> {
  SettingsService get _settingsService => ref.read(settingsServiceProvider);

  @override
  FutureOr<AppSettings> build() {
    return _settingsService.loadSettings();
  }

  Future<AppSettings> saveSettings(AppSettings settings) async {
    final previousSettings = state.asData?.value;
    state = AsyncData(settings);
    try {
      final savedSettings = await _settingsService.saveSettings(settings);
      state = AsyncData(savedSettings);
      return savedSettings;
    } catch (error, stackTrace) {
      if (previousSettings != null) {
        state = AsyncData(previousSettings);
      } else {
        state = AsyncError(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<AppSettings> updateThemeMode(AppThemeMode themeMode) async {
    final currentSettings =
        state.asData?.value ?? await _settingsService.loadSettings();
    return saveSettings(currentSettings.copyWith(themeMode: themeMode));
  }
}
