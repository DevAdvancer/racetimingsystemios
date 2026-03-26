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

  if (cleaned.isEmpty || _looksTechnical(cleaned)) {
    return fallback;
  }

  return cleaned;
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
      lower.contains('dart:');
}
