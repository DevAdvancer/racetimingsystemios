import 'dart:async';

import 'package:flutter/material.dart';
import 'package:race_timer/services/race_service.dart';

class RaceClock extends StatefulWidget {
  const RaceClock({
    super.key,
    required this.gunTime,
    required this.endTime,
    required this.isRunning,
    DateTime Function()? now,
  }) : now = now ?? _defaultNow;

  final DateTime? gunTime;
  final DateTime? endTime;
  final bool isRunning;
  final DateTime Function() now;

  static DateTime _defaultNow() => DateTime.now().toUtc();

  @override
  State<RaceClock> createState() => _RaceClockState();
}

class _RaceClockState extends State<RaceClock> {
  Timer? _timer;
  int? _elapsedTimeMs;

  @override
  void initState() {
    super.initState();
    _configureTicker();
  }

  @override
  void didUpdateWidget(covariant RaceClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gunTime != widget.gunTime ||
        oldWidget.endTime != widget.endTime ||
        oldWidget.isRunning != widget.isRunning) {
      _configureTicker();
    }
  }

  void _configureTicker() {
    _timer?.cancel();
    _elapsedTimeMs = _calculateElapsed();

    if (widget.gunTime == null || !widget.isRunning) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) {
        setState(() {
          _elapsedTimeMs = _calculateElapsed();
        });
      }
    });
  }

  int? _calculateElapsed() {
    final gunTime = widget.gunTime;
    if (gunTime == null) {
      return null;
    }

    final referenceTime = widget.isRunning
        ? widget.now()
        : widget.endTime ?? widget.now();
    final elapsedTimeMs = referenceTime.difference(gunTime).inMilliseconds;
    return elapsedTimeMs < 0 ? 0 : elapsedTimeMs;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gunTime = widget.gunTime;
    final endTime = widget.endTime;

    return SizedBox(
      width: double.infinity,
      child: Card(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 280),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Race Clock',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    RaceService.formatElapsed(_elapsedTimeMs),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 96,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  gunTime == null
                      ? 'Clock begins when the race starts.'
                      : widget.isRunning
                      ? 'Started at ${RaceService.formatFinishTime(gunTime)}'
                      : endTime == null
                      ? 'Clock stopped. Started at ${RaceService.formatFinishTime(gunTime)}'
                      : 'Clock stopped at ${RaceService.formatFinishTime(endTime)}. Started at ${RaceService.formatFinishTime(gunTime)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
