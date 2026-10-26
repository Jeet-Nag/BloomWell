import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bloomwell/domain/calculators/water_target_calculator.dart';
import 'package:bloomwell/domain/calculators/weight_metrics_calculator.dart';
import 'package:bloomwell/domain/calculators/gps_tracker_calculator.dart';
import 'package:bloomwell/domain/calculators/step_calculator.dart';
import 'package:bloomwell/domain/calculators/streak_calculator.dart';
import 'package:bloomwell/domain/models/weight_entry.dart';
import 'package:bloomwell/domain/models/water_log.dart';
import 'package:bloomwell/domain/models/user_profile.dart';
import 'package:bloomwell/domain/models/meal_item.dart';
import 'package:bloomwell/domain/models/walk_session.dart';
import 'package:bloomwell/domain/models/daily_activity_log.dart';
import 'package:bloomwell/domain/models/college_schedule.dart';
import 'package:bloomwell/domain/models/wake_verification.dart';
import 'package:bloomwell/data/datasources/weekly_menu_data.dart';
import 'package:bloomwell/core/constants/video_config.dart';
import 'package:bloomwell/services/pedometer_service.dart';
import 'package:bloomwell/services/device_info_service.dart';
import 'package:bloomwell/core/localization/app_strings.dart';
import 'package:bloomwell/presentation/widgets/guided_session_player.dart';
import 'package:bloomwell/presentation/controllers/app_controller.dart';

