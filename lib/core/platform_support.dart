import 'dart:io';

import 'package:flutter/widgets.dart';

class PlatformSupport {
  const PlatformSupport._();

  static Future<void> ensureInitialized() async {
    WidgetsFlutterBinding.ensureInitialized();
  }

  static bool get isIOS => Platform.isIOS;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isWindows => Platform.isWindows;

  static bool get usesFfiDatabase => isMacOS || isWindows;
  static bool get supportsStripePayments => isIOS;
  static bool get supportsNativeBrotherPrinting => isIOS;
  static bool get prefersSaveDialogForExport => isMacOS || isWindows;

  static String get platformLabel {
    if (isIOS) {
      return 'iPad / iPhone';
    }
    if (isMacOS) {
      return 'macOS';
    }
    if (isWindows) {
      return 'Windows';
    }
    return 'Unsupported';
  }
}
