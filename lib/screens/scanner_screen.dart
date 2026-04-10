import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/finish_scan_result.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/models/race_result.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/finish_scanner_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/results_provider.dart';
import 'package:race_timer/services/race_service.dart';
import 'package:race_timer/widgets/branding.dart';
import 'package:race_timer/widgets/results_table.dart';
import 'package:race_timer/widgets/runner_card.dart';
import 'package:race_timer/widgets/status_banner.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final TextEditingController _scannerController = TextEditingController();
  final FocusNode _scannerFocusNode = FocusNode();
  final ValueNotifier<String> _bufferNotifier = ValueNotifier<String>('');

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
  }

  Future<void> _submitScan() async {
    await ref
        .read(finishScannerProvider.notifier)
        .submitBuffer(_scannerController.text);
    if (!mounted) {
      return;
    }
    _scannerController.clear();
    _bufferNotifier.value = '';
    _requestScannerFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(pageTitle: 'Runner Scanner'),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scannerPanel = Consumer(
                builder: (context, ref, child) {
                  final raceAsync = ref.watch(currentRaceProvider);
                  final scannerState = ref.watch(finishScannerProvider);

                  return _buildScannerPanel(
                    context,
                    raceAsync: raceAsync,
                    scannerState: scannerState,
                  );
                },
              );
              final liveResultsPanel = Consumer(
                builder: (context, ref, child) {
                  final resultsAsync = ref.watch(resultsProvider);
                  return _buildLiveResultsPanel(context, resultsAsync);
                },
              );

              if (constraints.maxWidth >= 1100) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 460,
                      child: SingleChildScrollView(child: scannerPanel),
                    ),
                    const SizedBox(width: 24),
                    Expanded(child: liveResultsPanel),
                  ],
                );
              }

              final liveResultsHeight = constraints.maxHeight >= 900
                  ? 520.0
                  : 380.0;

              return ListView(
                children: [
                  scannerPanel,
                  const SizedBox(height: 24),
                  SizedBox(height: liveResultsHeight, child: liveResultsPanel),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScanBanner(FinishScanResult result) {
    final tone = switch (result.status) {
      FinishScanStatus.idle => StatusBannerTone.info,
      FinishScanStatus.success => StatusBannerTone.success,
      FinishScanStatus.raceStarted => StatusBannerTone.success,
      FinishScanStatus.awaitingEarlyStartRunner => StatusBannerTone.info,
      FinishScanStatus.earlyStartRecorded => StatusBannerTone.success,
      FinishScanStatus.unknownBarcode => StatusBannerTone.error,
      FinishScanStatus.duplicateScan => StatusBannerTone.warning,
      FinishScanStatus.raceNotStarted => StatusBannerTone.warning,
      FinishScanStatus.validationError => StatusBannerTone.error,
      FinishScanStatus.failure => StatusBannerTone.error,
    };

    final title = switch (result.status) {
      FinishScanStatus.idle => 'Ready',
      FinishScanStatus.success => result.runnerName ?? 'Finisher recorded',
      FinishScanStatus.raceStarted => 'Race started',
      FinishScanStatus.awaitingEarlyStartRunner => 'Early start mode',
      FinishScanStatus.earlyStartRecorded =>
        result.runnerName ?? 'Early start recorded',
      FinishScanStatus.unknownBarcode => 'Unknown barcode',
      FinishScanStatus.duplicateScan => 'Duplicate scan',
      FinishScanStatus.raceNotStarted => 'Race not started',
      FinishScanStatus.validationError => 'Scan issue',
      FinishScanStatus.failure => 'Scanner error',
    };

    final earlyStarterPrefix = result.isEarlyStarter ? 'Early starter. ' : '';
    final message = result.isSuccess
        ? result.status == FinishScanStatus.raceStarted
              ? 'Gun time recorded at ${RaceService.formatFinishTime(result.startTime)}. Early starters keep their personal start times.'
              : result.status == FinishScanStatus.earlyStartRecorded
              ? 'Early start recorded at ${RaceService.formatFinishTime(result.startTime)}.'
              : '${earlyStarterPrefix}Elapsed ${RaceService.formatElapsed(result.elapsedTimeMs)} at ${RaceService.formatFinishTime(result.finishTime)}'
        : result.status == FinishScanStatus.duplicateScan &&
              result.finishTime != null
        ? '${result.message} ${result.isEarlyStarter ? 'This runner used an early start. ' : ''}First finish kept: ${RaceService.formatElapsed(result.elapsedTimeMs)} at ${RaceService.formatFinishTime(result.finishTime)}.'
        : result.message;

    return StatusBanner(title: title, message: message, tone: tone);
  }

  Widget _buildScannerPanel(
    BuildContext context, {
    required AsyncValue<Race?> raceAsync,
    required FinishScannerState scannerState,
  }) {
    final race = raceAsync.asData?.value;
    final waitingMessage = race == null
        ? 'Create or select a race before scanning.'
        : race.isRunning
        ? 'Waiting for runner barcode to record a finish.'
        : 'Waiting for runner barcode. Any scan before Global Start becomes that runner\'s early start.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        raceAsync.when(
          data: (race) => StatusBanner(
            title: race?.name ?? 'No active race',
            message: race == null
                ? 'Create a race in Setup before scanning.'
                : 'Status: ${race.statusLabel}',
            tone: race?.isRunning == true
                ? StatusBannerTone.success
                : StatusBannerTone.warning,
          ),
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => StatusBanner(
            title: 'Scanner unavailable',
            message: userFacingErrorMessage(
              error,
              fallback:
                  'The scanner screen could not connect to the current race. Please go back and try again.',
            ),
            tone: StatusBannerTone.error,
          ),
        ),
        const SizedBox(height: 20),
        _buildScanBanner(scannerState.lastResult),
        if (_shouldShowScanHighlight(scannerState.lastResult)) ...[
          const SizedBox(height: 20),
          _buildScanHighlightCard(context, scannerState.lastResult),
        ],
        const SizedBox(height: 20),
        const StatusBanner(
          title: 'How scanning works',
          message:
              'Use Global Start in Race Control for everyone except early starters. Before Global Start, scanning a runner barcode records that runner\'s personal early start. After Global Start, scanning a runner barcode records the finish.',
          tone: StatusBannerTone.info,
        ),
        const SizedBox(height: 20),
        SizedBox(
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
        ValueListenableBuilder<String>(
          valueListenable: _bufferNotifier,
          builder: (context, buffer, child) {
            return RunnerCard(
              title: race?.isRunning == true
                  ? 'Finish scanner ready'
                  : 'Early-start scanner ready',
              subtitle: scannerState.isSubmitting
                  ? 'Recording scan...'
                  : buffer.isEmpty
                  ? waitingMessage
                  : 'Buffered: $buffer',
              trailing: IconButton(
                icon: const Icon(Icons.center_focus_strong),
                onPressed: _requestScannerFocus,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: scannerState.isSubmitting ? null : _submitScan,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Record Scan'),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveResultsPanel(
    BuildContext context,
    AsyncValue<List<RaceResultRow>> resultsAsync,
  ) {
    final finisherCount = resultsAsync.asData?.value
        .where((row) => row.finishTime != null)
        .length;
    final finisherMessage = finisherCount == null
        ? 'Each finisher appears here immediately after scanning.'
        : finisherCount == 0
        ? 'Each finisher appears here immediately after scanning.'
        : '$finisherCount finishers recorded. Early starters stay tagged in the order they finished.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusBanner(
          title: 'Live finish order',
          message: finisherMessage,
          tone: StatusBannerTone.info,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: resultsAsync.when(
            data: (rows) => ResultsTable(results: rows),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => StatusBanner(
              title: 'Unable to load results',
              message: userFacingErrorMessage(
                error,
                fallback:
                    'The live results panel could not refresh. Please return to the dashboard and try again.',
              ),
              tone: StatusBannerTone.error,
            ),
          ),
        ),
      ],
    );
  }

  bool _shouldShowScanHighlight(FinishScanResult result) {
    return result.status == FinishScanStatus.success ||
        result.status == FinishScanStatus.duplicateScan ||
        result.status == FinishScanStatus.earlyStartRecorded ||
        result.status == FinishScanStatus.raceStarted;
  }

  Widget _buildScanHighlightCard(
    BuildContext context,
    FinishScanResult result,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = switch (result.status) {
      FinishScanStatus.success => 'Last finisher',
      FinishScanStatus.duplicateScan => 'Already recorded',
      FinishScanStatus.earlyStartRecorded => 'Early start saved',
      FinishScanStatus.raceStarted => 'Gun time recorded',
      _ => 'Scanner update',
    };

    final headline = switch (result.status) {
      FinishScanStatus.raceStarted => RaceService.formatFinishTime(
        result.startTime,
      ),
      _ => result.runnerName ?? 'Ready',
    };

    final detail = switch (result.status) {
      FinishScanStatus.success =>
        '${result.isEarlyStarter ? 'Early starter • ' : ''}Elapsed ${RaceService.formatElapsed(result.elapsedTimeMs)} at ${RaceService.formatFinishTime(result.finishTime)}',
      FinishScanStatus.duplicateScan =>
        '${result.isEarlyStarter ? 'Early starter • ' : ''}First finish kept at ${RaceService.formatFinishTime(result.finishTime)} with ${RaceService.formatElapsed(result.elapsedTimeMs)}',
      FinishScanStatus.earlyStartRecorded =>
        'Personal start time ${RaceService.formatFinishTime(result.startTime)}',
      FinishScanStatus.raceStarted =>
        'Finish-line scans now use this gun time for everyone without an early start.',
      _ => result.message,
    };

    final icon = switch (result.status) {
      FinishScanStatus.success => Icons.emoji_events,
      FinishScanStatus.duplicateScan => Icons.history,
      FinishScanStatus.earlyStartRecorded => Icons.alarm_on,
      FinishScanStatus.raceStarted => Icons.flag,
      _ => Icons.info_outline,
    };

    final backgroundColor = result.status == FinishScanStatus.duplicateScan
        ? colorScheme.secondaryContainer
        : colorScheme.primaryContainer;

    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              headline,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
