import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/core/app_navigation.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/providers/finish_scanner_provider.dart';
import 'package:race_timer/providers/results_provider.dart';
import 'package:race_timer/widgets/branding.dart';
import 'package:race_timer/widgets/finish_scan_keyboard_listener.dart';
import 'package:race_timer/widgets/results_table.dart';

class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(resultsProvider);

    return FinishScanKeyboardListener(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const _ScannerTopBar(),
              Expanded(
                child: resultsAsync.when(
                  data: (rows) =>
                      ResultsTable(results: rows, showRegisteredRows: true),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        userFacingErrorMessage(
                          error,
                          fallback:
                              'The results table could not refresh. Please return to the dashboard and try again.',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
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
}

class _ScannerTopBar extends ConsumerWidget {
  const _ScannerTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scannerState = ref.watch(finishScannerProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          const Expanded(child: BrandAppBarTitle(pageTitle: 'Result Table')),
          _ScannerStatus(isSubmitting: scannerState.isSubmitting),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Back to Race Dashboard',
            child: OutlinedButton.icon(
              onPressed: () => goToAppRoute(context, AppRoutes.raceDashboard),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 56),
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Race Dashboard'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerStatus extends StatelessWidget {
  const _ScannerStatus({required this.isSubmitting});

  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = isSubmitting
        ? colorScheme.onTertiaryContainer
        : colorScheme.onPrimaryContainer;
    final backgroundColor = isSubmitting
        ? colorScheme.tertiaryContainer
        : colorScheme.primaryContainer;

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSubmitting ? Icons.sync : Icons.sensors,
            color: foregroundColor,
          ),
          const SizedBox(width: 10),
          Text(
            isSubmitting ? 'Recording scan' : 'Scanner listening',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
