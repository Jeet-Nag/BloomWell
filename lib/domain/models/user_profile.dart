class UserProfile {
  final String name;
  final String weightUnit; // kg, lbs
  final String heightUnit; // cm, ft_in
  final int age;
  final double heightCm;
  final double currentWeightKg;
  final double? targetWeightKg;
  final String dietaryPreference; // vegetarian, vegan, eggitarian, non_veg
  final String allergies;
  final String hostelFacility; // mess, kettle, shared_kitchen, full_kitchen
  final double weeklyFoodBudget;
  final String wakeUpTime; // "07:00"
  final String bedtime; // "23:00"
  final int waterReminderIntervalMinutes; // default 30
  final String exerciseExperience; // beginner, intermediate, light_mobility
  final String mobilityLimitations;
  final String pcodStatus; // yes, suspected, no
  final String healthGoal; // weight_loss, pcod_support, both

  /// Backwards-compatibility alias for [pcodStatus].
  String get pcosStatus => pcodStatus;

  final String activityLevel; // sedentary, light, moderate
  final bool isHotClimate;
  final bool hasFluidRestriction;
  final bool isOnboarded;

  const UserProfile({
    this.name = '',
    this.weightUnit = 'kg',
    this.heightUnit = 'cm',
    required this.age,
    required this.heightCm,
    required this.currentWeightKg,
    this.targetWeightKg,
    this.dietaryPreference = 'vegetarian',
    this.allergies = '',
    this.hostelFacility = 'mess',
    this.weeklyFoodBudget = 1000.0,
    this.wakeUpTime = '07:00',
    this.bedtime = '23:00',
    this.waterReminderIntervalMinutes = 30,
    this.exerciseExperience = 'beginner',
    this.mobilityLimitations = '',
    this.pcodStatus = 'suspected',
    this.healthGoal = 'both',
    String? pcosStatus,
    this.activityLevel = 'light',
    this.isHotClimate = false,
    this.hasFluidRestriction = false,
    this.isOnboarded = false,
  });

  bool get isMinor => age < 18;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'weightUnit': weightUnit,
      'heightUnit': heightUnit,
      'age': age,
      'heightCm': heightCm,
      'currentWeightKg': currentWeightKg,
      'targetWeightKg': targetWeightKg,
      'dietaryPreference': dietaryPreference,
      'allergies': allergies,
      'hostelFacility': hostelFacility,
      'weeklyFoodBudget': weeklyFoodBudget,
      'wakeUpTime': wakeUpTime,
      'bedtime': bedtime,
      'waterReminderIntervalMinutes': waterReminderIntervalMinutes,
      'exerciseExperience': exerciseExperience,
      'mobilityLimitations': mobilityLimitations,
      'pcodStatus': pcodStatus,
      'pcosStatus': pcodStatus,
      'healthGoal': healthGoal,
      'activityLevel': activityLevel,
      'isHotClimate': isHotClimate ? 1 : 0,
      'hasFluidRestriction': hasFluidRestriction ? 1 : 0,
      'isOnboarded': isOnboarded ? 1 : 0,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final int? rawIsOnboarded = map['isOnboarded'] as int?;
    final double weight = (map['currentWeightKg'] as num?)?.toDouble() ?? 0.0;
    final int age = map['age'] as int? ?? 0;

    // Existing valid profile with recorded age and weight indicates completed onboarding
    // even if a legacy SQLite row had a null/0 isOnboarded column.
    final bool hasValidLegacyProfile = weight > 0 && age > 0;
    final bool isOnboarded =
        rawIsOnboarded == 1 || (rawIsOnboarded == null && hasValidLegacyProfile);

    return UserProfile(
      name: map['name'] as String? ?? '',
      weightUnit: map['weightUnit'] as String? ?? 'kg',
      heightUnit: map['heightUnit'] as String? ?? 'cm',
      age: age > 0 ? age : 22,
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 160.0,
      currentWeightKg: weight > 0 ? weight : 60.0,
      targetWeightKg: (map['targetWeightKg'] as num?)?.toDouble(),
      dietaryPreference: map['dietaryPreference'] as String? ?? 'vegetarian',
      allergies: map['allergies'] as String? ?? '',
      hostelFacility: map['hostelFacility'] as String? ?? 'mess',
      weeklyFoodBudget: (map['weeklyFoodBudget'] as num?)?.toDouble() ?? 1000.0,
      wakeUpTime: map['wakeUpTime'] as String? ?? '07:00',
      bedtime: map['bedtime'] as String? ?? '23:00',
      waterReminderIntervalMinutes: map['waterReminderIntervalMinutes'] as int? ?? 30,
      exerciseExperience: map['exerciseExperience'] as String? ?? 'beginner',
      mobilityLimitations: map['mobilityLimitations'] as String? ?? '',
      pcodStatus: (map['pcodStatus'] ?? map['pcosStatus']) as String? ?? 'suspected',
      healthGoal: map['healthGoal'] as String? ?? 'both',
      activityLevel: map['activityLevel'] as String? ?? 'light',
      isHotClimate: (map['isHotClimate'] as int? ?? 0) == 1,
      hasFluidRestriction: (map['hasFluidRestriction'] as int? ?? 0) == 1,
      isOnboarded: isOnboarded,
    );
  }

  UserProfile copyWith({
    String? name,
    String? weightUnit,
    String? heightUnit,
    int? age,
    double? heightCm,
    double? currentWeightKg,
    double? targetWeightKg,
    String? dietaryPreference,
    String? allergies,
    String? hostelFacility,
    double? weeklyFoodBudget,
    String? wakeUpTime,
    String? bedtime,
    int? waterReminderIntervalMinutes,
    String? exerciseExperience,
    String? mobilityLimitations,
    String? pcodStatus,
    String? pcosStatus,
    String? healthGoal,
    String? activityLevel,
    bool? isHotClimate,
    bool? hasFluidRestriction,
    bool? isOnboarded,
  }) {
    return UserProfile(
      name: name ?? this.name,
      weightUnit: weightUnit ?? this.weightUnit,
      heightUnit: heightUnit ?? this.heightUnit,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      allergies: allergies ?? this.allergies,
      hostelFacility: hostelFacility ?? this.hostelFacility,
      weeklyFoodBudget: weeklyFoodBudget ?? this.weeklyFoodBudget,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      bedtime: bedtime ?? this.bedtime,
      waterReminderIntervalMinutes: waterReminderIntervalMinutes ?? this.waterReminderIntervalMinutes,
      exerciseExperience: exerciseExperience ?? this.exerciseExperience,
      mobilityLimitations: mobilityLimitations ?? this.mobilityLimitations,
      pcodStatus: pcodStatus ?? pcosStatus ?? this.pcodStatus,
      healthGoal: healthGoal ?? this.healthGoal,
      activityLevel: activityLevel ?? this.activityLevel,
      isHotClimate: isHotClimate ?? this.isHotClimate,
      hasFluidRestriction: hasFluidRestriction ?? this.hasFluidRestriction,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }
}
