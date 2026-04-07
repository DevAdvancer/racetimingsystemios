import 'package:flutter/services.dart';

String userFacingErrorMessage(Object error, {required String fallback}) {
  final rawMessage = switch (error) {
    PlatformException() => error.message ?? error.code,
    FormatException() => error.message,
    UnsupportedError() => error.message ?? fallback,
    ArgumentError() => fallback,
    StateError() => error.message,
    Exception() => error.toString(),
    _ => error.toString(),
  };

  final cleaned = rawMessage
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Unsupported operation: ', '')
      .trim();

  final friendly = _rewriteCommonTechnicalMessage(cleaned) ?? cleaned;

  if (friendly.isEmpty || _looksTechnical(friendly)) {
    return fallback;
  }

  return friendly;
}

String? _rewriteCommonTechnicalMessage(String message) {
  if (message.isEmpty) {
    return null;
  }

  final lower = message.toLowerCase();
  if (lower.contains('unique constraint failed') &&
      lower.contains('runners.barcode_value')) {
    return 'That barcode is already assigned to another runner.';
  }
  if (lower.contains('unique constraint failed') &&
      lower.contains('race_entries.runner_id') &&
      lower.contains('race_id')) {
    return 'That runner is already registered for this race.';
  }
  if (lower.contains('database is locked')) {
    return 'The app is still saving another change. Please wait a moment and try again.';
  }
  if (lower.contains('unable to open database') ||
      lower.contains('open_failed')) {
    return 'Saved race data could not be opened right now.';
  }
  if (lower.contains('runner record could not be found')) {
    return 'That runner could not be found anymore. Please refresh and try again.';
  }
  if (lower.contains('race entry not found')) {
    return 'That race entry could not be found anymore. Please refresh and try again.';
  }
  if (lower.contains('race distance config not found')) {
    return 'That distance option is no longer available. Please refresh and try again.';
  }
  if (lower == 'race not found.') {
    return 'That race could not be found. Please go back and choose it again.';
  }
  if (lower == 'finished races cannot be restarted.') {
    return 'This race has already been finished and cannot be started again.';
  }
  if (lower == 'only a running race can be ended.') {
    return 'Start the race before trying to end it.';
  }
  if (lower.contains('invalid printer payload')) {
    return 'The printer request could not be completed.';
  }

  return null;
}

bool _looksTechnical(String message) {
  final lower = message.toLowerCase();
  return lower.contains('null check') ||
      lower.contains('no such method') ||
      lower.contains('stack trace') ||
      lower.contains('type ') ||
      lower.contains('formatexception') ||
      lower.contains('missingpluginexception') ||
      lower.contains('platformexception') ||
      lower.contains('stateerror') ||
      lower.contains('fluttererror') ||
      lower.contains('sqflite') ||
      lower.contains('sqlite') ||
      lower.contains('pragma') ||
      lower.contains('constraint failed') ||
      lower.contains('channel-error') ||
      lower.contains('code=') ||
      lower.contains('dart:');
}
