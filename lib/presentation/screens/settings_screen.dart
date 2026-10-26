import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../domain/calculators/weight_metrics_calculator.dart';
import '../controllers/app_controller.dart';
import 'selfie_verification_screen.dart';
import 'morning_routine_screen.dart';
import '../widgets/update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final AppController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PermissionStatus? _notifStatus;
  PermissionStatus? _activityStatus;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notif = await Permission.notification.status;
    final activity = await Permission.activityRecognition.status;
    if (mounted) {
      setState(() {
        _notifStatus = notif;
        _activityStatus = activity;
      });
    }
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('confirmResetTitle', lang: widget.controller.language)),
        content: Text(AppStrings.get('confirmResetBody', lang: widget.controller.language)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get('cancel', lang: widget.controller.language)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gentleCoral),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.controller.resetAllData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All local data was erased.')),
                );
              }
            },
            child: Text(AppStrings.get('confirmResetButton', lang: widget.controller.language)),
          ),
        ],
      ),
    );
  }

  void _showDiagnostics() {
    final profile = widget.controller.profile;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diagnostic System Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 12),
            _diagRow('Client Name', profile?.name.trim().isNotEmpty == true ? profile!.name.trim() : 'Not configured'),
            _diagRow('PCOD Profile Status', profile?.pcodStatus ?? 'Not specified'),
            _diagRow('Height / Weight', '${profile?.heightCm.toStringAsFixed(1) ?? "--"} ${profile?.heightUnit ?? "cm"} / ${profile?.currentWeightKg.toStringAsFixed(1) ?? "--"} ${profile?.weightUnit ?? "kg"}'),
            _diagRow('Notifications Permission', _notifStatus?.name ?? 'unknown'),
            _diagRow('Activity / Step Sensor Permission', _activityStatus?.name ?? 'unknown'),
            _diagRow('Water Logs Count', '${widget.controller.todayWaterLogs.length} today'),
            _diagRow('Weight Entries Count', '${widget.controller.weightEntries.length} total'),
            _diagRow('Walk Sessions Count', '${widget.controller.walkSessions.length} total'),
            _diagRow('Water Interval', '${profile?.waterReminderIntervalMinutes ?? 30} mins'),
            _diagRow('Target Water', '${widget.controller.waterTargetToday} ml'),
            _diagRow('Device Target', 'Android 16 (API 36) Physical Device'),
            _diagRow('Backend / Cloud Sync', 'None (100% Offline Local Device)'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close Diagnostics'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.controller.language;
    final isDark = widget.controller.isDarkMode;
    final profile = widget.controller.profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('settingsTitle', lang: lang)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language Preference
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: AppColors.sagePrimary),
              title: Text(AppStrings.get('language', lang: lang)),
              subtitle: Text(lang == 'en' ? 'English (US/IN)' : 'हिन्दी (Hindi)'),
              trailing: Switch(
                value: lang == 'hi',
                activeThumbColor: AppColors.sagePrimary,
                onChanged: (val) => widget.controller.setLanguage(val ? 'hi' : 'en'),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Dark Theme Preference
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode_outlined, color: AppColors.mutedLavender),
              title: Text(AppStrings.get('theme', lang: lang)),
              subtitle: Text(isDark ? 'Dark theme enabled' : 'Soft warm theme enabled'),
              trailing: Switch(
                value: isDark,
                activeThumbColor: AppColors.sagePrimary,
                onChanged: (val) => widget.controller.toggleDarkMode(val),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Water Reminder Interval
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined, color: AppColors.softBlue),
              title: Text(AppStrings.get('fieldWaterInterval', lang: lang)),
              subtitle: Text('Current: ${profile?.waterReminderIntervalMinutes ?? 30} minutes'),
              trailing: DropdownButton<int>(
                value: profile?.waterReminderIntervalMinutes ?? 30,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 2, child: Text('2m (Test)')),
                  DropdownMenuItem(value: 30, child: Text('30m')),
                  DropdownMenuItem(value: 45, child: Text('45m')),
                  DropdownMenuItem(value: 60, child: Text('60m')),
                  DropdownMenuItem(value: 90, child: Text('90m')),
                ],
                onChanged: (val) {
                  if (val != null && profile != null) {
                    widget.controller.saveProfile(profile.copyWith(waterReminderIntervalMinutes: val));
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Wake-Up Alarm & Bedtime
          Card(
            child: ListTile(
              leading: const Icon(Icons.alarm, color: AppColors.softAmber),
              title: Text(AppStrings.get('sleepTitle', lang: lang)),
              subtitle: Text('Wake: ${profile?.wakeUpTime ?? "07:00"} • Bed: ${profile?.bedtime ?? "23:00"}\n(Tap to edit sleep/wake hours)'),
              onTap: () async {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppStrings.get('sleepTitle', lang: lang),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(Icons.wb_sunny_outlined, color: AppColors.softAmber),
                            title: const Text('Wake-Up Time'),
                            subtitle: Text('Current: ${profile?.wakeUpTime ?? "07:00"}'),
                            trailing: const Icon(Icons.edit, size: 18),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final parts = (profile?.wakeUpTime ?? "07:00").split(':');
                              final initialTime = TimeOfDay(
                                hour: int.tryParse(parts.first) ?? 7,
                                minute: int.tryParse(parts.last) ?? 0,
                              );
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: initialTime,
                              );
                              if (picked != null && profile != null) {
                                final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                await widget.controller.saveProfile(profile.copyWith(wakeUpTime: formatted));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Wake-up alarm set for $formatted')),
                                  );
                                }
                              }
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.bedtime_outlined, color: AppColors.sagePrimary),
                            title: const Text('Target Bedtime'),
                            subtitle: Text('Current: ${profile?.bedtime ?? "23:00"} (Water reminders paused)'),
                            trailing: const Icon(Icons.edit, size: 18),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final parts = (profile?.bedtime ?? "23:00").split(':');
                              final initialTime = TimeOfDay(
                                hour: int.tryParse(parts.first) ?? 23,
                                minute: int.tryParse(parts.last) ?? 0,
                              );
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: initialTime,
                              );
                              if (picked != null && profile != null) {
                                final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                await widget.controller.saveProfile(profile.copyWith(bedtime: formatted));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Bedtime set for $formatted. Water reminders will pause during sleep.')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () async {
                      final verified = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => SelfieVerificationScreen(controller: widget.controller),
                        ),
                      );
                      if (verified == true && context.mounted) {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MorningRoutineScreen(controller: widget.controller),
                          ),
                        );
                      }
                    },
                    child: const Text('Verify Selfie'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // College / Class Schedule Tile
          Card(
            child: ListTile(
              leading: const Icon(Icons.school, color: AppColors.sagePrimary),
              title: Text(AppStrings.get('classHoursCardTitle', lang: lang)),
              subtitle: Text(
                widget.controller.todayCollegeSchedule?.isClassConfigured == true
                    ? 'Classes today: ${widget.controller.todayCollegeSchedule!.classStartTime}–${widget.controller.todayCollegeSchedule!.classEndTime}'
                    : (widget.controller.todayCollegeSchedule?.isCollegeConfigured == true
                        ? 'College today: ${widget.controller.todayCollegeSchedule!.collegeStartTime}–${widget.controller.todayCollegeSchedule!.collegeEndTime}'
                        : (widget.controller.todayCollegeSchedule != null
                            ? 'No classes scheduled today'
                            : 'Tap to configure college / class hours')),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MorningRoutineScreen(controller: widget.controller),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Exact Alarm Permission Warning (if needed)
          if (!widget.controller.canScheduleExactAlarms) ...[
            Card(
              color: AppColors.peachBackground,
              child: ListTile(
                leading: const Icon(Icons.alarm_off, color: AppColors.softAmber),
                title: Text(AppStrings.get('exactAlarmRequiredTitle', lang: lang)),
                subtitle: Text(AppStrings.get('exactAlarmRequiredBody', lang: lang)),
                trailing: ElevatedButton(
                  onPressed: () => widget.controller.openExactAlarmSettings(),
                  child: Text(AppStrings.get('allowExactAlarms', lang: lang)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Diagnostics
          Card(
            child: ListTile(
              leading: const Icon(Icons.analytics_outlined, color: AppColors.sageDark),
              title: Text(AppStrings.get('diagnostics', lang: lang)),
              subtitle: const Text('Check device permissions and database health'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showDiagnostics,
            ),
          ),
          const SizedBox(height: 8),

          // CSV Export
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_download_outlined, color: AppColors.sagePrimary),
              title: Text(AppStrings.get('exportCsv', lang: lang)),
              subtitle: const Text('Export local weight history to CSV'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final csv = WeightMetricsCalculator.generateCsv(widget.controller.weightEntries);
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Local CSV Data Export'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          csv,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Check for Updates
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update_outlined, color: AppColors.sagePrimary),
              title: Text(AppStrings.get('checkForUpdates', lang: lang)),
              subtitle: Text(AppStrings.get('updatesSubtitle', lang: lang)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => UpdateDialog.show(context),
            ),
          ),
          const SizedBox(height: 14),

          // Offline Privacy Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCardMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.security, size: 18, color: AppColors.sagePrimary),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.get('privacyPolicy', lang: lang),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.get('privacyNotice', lang: lang),
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Reset Data Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gentleCoral,
              side: const BorderSide(color: AppColors.gentleCoral),
            ),
            icon: const Icon(Icons.delete_forever),
            label: Text(AppStrings.get('resetAllData', lang: lang)),
            onPressed: _showResetConfirmation,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
