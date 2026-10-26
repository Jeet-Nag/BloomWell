class WaterTargetCalculator {
  /// Calculates a conservative, safe daily water target in milliliters.
  ///
  /// Guided by dietary reference standards:
  /// - Baseline: ~30-35 ml per kg of body weight for healthy adults.
  /// - Adjustments: +250-400 ml for hot weather / tropical climate.
  /// - Adjustments: +200-350 ml for active movement (>30 min).
  /// - Safety Caps: Never exceeds 3000 ml for beginners; safe floor of 1500 ml.
  /// - Kidney/Heart restrictions: Caps strictly at conservative 1500 ml with advice to follow clinician orders.
  /// - Note: PCOD does not require higher or lower hydration.
  static int calculateDailyTargetMl({
    required double weightKg,
    required int age,
    String activityLevel = 'light',
    bool isHotClimate = false,
    int exerciseDurationMinutes = 0,
    bool hasFluidRestriction = false,
  }) {
    if (hasFluidRestriction) {
      return 1500; // Strict conservative ceiling for medically restricted individuals
    }

    // Baseline: 32 ml/kg for general adult hydration
    double target = weightKg * 32.0;

    // Floor and initial clamping
    if (target < 1600) target = 1600;

    // Activity level adjustment
    if (activityLevel == 'moderate') {
      target += 250;
    } else if (activityLevel == 'active') {
      target += 400;
    }

    // Climate adjustment
    if (isHotClimate) {
      target += 300;
    }

    // Exercise duration adjustment (conservative 200 ml per 30 mins)
    if (exerciseDurationMinutes > 0) {
      final additional = (exerciseDurationMinutes / 30.0) * 150.0;
      target += additional.clamp(0.0, 450.0);
    }

    // Safe physiological upper bound (avoiding overhydration / hyponatremia)
    if (target > 3000) {
      target = 3000;
    }

    // Round to nearest 50 ml for practical usability
    return ((target / 50.0).round()) * 50;
  }

  /// Calculates remaining ml, safely clamped at 0.
  static int calculateRemainingMl(int targetMl, int consumedMl) {
    final remaining = targetMl - consumedMl;
    return remaining < 0 ? 0 : remaining;
  }

  /// Percentage progress from 0.0 to 1.0 (or greater if exceeded)
  static double calculateProgress(int targetMl, int consumedMl) {
    if (targetMl <= 0) return 0.0;
    return (consumedMl / targetMl).clamp(0.0, 1.5);
  }
}
