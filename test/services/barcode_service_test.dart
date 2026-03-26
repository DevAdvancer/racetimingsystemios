import 'package:flutter_test/flutter_test.dart';
import 'package:race_timer/services/barcode_service.dart';

void main() {
  group('BarcodeService', () {
    test('builds the expected reusable runner barcode value', () {
      const service = BarcodeService();

      expect(service.buildRunnerBarcode(87), 'RT-000087');
    });

    test('normalizes scanned barcode input for handheld scanners', () {
      const service = BarcodeService();

      expect(service.normalizeScannedBarcode('  rt-000087\r\n'), 'RT-000087');
    });
  });
}
