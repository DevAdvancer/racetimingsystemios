import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/overall_runner_points_summary.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/points_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/widgets/branding.dart';
import 'package:race_timer/widgets/status_banner.dart';

class OverallPointsScreen extends ConsumerStatefulWidget {
  const OverallPointsScreen({super.key});

  @override
  ConsumerState<OverallPointsScreen> createState() =>
      _OverallPointsScreenState();
}

class _OverallPointsScreenState extends ConsumerState<OverallPointsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final racesAsync = ref.watch(raceListProvider);
    final pointsAsync = ref.watch(overallPointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(pageTitle: 'Overall Points'),
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
          child: _buildBody(
            context,
            racesAsync: racesAsync,
            pointsAsync: pointsAsync,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required AsyncValue<List<Race>> racesAsync,
    required AsyncValue<List<OverallRunnerPointsSummary>> pointsAsync,
  }) {
    if (racesAsync.hasError) {
      return StatusBanner(
        title: 'Could not load races',
        message: userFacingErrorMessage(
          racesAsync.error!,
          fallback: 'The race list is unavailable right now.',
        ),
        tone: StatusBannerTone.error,
      );
    }

    if (pointsAsync.hasError) {
      return StatusBanner(
        title: 'Could not load overall points',
        message: userFacingErrorMessage(
          pointsAsync.error!,
          fallback:
              'The full overall points table could not be loaded right now.',
        ),
        tone: StatusBannerTone.error,
      );
    }

    if (racesAsync.isLoading || pointsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final races = racesAsync.asData?.value ?? const <Race>[];
    final rows =
        pointsAsync.asData?.value ?? const <OverallRunnerPointsSummary>[];
    final filteredRows = _filterRows(rows, _searchQuery);
    final latestRace = _findLatestRace(races);
    final totalPoints = rows.fold<int>(0, (sum, row) => sum + row.totalPoints);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StatusBanner(
          title: 'Full standings table',
          message:
              'Search by racer name to quickly find any runner in the overall points standings.',
          tone: StatusBannerTone.info,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricTile(
              label: 'Latest Race',
              value: latestRace?.name ?? 'No races yet',
            ),
            _MetricTile(label: 'Total Races', value: '${races.length}'),
            _MetricTile(label: 'Racers', value: '${rows.length}'),
            _MetricTile(label: 'Points Awarded', value: '$totalPoints'),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            labelText: 'Search racer name',
            hintText: 'Type a runner name',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _searchQuery.trim().isEmpty
              ? 'Showing all ${rows.length} racers.'
              : 'Showing ${filteredRows.length} of ${rows.length} racers.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: rows.isEmpty
                  ? const StatusBanner(
                      title: 'No overall points yet',
                      message:
                          'Award points from a race dashboard, then this full standings table will populate automatically.',
                      tone: StatusBannerTone.info,
                    )
                  : filteredRows.isEmpty
                  ? StatusBanner(
                      title: 'No matching racers',
                      message:
                          'No racer name matched "${_searchQuery.trim()}". Try a shorter name or clear search.',
                      tone: StatusBannerTone.warning,
                    )
                  : _OverallPointsTable(rows: filteredRows),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverallPointsTable extends StatelessWidget {
  const _OverallPointsTable({required this.rows});

  final List<OverallRunnerPointsSummary> rows;

  @override
  Widget build(BuildContext context) {
    final timestampFormat = DateFormat('dd MMM yyyy, h:mm a');

    return LayoutBuilder(
      builder: (context, constraints) {
        final table = DataTable(
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Runner Name')),
            DataColumn(label: Text('Barcode')),
            DataColumn(label: Text('Total Points'), numeric: true),
            DataColumn(label: Text('Awards'), numeric: true),
            DataColumn(label: Text('Latest Race')),
            DataColumn(label: Text('Last Awarded')),
          ],
          rows: [
            for (var index = 0; index < rows.length; index++)
              DataRow(
                cells: [
                  DataCell(Text('${index + 1}')),
                  DataCell(Text(rows[index].runnerName)),
                  DataCell(Text(rows[index].barcodeValue)),
                  DataCell(Text('${rows[index].totalPoints}')),
                  DataCell(Text('${rows[index].awardCount}')),
                  DataCell(Text(rows[index].latestRaceName ?? '-')),
                  DataCell(
                    Text(
                      rows[index].lastAwardedAt == null
                          ? '-'
                          : timestampFormat.format(
                              rows[index].lastAwardedAt!.toLocal(),
                            ),
                    ),
                  ),
                ],
              ),
          ],
        );

        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth > 960
                      ? constraints.maxWidth
                      : 960,
                ),
                child: table,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
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

List<OverallRunnerPointsSummary> _filterRows(
  List<OverallRunnerPointsSummary> rows,
  String query,
) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return rows;
  }
  return rows
      .where((row) => row.runnerName.toLowerCase().contains(normalizedQuery))
      .toList(growable: false);
}

Race? _findLatestRace(List<Race> races) {
  if (races.isEmpty) {
    return null;
  }
  return races.reduce((current, candidate) {
    if (candidate.raceDate.isAfter(current.raceDate)) {
      return candidate;
    }
    if (candidate.raceDate.isAtSameMomentAs(current.raceDate) &&
        candidate.createdAt.isAfter(current.createdAt)) {
      return candidate;
    }
    return current;
  });
}
