import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../domain/calculators/water_target_calculator.dart';
import '../../domain/models/college_schedule.dart';
import '../controllers/app_controller.dart';
import 'morning_routine_screen.dart';

class WaterScreen extends StatefulWidget {
  final AppController controller;

  const WaterScreen({super.key, required this.controller});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isModalOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdated);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingConfirmation();
    });
  }

  @override
  void didUpdateWidget(covariant WaterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdated);
      widget.controller.addListener(_onControllerUpdated);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingConfirmation();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdated);
    super.dispose();
  }

  void _onControllerUpdated() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingConfirmation();
    });
  }

  void _checkPendingConfirmation() {
    if (!mounted || _isModalOpen) return;
    final state = widget.controller.waterReminderState;
    if (state == 'AWAITING_CONFIRMATION' || state == 'RINGING') {
      _showWaterConfirmationDialog();
    }
  }

  String _formatTime(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }

  String _formatCountdown(int seconds) {
    if (seconds <= 0) return 'Due now';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')} min';
  }

  void _showWaterConfirmationDialog({String? initialPhotoPath}) {
    if (_isModalOpen) return;
    _isModalOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _WaterConfirmationModal(
        controller: widget.controller,
        initialPhotoPath: initialPhotoPath,
      ),
    ).whenComplete(() {
      _isModalOpen = false;
    });
  }

  Future<void> _takeCameraPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        _showWaterConfirmationDialog(initialPhotoPath: photo.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e. You can use manual entry.')),
        );
      }
    }
  }

  Future<void> _pickGalleryPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        _showWaterConfirmationDialog(initialPhotoPath: photo.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo picker error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.controller.language;
    final consumed = widget.controller.waterConsumedToday;
    final target = widget.controller.waterTargetToday;
    final remaining = WaterTargetCalculator.calculateRemainingMl(target, consumed);
    final progress = WaterTargetCalculator.calculateProgress(target, consumed);
    final sessions = widget.controller.todayWaterLogs.length;
    final lastTime = widget.controller.lastDrinkTime;
    final countdownStr = _formatCountdown(widget.controller.secondsUntilNextReminder);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('tabWater', lang: lang)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Main Hydration Summary Card
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get('waterConsumed', lang: lang),
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$consumed ml',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.softBlue),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.sageBackground,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.water_drop, color: AppColors.softBlue, size: 36),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppStrings.get('waterTarget', lang: lang),
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$target ml',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: AppColors.borderLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.softBlue),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$remaining ml ${AppStrings.get('waterRemaining', lang: lang).toLowerCase()}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricTile(
                        icon: Icons.check_circle_outline,
                        label: AppStrings.get('waterSessions', lang: lang),
                        value: '$sessions',
                      ),
                      _buildMetricTile(
                        icon: Icons.hourglass_top,
                        label: AppStrings.get('nextReminderIn', lang: lang),
                        value: countdownStr,
                      ),
                      _buildMetricTile(
                        icon: Icons.history,
                        label: AppStrings.get('lastDrinkAt', lang: lang),
                        value: lastTime != null ? _formatTime(lastTime) : '--',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Exact Alarm Permission Alert (if needed)
          _buildExactAlarmBanner(context, lang),

          // College / Class Schedule Status Card
          _buildCollegeScheduleCard(context, lang),
          const SizedBox(height: 16),

          // Action Buttons: Camera Photo, Gallery, Snooze, Skip
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: Text(AppStrings.get('takeBottlePhoto', lang: lang)),
                  onPressed: _takeCameraPhoto,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.photo_library_outlined),
                tooltip: AppStrings.get('chooseGallery', lang: lang),
                onPressed: _pickGalleryPhoto,
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.skip_next_outlined),
                  label: Text(AppStrings.get('skipSession', lang: lang)),
                  onPressed: () => widget.controller.skipReminder(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.edit_note, color: AppColors.textMuted),
                tooltip: 'Enter amount with bottle photo',
                onPressed: () => _showWaterConfirmationDialog(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Photo disclaimer note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceCardMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.textSubtle),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.get('waterPhotoDisclaimer', lang: lang),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSubtle),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Today's Water History
          Text(
            AppStrings.get('waterHistoryToday', lang: lang),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),

          if (widget.controller.todayWaterLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  AppStrings.get('noWaterYet', lang: lang),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ...widget.controller.todayWaterLogs.map((log) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.sageBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: log.photoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(
                              File(log.photoPath!),
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.water_drop, color: AppColors.softBlue),
                            ),
                          )
                        : const Icon(Icons.water_drop, color: AppColors.softBlue, size: 24),
                  ),
                  title: Text(
                    '${log.amountMl} ml',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    '${_formatTime(log.timestamp)}${log.isPhotoVerified ? ' • Photo verified' : ' • Manual'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.gentleCoral),
                    onPressed: () {
                      if (log.id != null) {
                        widget.controller.deleteWaterLog(log.id!);
                      }
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMetricTile({required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.sagePrimary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }

  bool _isCurrentlyInClass(CollegeSchedule s) {
    if (!s.isClassConfigured) return false;
    final now = DateTime.now();
    final startParts = s.classStartTime!.split(':');
    final endParts = s.classEndTime!.split(':');
    final startM = (int.tryParse(startParts[0]) ?? 0) * 60 + (int.tryParse(startParts[1]) ?? 0);
    final endM = (int.tryParse(endParts[0]) ?? 0) * 60 + (int.tryParse(endParts[1]) ?? 0);
    final currentM = now.hour * 60 + now.minute;
    if (endM >= startM) {
      return currentM >= startM && currentM < endM;
    } else {
      return currentM >= startM || currentM < endM;
    }
  }

  Widget _buildExactAlarmBanner(BuildContext context, String lang) {
    if (widget.controller.canScheduleExactAlarms) {
      return const SizedBox.shrink();
    }
    return Card(
      color: AppColors.peachBackground,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.softAmber),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.alarm_off, color: AppColors.softAmber, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('exactAlarmRequiredTitle', lang: lang),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.get('exactAlarmRequiredBody', lang: lang),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => widget.controller.openExactAlarmSettings(),
              child: Text(AppStrings.get('allowExactAlarms', lang: lang)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollegeScheduleCard(BuildContext context, String lang) {
    final schedule = widget.controller.todayCollegeSchedule;

    if (schedule == null) {
      return Card(
        color: AppColors.surfaceCardMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        child: ListTile(
          leading: const Icon(Icons.school_outlined, color: AppColors.sagePrimary),
          title: Text(
            AppStrings.get('classHoursCardTitle', lang: lang),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
          ),
          subtitle: Text(
            lang == 'hi'
                ? 'कक्षा के समय रिमाइंडर रोकने के लिए समय सेट करें'
                : 'Set class hours to pause water reminders during study',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          trailing: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MorningRoutineScreen(controller: widget.controller),
              ),
            ),
            child: Text(AppStrings.get('editSchedule', lang: lang)),
          ),
        ),
      );
    }

    if (schedule.isClassConfigured || schedule.isCollegeConfigured) {
      final inClass = _isCurrentlyInClass(schedule);
      final bgColor = inClass ? AppColors.peachBackground : AppColors.sageBackground;
      final borderColor = inClass ? AppColors.softAmber : AppColors.sagePrimary;
      final icon = inClass ? Icons.notifications_paused : Icons.school;
      final iconColor = inClass ? AppColors.softAmber : AppColors.sagePrimary;
      
      final String title;
      if (schedule.isClassConfigured && schedule.isCollegeConfigured) {
        title = inClass
            ? AppStrings.get('inClassWaterPaused', lang: lang)
            : '${AppStrings.get('classesScheduledToday', lang: lang)}: ${schedule.classStartTime}–${schedule.classEndTime} • College: ${schedule.collegeStartTime}–${schedule.collegeEndTime}';
      } else if (schedule.isClassConfigured) {
        title = inClass
            ? AppStrings.get('inClassWaterPaused', lang: lang)
            : '${AppStrings.get('classesScheduledToday', lang: lang)}: ${schedule.classStartTime}–${schedule.classEndTime}';
      } else {
        title = 'College Today: ${schedule.collegeStartTime}–${schedule.collegeEndTime}';
      }

      final subtitle = inClass
          ? (lang == 'hi'
              ? 'कक्षा का समय: ${schedule.classStartTime}–${schedule.classEndTime}। कक्षा समाप्त होने पर रिमाइंडर फिर शुरू होगा।'
              : 'Class time: ${schedule.classStartTime}–${schedule.classEndTime}. Catch-up reminder will arrive when class ends.')
          : (schedule.isClassConfigured
              ? (lang == 'hi'
                  ? 'कक्षा के दौरान पानी के रिमाइंडर शांत रहेंगे।'
                  : 'Reminders will be silenced during this class period.')
              : 'College hours active today.');

      return Card(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: inClass ? AppColors.softAmber : AppColors.sageDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MorningRoutineScreen(controller: widget.controller),
                      ),
                    ),
                    child: Text(AppStrings.get('editSchedule', lang: lang)),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => widget.controller.cancelCollegeSchedule(),
                    child: Text(
                      AppStrings.get('cancelSchedule', lang: lang),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Explicitly answered no college / no classes
    return Card(
      color: AppColors.surfaceCardMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: ListTile(
        leading: const Icon(Icons.beach_access, color: AppColors.softAmber),
        title: Text(
          AppStrings.get('noClassesToday', lang: lang),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
        ),
        subtitle: Text(
          lang == 'hi'
              ? 'पानी के रिमाइंडर सामान्य रूप से आते रहेंगे।'
              : 'Regular water reminders will arrive as scheduled.',
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        trailing: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MorningRoutineScreen(controller: widget.controller),
            ),
          ),
          child: Text(AppStrings.get('editSchedule', lang: lang)),
        ),
      ),
    );
  }
}

class _WaterConfirmationModal extends StatefulWidget {
  final AppController controller;
  final String? initialPhotoPath;

  const _WaterConfirmationModal({
    required this.controller,
    this.initialPhotoPath,
  });

  @override
  State<_WaterConfirmationModal> createState() => _WaterConfirmationModalState();
}

class _WaterConfirmationModalState extends State<_WaterConfirmationModal> {
  int _selectedAmount = 250;
  final TextEditingController _customController = TextEditingController();
  bool _isCustom = false;
  String? _photoPath;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _photoPath = widget.initialPhotoPath;
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _showPhotoPickerOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        setState(() => _photoPath = photo.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access photo: $e')),
        );
      }
    }
  }

  Future<void> _confirm() async {
    if (_isSubmitting) return;

    if (_photoPath == null || _photoPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bottle photo required: Please take a photo or select from gallery to confirm water intake.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount = _isCustom
        ? (int.tryParse(_customController.text.trim()) ?? 0)
        : _selectedAmount;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a valid water amount.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await widget.controller.confirmWaterDrink(
        amountMl: amount,
        photoPath: _photoPath,
        isPhotoVerified: true,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Great job! $amount ml logged with bottle photo.'),
              backgroundColor: AppColors.sagePrimary,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save water log. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.controller.language;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.get('confirmDrinkTitle', lang: lang),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.get('confirmDrinkSubtitle', lang: lang),
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),

          // Mandatory Bottle Photo Section
          if (_photoPath != null) ...[
            Center(
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_photoPath!),
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),
                  IconButton(
                    icon: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                    onPressed: () => setState(() => _photoPath = null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Change Photo', style: TextStyle(fontSize: 12)),
                onPressed: _showPhotoPickerOptions,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.softAmber.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.camera_alt, color: AppColors.softAmber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Bottle Photo Required',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'A photo of your water bottle is required before water intake can be recorded and reminders updated.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt, size: 16),
                          label: const Text('Take Photo', style: TextStyle(fontSize: 12)),
                          onPressed: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: const Text('From Gallery', style: TextStyle(fontSize: 12)),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Amount Options
          Text(
            AppStrings.get('selectAmountDrank', lang: lang),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(AppStrings.get('amount100', lang: lang)),
                selected: !_isCustom && _selectedAmount == 100,
                onSelected: (_) => setState(() {
                  _selectedAmount = 100;
                  _isCustom = false;
                }),
              ),
              ChoiceChip(
                label: Text(AppStrings.get('amount150', lang: lang)),
                selected: !_isCustom && _selectedAmount == 150,
                onSelected: (_) => setState(() {
                  _selectedAmount = 150;
                  _isCustom = false;
                }),
              ),
              ChoiceChip(
                label: Text(AppStrings.get('amount250', lang: lang)),
                selected: !_isCustom && _selectedAmount == 250,
                onSelected: (_) => setState(() {
                  _selectedAmount = 250;
                  _isCustom = false;
                }),
              ),
              ChoiceChip(
                label: Text(AppStrings.get('amount500', lang: lang)),
                selected: !_isCustom && _selectedAmount == 500,
                onSelected: (_) => setState(() {
                  _selectedAmount = 500;
                  _isCustom = false;
                }),
              ),
              ChoiceChip(
                label: Text(AppStrings.get('customAmount', lang: lang)),
                selected: _isCustom,
                onSelected: (_) => setState(() => _isCustom = true),
              ),
            ],
          ),

          if (_isCustom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Enter amount in ml (e.g. 350)',
                suffixText: 'ml',
              ),
            ),
          ],
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: (_photoPath != null && _photoPath!.isNotEmpty && !_isSubmitting) ? _confirm : null,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _photoPath != null
                        ? AppStrings.get('confirmDrinkButton', lang: lang)
                        : 'Take Bottle Photo to Confirm',
                  ),
          ),
        ],
      ),
    );
  }
}
