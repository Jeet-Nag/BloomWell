class WeightEntry {
  final int? id;
  final double weightKg;
  final DateTime timestamp;
  final String? notes;

  const WeightEntry({
    this.id,
    required this.weightKg,
    required this.timestamp,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weightKg': weightKg,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
    };
  }

  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    return WeightEntry(
      id: map['id'] as int?,
      weightKg: (map['weightKg'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      notes: map['notes'] as String?,
    );
  }
}
