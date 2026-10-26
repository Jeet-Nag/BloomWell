class StepCalculator {
  /// Default female stride length in meters if height is not provided
  static const double defaultStrideLengthMeters = 0.70;

  /// Default baseline weight for calorie reference in kg
  static const double defaultWeightKg = 60.0;

  /// Calculates individual stride length in meters based on height.
  /// Uses the standard physiological ratio: height * 0.415 for women.
  static double calculateStrideLengthMeters(double? heightCm) {
    if (heightCm == null || heightCm < 100.0 || heightCm > 250.0) {
      return defaultStrideLengthMeters;
    }
    return (heightCm * 0.415) / 100.0;
  }

  /// Estimates walking distance in meters from step count and user height.
  static double estimateDistanceMeters({
    required int steps,
    double? heightCm,
  }) {
    if (steps <= 0) return 0.0;
    final stride = calculateStrideLengthMeters(heightCm);
    return steps * stride;
  }

  /// Estimates walking calories burned from step count and user weight.
  /// An average 60kg adult burns ~0.04 kcal per step (~40 kcal per 1,000 steps).
  /// Scales proportionally with body weight.
  static double estimateCaloriesBurned({
    required int steps,
    double? weightKg,
  }) {
    if (steps <= 0) return 0.0;
    final weight = (weightKg != null && weightKg >= 30.0 && weightKg <= 250.0)
        ? weightKg
        : defaultWeightKg;
    const baseKcalPerStepAt60Kg = 0.04;
    return steps * baseKcalPerStepAt60Kg * (weight / defaultWeightKg);
  }

  /// Estimates active walking minutes based on standard brisk walking cadence (~100 steps/min).
  static int estimateActiveMinutes(int steps) {
    if (steps < 100) return 0;
    return (steps / 100.0).round();
  }
}
