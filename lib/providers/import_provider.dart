import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/models/import_result.dart';
import 'package:race_timer/providers/race_provider.dart';

final importProvider = AsyncNotifierProvider<ImportController, ImportResult>(
  ImportController.new,
);

class ImportController extends AsyncNotifier<ImportResult> {
  @override
  FutureOr<ImportResult> build() {
    return ImportResult.idle();
  }

  Future<ImportResult> importRoster() async {
    state = const AsyncLoading();

    try {
      final roster = await ref.read(importServiceProvider).pickRoster();
      if (roster == null) {
        final result = ImportResult.canceled();
        state = AsyncData(result);
        return result;
      }

      final result = await ref.read(raceServiceProvider).importRoster(roster);
      state = AsyncData(result);
      return result;
    } catch (error) {
      final result = ImportResult.failure(_messageForImportError(error));
      state = AsyncData(result);
      return result;
    }
  }

  void reset() {
    state = AsyncData(ImportResult.idle());
  }

  String _messageForImportError(Object error) {
    final rawMessage = switch (error) {
      FormatException() => error.message,
      UnsupportedError() => error.message ?? error.toString(),
      ArgumentError() =>
        'The file picker could not open this roster file. Please try again.',
      _ =>
        'The roster could not be imported. Please use a .xlsx or .csv file and try again.',
    };

    return rawMessage.replaceFirst('Unsupported operation: ', '');
  }
}
