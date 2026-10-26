class MealIngredient {
  final String name;
  final String quantity;

  const MealIngredient({required this.name, required this.quantity});

  factory MealIngredient.fromMap(Map<String, dynamic> map) {
    return MealIngredient(
      name: map['name'] as String? ?? '',
      quantity: map['quantity'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'quantity': quantity};
}

class MealItem {
  final String id;
  final int dayOfWeek; // 1 = Monday ... 7 = Sunday
  final String mealType; // breakfast, lunch, snack, dinner
  final String name;
  final String nameHi;
  final int prepTimeMinutes;
  final int approxCalories;
  final double approxProteinG;
  final double approxCarbsG;
  final double approxFatG;
  final double approxFiberG;
  final List<String> hostelCategories; // mess, kettle, shared_kitchen, full_kitchen
  final String budgetTier; // low, moderate
  final List<MealIngredient> ingredients;
  final List<String> instructions;
  final List<String> substitutions;
  final String prepAheadNote;
  final String pcodTip;

  /// Backwards-compatibility alias for [pcodTip].
  String get pcosTip => pcodTip;

  const MealItem({
    required this.id,
    required this.dayOfWeek,
    required this.mealType,
    required this.name,
    required this.nameHi,
    required this.prepTimeMinutes,
    required this.approxCalories,
    required this.approxProteinG,
    required this.approxCarbsG,
    required this.approxFatG,
    required this.approxFiberG,
    required this.hostelCategories,
    required this.budgetTier,
    required this.ingredients,
    required this.instructions,
    required this.substitutions,
    required this.prepAheadNote,
    required this.pcodTip,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      id: json['id'] as String,
      dayOfWeek: json['dayOfWeek'] as int,
      mealType: json['mealType'] as String,
      name: json['name'] as String,
      nameHi: json['nameHi'] as String? ?? json['name'] as String,
      prepTimeMinutes: json['prepTimeMinutes'] as int? ?? 15,
      approxCalories: json['approxCalories'] as int? ?? 300,
      approxProteinG: (json['approxProteinG'] as num?)?.toDouble() ?? 10.0,
      approxCarbsG: (json['approxCarbsG'] as num?)?.toDouble() ?? 45.0,
      approxFatG: (json['approxFatG'] as num?)?.toDouble() ?? 8.0,
      approxFiberG: (json['approxFiberG'] as num?)?.toDouble() ?? 5.0,
      hostelCategories: List<String>.from(json['hostelCategories'] ?? []),
      budgetTier: json['budgetTier'] as String? ?? 'low',
      ingredients: (json['ingredients'] as List? ?? [])
          .map((i) => MealIngredient.fromMap(i as Map<String, dynamic>))
          .toList(),
      instructions: List<String>.from(json['instructions'] ?? []),
      substitutions: List<String>.from(json['substitutions'] ?? []),
      prepAheadNote: json['prepAheadNote'] as String? ?? '',
      pcodTip: json['pcodTip'] as String? ?? json['pcosTip'] as String? ?? '',
    );
  }
}
