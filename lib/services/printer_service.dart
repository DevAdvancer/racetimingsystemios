import 'package:flutter/services.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/platform_support.dart';
import 'package:race_timer/models/printer_status.dart';
import 'package:race_timer/services/barcode_service.dart';
import 'package:race_timer/services/settings_service.dart';

abstract class PrinterService {
  Future<PrinterStatus> configure();
  Future<PrinterStatus> getStatus();
  Future<PrinterStatus> printLabel(LabelDocument document);
  Future<PrinterStatus> testPrint();
}

class MethodChannelPrinterService implements PrinterService {
  MethodChannelPrinterService(this._settingsService);

  final SettingsService _settingsService;
  final MethodChannel _channel = const MethodChannel(
    AppConstants.printerChannel,
  );

  @override
  Future<PrinterStatus> configure() async {
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
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'configure',
        <String, Object?>{
          'host': settings.printerHost,
          'media': settings.printerMedia,
          'connectionType': settings.printerConnectionType.storageValue,
        },
      );
      if (response == null) {
        return PrinterStatus.error(
          host: settings.printerHost,
          message: 'No printer response received.',
        );
      }
      return PrinterStatus.fromMap(response);
    } on PlatformException catch (error) {
      return PrinterStatus.error(
        host: settings.printerHost,
        message: error.message ?? 'Printer configuration failed.',
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
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'getStatus',
        <String, Object?>{
          'host': settings.printerHost,
          'media': settings.printerMedia,
          'connectionType': settings.printerConnectionType.storageValue,
        },
      );
      if (response == null) {
        return PrinterStatus.error(
          host: settings.printerHost,
          message: 'Unable to read printer status.',
        );
      }
      return PrinterStatus.fromMap(response);
    } on PlatformException catch (error) {
      return PrinterStatus.error(
        host: settings.printerHost,
        message: error.message ?? 'Printer status failed.',
      );
    }
  }

  @override
  Future<PrinterStatus> printLabel(LabelDocument document) async {
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
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'printLabel',
        document.toMap(
          printerHost: settings.printerHost,
          printerMedia: settings.printerMedia,
        )..['connectionType'] = settings.printerConnectionType.storageValue,
      );
      if (response == null) {
        return PrinterStatus.error(
          host: settings.printerHost,
          message: 'Printer did not acknowledge the label request.',
        );
      }
      return PrinterStatus.fromMap(response);
    } on PlatformException catch (error) {
      return PrinterStatus.error(
        host: settings.printerHost,
        message: error.message ?? 'Printing failed.',
      );
    }
  }

  @override
  Future<PrinterStatus> testPrint() async {
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
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'testPrint',
        <String, Object?>{
          'host': settings.printerHost,
          'media': settings.printerMedia,
          'connectionType': settings.printerConnectionType.storageValue,
        },
      );
      if (response == null) {
        return PrinterStatus.error(
          host: settings.printerHost,
          message: 'No test print response received.',
        );
      }
      return PrinterStatus.fromMap(response);
    } on PlatformException catch (error) {
      return PrinterStatus.error(
        host: settings.printerHost,
        message: error.message ?? 'Test print failed.',
      );
    }
  }
}