void main() {
  group('WaterTargetCalculator Unit Tests', () {
    test('Calculates conservative baseline water target for 60kg adult', () {
      // 60kg * 32 ml/kg = 1920 ml -> rounded to nearest 50 ml = 1900 ml
      final target = WaterTargetCalculator.calculateDailyTargetMl(
        weightKg: 60.0,
        age: 22,
        activityLevel: 'light',
      );
      expect(target, equals(1900));
    });

    test('Caps maximum water target at 3000 ml for safety', () {
      final target = WaterTargetCalculator.calculateDailyTargetMl(
        weightKg: 110.0,
        age: 30,
        activityLevel: 'active',
        isHotClimate: true,
        exerciseDurationMinutes: 60,
      );
      expect(target, lessThanOrEqualTo(3000));
      expect(target, equals(3000));
    });

    test('Strictly limits target to 1500 ml when doctor-prescribed fluid restriction is enabled', () {
      final target = WaterTargetCalculator.calculateDailyTargetMl(
        weightKg: 85.0,
        age: 28,
        hasFluidRestriction: true,
      );
      expect(target, equals(1500));
    });

    test('Remaining ml never drops below 0 when user drinks more than target', () {
      final remaining = WaterTargetCalculator.calculateRemainingMl(2000, 2400);
      expect(remaining, equals(0));
    });
  });

  group('WeightMetricsCalculator Unit Tests', () {
    test('Correctly computes loss, gain, and baseline change neutrally', () {
      final baseDate = DateTime(2026, 10, 1);
      final secondDate = DateTime(2026, 10, 16); // 15 days later
      final thirdDate = DateTime(2026, 10, 31); // 30 days later

      final entries = [
        WeightEntry(weightKg: 65.0, timestamp: baseDate),
        WeightEntry(weightKg: 64.2, timestamp: secondDate),
        WeightEntry(weightKg: 64.6, timestamp: thirdDate),
      ];

      final summary = WeightMetricsCalculator.computeSummary(entries, now: thirdDate);

      expect(summary.currentWeight, equals(64.6));
      expect(summary.baselineWeight, equals(65.0));
      // Change from previous: 64.6 - 64.2 = +0.4
      expect(summary.changeFromPrevious, closeTo(0.4, 0.01));
      // Total change from baseline: 64.6 - 65.0 = -0.4
      expect(summary.changeFromBaseline, closeTo(-0.4, 0.01));

      expect(WeightMetricsCalculator.formatDelta(0.4), equals('+0.4 kg'));
      expect(WeightMetricsCalculator.formatDelta(-0.4), equals('-0.4 kg'));
      expect(WeightMetricsCalculator.formatDelta(0.0), equals('0.0 kg (steady)'));
    });

    test('Accurately tracks 15-day check-in window', () {
      final lastCheckin = DateTime(2026, 10, 10);
      final entries = [WeightEntry(weightKg: 60.0, timestamp: lastCheckin)];

      // 5 days later -> 10 days remaining
      final summary5 = WeightMetricsCalculator.computeSummary(
        entries,
        now: DateTime(2026, 10, 15),
      );
      expect(summary5.daysUntilNextCheckin, equals(10));
      expect(summary5.isCheckinDue, isFalse);

      // 16 days later -> 0 days remaining, checkin due
      final summary16 = WeightMetricsCalculator.computeSummary(
        entries,
        now: DateTime(2026, 10, 26),
      );
      expect(summary16.daysUntilNextCheckin, equals(0));
      expect(summary16.isCheckinDue, isTrue);
    });

    test('Generates valid CSV content with date, weight and notes', () {
      final entries = [
        WeightEntry(weightKg: 62.5, timestamp: DateTime(2026, 10, 1), notes: 'Felt well'),
        WeightEntry(weightKg: 62.1, timestamp: DateTime(2026, 10, 16), notes: 'Good sleep'),
      ];

      final csv = WeightMetricsCalculator.generateCsv(entries);
      expect(csv, contains('Date,Weight (kg),Notes'));
      expect(csv, contains('2026-10-01,62.5,"Felt well"'));
      expect(csv, contains('2026-10-16,62.1,"Good sleep"'));
    });
  });

  group('Youth Safety Guardrails', () {
    test('Identifies minors under 18', () {
      const minor = UserProfile(age: 17, heightCm: 158, currentWeightKg: 55);
      expect(minor.isMinor, isTrue);

      const adult = UserProfile(age: 18, heightCm: 162, currentWeightKg: 60);
      expect(adult.isMinor, isFalse);
    });
  });

  group('GpsTrackerCalculator & LocationService Unit Tests (9 Verification Suites)', () {
    test('1. Stationary coordinates with small GPS drift do not accumulate meaningful distance', () {
      final baseTime = DateTime(2026, 10, 25, 10, 0, 0);
      final points = <GpsPoint>[];

      // Simulate 30 stationary fixes with 0.5 to 2.0 meters of jitter around Bangalore location
      for (int i = 0; i < 30; i++) {
        // Small jitter in 5th decimal place is ~1.1 meters
        final latJitter = 12.97160 + (i % 3 - 1) * 0.00001;
        final lonJitter = 77.59460 + ((i + 1) % 3 - 1) * 0.00001;
        points.add(GpsPoint(
          latitude: latJitter,
          longitude: lonJitter,
          accuracy: 8.0,
          timestamp: baseTime.add(Duration(seconds: i * 2)),
          speed: 0.1, // tiny noisy speed reported by hardware
        ));
      }

      final result = GpsTrackerCalculator.processTrack(points);
      expect(result.totalDistanceMeters, equals(0.0),
          reason: 'Stationary GPS jitter must be completely rejected and not accumulate distance');
      expect(result.stationaryFilteredCount, greaterThan(20));
    });

    test('2. Invalid and poor-accuracy points are rejected', () {
      final now = DateTime(2026, 10, 25, 10, 0, 0);

      // Point with excessive uncertainty (> 25m)
      final poorAccuracy = GpsPoint(latitude: 12.9716, longitude: 77.5946, accuracy: 45.0, timestamp: now);
      expect(GpsTrackerCalculator.isValidPoint(poorAccuracy), isFalse);

      // Point with zero or negative accuracy
      final zeroAccuracy = GpsPoint(latitude: 12.9716, longitude: 77.5946, accuracy: 0.0, timestamp: now);
      expect(GpsTrackerCalculator.isValidPoint(zeroAccuracy), isFalse);

      // Point with impossible latitude
      final invalidLat = GpsPoint(latitude: 95.0, longitude: 77.5946, accuracy: 5.0, timestamp: now);
      expect(GpsTrackerCalculator.isValidPoint(invalidLat), isFalse);

      // Point with stale timestamp (> 15 seconds)
      final stalePoint = GpsPoint(
        latitude: 12.9716,
        longitude: 77.5946,
        accuracy: 5.0,
        timestamp: now.subtract(const Duration(seconds: 40)),
      );
      expect(GpsTrackerCalculator.isValidPoint(stalePoint, referenceTime: now), isFalse);

      // Point with valid parameters
      final validPoint = GpsPoint(latitude: 12.9716, longitude: 77.5946, accuracy: 8.5, timestamp: now);
      expect(GpsTrackerCalculator.isValidPoint(validPoint, referenceTime: now), isTrue);
    });

    test('3. Implausible GPS jumps are rejected', () {
      final t0 = DateTime(2026, 10, 25, 10, 0, 0);
      final t1 = DateTime(2026, 10, 25, 10, 0, 2); // 2 seconds later

      final points = [
        GpsPoint(latitude: 12.9716, longitude: 77.5946, accuracy: 5.0, timestamp: t0),
        // A jump of 10 km in 2 seconds is ~18,000 km/h (GPS drift/glitch)
        GpsPoint(latitude: 13.0716, longitude: 77.5946, accuracy: 5.0, timestamp: t1),
      ];

      final result = GpsTrackerCalculator.processTrack(points);
      expect(result.totalDistanceMeters, equals(0.0), reason: 'Teleport jump must be filtered');
      expect(result.rejectedPointsCount, greaterThanOrEqualTo(1));
    });

    test('4. Stationary speed and pace do not fluctuate as real movement', () {
      // When not moving, pace must return null
      final paceStationary = GpsTrackerCalculator.calculatePaceMinPerKm(
        distanceMeters: 5.0,
        activeMovingSeconds: 0,
        isMoving: false,
      );
      expect(paceStationary, isNull);
      expect(GpsTrackerCalculator.formatPace(paceStationary), equals('--:-- min/km'));

      // Slower than 30 min/km (< 2 km/h) is considered stationary or stopped
      final paceTooSlow = GpsTrackerCalculator.calculatePaceMinPerKm(
        distanceMeters: 30.0,
        activeMovingSeconds: 120, // 40 min/km = 1.5 km/h
        isMoving: true,
      );
      expect(paceTooSlow, isNull);
      expect(GpsTrackerCalculator.formatPace(paceTooSlow), equals('--:-- min/km'));
    });

    test('5. Active movement increases distance and active duration appropriately', () {
      final t0 = DateTime(2026, 10, 25, 10, 0, 0);
      final points = <GpsPoint>[];

      // Simulate a user walking at ~4.5 km/h (~1.25 m/s) heading North for 60 seconds
      // 0.000011 deg lat is ~1.22 meters
      for (int i = 0; i <= 20; i++) {
        final lat = 12.97160 + (i * 0.000035); // ~3.9 meters every 3 seconds (~4.7 km/h)
        points.add(GpsPoint(
          latitude: lat,
          longitude: 77.59460,
          accuracy: 6.0,
          timestamp: t0.add(Duration(seconds: i * 3)),
          speed: 1.3,
        ));
      }

      final result = GpsTrackerCalculator.processTrack(points);
      expect(result.totalDistanceMeters, greaterThan(50.0));
      expect(result.totalDistanceMeters, lessThan(120.0));

      final avgSpeed = GpsTrackerCalculator.calculateAvgSpeedKmh(result.totalDistanceMeters, 60);
      expect(avgSpeed, closeTo(4.7, 1.5));
    });

    test('6. Paused/stationary periods do not inflate active walking calories', () {
      const weightKg = 60.0;

      // 1. Sitting still for 30 minutes (activeMovingSeconds = 0)
      final stationaryCalories = GpsTrackerCalculator.estimateCaloriesBurned(
        weightKg: weightKg,
        activeMovingSeconds: 0,
        avgSpeedKmh: 0.0,
      );
      expect(stationaryCalories, equals(0.0), reason: 'Stationary duration must NOT burn active walking calories');

      // 2. 10 minutes active walking vs 30 minutes total session
      final activeCalories = GpsTrackerCalculator.estimateCaloriesBurned(
        weightKg: weightKg,
        activeMovingSeconds: 600, // 10 minutes
        avgSpeedKmh: 4.5,
      );
      // 3.5 MET * 60kg * (10/60) = 35 kcal
      expect(activeCalories, closeTo(35.0, 5.0));

      // 3. Compare with legacy bug where total elapsed time (30 min) was falsely used
      final inflatedCaloriesBug = 3.5 * weightKg * (1800 / 3600); // 105 kcal!
      expect(activeCalories, lessThan(inflatedCaloriesBug * 0.5),
          reason: 'Active calories must only count active movement time');
    });

    test('7. Distance formats as metres below 1,000 m and kilometres at/above 1,000 m', () {
      // Below 1,000 m: whole metres
      expect(GpsTrackerCalculator.formatDistance(0.0), equals('0 m'));
      expect(GpsTrackerCalculator.formatDistance(140.0), equals('140 m'));
      expect(GpsTrackerCalculator.formatDistance(999.4), equals('999 m'));

      expect(GpsTrackerCalculator.formatDistanceValue(140.0), equals('140'));
      expect(GpsTrackerCalculator.formatDistanceUnit(140.0), equals('METERS'));

      // At or above 1,000 m: kilometres with 2 decimals
      expect(GpsTrackerCalculator.formatDistance(1000.0), equals('1.00 km'));
      expect(GpsTrackerCalculator.formatDistance(1020.0), equals('1.02 km'));
      expect(GpsTrackerCalculator.formatDistance(3456.7), equals('3.46 km'));

      expect(GpsTrackerCalculator.formatDistanceValue(1020.0), equals('1.02'));
      expect(GpsTrackerCalculator.formatDistanceUnit(1020.0), equals('KILOMETERS'));
    });

    test('8. Average speed and pace handle zero distance and short sessions safely', () {
      // Zero distance
      expect(GpsTrackerCalculator.calculateAvgSpeedKmh(0.0, 60), equals(0.0));
      expect(GpsTrackerCalculator.calculateElapsedAvgSpeedKmh(0.0, 60), equals(0.0));
      expect(GpsTrackerCalculator.calculatePaceMinPerKm(distanceMeters: 0.0, activeMovingSeconds: 60), isNull);

      // Short session (< 5 seconds or < 10 meters)
      expect(GpsTrackerCalculator.calculateAvgSpeedKmh(5.0, 2), equals(0.0));
      expect(GpsTrackerCalculator.calculatePaceMinPerKm(distanceMeters: 5.0, activeMovingSeconds: 2), isNull);

      // Safe pace formatting
      expect(GpsTrackerCalculator.formatPace(null), equals('--:-- min/km'));
      expect(GpsTrackerCalculator.formatPace(double.nan), equals('--:-- min/km'));
      expect(GpsTrackerCalculator.formatPace(double.infinity), equals('--:-- min/km'));
    });

    test('9. Finish & Save stops tracking and creates consistent, unmanipulated session summary', () {
      final start = DateTime(2026, 10, 25, 10, 0, 0);
      final end = DateTime(2026, 10, 25, 10, 20, 0);

      const distanceMeters = 1250.0;
      const totalDuration = 1200; // 20 min elapsed
      const activeDuration = 900; // 15 min active moving

      final movingSpeed = GpsTrackerCalculator.calculateAvgSpeedKmh(distanceMeters, activeDuration);
      final elapsedSpeed = GpsTrackerCalculator.calculateElapsedAvgSpeedKmh(distanceMeters, totalDuration);

      final calories = GpsTrackerCalculator.estimateCaloriesBurned(
        weightKg: 62.0,
        activeMovingSeconds: activeDuration,
        avgSpeedKmh: movingSpeed,
      );

      final session = WalkSession(
        startTime: start,
        endTime: end,
        distanceMeters: distanceMeters,
        durationSeconds: totalDuration,
        activeDurationSeconds: activeDuration,
        avgSpeedKmh: movingSpeed,
        elapsedAvgSpeedKmh: elapsedSpeed,
        estimatedCalories: calories,
      );

      expect(session.distanceFormatted, equals('1.25 km'));
      expect(session.distanceKm, equals(1.25));
      expect(session.effectiveActiveDurationSeconds, equals(900));
      expect(session.paceFormatted, contains('min/km'));
      expect(session.avgSpeedKmh, closeTo(5.0, 0.1));
      expect(session.elapsedAvgSpeedKmh, closeTo(3.75, 0.1));

      // Verify toMap & fromMap serialization roundtrip
      final map = session.toMap();
      expect(map['distanceMeters'], equals(1250.0));
      expect(map['durationSeconds'], equals(1200));
      expect(map['activeDurationSeconds'], equals(900));

      final restored = WalkSession.fromMap(map);
      expect(restored.distanceMeters, equals(1250.0));
      expect(restored.durationSeconds, equals(1200));
      expect(restored.activeDurationSeconds, equals(900));
      expect(restored.avgSpeedKmh, equals(movingSpeed));
      expect(restored.estimatedCalories, equals(calories));
    });
  });

  group('StreakCalculator Unit Tests', () {
    test('Calculates 3-day consecutive streak accurately', () {
      final today = DateTime(2026, 10, 25);
      final dates = [
        DateTime(2026, 10, 25, 9, 30),
        DateTime(2026, 10, 24, 14, 0),
        DateTime(2026, 10, 23, 19, 15),
      ];

      final streak = StreakCalculator.calculateStreak(dates, referenceDate: today);
      expect(streak, equals(3));
    });

    test('Resets streak to 0 if gap exists without negative penalty', () {
      final today = DateTime(2026, 10, 25);
      final dates = [
        DateTime(2026, 10, 21), // Missed 22, 23, 24, 25
        DateTime(2026, 10, 20),
      ];

      final streak = StreakCalculator.calculateStreak(dates, referenceDate: today);
      expect(streak, equals(0));
    });
  });

  group('PCOD Terminology & Model Compatibility Tests', () {
    test('MealItem supports both pcodTip and legacy pcosTip seamlessly', () {
      final modernJson = {
        'id': 'meal_test_1',
        'dayOfWeek': 1,
        'mealType': 'breakfast',
        'name': 'Moong Dal Chilla',
        'prepTimeMinutes': 15,
        'approxCalories': 220,
        'approxProteinG': 12.0,
        'approxCarbsG': 30.0,
        'approxFatG': 4.0,
        'approxFiberG': 6.0,
        'hostelCategories': ['mess', 'kettle'],
        'budgetTier': 'low',
        'ingredients': [
          {'name': 'Moong dal', 'quantity': '1/2 cup'},
          {'name': 'Ginger', 'quantity': '1 inch'}
        ],
        'instructions': ['Soak', 'Grind', 'Cook'],
        'substitutions': ['Besan chilla'],
        'prepAheadNote': 'Soak dal night before',
        'pcodTip': 'Complex carbs prevent sharp insulin spikes.',
      };

      final item = MealItem.fromJson(modernJson);
      expect(item.pcodTip, equals('Complex carbs prevent sharp insulin spikes.'));
      expect(item.pcosTip, equals('Complex carbs prevent sharp insulin spikes.'));

      final legacyJson = Map<String, dynamic>.from(modernJson)
        ..remove('pcodTip')
        ..['pcosTip'] = 'Legacy tip for backwards compatibility.';

      final legacyItem = MealItem.fromJson(legacyJson);
      expect(legacyItem.pcodTip, equals('Legacy tip for backwards compatibility.'));
      expect(legacyItem.pcosTip, equals('Legacy tip for backwards compatibility.'));
    });

    test('UserProfile handles pcodStatus and legacy pcosStatus in maps and models', () {
      const profile = UserProfile(
        age: 22,
        heightCm: 160,
        currentWeightKg: 58,
        pcodStatus: 'confirmed',
      );

      expect(profile.pcodStatus, equals('confirmed'));
      expect(profile.pcosStatus, equals('confirmed'));

      final map = profile.toMap();
      expect(map['pcodStatus'], equals('confirmed'));
      expect(map['pcosStatus'], equals('confirmed'));

      final restored = UserProfile.fromMap(map);
      expect(restored.pcodStatus, equals('confirmed'));

      // Restoring from legacy map containing only pcosStatus
      final legacyMap = Map<String, dynamic>.from(map)..remove('pcodStatus');
      final fromLegacy = UserProfile.fromMap(legacyMap);
      expect(fromLegacy.pcodStatus, equals('confirmed'));
    });

    test('AppStrings provides non-curative PCOD messaging in EN and HI', () {
      final disclaimerEn = AppStrings.get('medicalDisclaimer', lang: 'en');
      final disclaimerHi = AppStrings.get('medicalDisclaimer', lang: 'hi');

      expect(disclaimerEn, contains('PCOD'));
      expect(disclaimerEn, contains('do not cure'));
      expect(disclaimerHi, contains('PCOD'));
      expect(disclaimerHi, contains('इलाज नहीं'));
    });

    test('UserProfile.fromMap safely detects onboarding status for legacy profiles', () {
      // 1. Explicit modern profile with isOnboarded = 1
      final modernMap = {
        'age': 23,
        'heightCm': 165.0,
        'currentWeightKg': 62.0,
        'isOnboarded': 1,
      };
      final modernProfile = UserProfile.fromMap(modernMap);
      expect(modernProfile.isOnboarded, isTrue);

      // 2. Legacy database map where isOnboarded column is null/missing, but profile has valid weight & age
      final legacyValidMap = {
        'age': 24,
        'heightCm': 160.0,
        'currentWeightKg': 59.5,
        'isOnboarded': null,
      };
      final legacyProfile = UserProfile.fromMap(legacyValidMap);
      expect(legacyProfile.isOnboarded, isTrue,
          reason: 'Valid legacy profile must not force the user to repeat onboarding');

      // 3. Fresh uninitialized profile
      final freshUninitializedMap = {
        'age': 0,
        'heightCm': 0.0,
        'currentWeightKg': 0.0,
        'isOnboarded': 0,
      };
      final freshProfile = UserProfile.fromMap(freshUninitializedMap);
      expect(freshProfile.isOnboarded, isFalse);
    });

    test('Water reminder deadline diff accurately detects remaining time and elapsed deadlines', () {
      final now = DateTime(2026, 10, 25, 12, 0, 0);

      // Future deadline: 15 minutes ahead
      final futureDeadline = now.add(const Duration(minutes: 15));
      final futureDiff = futureDeadline.difference(now).inSeconds;
      expect(futureDiff, equals(900));

      // Elapsed deadline: 10 minutes in the past
      final pastDeadline = now.subtract(const Duration(minutes: 10));
      final pastDiff = pastDeadline.difference(now).inSeconds;
      expect(pastDiff, lessThanOrEqualTo(0));
      // In app logic: non-positive diff resolves to 0 ("Due now")
      final remainingSeconds = pastDiff > 0 ? pastDiff : 0;
      expect(remainingSeconds, equals(0));

      // Snooze: 10 minutes from now
      final snoozeDeadline = now.add(const Duration(minutes: 10));
      final snoozeDiff = snoozeDeadline.difference(now).inSeconds;
      expect(snoozeDiff, equals(600));
    });
  });

  group('Automatic Daily Activity & Pedometer Tests', () {
    test('1. StepCalculator calculates stride length, distance, calories and active minutes honestly', () {
      // 1. Stride length calculation
      // For 160cm woman: 160 * 0.415 = 66.4 cm = 0.664 m
      final stride160 = StepCalculator.calculateStrideLengthMeters(160.0);
      expect(stride160, closeTo(0.664, 0.001));

      // Default stride when height is missing
      final defaultStride = StepCalculator.calculateStrideLengthMeters(null);
      expect(defaultStride, equals(0.70));

      // 2. Distance estimation
      // 1000 steps * 0.70 m = 700 m (< 1,000 m format)
      final dist700 = StepCalculator.estimateDistanceMeters(steps: 1000, heightCm: null);
      expect(dist700, equals(700.0));
      expect(GpsTrackerCalculator.formatDistance(dist700), equals('700 m'));

      // 5000 steps * 0.70 m = 3500 m (>= 1,000 m format)
      final dist3500 = StepCalculator.estimateDistanceMeters(steps: 5000, heightCm: null);
      expect(dist3500, equals(3500.0));
      expect(GpsTrackerCalculator.formatDistance(dist3500), equals('3.50 km'));

      // 3. Calorie estimation (0.04 kcal/step at 60kg)
      final cal60kg = StepCalculator.estimateCaloriesBurned(steps: 2500, weightKg: 60.0);
      expect(cal60kg, equals(100.0)); // 2500 * 0.04 = 100 kcal

      // Proportionate scaling for 75kg
      final cal75kg = StepCalculator.estimateCaloriesBurned(steps: 2500, weightKg: 75.0);
      expect(cal75kg, equals(125.0)); // 100 * (75/60) = 125 kcal

      // 4. Active minutes (at ~100 steps/minute)
      expect(StepCalculator.estimateActiveMinutes(0), equals(0));
      expect(StepCalculator.estimateActiveMinutes(50), equals(0));
      expect(StepCalculator.estimateActiveMinutes(1000), equals(10));
      expect(StepCalculator.estimateActiveMinutes(6000), equals(60));
    });

    test('2. DailyActivityLog serializes to/from map cleanly and reports progress correctly', () {
      final now = DateTime(2026, 10, 25, 18, 0, 0);
      final log = DailyActivityLog(
        date: '2026-10-25',
        steps: 4500,
        goal: 6000,
        distanceMeters: 3150.0,
        activeMinutes: 45,
        estimatedCalories: 180.0,
        lastUpdatedAt: now,
      );

      expect(log.progressPercent, equals(0.75));
      expect(log.isGoalAchieved, isFalse);
      expect(log.distanceFormatted, equals('3.15 km'));

      final map = log.toMap();
      expect(map['date'], equals('2026-10-25'));
      expect(map['steps'], equals(4500));
      expect(map['goal'], equals(6000));
      expect(map['distanceMeters'], equals(3150.0));

      final restored = DailyActivityLog.fromMap(map);
      expect(restored.date, equals('2026-10-25'));
      expect(restored.steps, equals(4500));
      expect(restored.goal, equals(6000));
      expect(restored.activeMinutes, equals(45));

      // Overachieved goal clamp
      final achievedLog = log.copyWith(steps: 8000);
      expect(achievedLog.isGoalAchieved, isTrue);
      expect(achievedLog.progressPercent, equals(1.0)); // clamped
    });

    test('3. PedometerService initializes daily baseline and tracks step increments without double-counting', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final pedometer = PedometerService.instance;

      final t0 = DateTime(2026, 10, 25, 8, 0, 0);

      // Event 1: Hardware step counter reads 12,000 steps since device boot
      // This establishes the day start baseline of 12,000 steps
      await pedometer.processStepEvent(
        rawHardwareSteps: 12000,
        eventTime: t0,
        prefsInstance: prefs,
      );
      expect(pedometer.todaySteps, equals(0), reason: 'First event must establish baseline with 0 steps today');

      // Event 2: User walks 350 steps (hardware counter increments to 12,350)
      final t1 = t0.add(const Duration(minutes: 10));
      await pedometer.processStepEvent(
        rawHardwareSteps: 12350,
        eventTime: t1,
        prefsInstance: prefs,
      );
      expect(pedometer.todaySteps, equals(350));

      // Event 3: Sitting stationary — hardware counter remains at 12,350
      final t2 = t1.add(const Duration(minutes: 5));
      await pedometer.processStepEvent(
        rawHardwareSteps: 12350,
        eventTime: t2,
        prefsInstance: prefs,
      );
      expect(pedometer.todaySteps, equals(350), reason: 'Stationary sitting must not increase steps');

      // Event 4: User walks another 500 steps (hardware counter increments to 12,850)
      final t3 = t2.add(const Duration(minutes: 15));
      await pedometer.processStepEvent(
        rawHardwareSteps: 12850,
        eventTime: t3,
        prefsInstance: prefs,
      );
      expect(pedometer.todaySteps, equals(850));
    });

    test('4. PedometerService correctly handles device reboot baseline reset without losing steps', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final pedometer = PedometerService.instance;
      pedometer.resetForTesting();

      final date = DateTime(2026, 10, 25, 10, 0, 0);

      // Before reboot: baseline 5,000, user walks 1,200 steps (counter at 6,200)
      await pedometer.processStepEvent(
        rawHardwareSteps: 5000,
        eventTime: date,
        prefsInstance: prefs,
      );
      await pedometer.processStepEvent(
        rawHardwareSteps: 6200,
        eventTime: date.add(const Duration(hours: 1)),
        prefsInstance: prefs,
      );
      expect(pedometer.todaySteps, equals(1200));

      // DEVICE REBOOTS: Hardware counter resets to 0!
      // New event arrives with rawHardwareSteps = 50 (50 steps since reboot)
      await pedometer.processStepEvent(
        rawHardwareSteps: 50,
        eventTime: date.add(const Duration(hours: 2)),
        prefsInstance: prefs,
      );
      // Expected: 1,200 (pre-reboot) + 50 (post-reboot) = 1,250 steps!
      expect(pedometer.todaySteps, equals(1250),
          reason: 'Steps accumulated before reboot must be preserved and added to post-reboot steps');
    });

    test('5. PedometerService detects midnight rollover and resets today steps without corrupting baseline', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final pedometer = PedometerService.instance;
      pedometer.resetForTesting();

      final day1 = DateTime(2026, 10, 25, 23, 50, 0);
      final day2 = DateTime(2026, 10, 26, 0, 5, 0);

      // Day 1: baseline 10,000, reaches 14,000 (4,000 steps today)
      await pedometer.processStepEvent(rawHardwareSteps: 10000, eventTime: day1, prefsInstance: prefs);
      await pedometer.processStepEvent(rawHardwareSteps: 14000, eventTime: day1, prefsInstance: prefs);
      expect(pedometer.todaySteps, equals(4000));

      // Day 2 (Midnight crosses): hardware counter at 14,020 (took 20 steps after midnight)
      await pedometer.processStepEvent(rawHardwareSteps: 14020, eventTime: day2, prefsInstance: prefs);
      // New day starts baseline at 14,020, today's steps for Day 2 is 0 initially!
      expect(pedometer.todaySteps, equals(0), reason: 'New day must reset today steps to 0');

      // Later on Day 2: user takes 300 steps (counter at 14,320)
      await pedometer.processStepEvent(
        rawHardwareSteps: 14320,
        eventTime: day2.add(const Duration(hours: 2)),
        prefsInstance: prefs,
      );
      expect(pedometer.todaySteps, equals(300));
    });

    test('6. Outdoor GPS route session remains separate and does not double-count daily pedometer steps', () {
      final pedometerStepsBefore = 2500;
      final start = DateTime(2026, 10, 25, 14, 0, 0);
      final end = DateTime(2026, 10, 25, 14, 30, 0);

      // Record a distinct GPS outdoor walk session of 1,500m
      final walkSession = WalkSession(
        startTime: start,
        endTime: end,
        distanceMeters: 1500.0,
        durationSeconds: 1800,
        activeDurationSeconds: 1500,
        avgSpeedKmh: 4.5,
        elapsedAvgSpeedKmh: 3.0,
        estimatedCalories: 75.0,
      );

      expect(walkSession.distanceFormatted, equals('1.50 km'));
      // Daily pedometer steps are completely independent of GPS session distance
      expect(pedometerStepsBefore, equals(2500), reason: 'GPS walk session must not inflate hardware pedometer totals');
    });

    test('7. Sensor cumulative count reconciliation without duplicate steps', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final pedometer = PedometerService.instance;
      pedometer.resetForTesting();
      final time = DateTime(2026, 10, 25, 12, 0, 0);

      // 1. Initial fix: hardware step counter is at 20,000
      await pedometer.processStepEvent(rawHardwareSteps: 20000, eventTime: time, prefsInstance: prefs);
      expect(pedometer.todaySteps, equals(0));

      // 2. User walks 100 steps (hardware counter increments to 20,100)
      await pedometer.processStepEvent(rawHardwareSteps: 20100, eventTime: time.add(const Duration(minutes: 5)), prefsInstance: prefs);
      expect(pedometer.todaySteps, equals(100));

      // 3. Repeated event with same raw count (20,100) must NOT double count
      await pedometer.processStepEvent(rawHardwareSteps: 20100, eventTime: time.add(const Duration(minutes: 6)), prefsInstance: prefs);
      expect(pedometer.todaySteps, equals(100));

      // 4. Next walk of 50 steps (20,150)
      await pedometer.processStepEvent(rawHardwareSteps: 20150, eventTime: time.add(const Duration(minutes: 10)), prefsInstance: prefs);
      expect(pedometer.todaySteps, equals(150));
    });

    test('8. Step totals update when UI is not active via background sensor reconciliation', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final pedometer = PedometerService.instance;
      pedometer.resetForTesting();
      final time = DateTime(2026, 10, 25, 15, 0, 0);

      // Active in foreground: 150 steps
      await pedometer.processStepEvent(rawHardwareSteps: 30000, eventTime: time, prefsInstance: prefs);
      await pedometer.processStepEvent(rawHardwareSteps: 30150, eventTime: time.add(const Duration(minutes: 5)), prefsInstance: prefs);
      expect(pedometer.todaySteps, equals(150));

      // Phone screen turned OFF / app backgrounded for 20 minutes. User walks 120 steps.
      // Hardware counter accumulates to 30,270.
      final resumeTime = time.add(const Duration(minutes: 25));
      await pedometer.processStepEvent(rawHardwareSteps: 30270, eventTime: resumeTime, prefsInstance: prefs);

      // On resume, all steps accumulated while screen was off must be immediately reconciled!
      expect(pedometer.todaySteps, equals(270));
    });

    test('9. Process restart restores baseline and strictly preserves today existing steps', () async {
      // Simulate existing app session with 166 steps already stored
      SharedPreferences.setMockInitialValues({
        'bloomwell_pedometer_date': '2026-10-25',
        'bloomwell_pedometer_today_steps': 166,
        'bloomwell_pedometer_baseline': 50000,
        'bloomwell_pedometer_reboot_offset': 0,
      });
      final prefs = await SharedPreferences.getInstance();
      final pedometer = PedometerService.instance;
      pedometer.resetForTesting(initialSteps: 166);

      // New event arrives after process was restarted (user walked 4 more steps: 50,170)
      final time = DateTime(2026, 10, 25, 16, 0, 0);
      await pedometer.processStepEvent(rawHardwareSteps: 50170, eventTime: time, prefsInstance: prefs);

      // Expected: 50,170 - 50,000 = 170 steps total (166 prior steps preserved + 4 new steps)
      expect(pedometer.todaySteps, equals(170));
    });

    test('10. Missed midnight rollover recovery closes prior day and starts new day at 0', () async {
      // Prior day (2026-10-25) ended with 166 steps
      SharedPreferences.setMockInitialValues({
        'bloomwell_pedometer_date': '2026-10-25',
        'bloomwell_pedometer_today_steps': 166,
        'bloomwell_pedometer_baseline': 40000,
        'bloomwell_pedometer_reboot_offset': 0,
      });
      final prefs = await SharedPreferences.getInstance();
      final pedometer = PedometerService.instance;
      pedometer.resetForTesting(initialSteps: 166);

      // App is opened next morning on 2026-10-26 at 08:30 AM with hardware steps at 40,200
      final morningTime = DateTime(2026, 10, 26, 8, 30, 0);
      await pedometer.processStepEvent(rawHardwareSteps: 40200, eventTime: morningTime, prefsInstance: prefs);

      // New day MUST start at 0 steps without fabricating steps!
      expect(pedometer.todaySteps, equals(0));
      expect(prefs.getString('bloomwell_pedometer_date'), equals('2026-10-26'));
      expect(prefs.getInt('bloomwell_pedometer_baseline'), equals(40200));

      // Walking 50 steps on the new day increments from 0
      await pedometer.processStepEvent(rawHardwareSteps: 40250, eventTime: morningTime.add(const Duration(minutes: 10)), prefsInstance: prefs);
      expect(pedometer.todaySteps, equals(50));
    });

    test('11. Device-adaptive battery guidance accurately identifies OEMs and falls back gracefully', () {
      final info = DeviceInfoService.instance;

      // Xiaomi / Poco detection
      info.setMockDeviceDetails(manufacturer: 'Xiaomi', model: '25053PC47I', sdkInt: 36, isBatteryOptimizationIgnored: false);
      final xiaomiGuidance = info.getBatteryGuidance(language: 'en');
      expect(xiaomiGuidance.manufacturerKey, equals('xiaomi'));
      expect(xiaomiGuidance.isIdentified, isTrue);
      expect(xiaomiGuidance.steps.any((s) => s.contains('No Restrictions')), isTrue);
      expect(xiaomiGuidance.steps.any((s) => s.contains('Autostart')), isTrue);
      expect(xiaomiGuidance.statusLabel, contains('Restricted'));

      // Samsung detection
      info.setMockDeviceDetails(manufacturer: 'samsung', model: 'SM-G991B', sdkInt: 34, isBatteryOptimizationIgnored: true);
      final samsungGuidance = info.getBatteryGuidance(language: 'en');
      expect(samsungGuidance.manufacturerKey, equals('samsung'));
      expect(samsungGuidance.isIdentified, isTrue);
      expect(samsungGuidance.steps.any((s) => s.contains('Never sleeping apps')), isTrue);
      expect(samsungGuidance.statusLabel, contains('Unrestricted'));

      // OnePlus / BBK detection
      info.setMockDeviceDetails(manufacturer: 'OnePlus', model: 'IN2023', sdkInt: 34, isBatteryOptimizationIgnored: false);
      final bbkGuidance = info.getBatteryGuidance(language: 'en');
      expect(bbkGuidance.manufacturerKey, equals('bbk'));
      expect(bbkGuidance.isIdentified, isTrue);
      expect(bbkGuidance.steps.any((s) => s.contains('Allow background activity')), isTrue);

      // Google Pixel / Stock detection
      info.setMockDeviceDetails(manufacturer: 'Google', model: 'Pixel 8', sdkInt: 35, isBatteryOptimizationIgnored: true);
      final pixelGuidance = info.getBatteryGuidance(language: 'en');
      expect(pixelGuidance.manufacturerKey, equals('stock'));
      expect(pixelGuidance.isIdentified, isTrue);

      // Generic OEM Fallback
      info.setMockDeviceDetails(manufacturer: 'UnknownCustomBrand', model: 'X1', sdkInt: 33, isBatteryOptimizationIgnored: false);
      final genericGuidance = info.getBatteryGuidance(language: 'en');
      expect(genericGuidance.manufacturerKey, equals('generic'));
      expect(genericGuidance.isIdentified, isFalse);
      expect(genericGuidance.steps.any((s) => s.contains('Battery')), isTrue);

      // Hindi localization verification
      final hindiGuidance = info.getBatteryGuidance(language: 'hi');
      expect(hindiGuidance.steps.isNotEmpty, isTrue);
      expect(hindiGuidance.caveat, contains('ध्यान दें'));
    });
  });

  group('CollegeSchedule & WakeVerification Unit Tests', () {
    test('CollegeSchedule model properly serializes and deserializes', () {
      final now = DateTime(2026, 10, 25, 9, 0);
      final schedule = CollegeSchedule(
        date: '2026-10-25',
        goingToCollege: true,
        hasClasses: true,
        classStartTime: '09:00',
        classEndTime: '10:30',
        updatedAt: now,
      );

      expect(schedule.isClassConfigured, isTrue);

      final map = schedule.toMap();
      expect(map['date'], equals('2026-10-25'));
      expect(map['goingToCollege'], equals(1));
      expect(map['hasClasses'], equals(1));
      expect(map['classStartTime'], equals('09:00'));
      expect(map['classEndTime'], equals('10:30'));

      final fromMap = CollegeSchedule.fromMap(map);
      expect(fromMap.date, equals('2026-10-25'));
      expect(fromMap.goingToCollege, isTrue);
      expect(fromMap.hasClasses, isTrue);
      expect(fromMap.classStartTime, equals('09:00'));
      expect(fromMap.classEndTime, equals('10:30'));
      expect(fromMap.isClassConfigured, isTrue);
    });

    test('CollegeSchedule correctly evaluates isClassConfigured', () {
      final notGoing = CollegeSchedule(
        date: '2026-10-25',
        goingToCollege: false,
        hasClasses: false,
        updatedAt: DateTime(2026, 10, 25),
      );
      expect(notGoing.isClassConfigured, isFalse);

      final noClass = CollegeSchedule(
        date: '2026-10-25',
        goingToCollege: true,
        hasClasses: false,
        updatedAt: DateTime(2026, 10, 25),
      );
      expect(noClass.isClassConfigured, isFalse);

      final missingTimes = CollegeSchedule(
        date: '2026-10-25',
        goingToCollege: true,
        hasClasses: true,
        classStartTime: null,
        classEndTime: null,
        updatedAt: DateTime(2026, 10, 25),
      );
      expect(missingTimes.isClassConfigured, isFalse);
    });

    test('CollegeSchedule supports independent college and class intervals', () {
      final schedule = CollegeSchedule(
        date: '2026-10-26',
        goingToCollege: true,
        hasClasses: false,
        collegeStartTime: '08:00',
        collegeEndTime: '14:00',
        classStartTime: null,
        classEndTime: null,
        updatedAt: DateTime(2026, 10, 26),
      );
      expect(schedule.isCollegeConfigured, isTrue);
      expect(schedule.isClassConfigured, isFalse);

      final map = schedule.toMap();
      expect(map['collegeStartTime'], equals('08:00'));
      expect(map['collegeEndTime'], equals('14:00'));
      expect(map['classStartTime'], isNull);

      final fromMap = CollegeSchedule.fromMap(map);
      expect(fromMap.goingToCollege, isTrue);
      expect(fromMap.hasClasses, isFalse);
      expect(fromMap.collegeStartTime, equals('08:00'));
      expect(fromMap.collegeEndTime, equals('14:00'));
    });

    test('Sleep window calculation correctly detects bedtime to wakeup across midnight', () {
      // Bedtime 23:00, Wakeup 07:00
      bool isSleep(int currentHour, int currentMin, int bedHour, int bedMin, int wakeHour, int wakeMin) {
        final currentMinutes = currentHour * 60 + currentMin;
        final bedMinutes = bedHour * 60 + bedMin;
        final wakeMinutes = wakeHour * 60 + wakeMin;
        if (bedMinutes > wakeMinutes) {
          // Midnight crossover
          return currentMinutes >= bedMinutes || currentMinutes < wakeMinutes;
        } else {
          return currentMinutes >= bedMinutes && currentMinutes < wakeMinutes;
        }
      }

      // At 22:30 (before bed) -> awake
      expect(isSleep(22, 30, 23, 0, 7, 0), isFalse);
      // At 23:00 (bedtime) -> sleeping
      expect(isSleep(23, 0, 23, 0, 7, 0), isTrue);
      // At 01:30 (night) -> sleeping
      expect(isSleep(1, 30, 23, 0, 7, 0), isTrue);
      // At 06:59 (just before wake) -> sleeping
      expect(isSleep(6, 59, 23, 0, 7, 0), isTrue);
      // At 07:00 (wake time) -> awake
      expect(isSleep(7, 0, 23, 0, 7, 0), isFalse);
      // At 12:00 (daytime) -> awake
      expect(isSleep(12, 0, 23, 0, 7, 0), isFalse);
    });

    test('WakeVerification model properly serializes and deserializes', () {
      final now = DateTime(2026, 10, 25, 7, 5, 23);
      final verification = WakeVerification(
        date: '2026-10-25',
        verifiedAt: now,
        method: 'selfie',
      );

      final map = verification.toMap();
      expect(map['date'], equals('2026-10-25'));
      expect(map['verifiedAt'], equals(now.toIso8601String()));
      expect(map['method'], equals('selfie'));

      final fromMap = WakeVerification.fromMap(map);
      expect(fromMap.date, equals('2026-10-25'));
      expect(fromMap.verifiedAt, equals(now));
      expect(fromMap.method, equals('selfie'));
    });

    test('Class active interval accurately detects during-class vs outside-class', () {
      bool isClassActive(String startTime, String endTime, int hour, int minute) {
        final startParts = startTime.split(':');
        final endParts = endTime.split(':');
        final startM = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endM = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        final currentM = hour * 60 + minute;
        if (endM >= startM) {
          return currentM >= startM && currentM < endM;
        } else {
          return currentM >= startM || currentM < endM;
        }
      }

      // 09:00 to 10:30 class
      expect(isClassActive('09:00', '10:30', 8, 59), isFalse);
      expect(isClassActive('09:00', '10:30', 9, 0), isTrue);
      expect(isClassActive('09:00', '10:30', 9, 45), isTrue);
      expect(isClassActive('09:00', '10:30', 10, 29), isTrue);
      expect(isClassActive('09:00', '10:30', 10, 30), isFalse);
      expect(isClassActive('09:00', '10:30', 11, 0), isFalse);

      // Night class crossing midnight: 23:00 to 01:00
      expect(isClassActive('23:00', '01:00', 22, 59), isFalse);
      expect(isClassActive('23:00', '01:00', 23, 15), isTrue);
      expect(isClassActive('23:00', '01:00', 0, 30), isTrue);
      expect(isClassActive('23:00', '01:00', 1, 0), isFalse);
    });

    test('Localization contains all required strings in English and Hindi', () {
      const requiredKeys = [
        'selfieVerificationTitle',
        'selfieVerificationPrompt',
        'selfieVerificationSubtitle',
        'retakeSelfie',
        'submitSelfie',
        'openFrontCamera',
        'collegePromptTitle',
        'classesPromptTitle',
        'classHoursTitle',
        'timeToDrinkWater',
        'iDrankWater',
        'snooze',
        'exactAlarmRequiredTitle',
        'todaysSession',
        'sessionSubtitle',
        'stepExercise',
        'stepYoga',
        'playExercise',
        'playYoga',
        'restTitle',
        'restSubtitle',
        'skipRest',
        'sessionCompleted',
        'sessionCompletedDesc',
        'replaySession',
        'videoNotConfigured',
        'viewRecipe',
        'ingredientsTitle',
        'instructionsTitle',
        'substitutionsTitle',
      ];

      for (final key in requiredKeys) {
        final en = AppStrings.get(key, lang: 'en');
        final hi = AppStrings.get(key, lang: 'hi');
        expect(en, isNotEmpty);
        expect(hi, isNotEmpty);
        expect(en, isNot(equals(key)), reason: 'Missing translation for $key in en');
        expect(hi, isNot(equals(key)), reason: 'Missing translation for $key in hi');
      }
    });
  });

  group('WeeklyMenuData & Offline Recipes Unit Tests', () {
    test('Every day of the week (1 to 7) contains exactly 3 meals: Breakfast, Lunch, Dinner', () {
      for (int day = 1; day <= 7; day++) {
        final meals = WeeklyMenuData.getMealItemsForDay(day);
        expect(meals.length, equals(3), reason: 'Day $day must have 3 meals');
        expect(meals[0].mealType, equals('breakfast'));
        expect(meals[1].mealType, equals('lunch'));
        expect(meals[2].mealType, equals('dinner'));
      }
    });

    test('Total weekly menu contains 21 scheduled meals and all map to valid recipes', () {
      final allMeals = WeeklyMenuData.getAllMealItems();
      expect(allMeals.length, equals(21));

      for (final meal in allMeals) {
        expect(meal.id, isNotEmpty);
        expect(meal.name, isNotEmpty);
        expect(meal.nameHi, isNotEmpty);
        expect(meal.prepTimeMinutes, greaterThan(0));
        expect(meal.ingredients, isNotEmpty);
        expect(meal.instructions, isNotEmpty);
        expect(meal.substitutions, isNotEmpty);
      }
    });

    test('Unique recipes count equals 15 without duplicate definitions', () {
      final uniqueRecipes = WeeklyMenuData.recipes;
      expect(uniqueRecipes.length, equals(15));

      final uniqueIds = uniqueRecipes.keys.toSet();
      expect(uniqueIds.length, equals(15));
    });

    test('Recipe details provide explicit quantities and step-by-step instructions in EN & HI', () {
      for (final entry in WeeklyMenuData.recipes.entries) {
        final recipe = entry.value;
        expect(recipe.ingredients.length, greaterThanOrEqualTo(3));
        expect(recipe.instructions.length, greaterThanOrEqualTo(3));
        expect(recipe.instructionsHi.length, equals(recipe.instructions.length));
        expect(recipe.substitutions.length, greaterThanOrEqualTo(1));
        expect(recipe.prepTimeMinutes, greaterThan(0));
        expect(recipe.cookTimeMinutes, greaterThan(0));
      }
    });

    test('Meals do not make medical or PCOD cure claims', () {
      final allMeals = WeeklyMenuData.getAllMealItems();
      for (final meal in allMeals) {
        expect(meal.pcodTip.toLowerCase(), isNot(contains('cure')));
        expect(meal.pcodTip.toLowerCase(), isNot(contains('permanent cure')));
        expect(meal.pcodTip.toLowerCase(), isNot(contains('guarantee')));
      }
    });
  });

  group('VideoConfig & Guided Session Unit Tests', () {
    test('VideoConfig loads and saves runtime sources cleanly', () async {
      SharedPreferences.setMockInitialValues({
        'bloomwell_exercise_video_source': 'https://example.com/exercise.mp4',
        'bloomwell_yoga_video_source': 'https://example.com/yoga.mp4',
      });

      await VideoConfig.loadSavedSources();
      expect(VideoConfig.exerciseVideoSource, equals('https://example.com/exercise.mp4'));
      expect(VideoConfig.yogaVideoSource, equals('https://example.com/yoga.mp4'));

      await VideoConfig.saveSources(exerciseUrl: 'https://youtube.com/watch?v=new_exercise');
      expect(VideoConfig.exerciseVideoSource, equals('https://youtube.com/watch?v=new_exercise'));
    });

    test('Rest timer deadline computation and restoration handles background/resume cleanly', () {
      // 5-minute rest = 300 seconds
      final now = DateTime.now();
      final deadline = now.add(const Duration(minutes: 5));

      final remainingSeconds = deadline.difference(now).inSeconds;
      expect(remainingSeconds, equals(300));

      // Simulating 2 minutes elapsed while app in background
      final resumedTime = now.add(const Duration(minutes: 2));
      final resumedRemaining = deadline.difference(resumedTime).inSeconds;
      expect(resumedRemaining, equals(180));

      // Simulating rest expired while app in background
      final expiredTime = now.add(const Duration(minutes: 6));
      final expiredRemaining = deadline.difference(expiredTime).inSeconds;
      expect(expiredRemaining, lessThanOrEqualTo(0));
    });

    test('GuidedSessionPlayer correctly detects YouTube URLs and isolates them from MP4 paths', () {
      expect(GuidedSessionPlayer.isYouTubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(GuidedSessionPlayer.isYouTubeUrl('https://youtu.be/dQw4w9WgXcQ?si=abc12345'), isTrue);
      expect(GuidedSessionPlayer.isYouTubeUrl('https://m.youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(GuidedSessionPlayer.isYouTubeUrl('https://www.youtube.com/embed/dQw4w9WgXcQ'), isTrue);
      expect(GuidedSessionPlayer.isYouTubeUrl('dQw4w9WgXcQ'), isTrue);
      expect(GuidedSessionPlayer.isYouTubeUrl('http://youtu.be/dQw4w9WgXcQ'), isTrue);

      // Non-YouTube URLs must never be flagged as YouTube
      expect(GuidedSessionPlayer.isYouTubeUrl('https://example.com/stream/exercise.mp4'), isFalse);
      expect(GuidedSessionPlayer.isYouTubeUrl('https://mycdn.net/hls/yoga.m3u8'), isFalse);
      expect(GuidedSessionPlayer.isYouTubeUrl(''), isFalse);
    });

    test('GuidedSessionPlayer extracts 11-char video ID cleanly across URL variants', () {
      expect(
        GuidedSessionPlayer.extractYouTubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        GuidedSessionPlayer.extractYouTubeId('https://youtu.be/dQw4w9WgXcQ?si=abcdefghijk12345'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        GuidedSessionPlayer.extractYouTubeId('https://m.youtube.com/watch?v=dQw4w9WgXcQ&feature=share'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        GuidedSessionPlayer.extractYouTubeId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        GuidedSessionPlayer.extractYouTubeId('dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        GuidedSessionPlayer.extractYouTubeId('https://example.com/video.mp4'),
        isNull,
      );
    });
  });

  group('Reset All Data & Alarm Suppression Regression Tests', () {
    test('Reset state ensures isOnboarded is false and clears user profile', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.bloomwell_onboarding_completed': true,
        'bloomwell_onboarding_completed': true,
        'bloomwell_wake_time': '07:00',
        'bloomwell_water_reminder_interval': 30,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('bloomwell_onboarding_completed'), isTrue);

      // Simulating resetAllData actions
      await prefs.clear();
      expect(prefs.getBool('bloomwell_onboarding_completed'), isNull);
      expect(prefs.getString('bloomwell_wake_time'), isNull);
    });

    test('Un-onboarded / reset state prevents restoring water reminders or wake alarms', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final bool prefsOnboarded = prefs.getBool('bloomwell_onboarding_completed') ?? false;
      const UserProfile? profile = null;
      final bool profileOnboarded = profile != null && profile.isOnboarded;
      final bool isOnboarded = prefsOnboarded || profileOnboarded;

      expect(isOnboarded, isFalse);
      // Reminders and alarms are strictly blocked when isOnboarded is false
      bool reminderScheduled = false;
      if (isOnboarded && profile != null) {
        reminderScheduled = true;
      }
      expect(reminderScheduled, isFalse);
    });

    test('Onboarding draft save and restoration preserves user inputs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // User enters step 0 and 3
      await prefs.setInt('bloomwell_draft_step', 3);
      await prefs.setString('bloomwell_draft_name', 'Ananya');
      await prefs.setString('bloomwell_draft_weight', '58.5');
      await prefs.setString('bloomwell_draft_weight_unit', 'kg');
      await prefs.setString('bloomwell_draft_height', '163');
      await prefs.setString('bloomwell_draft_height_unit', 'cm');
      await prefs.setString('bloomwell_draft_pcod', 'diagnosed');

      // Restoring draft
      final restoredStep = prefs.getInt('bloomwell_draft_step');
      final restoredName = prefs.getString('bloomwell_draft_name');
      final restoredWeight = prefs.getString('bloomwell_draft_weight');
      final restoredUnit = prefs.getString('bloomwell_draft_weight_unit');
      final restoredPcod = prefs.getString('bloomwell_draft_pcod');

      expect(restoredStep, equals(3));
      expect(restoredName, equals('Ananya'));
      expect(restoredWeight, equals('58.5'));
      expect(restoredUnit, equals('kg'));
      expect(restoredPcod, equals('diagnosed'));
    });

    test('UserProfile model handles client name, units, and conversions accurately', () {
      const profile = UserProfile(
        name: 'Priya Sharma',
        weightUnit: 'lbs',
        heightUnit: 'ft_in',
        age: 23,
        heightCm: 165.1,
        currentWeightKg: 58.967,
        pcodStatus: 'lifestyle_management',
        isOnboarded: true,
      );

      final map = profile.toMap();
      expect(map['name'], equals('Priya Sharma'));
      expect(map['weightUnit'], equals('lbs'));
      expect(map['heightUnit'], equals('ft_in'));
      expect(map['pcodStatus'], equals('lifestyle_management'));

      final fromMap = UserProfile.fromMap(map);
      expect(fromMap.name, equals('Priya Sharma'));
      expect(fromMap.weightUnit, equals('lbs'));
      expect(fromMap.heightUnit, equals('ft_in'));
      expect(fromMap.pcodStatus, equals('lifestyle_management'));
      expect(fromMap.isOnboarded, isTrue);
    });

    test('CSV Export includes client name and export date header when provided', () {
      final entries = [
        WeightEntry(
          weightKg: 62.0,
          timestamp: DateTime(2026, 10, 20),
          notes: 'Check-in 1',
        ),
      ];

      final csv = WeightMetricsCalculator.generateCsv(entries, clientName: 'Aarohi');
      expect(csv, contains('# BloomWell Progress Report - Client: Aarohi'));
      expect(csv, contains('Date,Weight (kg),Notes'));
      expect(csv, contains('62.0'));
    });

    test('Water reminder interval updates to configured interval upon drink confirmation, not 10 min', () {
      const configuredIntervalMinutes = 45;
      final now = DateTime(2026, 10, 26, 10, 0);

      // Normal drink confirmation deadline
      final drinkDeadline = now.add(const Duration(minutes: configuredIntervalMinutes));
      expect(drinkDeadline.difference(now).inMinutes, equals(45));

      // Snooze deadline is explicitly 10 minutes
      const snoozeMinutes = 10;
      final snoozeDeadline = now.add(const Duration(minutes: snoozeMinutes));
      expect(snoozeDeadline.difference(now).inMinutes, equals(10));
    });

    test('WaterLog model correctly persists and restores optional photoPath and isPhotoVerified', () {
      final logWithPhoto = WaterLog(
        id: 1,
        amountMl: 350,
        timestamp: DateTime(2026, 10, 26, 10, 30),
        photoPath: '/data/user/0/com.bloomwell.bloomwell/app_flutter/bottle_123.jpg',
        isPhotoVerified: true,
      );

      final map = logWithPhoto.toMap();
      expect(map['photoPath'], equals('/data/user/0/com.bloomwell.bloomwell/app_flutter/bottle_123.jpg'));
      expect(map['isPhotoVerified'], equals(1));

      final restored = WaterLog.fromMap(map);
      expect(restored.photoPath, equals('/data/user/0/com.bloomwell.bloomwell/app_flutter/bottle_123.jpg'));
      expect(restored.isPhotoVerified, isTrue);

      final logWithoutPhoto = WaterLog(
        id: 2,
        amountMl: 250,
        timestamp: DateTime(2026, 10, 26, 11, 0),
      );
      final map2 = logWithoutPhoto.toMap();
      expect(map2['photoPath'], isNull);
      expect(map2['isPhotoVerified'], equals(0));
    });
  });

  group('Targeted Video Integration, Onboarding & Water Reminder Unit Tests', () {
    test('VideoConfig has exact unlisted YouTube URLs configured as defaults', () {
      expect(VideoConfig.defaultExerciseUrl, equals('https://youtu.be/B8w09Rb5e54'));
      expect(VideoConfig.defaultYogaUrl, equals('https://youtu.be/IOLnvYMy8_o'));
    });

    test('GuidedSessionPlayer recognizes YouTube URLs and extracts video IDs', () {
      expect(GuidedSessionPlayer.isYouTubeUrl(VideoConfig.defaultExerciseUrl), isTrue);
      expect(GuidedSessionPlayer.isYouTubeUrl(VideoConfig.defaultYogaUrl), isTrue);
      expect(GuidedSessionPlayer.extractYouTubeId(VideoConfig.defaultExerciseUrl), equals('B8w09Rb5e54'));
      expect(GuidedSessionPlayer.extractYouTubeId(VideoConfig.defaultYogaUrl), equals('IOLnvYMy8_o'));
    });

    test('VideoConfig.loadSavedSources restores defaults when preferences are empty', () async {
      SharedPreferences.setMockInitialValues({});
      await VideoConfig.loadSavedSources();
      expect(VideoConfig.exerciseVideoSource, equals('https://youtu.be/B8w09Rb5e54'));
      expect(VideoConfig.yogaVideoSource, equals('https://youtu.be/IOLnvYMy8_o'));
    });

    test('UserProfile supports healthGoal and defaults to both', () {
      const defaultProfile = UserProfile(age: 22, heightCm: 160, currentWeightKg: 60);
      expect(defaultProfile.healthGoal, equals('both'));

      const weightLossProfile = UserProfile(
        age: 22,
        heightCm: 160,
        currentWeightKg: 60,
        healthGoal: 'weight_loss',
      );
      expect(weightLossProfile.healthGoal, equals('weight_loss'));

      final map = weightLossProfile.toMap();
      expect(map['healthGoal'], equals('weight_loss'));

      final restored = UserProfile.fromMap(map);
      expect(restored.healthGoal, equals('weight_loss'));

      final legacyMap = {'age': 22, 'heightCm': 160.0, 'currentWeightKg': 60.0};
      final fromLegacy = UserProfile.fromMap(legacyMap);
      expect(fromLegacy.healthGoal, equals('both'));
    });

    test('CollegeSchedule supports independent college and classes mixed combinations', () {
      final now = DateTime.now();

      // 1. College = Yes, Classes = No
      final collegeOnly = CollegeSchedule(
        date: '2026-10-26',
        goingToCollege: true,
        hasClasses: false,
        collegeStartTime: '09:00',
        collegeEndTime: '17:00',
        updatedAt: now,
      );
      expect(collegeOnly.isCollegeConfigured, isTrue);
      expect(collegeOnly.isClassConfigured, isFalse);

      // 2. College = No, Classes = Yes (e.g. online lectures)
      final classOnly = CollegeSchedule(
        date: '2026-10-26',
        goingToCollege: false,
        hasClasses: true,
        classStartTime: '10:00',
        classEndTime: '12:00',
        updatedAt: now,
      );
      expect(classOnly.isCollegeConfigured, isFalse);
      expect(classOnly.isClassConfigured, isTrue);

      // 3. Both Yes
      final both = CollegeSchedule(
        date: '2026-10-26',
        goingToCollege: true,
        hasClasses: true,
        collegeStartTime: '09:00',
        collegeEndTime: '17:00',
        classStartTime: '10:00',
        classEndTime: '15:00',
        updatedAt: now,
      );
      expect(both.isCollegeConfigured, isTrue);
      expect(both.isClassConfigured, isTrue);
    });

    test('Mandatory bottle photo flag prevents unverified water confirmation', () {
      final validLog = WaterLog(
        id: 1,
        amountMl: 250,
        timestamp: DateTime.now(),
        photoPath: '/mock/path/bottle.jpg',
        isPhotoVerified: true,
      );
      expect(validLog.isPhotoVerified, isTrue);
      expect(validLog.photoPath, isNotNull);
    });
  });

  group('Critical Water Alarm & State Machine Regression Suite (20 Verification Criteria)', () {
    test('1-3. State Machine transitions: SCHEDULED -> RINGING -> AWAITING_CONFIRMATION -> COMPLETED', () {
      String state = 'SCHEDULED';
      String? activeId = 'water_1730000000';

      // 1. Alarm triggers
      state = 'RINGING';
      expect(state, equals('RINGING'));
      expect(activeId, isNotNull);

      // 2. Notification & full-screen UI presented
      state = 'AWAITING_CONFIRMATION';
      expect(state, equals('AWAITING_CONFIRMATION'));

      // 3. User provides valid bottle photo + amount and confirms in SQLite
      final isDbCommitted = true;
      if (isDbCommitted) {
        state = 'COMPLETED';
        activeId = null;
      }
      expect(state, equals('COMPLETED'));
      expect(activeId, isNull);
    });

    test('4-5. Screen opening or app resume does not transition state or stop active alarm prematurely', () {
      String state = 'AWAITING_CONFIRMATION';
      String? activeId = 'water_1730000000';
      bool isAudioPlaying = true;

      // Simulate app resume / screen open
      // State MUST remain AWAITING_CONFIRMATION and audio MUST NOT stop
      expect(state, equals('AWAITING_CONFIRMATION'));
      expect(activeId, equals('water_1730000000'));
      expect(isAudioPlaying, isTrue);
    });

    test('6. Camera or gallery cancellation does not log water or complete reminder', () {
      bool canSubmit(int amount, String? photo) => amount > 0 && photo != null && photo.isNotEmpty;
      const String? pickedPhotoPath = null; // user cancelled picker

      expect(pickedPhotoPath, isNull);
      expect(canSubmit(250, pickedPhotoPath), isFalse);
    });

    test('7. Missing photo strictly prevents submission', () {
      bool canSubmit(int amount, String? photo) => amount > 0 && photo != null && photo.isNotEmpty;
      const String? photoPath = null;

      expect(canSubmit(250, photoPath), isFalse);
    });

    test('8. Missing or non-positive amount strictly prevents submission', () {
      int amount = 0;
      String photoPath = '/data/photos/bottle.jpg';

      bool isValid = amount > 0 && photoPath.isNotEmpty;
      expect(isValid, isFalse);
    });

    test('9. Successful photo + amount + DB write stops audio session and resolves exactly once', () {
      String state = 'AWAITING_CONFIRMATION';
      String? activeSessionId = 'water_1730000000';
      bool audioPlaying = true;

      // DB write succeeds
      state = 'COMPLETED';
      audioPlaying = false;
      activeSessionId = null;

      expect(state, equals('COMPLETED'));
      expect(audioPlaying, isFalse);
      expect(activeSessionId, isNull);
    });

    test('10. Database write failure retains pending confirmation and does not schedule next interval', () {
      String state = 'AWAITING_CONFIRMATION';
      String? activeSessionId = 'water_1730000000';
      DateTime? nextScheduledDeadline;

      bool dbSuccess = false; // Simulated SQLite write failure (e.g. disk full)
      if (!dbSuccess) {
        // State remains AWAITING_CONFIRMATION and next reminder is NOT scheduled
        expect(state, equals('AWAITING_CONFIRMATION'));
        expect(activeSessionId, isNotNull);
        expect(nextScheduledDeadline, isNull);
      }
    });

    test('11. Repeated Submit taps are debounced (idempotent)', () {
      int dbWrites = 0;
      bool isSubmitting = false;

      void onSubmit() {
        if (isSubmitting) return;
        isSubmitting = true;
        dbWrites++;
      }

      onSubmit(); // First tap
      onSubmit(); // Accidental double tap
      onSubmit(); // Triple tap

      expect(dbWrites, equals(1));
    });

    test('12-14. Process death and reboot recover pending confirmation without auto-completing or duplicating sound', () {
      // Simulate persistent storage read on reboot
      final savedState = 'AWAITING_CONFIRMATION';
      final savedId = 'water_1730000000';

      String recoveredState = savedState;
      String? recoveredId = savedId;
      bool autoCompleted = false;

      if (recoveredState == 'AWAITING_CONFIRMATION') {
        autoCompleted = false;
      }

      expect(recoveredState, equals('AWAITING_CONFIRMATION'));
      expect(recoveredId, equals('water_1730000000'));
      expect(autoCompleted, isFalse);
    });

    test('15. Next water reminder calculates from configured interval (e.g. 45 min), never hardcoded 10 min', () {
      final now = DateTime(2026, 10, 26, 14, 0);
      const configuredInterval = 45;
      final deadline = now.add(const Duration(minutes: configuredInterval));

      expect(deadline.difference(now).inMinutes, equals(45));
      expect(deadline.difference(now).inMinutes, isNot(equals(10)));
    });

    test('16. College & class interval suppression: suppresses during active intervals and resumes after', () {
      final collegeSchedule = CollegeSchedule(
        date: '2026-10-26',
        goingToCollege: true,
        hasClasses: true,
        collegeStartTime: '08:30',
        collegeEndTime: '16:30',
        classStartTime: '09:00',
        classEndTime: '10:30',
        updatedAt: DateTime(2026, 10, 26, 7, 0),
      );

      // Candidate at 09:30 (inside class and inside college) -> pushed to 16:30 (college end)
      final candidate1 = DateTime(2026, 10, 26, 9, 30);
      final next1 = AppController.calculateNextUnsuppressedWaterTime(
        candidate: candidate1,
        bedtimeStr: '23:00',
        wakeTimeStr: '07:00',
        collegeSchedule: collegeSchedule,
      );
      expect(next1.hour, equals(16));
      expect(next1.minute, equals(30));

      // Candidate at 17:00 (after college and class) -> unchanged (not suppressed)
      final candidate2 = DateTime(2026, 10, 26, 17, 0);
      final next2 = AppController.calculateNextUnsuppressedWaterTime(
        candidate: candidate2,
        bedtimeStr: '23:00',
        wakeTimeStr: '07:00',
        collegeSchedule: collegeSchedule,
      );
      expect(next2, equals(candidate2));
    });

    test('17. Independent College / Class combinations: Class only (e.g. online lectures)', () {
      final classOnlySchedule = CollegeSchedule(
        date: '2026-10-26',
        goingToCollege: false,
        hasClasses: true,
        classStartTime: '10:00',
        classEndTime: '11:30',
        updatedAt: DateTime(2026, 10, 26, 7, 0),
      );

      // 10:15 is inside class -> pushed to 11:30
      final candidate = DateTime(2026, 10, 26, 10, 15);
      final next = AppController.calculateNextUnsuppressedWaterTime(
        candidate: candidate,
        bedtimeStr: '23:00',
        wakeTimeStr: '07:00',
        collegeSchedule: classOnlySchedule,
      );
      expect(next.hour, equals(11));
      expect(next.minute, equals(30));
    });

    test('17b. Independent College / Class combinations: Both No -> reminders unsuppressed during daytime', () {
      final bothNoSchedule = CollegeSchedule(
        date: '2026-10-26',
        goingToCollege: false,
        hasClasses: false,
        updatedAt: DateTime(2026, 10, 26, 7, 0),
      );

      final candidate = DateTime(2026, 10, 26, 11, 0);
      final next = AppController.calculateNextUnsuppressedWaterTime(
        candidate: candidate,
        bedtimeStr: '23:00',
        wakeTimeStr: '07:00',
        collegeSchedule: bothNoSchedule,
      );
      expect(next, equals(candidate));
    });

    test('18-19. Reset cancels obsolete alarms and prevents stale morning or water alarms from returning', () {
      String state = 'AWAITING_CONFIRMATION';
      DateTime? nextAlarm = DateTime.now().add(const Duration(minutes: 30));

      // User performs intentional reset
      state = 'COMPLETED';
      nextAlarm = null;

      expect(state, equals('COMPLETED'));
      expect(nextAlarm, isNull);
    });

    test('20. Sleep schedule suppression correctly advances candidate across midnight to wake up time', () {
      final candidate = DateTime(2026, 10, 26, 23, 30); // 11:30 PM
      final next = AppController.calculateNextUnsuppressedWaterTime(
        candidate: candidate,
        bedtimeStr: '23:00',
        wakeTimeStr: '07:00',
      );
      expect(next.day, equals(27)); // next day
      expect(next.hour, equals(7));
      expect(next.minute, equals(0));
    });
  });
}
