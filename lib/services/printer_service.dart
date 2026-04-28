import 'package:flutter/services.dart';
import 'package:race_timer/core/platform_support.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/app_settings.dart';
import 'package:race_timer/models/discovered_printer.dart';
import 'package:race_timer/models/printer_status.dart';
import 'package:race_timer/services/barcode_service.dart';
import 'package:race_timer/services/settings_service.dart';

abstract class PrinterService {
  Future<PrinterStatus> configure();
  Future<List<DiscoveredPrinter>> discoverPrinters({
    required PrinterConnectionType connectionType,
  });
  Future<PrinterStatus> getStatus();
  Future<PrinterStatus> printLabel(LabelDocument document);
  Future<PrinterStatus> testPrint();
}

class MethodChannelPrinterService implements PrinterService {
  MethodChannelPrinterService(this._settingsService);

  static const MethodChannel _channel = MethodChannel('com.racetimer/printer');

  final SettingsService _settingsService;

  @override
  Future<PrinterStatus> configure() async {
    return getStatus();
  }

  @override
  Future<List<DiscoveredPrinter>> discoverPrinters({
    required PrinterConnectionType connectionType,
  }) async {
    if (!PlatformSupport.supportsNativeBrotherPrinting) {
      return const [];
    }

    try {
      final rawResult =
          await _channel.invokeMethod<List<Object?>>(
            'discoverPrinters',
            <String, Object?>{'connectionType': connectionType.storageValue},
          ) ??
          const <Object?>[];

      return rawResult
          .whereType<Map<Object?, Object?>>()
          .map(DiscoveredPrinter.fromMap)
          .toList(growable: false);
    } on PlatformException catch (error) {
      throw Exception(
        userFacingErrorMessage(
          error,
          fallback: 'The printer list could not be loaded right now.',
        ),
      );
    }
  }

  @override
  Future<PrinterStatus> getStatus() async {
    final settings = await _settingsService.loadSettings();
    if (!settings.hasPrinterConfigured) {
      return PrinterStatus.notConfigured(
        message:
            '${settings.printerConnectionType.targetFieldLabel} is not configured.',
      );
    }
    if (!PlatformSupport.supportsNativeBrotherPrinting) {
      return PrinterStatus.unsupported();
    }

    try {
      final result = await _invokeStatusMethod('getStatus', settings: settings);
      return PrinterStatus.fromMap(result);
    } on PlatformException catch (error) {
      return PrinterStatus.error(
        host: settings.printerHost,
        message: userFacingErrorMessage(
          error,
          fallback: 'The printer status could not be read right now.',
        ),
      );
    }
  }

  @override
  Future<PrinterStatus> printLabel(LabelDocument document) async {
    return _printDocument(
      document,
      successFallback: 'Brother label sent successfully.',
    );
  }

  @override
  Future<PrinterStatus> testPrint() async {
    return _printDocument(
      const LabelDocument(
        runnerName: 'Printer Test',
        barcodeValue: 'TEST-PRINT',
        raceId: 0,
        raceName: 'RaceTimerApp',
      ),
      methodName: 'testPrint',
      successFallback: 'Brother printer test label sent.',
    );
  }

  Future<PrinterStatus> _printDocument(
    LabelDocument document, {
    String methodName = 'printLabel',
    required String successFallback,
  }) async {
    final settings = await _settingsService.loadSettings();
    if (!settings.hasPrinterConfigured) {
      return PrinterStatus.notConfigured(
        message:
            'Runner saved, but ${settings.printerConnectionType.targetFieldLabel.toLowerCase()} is not configured.',
      );
    }
    if (!PlatformSupport.supportsNativeBrotherPrinting) {
      return PrinterStatus.unsupported(
        message: 'Runner saved. Reprint from an iPad with Brother support.',
      );
    }

    try {
      final result = await _invokeStatusMethod(
        methodName,
        settings: settings,
        extra: document.toMap(
          printerHost: settings.printerHost,
          printerMedia: settings.printerMedia,
        ),
      );
      final status = PrinterStatus.fromMap(result);
      if (status.message.trim().isEmpty && status.isReady) {
        return PrinterStatus.success(
          host: status.host,
          message: successFallback,
        );
      }
      return status;
    } on PlatformException catch (error) {
      return PrinterStatus.error(
        host: settings.printerHost,
        message: userFacingErrorMessage(
          error,
          fallback:
              'The Brother printer could not complete that request right now.',
        ),
      );
    }
  }

  Future<Map<Object?, Object?>> _invokeStatusMethod(
    String methodName, {
    required AppSettings settings,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    final payload = <String, Object?>{
      'printerHost': settings.printerHost,
      'printerMedia': settings.printerMedia,
      'connectionType': settings.printerConnectionType.storageValue,
      ...extra,
    };

    final result =
        await _channel.invokeMethod<Map<Object?, Object?>>(
          methodName,
          payload,
        ) ??
        const <Object?, Object?>{};
    return result;
  }
}
