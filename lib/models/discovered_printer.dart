import 'package:race_timer/models/app_settings.dart';

class DiscoveredPrinter {
  const DiscoveredPrinter({
    required this.connectionType,
    required this.host,
    required this.modelName,
    required this.printerName,
  });

  final PrinterConnectionType connectionType;
  final String host;
  final String modelName;
  final String printerName;

  String get displayName => printerName.isNotEmpty ? printerName : modelName;

  factory DiscoveredPrinter.fromMap(Map<Object?, Object?> map) {
    return DiscoveredPrinter(
      connectionType: PrinterConnectionType.fromStorage(
        map['connectionType'] as String?,
      ),
      host: (map['host'] as String?) ?? '',
      modelName: (map['modelName'] as String?) ?? 'QL-820NWB',
      printerName: (map['printerName'] as String?) ?? '',
    );
  }
}
