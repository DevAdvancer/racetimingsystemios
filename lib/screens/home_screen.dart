import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/overall_runner_points_summary.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/runner_points_summary.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/points_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/results_provider.dart';
import 'package:race_timer/widgets/branding.dart';
import 'package:race_timer/widgets/status_banner.dart';
import 'package:race_timer/widgets/user_dialogs.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final racesAsync = ref.watch(raceListProvider);
    final currentRaceAsync = ref.watch(currentRaceProvider);
    final selectedRaceId = currentRaceAsync.asData?.value?.id;

    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(pageTitle: 'Admin Dashboard'),
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
                value: AppRoutes.setup,
                child: Text('Organizer Tools'),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackedLayout =
                  constraints.maxHeight < 900 || constraints.maxWidth < 1400;

              final heroPanel = _HeroPanel(
                selectedRaceId: selectedRaceId,
                onCreateRace: () => _showCreateRaceDialog(context, ref),
                onBulkRaceTools: () => _showBulkRaceToolsDialog(context, ref),
                onOpenSelectedRace: selectedRaceId == null
                    ? null
                    : () => context.go(AppRoutes.raceDashboard),
              );

              final overallSection = racesAsync.when(
                data: (races) => stackedLayout
                    ? _OverallPointsSection(
                        races: races,
                        onAdjustPoints: () =>
                            _showOverallPointsDialog(context, ref, races),
                        onExportPoints: () =>
                            _exportOverallPoints(context, ref, races),
                      )
                    : SizedBox(
                        height: 360,
                        child: _OverallPointsSection(
                          races: races,
                          fillHeight: true,
                          onAdjustPoints: () =>
                              _showOverallPointsDialog(context, ref, races),
                          onExportPoints: () =>
                              _exportOverallPoints(context, ref, races),
                        ),
                      ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => StatusBanner(
                  title: 'Overall points unavailable',
                  message: userFacingErrorMessage(
                    error,
                    fallback:
                        'The overall points section could not load right now.',
                  ),
                  tone: StatusBannerTone.error,
                ),
              );

              final raceList = racesAsync.when(
                data: (races) => _RaceListSection(
                  races: races,
                  selectedRaceId: selectedRaceId,
                  expandToFill: !stackedLayout,
                  onCreateRace: () => _showCreateRaceDialog(context, ref),
                  onBulkRaceTools: () => _showBulkRaceToolsDialog(context, ref),
                  onOpenRace: (race) async {
                    await ref
                        .read(currentRaceProvider.notifier)
                        .selectRace(race.id);
                    if (context.mounted) {
                      context.go(AppRoutes.raceDashboard);
                    }
                  },
                ),
                loading: () => stackedLayout
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: StatusBanner(
                      title: 'Could not load races',
                      message: userFacingErrorMessage(
                        error,
                        fallback:
                            'The saved race list could not be loaded. Please reopen the app and try again.',
                      ),
                      tone: StatusBannerTone.error,
                    ),
                  ),
                ),
              );

              if (stackedLayout) {
                return ListView(
                  children: [
                    heroPanel,
                    const SizedBox(height: 24),
                    raceList,
                    const SizedBox(height: 24),
                    overallSection,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heroPanel,
                  const SizedBox(height: 24),
                  overallSection,
                  const SizedBox(height: 24),
                  Expanded(child: raceList),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateRaceDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final raceName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _CreateRaceDialog(),
    );

    if (raceName == null || raceName.isEmpty) {
      return;
    }

    try {
      await ref.read(currentRaceProvider.notifier).createRace(name: raceName);
      if (context.mounted) {
        context.go(AppRoutes.raceDashboard);
      }
    } catch (_) {
      if (context.mounted) {
        await showUserMessageDialog(
          context,
          title: 'Could not create race',
          message:
              'The app could not save the race. Please try again in a moment.',
          tone: UserDialogTone.error,
        );
      }
    }
  }

  Future<void> _showBulkRaceToolsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => const _BulkRaceToolsDialog(),
    );
  }

  Future<void> _showOverallPointsDialog(
    BuildContext context,
    WidgetRef ref,
    List<Race> races,
  ) async {
    if (races.isEmpty) {
      await showUserMessageDialog(
        context,
        title: 'No races available',
        message: 'Create or import a race before adjusting overall points.',
        tone: UserDialogTone.warning,
      );
      return;
    }

    final result = await showDialog<_PointsAdjustmentResult>(
      context: context,
      builder: (dialogContext) => _AdjustOverallPointsDialog(races: races),
    );
    if (result == null || !context.mounted) {
      return;
    }

    final actionLabel = result.pointsDelta > 0 ? 'added' : 'removed';
    await showUserMessageDialog(
      context,
      title: 'Overall points updated',
      message:
          '${result.pointsDelta.abs()} points $actionLabel for ${result.runnerName}. New total: ${result.updatedTotalPoints} points.',
      tone: UserDialogTone.success,
    );
  }

  Future<void> _exportOverallPoints(
    BuildContext context,
    WidgetRef ref,
    List<Race> races,
  ) async {
    try {
      final rows = await ref.read(overallPointsProvider.future);
      if (!context.mounted) {
        return;
      }
      if (rows.isEmpty) {
        await showUserMessageDialog(
          context,
          title: 'Nothing to export',
          message:
              'Add some racer points before exporting the overall standings.',
          tone: UserDialogTone.warning,
        );
        return;
      }

      final latestRace = _findLatestRace(races);
      final result = await ref
          .read(exportServiceProvider)
          .exportOverallPoints(
            latestRaceName: latestRace?.name,
            totalRaceCount: races.length,
            rows: rows,
          );
      if (!context.mounted) {
        return;
      }

      await showUserMessageDialog(
        context,
        title: result.succeeded
            ? 'Overall points export ready'
            : 'Export failed',
        message: result.message,
        tone: result.succeeded ? UserDialogTone.success : UserDialogTone.error,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Export failed',
        message: userFacingErrorMessage(
          error,
          fallback:
              'The overall points could not be exported right now. Please try again.',
        ),
        tone: UserDialogTone.error,
      );
    }
  }
}

