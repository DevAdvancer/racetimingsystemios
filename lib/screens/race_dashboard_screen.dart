import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/core/app_navigation.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/check_in_result.dart';
import 'package:race_timer/models/import_result.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_distance_config.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/models/runner_points_summary.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/check_in_provider.dart';
import 'package:race_timer/providers/import_provider.dart';
import 'package:race_timer/providers/points_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/results_provider.dart';
import 'package:race_timer/services/race_service.dart';
import 'package:race_timer/widgets/branding.dart';
import 'package:race_timer/widgets/primary_action_tile.dart';
import 'package:race_timer/widgets/status_banner.dart';
import 'package:race_timer/widgets/user_dialogs.dart';

class RaceDashboardScreen extends ConsumerWidget {
  const RaceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRace = ref.watch(currentRaceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const BrandAppBarTitle(pageTitle: 'Race Day Console'),
        actions: [
          IconButton(
            tooltip: 'Back to Choose Race',
            onPressed: () => goToAppRoute(context, AppRoutes.adminHome),
            icon: const Icon(Icons.arrow_back),
          ),
          _DashboardOverflowMenu(
            onSelected: (value) => goToAppRoute(context, value),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    colors: <Color>[
                      colorScheme.primaryContainer,
                      colorScheme.tertiaryContainer.withValues(alpha: 0.78),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: currentRace.when(
                  data: (race) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Race Day Console',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          race == null
                              ? 'Choose a race from the main screen before volunteers begin.'
                              : 'Active race: ${race.name} • ${race.statusLabel}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 20),
                        StatusBanner(
                          title: race?.name ?? 'No active race',
                          message: race == null
                              ? 'Go back and choose a race first.'
                              : race.isRunning
                              ? 'The clock is live. Finish scans will record times immediately.'
                              : 'Runner list and label printing are ready for this race.',
                          tone: race == null
                              ? StatusBannerTone.warning
                              : race.isRunning
                              ? StatusBannerTone.success
                              : StatusBannerTone.info,
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => StatusBanner(
                    title: 'Unable to load race',
                    message: userFacingErrorMessage(
                      error,
                      fallback:
                          'The selected race could not be opened. Please go back and choose the race again.',
                    ),
                    tone: StatusBannerTone.error,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = switch (constraints.maxWidth) {
                    >= 1320 => 4,
                    >= 760 => 2,
                    _ => 1,
                  };
                  final mainAxisExtent = switch (crossAxisCount) {
                    4 => 290.0,
                    2 => 310.0,
                    _ => 270.0,
                  };
                  final tiles = [
                    PrimaryActionTile(
                      title: 'Runner Kiosk',
                      subtitle:
                          'Return to the large runner-facing check-in screen.',
                      icon: Icons.badge_outlined,
                      onTap: () {
                        goToAppRoute(context, AppRoutes.registration);
                        ref.read(adminAccessProvider.notifier).lock();
                      },
                    ),
                    PrimaryActionTile(
                      title: 'Race Timing',
                      subtitle: 'Manage gun time, stop time, and race status.',
                      icon: Icons.flag_circle,
                      onTap: () => goToAppRoute(context, AppRoutes.raceControl),
                    ),
                    PrimaryActionTile(
                      title: 'Timing Capture',
                      subtitle:
                          'Capture barcode scans for early starts and finishes.',
                      icon: Icons.qr_code_scanner,
                      onTap: () => goToAppRoute(context, AppRoutes.scanner),
                    ),
                    PrimaryActionTile(
                      title: 'Roster Tools',
                      subtitle:
                          'Edit racer data, distances, and points on one page.',
                      icon: Icons.groups_2_outlined,
                      onTap: () => goToAppRoute(context, AppRoutes.rosterTools),
                    ),
                  ];

                  return GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisExtent: mainAxisExtent,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                    ),
                    children: tiles,
                  );
                },
              ),
              const SizedBox(height: 24),
              currentRace.when(
                data: (race) => _RaceRosterToolsCard(
                  race: race,
                  onImportRunners: race == null
                      ? null
                      : () => _importRunners(context, ref, race),
                  onAddRunner: race == null
                      ? null
                      : () => _addRunner(context, ref, race),
                  onDownloadQrPacketPdf: race == null
                      ? null
                      : () => _downloadQrPacketPdf(context, ref, race),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => StatusBanner(
                  title: 'Roster tools unavailable',
                  message: userFacingErrorMessage(
                    error,
                    fallback:
                        'The selected race roster tools could not load right now.',
                  ),
                  tone: StatusBannerTone.error,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importRunners(
    BuildContext context,
    WidgetRef ref,
    Race race,
  ) async {
    final result = await ref.read(importProvider.notifier).importRoster();
    ref.invalidate(resultsProvider);
    ref.invalidate(checkInProvider);
    ref.invalidate(currentRaceProvider);

    if (!context.mounted) {
      return;
    }

    switch (result.outcome) {
      case ImportOutcome.success:
        await showUserMessageDialog(
          context,
          title: 'Runner import complete',
          message: result.message,
          tone: UserDialogTone.success,
        );
        return;
      case ImportOutcome.noActiveRace:
      case ImportOutcome.validationError:
        await showUserMessageDialog(
          context,
          title: 'Runner import needs attention',
          message: result.message,
          tone: UserDialogTone.warning,
        );
        return;
      case ImportOutcome.failure:
        await showUserMessageDialog(
          context,
          title: 'Runner import failed',
          message: result.message,
          tone: UserDialogTone.error,
        );
        return;
      case ImportOutcome.canceled:
      case ImportOutcome.idle:
        return;
    }
  }

  Future<void> _addRunner(
    BuildContext context,
    WidgetRef ref,
    Race race,
  ) async {
    final distanceConfigs = await ref.read(
      raceDistanceConfigsProvider(race.id).future,
    );
    if (!context.mounted) {
      return;
    }
    final payload = await showDialog<_AddRunnerPayload>(
      context: context,
      builder: (context) =>
          _AddRunnerDialog(race: race, distanceConfigs: distanceConfigs),
    );
    if (payload == null || payload.runnerName.trim().isEmpty) {
      return;
    }

    final result = await ref
        .read(raceServiceProvider)
        .createAdHocRunnerAndPrint(
          payload.runnerName,
          paymentStatus: payload.paymentStatus,
          raceDistanceId: payload.raceDistanceId,
        );
    ref.invalidate(resultsProvider);
    ref.invalidate(checkInProvider);
    ref.invalidate(raceDistanceConfigsProvider(race.id));

    if (!context.mounted) {
      return;
    }

    final tone = result.outcome == CheckInOutcome.printed
        ? UserDialogTone.success
        : result.outcome == CheckInOutcome.printerWarning
        ? UserDialogTone.warning
        : UserDialogTone.error;
    final title = result.outcome == CheckInOutcome.printed
        ? 'Runner added'
        : result.outcome == CheckInOutcome.printerWarning
        ? 'Runner added, printer needs attention'
        : 'Could not add runner';

    await showUserMessageDialog(
      context,
      title: title,
      message: result.message,
      tone: tone,
    );
  }

  Future<void> _awardPoints(
    BuildContext context,
    WidgetRef ref,
    Race race,
  ) async {
    late final List<RunnerPointsSummary> summaries;
    late final List<RaceResultRow> results;

    try {
      final loaded = await Future.wait<Object>([
        ref.read(racePointsProvider(race.id).future),
        ref.read(raceResultsProvider(race.id).future),
      ]);
      summaries = loaded[0] as List<RunnerPointsSummary>;
      results = loaded[1] as List<RaceResultRow>;
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Could not load points table',
        message: userFacingErrorMessage(
          error,
          fallback:
              'The race positions and racer points could not be loaded right now.',
        ),
        tone: UserDialogTone.error,
      );
      return;
    }

    if (!context.mounted) {
      return;
    }
    if (summaries.isEmpty) {
      await showUserMessageDialog(
        context,
        title: 'No racers available',
        message:
            'Import runners or add a runner to ${race.name} before assigning points.',
        tone: UserDialogTone.warning,
      );
      return;
    }

    final payload = await showDialog<_AwardPointsPayload>(
      context: context,
      builder: (context) => _AwardPointsDialog(
        race: race,
        summaries: summaries,
        results: results,
      ),
    );
    if (payload == null) {
      return;
    }

    try {
      final updated = await ref
          .read(raceServiceProvider)
          .awardPointsToRunner(
            raceId: race.id,
            runnerId: payload.runnerId,
            points: payload.points,
          );
      ref.invalidate(racePointsProvider(race.id));
      ref.invalidate(overallPointsProvider);

      if (!context.mounted) {
        return;
      }

      await showUserMessageDialog(
        context,
        title: 'Points saved',
        message:
            '${updated.runnerName} now has ${updated.totalPoints} total points. Added ${payload.points} points for ${race.name}.',
        tone: UserDialogTone.success,
      );
    } on FormatException catch (error) {
      if (!context.mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Points need attention',
        message: error.message,
        tone: UserDialogTone.warning,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Could not save points',
        message: userFacingErrorMessage(
          error,
          fallback:
              'The racer points could not be saved right now. Please try again.',
        ),
        tone: UserDialogTone.error,
      );
    }
  }

  Future<void> _downloadPoints(
    BuildContext context,
    WidgetRef ref,
    Race race,
  ) async {
    final summaries = await ref.read(racePointsProvider(race.id).future);
    if (!context.mounted) {
      return;
    }
    if (summaries.isEmpty) {
      await showUserMessageDialog(
        context,
        title: 'Nothing to export',
        message:
            'Import runners or add a runner to ${race.name} before downloading points.',
        tone: UserDialogTone.warning,
      );
      return;
    }

    final result = await ref
        .read(exportServiceProvider)
        .exportPoints(race: race, rows: summaries);
    if (!context.mounted) {
      return;
    }

    await showUserMessageDialog(
      context,
      title: result.succeeded ? 'Points export ready' : 'Points export failed',
      message: result.message,
      tone: result.succeeded ? UserDialogTone.success : UserDialogTone.error,
    );
  }

  Future<void> _downloadResultsPdf(
    BuildContext context,
    WidgetRef ref,
    Race race,
  ) async {
    final rows = await ref.read(raceResultsProvider(race.id).future);
    if (!context.mounted) {
      return;
    }
    if (rows.isEmpty) {
      await showUserMessageDialog(
        context,
        title: 'Nothing to export',
        message:
            'Import runners or add a runner to ${race.name} before downloading the results sheet.',
        tone: UserDialogTone.warning,
      );
      return;
    }

    final result = await ref
        .read(exportServiceProvider)
        .exportResultsPdf(race: race, rows: rows);
    if (!context.mounted) {
      return;
    }

    await showUserMessageDialog(
      context,
      title: result.succeeded ? 'Results PDF ready' : 'Results PDF failed',
      message: result.message,
      tone: result.succeeded ? UserDialogTone.success : UserDialogTone.error,
    );
  }

  Future<void> _downloadQrPacketPdf(
    BuildContext context,
    WidgetRef ref,
    Race race,
  ) async {
    final roster = await ref.read(raceServiceProvider).listCheckInRoster(race);
    if (!context.mounted) {
      return;
    }
    if (roster.isEmpty) {
      await showUserMessageDialog(
        context,
        title: 'Nothing to export',
        message:
            'Import runners or add a runner to ${race.name} before downloading the barcode packet.',
        tone: UserDialogTone.warning,
      );
      return;
    }

    final result = await ref
        .read(exportServiceProvider)
        .exportQrPacketPdf(race: race, matches: roster);
    if (!context.mounted) {
      return;
    }

    await showUserMessageDialog(
      context,
      title: result.succeeded
          ? 'Barcode packet ready'
          : 'Barcode packet failed',
      message: result.message,
      tone: result.succeeded ? UserDialogTone.success : UserDialogTone.error,
    );
  }

  Future<void> _editRosterEntry(
    BuildContext context,
    WidgetRef ref,
    Race race,
    RaceResultRow row,
  ) async {
    final distanceConfigs = await ref.read(
      raceDistanceConfigsProvider(race.id).future,
    );
    if (!context.mounted) {
      return;
    }
    final payload = await showDialog<_EditRosterEntryPayload>(
      context: context,
      builder: (context) =>
          _EditRosterEntryDialog(row: row, distanceConfigs: distanceConfigs),
    );
    if (payload == null) {
      return;
    }

    try {
      await ref
          .read(raceServiceProvider)
          .updateRosterEntry(
            runnerId: row.runnerId,
            entryId: row.entryId,
            name: payload.name,
            barcodeValue: payload.barcodeValue,
            paymentStatus: payload.paymentStatus,
            membershipStatus: payload.membershipStatus,
            city: payload.city,
            gender: payload.gender,
            bibNumber: payload.bibNumber,
            age: payload.age,
            raceDistanceId: payload.raceDistanceId,
            elapsedTimeMs: payload.elapsedTimeMs,
            paceOverride: payload.paceOverride,
          );
      ref.invalidate(raceResultsProvider(race.id));
      ref.invalidate(resultsProvider);
      ref.invalidate(checkInProvider);
      ref.invalidate(racePointsProvider(race.id));
      ref.invalidate(overallPointsProvider);
      ref.invalidate(raceDistanceConfigsProvider(race.id));

      if (!context.mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Racer data updated',
        message:
            '${payload.name} was updated for ${race.name}. Distance, elapsed time, pace, barcode reuse, and payment status were saved.',
        tone: UserDialogTone.success,
      );
    } on FormatException catch (error) {
      if (!context.mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Data needs attention',
        message: error.message,
        tone: UserDialogTone.warning,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Could not save racer data',
        message: userFacingErrorMessage(
          error,
          fallback:
              'The racer details could not be saved right now. Please try again.',
        ),
        tone: UserDialogTone.error,
      );
    }
  }

  Future<void> _saveDistanceConfig(
    BuildContext context,
    WidgetRef ref,
    Race race, {
    RaceDistanceConfig? existing,
  }) async {
    final payload = await showDialog<_RaceDistancePayload>(
      context: context,
      builder: (context) => _RaceDistanceDialog(existing: existing),
    );
    if (payload == null) {
      return;
    }

    try {
      await ref
          .read(raceServiceProvider)
          .saveRaceDistanceConfig(
            id: existing?.id,
            raceId: race.id,
            name: payload.name,
            distanceMiles: payload.distanceMiles,
            isPrimary: payload.isPrimary,
          );
      ref.invalidate(raceDistanceConfigsProvider(race.id));
      ref.invalidate(raceResultsProvider(race.id));
      ref.invalidate(resultsProvider);

      if (!context.mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: existing == null ? 'Distance saved' : 'Distance updated',
        message:
            '${payload.name} is now available for ${race.name}. Finish scans will use this distance to calculate pace automatically.',
        tone: UserDialogTone.success,
      );
    } on FormatException catch (error) {
      if (!context.mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Distance needs attention',
        message: error.message,
        tone: UserDialogTone.warning,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Could not save distance',
        message: userFacingErrorMessage(
          error,
          fallback:
              'The race distance configuration could not be saved right now.',
        ),
        tone: UserDialogTone.error,
      );
    }
  }

  Future<void> _deleteDistanceConfig(
    BuildContext context,
    WidgetRef ref,
    Race race,
    RaceDistanceConfig config,
  ) async {
    final confirmed = await showUserConfirmDialog(
      context,
      title: 'Delete distance?',
      message:
          'This will remove ${config.sectionLabel} from ${race.name}. Any assigned runners will keep their finish data, but the distance assignment will be cleared.',
      confirmText: 'Delete Distance',
      tone: UserDialogTone.warning,
    );
    if (!confirmed) {
      return;
    }

    await ref.read(raceServiceProvider).deleteRaceDistanceConfig(config.id);
    ref.invalidate(raceDistanceConfigsProvider(race.id));
    ref.invalidate(raceResultsProvider(race.id));
    ref.invalidate(resultsProvider);

    if (!context.mounted) {
      return;
    }
    await showUserMessageDialog(
      context,
      title: 'Distance deleted',
      message: '${config.sectionLabel} was removed from ${race.name}.',
      tone: UserDialogTone.success,
    );
  }
}

class _DashboardOverflowMenu extends StatelessWidget {
  const _DashboardOverflowMenu({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      tooltip: 'More options',
      icon: const Icon(Icons.more_vert),
      iconColor: colorScheme.onSurface,
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: AppRoutes.adminHome,
          child: Text('Choose Race'),
        ),
        const PopupMenuItem(
          value: AppRoutes.rosterTools,
          child: Text('Roster Tools'),
        ),
        const PopupMenuItem(
          value: AppRoutes.setup,
          child: Text('Organizer Tools'),
        ),
        const PopupMenuItem(
          value: AppRoutes.results,
          child: Text('Live Results'),
        ),
        const PopupMenuItem(
          value: AppRoutes.export,
          child: Text('Export Results'),
        ),
      ],
    );
  }
}

class RosterToolsScreen extends RaceDashboardScreen {
  const RosterToolsScreen({super.key});

  void _returnToDashboard(BuildContext context) {
    goToAppRoute(context, AppRoutes.raceDashboard);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRace = ref.watch(currentRaceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const BrandAppBarTitle(pageTitle: 'Roster Tools'),
        actions: [
          IconButton(
            tooltip: 'Back to Race Dashboard',
            onPressed: () => _returnToDashboard(context),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: colorScheme.surfaceContainerLowest,
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: currentRace.when(
                  data: (race) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Roster Tools',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        race == null
                            ? 'Choose a race before editing roster details.'
                            : 'Active race: ${race.name} • ${race.statusLabel}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      StatusBanner(
                        title: race == null
                            ? 'No active race'
                            : 'Roster tools for ${race.name}',
                        message: race == null
                            ? 'Return to Choose Race, select a race, then open Roster Tools again.'
                            : 'Edit saved racer data, configure alternate distances, and assign racer points from this page.',
                        tone: race == null
                            ? StatusBannerTone.warning
                            : StatusBannerTone.info,
                      ),
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => StatusBanner(
                    title: 'Unable to load race',
                    message: userFacingErrorMessage(
                      error,
                      fallback:
                          'The selected race could not be opened. Please go back and choose the race again.',
                    ),
                    tone: StatusBannerTone.error,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              currentRace.when(
                data: (race) => _RaceDatabaseCard(
                  race: race,
                  onDownloadResultsPdf: race == null
                      ? null
                      : () => _downloadResultsPdf(context, ref, race),
                  onEditRow: race == null
                      ? null
                      : (row) => _editRosterEntry(context, ref, race, row),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => StatusBanner(
                  title: 'Database editor unavailable',
                  message: userFacingErrorMessage(
                    error,
                    fallback:
                        'The editable race database view could not load right now.',
                  ),
                  tone: StatusBannerTone.error,
                ),
              ),
              const SizedBox(height: 24),
              currentRace.when(
                data: (race) => _RaceDistanceConfigsCard(
                  race: race,
                  onAddDistance: race == null
                      ? null
                      : () => _saveDistanceConfig(context, ref, race),
                  onEditDistance: race == null
                      ? null
                      : (config) => _saveDistanceConfig(
                          context,
                          ref,
                          race,
                          existing: config,
                        ),
                  onDeleteDistance: race == null
                      ? null
                      : (config) =>
                            _deleteDistanceConfig(context, ref, race, config),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => StatusBanner(
                  title: 'Distance setup unavailable',
                  message: userFacingErrorMessage(
                    error,
                    fallback:
                        'The alternate distance setup card could not load right now.',
                  ),
                  tone: StatusBannerTone.error,
                ),
              ),
              const SizedBox(height: 24),
              currentRace.when(
                data: (race) => _RacePointsCard(
                  race: race,
                  onAwardPoints: race == null
                      ? null
                      : () => _awardPoints(context, ref, race),
                  onDownloadPoints: race == null
                      ? null
                      : () => _downloadPoints(context, ref, race),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => StatusBanner(
                  title: 'Points tools unavailable',
                  message: userFacingErrorMessage(
                    error,
                    fallback:
                        'The racer points tools could not load right now.',
                  ),
                  tone: StatusBannerTone.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaceRosterToolsCard extends StatelessWidget {
  const _RaceRosterToolsCard({
    required this.race,
    required this.onImportRunners,
    required this.onAddRunner,
    required this.onDownloadQrPacketPdf,
  });

  final Race? race;
  final VoidCallback? onImportRunners;
  final VoidCallback? onAddRunner;
  final VoidCallback? onDownloadQrPacketPdf;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Race Roster Tools',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                race == null
                    ? 'Choose a race first. Runner import and manual add only appear inside an open race dashboard.'
                    : 'Import the runner spreadsheet for ${race!.name}, or add a new runner outside the Excel list right here.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  FilledButton.icon(
                    onPressed: onImportRunners,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(240, 64),
                      textStyle: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import Runners'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onAddRunner,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(240, 64),
                      textStyle: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add New Runner'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDownloadQrPacketPdf,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(240, 64),
                      textStyle: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Download Barcode Packet'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Use the import for the Excel or CSV roster. The optional Distance column can auto-assign full or alternate distances. Use Add New Runner for walk-ups or anyone missing from the spreadsheet. Download Barcode Packet creates a printable PDF with the START RACE barcode and one barcode row for every runner in this race.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RacePointsCard extends ConsumerWidget {
  const _RacePointsCard({
    required this.race,
    required this.onAwardPoints,
    required this.onDownloadPoints,
  });

  final Race? race;
  final VoidCallback? onAwardPoints;
  final VoidCallback? onDownloadPoints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = race == null
        ? const AsyncValue<List<RunnerPointsSummary>>.data(
            <RunnerPointsSummary>[],
          )
        : ref.watch(racePointsProvider(race!.id));

    return Card(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Racer Points',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                race == null
                    ? 'Choose a race first. Points are assigned to racers from the open race roster and saved locally on this device.'
                    : 'Add points to a racer in ${race!.name}. Saved totals always add on top of any previous points already stored in SQLite.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              pointsAsync.when(
                data: (summaries) {
                  final racersWithPoints = summaries
                      .where((summary) => summary.totalPoints > 0)
                      .toList(growable: false);
                  final preview = racersWithPoints
                      .take(5)
                      .toList(growable: false);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBanner(
                        title: race == null
                            ? 'No race selected'
                            : '${summaries.length} racers available',
                        message: race == null
                            ? 'Open a race to assign or download racer points.'
                            : racersWithPoints.isEmpty
                            ? 'No points have been assigned yet. Add points to start building the totals.'
                            : '${racersWithPoints.length} racers already have saved points. Download exports the full roster with current totals.',
                        tone: race == null
                            ? StatusBannerTone.warning
                            : racersWithPoints.isEmpty
                            ? StatusBannerTone.info
                            : StatusBannerTone.success,
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        ...preview.map(
                          (summary) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(summary.runnerName),
                            subtitle: Text(summary.barcodeValue),
                            trailing: Text(
                              '${summary.totalPoints} pts',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => StatusBanner(
                  title: 'Could not load points',
                  message: userFacingErrorMessage(
                    error,
                    fallback:
                        'The saved racer points could not be loaded right now.',
                  ),
                  tone: StatusBannerTone.error,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  FilledButton.icon(
                    onPressed: onAwardPoints,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(240, 64),
                      textStyle: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.workspace_premium_outlined),
                    label: const Text('Add Points'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDownloadPoints,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(240, 64),
                      textStyle: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download Points CSV'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaceDatabaseCard extends ConsumerStatefulWidget {
  const _RaceDatabaseCard({
    required this.race,
    required this.onDownloadResultsPdf,
    required this.onEditRow,
  });

  final Race? race;
  final VoidCallback? onDownloadResultsPdf;
  final Future<void> Function(RaceResultRow row)? onEditRow;

  @override
  ConsumerState<_RaceDatabaseCard> createState() => _RaceDatabaseCardState();
}

class _RaceDatabaseCardState extends ConsumerState<_RaceDatabaseCard> {
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = widget.race == null
        ? const AsyncValue<List<RaceResultRow>>.data(<RaceResultRow>[])
        : ref.watch(raceResultsProvider(widget.race!.id));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editable Race Database',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.race == null
                    ? 'Choose a race first. This section lets organizers edit the runner data that was imported or added on the spot.'
                    : 'Review and edit the saved roster for ${widget.race!.name}. Started runners show their start scan, ended runners show their finish or global-stop time, and every row can be edited directly from this spreadsheet view.',
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onDownloadResultsPdf,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(240, 64),
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Download Results PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(
                  'Spreadsheet view: scroll sideways for all columns, then tap Edit on any row to update the saved database entry.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              rowsAsync.when(
                data: (rows) {
                  final sortedRows = rows.toList(growable: false)
                    ..sort(
                      (left, right) => left.runnerName.toLowerCase().compareTo(
                        right.runnerName.toLowerCase(),
                      ),
                    );
                  if (sortedRows.isEmpty) {
                    return const StatusBanner(
                      title: 'No racer data yet',
                      message:
                          'Import runners or add a walk-up racer first, then the editable database list will appear here.',
                      tone: StatusBannerTone.info,
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 1700),
                          child: DataTable(
                            headingRowHeight: 64,
                            dataRowMinHeight: 76,
                            dataRowMaxHeight: 92,
                            horizontalMargin: 14,
                            columnSpacing: 20,
                            dividerThickness: 1,
                            headingTextStyle: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                            dataTextStyle: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            columns: const [
                              DataColumn(label: Text('Runner')),
                              DataColumn(label: Text('Barcode')),
                              DataColumn(label: Text('Bib No.')),
                              DataColumn(label: Text('City')),
                              DataColumn(label: Text('Age')),
                              DataColumn(label: Text('Gender')),
                              DataColumn(label: Text('Distance')),
                              DataColumn(label: Text('Started')),
                              DataColumn(label: Text('Ended')),
                              DataColumn(label: Text('Time')),
                              DataColumn(label: Text('Pace')),
                              DataColumn(label: Text('Payment')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Action')),
                            ],
                            rows: List<DataRow>.generate(sortedRows.length, (
                              index,
                            ) {
                              final row = sortedRows[index];
                              final stripeColor = index.isEven
                                  ? colorScheme.surface
                                  : colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.28);

                              return DataRow(
                                color: WidgetStatePropertyAll<Color?>(
                                  stripeColor,
                                ),
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 220,
                                      child: Text(
                                        row.runnerName,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 118,
                                      child: Text(row.barcodeValue),
                                    ),
                                  ),
                                  DataCell(Text(_displayValue(row.bibNumber))),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: Text(_displayValue(row.city)),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      row.age == null
                                          ? '--'
                                          : row.age.toString(),
                                    ),
                                  ),
                                  DataCell(Text(_displayValue(row.gender))),
                                  DataCell(
                                    SizedBox(
                                      width: 170,
                                      child: Text(
                                        RaceService.buildDistanceLabel(
                                          row.distanceName,
                                          row.distanceMiles,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(_formatStartValue(row))),
                                  DataCell(Text(_formatEndValue(row))),
                                  DataCell(Text(_formatElapsedValue(row))),
                                  DataCell(
                                    SizedBox(
                                      width: 88,
                                      child: Text(_formatPaceValue(row)),
                                    ),
                                  ),
                                  DataCell(Text(row.paymentStatus.label)),
                                  DataCell(
                                    _DatabaseStatusPill(
                                      label: row.editableStatusLabel,
                                    ),
                                  ),
                                  DataCell(
                                    FilledButton.tonalIcon(
                                      onPressed: widget.onEditRow == null
                                          ? null
                                          : () => widget.onEditRow!(row),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Edit'),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => StatusBanner(
                  title: 'Could not load racer data',
                  message: userFacingErrorMessage(
                    error,
                    fallback:
                        'The editable racer database could not be loaded right now.',
                  ),
                  tone: StatusBannerTone.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '--';
    }
    return trimmed;
  }

  String _formatStartValue(RaceResultRow row) {
    return row.startTime == null
        ? '--'
        : RaceService.formatFinishTime(row.startTime);
  }

  String _formatEndValue(RaceResultRow row) {
    return row.finishTime == null
        ? '--'
        : RaceService.formatFinishTime(row.finishTime);
  }

  String _formatElapsedValue(RaceResultRow row) {
    return row.elapsedTimeMs == null
        ? '--'
        : RaceService.formatElapsed(row.elapsedTimeMs);
  }

  String _formatPaceValue(RaceResultRow row) {
    final pace = RaceService.formatPace(
      elapsedTimeMs: row.elapsedTimeMs,
      distanceMiles: row.distanceMiles,
      paceOverride: row.paceOverride,
    ).trim();
    return pace.isEmpty ? '--' : pace;
  }
}

class _DatabaseStatusPill extends StatelessWidget {
  const _DatabaseStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = switch (label) {
      'Ended' => (
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      ),
      'Started' => (
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
      ),
      'In Race' => (
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      ),
      _ => (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurface,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RaceDistanceConfigsCard extends ConsumerWidget {
  const _RaceDistanceConfigsCard({
    required this.race,
    required this.onAddDistance,
    required this.onEditDistance,
    required this.onDeleteDistance,
  });

  final Race? race;
  final VoidCallback? onAddDistance;
  final Future<void> Function(RaceDistanceConfig config)? onEditDistance;
  final Future<void> Function(RaceDistanceConfig config)? onDeleteDistance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final configsAsync = race == null
        ? const AsyncValue<List<RaceDistanceConfig>>.data(
            <RaceDistanceConfig>[],
          )
        : ref.watch(raceDistanceConfigsProvider(race!.id));

    return Card(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alternate Distance Setup',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                race == null
                    ? 'Choose a race first, then configure the main distance and any alternate distances for that event day.'
                    : 'Set up the main race distance and any alternate distances for ${race!.name}. Each runner can be assigned to one distance, and pace is calculated from that distance after the finish scan.',
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  FilledButton.icon(
                    onPressed: onAddDistance,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(240, 64),
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.add_road_outlined),
                    label: const Text('Add Distance'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              configsAsync.when(
                data: (configs) {
                  if (configs.isEmpty) {
                    return const StatusBanner(
                      title: 'No distance setup yet',
                      message:
                          'Add the full distance first. Imported and walk-up runners will then default to the primary distance, and alternate distances can be assigned in the racer editor.',
                      tone: StatusBannerTone.info,
                    );
                  }

                  return Column(
                    children: configs
                        .map(
                          (config) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          config.sectionLabel,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          config.isPrimary
                                              ? 'Primary distance for new imports and walk-up runners.'
                                              : 'Alternate distance available for runner assignment and grouped exports.',
                                          style: theme.textTheme.bodyLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (config.isPrimary) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD7EEE8),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'Primary',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: const Color(0xFF123A35),
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  OutlinedButton.icon(
                                    onPressed: onEditDistance == null
                                        ? null
                                        : () => onEditDistance!(config),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit'),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: onDeleteDistance == null
                                        ? null
                                        : () => onDeleteDistance!(config),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => StatusBanner(
                  title: 'Could not load distance setup',
                  message: userFacingErrorMessage(
                    error,
                    fallback:
                        'The saved distance configuration could not be loaded right now.',
                  ),
                  tone: StatusBannerTone.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddRunnerPayload {
  const _AddRunnerPayload({
    required this.runnerName,
    required this.paymentStatus,
    required this.raceDistanceId,
  });

  final String runnerName;
  final PaymentStatus paymentStatus;
  final int? raceDistanceId;
}

class _EditRosterEntryPayload {
  const _EditRosterEntryPayload({
    required this.name,
    required this.city,
    required this.bibNumber,
    required this.age,
    required this.gender,
    required this.barcodeValue,
    required this.paymentStatus,
    required this.membershipStatus,
    required this.raceDistanceId,
    required this.elapsedTimeMs,
    required this.paceOverride,
  });

  final String name;
  final String? city;
  final String? bibNumber;
  final int? age;
  final String? gender;
  final String barcodeValue;
  final PaymentStatus paymentStatus;
  final MembershipStatus membershipStatus;
  final int? raceDistanceId;
  final int? elapsedTimeMs;
  final String? paceOverride;
}

class _RaceDistancePayload {
  const _RaceDistancePayload({
    required this.name,
    required this.distanceMiles,
    required this.isPrimary,
  });

  final String name;
  final double distanceMiles;
  final bool isPrimary;
}

class _AwardPointsPayload {
  const _AwardPointsPayload({required this.runnerId, required this.points});

  final int runnerId;
  final int points;
}

class _AwardPointsDialog extends StatefulWidget {
  const _AwardPointsDialog({
    required this.race,
    required this.summaries,
    required this.results,
  });

  final Race race;
  final List<RunnerPointsSummary> summaries;
  final List<RaceResultRow> results;

  @override
  State<_AwardPointsDialog> createState() => _AwardPointsDialogState();
}

class _AwardPointsDialogState extends State<_AwardPointsDialog> {
  final TextEditingController _pointsController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  late final List<_AwardPointsRow> _rows;
  int? _selectedRunnerId;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _rows = _buildAwardPointsRows(widget.summaries, widget.results);
    if (_rows.isNotEmpty) {
      _selectedRunnerId = _rows.first.summary.runnerId;
    }
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  _AwardPointsRow? get _selectedRow {
    final runnerId = _selectedRunnerId;
    if (runnerId == null) {
      return null;
    }
    for (final row in _rows) {
      if (row.summary.runnerId == runnerId) {
        return row;
      }
    }
    return null;
  }

  void _submit() {
    final runnerId = _selectedRunnerId;
    final points = int.tryParse(_pointsController.text.trim());
    if (runnerId == null) {
      setState(() {
        _validationMessage = 'Choose a racer before saving points.';
      });
      return;
    }
    if (points == null || points <= 0) {
      setState(() {
        _validationMessage = 'Enter a whole number greater than zero.';
      });
      return;
    }

    Navigator.of(
      context,
    ).pop(_AwardPointsPayload(runnerId: runnerId, points: points));
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final selectedRow = _selectedRow;
    final selectedSummary = selectedRow?.summary;

    return AlertDialog(
      title: const Text('Add Racer Points'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mediaSize.width < 760 ? mediaSize.width - 56 : 940,
          maxHeight: mediaSize.height * 0.76,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick a racer from ${widget.race.name}, check their race position, then add the new points.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            Flexible(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Scrollbar(
                  controller: _verticalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalScrollController,
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      notificationPredicate: (notification) =>
                          notification.metrics.axis == Axis.horizontal,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          showCheckboxColumn: false,
                          headingTextStyle: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                          columns: const [
                            DataColumn(label: Text('Position')),
                            DataColumn(label: Text('Racer')),
                            DataColumn(label: Text('Status')),
                            DataColumn(
                              label: Text('Race Points'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text('Total Points'),
                              numeric: true,
                            ),
                            DataColumn(label: Text('Barcode')),
                          ],
                          rows: _rows
                              .map((row) {
                                final summary = row.summary;
                                return DataRow(
                                  selected:
                                      summary.runnerId == _selectedRunnerId,
                                  onSelectChanged: (_) {
                                    setState(() {
                                      _selectedRunnerId = summary.runnerId;
                                      _validationMessage = null;
                                    });
                                  },
                                  cells: [
                                    DataCell(
                                      Text(
                                        row.positionLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 220,
                                        child: Text(
                                          summary.runnerName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(row.statusLabel)),
                                    DataCell(Text('${summary.pointsInRace}')),
                                    DataCell(Text('${summary.totalPoints}')),
                                    DataCell(Text(summary.barcodeValue)),
                                  ],
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (selectedRow != null && selectedSummary != null)
              StatusBanner(
                title:
                    '${selectedSummary.runnerName} • ${selectedRow.positionLabel}',
                message:
                    '${selectedRow.statusLabel}. ${selectedSummary.pointsInRace} points already assigned in this race, ${selectedSummary.totalPoints} total points saved.',
                tone: selectedSummary.totalPoints > 0
                    ? StatusBannerTone.success
                    : StatusBannerTone.info,
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Points to add',
                hintText: 'Example: 10',
                errorText: _validationMessage,
              ),
              onChanged: (_) {
                if (_validationMessage == null) {
                  return;
                }
                setState(() {
                  _validationMessage = null;
                });
              },
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save Points')),
      ],
    );
  }
}

class _AwardPointsRow {
  const _AwardPointsRow({
    required this.summary,
    required this.positionLabel,
    required this.statusLabel,
    required this.sortGroup,
    required this.sortValue,
  });

  final RunnerPointsSummary summary;
  final String positionLabel;
  final String statusLabel;
  final int sortGroup;
  final int sortValue;
}

class _RacePositionInfo {
  const _RacePositionInfo({
    required this.positionLabel,
    required this.statusLabel,
    required this.sortGroup,
    required this.sortValue,
  });

  final String positionLabel;
  final String statusLabel;
  final int sortGroup;
  final int sortValue;
}

List<_AwardPointsRow> _buildAwardPointsRows(
  List<RunnerPointsSummary> summaries,
  List<RaceResultRow> results,
) {
  final positions = _buildRacePositionLookup(results);
  final rows = summaries
      .map((summary) {
        final position = positions[summary.runnerId];
        return _AwardPointsRow(
          summary: summary,
          positionLabel: position?.positionLabel ?? '--',
          statusLabel: position?.statusLabel ?? 'Registered',
          sortGroup: position?.sortGroup ?? 4,
          sortValue: position?.sortValue ?? summary.runnerId,
        );
      })
      .toList(growable: false);

  rows.sort((left, right) {
    final groupComparison = left.sortGroup.compareTo(right.sortGroup);
    if (groupComparison != 0) {
      return groupComparison;
    }
    final valueComparison = left.sortValue.compareTo(right.sortValue);
    if (valueComparison != 0) {
      return valueComparison;
    }
    return left.summary.runnerName.compareTo(right.summary.runnerName);
  });

  return rows;
}

Map<int, _RacePositionInfo> _buildRacePositionLookup(
  List<RaceResultRow> results,
) {
  final sortedRows = results.toList(growable: false)
    ..sort(_compareRowsForRacePosition);
  final positions = <int, _RacePositionInfo>{};
  var finishPlace = 0;

  for (final row in sortedRows) {
    final finishTime = row.finishTime;
    final startTime = row.startTime;
    final checkedInAt = row.checkedInAt;

    if (finishTime != null) {
      finishPlace += 1;
      positions.putIfAbsent(
        row.runnerId,
        () => _RacePositionInfo(
          positionLabel: '#$finishPlace',
          statusLabel: 'Finished',
          sortGroup: 0,
          sortValue: finishTime.millisecondsSinceEpoch,
        ),
      );
      continue;
    }

    if (startTime != null) {
      positions.putIfAbsent(
        row.runnerId,
        () => _RacePositionInfo(
          positionLabel: '--',
          statusLabel: 'Started',
          sortGroup: 1,
          sortValue: startTime.millisecondsSinceEpoch,
        ),
      );
      continue;
    }

    if (checkedInAt != null) {
      positions.putIfAbsent(
        row.runnerId,
        () => _RacePositionInfo(
          positionLabel: '--',
          statusLabel: 'Checked in',
          sortGroup: 2,
          sortValue: checkedInAt.millisecondsSinceEpoch,
        ),
      );
      continue;
    }

    positions.putIfAbsent(
      row.runnerId,
      () => _RacePositionInfo(
        positionLabel: '--',
        statusLabel: 'Registered',
        sortGroup: 3,
        sortValue: row.entryId,
      ),
    );
  }

  return positions;
}

int _compareRowsForRacePosition(RaceResultRow left, RaceResultRow right) {
  final leftFinish = left.finishTime;
  final rightFinish = right.finishTime;
  if (leftFinish != null && rightFinish != null) {
    final comparison = leftFinish.compareTo(rightFinish);
    return comparison == 0 ? left.entryId.compareTo(right.entryId) : comparison;
  }
  if (leftFinish != null) {
    return -1;
  }
  if (rightFinish != null) {
    return 1;
  }

  final leftStart = left.startTime;
  final rightStart = right.startTime;
  if (leftStart != null && rightStart != null) {
    final comparison = leftStart.compareTo(rightStart);
    return comparison == 0 ? left.entryId.compareTo(right.entryId) : comparison;
  }
  if (leftStart != null) {
    return -1;
  }
  if (rightStart != null) {
    return 1;
  }

  return left.entryId.compareTo(right.entryId);
}

class _AddRunnerDialog extends StatefulWidget {
  const _AddRunnerDialog({required this.race, required this.distanceConfigs});

  final Race race;
  final List<RaceDistanceConfig> distanceConfigs;

  @override
  State<_AddRunnerDialog> createState() => _AddRunnerDialogState();
}

class _EditRosterEntryDialog extends StatefulWidget {
  const _EditRosterEntryDialog({
    required this.row,
    required this.distanceConfigs,
  });

  final RaceResultRow row;
  final List<RaceDistanceConfig> distanceConfigs;

  @override
  State<_EditRosterEntryDialog> createState() => _EditRosterEntryDialogState();
}

class _EditRosterEntryDialogState extends State<_EditRosterEntryDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _bibNumberController;
  late final TextEditingController _ageController;
  late final TextEditingController _genderController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _elapsedTimeController;
  late final TextEditingController _paceController;
  late PaymentStatus _paymentStatus;
  late MembershipStatus _membershipStatus;
  int? _raceDistanceId;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.row.runnerName);
    _cityController = TextEditingController(text: widget.row.city ?? '');
    _bibNumberController = TextEditingController(
      text: widget.row.bibNumber ?? '',
    );
    _ageController = TextEditingController(
      text: widget.row.age?.toString() ?? '',
    );
    _genderController = TextEditingController(text: widget.row.gender ?? '');
    _barcodeController = TextEditingController(text: widget.row.barcodeValue);
    _elapsedTimeController = TextEditingController(
      text: RaceService.formatElapsedInput(widget.row.elapsedTimeMs),
    );
    _paceController = TextEditingController(
      text: widget.row.paceOverride ?? '',
    );
    _paymentStatus = widget.row.paymentStatus;
    _membershipStatus = widget.row.membershipStatus;
    _raceDistanceId = widget.row.raceDistanceId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _bibNumberController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _barcodeController.dispose();
    _elapsedTimeController.dispose();
    _paceController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim();
    final ageText = _ageController.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);
    final elapsedTimeText = _elapsedTimeController.text.trim();
    int? elapsedTimeMs;

    if (name.isEmpty) {
      setState(() {
        _validationMessage = 'Runner name is required.';
      });
      return;
    }
    if (barcode.isEmpty) {
      setState(() {
        _validationMessage = 'Barcode is required.';
      });
      return;
    }
    if (ageText.isNotEmpty && age == null) {
      setState(() {
        _validationMessage = 'Age must be a whole number.';
      });
      return;
    }
    try {
      elapsedTimeMs = RaceService.parseElapsed(elapsedTimeText);
    } on FormatException catch (error) {
      setState(() {
        _validationMessage = error.message;
      });
      return;
    }
    if (widget.row.finishTime != null &&
        widget.row.elapsedTimeMs != null &&
        elapsedTimeMs == null) {
      setState(() {
        _validationMessage =
            'Elapsed time cannot be blank after a finisher is recorded.';
      });
      return;
    }

    Navigator.of(context).pop(
      _EditRosterEntryPayload(
        name: name,
        city: _normalizeOptional(_cityController.text),
        bibNumber: _normalizeOptional(_bibNumberController.text),
        age: age,
        gender: _normalizeOptional(_genderController.text),
        barcodeValue: barcode,
        paymentStatus: _paymentStatus,
        membershipStatus: _membershipStatus,
        raceDistanceId: _raceDistanceId,
        elapsedTimeMs: elapsedTimeMs,
        paceOverride: _normalizeOptional(_paceController.text),
      ),
    );
  }

  String? _normalizeOptional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaSize = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: const Text('Edit Racer Data'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mediaSize.width < 820 ? mediaSize.width - 56 : 560,
          maxHeight: mediaSize.height * 0.76,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update any imported or walk-up racer details here. Distance controls pace calculation, finish scans set the time taken automatically, and both time and pace can still be corrected manually.',
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                style: theme.textTheme.titleLarge,
                decoration: InputDecoration(
                  labelText: 'Runner name',
                  errorText: _validationMessage,
                ),
                onChanged: (_) {
                  if (_validationMessage == null) {
                    return;
                  }
                  setState(() {
                    _validationMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cityController,
                style: theme.textTheme.titleMedium,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bibNumberController,
                style: theme.textTheme.titleMedium,
                decoration: const InputDecoration(labelText: 'Bib No.'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                style: theme.textTheme.titleMedium,
                decoration: const InputDecoration(labelText: 'Age'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _genderController,
                style: theme.textTheme.titleMedium,
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _barcodeController,
                style: theme.textTheme.titleMedium,
                decoration: const InputDecoration(labelText: 'Barcode'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: _raceDistanceId,
                decoration: const InputDecoration(
                  labelText: 'Distance',
                  helperText:
                      'Pace is calculated from this distance after the finish scan.',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('No distance selected'),
                  ),
                  ...widget.distanceConfigs.map(
                    (config) => DropdownMenuItem<int?>(
                      value: config.id,
                      child: Text(config.sectionLabel),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _raceDistanceId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _elapsedTimeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: theme.textTheme.titleMedium,
                decoration: const InputDecoration(
                  labelText: 'Time taken',
                  helperText: 'Examples: 33:43.0 or 1:06:08.0',
                ),
                onChanged: (_) {
                  if (_validationMessage == null) {
                    return;
                  }
                  setState(() {
                    _validationMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _paceController,
                style: theme.textTheme.titleMedium,
                decoration: InputDecoration(
                  labelText: 'Pace override',
                  helperText:
                      'Leave blank to use automatic pace${widget.row.distanceMiles == null ? '.' : ' (${RaceService.formatPace(elapsedTimeMs: widget.row.elapsedTimeMs, distanceMiles: widget.row.distanceMiles, paceOverride: widget.row.paceOverride).isEmpty ? 'when finish time exists' : RaceService.formatPace(elapsedTimeMs: widget.row.elapsedTimeMs, distanceMiles: widget.row.distanceMiles, paceOverride: widget.row.paceOverride)})'}',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PaymentStatus>(
                initialValue: _paymentStatus,
                decoration: const InputDecoration(labelText: 'Payment status'),
                items: PaymentStatus.values
                    .map(
                      (status) => DropdownMenuItem<PaymentStatus>(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _paymentStatus = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MembershipStatus>(
                initialValue: _membershipStatus,
                decoration: const InputDecoration(
                  labelText: 'Membership status',
                ),
                items: MembershipStatus.values
                    .map(
                      (status) => DropdownMenuItem<MembershipStatus>(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _membershipStatus = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save Changes')),
      ],
    );
  }
}

class _AddRunnerDialogState extends State<_AddRunnerDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  PaymentStatus _paymentStatus = PaymentStatus.pending;
  int? _raceDistanceId;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    for (final config in widget.distanceConfigs) {
      if (config.isPrimary) {
        _raceDistanceId = config.id;
        break;
      }
    }
    _raceDistanceId ??= widget.distanceConfigs.isEmpty
        ? null
        : widget.distanceConfigs.first.id;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _validationMessage = 'Enter the runner name before saving.';
      });
      return;
    }
    Navigator.of(context).pop(
      _AddRunnerPayload(
        runnerName: trimmed,
        paymentStatus: _paymentStatus,
        raceDistanceId: _raceDistanceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: const Text('Add New Runner'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mediaSize.width < 760 ? mediaSize.width - 56 : 460,
          maxHeight: mediaSize.height * 0.72,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a runner directly to ${widget.race.name} even if they are not in the imported spreadsheet.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Runner name',
                  errorText: _validationMessage,
                ),
                onChanged: (_) {
                  if (_validationMessage == null) {
                    return;
                  }
                  setState(() {
                    _validationMessage = null;
                  });
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 18),
              if (widget.distanceConfigs.isNotEmpty) ...[
                DropdownButtonFormField<int?>(
                  initialValue: _raceDistanceId,
                  decoration: const InputDecoration(
                    labelText: 'Distance',
                    helperText:
                        'New walk-up runners start in the primary distance by default.',
                  ),
                  items: widget.distanceConfigs
                      .map(
                        (config) => DropdownMenuItem<int?>(
                          value: config.id,
                          child: Text(config.sectionLabel),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    setState(() {
                      _raceDistanceId = value;
                    });
                  },
                ),
                const SizedBox(height: 18),
              ],
              DropdownButtonFormField<PaymentStatus>(
                initialValue: _paymentStatus,
                decoration: const InputDecoration(labelText: 'Payment status'),
                items: PaymentStatus.values
                    .map(
                      (status) => DropdownMenuItem<PaymentStatus>(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _paymentStatus = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add Runner')),
      ],
    );
  }
}

class _RaceDistanceDialog extends StatefulWidget {
  const _RaceDistanceDialog({this.existing});

  final RaceDistanceConfig? existing;

  @override
  State<_RaceDistanceDialog> createState() => _RaceDistanceDialogState();
}

class _RaceDistanceDialogState extends State<_RaceDistanceDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _distanceController;
  late bool _isPrimary;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _distanceController = TextEditingController(
      text: widget.existing?.distanceMiles.toString() ?? '',
    );
    _isPrimary = widget.existing?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final distanceMiles = double.tryParse(_distanceController.text.trim());
    if (name.isEmpty) {
      setState(() {
        _validationMessage = 'Distance name is required.';
      });
      return;
    }
    if (distanceMiles == null || distanceMiles <= 0) {
      setState(() {
        _validationMessage = 'Distance must be a number greater than zero.';
      });
      return;
    }

    Navigator.of(context).pop(
      _RaceDistancePayload(
        name: name,
        distanceMiles: distanceMiles,
        isPrimary: _isPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Distance' : 'Edit Distance'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mediaSize.width < 760 ? mediaSize.width - 56 : 480,
          maxHeight: mediaSize.height * 0.72,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create one main distance and any alternate distances for the same event day. Pace is calculated per runner from the assigned distance.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Distance name',
                  hintText: 'Example: Full Distance or Alternate Distance',
                  errorText: _validationMessage,
                ),
                onChanged: (_) {
                  if (_validationMessage == null) {
                    return;
                  }
                  setState(() {
                    _validationMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _distanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Distance in miles',
                  hintText: 'Example: 5 or 4.4',
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _isPrimary,
                onChanged: (value) {
                  setState(() {
                    _isPrimary = value;
                  });
                },
                title: const Text('Primary distance'),
                subtitle: const Text(
                  'Imported and walk-up runners default to this distance.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.existing == null ? 'Add Distance' : 'Save Distance',
          ),
        ),
      ],
    );
  }
}
