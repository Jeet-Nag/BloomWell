import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/video_config.dart';
import '../../core/localization/app_strings.dart';
import '../../domain/calculators/gps_tracker_calculator.dart';
import '../../domain/calculators/step_calculator.dart';
import '../../services/pedometer_service.dart';
import '../controllers/app_controller.dart';
import '../widgets/guided_session_player.dart';

class MoveScreen extends StatefulWidget {
  final AppController controller;

  const MoveScreen({super.key, required this.controller});

  @override
  State<MoveScreen> createState() => _MoveScreenState();
}

enum GuidedSessionStep {
  notStarted,
  exercisePlaying,
  exerciseRest,
  yogaPlaying,
  sessionCompleted,
}

class _MoveScreenState extends State<MoveScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  // Guided Session State
  GuidedSessionStep _sessionStep = GuidedSessionStep.notStarted;
  DateTime? _restDeadline;
  int _remainingRestSeconds = 300;
  Timer? _restTimer;

  static const String _prefRestDeadline = 'flutter.bloomwell_exercise_rest_deadline';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    widget.controller.addListener(_onControllerChange);

    VideoConfig.loadSavedSources();
    _checkAndRestoreRestDeadline();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRestoreRestDeadline();
    }
  }

  Future<void> _checkAndRestoreRestDeadline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deadlineStr = prefs.getString(_prefRestDeadline);

      if (deadlineStr != null) {
        final deadline = DateTime.tryParse(deadlineStr);
        if (deadline != null) {
          final now = DateTime.now();
          if (now.isBefore(deadline)) {
            // Still in 5-minute rest
            final diff = deadline.difference(now).inSeconds;
            setState(() {
              _sessionStep = GuidedSessionStep.exerciseRest;
              _restDeadline = deadline;
              _remainingRestSeconds = diff.clamp(0, 300);
            });
            _startRestTimer();
          } else {
            // Rest ended while app was in background / closed
            await prefs.remove(_prefRestDeadline);
            if (mounted) {
              setState(() {
                _sessionStep = GuidedSessionStep.yogaPlaying;
                _restDeadline = null;
                _remainingRestSeconds = 0;
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restDeadline == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      if (now.isBefore(_restDeadline!)) {
        final diff = _restDeadline!.difference(now).inSeconds;
        if (mounted) {
          setState(() {
            _remainingRestSeconds = diff.clamp(0, 300);
          });
        }
      } else {
        // Rest period finished! Advance automatically to Yoga!
        timer.cancel();
        _onRestFinished();
      }
    });
  }

  Future<void> _onExerciseCompleted() async {
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRestDeadline, deadline.toIso8601String());

    if (mounted) {
      setState(() {
        _sessionStep = GuidedSessionStep.exerciseRest;
        _restDeadline = deadline;
        _remainingRestSeconds = 300;
      });
      _startRestTimer();
    }
  }

  Future<void> _onSkipRest() async {
    _restTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefRestDeadline);

    if (mounted) {
      setState(() {
        _sessionStep = GuidedSessionStep.yogaPlaying;
        _restDeadline = null;
        _remainingRestSeconds = 0;
      });
    }
  }

  Future<void> _onRestFinished() async {
    _restTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefRestDeadline);

    if (mounted) {
      setState(() {
        _sessionStep = GuidedSessionStep.yogaPlaying;
        _restDeadline = null;
        _remainingRestSeconds = 0;
      });
    }
  }

  Future<void> _onYogaCompleted() async {
    // Record gentle workout session milestone into SQLite workout_logs
    try {
      final weight = widget.controller.profile?.currentWeightKg ?? 60.0;
      final calories = 30.0 * (3.5 * weight / 60.0); // 30 min session approx
      await widget.controller.recordWorkout(
        'guided_daily_session',
        'Daily Exercise & Restorative Yoga Session',
        1800,
        calories,
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _sessionStep = GuidedSessionStep.sessionCompleted;
      });
    }
  }

  void _onReplaySession() {
    setState(() {
      _sessionStep = GuidedSessionStep.notStarted;
      _restDeadline = null;
      _remainingRestSeconds = 300;
    });
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer?.cancel();
    widget.controller.removeListener(_onControllerChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.controller.language;

    if (_sessionStep == GuidedSessionStep.exercisePlaying) {
      return GuidedSessionPlayer(
        videoSource: VideoConfig.exerciseVideoSource,
        title: 'Exercise: Low-Impact Daily Workout',
        autoPlay: true,
        onCompleted: _onExerciseCompleted,
        onConfigureRequested: () => _showConfigureVideoDialog(context),
        builder: (context, player) => _buildScaffoldWithPlayer(player, lang),
      );
    } else if (_sessionStep == GuidedSessionStep.yogaPlaying) {
      return GuidedSessionPlayer(
        videoSource: VideoConfig.yogaVideoSource,
        title: 'Yoga: Restorative Session',
        autoPlay: true,
        onCompleted: _onYogaCompleted,
        onConfigureRequested: () => _showConfigureVideoDialog(context),
        builder: (context, player) => _buildScaffoldWithPlayer(player, lang),
      );
    }

    return _buildScaffoldWithPlayer(null, lang);
  }

  Widget _buildScaffoldWithPlayer(Widget? activePlayer, String lang) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('moveTitle', lang: lang)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.sageDark,
          indicatorColor: AppColors.sagePrimary,
          tabs: [
            Tab(text: AppStrings.get('dailyActivity', lang: lang), icon: const Icon(Icons.directions_walk)),
            Tab(text: AppStrings.get('workoutLibrary', lang: lang), icon: const Icon(Icons.fitness_center_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyActivityTab(lang),
          _buildExerciseLibraryTab(lang, activePlayer),
        ],
      ),
    );
  }

  // --- Tab 1: Automatic Daily Activity Dashboard ---
  Widget _buildDailyActivityTab(String lang) {
    final pedometer = widget.controller.pedometerService;
    final steps = pedometer.todaySteps;
    final goal = pedometer.dailyGoal;
    final progress = goal > 0 ? (steps / goal).clamp(0.0, 1.0) : 0.0;
    final height = widget.controller.profile?.heightCm;
    final weight = widget.controller.profile?.currentWeightKg;
    final distMeters = StepCalculator.estimateDistanceMeters(steps: steps, heightCm: height);
    final distStr = GpsTrackerCalculator.formatDistance(distMeters);
    final calories = StepCalculator.estimateCaloriesBurned(steps: steps, weightKg: weight);
    final activeMins = StepCalculator.estimateActiveMinutes(steps);
    final pedestrianStatus = pedometer.pedestrianStatus;
    final sensorStatus = pedometer.sensorStatus;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Permission or Hardware Warning Banner (if applicable)
        if (sensorStatus == PedometerSensorStatus.permissionDenied)
          Card(
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.amber.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.amber.shade900),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.get('sensorPermissionRequired', lang: lang),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'BloomWell uses your phone’s internal step sensor to count daily steps automatically.',
                          style: TextStyle(fontSize: 11, color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.controller.requestActivityPermission(),
                    child: const Text('Grant', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          )
        else if (sensorStatus == PedometerSensorStatus.sensorUnavailable)
          Card(
            color: Colors.grey.shade100,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textMuted),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hardware step counter sensor is not available on this device.',
                      style: TextStyle(fontSize: 12, color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Main Today's Steps Card
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Top status bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pedestrianStatus == 'walking' ? AppColors.sageBackground : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pedestrianStatus == 'walking'
                              ? AppColors.sagePrimary.withValues(alpha: 0.3)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            pedestrianStatus == 'walking' ? Icons.directions_walk : Icons.accessibility_new,
                            size: 14,
                            color: pedestrianStatus == 'walking' ? AppColors.sageDark : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pedestrianStatus == 'walking'
                                ? AppStrings.get('statusWalking', lang: lang)
                                : AppStrings.get('statusIdle', lang: lang),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: pedestrianStatus == 'walking' ? AppColors.sageDark : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Goal: $goal ${AppStrings.get('stepsUnit', lang: lang)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Step count display
                Text(
                  '$steps',
                  style: const TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sageDark,
                    height: 1.0,
                  ),
                ),
                Text(
                  AppStrings.get('todaySteps', lang: lang).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 14),

                // Linear progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sagePrimary),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toInt()}% completed',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.sageDark),
                    ),
                    Text(
                      steps >= goal ? 'Goal Met! 🎉' : '${goal - steps} steps to goal',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Quick Goal Picker Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Goal: ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    for (final g in [4000, 6000, 8000, 10000])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text('${g ~/ 1000}k', style: const TextStyle(fontSize: 11)),
                          selected: goal == g,
                          onSelected: (_) => widget.controller.setDailyStepGoal(g),
                          selectedColor: AppColors.sagePrimary,
                          labelStyle: TextStyle(
                            color: goal == g ? Colors.white : AppColors.textDark,
                            fontWeight: goal == g ? FontWeight.bold : FontWeight.normal,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Honest Metrics 4-Box Grid
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.straighten,
                value: distStr,
                label: AppStrings.get('estimatedDistance', lang: lang),
                footnote: '*0.415× height stride',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.timer_outlined,
                value: '$activeMins min',
                label: AppStrings.get('activeMinutes', lang: lang),
                footnote: '*~100 steps/min cadence',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.local_fire_department_outlined,
                value: '~${calories.toInt()} kcal',
                label: AppStrings.get('estimatedCalories', lang: lang),
                footnote: '*0.04 kcal/step at weight',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.flag_outlined,
                value: steps >= goal ? 'Achieved!' : '${goal - steps}',
                label: 'Remaining Steps',
                footnote: 'Low-impact wellness',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Weekly Trends Section (Past 7 Days from SQLite)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.get('weeklyTrends', lang: lang),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const Text(
              'Past 7 Days',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (widget.controller.weeklyActivityLogs.isEmpty)
          Card(
            color: Colors.white,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Today is your first tracked day! Your 7-day trend will build automatically as you walk.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ),
          )
        else
          Card(
            color: Colors.white,
            child: Column(
              children: [
                for (final log in widget.controller.weeklyActivityLogs)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 85,
                          child: Text(
                            log.date,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: log.progressPercent,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                log.isGoalAchieved ? AppColors.sagePrimary : Colors.amber.shade700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 65,
                          child: Text(
                            '${log.steps} st',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.sageDark),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Device-Adaptive Battery Optimization Guide Card
        Builder(
          builder: (context) {
            final guidance = widget.controller.deviceInfoService.getBatteryGuidance(language: lang);
            return Card(
              color: Colors.blueGrey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blueGrey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.battery_charging_full, size: 18, color: Colors.blueGrey.shade800),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  guidance.manufacturerDisplayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.blueGrey.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: guidance.isBatteryOptimizationIgnored
                                ? Colors.green.shade100
                                : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: guidance.isBatteryOptimizationIgnored
                                  ? Colors.green.shade300
                                  : Colors.amber.shade300,
                            ),
                          ),
                          child: Text(
                            guidance.isBatteryOptimizationIgnored ? 'Optimal' : 'Restricted',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: guidance.isBatteryOptimizationIgnored
                                  ? Colors.green.shade800
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      guidance.statusLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade900),
                    ),
                    const SizedBox(height: 8),
                    ...guidance.steps.map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700)),
                            Expanded(
                              child: Text(
                                step,
                                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (guidance.hasAction)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final success = await widget.controller.deviceInfoService.openBatterySettings();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? AppStrings.get('batteryOptimizationSettingsOpened', lang: lang)
                                        : AppStrings.get('batteryOptimizationSettingsFailed', lang: lang),
                                  ),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.settings_outlined, size: 16),
                          label: Text(
                            AppStrings.get('openBatterySettings', lang: lang),
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueGrey.shade900,
                            side: BorderSide(color: Colors.blueGrey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      guidance.caveat,
                      style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.blueGrey.shade600),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Educational Physiological Guidance
        const Text(
          'BloomWell uses your device’s native hardware step-counter sensor. Data remains 100% offline on your device with zero cloud sync and zero battery-draining continuous GPS.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textSubtle),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String label,
    required String footnote,
  }) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.sagePrimary),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text(footnote, style: const TextStyle(fontSize: 9, color: AppColors.textSubtle)),
          ],
        ),
      ),
    );
  }

  // --- Tab 1: Exercise Library (Today's Two-Video Guided Session) ---
  Widget _buildExerciseLibraryTab(String lang, Widget? activePlayer) {
    final isHindi = lang == 'hi';

    return SingleChildScrollView(
      key: const PageStorageKey<String>('exercise_library_scroll'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Heading
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.get('todaysSession', lang: lang),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.get('sessionSubtitle', lang: lang),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppColors.sageDark),
                tooltip: 'Video Configuration',
                onPressed: () => _showConfigureVideoDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // CARD 1: EXERCISE
          _buildExerciseCard(lang, isHindi, activePlayer),
          const SizedBox(height: 16),

          // CARD 1.5: 5-MINUTE REST CARD (Visible during rest interval)
          if (_sessionStep == GuidedSessionStep.exerciseRest) ...[
            _buildRestCard(lang, isHindi),
            const SizedBox(height: 16),
          ],

          // CARD 2: YOGA
          _buildYogaCard(lang, isHindi, activePlayer),
          const SizedBox(height: 16),

          // CARD 3: SESSION COMPLETED STATE
          if (_sessionStep == GuidedSessionStep.sessionCompleted)
            _buildCompletedSessionCard(lang, isHindi),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // --- CARD 1: EXERCISE ---
  Widget _buildExerciseCard(String lang, bool isHindi, Widget? activePlayer) {
    final isPlaying = _sessionStep == GuidedSessionStep.exercisePlaying;
    final isDone = _sessionStep == GuidedSessionStep.exerciseRest ||
        _sessionStep == GuidedSessionStep.yogaPlaying ||
        _sessionStep == GuidedSessionStep.sessionCompleted;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPlaying
              ? AppColors.sagePrimary
              : (isDone ? AppColors.sageDark.withValues(alpha: 0.5) : AppColors.borderLight),
          width: isPlaying ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDone ? AppColors.sageBackground : AppColors.softAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isDone ? 'COMPLETED ✓' : 'STEP 1 • EXERCISE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDone ? AppColors.sageDark : AppColors.softAmber,
                    ),
                  ),
                ),
                const Spacer(),
                if (isDone)
                  const Icon(Icons.check_circle, color: AppColors.sageDark, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isHindi ? 'दैनिक व्यायाम (Daily Exercise)' : 'Daily Low-Impact Exercise',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              isHindi
                  ? 'ऊर्जा, इंसुलिन संवेदनशीलता और मेटाबॉलिक स्वास्थ्य के लिए हल्का कार्डियो।'
                  : 'Low-impact aerobic movement to boost insulin sensitivity and gentle metabolism.',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
            ),
            const SizedBox(height: 14),

            if (_sessionStep == GuidedSessionStep.notStarted) ...[
              // Compact preview with prominent Play button
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCardMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sagePrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 22, color: Colors.white),
                    label: Text(
                      AppStrings.get('playExercise', lang: lang),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: () {
                      setState(() {
                        _sessionStep = GuidedSessionStep.exercisePlaying;
                      });
                    },
                  ),
                ),
              ),
            ] else if (isPlaying) ...[
              // Active player
              activePlayer ??
                  GuidedSessionPlayer(
                    videoSource: VideoConfig.exerciseVideoSource,
                    title: 'Exercise: Low-Impact Daily Workout',
                    autoPlay: true,
                    onCompleted: _onExerciseCompleted,
                    onConfigureRequested: () => _showConfigureVideoDialog(context),
                  ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _onExerciseCompleted,
                  icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.sageDark),
                  label: Text(
                    isHindi ? 'व्यायाम पूर्ण चिन्हित करें ✓' : 'Mark Exercise Finished ✓',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.sageDark),
                  ),
                ),
              ),
            ] else ...[
              // Collapsed completed status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sageBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.sageDark, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isHindi ? 'व्यायाम पूरा हुआ! बहुत बढ़िया।' : 'Exercise completed! Great effort.',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.sageDark),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _sessionStep = GuidedSessionStep.exercisePlaying;
                        });
                      },
                      child: Text(isHindi ? 'पुनः देखें' : 'Watch Again', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- CARD 1.5: 5-MINUTE REST ---
  Widget _buildRestCard(String lang, bool isHindi) {
    final mins = (_remainingRestSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingRestSeconds % 60).toString().padLeft(2, '0');
    final progress = _remainingRestSeconds / 300.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lavenderLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mutedLavender.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.mutedLavender.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.spa, color: AppColors.mutedLavender, size: 22),
              const SizedBox(width: 8),
              Text(
                AppStrings.get('restTitle', lang: lang),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.get('restSubtitle', lang: lang),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.3),
          ),
          const SizedBox(height: 18),

          // Big Countdown Display with circular indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 8,
                  backgroundColor: Colors.white,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.mutedLavender),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$mins:$secs',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    isHindi ? 'शेष समय' : 'Remaining',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Skip Rest Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sagePrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.skip_next, size: 20, color: Colors.white),
            label: Text(
              AppStrings.get('skipRest', lang: lang),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            onPressed: _onSkipRest,
          ),
        ],
      ),
    );
  }

  // --- CARD 2: YOGA ---
  Widget _buildYogaCard(String lang, bool isHindi, Widget? activePlayer) {
    final isLocked = _sessionStep == GuidedSessionStep.notStarted ||
        _sessionStep == GuidedSessionStep.exercisePlaying;
    final isResting = _sessionStep == GuidedSessionStep.exerciseRest;
    final isPlaying = _sessionStep == GuidedSessionStep.yogaPlaying;
    final isDone = _sessionStep == GuidedSessionStep.sessionCompleted;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPlaying
              ? AppColors.softBlue
              : (isDone ? AppColors.sageDark.withValues(alpha: 0.5) : AppColors.borderLight),
          width: isPlaying ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.sageBackground
                        : (isLocked ? Colors.grey.withValues(alpha: 0.15) : AppColors.softBlue.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isDone ? 'COMPLETED ✓' : 'STEP 2 • YOGA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDone ? AppColors.sageDark : (isLocked ? AppColors.textSubtle : AppColors.softBlue),
                    ),
                  ),
                ),
                const Spacer(),
                if (isDone)
                  const Icon(Icons.check_circle, color: AppColors.sageDark, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isHindi ? 'पुनर्स्थापनात्मक योग (Restorative Yoga)' : 'Restorative & Relaxing Yoga',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isLocked ? AppColors.textMuted : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isHindi
                  ? 'तनाव कम करने, कोर्टिसोल नियंत्रित करने और शरीर के लचीलेपन के लिए कोमल आसन।'
                  : 'Gentle stretching and asanas to lower cortisol, reduce stress, and restore balance.',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
            ),
            const SizedBox(height: 14),

            if (isLocked) ...[
              // Locked until Exercise & Rest complete
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCardMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, color: AppColors.textSubtle, size: 26),
                      const SizedBox(height: 6),
                      Text(
                        isHindi ? 'व्यायाम और 5-मिनट विश्राम के बाद अनलॉक होगा' : 'Unlocks after Exercise and 5-min rest',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSubtle),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (isResting) ...[
              // Up next cue
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.sageBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sagePrimary.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_bottom, color: AppColors.sageDark, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        isHindi ? 'विश्राम समाप्त होने पर स्वतः शुरू होगा...' : 'Will start automatically after rest...',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.sageDark),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (isPlaying) ...[
              // Active Yoga Player
              activePlayer ??
                  GuidedSessionPlayer(
                    videoSource: VideoConfig.yogaVideoSource,
                    title: 'Yoga: Restorative Session',
                    autoPlay: true,
                    onCompleted: _onYogaCompleted,
                    onConfigureRequested: () => _showConfigureVideoDialog(context),
                  ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _onYogaCompleted,
                  icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.softBlue),
                  label: Text(
                    isHindi ? 'योग पूर्ण चिन्हित करें ✓' : 'Mark Yoga Finished ✓',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.softBlue),
                  ),
                ),
              ),
            ] else ...[
              // Collapsed completed status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sageBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.sageDark, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isHindi ? 'योग सत्र पूरा हुआ! मन शांत और तरोताजा।' : 'Yoga completed! Mind and body restored.',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.sageDark),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _sessionStep = GuidedSessionStep.yogaPlaying;
                        });
                      },
                      child: Text(isHindi ? 'पुनः देखें' : 'Watch Again', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- CARD 3: COMPLETED SESSION ---
  Widget _buildCompletedSessionCard(String lang, bool isHindi) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.sageBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sagePrimary.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.sagePrimary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_outlined, color: AppColors.softAmber, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.get('sessionCompleted', lang: lang),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.sageDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.get('sessionCompletedDesc', lang: lang),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.35),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sagePrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.replay, size: 20, color: Colors.white),
            label: Text(
              AppStrings.get('replaySession', lang: lang),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            onPressed: _onReplaySession,
          ),
        ],
      ),
    );
  }

  // Dialog to easily paste or configure video URLs at runtime
  void _showConfigureVideoDialog(BuildContext context) {
    final exerciseCtrl = TextEditingController(text: VideoConfig.exerciseVideoSource);
    final yogaCtrl = TextEditingController(text: VideoConfig.yogaVideoSource);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configure Video URLs', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload your videos to YouTube as "Unlisted" (free no-cost hosting) and paste their links here. Direct MP4 links are also supported.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: exerciseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Exercise Video URL (YouTube / MP4)',
                  hintText: 'https://youtu.be/...',
                  prefixIcon: Icon(Icons.fitness_center),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: yogaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Yoga Video URL (YouTube / MP4)',
                  hintText: 'https://youtu.be/...',
                  prefixIcon: Icon(Icons.spa),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await VideoConfig.saveSources(
                exerciseUrl: exerciseCtrl.text.trim(),
                yogaUrl: yogaCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            child: const Text('Save & Apply'),
          ),
        ],
      ),
    );
  }
}
