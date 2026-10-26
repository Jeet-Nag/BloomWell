import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../domain/calculators/water_target_calculator.dart';
import '../../domain/calculators/weight_metrics_calculator.dart';
import '../controllers/app_controller.dart';

class HomeDashboardScreen extends StatelessWidget {
  final AppController controller;
  final Function(int tabIndex) onNavigateToTab;

  const HomeDashboardScreen({
    super.key,
    required this.controller,
    required this.onNavigateToTab,
  });

  String _formatCountdown(int seconds) {
    if (seconds <= 0) return 'Due now';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')} min';
  }

  String _getGreeting(String lang) {
    final hour = DateTime.now().hour;
    final base = hour < 12
        ? AppStrings.get('greetingMorning', lang: lang)
        : (hour < 17
            ? AppStrings.get('greetingAfternoon', lang: lang)
            : AppStrings.get('greetingEvening', lang: lang));
    final name = controller.profile?.name.trim() ?? '';
    return name.isNotEmpty ? '$base, $name' : base;
  }

  @override
  Widget build(BuildContext context) {
    final lang = controller.language;
    final profile = controller.profile;
    final consumed = controller.waterConsumedToday;
    final target = controller.waterTargetToday;
    final progress = WaterTargetCalculator.calculateProgress(target, consumed);
    final weightSummary = controller.weightSummary;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(lang),
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.normal),
            ),
            Text(
              AppStrings.get('appName', lang: lang),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.sageDark),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined, color: AppColors.textDark),
            tooltip: 'Settings',
            onPressed: () => onNavigateToTab(5),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.initialize(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Streak & Consistency Card
            _buildStreakBanner(lang),
            const SizedBox(height: 12),

            // Today's Water Progress Card
            _buildWaterCard(context, lang, consumed, target, progress),
            const SizedBox(height: 12),

            // 15-Day Weight Milestone Card
            _buildWeightCard(context, lang, weightSummary),
            const SizedBox(height: 12),

            // Sleep & Rest Schedule Card
            _buildSleepCard(context, lang, profile),
            const SizedBox(height: 20),

            // Medical Disclaimer Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCardMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                AppStrings.get('medicalDisclaimer', lang: lang),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.textSubtle, height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakBanner(String lang) {
    final streak = controller.streakDays;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.sageBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sageLight.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt, color: AppColors.softAmber, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.get('currentStreak', lang: lang)}: $streak ${AppStrings.get('days', lang: lang)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.sageDark),
                ),
                Text(
                  streak == 0
                      ? 'Log water, a meal, or gentle movement to begin your habit blossom.'
                      : 'Consistent self-care supports hormonal and metabolic balance.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterCard(
    BuildContext context,
    String lang,
    int consumed,
    int target,
    double progress,
  ) {
    final remaining = WaterTargetCalculator.calculateRemainingMl(target, consumed);
    final countdownStr = _formatCountdown(controller.secondsUntilNextReminder);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop, color: AppColors.softBlue, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.get('todayWater', lang: lang),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: AppColors.mutedLavender),
                      const SizedBox(width: 4),
                      Text(
                        countdownStr,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A3E66)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress Bar & Counts
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: AppColors.borderLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.softBlue),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$consumed / $target ml (${(progress * 100).toInt()}%)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                ),
                Text(
                  '$remaining ml ${AppStrings.get('waterRemaining', lang: lang).toLowerCase()}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(AppStrings.get('quickLogWater', lang: lang)),
                    onPressed: () => onNavigateToTab(1), // Water Tab
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightCard(
    BuildContext context,
    String lang,
    WeightSummary? summary,
  ) {
    final currentWeight = summary?.currentWeight ?? 0.0;
    final changeStr = WeightMetricsCalculator.formatDelta(summary?.changeFromPrevious);
    final daysUntil = summary?.daysUntilNextCheckin ?? 15;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.monitor_weight_outlined, color: AppColors.sagePrimary, size: 20),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          AppStrings.get('nextWeightCheck', lang: lang),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigateToTab(4), // Progress Tab
                  child: Text(AppStrings.get('weightHistory', lang: lang), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentWeight > 0 ? '$currentWeight kg' : '--',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        '${AppStrings.get('changeSinceLast', lang: lang)}: $changeStr',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCardMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$daysUntil',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.sageDark),
                      ),
                      Text(
                        AppStrings.get('daysUntilWeightCheck', lang: lang),
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepCard(BuildContext context, String lang, dynamic profile) {
    final bedtime = profile?.bedtime ?? '23:00';
    final waketime = profile?.wakeUpTime ?? '07:00';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.nightlight_round, color: AppColors.mutedLavender, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('sleepTitle', lang: lang),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Bedtime $bedtime • Wake up $waketime',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.alarm_outlined, color: AppColors.sagePrimary),
              onPressed: () => onNavigateToTab(5), // Settings
            ),
          ],
        ),
      ),
    );
  }
}
