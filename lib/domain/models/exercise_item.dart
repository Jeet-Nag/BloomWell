class ExerciseItem {
  final String id;
  final String name;
  final String nameHi;
  final String category; // warmup, yoga, strength, walking, cooldown, recovery
  final String difficulty; // gentle, easy, beginner
  final int durationSeconds;
  final String? repetitions;
  final String targetMuscles;
  final List<String> instructions;
  final String safetyPrecautions;
  final String easierModification;
  final String benefits;
  final String iconName;

  const ExerciseItem({
    required this.id,
    required this.name,
    required this.nameHi,
    required this.category,
    required this.difficulty,
    required this.durationSeconds,
    this.repetitions,
    required this.targetMuscles,
    required this.instructions,
    required this.safetyPrecautions,
    required this.easierModification,
    required this.benefits,
    required this.iconName,
  });

  factory ExerciseItem.fromJson(Map<String, dynamic> json) {
    return ExerciseItem(
      id: json['id'] as String,
      name: json['name'] as String,
      nameHi: json['nameHi'] as String? ?? json['name'] as String,
      category: json['category'] as String,
      difficulty: json['difficulty'] as String? ?? 'beginner',
      durationSeconds: json['durationSeconds'] as int? ?? 120,
      repetitions: json['repetitions'] as String?,
      targetMuscles: json['targetMuscles'] as String? ?? '',
      instructions: List<String>.from(json['instructions'] ?? []),
      safetyPrecautions: json['safetyPrecautions'] as String? ?? '',
      easierModification: json['easierModification'] as String? ?? '',
      benefits: json['benefits'] as String? ?? '',
      iconName: json['iconName'] as String? ?? 'fitness_center',
    );
  }
}

class WorkoutLog {
  final int? id;
  final String exerciseId;
  final String exerciseName;
  final DateTime completedAt;
  final int durationSeconds;
  final double estimatedCalories;

  const WorkoutLog({
    this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.completedAt,
    required this.durationSeconds,
    required this.estimatedCalories,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'completedAt': completedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'estimatedCalories': estimatedCalories,
    };
  }

  factory WorkoutLog.fromMap(Map<String, dynamic> map) {
    return WorkoutLog(
      id: map['id'] as int?,
      exerciseId: map['exerciseId'] as String,
      exerciseName: map['exerciseName'] as String,
      completedAt: DateTime.parse(map['completedAt'] as String),
      durationSeconds: map['durationSeconds'] as int,
      estimatedCalories: (map['estimatedCalories'] as num).toDouble(),
    );
  }
}
