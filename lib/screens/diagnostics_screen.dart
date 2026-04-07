import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/diagnostics_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/widgets/branding.dart';
import 'package:race_timer/widgets/status_banner.dart';
import 'package:race_timer/widgets/user_dialogs.dart';

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnosticsAsync = ref.watch(diagnosticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(pageTitle: 'Diagnostics'),
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
          child: diagnosticsAsync.when(
            data: (report) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBanner(
                  title: report.databaseHealthy
                      ? 'Database healthy'
                      : 'Database issue detected',
                  message: report.messages.join(' '),
                  tone: report.databaseHealthy
                      ? StatusBannerTone.success
                      : StatusBannerTone.warning,
                ),
                const SizedBox(height: 20),
                StatusBanner(
                  title: 'Printer',
                  message: report.printerStatus.message,
                  tone: report.printerStatus.isReady
                      ? StatusBannerTone.info
                      : StatusBannerTone.warning,
                ),
                const SizedBox(height: 20),
                StatusBanner(
                  title: report.scannerReady
                      ? 'Scanner confirmed'
                      : 'Scanner not confirmed',
                  message: report.scannerMessage,
                  tone: report.scannerReady
                      ? StatusBannerTone.success
                      : StatusBannerTone.warning,
                ),
                if (report.scanEventCount > 0) ...[
                  const SizedBox(height: 20),
                  StatusBanner(
                    title: 'Recent scan warnings',
                    message: report.recentScanIssues.join(' '),
                    tone: StatusBannerTone.warning,
                  ),
                ],
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(diagnosticsProvider.notifier).refresh(),
                      child: const Text('Refresh Diagnostics'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final status = await ref
                            .read(printerServiceProvider)
                            .testPrint();
                        if (context.mounted) {
                          await showUserMessageDialog(
                            context,
                            title: status.isReady
                                ? 'Printer ready'
                                : 'Printer test',
                            message: status.message,
                            tone: status.isReady
                                ? UserDialogTone.success
                                : UserDialogTone.warning,
                          );
                        }
                      },
                      child: const Text('Test Printer'),
                    ),
                    OutlinedButton(
                      onPressed: () => ref
                          .read(diagnosticsProvider.notifier)
                          .seedDryRunData(),
                      child: const Text('Generate Test Runners'),
                    ),
                    OutlinedButton(
                      onPressed: () => ref
                          .read(diagnosticsProvider.notifier)
                          .clearDryRunData(),
                      child: const Text('Clear Test Data'),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => StatusBanner(
              title: 'Diagnostics unavailable',
              message: userFacingErrorMessage(
                error,
                fallback:
                    'Diagnostics could not be loaded right now. Please refresh the app and try again.',
              ),
              tone: StatusBannerTone.error,
            ),
          ),
        ),
      ),
    );
  }
}
