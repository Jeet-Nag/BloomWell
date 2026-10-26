class WaterLog {
  final int? id;
  final int amountMl;
  final DateTime timestamp;
  final String? photoPath;
  final String? notes;
  final bool isPhotoVerified;

  const WaterLog({
    this.id,
    required this.amountMl,
    required this.timestamp,
    this.photoPath,
    this.notes,
    this.isPhotoVerified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amountMl': amountMl,
      'timestamp': timestamp.toIso8601String(),
      'photoPath': photoPath,
      'notes': notes,
      'isPhotoVerified': isPhotoVerified ? 1 : 0,
    };
  }

  factory WaterLog.fromMap(Map<String, dynamic> map) {
    return WaterLog(
      id: map['id'] as int?,
      amountMl: map['amountMl'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      photoPath: map['photoPath'] as String?,
      notes: map['notes'] as String?,
      isPhotoVerified: (map['isPhotoVerified'] as int? ?? 0) == 1,
    );
  }
}
