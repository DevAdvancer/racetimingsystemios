import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/platform_support.dart';
import 'package:race_timer/core/router.dart';
import 'package:race_timer/core/theme.dart';
import 'package:race_timer/database/database_helper.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/settings_provider.dart';
import 'package:race_timer/services/settings_service.dart';

Future<void> main() async {
  await PlatformSupport.ensureInitialized();
  final databaseHelper = await DatabaseHelper.create();
  await databaseHelper.ensureInitialized();
  final settingsService = await SettingsService.create();

  runApp(
    ProviderScope(
      overrides: [
        databaseHelperProvider.overrideWithValue(databaseHelper),
        settingsServiceProvider.overrideWithValue(settingsService),
      ],
      child: const RaceTimerApp(),
    ),
  );
}

class RaceTimerApp extends ConsumerWidget {
  const RaceTimerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: buildRaceTimerTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
