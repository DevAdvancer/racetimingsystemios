import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/services/race_service.dart';
import 'package:race_timer/widgets/race_clock.dart';
import 'package:race_timer/widgets/status_banner.dart';
import 'package:race_timer/widgets/user_dialogs.dart';

class RaceControlScreen extends ConsumerWidget {
  const RaceControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raceAsync = ref.watch(currentRaceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Race Control'),
        actions: [
          IconButton(
            tooltip: 'Return to start screen',
            onPressed: () {
              ref.read(adminAccessProvider.notifier).lock();
              context.go(AppRoutes.home);
            },
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: raceAsync.when(
            data: (race) {
              if (race == null) {
                return const StatusBanner(
                  title: 'No active race',
                  message: 'Create a race in Setup before starting the clock.',
                  tone: StatusBannerTone.warning,
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBanner(
                      title: race.name,
                      message: _buildRaceStatusMessage(race),
                      tone: race.isRunning
                          ? StatusBannerTone.success
                          : StatusBannerTone.info,
                    ),
                    const SizedBox(height: 20),
                    RaceClock(
                      gunTime: race.gunTime,
                      endTime: race.endTime,
                      isRunning: race.isRunning,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 88,
                      child: ElevatedButton(
                        onPressed: race.isRunning || race.isFinished
                            ? null
                            : () async {
                                final confirmed = await _confirmAction(
                                  context,
                                  title: 'Start race?',
                                  message:
                                      'This will record the global start time for everyone except early starters.',
                                );
                                if (!confirmed) {
                                  return;
                                }
                                try {
                                  await ref
                                      .read(currentRaceProvider.notifier)
                                      .startRace(race.id);
                                  if (context.mounted) {
                                    await showUserMessageDialog(
                                      context,
                                      title: 'Global start recorded',
                                      message:
                                          'The race clock is now running. Runner scans will now record finishes for everyone without an earlier personal start.',
                                      tone: UserDialogTone.success,
                                    );
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    await showUserMessageDialog(
                                      context,
                                      title: 'Could not start race',
                                      message:
                                          'The race could not be started. Please try again.',
                                      tone: UserDialogTone.error,
                                    );
                                  }
                                }
                              },
                        child: const Text('GLOBAL START'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const StatusBanner(
                      title: 'Global start',
                      message:
                          'Use the button above to record the shared gun time for the full field, except early starters.',
                      tone: StatusBannerTone.info,
                    ),
                    const SizedBox(height: 20),
                    const StatusBanner(
                      title: 'Early starters',
                      message:
                          'Before Global Start, scan the runner barcode in the scanner screen to give that runner a personal early start. After Global Start, scan runner barcodes again to record finishes.',
                      tone: StatusBannerTone.info,
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => StatusBanner(
              title: 'Race control unavailable',
              message: userFacingErrorMessage(
                error,
                fallback:
                    'Race control is not available right now. Please return to the dashboard and try again.',
              ),
              tone: StatusBannerTone.error,
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    return showUserConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: 'Yes',
      cancelText: 'No',
    );
  }

  String _buildRaceStatusMessage(Race race) {
    final finalTotal = race.totalElapsedTimeMs == null
        ? null
        : RaceService.formatElapsed(race.totalElapsedTimeMs);
    if (finalTotal != null && race.isFinished) {
      return 'Status: ${race.statusLabel} • Final total $finalTotal';
    }
    return 'Status: ${race.statusLabel}';
  }
}
