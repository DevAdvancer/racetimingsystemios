import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(pageTitle: 'Live Results'),
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
              const StatusBanner(
                title: 'Finish order',
                message: 'Results update automatically after each finisher.',
                tone: StatusBannerTone.info,
              ),
              if (finisherCount != null) ...[
                const SizedBox(height: 12),
                StatusBanner(
                  title: 'Recorded finishers',
                  message: finisherCount == 0
                      ? 'No finishers have been scanned yet.'
                      : '$finisherCount finishers are in the live order below.',
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
