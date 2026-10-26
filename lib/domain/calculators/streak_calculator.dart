class StreakCalculator {
  /// Calculates consecutive active days up to today (or yesterday if today is still in progress).
  ///
  /// Takes a set or list of active event dates (dates where water, meal, workout, or sleep was logged).
  static int calculateStreak(List<DateTime> activeDates, {DateTime? referenceDate}) {
    if (activeDates.isEmpty) return 0;

    final ref = referenceDate ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Normalize unique calendar days in descending order
    final uniqueDays = activeDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (uniqueDays.isEmpty) return 0;

    // Check if streak includes today or yesterday
    final mostRecent = uniqueDays.first;
    if (mostRecent != today && mostRecent != yesterday) {
      // Streak broken, but zero shame
      return 0;
    }

    int streak = 0;
    DateTime expectedDay = mostRecent;

    for (final day in uniqueDays) {
      if (day == expectedDay) {
        streak++;
        expectedDay = expectedDay.subtract(const Duration(days: 1));
      } else if (day.isBefore(expectedDay)) {
        break; // Gap found
      }
    }

    return streak;
  }
}
