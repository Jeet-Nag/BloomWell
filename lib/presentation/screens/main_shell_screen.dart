import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../controllers/app_controller.dart';
import 'home_dashboard_screen.dart';
import 'water_screen.dart';
import 'move_screen.dart';
import 'meals_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import 'selfie_verification_screen.dart';
import 'morning_routine_screen.dart';

class MainShellScreen extends StatefulWidget {
  final AppController controller;

  const MainShellScreen({super.key, required this.controller});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  StreamSubscription<String>? _flowSubscription;
  bool _isHandlingFlow = false;

  @override
  void initState() {
    super.initState();
    _initFlowListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialFlow();
    });
  }

  void _initFlowListeners() {
    _flowSubscription = widget.controller.nativeAlarmService.onOpenFlowStream.listen((flow) {
      if (flow == 'selfie_verification') {
        _openSelfieVerification();
      } else if (flow == 'water_screen' || flow == 'water_acknowledge') {
        _openDrinkWaterScreen();
      }
    });
  }

  Future<void> _checkInitialFlow() async {
    final flow = await widget.controller.nativeAlarmService.getInitialFlow();
    if (flow == 'selfie_verification') {
      await _openSelfieVerification();
    } else if (flow == 'water_screen' || flow == 'water_acknowledge') {
      await _openDrinkWaterScreen();
    }
  }

  Future<void> _openDrinkWaterScreen() async {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedIndex != 1) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() => _selectedIndex = 1);
      }
    });
  }

  Future<void> _openSelfieVerification() async {
    if (_isHandlingFlow || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_isHandlingFlow || !mounted) return;
      _isHandlingFlow = true;
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SelfieVerificationScreen(controller: widget.controller),
        ),
      );
      _isHandlingFlow = false;
      if (verified == true && mounted) {
        // Show morning routine ONLY after successful wake-up selfie verification
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MorningRoutineScreen(controller: widget.controller),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _flowSubscription?.cancel();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.controller.language;

    final List<Widget> screens = [
      HomeDashboardScreen(
        controller: widget.controller,
        onNavigateToTab: _onTabSelected,
      ),
      WaterScreen(controller: widget.controller),
      MoveScreen(controller: widget.controller),
      MealsScreen(controller: widget.controller),
      ProgressScreen(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
    ];

    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      backgroundColor: isLandscape ? Colors.black : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: isLandscape
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onTabSelected,
              destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: AppStrings.get('tabHome', lang: lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.water_drop_outlined),
            selectedIcon: const Icon(Icons.water_drop),
            label: AppStrings.get('tabWater', lang: lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.directions_run_outlined),
            selectedIcon: const Icon(Icons.directions_run),
            label: AppStrings.get('tabMove', lang: lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant),
            label: AppStrings.get('tabMeals', lang: lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: AppStrings.get('tabProgress', lang: lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune),
            label: AppStrings.get('tabSettings', lang: lang),
          ),
        ],
      ),
    );
  }
}
