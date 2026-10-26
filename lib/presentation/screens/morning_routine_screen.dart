import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../controllers/app_controller.dart';

class MorningRoutineScreen extends StatefulWidget {
  final AppController controller;

  const MorningRoutineScreen({super.key, required this.controller});

  @override
  State<MorningRoutineScreen> createState() => _MorningRoutineScreenState();
}

class _MorningRoutineScreenState extends State<MorningRoutineScreen> {
  late bool _goingToCollege;
  late bool _hasClasses;

  TimeOfDay _collegeStartTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _collegeEndTime = const TimeOfDay(hour: 16, minute: 30);

  TimeOfDay _classStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _classEndTime = const TimeOfDay(hour: 10, minute: 30);

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.controller.todayCollegeSchedule;
    if (existing != null) {
      _goingToCollege = existing.goingToCollege;
      _hasClasses = existing.hasClasses;

      if (existing.collegeStartTime != null) {
        _collegeStartTime = _parseTimeOfDay(existing.collegeStartTime!) ?? _collegeStartTime;
      }
      if (existing.collegeEndTime != null) {
        _collegeEndTime = _parseTimeOfDay(existing.collegeEndTime!) ?? _collegeEndTime;
      }
      if (existing.classStartTime != null) {
        _classStartTime = _parseTimeOfDay(existing.classStartTime!) ?? _classStartTime;
      }
      if (existing.classEndTime != null) {
        _classEndTime = _parseTimeOfDay(existing.classEndTime!) ?? _classEndTime;
      }
    } else {
      _goingToCollege = true;
      _hasClasses = true;
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return null;
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('h:mm a').format(dt);
  }

  String _timeOfDayTo24h(TimeOfDay tod) {
    return '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
  }

  int _toMinutes(TimeOfDay tod) => tod.hour * 60 + tod.minute;

  bool get _hasCollegeSameTime => _toMinutes(_collegeStartTime) == _toMinutes(_collegeEndTime);
  bool get _hasClassSameTime => _toMinutes(_classStartTime) == _toMinutes(_classEndTime);

  bool get _hasIntervalConflict {
    if (!_goingToCollege || !_hasClasses) return false;
    final colStart = _toMinutes(_collegeStartTime);
    final colEnd = _toMinutes(_collegeEndTime);
    final clsStart = _toMinutes(_classStartTime);
    final clsEnd = _toMinutes(_classEndTime);

    // If class extends before college start or after college end (assuming same day)
    if (colStart < colEnd && clsStart < clsEnd) {
      return clsStart < colStart || clsEnd > colEnd;
    }
    return false;
  }

