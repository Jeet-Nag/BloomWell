import '../calculators/gps_tracker_calculator.dart';

class DailyActivityLog {
  final String date; // YYYY-MM-DD
  final int steps;
  final int goal;
  final double distanceMeters;
  final int activeMinutes;
  final double estimatedCalories;
  final DateTime lastUpdatedAt;

  const DailyActivityLog({
    required this.date,
    required this.steps,
    this.goal = 6000,
    required this.distanceMeters,
    required this.activeMinutes,
    required this.estimatedCalories,
    required this.lastUpdatedAt,
  });

  double get progressPercent => goal > 0 ? (steps / goal).clamp(0.0, 1.0) : 0.0;

  bool get isGoalAchieved => steps >= goal;

  String get distanceFormatted => GpsTrackerCalculator.formatDistance(distanceMeters);

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'steps': steps,
      'goal': goal,
      'distanceMeters': distanceMeters,
      'activeMinutes': activeMinutes,
      'estimatedCalories': estimatedCalories,
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    };
  }

  factory DailyActivityLog.fromMap(Map<String, dynamic> map) {
    return DailyActivityLog(
      date: map['date'] as String,
      steps: map['steps'] as int? ?? 0,
      goal: map['goal'] as int? ?? 6000,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      activeMinutes: map['activeMinutes'] as int? ?? 0,
      estimatedCalories: (map['estimatedCalories'] as num?)?.toDouble() ?? 0.0,
      lastUpdatedAt: map['lastUpdatedAt'] != null
          ? DateTime.tryParse(map['lastUpdatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  DailyActivityLog copyWith({
    String? date,
    int? steps,
    int? goal,
    double? distanceMeters,
    int? activeMinutes,
    double? estimatedCalories,
    DateTime? lastUpdatedAt,
  }) {
    return DailyActivityLog(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      goal: goal ?? this.goal,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
