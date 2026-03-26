import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/settings_provider.dart';
import 'package:race_timer/widgets/admin_access_dialog.dart';
import 'package:race_timer/widgets/status_banner.dart';

class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentRaceAsync = ref.watch(currentRaceProvider);

    return Scaffold(
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                colorScheme.primaryContainer,
                colorScheme.tertiaryContainer.withValues(alpha: 0.8),
                theme.scaffoldBackgroundColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                AppConstants.appName,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Open the barcode print kiosk only when you need it, or unlock the organizer dashboard.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),
                              currentRaceAsync.when(
                                data: (race) => StatusBanner(
                                  title:
                                      race?.name ?? 'No active race selected',
                                  message: race == null
                                      ? 'Choose a race from the organizer dashboard before volunteers start printing.'
                                      : 'Current race status: ${race.statusLabel}',
                                  tone: race == null
                                      ? StatusBannerTone.warning
                                      : race.isRunning
                                      ? StatusBannerTone.success
                                      : StatusBannerTone.info,
                                ),
                                loading: () => const LinearProgressIndicator(),
                                error: (error, stackTrace) => const StatusBanner(
                                  title: 'Race status unavailable',
                                  message:
                                      'The app could not load the current race right now.',
                                  tone: StatusBannerTone.error,
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                height: 90,
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      context.go(AppRoutes.registration),
                                  icon: const Icon(Icons.print_outlined),
                                  label: const Text('Print Barcode'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 72,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _openAdminDashboard(context, ref),
                                  icon: const Icon(
                                    Icons.admin_panel_settings_outlined,
                                  ),
                                  label: const Text('Organizer Dashboard'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openAdminDashboard(BuildContext context, WidgetRef ref) async {
    if (ref.read(adminAccessProvider)) {
      if (context.mounted) {
        context.go(AppRoutes.adminHome);
      }
      return;
    }

    final settings = await ref.read(settingsServiceProvider).loadSettings();
    if (!context.mounted) {
      return;
    }

    final accessGranted = await showAdminAccessDialog(
      context,
      expectedPasscode: settings.adminPasscode,
    );
    if (!accessGranted || !context.mounted) {
      return;
    }

    ref.read(adminAccessProvider.notifier).unlock();
    context.go(AppRoutes.adminHome);
  }
}