  Future<void> _pickTime({
    required TimeOfDay initialTime,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Future<void> _saveRoutine() async {
    final lang = widget.controller.language;

    if (_goingToCollege && _hasCollegeSameTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.get('collegeTimeTitle', lang: lang)}: ${AppStrings.get('sameTimeWarning', lang: lang)}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (_hasClasses && _hasClassSameTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.get('classTimeTitle', lang: lang)}: ${AppStrings.get('sameTimeWarning', lang: lang)}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.controller.recordCollegeSchedule(
        goingToCollege: _goingToCollege,
        hasClasses: _hasClasses,
        collegeStartTime: _goingToCollege ? _timeOfDayTo24h(_collegeStartTime) : null,
        collegeEndTime: _goingToCollege ? _timeOfDayTo24h(_collegeEndTime) : null,
        classStartTime: _hasClasses ? _timeOfDayTo24h(_classStartTime) : null,
        classEndTime: _hasClasses ? _timeOfDayTo24h(_classEndTime) : null,
      );

      if (mounted) {
        final message = _goingToCollege && _hasClasses
            ? 'Schedule saved! Reminders paused during campus (${_formatTimeOfDay(_collegeStartTime)}–${_formatTimeOfDay(_collegeEndTime)}) and classes (${_formatTimeOfDay(_classStartTime)}–${_formatTimeOfDay(_classEndTime)}).'
            : _goingToCollege
                ? 'Schedule saved! Reminders paused during campus (${_formatTimeOfDay(_collegeStartTime)}–${_formatTimeOfDay(_collegeEndTime)}).'
                : _hasClasses
                    ? 'Schedule saved! Reminders paused during classes (${_formatTimeOfDay(_classStartTime)}–${_formatTimeOfDay(_classEndTime)}).'
                    : 'Schedule saved! Reminders active as normal today.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.sagePrimary,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.controller.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('collegePromptTitle', lang: lang)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Info Card
            Card(
              color: AppColors.sageLight.withValues(alpha: 0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined, color: AppColors.softAmber, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get('collegePromptTitle', lang: lang),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.sageDark),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Plan your day so reminders stay silent during campus and study hours.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Question 1: Are you going to college today?
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school_outlined, color: AppColors.sagePrimary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppStrings.get('questionGoingToCollege', lang: lang),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(
                              child: Text(
                                AppStrings.get('yes', lang: lang),
                                style: TextStyle(
                                  fontWeight: _goingToCollege ? FontWeight.bold : FontWeight.normal,
                                  color: _goingToCollege ? Colors.white : AppColors.textDark,
                                ),
                              ),
                            ),
                            selected: _goingToCollege,
                            selectedColor: AppColors.sagePrimary,
                            onSelected: (val) {
                              if (val) setState(() => _goingToCollege = true);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(
                              child: Text(
                                AppStrings.get('no', lang: lang),
                                style: TextStyle(
                                  fontWeight: !_goingToCollege ? FontWeight.bold : FontWeight.normal,
                                  color: !_goingToCollege ? Colors.white : AppColors.textDark,
                                ),
                              ),
                            ),
                            selected: !_goingToCollege,
                            selectedColor: Colors.grey.shade700,
                            onSelected: (val) {
                              if (val) setState(() => _goingToCollege = false);
                            },
                          ),
                        ),
                      ],
                    ),

                    // College Time Interval (Visible only if Question 1 is Yes)
                    if (_goingToCollege) ...[
                      const Divider(height: 24),
                      Text(
                        AppStrings.get('collegeTimeTitle', lang: lang),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.sageDark),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimeTile(
                              label: AppStrings.get('start', lang: lang),
                              timeStr: _formatTimeOfDay(_collegeStartTime),
                              onTap: () => _pickTime(
                                initialTime: _collegeStartTime,
                                onPicked: (t) => _collegeStartTime = t,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTimeTile(
                              label: AppStrings.get('end', lang: lang),
                              timeStr: _formatTimeOfDay(_collegeEndTime),
                              onTap: () => _pickTime(
                                initialTime: _collegeEndTime,
                                onPicked: (t) => _collegeEndTime = t,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Campus time: ${_formatTimeOfDay(_collegeStartTime)}–${_formatTimeOfDay(_collegeEndTime)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Question 2: Do you have classes today? (ALWAYS VISIBLE!)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.menu_book_outlined, color: AppColors.sagePrimary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppStrings.get('questionHaveClasses', lang: lang),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(
                              child: Text(
                                AppStrings.get('yes', lang: lang),
                                style: TextStyle(
                                  fontWeight: _hasClasses ? FontWeight.bold : FontWeight.normal,
                                  color: _hasClasses ? Colors.white : AppColors.textDark,
                                ),
                              ),
                            ),
                            selected: _hasClasses,
                            selectedColor: AppColors.sagePrimary,
                            onSelected: (val) {
                              if (val) setState(() => _hasClasses = true);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(
                              child: Text(
                                AppStrings.get('no', lang: lang),
                                style: TextStyle(
                                  fontWeight: !_hasClasses ? FontWeight.bold : FontWeight.normal,
                                  color: !_hasClasses ? Colors.white : AppColors.textDark,
                                ),
                              ),
                            ),
                            selected: !_hasClasses,
                            selectedColor: Colors.grey.shade700,
                            onSelected: (val) {
                              if (val) setState(() => _hasClasses = false);
                            },
                          ),
                        ),
                      ],
                    ),

                    // Class Time Interval (Visible only if Question 2 is Yes)
                    if (_hasClasses) ...[
                      const Divider(height: 24),
                      Text(
                        AppStrings.get('classTimeTitle', lang: lang),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.sageDark),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimeTile(
                              label: AppStrings.get('start', lang: lang),
                              timeStr: _formatTimeOfDay(_classStartTime),
                              onTap: () => _pickTime(
                                initialTime: _classStartTime,
                                onPicked: (t) => _classStartTime = t,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTimeTile(
                              label: AppStrings.get('end', lang: lang),
                              timeStr: _formatTimeOfDay(_classEndTime),
                              onTap: () => _pickTime(
                                initialTime: _classEndTime,
                                onPicked: (t) => _classEndTime = t,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Class hours: ${_formatTimeOfDay(_classStartTime)}–${_formatTimeOfDay(_classEndTime)} (Water alerts silenced)',
                        style: const TextStyle(fontSize: 12, color: AppColors.sageDark, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sensible Validation & Interval Conflict Banner
            if (_hasIntervalConflict)
              Card(
                color: Colors.amber.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade900),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppStrings.get('conflictWarning', lang: lang),
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Save Routine Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveRoutine,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sagePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      AppStrings.get('saveRoutine', lang: lang),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeTile({
    required String label,
    required String timeStr,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const Icon(Icons.access_time, size: 16, color: AppColors.sagePrimary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
