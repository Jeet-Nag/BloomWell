import '../models/weight_entry.dart';

class WeightSummary {
  final double currentWeight;
  final double? baselineWeight;
  final double? changeFromPrevious;
  final double? changeFromBaseline;
  final int daysSinceLastEntry;
  final int daysUntilNextCheckin;
  final bool isCheckinDue;
  final String statusMessage;

  const WeightSummary({
    required this.currentWeight,
    this.baselineWeight,
    this.changeFromPrevious,
    this.changeFromBaseline,
    required this.daysSinceLastEntry,
    required this.daysUntilNextCheckin,
    required this.isCheckinDue,
    required this.statusMessage,
  });
}

class WeightMetricsCalculator {
  static const int checkinIntervalDays = 15;

  /// Computes neutral, non-judgmental weight metrics from chronological entries.
  static WeightSummary computeSummary(List<WeightEntry> entries, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    if (entries.isEmpty) {
      return const WeightSummary(
        currentWeight: 0.0,
        daysSinceLastEntry: 0,
        daysUntilNextCheckin: checkinIntervalDays,
        isCheckinDue: true,
        statusMessage: 'Ready for baseline measurement.',
      );
    }

    // Sort ascending by timestamp
    final sorted = List<WeightEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final baseline = sorted.first.weightKg;
    final latest = sorted.last;
    final currentWeight = latest.weightKg;

    double? changeFromPrevious;
    if (sorted.length > 1) {
      final prev = sorted[sorted.length - 2].weightKg;
      changeFromPrevious = currentWeight - prev;
    }

    final double changeFromBaseline = currentWeight - baseline;

    final diffDays = currentTime.difference(latest.timestamp).inDays;
    final daysUntilNext = (checkinIntervalDays - diffDays).clamp(0, checkinIntervalDays);
    final isDue = diffDays >= checkinIntervalDays;

    String status;
    if (sorted.length == 1) {
      status = 'Baseline recorded. Next mindful check-in in $daysUntilNext days.';
    } else if (isDue) {
      status = '15-day check-in window open. Record whenever convenient.';
    } else {
      status = '$daysUntilNext days remaining until your next 15-day check-in.';
    }

    return WeightSummary(
      currentWeight: currentWeight,
      baselineWeight: baseline,
      changeFromPrevious: changeFromPrevious,
      changeFromBaseline: changeFromBaseline,
      daysSinceLastEntry: diffDays,
      daysUntilNextCheckin: daysUntilNext,
      isCheckinDue: isDue,
      statusMessage: status,
    );
  }

  /// Formats a change in weight neutrally with signed prefix.
  /// Example: "+0.5 kg" or "-0.8 kg" or "0.0 kg"
  static String formatDelta(double? delta) {
    if (delta == null) return '--';
    if (delta.abs() < 0.05) return '0.0 kg (steady)';
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)} kg';
  }

  /// Generates CSV string for local export initiated by user.
  static String generateCsv(List<WeightEntry> entries, {String? clientName}) {
    final buffer = StringBuffer();
    if (clientName != null && clientName.trim().isNotEmpty) {
      buffer.writeln('# BloomWell Progress Report - Client: ${clientName.trim()}');
      buffer.writeln('# Export Date: ${DateTime.now().toIso8601String().split('T').first}');
    }
    buffer.writeln('Date,Weight (kg),Notes');
    final sorted = List<WeightEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final e in sorted) {
      final dateStr = e.timestamp.toIso8601String().split('T').first;
      final cleanNotes = (e.notes ?? '').replaceAll(',', ' ').replaceAll('\n', ' ');
      buffer.writeln('$dateStr,${e.weightKg.toStringAsFixed(1)},"$cleanNotes"');
    }
    return buffer.toString();
  }
}
