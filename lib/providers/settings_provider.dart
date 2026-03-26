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
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _settingsService.saveSettings(settings),
    );
    return state.requireValue;
  }
}
