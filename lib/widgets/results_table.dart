import 'package:flutter/material.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/services/race_service.dart';

class ResultsTable extends StatelessWidget {
  const ResultsTable({super.key, required this.results});

  final List<RaceResultRow> results;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleRows = results
        .where((row) => row.startTime != null || row.finishTime != null)
        .toList(growable: false);
    visibleRows.sort((left, right) {
      final leftFinish = left.finishTime;
      final rightFinish = right.finishTime;
      if (leftFinish != null && rightFinish != null) {
        final comparison = leftFinish.compareTo(rightFinish);
        return comparison == 0
            ? left.entryId.compareTo(right.entryId)
            : comparison;
      }
      if (leftFinish != null) {
        return -1;
      }
      if (rightFinish != null) {
        return 1;
      }
      return left.entryId.compareTo(right.entryId);
    });

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Place',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Runner',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Start Time',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'End Time',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: visibleRows.isEmpty
                ? Center(
                    child: Text(
                      'No runners started yet.',
                      style: theme.textTheme.titleMedium,
                    ),
                  )
                : ListView.separated(
                    itemCount: visibleRows.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      final row = visibleRows[index];
                      final place = row.finishTime == null
                          ? '--'
                          : '${visibleRows.take(index).where((row) => row.finishTime != null).length + 1}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                place,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.runnerName,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (row.earlyStart) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFE2B6),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        'Early Start',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: const Color(0xFF8A4B00),
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                RaceService.formatFinishTime(row.startTime),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                RaceService.formatFinishTime(row.finishTime),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                RaceService.formatElapsed(row.elapsedTimeMs),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
