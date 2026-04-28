import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/results_provider.dart';
import 'package:race_timer/services/race_service.dart';
import 'package:race_timer/widgets/branding.dart';
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
        title: const BrandAppBarTitle(pageTitle: 'Race Timing'),
        actions: [
          IconButton(
            tooltip: 'Back to Race Dashboard',
            onPressed: () => context.go(AppRoutes.raceDashboard),
            icon: const Icon(Icons.arrow_back),
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
              final raceResultsAsync = ref.watch(raceResultsProvider(race.id));

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
                    _EarlyStartersList(resultsAsync: raceResultsAsync),
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
                                  title: 'Record global start?',
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
                                  ref.invalidate(raceResultsProvider(race.id));
                                  ref.invalidate(resultsProvider);
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
                                      title: 'Could not record global start',
                                      message:
                                          'The global start could not be recorded. Please try again.',
                                      tone: UserDialogTone.error,
                                    );
                                  }
                                }
                              },
                        child: const Text('GLOBAL START'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 88,
                      child: FilledButton(
                        onPressed: !race.isRunning || race.isFinished
                            ? null
                            : () async {
                                final unfinishedCount = await ref
                                    .read(raceServiceProvider)
                                    .countUnfinishedEntries(race.id);
                                if (!context.mounted) {
                                  return;
                                }
                                final confirmed = await _confirmAction(
                                  context,
                                  title: 'Stop race?',
                                  message: unfinishedCount == 0
                                      ? 'This will record the global stop time and close finish scanning for this race.'
                                      : 'This will record the global stop time. $unfinishedCount ${unfinishedCount == 1 ? 'runner has' : 'runners have'} no finish scan yet, so ${unfinishedCount == 1 ? 'that runner will' : 'those runners will'} be completed using the stop time.',
                                );
                                if (!confirmed) {
                                  return;
                                }
                                try {
                                  await ref
                                      .read(currentRaceProvider.notifier)
                                      .endRace(race.id);
                                  ref.invalidate(raceResultsProvider(race.id));
                                  ref.invalidate(resultsProvider);
                                  if (context.mounted) {
                                    await showUserMessageDialog(
                                      context,
                                      title: 'Global stop recorded',
                                      message: unfinishedCount == 0
                                          ? 'The race clock is now stopped and finish scanning is closed.'
                                          : 'The race clock is now stopped. $unfinishedCount ${unfinishedCount == 1 ? 'runner was' : 'runners were'} assigned the global stop time because no finish scan was recorded.',
                                      tone: UserDialogTone.success,
                                    );
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    await showUserMessageDialog(
                                      context,
                                      title: 'Could not stop race',
                                      message:
                                          'The race could not be stopped. Please try again.',
                                      tone: UserDialogTone.error,
                                    );
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onError,
                        ),
                        child: const Text('GLOBAL STOP'),
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
                      title: 'Global stop',
                      message:
                          'Use Global Stop when finish scanning is done. Any checked-in runner who still has no finish scan will be assigned the stop time automatically. If the last unfinished runner in this race is scanned at the finish line first, the race closes automatically.',
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

class _EarlyStartersList extends StatelessWidget {
  const _EarlyStartersList({required this.resultsAsync});

  final AsyncValue<List<RaceResultRow>> resultsAsync;

  @override
  Widget build(BuildContext context) {
    return resultsAsync.when(
      data: (rows) {
        final earlyStarters =
            rows
                .where((row) => row.earlyStart && row.startTime != null)
                .toList(growable: false)
              ..sort(
                (left, right) => left.startTime!.compareTo(right.startTime!),
              );

        if (earlyStarters.isEmpty) {
          return const StatusBanner(
            title: 'Early starters',
            message:
                'No personal start times have been recorded yet. Before the global start, scan a runner barcode in Timing Capture to add one here.',
            tone: StatusBannerTone.info,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusBanner(
              title:
                  '${earlyStarters.length} early ${earlyStarters.length == 1 ? 'starter' : 'starters'}',
              message:
                  'These runners keep their personal start time when the global start is recorded.',
              tone: StatusBannerTone.success,
            ),
            const SizedBox(height: 12),
            ...earlyStarters.map((row) => _EarlyStarterTile(row: row)),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => StatusBanner(
        title: 'Early starters unavailable',
        message: userFacingErrorMessage(
          error,
          fallback: 'The early starter list could not load right now.',
        ),
        tone: StatusBannerTone.error,
      ),
    );
  }
}

class _EarlyStarterTile extends StatelessWidget {
  const _EarlyStarterTile({required this.row});

  final RaceResultRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <String>[
      if (row.bibNumber != null && row.bibNumber!.trim().isNotEmpty)
        'Bib ${row.bibNumber}',
      row.barcodeValue,
    ].join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.directions_run),
        title: Text(row.runnerName),
        subtitle: Text(details),
        trailing: Text(
          RaceService.formatFinishTime(row.startTime),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
