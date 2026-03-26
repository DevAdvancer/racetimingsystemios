import 'package:race_timer/models/runner.dart';

class ImportedRunnerData {
  const ImportedRunnerData({
    required this.name,
    this.barcodeValue,
    this.paymentStatus,
    this.membershipStatus,
  });

  final String name;
  final String? barcodeValue;
  final PaymentStatus? paymentStatus;
  final MembershipStatus? membershipStatus;
}

class RosterImport {
  const RosterImport({
    required this.sourceName,
    required this.runners,
    this.invalidRowCount = 0,
  });

  final String sourceName;
  final List<ImportedRunnerData> runners;
  final int invalidRowCount;
}
