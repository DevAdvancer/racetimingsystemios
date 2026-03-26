import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
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
        title: const Text('Admin Dashboard'),
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
              PopupMenuItem(
                value: AppRoutes.diagnostics,
                child: Text('Diagnostics'),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroPanel(
                selectedRaceId: selectedRaceId,
                onCreateRace: () => _showCreateRaceDialog(context, ref),
                onOpenSelectedRace: selectedRaceId == null
                    ? null
                    : () => context.go(AppRoutes.raceDashboard),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: racesAsync.when(
                  data: (races) => _RaceListSection(
                    races: races,
                    selectedRaceId: selectedRaceId,
                    onCreateRace: () => _showCreateRaceDialog(context, ref),
                    onOpenRace: (race) async {
                      await ref
                          .read(currentRaceProvider.notifier)
                          .selectRace(race.id);
                      if (context.mounted) {
                        context.go(AppRoutes.raceDashboard);
                      }
                    },
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
                ),
              ),
            ],
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
    required this.onOpenSelectedRace,
  });

  final int? selectedRaceId;
  final VoidCallback onCreateRace;
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

class _RaceListSection extends StatelessWidget {
  const _RaceListSection({
    required this.races,
    required this.selectedRaceId,
    required this.onCreateRace,
    required this.onOpenRace,
  });

  final List<Race> races;
  final int? selectedRaceId;
  final VoidCallback onCreateRace;
  final ValueChanged<Race> onOpenRace;

  @override
  Widget build(BuildContext context) {
    if (races.isEmpty) {
      return _EmptyRaceState(onCreateRace: onCreateRace);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Available Races', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 1200
                  ? 3
                  : constraints.maxWidth >= 760
                  ? 2
                  : 1;

              return GridView.builder(
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
          ),
        ),
      ],
    );
  }
}

class _EmptyRaceState extends StatelessWidget {
  const _EmptyRaceState({required this.onCreateRace});

  final VoidCallback onCreateRace;

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
