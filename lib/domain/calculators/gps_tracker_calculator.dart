import 'dart:math' as math;

class GpsPoint {
  final double latitude;
  final double longitude;
  final double accuracy; // meters
  final DateTime timestamp;
  final double? speed; // m/s from hardware if available

  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.speed,
  });

  @override
  String toString() =>
      'GpsPoint(lat: $latitude, lon: $longitude, acc: ${accuracy.toStringAsFixed(1)}m, t: $timestamp, spd: $speed)';
}

class FilteredTrackResult {
  final double totalDistanceMeters;
  final int validPointsCount;
  final int rejectedPointsCount;
  final int stationaryFilteredCount;

  const FilteredTrackResult({
    required this.totalDistanceMeters,
    required this.validPointsCount,
    required this.rejectedPointsCount,
    required this.stationaryFilteredCount,
  });
}

class GpsTrackerCalculator {
  /// Earth's mean radius in meters
  static const double _earthRadiusMeters = 6371000.0;

  /// Maximum acceptable GPS horizontal accuracy in meters.
  /// Points with uncertainty worse than 15m are classified as weak GPS and rejected
  /// from distance accumulation to eliminate indoor multipath and ceiling drift.
  static const double maxAcceptableAccuracyMeters = 15.0;

  /// Maximum realistic human walking/jogging speed in km/h to filter out GPS teleports/jumps.
  static const double maxRealisticSpeedKmh = 12.0;

  /// Minimum speed required to consider human movement (km/h).
  /// Normal walking is ~3.0 - 5.5 km/h. Anything below 1.4 km/h with tiny displacement is jitter.
  static const double minMovingSpeedKmh = 1.4;

  /// Maximum realistic human walking speed for pedestrian tracker (km/h).
  /// Exceeding this from a stationary anchor is an indoor multipath jump or vehicle jump.
  static const double maxWalkingSpeedKmh = 8.5;

  /// Speed threshold below which movement drops back to stationary (km/h) for hysteresis.
  static const double stopMovingSpeedKmh = 1.0;

  /// Minimum displacement required from anchor to register genuine movement (meters).
  static const double minMovementDistanceMeters = 6.0;

  /// Maximum allowable age for a GPS point to prevent using stale cached fixes (seconds).
  static const int maxStaleSeconds = 15;

