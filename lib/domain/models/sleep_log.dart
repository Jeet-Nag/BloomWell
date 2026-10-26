class SleepLog {
  final int? id;
  final DateTime bedtime;
  final DateTime wakeTime;
  final int durationMinutes;
  final String? notes;

  const SleepLog({
    this.id,
    required this.bedtime,
    required this.wakeTime,
    required this.durationMinutes,
    this.notes,
  });

  double get durationHours => durationMinutes / 60.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bedtime': bedtime.toIso8601String(),
      'wakeTime': wakeTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'notes': notes,
    };
  }

  factory SleepLog.fromMap(Map<String, dynamic> map) {
    return SleepLog(
      id: map['id'] as int?,
      bedtime: DateTime.parse(map['bedtime'] as String),
      wakeTime: DateTime.parse(map['wakeTime'] as String),
      durationMinutes: map['durationMinutes'] as int,
      notes: map['notes'] as String?,
    );
  }
}
