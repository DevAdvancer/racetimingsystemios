import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/core/app_navigation.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/finish_scan_result.dart';
import 'package:race_timer/providers/finish_scanner_provider.dart';
import 'package:race_timer/providers/results_provider.dart';
import 'package:race_timer/services/race_service.dart';
import 'package:race_timer/widgets/branding.dart';
import 'package:race_timer/widgets/results_table.dart';
import 'package:race_timer/widgets/user_dialogs.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final TextEditingController _scannerController = TextEditingController();
  final FocusNode _scannerFocusNode = FocusNode();
  final ValueNotifier<String> _bufferNotifier = ValueNotifier<String>('');
  Timer? _autoSubmitTimer;
  bool _submittingScan = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestScannerFocus();
      }
    });
  }

  @override
  void dispose() {
    _autoSubmitTimer?.cancel();
    _bufferNotifier.dispose();
    _scannerController.dispose();
    _scannerFocusNode.dispose();
    super.dispose();
  }

  void _requestScannerFocus() {
    if (!_scannerFocusNode.hasFocus) {
      _scannerFocusNode.requestFocus();
    }
  }

  void _handleBufferChanged(String value) {
    if (_bufferNotifier.value == value) {
      return;
    }
    _bufferNotifier.value = value;
    _autoSubmitTimer?.cancel();
    if (value.trim().isEmpty || _submittingScan) {
      return;
    }

    if (value.contains('\n') || value.contains('\r') || value.contains('\t')) {
      unawaited(_submitScan());
      return;
    }

    _autoSubmitTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted &&
          !_submittingScan &&
          _scannerController.text.trim().isNotEmpty) {
        unawaited(_submitScan());
      }
    });
  }

  Future<void> _submitScan() async {
    if (_submittingScan) {
      return;
    }
    final scanValue = _scannerController.text.trim();
    if (scanValue.isEmpty) {
      _requestScannerFocus();
      return;
    }

    _autoSubmitTimer?.cancel();
    _submittingScan = true;
    try {
      final result = await ref
          .read(finishScannerProvider.notifier)
          .submitBuffer(scanValue);
      if (!mounted) {
        return;
      }
      _scannerController.clear();
      _bufferNotifier.value = '';
      _requestScannerFocus();
      await _showRecordedScanDialog(result);
    } finally {
      _submittingScan = false;
      if (mounted) {
        _requestScannerFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ScannerTopBar(onRecordScan: _submitScan),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final resultsAsync = ref.watch(resultsProvider);
                        return resultsAsync.when(
                          data: (rows) => ResultsTable(
                            results: rows,
                            showRegisteredRows: true,
                          ),
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
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: -10,
                    top: -10,
                    width: 1,
                    height: 1,
                    child: Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _scannerController,
                        focusNode: _scannerFocusNode,
                        autofocus: true,
                        onChanged: _handleBufferChanged,
                        onSubmitted: (_) => _submitScan(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRecordedScanDialog(FinishScanResult result) async {
    switch (result.status) {
      case FinishScanStatus.awaitingEarlyStartRunner:
        await showUserMessageDialog(
          context,
          title: 'Runner Start Ready',
          message:
              'Scan the runner barcode now and the personal start time will be stored for this race.',
          tone: UserDialogTone.info,
          buttonText: 'Continue Scanning',
        );
        return;
      case FinishScanStatus.earlyStartRecorded:
        await showUserMessageDialog(
          context,
          title: 'Personal Start Saved',
          message:
              '${result.runnerName ?? 'Runner'} started at ${RaceService.formatFinishTime(result.startTime)}. This personal start time is now stored for this race.',
          tone: UserDialogTone.success,
          buttonText: 'Continue Scanning',
        );
        return;
      case FinishScanStatus.success:
        final timingSource = result.isEarlyStarter
            ? 'This racer used a personal early-start time.'
            : 'This racer used the global start time.';
        final autoCloseMessage = result.raceAutoClosed
            ? ' This was the last unfinished runner in this race, so the race closed automatically at ${RaceService.formatFinishTime(result.raceEndTime ?? result.finishTime)}.'
            : '';
        await showUserMessageDialog(
          context,
          title: result.raceAutoClosed
              ? '${result.runnerName ?? 'Runner'} Finished ${RaceService.formatOrdinal(result.finishPlace)} and Race Closed'
              : '${result.runnerName ?? 'Runner'} Finished ${RaceService.formatOrdinal(result.finishPlace)}',
          message:
              '${result.runnerName ?? 'Runner'} has finished in ${RaceService.formatOrdinal(result.finishPlace)} place at ${RaceService.formatFinishTime(result.finishTime)} with a stored time of ${RaceService.formatElapsed(result.elapsedTimeMs)}. $timingSource$autoCloseMessage',
          tone: UserDialogTone.success,
          buttonText: 'Continue Scanning',
        );
        return;
      default:
        return;
    }
  }
}

class _ScannerTopBar extends ConsumerWidget {
  const _ScannerTopBar({required this.onRecordScan});

  final VoidCallback onRecordScan;

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
          FilledButton.icon(
            onPressed: scannerState.isSubmitting ? null : onRecordScan,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Record Scan'),
          ),
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
