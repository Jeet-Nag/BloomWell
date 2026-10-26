class WakeVerification {
  final String date; // yyyy-MM-dd
  final DateTime verifiedAt;
  final String method; // 'selfie'

  const WakeVerification({
    required this.date,
    required this.verifiedAt,
    this.method = 'selfie',
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'verifiedAt': verifiedAt.toIso8601String(),
      'method': method,
    };
  }

  factory WakeVerification.fromMap(Map<String, dynamic> map) {
    return WakeVerification(
      date: map['date'] as String,
      verifiedAt: DateTime.parse(map['verifiedAt'] as String),
      method: map['method'] as String? ?? 'selfie',
    );
  }
}