  /// Calculate distance between two lat/long points using Haversine formula in meters.
  static double haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180.0);

  /// Validates a single GPS point against coordinate boundaries, accuracy, and staleness.
  static bool isValidPoint(
    GpsPoint point, {
    DateTime? referenceTime,
    double maxAccuracy = maxAcceptableAccuracyMeters,
  }) {
    if (point.latitude < -90.0 || point.latitude > 90.0) return false;
    if (point.longitude < -180.0 || point.longitude > 180.0) return false;
    if (point.accuracy <= 0.0 || point.accuracy > maxAccuracy) return false;

    if (referenceTime != null) {
      final diff = referenceTime.difference(point.timestamp).inSeconds;
      if (diff < -5 || diff > maxStaleSeconds) return false;
    }

    return true;
  }

  /// Filters noise and calculates total distance from a series of GPS points.
  /// Uses a hysteresis state machine to reject stationary drift and jump glitches.
  static FilteredTrackResult processTrack(List<GpsPoint> points) {
    if (points.length < 2) {
      return FilteredTrackResult(
        totalDistanceMeters: 0.0,
        validPointsCount: points.length,
        rejectedPointsCount: 0,
        stationaryFilteredCount: 0,
      );
    }

    double totalDistance = 0.0;
    int rejected = 0;
    int stationaryFiltered = 0;
    int valid = 0;

    GpsPoint? lastConfirmedPoint;
    GpsPoint? anchorPoint;
    GpsPoint? lastMovingCandidatePoint;
    bool isMoving = false;
    int consecutiveMovingCandidates = 0;

    for (final p in points) {
      // 1. Quality validation
      if (!isValidPoint(p)) {
        rejected++;
        continue;
      }

      valid++;

      if (lastConfirmedPoint == null) {
        lastConfirmedPoint = p;
        anchorPoint = p;
        continue;
      }

      final distFromLast = haversineDistanceMeters(
        lastConfirmedPoint.latitude,
        lastConfirmedPoint.longitude,
        p.latitude,
        p.longitude,
      );

      final dtSeconds = p.timestamp.difference(lastConfirmedPoint.timestamp).inSeconds;
      if (dtSeconds <= 0) {
        rejected++;
        continue;
      }

      final derivedSpeedKmh = (distFromLast / dtSeconds) * 3.6;

      // 2. Teleport / implausible jump rejection
      if (derivedSpeedKmh > maxRealisticSpeedKmh) {
        rejected++;
        continue;
      }

      // 3. Stationary drift detection with hysteresis
      final deviceSpeedKmh = (p.speed != null && p.speed! >= 0) ? (p.speed! * 3.6) : null;

      if (!isMoving) {
        final distFromAnchor = haversineDistanceMeters(
          anchorPoint!.latitude,
          anchorPoint.longitude,
          p.latitude,
          p.longitude,
        );
        final dtAnchor = p.timestamp.difference(anchorPoint.timestamp).inSeconds;
        final anchorSpeedKmh = dtAnchor > 0 ? (distFromAnchor / dtAnchor) * 3.6 : 0.0;

        final bool meetsDisplacement = distFromAnchor >=
            math.max(minMovementDistanceMeters, p.accuracy * 0.8);
        final bool meetsWalkingSpeed = anchorSpeedKmh >= minMovingSpeedKmh &&
            anchorSpeedKmh <= maxWalkingSpeedKmh;
        final bool notDopplerStationary = deviceSpeedKmh == null || deviceSpeedKmh >= 0.8;

        if (meetsDisplacement && meetsWalkingSpeed && notDopplerStationary) {
          consecutiveMovingCandidates++;
          if (consecutiveMovingCandidates == 1) {
            lastMovingCandidatePoint = p;
          } else if (consecutiveMovingCandidates >= 2) {
            // Confirmed start of movement!
            // Add step distance from moving candidates
            isMoving = true;
            final stepDist = lastMovingCandidatePoint != null
                ? haversineDistanceMeters(
                    lastMovingCandidatePoint.latitude,
                    lastMovingCandidatePoint.longitude,
                    p.latitude,
                    p.longitude,
                  )
                : distFromLast;
            totalDistance += math.min(stepDist + 4.0, distFromAnchor);
            lastConfirmedPoint = p;
            anchorPoint = p;
            consecutiveMovingCandidates = 0;
            lastMovingCandidatePoint = null;
          }
        } else {
          // Stationary jitter around anchor — do NOT accumulate distance!
          consecutiveMovingCandidates = 0;
          lastMovingCandidatePoint = null;
          stationaryFiltered++;
          if (distFromAnchor < 2.5) {
            // Continuously track tiny jitter centroid so stationary drift does not snap
            anchorPoint = p;
          }
        }
      } else {
        // Currently moving
        final bool slowDerived = derivedSpeedKmh < stopMovingSpeedKmh && distFromLast < 2.0;
        final bool slowDevice = deviceSpeedKmh != null && deviceSpeedKmh < stopMovingSpeedKmh && distFromLast < 2.0;

        if (slowDerived || slowDevice) {
          // User slowed down / stopped
          isMoving = false;
          anchorPoint = p;
          lastConfirmedPoint = p;
          stationaryFiltered++;
        } else {
          totalDistance += distFromLast;
          lastConfirmedPoint = p;
        }
      }
    }

    return FilteredTrackResult(
      totalDistanceMeters: totalDistance,
      validPointsCount: valid,
      rejectedPointsCount: rejected,
      stationaryFilteredCount: stationaryFiltered,
    );
  }

  /// Legacy helper method that returns just the filtered total distance in meters.
  static double calculateTotalDistanceMeters(List<GpsPoint> points) {
    return processTrack(points).totalDistanceMeters;
  }

  /// Calculates moving average speed in km/h based on valid distance and active moving seconds.
  static double calculateAvgSpeedKmh(double distanceMeters, int activeMovingSeconds) {
    if (activeMovingSeconds < 5 || distanceMeters < 10) return 0.0;
    return (distanceMeters / activeMovingSeconds) * 3.6;
  }

  /// Calculates elapsed average speed in km/h based on valid distance and total elapsed seconds.
  static double calculateElapsedAvgSpeedKmh(double distanceMeters, int totalElapsedSeconds) {
    if (totalElapsedSeconds < 5 || distanceMeters < 10) return 0.0;
    return (distanceMeters / totalElapsedSeconds) * 3.6;
  }

  /// Calculates pace in minutes per kilometer.
  /// Returns null if stationary, not moving, or distance is too small to yield a reliable pace.
  static double? calculatePaceMinPerKm({
    required double distanceMeters,
    required int activeMovingSeconds,
    bool isMoving = true,
  }) {
    if (!isMoving || distanceMeters < 20 || activeMovingSeconds < 10) return null;
    final km = distanceMeters / 1000.0;
    final minutes = activeMovingSeconds / 60.0;
    final pace = minutes / km;

    // A pace slower than 30 min/km corresponds to < 2.0 km/h, which is stationary or paused
    if (pace > 30.0) return null;
    return pace;
  }

  /// Formats pace into `M:SS min/km` or `--:-- min/km` if null/stationary.
  static String formatPace(double? paceMinPerKm) {
    if (paceMinPerKm == null || paceMinPerKm.isNaN || paceMinPerKm.isInfinite) {
      return '--:-- min/km';
    }
    final int minutes = paceMinPerKm.floor();
    final int seconds = ((paceMinPerKm - minutes) * 60).round().clamp(0, 59);
    return '$minutes:${seconds.toString().padLeft(2, '0')} min/km';
  }

  /// Formats distance dynamically:
  /// - Below 1,000 meters: whole meters (e.g. `140 m`)
  /// - At or above 1,000 meters: kilometers with 2 decimals (e.g. `1.02 km`)
  static String formatDistance(double meters) {
    if (meters < 1000.0) {
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(2)} km';
  }

  /// Value part for large HUD displays (e.g. `140` or `1.02`)
  static String formatDistanceValue(double meters) {
    if (meters < 1000.0) {
      return '${meters.round()}';
    }
    final km = meters / 1000.0;
    return km.toStringAsFixed(2);
  }

  /// Unit part for large HUD displays (e.g. `METERS` or `KILOMETERS`)
  static String formatDistanceUnit(double meters) {
    if (meters < 1000.0) {
      return 'METERS';
    }
    return 'KILOMETERS';
  }

  /// Estimates energy expenditure (kcal) using standard metabolic equivalent of task (MET).
  ///
  /// CRITICAL HONESTY RULE:
  /// Must be computed exclusively from [activeMovingSeconds] and [movingAvgSpeedKmh].
  /// Sitting still or stationary periods MUST NOT inflate calories.
  ///
  /// Formula: kcal = MET * weightKg * (activeMovingHours)
  /// Always labelled clearly as an estimate.
  static double estimateCaloriesBurned({
    required double weightKg,
    required int activeMovingSeconds,
    required double avgSpeedKmh,
  }) {
    if (activeMovingSeconds < 10 || avgSpeedKmh < 1.0) return 0.0;

    double met = 3.5; // Standard brisk walk
    if (avgSpeedKmh > 7.5) {
      met = 7.5; // Jogging/Running
    } else if (avgSpeedKmh > 5.5) {
      met = 4.3; // Fast walk
    } else if (avgSpeedKmh >= 3.0) {
      met = 3.5; // Moderate walk
    } else {
      met = 2.8; // Gentle stroll
    }

    final double hours = activeMovingSeconds / 3600.0;
    return (met * weightKg * hours).clamp(0.0, 2000.0);
  }
}