class _CreateRaceDialog extends StatefulWidget {
  const _CreateRaceDialog();

  @override
  State<_CreateRaceDialog> createState() => _CreateRaceDialogState();
}

class _CreateRaceDialogState extends State<_CreateRaceDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _validationMessage;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _close([String? value]) {
    _focusNode.unfocus();
    Navigator.of(context).pop(value);
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _validationMessage = 'Please enter a race name before continuing.';
      });
      return;
    }
    _close(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create a New Race'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type the race name exactly how volunteers should see it on the tablet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Race name',
                hintText: 'Example: Saturday Park Run',
                errorText: _validationMessage,
              ),
              onChanged: (value) {
                if (_validationMessage == null || value.trim().isEmpty) {
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
        TextButton(onPressed: _close, child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create Race')),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.selectedRaceId,
    required this.onCreateRace,
    required this.onBulkRaceTools,
    required this.onOpenSelectedRace,
  });

  final int? selectedRaceId;
  final VoidCallback onCreateRace;
  final VoidCallback onBulkRaceTools;
  final VoidCallback? onOpenSelectedRace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: <Color>[
            colorScheme.primaryContainer,
            colorScheme.tertiaryContainer.withValues(alpha: 0.72),
            Theme.of(context).scaffoldBackgroundColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Race Dashboard', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 10),
          Text(
            'Create a race, choose an existing race, then send volunteers into the simple race-day screen.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          StatusBanner(
            title: selectedRaceId == null
                ? 'Choose a race to begin'
                : 'Race selected',
            message: selectedRaceId == null
                ? 'Once a race is selected, volunteers can check in runners, record the global start, and scan runner barcodes for early starts and finishes.'
                : 'The last selected race is ready to reopen from this dashboard.',
            tone: selectedRaceId == null
                ? StatusBannerTone.info
                : StatusBannerTone.success,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onCreateRace,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create Race'),
              ),
              OutlinedButton.icon(
                onPressed: onBulkRaceTools,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Import Race Schedule'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenSelectedRace,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Open Selected Race'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverallPointsSection extends ConsumerWidget {
  const _OverallPointsSection({
    required this.races,
    required this.onAdjustPoints,
    required this.onExportPoints,
    this.fillHeight = false,
  });

  final List<Race> races;
  final VoidCallback onAdjustPoints;
  final VoidCallback onExportPoints;
  final bool fillHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overallPointsAsync = ref.watch(overallPointsProvider);
    final latestRace = _findLatestRace(races);
    final content = overallPointsAsync.when(
      data: (rows) => _OverallPointsContent(
        rows: rows,
        latestRace: latestRace,
        races: races,
        fillHeight: fillHeight,
        onAdjustPoints: onAdjustPoints,
        onExportPoints: onExportPoints,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => StatusBanner(
        title: 'Could not load overall points',
        message: userFacingErrorMessage(
          error,
          fallback:
              'The saved overall points standings could not be loaded right now.',
        ),
        tone: StatusBannerTone.error,
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Points',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'See the full points table till now, the latest race, total races, and adjust or export standings from here.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            if (fillHeight) Expanded(child: content) else content,
          ],
        ),
      ),
    );
  }
}

class _OverallPointsContent extends StatelessWidget {
  const _OverallPointsContent({
    required this.rows,
    required this.latestRace,
    required this.races,
    required this.fillHeight,
    required this.onAdjustPoints,
    required this.onExportPoints,
  });

  final List<OverallRunnerPointsSummary> rows;
  final Race? latestRace;
  final List<Race> races;
  final bool fillHeight;
  final VoidCallback onAdjustPoints;
  final VoidCallback onExportPoints;

  @override
  Widget build(BuildContext context) {
    final totalPoints = rows.fold<int>(0, (sum, row) => sum + row.totalPoints);
    final metrics = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _OverviewMetricTile(
          label: 'Latest Race',
          value: latestRace?.name ?? 'No races yet',
        ),
        _OverviewMetricTile(label: 'Total Races', value: '${races.length}'),
        _OverviewMetricTile(
          label: 'Racers With Points',
          value: '${rows.length}',
        ),
        _OverviewMetricTile(label: 'Points Awarded', value: '$totalPoints'),
      ],
    );

    final actions = Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.overallPoints),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('View Full Table'),
          ),
          FilledButton.icon(
            onPressed: races.isEmpty ? null : onAdjustPoints,
            icon: const Icon(Icons.tune),
            label: const Text('Adjust Overall Points'),
          ),
          OutlinedButton.icon(
            onPressed: onExportPoints,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export Overall Points'),
          ),
        ],
      ),
    );

    if (fillHeight) {
      if (rows.isEmpty) {
        final hintStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            metrics,
            const SizedBox(height: 16),
            actions,
            const SizedBox(height: 12),
            Text(
              'No overall points yet. Open a race dashboard and award points to populate this section.',
              style: hintStyle,
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          metrics,
          const SizedBox(height: 16),
          actions,
          const SizedBox(height: 16),
          Expanded(child: _buildStandingsPanel(context, detailedRows: true)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        metrics,
        const SizedBox(height: 16),
        actions,
        const SizedBox(height: 16),
        if (rows.isEmpty)
          _buildStandingsPanel(context, detailedRows: false)
        else
          SizedBox(
            height: 240,
            child: _buildStandingsPanel(context, detailedRows: false),
          ),
      ],
    );
  }

  Widget _buildStandingsPanel(
    BuildContext context, {
    required bool detailedRows,
  }) {
    if (rows.isEmpty) {
      return const Align(
        alignment: Alignment.topLeft,
        child: StatusBanner(
          title: 'No overall points yet',
          message:
              'Open a race dashboard to award points, then this full standings section will populate automatically.',
          tone: StatusBannerTone.info,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusBanner(
          title: 'Current standings',
          message: latestRace == null
              ? 'The list below shows all saved points so far.'
              : 'Latest race: ${latestRace!.name}. The list below shows the saved overall totals for every racer with points.',
          tone: StatusBannerTone.success,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) {
              final row = rows[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: detailedRows
                    ? CircleAvatar(radius: 18, child: Text('${index + 1}'))
                    : null,
                title: Text(row.runnerName),
                subtitle: Text(
                  detailedRows
                      ? row.latestRaceName == null
                            ? row.barcodeValue
                            : '${row.barcodeValue} • Last race: ${row.latestRaceName}'
                      : '${row.barcodeValue} • ${row.totalPoints} pts',
                ),
                trailing: detailedRows
                    ? Text(
                        '${row.totalPoints} pts',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OverviewMetricTile extends StatelessWidget {
  const _OverviewMetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RaceListSection extends StatelessWidget {
  const _RaceListSection({
    required this.races,
    required this.selectedRaceId,
    this.expandToFill = true,
    required this.onCreateRace,
    required this.onBulkRaceTools,
    required this.onOpenRace,
  });

  final List<Race> races;
  final int? selectedRaceId;
  final bool expandToFill;
  final VoidCallback onCreateRace;
  final VoidCallback onBulkRaceTools;
  final ValueChanged<Race> onOpenRace;

  @override
  Widget build(BuildContext context) {
    if (races.isEmpty) {
      return _EmptyRaceState(
        onCreateRace: onCreateRace,
        onBulkRaceTools: onBulkRaceTools,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Available Races', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (expandToFill)
          Expanded(child: _buildRaceGrid())
        else
          _buildRaceGrid(),
      ],
    );
  }

  Widget _buildRaceGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: !expandToFill,
          physics: expandToFill ? null : const NeverScrollableScrollPhysics(),
          itemCount: races.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final race = races[index];
            return _RaceCard(
              race: race,
              isSelected: race.id == selectedRaceId,
              onTap: () => onOpenRace(race),
            );
          },
        );
      },
    );
  }
}

class _EmptyRaceState extends StatelessWidget {
  const _EmptyRaceState({
    required this.onCreateRace,
    required this.onBulkRaceTools,
  });

  final VoidCallback onCreateRace;
  final VoidCallback onBulkRaceTools;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flag_outlined, size: 52),
                const SizedBox(height: 16),
                Text(
                  'No races have been created yet.',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap Create Race to add the next event, then open that race dashboard to import runners or add a new runner.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onCreateRace,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Create Race'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onBulkRaceTools,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Import Race Schedule'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RaceCard extends StatelessWidget {
  const _RaceCard({
    required this.race,
    required this.isSelected,
    required this.onTap,
  });

  final Race race;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    final dateLabel = DateFormat(
      'EEE, d MMM • h:mm a',
    ).format(race.createdAt.toLocal());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: isSelected
                  ? <Color>[colorScheme.primaryContainer, colorScheme.surface]
                  : <Color>[colorScheme.surface, scaffoldBackground],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        race.name,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusChip(
                      label: race.statusLabel,
                      isSelected: isSelected,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Created $dateLabel',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(
                  isSelected ? 'Selected now' : 'Tap to open this race',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.isSelected});

  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.18)
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _PointsAdjustmentResult {
  const _PointsAdjustmentResult({
    required this.runnerName,
    required this.updatedTotalPoints,
    required this.pointsDelta,
  });

  final String runnerName;
  final int updatedTotalPoints;
  final int pointsDelta;
}

class _AdjustOverallPointsDialog extends ConsumerStatefulWidget {
  const _AdjustOverallPointsDialog({required this.races});

  final List<Race> races;

  @override
  ConsumerState<_AdjustOverallPointsDialog> createState() =>
      _AdjustOverallPointsDialogState();
}

class _AdjustOverallPointsDialogState
    extends ConsumerState<_AdjustOverallPointsDialog> {
  final TextEditingController _pointsController = TextEditingController();
  int? _selectedRaceId;
  int? _selectedRunnerId;
  String? _validationMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedRaceId =
        _findLatestRace(widget.races)?.id ?? widget.races.first.id;
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRaceId = _selectedRaceId;
    final selectedRace = selectedRaceId == null
        ? null
        : widget.races.firstWhere((race) => race.id == selectedRaceId);
    final racerSummariesAsync = selectedRaceId == null
        ? const AsyncValue<List<RunnerPointsSummary>>.data(
            <RunnerPointsSummary>[],
          )
        : ref.watch(racePointsProvider(selectedRaceId));

    return AlertDialog(
      title: const Text('Adjust Overall Points'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a race and racer, then enter a positive or negative number to manually adjust the overall total.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              initialValue: _selectedRaceId,
              decoration: const InputDecoration(labelText: 'Race'),
              items: widget.races
                  .map(
                    (race) => DropdownMenuItem<int>(
                      value: race.id,
                      child: Text(race.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _selectedRaceId = value;
                        _selectedRunnerId = null;
                        _validationMessage = null;
                      });
                    },
            ),
            const SizedBox(height: 16),
            racerSummariesAsync.when(
              data: (summaries) {
                final availableRunnerId =
                    _selectedRunnerId != null &&
                        summaries.any(
                          (row) => row.runnerId == _selectedRunnerId,
                        )
                    ? _selectedRunnerId
                    : summaries.isEmpty
                    ? null
                    : summaries.first.runnerId;
                RunnerPointsSummary? selectedSummary;
                for (final summary in summaries) {
                  if (summary.runnerId == availableRunnerId) {
                    selectedSummary = summary;
                    break;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      key: ValueKey<int?>(availableRunnerId),
                      initialValue: availableRunnerId,
                      decoration: const InputDecoration(labelText: 'Racer'),
                      items: summaries
                          .map(
                            (summary) => DropdownMenuItem<int>(
                              value: summary.runnerId,
                              child: Text(summary.runnerName),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isSaving || summaries.isEmpty
                          ? null
                          : (value) {
                              setState(() {
                                _selectedRunnerId = value;
                                _validationMessage = null;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    StatusBanner(
                      title: selectedRace?.name ?? 'No race selected',
                      message: summaries.isEmpty
                          ? 'No racers are available in this race yet.'
                          : selectedSummary == null
                          ? 'Choose a racer to see the current total.'
                          : '${selectedSummary.totalPoints} total points so far, with ${selectedSummary.pointsInRace} points already attached to this race.',
                      tone: summaries.isEmpty
                          ? StatusBannerTone.warning
                          : StatusBannerTone.info,
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => StatusBanner(
                title: 'Could not load racers',
                message: userFacingErrorMessage(
                  error,
                  fallback:
                      'The racer list for this race could not be loaded right now.',
                ),
                tone: StatusBannerTone.error,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pointsController,
              enabled: !_isSaving,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'-?[0-9]*')),
              ],
              decoration: InputDecoration(
                labelText: 'Points adjustment',
                hintText: 'Example: 10 or -5',
                helperText:
                    'Positive numbers add points. Negative numbers remove points.',
                errorText: _validationMessage,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving
              ? null
              : () => _saveAdjustment(context, racerSummariesAsync),
          child: const Text('Save Adjustment'),
        ),
      ],
    );
  }

  Future<void> _saveAdjustment(
    BuildContext context,
    AsyncValue<List<RunnerPointsSummary>> racerSummariesAsync,
  ) async {
    final raceId = _selectedRaceId;
    final summaries = racerSummariesAsync.asData?.value ?? const [];
    final runnerId =
        _selectedRunnerId ??
        (summaries.isEmpty ? null : summaries.first.runnerId);
    final pointsDelta = int.tryParse(_pointsController.text.trim());

    if (raceId == null) {
      setState(() {
        _validationMessage = 'Choose a race before saving.';
      });
      return;
    }
    if (runnerId == null) {
      setState(() {
        _validationMessage = 'Choose a racer before saving.';
      });
      return;
    }
    if (pointsDelta == null || pointsDelta == 0) {
      setState(() {
        _validationMessage =
            'Enter a positive or negative number for the adjustment.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updated = await ref
          .read(raceServiceProvider)
          .adjustRunnerPoints(
            raceId: raceId,
            runnerId: runnerId,
            pointsDelta: pointsDelta,
          );
      ref.invalidate(overallPointsProvider);
      ref.invalidate(racePointsProvider(raceId));

      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop(
        _PointsAdjustmentResult(
          runnerName: updated.runnerName,
          updatedTotalPoints: updated.totalPoints,
          pointsDelta: pointsDelta,
        ),
      );
    } on FormatException catch (error) {
      setState(() {
        _isSaving = false;
        _validationMessage = error.message;
      });
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      await showUserMessageDialog(
        context,
        title: 'Could not adjust points',
        message: userFacingErrorMessage(
          error,
          fallback:
              'The overall points adjustment could not be saved right now.',
        ),
        tone: UserDialogTone.error,
      );
    }
  }
}

Race? _findLatestRace(List<Race> races) {
  if (races.isEmpty) {
    return null;
  }

  final sortedRaces = List<Race>.from(races)
    ..sort((left, right) {
      final raceDateComparison = right.raceDate.compareTo(left.raceDate);
      if (raceDateComparison != 0) {
        return raceDateComparison;
      }
      return right.createdAt.compareTo(left.createdAt);
    });
  return sortedRaces.first;
}

class _BulkRaceToolsDialog extends ConsumerStatefulWidget {
  const _BulkRaceToolsDialog();

  @override
  ConsumerState<_BulkRaceToolsDialog> createState() =>
      _BulkRaceToolsDialogState();
}

class _BulkRaceToolsDialogState extends ConsumerState<_BulkRaceToolsDialog> {
  final TextEditingController _namePrefixController = TextEditingController();
  final TextEditingController _seriesNameController = TextEditingController();
  final TextEditingController _datesController = TextEditingController();
  bool _isWorking = false;

  @override
  void dispose() {
    _namePrefixController.dispose();
    _seriesNameController.dispose();
    _datesController.dispose();
    super.dispose();
  }

  Future<void> _refreshRaceLists() async {
    ref.invalidate(raceListProvider);
    ref.invalidate(currentRaceProvider);
  }

  Future<void> _importScheduleFile() async {
    setState(() {
      _isWorking = true;
    });

    try {
      final schedule = await ref.read(importServiceProvider).pickRaceSchedule();
      if (schedule == null) {
        return;
      }

      final result = await ref
          .read(raceServiceProvider)
          .createRacesFromSchedule(
            entries: schedule.entries,
            fallbackNamePrefix: _namePrefixController.text,
            fallbackSeriesName: _seriesNameController.text,
          );

      await _refreshRaceLists();

      if (!mounted) {
        return;
      }

      final messageParts = <String>[
        'Created ${result.createdCount} races from ${schedule.sourceName}.',
      ];
      if (result.skippedCount > 0) {
        messageParts.add(
          'Skipped ${result.skippedCount} duplicates that already existed.',
        );
      }
      if (schedule.invalidRowCount > 0) {
        messageParts.add(
          'Ignored ${schedule.invalidRowCount} rows that did not contain a usable race date.',
        );
      }

      await showUserMessageDialog(
        context,
        title: 'Race schedule imported',
        message: messageParts.join(' '),
        tone: UserDialogTone.success,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Schedule needs attention',
        message: error.message,
        tone: UserDialogTone.warning,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Could not import schedule',
        message: userFacingErrorMessage(
          error,
          fallback:
              'The race schedule could not be imported right now. Please try again.',
        ),
        tone: UserDialogTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _createFromTypedDates() async {
    setState(() {
      _isWorking = true;
    });

    try {
      final dates = ref
          .read(raceServiceProvider)
          .parseBulkRaceDates(_datesController.text);
      final result = await ref
          .read(raceServiceProvider)
          .createRacesFromDates(
            namePrefix: _namePrefixController.text,
            seriesName: _seriesNameController.text,
            dates: dates,
          );

      await _refreshRaceLists();

      if (!mounted) {
        return;
      }

      await showUserMessageDialog(
        context,
        title: 'Race dates created',
        message:
            'Created ${result.createdCount} races. Skipped ${result.skippedCount} duplicates that already existed.',
        tone: UserDialogTone.success,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Dates need attention',
        message: error.message,
        tone: UserDialogTone.warning,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Could not create races',
        message: userFacingErrorMessage(
          error,
          fallback:
              'The race dates could not be saved right now. Please try again.',
        ),
        tone: UserDialogTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final compactHeight = mediaSize.height < 900;

    return AlertDialog(
      title: const Text('Bulk Race Creation'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: mediaSize.height * 0.68,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload an Excel or CSV schedule for the whole year, or paste one race date per line.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _namePrefixController,
                decoration: const InputDecoration(
                  labelText: 'Fallback race title prefix',
                  hintText: 'Example: Saturday Park Run',
                  helperText:
                      'Used when the uploaded file has dates only and no race name column.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _seriesNameController,
                decoration: const InputDecoration(
                  labelText: 'Series name (optional)',
                  hintText: 'Example: 2026 Park Series',
                ),
              ),
              const SizedBox(height: 16),
              StatusBanner(
                title: 'Schedule upload',
                message:
                    'Accepted formats are Excel (.xlsx) and CSV (.csv). Include a date column, and optionally race name and series name columns.',
                tone: StatusBannerTone.info,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isWorking ? null : _importScheduleFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload Race Schedule File'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _datesController,
                minLines: compactHeight ? 4 : 5,
                maxLines: compactHeight ? 5 : 7,
                decoration: const InputDecoration(
                  labelText: 'Race dates',
                  hintText: '2026-03-28\n2026-04-04\n2026-04-11',
                  helperText:
                      'Use one date per line. Supported formats: YYYY-MM-DD, MM/DD/YYYY, or Month Day, Year.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isWorking ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _isWorking ? null : _createFromTypedDates,
          child: const Text('Create From Typed Dates'),
        ),
      ],
    );
  }
}
