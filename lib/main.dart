import 'package:flutter/material.dart';

import 'core/constants/app_theme.dart';
import 'core/constants/video_config.dart';
import 'presentation/controllers/app_controller.dart';
import 'presentation/screens/main_shell_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load configured video sources (Exercise and Yoga YouTube URLs)
  await VideoConfig.loadSavedSources();

  // Initialize offline local notifications
  await NotificationService.instance.init();

  runApp(const BloomWellApp());
}

class BloomWellApp extends StatefulWidget {
  const BloomWellApp({super.key});

  @override
  State<BloomWellApp> createState() => _BloomWellAppState();
}

class _BloomWellAppState extends State<BloomWellApp> with WidgetsBindingObserver {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AppController();
    _controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.syncReminderWithCurrentTime();
      _controller.reconcileActivityDataOnResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isDark = _controller.isDarkMode;

        return MaterialApp(
          title: 'BloomWell',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: _controller.isLoading
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : !_controller.isOnboarded
                  ? OnboardingScreen(
                      controller: _controller,
                      onCompleted: () => setState(() {}),
                    )
                  : MainShellScreen(controller: _controller),
        );
      },
    );
  }
}
