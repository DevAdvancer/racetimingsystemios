import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/models/finish_scan_result.dart';
import 'package:race_timer/providers/finish_scanner_provider.dart';
import 'package:race_timer/services/race_service.dart';

class FinishScanKeyboardListener extends ConsumerStatefulWidget {
  const FinishScanKeyboardListener({
    super.key,
    required this.child,
    this.debounceDuration = const Duration(milliseconds: 180),
    this.popupDuration = const Duration(seconds: 1),
    this.enabled = true,
    this.onScan,
  });

  final Widget child;
  final Duration debounceDuration;
  final Duration popupDuration;
  final bool enabled;
  final Future<FinishScanResult> Function(String scanValue)? onScan;

  @override
  ConsumerState<FinishScanKeyboardListener> createState() =>
      _FinishScanKeyboardListenerState();
}

class _FinishScanKeyboardListenerState
    extends ConsumerState<FinishScanKeyboardListener> {
  final StringBuffer _buffer = StringBuffer();
  final FocusNode _focusNode = FocusNode(debugLabel: 'finishScanKeyboard');
  Timer? _autoSubmitTimer;
  bool _isSubmitting = false;
  bool _submitWhenReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _autoSubmitTimer?.cancel();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (_isScanTerminator(key)) {
      final hadBufferedScan = _buffer.toString().trim().isNotEmpty;
      _autoSubmitTimer?.cancel();
      _submitBufferedScan();
      return hadBufferedScan ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    final character = event.character;
    if (character == null || character.isEmpty || _isControlText(character)) {
      return KeyEventResult.ignored;
    }

    _buffer.write(character);
    _autoSubmitTimer?.cancel();
    _autoSubmitTimer = Timer(widget.debounceDuration, _submitBufferedScan);
    return KeyEventResult.handled;
  }

  bool _isScanTerminator(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab;
  }

  bool _isControlText(String value) {
    return value.runes.any((rune) => rune < 0x20 || rune == 0x7f);
  }

  void _submitBufferedScan() {
    if (_isSubmitting) {
      _submitWhenReady = true;
      return;
    }

    final scanValue = _buffer.toString().trim();
    _buffer.clear();
    if (scanValue.isEmpty) {
      return;
    }

    _isSubmitting = true;
    unawaited(_recordScan(scanValue));
  }

  Future<void> _recordScan(String scanValue) async {
    try {
      final result = await _submitScan(scanValue);
      if (mounted) {
        _showScanPopup(result);
      }
    } finally {
      _isSubmitting = false;
      if (mounted && widget.enabled) {
        _focusNode.requestFocus();
      }
      if (_submitWhenReady || _buffer.toString().trim().isNotEmpty) {
        _submitWhenReady = false;
        _submitBufferedScan();
      }
    }
  }

  Future<FinishScanResult> _submitScan(String scanValue) {
    final onScan = widget.onScan;
    if (onScan != null) {
      return onScan(scanValue);
    }
    return ref.read(finishScannerProvider.notifier).submitBuffer(scanValue);
  }

  void _showScanPopup(FinishScanResult result) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || result.status == FinishScanStatus.idle) {
      return;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(_popupMessage(result)),
        duration: widget.popupDuration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: _popupColor(result),
      ),
    );
  }

  Color? _popupColor(FinishScanResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (result.status) {
      FinishScanStatus.success ||
      FinishScanStatus.raceStarted ||
      FinishScanStatus.earlyStartRecorded => colorScheme.primary,
      FinishScanStatus.duplicateScan ||
      FinishScanStatus.awaitingEarlyStartRunner => colorScheme.tertiary,
      FinishScanStatus.unknownBarcode ||
      FinishScanStatus.raceNotStarted ||
      FinishScanStatus.validationError ||
      FinishScanStatus.failure => colorScheme.error,
      FinishScanStatus.idle => null,
    };
  }

  String _popupMessage(FinishScanResult result) {
    final runnerName = result.runnerName ?? 'Runner';
    return switch (result.status) {
      FinishScanStatus.success =>
        '$runnerName finish scanned at ${RaceService.formatFinishTime(result.finishTime)}',
      FinishScanStatus.earlyStartRecorded =>
        '$runnerName early start scanned at ${RaceService.formatFinishTime(result.startTime)}',
      FinishScanStatus.raceStarted => 'Global start scanned',
      FinishScanStatus.duplicateScan => '$runnerName was already scanned',
      _ => result.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.enabled,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.enabled ? _focusNode.requestFocus : null,
        child: widget.child,
      ),
    );
  }
}
