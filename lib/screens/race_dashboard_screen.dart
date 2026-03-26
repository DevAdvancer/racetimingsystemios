import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/check_in_result.dart';
import 'package:race_timer/models/import_result.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/runner.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/check_in_provider.dart';
import 'package:race_timer/providers/import_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/results_provider.dart';
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
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Return to start screen',
            onPressed: () {
              ref.read(adminAccessProvider.notifier).lock();
              context.go(AppRoutes.home);
            },
            icon: const Icon(Icons.lock_outline),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => context.push(value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: AppRoutes.adminHome,
                child: Text('Choose Race'),
              ),
              PopupMenuItem(
                value: AppRoutes.setup,
                child: Text('Organizer Tools'),
              ),
              PopupMenuItem(
                value: AppRoutes.results,
                child: Text('Live Results'),
              ),
              PopupMenuItem(value: AppRoutes.export, child: Text('Export CSV')),
              PopupMenuItem(
                value: AppRoutes.diagnostics,
                child: Text('Diagnostics'),
              ),
            ],
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
                  final wide = constraints.maxWidth >= 900;
                  final tiles = [
                    PrimaryActionTile(
                      title: 'Runner Kiosk',
                      subtitle:
                          'Return to the large runner-facing check-in screen.',
                      icon: Icons.badge_outlined,
                      onTap: () => context.go(AppRoutes.registration),
                    ),
                    PrimaryActionTile(
                      title: 'Start Race',
                      subtitle: 'Manage gun time and race status.',
                      icon: Icons.flag_circle,
                      onTap: () => context.push(AppRoutes.raceControl),
                    ),
                    PrimaryActionTile(
                      title: 'Scan Runners',
                      subtitle:
                          'Capture barcode scans for early starts and finishes.',
                      icon: Icons.qr_code_scanner,
                      onTap: () => context.push(AppRoutes.scanner),
                    ),
                  ];

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: wide ? 3 : 1,
                    childAspectRatio: wide ? 1.0 : 2.4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
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
    final payload = await showDialog<_AddRunnerPayload>(
      context: context,
      builder: (context) => _AddRunnerDialog(race: race),
    );
    if (payload == null || payload.runnerName.trim().isEmpty) {
      return;
    }

    final result = await ref
        .read(raceServiceProvider)
        .createAdHocRunnerAndPrint(
          payload.runnerName,
          paymentStatus: payload.paymentStatus,
        );
    ref.invalidate(resultsProvider);
    ref.invalidate(checkInProvider);

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
}

class _RaceRosterToolsCard extends StatelessWidget {
  const _RaceRosterToolsCard({
    required this.race,
    required this.onImportRunners,
    required this.onAddRunner,
  });

  final Race? race;
  final VoidCallback? onImportRunners;
  final VoidCallback? onAddRunner;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Use the import for the Excel or CSV roster. Use Add New Runner for walk-ups or anyone missing from the spreadsheet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddRunnerPayload {
  const _AddRunnerPayload({
    required this.runnerName,
    required this.paymentStatus,
  });

  final String runnerName;
  final PaymentStatus paymentStatus;
}

class _AddRunnerDialog extends StatefulWidget {
  const _AddRunnerDialog({required this.race});

  final Race race;

  @override
  State<_AddRunnerDialog> createState() => _AddRunnerDialogState();
}

class _AddRunnerDialogState extends State<_AddRunnerDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  PaymentStatus _paymentStatus = PaymentStatus.pending;
  String? _validationMessage;

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
      _AddRunnerPayload(runnerName: trimmed, paymentStatus: _paymentStatus),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Runner'),
      content: SizedBox(
        width: 460,
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
