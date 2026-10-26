import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../controllers/app_controller.dart';

class CollegeScheduleDialog extends StatefulWidget {
  final AppController controller;

  const CollegeScheduleDialog({super.key, required this.controller});

  static Future<void> show(BuildContext context, AppController controller) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CollegeScheduleDialog(controller: controller),
    );
  }

  @override
  State<CollegeScheduleDialog> createState() => _CollegeScheduleDialogState();
}

class _CollegeScheduleDialogState extends State<CollegeScheduleDialog> {
  int _step = 1; // 1: Going to college?, 2: Has classes?, 3: Set class time
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 30);
  bool _isSaving = false;

  String _formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('h:mm a').format(dt);
  }

  String _timeOfDayTo24h(TimeOfDay tod) {
    return '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _saveAndClose({
    required bool goingToCollege,
    required bool hasClasses,
    String? startStr,
    String? endStr,
  }) async {
    setState(() => _isSaving = true);
    try {
      await widget.controller.recordCollegeSchedule(
        goingToCollege: goingToCollege,
        hasClasses: hasClasses,
        classStartTime: startStr,
        classEndTime: endStr,
      );
      if (mounted) {
        Navigator.of(context).pop();
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

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.school, color: AppColors.sagePrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _step == 1
                  ? AppStrings.get('collegePromptTitle', lang: lang)
                  : _step == 2
                      ? AppStrings.get('classesPromptTitle', lang: lang)
                      : AppStrings.get('classHoursTitle', lang: lang),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: _buildContent(lang),
      actions: _buildActions(lang),
    );
  }

  Widget _buildContent(String lang) {
    if (_step == 1) {
      return Text(
        'Are you going to college today?',
        style: const TextStyle(fontSize: 16, color: AppColors.textDark),
      );
    } else if (_step == 2) {
      return Text(
        'Do you have classes today?',
        style: const TextStyle(fontSize: 16, color: AppColors.textDark),
      );
    } else {
      final summaryStr = 'Class time: ${_formatTimeOfDay(_startTime)}–${_formatTimeOfDay(_endTime)}.';
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.get('classHoursExplanation', lang: lang),
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickStartTime,
                  child: Column(
                    children: [
                      Text(AppStrings.get('start', lang: lang), style: const TextStyle(fontSize: 11)),
                      Text(
                        _formatTimeOfDay(_startTime),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('to', style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickEndTime,
                  child: Column(
                    children: [
                      Text(AppStrings.get('end', lang: lang), style: const TextStyle(fontSize: 11)),
                      Text(
                        _formatTimeOfDay(_endTime),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.sageBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.sagePrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summaryStr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  List<Widget> _buildActions(String lang) {
    if (_isSaving) {
      return const [
        Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
      ];
    }

    if (_step == 1) {
      return [
        TextButton(
          onPressed: () => _saveAndClose(goingToCollege: false, hasClasses: false),
          child: Text(AppStrings.get('no', lang: lang)),
        ),
        ElevatedButton(
          onPressed: () => setState(() => _step = 2),
          child: Text(AppStrings.get('yes', lang: lang)),
        ),
      ];
    } else if (_step == 2) {
      return [
        TextButton(
          onPressed: () => _saveAndClose(goingToCollege: true, hasClasses: false),
          child: Text(AppStrings.get('no', lang: lang)),
        ),
        ElevatedButton(
          onPressed: () => setState(() => _step = 3),
          child: Text(AppStrings.get('yes', lang: lang)),
        ),
      ];
    } else {
      return [
        TextButton(
          onPressed: () => setState(() => _step = 2),
          child: Text(AppStrings.get('back', lang: lang)),
        ),
        ElevatedButton(
          onPressed: () => _saveAndClose(
            goingToCollege: true,
            hasClasses: true,
            startStr: _timeOfDayTo24h(_startTime),
            endStr: _timeOfDayTo24h(_endTime),
          ),
          child: Text(AppStrings.get('confirmSchedule', lang: lang)),
        ),
      ];
    }
  }
}
