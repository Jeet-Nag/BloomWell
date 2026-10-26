import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../domain/calculators/water_target_calculator.dart';
import '../../domain/models/user_profile.dart';
import '../controllers/app_controller.dart';

class OnboardingScreen extends StatefulWidget {
  final AppController controller;
  final VoidCallback onCompleted;
  final LocalAuthentication? localAuth;

  const OnboardingScreen({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.localAuth,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 6;

  // SharedPreferences draft keys
  static const String _draftStepKey = 'bloomwell_draft_step';
  static const String _draftNameKey = 'bloomwell_draft_name';
  static const String _draftBiometricVerifiedKey = 'bloomwell_draft_biometric_verified';
  static const String _draftHealthGoalKey = 'bloomwell_draft_health_goal';
  static const String _draftAgeKey = 'bloomwell_draft_age';
  static const String _draftWeightKey = 'bloomwell_draft_weight';
  static const String _draftWeightUnitKey = 'bloomwell_draft_weight_unit';
  static const String _draftHeightKey = 'bloomwell_draft_height';
  static const String _draftHeightUnitKey = 'bloomwell_draft_height_unit';
  static const String _draftHeightFeetKey = 'bloomwell_draft_height_feet';
  static const String _draftHeightInchesKey = 'bloomwell_draft_height_inches';
  static const String _draftTargetWeightKey = 'bloomwell_draft_target_weight';
  static const String _draftWakeKey = 'bloomwell_draft_wake';
  static const String _draftBedKey = 'bloomwell_draft_bed';
  static const String _draftCollegeGoingKey = 'bloomwell_draft_college_going';
  static const String _draftCollegeStartKey = 'bloomwell_draft_college_start';
  static const String _draftCollegeEndKey = 'bloomwell_draft_college_end';
  static const String _draftHasClassesKey = 'bloomwell_draft_has_classes';
  static const String _draftClassStartKey = 'bloomwell_draft_class_start';
  static const String _draftClassEndKey = 'bloomwell_draft_class_end';
  static const String _draftWaterIntervalKey = 'bloomwell_draft_water_interval';
  static const String _draftHotClimateKey = 'bloomwell_draft_hot_climate';
  static const String _draftFluidRestrictionKey = 'bloomwell_draft_fluid_restriction';

  // Step 0 (Step A): Preferred Name & Biometrics
  final TextEditingController _nameController = TextEditingController();
  bool _biometricVerified = false;
  bool _isCheckingBiometrics = false;

  // Step 1 (Step B): Health Goal Selection
  // Exactly 3 options: 'weight_loss', 'pcod_support', 'both'
  String _healthGoal = 'both';
  bool _isAutoNavigating = false;

  // Step 2 (Step C): Age & Body Metrics
  final TextEditingController _ageController = TextEditingController(text: '22');
  final TextEditingController _weightController = TextEditingController(text: '60.0');
  final TextEditingController _heightController = TextEditingController(text: '160');
  final TextEditingController _heightFeetController = TextEditingController(text: '5');
  final TextEditingController _heightInchesController = TextEditingController(text: '3');
  final TextEditingController _targetWeightController = TextEditingController();
  String _weightUnit = 'kg'; // 'kg' or 'lbs'
  String _heightUnit = 'cm'; // 'cm' or 'ft_in'

  // Step 3 (Step E): Daily Routine & Rest
  String _wakeTime = '07:00';
  String _bedtime = '23:00';
  bool _attendingCollege = false;
  String _collegeStartTime = '09:00';
  String _collegeEndTime = '16:00';
  bool _hasClasses = false;
  String _classStartTime = '10:00';
  String _classEndTime = '15:00';

  // Step 4 (Step F): Hydration
  int _waterIntervalMinutes = 30;
  bool _isHotClimate = false;
  bool _hasFluidRestriction = false;

  // Validation feedback
  String? _errorMessage;

  String get _clientName => _nameController.text.trim();

  bool get _isMinor {
    final age = int.tryParse(_ageController.text.trim()) ?? 22;
    return age < 18;
  }

  late final LocalAuthentication _auth;

  @override
  void initState() {
    super.initState();
    _auth = widget.localAuth ?? LocalAuthentication();
    _loadDraft();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  // --- Draft Persistence ---
  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final savedName = prefs.getString(_draftNameKey);
      if (savedName != null && savedName.isNotEmpty) {
        _nameController.text = savedName;
      }

      _biometricVerified = prefs.getBool(_draftBiometricVerifiedKey) ?? false;
      _healthGoal = prefs.getString(_draftHealthGoalKey) ?? 'both';

      final savedAge = prefs.getString(_draftAgeKey);
      if (savedAge != null) _ageController.text = savedAge;

      final savedWeight = prefs.getString(_draftWeightKey);
      if (savedWeight != null) _weightController.text = savedWeight;

      _weightUnit = prefs.getString(_draftWeightUnitKey) ?? 'kg';

      final savedHeight = prefs.getString(_draftHeightKey);
      if (savedHeight != null) _heightController.text = savedHeight;

      _heightUnit = prefs.getString(_draftHeightUnitKey) ?? 'cm';

      final savedFt = prefs.getString(_draftHeightFeetKey);
      if (savedFt != null) _heightFeetController.text = savedFt;

      final savedIn = prefs.getString(_draftHeightInchesKey);
      if (savedIn != null) _heightInchesController.text = savedIn;

      final savedTarget = prefs.getString(_draftTargetWeightKey);
      if (savedTarget != null) _targetWeightController.text = savedTarget;

      _wakeTime = prefs.getString(_draftWakeKey) ?? '07:00';
      _bedtime = prefs.getString(_draftBedKey) ?? '23:00';

      _attendingCollege = prefs.getBool(_draftCollegeGoingKey) ?? false;
      _collegeStartTime = prefs.getString(_draftCollegeStartKey) ?? '09:00';
      _collegeEndTime = prefs.getString(_draftCollegeEndKey) ?? '16:00';

      _hasClasses = prefs.getBool(_draftHasClassesKey) ?? false;
      _classStartTime = prefs.getString(_draftClassStartKey) ?? '10:00';
      _classEndTime = prefs.getString(_draftClassEndKey) ?? '15:00';

      _waterIntervalMinutes = prefs.getInt(_draftWaterIntervalKey) ?? 30;
      _isHotClimate = prefs.getBool(_draftHotClimateKey) ?? false;
      _hasFluidRestriction = prefs.getBool(_draftFluidRestrictionKey) ?? false;

      final savedStep = prefs.getInt(_draftStepKey) ?? 0;
      if (savedStep > 0 && savedStep < _totalSteps) {
        _currentStep = savedStep;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(savedStep);
          }
        });
      }
      setState(() {});
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_draftStepKey, _currentStep);
      await prefs.setString(_draftNameKey, _nameController.text.trim());
      await prefs.setBool(_draftBiometricVerifiedKey, _biometricVerified);
      await prefs.setString(_draftHealthGoalKey, _healthGoal);
      await prefs.setString(_draftAgeKey, _ageController.text.trim());
      await prefs.setString(_draftWeightKey, _weightController.text.trim());
      await prefs.setString(_draftWeightUnitKey, _weightUnit);
      await prefs.setString(_draftHeightKey, _heightController.text.trim());
      await prefs.setString(_draftHeightUnitKey, _heightUnit);
      await prefs.setString(_draftHeightFeetKey, _heightFeetController.text.trim());
      await prefs.setString(_draftHeightInchesKey, _heightInchesController.text.trim());
      await prefs.setString(_draftTargetWeightKey, _targetWeightController.text.trim());
      await prefs.setString(_draftWakeKey, _wakeTime);
      await prefs.setString(_draftBedKey, _bedtime);
      await prefs.setBool(_draftCollegeGoingKey, _attendingCollege);
      await prefs.setString(_draftCollegeStartKey, _collegeStartTime);
      await prefs.setString(_draftCollegeEndKey, _collegeEndTime);
      await prefs.setBool(_draftHasClassesKey, _hasClasses);
      await prefs.setString(_draftClassStartKey, _classStartTime);
      await prefs.setString(_draftClassEndKey, _classEndTime);
      await prefs.setInt(_draftWaterIntervalKey, _waterIntervalMinutes);
      await prefs.setBool(_draftHotClimateKey, _isHotClimate);
      await prefs.setBool(_draftFluidRestrictionKey, _hasFluidRestriction);
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftStepKey);
      await prefs.remove(_draftNameKey);
      await prefs.remove(_draftBiometricVerifiedKey);
      await prefs.remove(_draftHealthGoalKey);
      await prefs.remove(_draftAgeKey);
      await prefs.remove(_draftWeightKey);
      await prefs.remove(_draftWeightUnitKey);
      await prefs.remove(_draftHeightKey);
      await prefs.remove(_draftHeightUnitKey);
      await prefs.remove(_draftHeightFeetKey);
      await prefs.remove(_draftHeightInchesKey);
      await prefs.remove(_draftTargetWeightKey);
      await prefs.remove(_draftWakeKey);
      await prefs.remove(_draftBedKey);
      await prefs.remove(_draftCollegeGoingKey);
      await prefs.remove(_draftCollegeStartKey);
      await prefs.remove(_draftCollegeEndKey);
      await prefs.remove(_draftHasClassesKey);
      await prefs.remove(_draftClassStartKey);
      await prefs.remove(_draftClassEndKey);
      await prefs.remove(_draftWaterIntervalKey);
      await prefs.remove(_draftHotClimateKey);
      await prefs.remove(_draftFluidRestrictionKey);
    } catch (_) {}
  }

  // --- Step Navigation & Validation ---
  bool _validateCurrentStep() {
    setState(() => _errorMessage = null);

    if (_currentStep == 0) {
      if (_nameController.text.trim().length < 2) {
        setState(() => _errorMessage = 'Please enter your preferred name (at least 2 letters).');
        return false;
      }
    } else if (_currentStep == 1) {
      if (_healthGoal.isEmpty) {
        setState(() => _errorMessage = 'Please select a health goal to continue.');
        return false;
      }
    } else if (_currentStep == 2) {
      final age = int.tryParse(_ageController.text.trim());
      if (age == null || age < 12 || age > 100) {
        setState(() => _errorMessage = 'Please enter a valid age between 12 and 100.');
        return false;
      }

      final weight = double.tryParse(_weightController.text.trim());
      if (weight == null || weight <= 20 || weight > 300) {
        setState(() => _errorMessage = 'Please enter a valid weight.');
        return false;
      }

      if (_heightUnit == 'cm') {
        final height = double.tryParse(_heightController.text.trim());
        if (height == null || height < 90 || height > 250) {
          setState(() => _errorMessage = 'Please enter a valid height in cm (90–250 cm).');
          return false;
        }
      } else {
        final ft = int.tryParse(_heightFeetController.text.trim());
        final inch = int.tryParse(_heightInchesController.text.trim());
        if (ft == null || ft < 3 || ft > 7 || inch == null || inch < 0 || inch > 11) {
          setState(() => _errorMessage = 'Please enter valid height in feet (3–7) and inches (0–11).');
          return false;
        }
      }
    } else if (_currentStep == 3) {
      // Validate college schedule if attending
      if (_attendingCollege) {
        final collegeStart = _parseTimeMinutes(_collegeStartTime);
        final collegeEnd = _parseTimeMinutes(_collegeEndTime);
        if (collegeStart == null || collegeEnd == null || collegeStart >= collegeEnd) {
          setState(() => _errorMessage = 'College start time must be before end time.');
          return false;
        }
      }

      // Validate class schedule if having classes
      if (_hasClasses) {
        final classStart = _parseTimeMinutes(_classStartTime);
        final classEnd = _parseTimeMinutes(_classEndTime);
        if (classStart == null || classEnd == null || classStart >= classEnd) {
          setState(() => _errorMessage = 'Class start time must be before end time.');
          return false;
        }
      }
    }
    return true;
  }

  int? _parseTimeMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return h * 60 + m;
      }
    } catch (_) {}
    return null;
  }

  // --- Step A: Native Biometric Verification ---
  Future<bool> _authenticateBiometrics() async {
    setState(() {
      _isCheckingBiometrics = true;
      _errorMessage = null;
    });

    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheck && !isDeviceSupported) {
        if (mounted) {
          setState(() {
            _isCheckingBiometrics = false;
            _errorMessage =
                'Biometrics or device screen lock are not enrolled on this device. Please set up a fingerprint, face, or screen lock (PIN/Pattern) in Android Settings to secure your profile.';
          });
        }
        return false;
      }

      final bool didAuth = await _auth.authenticate(
        localizedReason: 'Please verify your identity to access BloomWell on this device',
        biometricOnly: false,
      );

      if (mounted) {
        setState(() {
          _isCheckingBiometrics = false;
          _biometricVerified = didAuth;
          if (!didAuth) {
            _errorMessage = 'Biometric verification required to proceed. Please authenticate using fingerprint, face, or PIN.';
          }
        });
        if (didAuth) {
          await _saveDraft();
        }
      }
      return didAuth;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingBiometrics = false;
          _errorMessage = 'Authentication check error: $e. Please verify biometrics or device PIN.';
        });
      }
      return false;
    }
  }

  Future<void> _nextPage() async {
    if (!_validateCurrentStep()) return;

    // Step A (Index 0): Name entered -> Immediately trigger native biometrics
    if (_currentStep == 0) {
      if (!_biometricVerified) {
        final didAuth = await _authenticateBiometrics();
        if (!didAuth) {
          // Block progression if authentication did not succeed
          return;
        }
      }
    }

    if (_currentStep < _totalSteps - 1) {
      _currentStep++;
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _saveDraft();
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _currentStep--;
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _saveDraft();
    }
  }

  void _goToStep(int step) {
    if (step >= 0 && step < _totalSteps) {
      _currentStep = step;
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _saveDraft();
    }
  }

  // --- Step B: Single-Tap Goal Selection & Auto Advance ---
  void _selectHealthGoal(String goal) {
    if (_isAutoNavigating) return;
    _isAutoNavigating = true;

    setState(() {
      _healthGoal = goal;
      _errorMessage = null;
    });
    _saveDraft();

    // Automatically advance to Step 2 (Body Metrics) without requiring a second Next tap
    _pageController
        .animateToPage(
      2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    )
        .then((_) {
      if (mounted) {
        _isAutoNavigating = false;
      }
    });
  }

  // --- Finish Onboarding ---
  Future<void> _finishOnboarding() async {
    final age = int.tryParse(_ageController.text.trim()) ?? 22;

    // Convert height to cm
    double heightInCm;
    if (_heightUnit == 'ft_in') {
      final ft = int.tryParse(_heightFeetController.text.trim()) ?? 5;
      final inch = int.tryParse(_heightInchesController.text.trim()) ?? 3;
      heightInCm = (ft * 12 + inch) * 2.54;
    } else {
      heightInCm = double.tryParse(_heightController.text.trim()) ?? 160.0;
    }

    // Convert weight to kg
    double weightInKg;
    final rawWeight = double.tryParse(_weightController.text.trim()) ?? 60.0;
    if (_weightUnit == 'lbs') {
      weightInKg = rawWeight / 2.20462;
    } else {
      weightInKg = rawWeight;
    }

    // Optional target weight
    double? targetWeightKg;
    if (age >= 18 && _targetWeightController.text.trim().isNotEmpty) {
      final rawTarget = double.tryParse(_targetWeightController.text.trim());
      if (rawTarget != null && rawTarget > 0) {
        targetWeightKg = _weightUnit == 'lbs' ? (rawTarget / 2.20462) : rawTarget;
      }
    }

    final profile = UserProfile(
      name: _clientName,
      weightUnit: _weightUnit,
      heightUnit: _heightUnit,
      age: age,
      heightCm: heightInCm,
      currentWeightKg: weightInKg,
      targetWeightKg: targetWeightKg,
      dietaryPreference: 'vegetarian',
      allergies: '',
      hostelFacility: 'mess',
      weeklyFoodBudget: 1000.0,
      wakeUpTime: _wakeTime,
      bedtime: _bedtime,
      waterReminderIntervalMinutes: _waterIntervalMinutes,
      exerciseExperience: 'beginner',
      mobilityLimitations: '',
      pcodStatus: _healthGoal == 'weight_loss' ? 'unspecified' : 'lifestyle_management',
      healthGoal: _healthGoal,
      activityLevel: 'light',
      isHotClimate: _isHotClimate,
      hasFluidRestriction: _hasFluidRestriction,
      isOnboarded: true,
    );

    // Save profile (schedules personalized wake alarm & water reminder)
    await widget.controller.saveProfile(profile);

    // Save college & class schedule if configured
    if (_attendingCollege || _hasClasses) {
      await widget.controller.recordCollegeSchedule(
        goingToCollege: _attendingCollege,
        hasClasses: _hasClasses,
        collegeStartTime: _attendingCollege ? _collegeStartTime : null,
        collegeEndTime: _attendingCollege ? _collegeEndTime : null,
        classStartTime: _hasClasses ? _classStartTime : null,
        classEndTime: _hasClasses ? _classEndTime : null,
      );
    } else {
      await widget.controller.cancelCollegeSchedule();
    }

    // Clear temporary drafts
    await _clearDraft();

    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.controller.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('appName', lang: lang)),
        actions: [
          TextButton(
            onPressed: () {
              final newLang = lang == 'en' ? 'hi' : 'en';
              widget.controller.setLanguage(newLang);
            },
            child: Text(
              lang == 'en' ? 'हिन्दी' : 'English',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar & Step Counter (1/6 to 6/6)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      backgroundColor: AppColors.borderLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sagePrimary),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_currentStep + 1}/$_totalSteps',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Step Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentStep = idx),
                children: [
                  _buildStep0Name(lang),
                  _buildStep1HealthGoal(lang),
                  _buildStep2BodyMetrics(lang),
                  _buildStep3DailySchedule(lang),
                  _buildStep4Hydration(lang),
                  _buildStep5Review(lang),
                ],
              ),
            ),

            // Bottom Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _prevPage,
                        child: Text(AppStrings.get('back', lang: lang)),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isCheckingBiometrics ? null : _nextPage,
                      child: _isCheckingBiometrics
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _currentStep == _totalSteps - 1
                                  ? 'Save & Enter BloomWell'
                                  : AppStrings.get('next', lang: lang),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 0 (Step A): Preferred Name & Biometric Access ---
  Widget _buildStep0Name(String lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to BloomWell',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your private, offline companion for gentle wellness, mindful hydration, and daily balance.',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          const Text(
            'What should we call you?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter your preferred name (e.g. Priya)',
              prefixIcon: Icon(Icons.person_outline, color: AppColors.sagePrimary),
            ),
            onChanged: (_) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
              _saveDraft();
            },
          ),
          const SizedBox(height: 20),

          // Biometric Notice & Verification Status
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _biometricVerified ? Colors.green.shade50 : AppColors.surfaceCardMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _biometricVerified ? Colors.green.shade200 : AppColors.borderLight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _biometricVerified ? Icons.check_circle : Icons.fingerprint,
                  color: _biometricVerified ? Colors.green : AppColors.sagePrimary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _biometricVerified ? 'Biometrics Verified ✓' : 'Protected on This Device',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _biometricVerified ? Colors.green.shade900 : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _biometricVerified
                            ? 'Your identity is confirmed on this phone. Tap Next to continue.'
                            : 'Tapping Next will open your device’s secure biometric / PIN prompt. Biometrics verify access locally; they never create an account or leave this phone.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _biometricVerified ? Colors.green.shade800 : AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!_biometricVerified && _errorMessage != null)
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry Biometric Verification'),
                onPressed: _isCheckingBiometrics ? null : _authenticateBiometrics,
              ),
            ),
        ],
      ),
    );
  }

  // --- Step 1 (Step B): Health Goal Selection ---
  Widget _buildStep1HealthGoal(String lang) {
    final name = _clientName.isNotEmpty ? _clientName : 'there';

    final goals = [
      {
        'id': 'weight_loss',
        'title': 'Weight loss',
        'subtitle': 'Sustainable habits, mindful hydration, and low-impact daily movement.',
        'icon': Icons.trending_down,
      },
      {
        'id': 'pcod_support',
        'title': 'PCOD support',
        'subtitle': 'Gentle restorative routines, consistent circadian rhythm, and hormone balance support.',
        'icon': Icons.spa_outlined,
      },
      {
        'id': 'both',
        'title': 'Both weight loss and PCOD support',
        'subtitle': 'Balanced lifestyle guidance combining gentle weight management and restorative PCOD wellness.',
        'icon': Icons.all_inclusive,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $name!',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select your wellness focus',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.sageDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'BloomWell personalizes your daily movement, gentle routines, and hydration based on what matters most to you.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35),
          ),
          const SizedBox(height: 16),

          // Respectful, non-diagnostic notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCardMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.softAmber.withValues(alpha: 0.5)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.health_and_safety_outlined, color: AppColors.softAmber, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Educational Self-Care Notice: Gentle movement, hydration, and restful routines support vitality, but they do not diagnose, treat, or cure PCOD. Always consult a qualified medical professional.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Exactly 3 Selectable Goals with Single-Tap Auto Advance
          ...goals.map((g) {
            final isSelected = _healthGoal == g['id'];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppColors.sagePrimary : AppColors.borderLight,
                  width: isSelected ? 2 : 1,
                ),
              ),
              color: isSelected ? AppColors.sageBackground : Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: isSelected ? AppColors.sagePrimary : AppColors.surfaceCardMuted,
                  child: Icon(
                    g['icon'] as IconData,
                    color: isSelected ? Colors.white : AppColors.sageDark,
                    size: 20,
                  ),
                ),
                title: Text(
                  g['title'] as String,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppColors.sageDark : AppColors.textDark,
                    fontSize: 15,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    g['subtitle'] as String,
                    style: const TextStyle(fontSize: 12, height: 1.3),
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppColors.sagePrimary)
                    : const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSubtle),
                onTap: () => _selectHealthGoal(g['id'] as String),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- Step 2 (Step C): Age & Body Metrics ---
  Widget _buildStep2BodyMetrics(String lang) {
    final name = _clientName.isNotEmpty ? _clientName : 'there';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Body Metrics, $name',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Used locally to calculate baseline hydration targets and personalized pedometer stride lengths.',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),

          // Age
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppStrings.get('fieldAge', lang: lang),
              prefixIcon: const Icon(Icons.cake_outlined, color: AppColors.sagePrimary),
            ),
            onChanged: (_) {
              setState(() {});
              _saveDraft();
            },
          ),

          if (_isMinor) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Youth Notice: Under 18 years. Weight-loss targets are disabled. BloomWell focuses on balanced nourishment and gentle movement.',
                      style: TextStyle(fontSize: 11, color: Colors.brown),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Weight with Unit Switcher
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Current Weight ($_weightUnit)',
                    prefixIcon: const Icon(Icons.monitor_weight_outlined, color: AppColors.sagePrimary),
                  ),
                  onChanged: (_) => _saveDraft(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'kg', label: Text('kg')),
                    ButtonSegment(value: 'lbs', label: Text('lbs')),
                  ],
                  selected: {_weightUnit},
                  onSelectionChanged: (set) {
                    final newUnit = set.first;
                    final curVal = double.tryParse(_weightController.text.trim());
                    if (curVal != null && curVal > 0) {
                      if (_weightUnit == 'kg' && newUnit == 'lbs') {
                        _weightController.text = (curVal * 2.20462).toStringAsFixed(1);
                      } else if (_weightUnit == 'lbs' && newUnit == 'kg') {
                        _weightController.text = (curVal / 2.20462).toStringAsFixed(1);
                      }
                    }
                    setState(() => _weightUnit = newUnit);
                    _saveDraft();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Height with Unit Switcher
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _heightUnit == 'cm'
                    ? TextField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Height (cm)',
                          prefixIcon: Icon(Icons.height, color: AppColors.sagePrimary),
                        ),
                        onChanged: (_) => _saveDraft(),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _heightFeetController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Feet (ft)'),
                              onChanged: (_) => _saveDraft(),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _heightInchesController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Inches (in)'),
                              onChanged: (_) => _saveDraft(),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'cm', label: Text('cm')),
                    ButtonSegment(value: 'ft_in', label: Text('ft/in')),
                  ],
                  selected: {_heightUnit},
                  onSelectionChanged: (set) {
                    final newUnit = set.first;
                    setState(() => _heightUnit = newUnit);
                    _saveDraft();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Target Weight (Disabled for Minors)
          if (!_isMinor) ...[
            TextField(
              controller: _targetWeightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Target Weight ($_weightUnit) — Optional',
                prefixIcon: const Icon(Icons.flag_outlined, color: AppColors.mutedLavender),
              ),
              onChanged: (_) => _saveDraft(),
            ),
          ],
        ],
      ),
    );
  }

  // --- Step 3 (Step E): Daily Routine & Rest ---
  Widget _buildStep3DailySchedule(String lang) {
    final name = _clientName.isNotEmpty ? _clientName : 'there';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Routine & Rest, $name',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          const Text(
            'Consistent circadian rhythms help regulate cortisol, natural energy, and metabolic balance.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),

          // Wake and Bed times
          Row(
            children: [
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.wb_sunny, color: AppColors.softAmber),
                    title: const Text('Wake-Up', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      _wakeTime,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.sageDark),
                    ),
                    onTap: () async {
                      final parts = _wakeTime.split(':');
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.tryParse(parts[0]) ?? 7,
                          minute: int.tryParse(parts[1]) ?? 0,
                        ),
                      );
                      if (t != null) {
                        setState(() {
                          _wakeTime =
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                        });
                        _saveDraft();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.nightlight_round, color: AppColors.mutedLavender),
                    title: const Text('Bedtime', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      _bedtime,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mutedLavender),
                    ),
                    onTap: () async {
                      final parts = _bedtime.split(':');
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.tryParse(parts[0]) ?? 23,
                          minute: int.tryParse(parts[1]) ?? 0,
                        ),
                      );
                      if (t != null) {
                        setState(() {
                          _bedtime =
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                        });
                        _saveDraft();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Question 1: Are you attending college today?
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Are you attending college today?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Attending campus / library / labs',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Yes')),
                          ButtonSegment(value: false, label: Text('No')),
                        ],
                        selected: {_attendingCollege},
                        onSelectionChanged: (set) {
                          setState(() => _attendingCollege = set.first);
                          _saveDraft();
                        },
                      ),
                    ],
                  ),
                  if (_attendingCollege) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: AppColors.surfaceCardMuted,
                            child: ListTile(
                              dense: true,
                              title: const Text('College Starts', style: TextStyle(fontSize: 11)),
                              subtitle: Text(_collegeStartTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.access_time, size: 16),
                              onTap: () async {
                                final parts = _collegeStartTime.split(':');
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: int.tryParse(parts[0]) ?? 9,
                                    minute: int.tryParse(parts[1]) ?? 0,
                                  ),
                                );
                                if (t != null) {
                                  setState(() {
                                    _collegeStartTime =
                                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                  });
                                  _saveDraft();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            color: AppColors.surfaceCardMuted,
                            child: ListTile(
                              dense: true,
                              title: const Text('College Ends', style: TextStyle(fontSize: 11)),
                              subtitle: Text(_collegeEndTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.access_time, size: 16),
                              onTap: () async {
                                final parts = _collegeEndTime.split(':');
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: int.tryParse(parts[0]) ?? 16,
                                    minute: int.tryParse(parts[1]) ?? 0,
                                  ),
                                );
                                if (t != null) {
                                  setState(() {
                                    _collegeEndTime =
                                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                  });
                                  _saveDraft();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Question 2: Do you have classes today?
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Do you have classes today?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Reminders quietly paused during active lecture hours',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Yes')),
                          ButtonSegment(value: false, label: Text('No')),
                        ],
                        selected: {_hasClasses},
                        onSelectionChanged: (set) {
                          setState(() => _hasClasses = set.first);
                          _saveDraft();
                        },
                      ),
                    ],
                  ),
                  if (_hasClasses) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: AppColors.surfaceCardMuted,
                            child: ListTile(
                              dense: true,
                              title: const Text('Classes Start', style: TextStyle(fontSize: 11)),
                              subtitle: Text(_classStartTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.access_time, size: 16),
                              onTap: () async {
                                final parts = _classStartTime.split(':');
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: int.tryParse(parts[0]) ?? 10,
                                    minute: int.tryParse(parts[1]) ?? 0,
                                  ),
                                );
                                if (t != null) {
                                  setState(() {
                                    _classStartTime =
                                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                  });
                                  _saveDraft();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            color: AppColors.surfaceCardMuted,
                            child: ListTile(
                              dense: true,
                              title: const Text('Classes End', style: TextStyle(fontSize: 11)),
                              subtitle: Text(_classEndTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.access_time, size: 16),
                              onTap: () async {
                                final parts = _classEndTime.split(':');
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: int.tryParse(parts[0]) ?? 15,
                                    minute: int.tryParse(parts[1]) ?? 0,
                                  ),
                                );
                                if (t != null) {
                                  setState(() {
                                    _classEndTime =
                                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                  });
                                  _saveDraft();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 4 (Step F): Hydration ---
  Widget _buildStep4Hydration(String lang) {
    final name = _clientName.isNotEmpty ? _clientName : 'there';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hydration Settings, $name',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mindful hydration supports metabolic function, prevents dehydration headaches, and promotes vitality.',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),

          // Water interval selector
          const Text(
            'Water Reminder Interval',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: _waterIntervalMinutes,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.water_drop_outlined, color: AppColors.softBlue)),
            items: const [
              DropdownMenuItem(value: 30, child: Text('Every 30 min (Recommended for active days)')),
              DropdownMenuItem(value: 45, child: Text('Every 45 min')),
              DropdownMenuItem(value: 60, child: Text('Every 60 min (Gentle)')),
              DropdownMenuItem(value: 90, child: Text('Every 90 min')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _waterIntervalMinutes = val);
              _saveDraft();
            },
          ),
          const SizedBox(height: 18),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hot Climate / Summer Season', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Adds conservative +300 ml to your daily hydration goal', style: TextStyle(fontSize: 12)),
            value: _isHotClimate,
            activeThumbColor: AppColors.sagePrimary,
            onChanged: (val) {
              setState(() => _isHotClimate = val);
              _saveDraft();
            },
          ),
          const Divider(height: 16),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Doctor-Prescribed Fluid Restriction', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Caps daily water target at 1500 ml for renal or cardiac safety', style: TextStyle(fontSize: 12)),
            value: _hasFluidRestriction,
            activeThumbColor: AppColors.gentleCoral,
            onChanged: (val) {
              setState(() => _hasFluidRestriction = val);
              _saveDraft();
            },
          ),
        ],
      ),
    );
  }

  // --- Step 5 (Step G): Review & Final Confirmation ---
  Widget _buildStep5Review(String lang) {
    final name = _clientName.isNotEmpty ? _clientName : 'there';
    final age = int.tryParse(_ageController.text.trim()) ?? 22;

    double weightKg = double.tryParse(_weightController.text.trim()) ?? 60.0;
    if (_weightUnit == 'lbs') weightKg = weightKg / 2.20462;

    final targetWater = WaterTargetCalculator.calculateDailyTargetMl(
      weightKg: weightKg,
      age: age,
      activityLevel: 'light',
      isHotClimate: _isHotClimate,
      hasFluidRestriction: _hasFluidRestriction,
    );

    String goalDisplay;
    if (_healthGoal == 'weight_loss') {
      goalDisplay = 'Weight loss';
    } else if (_healthGoal == 'pcod_support') {
      goalDisplay = 'PCOD support';
    } else {
      goalDisplay = 'Both weight loss & PCOD support';
    }

    String routineDisplay = 'Wake: $_wakeTime • Sleep: $_bedtime';
    if (_attendingCollege) {
      routineDisplay += '\nCollege: $_collegeStartTime–$_collegeEndTime';
    } else {
      routineDisplay += '\nCollege: Not today';
    }
    if (_hasClasses) {
      routineDisplay += '\nClasses: $_classStartTime–$_classEndTime';
    } else {
      routineDisplay += '\nClasses: None today';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Your Profile, $name',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check your preferences below. You can tap edit to change any detail before saving.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _reviewRow(
                    icon: Icons.person_outline,
                    label: 'Client Name',
                    value: name,
                    onEdit: () => _goToStep(0),
                  ),
                  const Divider(height: 16),
                  _reviewRow(
                    icon: Icons.fingerprint,
                    label: 'Biometric Access',
                    value: _biometricVerified ? 'Verified on device ✓' : 'Pending Verification',
                    onEdit: () => _goToStep(0),
                  ),
                  const Divider(height: 16),
                  _reviewRow(
                    icon: Icons.track_changes,
                    label: 'Wellness Focus',
                    value: goalDisplay,
                    onEdit: () => _goToStep(1),
                  ),
                  const Divider(height: 16),
                  _reviewRow(
                    icon: Icons.accessibility_new,
                    label: 'Age & Body Metrics',
                    value: '$age yrs • ${_weightController.text} $_weightUnit • '
                        '${_heightUnit == "cm" ? "${_heightController.text} cm" : "${_heightFeetController.text}ft ${_heightInchesController.text}in"}',
                    onEdit: () => _goToStep(2),
                  ),
                  const Divider(height: 16),
                  _reviewRow(
                    icon: Icons.schedule,
                    label: 'Daily Routine & Rest',
                    value: routineDisplay,
                    onEdit: () => _goToStep(3),
                  ),
                  const Divider(height: 16),
                  _reviewRow(
                    icon: Icons.water_drop,
                    label: 'Hydration Target',
                    value: '$targetWater ml/day • Every $_waterIntervalMinutes min',
                    onEdit: () => _goToStep(4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sageBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.sageDark, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All your data will be stored securely on this phone. Personalized wake alarms and reminders will be scheduled upon saving.',
                    style: TextStyle(fontSize: 12, color: AppColors.sageDark, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onEdit,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.sagePrimary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
          tooltip: 'Edit $label',
          onPressed: onEdit,
        ),
      ],
    );
  }
}
