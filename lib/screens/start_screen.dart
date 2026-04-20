import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/settings_provider.dart';
import 'package:race_timer/widgets/admin_access_dialog.dart';
import 'package:race_timer/widgets/branding.dart';
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
                          padding: const EdgeInsets.all(34),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(
                                child: BrandMark(size: 116, borderRadius: 30),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _StartBadge(
                                    icon: Icons.visibility_outlined,
                                    label: 'Large print layout',
                                  ),
                                  _StartBadge(
                                    icon: Icons.touch_app_outlined,
                                    label: 'Big tap targets',
                                  ),
                                  _StartBadge(
                                    icon: Icons.emoji_people_outlined,
                                    label: 'Simple race-day flow',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                AppConstants.appName,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'The locked screen stays focused on runner check-in. Organizers use Choose Race to unlock setup and pick today\'s event.',
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
                              const _StartInstructionList(),
                              const SizedBox(height: 28),
                              SizedBox(
                                height: 104,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(adminAccessProvider.notifier)
                                        .lock();
                                    context.go(AppRoutes.registration);
                                  },
                                  icon: const Icon(
                                    Icons.print_outlined,
                                    size: 34,
                                  ),
                                  label: const Text('Print Barcode'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 84,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _openAdminDashboard(context, ref),
                                  icon: const Icon(Icons.list_alt_outlined),
                                  label: const Text('Choose Race'),
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

class _StartBadge extends StatelessWidget {
  const _StartBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartInstructionList extends StatelessWidget {
  const _StartInstructionList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _StartInstructionRow(
            step: '1',
            message: 'Tap Print Barcode when a racer needs a label.',
          ),
          SizedBox(height: 14),
          _StartInstructionRow(
            step: '2',
            message:
                'Tap Choose Race to unlock organizer tools and select today\'s race.',
          ),
          SizedBox(height: 14),
          _StartInstructionRow(
            step: '3',
            message:
                'Before Global Start, scan the runner barcode to store that racer\'s personal start. After Global Start, scan the same runner barcode again to store the finish.',
          ),
        ],
      ),
    );
  }
}

class _StartInstructionRow extends StatelessWidget {
  const _StartInstructionRow({required this.step, required this.message});

  final String step;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          child: Text(
            step,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
