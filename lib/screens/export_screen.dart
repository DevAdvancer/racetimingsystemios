import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/results_provider.dart';
import 'package:race_timer/services/export_service.dart';
import 'package:race_timer/widgets/branding.dart';
import 'package:race_timer/widgets/status_banner.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportResult? _lastResult;
  bool _exporting = false;
  int? _selectedRaceId;

  Future<void> _exportCsv({required Race race}) async {
    setState(() {
      _exporting = true;
      _lastResult = null;
    });

    try {
      final rows = await ref.read(raceResultsProvider(race.id).future);

      final result = await ref
          .read(exportServiceProvider)
          .exportResults(race: race, rows: rows);
      setState(() {
        _lastResult = result;
      });
    } catch (error) {
      setState(() {
        _lastResult = ExportResult.failure(
          userFacingErrorMessage(
            error,
            fallback:
                'The results CSV could not be prepared right now. Please try again.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _exportPdf({required Race race}) async {
    setState(() {
      _exporting = true;
      _lastResult = null;
    });

    try {
      final rows = await ref.read(raceResultsProvider(race.id).future);

      final result = await ref
          .read(exportServiceProvider)
          .exportResultsPdf(race: race, rows: rows);
      setState(() {
        _lastResult = result;
      });
    } catch (error) {
      setState(() {
        _lastResult = ExportResult.failure(
          userFacingErrorMessage(
            error,
            fallback:
                'The results PDF could not be prepared right now. Please try again.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRaceAsync = ref.watch(currentRaceProvider);
    final raceListAsync = ref.watch(raceListProvider);
    final races = raceListAsync.asData?.value ?? const <Race>[];
    final currentRace = currentRaceAsync.asData?.value;
    final selectedRace = _resolveSelectedRace(
      races: races,
      currentRace: currentRace,
    );
    final selectedResultsAsync = selectedRace == null
        ? null
        : ref.watch(raceResultsProvider(selectedRace.id));

    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(pageTitle: 'Export Results'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              raceListAsync.when(
                data: (races) => StatusBanner(
                  title: selectedRace?.name ?? 'No race selected',
                  message: races.isEmpty
                      ? 'Create a race before exporting results.'
                      : 'Choose a race and export either a full CSV or a printable PDF-style results sheet with the race-day columns.',
                  tone: races.isEmpty
                      ? StatusBannerTone.warning
                      : StatusBannerTone.info,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => StatusBanner(
                  title: 'Export unavailable',
                  message:
                      'The export screen could not load the current race. Please go back and choose the race again.',
                  tone: StatusBannerTone.error,
                ),
              ),
              const SizedBox(height: 20),
              if (races.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  initialValue: selectedRace?.id,
                  decoration: const InputDecoration(
                    labelText: 'Race to export',
                    helperText:
                        'Select the race whose results should be exported.',
                  ),
                  items: races
                      .map(
                        (race) => DropdownMenuItem<int>(
                          value: race.id,
                          child: Text(race.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _exporting
                      ? null
                      : (value) {
                          setState(() {
                            _selectedRaceId = value;
                            _lastResult = null;
                          });
                        },
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: selectedResultsAsync == null
                      ? _buildExportSummary(
                          context,
                          race: null,
                          rows: const <RaceResultRow>[],
                        )
                      : selectedResultsAsync.when(
                          data: (rows) => _buildExportSummary(
                            context,
                            race: selectedRace,
                            rows: rows,
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) => StatusBanner(
                            title: 'Unable to prepare export',
                            message: userFacingErrorMessage(
                              error,
                              fallback:
                                  'The selected race results could not be loaded for export right now.',
                            ),
                            tone: StatusBannerTone.error,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const Spacer(),
              ],
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _exporting || selectedRace == null
                          ? null
                          : () => _exportCsv(race: selectedRace),
                      icon: const Icon(Icons.table_view_outlined),
                      label: Text(
                        _exporting
                            ? 'Exporting...'
                            : 'Export Selected Race CSV',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exporting || selectedRace == null
                          ? null
                          : () => _exportPdf(race: selectedRace),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Export Selected Race PDF'),
                    ),
                  ],
                ),
              ),
              if (_lastResult != null) ...[
                const SizedBox(height: 20),
                StatusBanner(
                  title: 'Export status',
                  message: _lastResult!.message,
                  tone: _lastResult!.succeeded
                      ? StatusBannerTone.success
                      : StatusBannerTone.warning,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Race? _resolveSelectedRace({
    required List<Race> races,
    required Race? currentRace,
  }) {
    final preferredId = _selectedRaceId ?? currentRace?.id;
    if (preferredId != null) {
      for (final race in races) {
        if (race.id == preferredId) {
          return race;
        }
      }
    }
    return races.isEmpty ? null : races.first;
  }

  Widget _buildExportSummary(
    BuildContext context, {
    required Race? race,
    required List<RaceResultRow> rows,
  }) {
    final totalEntries = rows.length;
    final finishers = rows.where((row) => row.finishTime != null).length;
    final earlyStarters = rows.where((row) => row.earlyStart).length;
    final exportService = ref.read(exportServiceProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              race == null
                  ? 'Select a race to preview the CSV export.'
                  : 'Race date: ${DateFormat('yyyy-MM-dd').format(race.raceDate.toLocal())}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Entries: $totalEntries • Finishers: $finishers • Early starts: $earlyStarters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (race != null)
              Text(
                'File name: ${exportService.buildFileName(race, exportedAt: DateTime.now())}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 12),
            Text(
              'The exports include the race-day columns from the roster template, including name, city, Bib No., age, gender, barcode, payment status, and timing details.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
