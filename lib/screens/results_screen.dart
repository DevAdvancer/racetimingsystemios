import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/providers/results_provider.dart';
import 'package:race_timer/widgets/branding.dart';
import 'package:race_timer/widgets/results_table.dart';
import 'package:race_timer/widgets/status_banner.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(resultsProvider);
    final finisherCount = resultsAsync.asData?.value
        .where((row) => row.finishTime != null)
        .length;
    final startedCount = resultsAsync.asData?.value
        .where((row) => row.startTime != null || row.finishTime != null)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(pageTitle: 'Live Results'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusBanner(
                title: 'Live race results',
                message:
                    'Runners appear here after Global Start. Finish scans and Global Stop update their end and total times automatically.',
                tone: StatusBannerTone.info,
              ),
              if (finisherCount != null && startedCount != null) ...[
                const SizedBox(height: 12),
                StatusBanner(
                  title: 'Recorded runners',
                  message: startedCount == 0
                      ? 'No runners have started yet.'
                      : '$startedCount runners shown. $finisherCount ${finisherCount == 1 ? 'runner has' : 'runners have'} an end time.',
                  tone: StatusBannerTone.success,
                ),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: resultsAsync.when(
                  data: (rows) => ResultsTable(results: rows),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => StatusBanner(
                    title: 'Unable to load results',
                    message: userFacingErrorMessage(
                      error,
                      fallback:
                          'The race results could not be loaded. Please return to the dashboard and try again.',
                    ),
                    tone: StatusBannerTone.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
