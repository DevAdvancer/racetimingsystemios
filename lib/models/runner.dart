enum PaymentStatus { pending, paid, waived, refunded }

extension PaymentStatusX on PaymentStatus {
  String get dbValue => switch (this) {
    PaymentStatus.pending => 'pending',
    PaymentStatus.paid => 'paid',
    PaymentStatus.waived => 'waived',
    PaymentStatus.refunded => 'refunded',
  };

  String get label => switch (this) {
    PaymentStatus.pending => 'Pending',
    PaymentStatus.paid => 'Paid',
    PaymentStatus.waived => 'Waived',
    PaymentStatus.refunded => 'Refunded',
  };

  bool get countsAsPaid =>
      this == PaymentStatus.paid || this == PaymentStatus.waived;

  static PaymentStatus fromDb(String? value, {Object? legacyPaid}) {
    return switch (value?.trim().toLowerCase()) {
      'pending' => PaymentStatus.pending,
      'paid' => PaymentStatus.paid,
      'waived' => PaymentStatus.waived,
      'refunded' => PaymentStatus.refunded,
      _ => _fromLegacyPaid(legacyPaid),
    };
  }

  static PaymentStatus _fromLegacyPaid(Object? value) {
    final isPaid = switch (value) {
      int() => value == 1,
      bool() => value,
      _ => true,
    };
    return isPaid ? PaymentStatus.paid : PaymentStatus.pending;
  }
}

enum MembershipStatus { unknown, member, nonMember, expired }

extension MembershipStatusX on MembershipStatus {
  String get dbValue => switch (this) {
    MembershipStatus.unknown => 'unknown',
    MembershipStatus.member => 'member',
    MembershipStatus.nonMember => 'non_member',
    MembershipStatus.expired => 'expired',
  };

  String get label => switch (this) {
    MembershipStatus.unknown => 'Unknown',
    MembershipStatus.member => 'Member',
    MembershipStatus.nonMember => 'Non-member',
    MembershipStatus.expired => 'Expired',
  };

  static MembershipStatus fromDb(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'member' => MembershipStatus.member,
      'non_member' => MembershipStatus.nonMember,
      'expired' => MembershipStatus.expired,
      _ => MembershipStatus.unknown,
    };
  }
}

class Runner {
  const Runner({
    required this.id,
    required this.name,
    required this.barcodeValue,
    required this.stripePaymentId,
    required this.paymentStatus,
    required this.membershipStatus,
    required this.createdAt,
    this.city,
    this.gender,
  });

  final int id;
  final String name;
  final String barcodeValue;
  final String? stripePaymentId;
  final PaymentStatus paymentStatus;
  final MembershipStatus membershipStatus;
  final DateTime createdAt;
  final String? city;
  final String? gender;

  bool get paid => paymentStatus.countsAsPaid;

  Runner copyWith({
    int? id,
    String? name,
    String? barcodeValue,
    String? stripePaymentId,
    PaymentStatus? paymentStatus,
    MembershipStatus? membershipStatus,
    DateTime? createdAt,
    String? city,
    bool clearCity = false,
    String? gender,
    bool clearGender = false,
  }) {
    return Runner(
      id: id ?? this.id,
      name: name ?? this.name,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      stripePaymentId: stripePaymentId ?? this.stripePaymentId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      createdAt: createdAt ?? this.createdAt,
      city: clearCity ? null : city ?? this.city,
      gender: clearGender ? null : gender ?? this.gender,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'barcode_value': barcodeValue,
      'stripe_payment_id': stripePaymentId,
      'paid': paid ? 1 : 0,
      'payment_status': paymentStatus.dbValue,
      'membership_status': membershipStatus.dbValue,
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      'city': city,
      'gender': gender,
    };
  }

  factory Runner.fromMap(Map<String, Object?> map) {
    return Runner(
      id: map['id'] as int,
      name: map['name'] as String,
      barcodeValue: (map['barcode_value'] as String?) ?? '',
      stripePaymentId: map['stripe_payment_id'] as String?,
      paymentStatus: PaymentStatusX.fromDb(
        map['payment_status'] as String?,
        legacyPaid: map['paid'],
      ),
      membershipStatus: MembershipStatusX.fromDb(
        map['membership_status'] as String?,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
        isUtc: true,
      ),
      city: map['city'] as String?,
      gender: map['gender'] as String?,
    );
  }
}
