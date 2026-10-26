import '../calculators/gps_tracker_calculator.dart';

class WalkSession {
  final int? id;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceMeters;
  final int durationSeconds; // Total elapsed session duration in seconds
  final int? activeDurationSeconds; // Active moving duration in seconds
  final double avgSpeedKmh; // Moving average speed (km/h)
  final double? elapsedAvgSpeedKmh; // Total elapsed average speed (km/h)
  final double estimatedCalories;
  final String? notes;

  const WalkSession({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.distanceMeters,
    required this.durationSeconds,
    this.activeDurationSeconds,
    required this.avgSpeedKmh,
    this.elapsedAvgSpeedKmh,
    required this.estimatedCalories,
    this.notes,
  });

  int get effectiveActiveDurationSeconds => activeDurationSeconds ?? durationSeconds;

  double get distanceKm => distanceMeters / 1000.0;

  String get distanceFormatted => GpsTrackerCalculator.formatDistance(distanceMeters);

  // Pace in min/km computed from active moving duration and distance
  String get paceFormatted {
    final pace = GpsTrackerCalculator.calculatePaceMinPerKm(
      distanceMeters: distanceMeters,
      activeMovingSeconds: effectiveActiveDurationSeconds,
      isMoving: true,
    );
    return GpsTrackerCalculator.formatPace(pace);
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'avgSpeedKmh': avgSpeedKmh,
      'estimatedCalories': estimatedCalories,
      'notes': notes,
    };
    if (activeDurationSeconds != null) {
      map['activeDurationSeconds'] = activeDurationSeconds;
    }
    if (elapsedAvgSpeedKmh != null) {
      map['elapsedAvgSpeedKmh'] = elapsedAvgSpeedKmh;
    }
    return map;
  }

  factory WalkSession.fromMap(Map<String, dynamic> map) {
    return WalkSession(
      id: map['id'] as int?,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: DateTime.parse(map['endTime'] as String),
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
      durationSeconds: map['durationSeconds'] as int,
      activeDurationSeconds: map['activeDurationSeconds'] as int?,
      avgSpeedKmh: (map['avgSpeedKmh'] as num).toDouble(),
      elapsedAvgSpeedKmh: (map['elapsedAvgSpeedKmh'] as num?)?.toDouble(),
      estimatedCalories: (map['estimatedCalories'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }
}
