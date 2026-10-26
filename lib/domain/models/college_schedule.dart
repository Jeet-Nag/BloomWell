class CollegeSchedule {
  final String date; // yyyy-MM-dd
  final bool goingToCollege;
  final bool hasClasses;
  final String? collegeStartTime; // "08:30"
  final String? collegeEndTime; // "16:30"
  final String? classStartTime; // "09:00"
  final String? classEndTime; // "10:30"
  final DateTime updatedAt;

  const CollegeSchedule({
    required this.date,
    required this.goingToCollege,
    required this.hasClasses,
    this.collegeStartTime,
    this.collegeEndTime,
    this.classStartTime,
    this.classEndTime,
    required this.updatedAt,
  });

  bool get isCollegeConfigured => goingToCollege && collegeStartTime != null && collegeEndTime != null;
  bool get isClassConfigured => hasClasses && classStartTime != null && classEndTime != null;

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'goingToCollege': goingToCollege ? 1 : 0,
      'hasClasses': hasClasses ? 1 : 0,
      'collegeStartTime': collegeStartTime,
      'collegeEndTime': collegeEndTime,
      'classStartTime': classStartTime,
      'classEndTime': classEndTime,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CollegeSchedule.fromMap(Map<String, dynamic> map) {
    return CollegeSchedule(
      date: map['date'] as String,
      goingToCollege: (map['goingToCollege'] as int? ?? 0) == 1,
      hasClasses: (map['hasClasses'] as int? ?? 0) == 1,
      collegeStartTime: map['collegeStartTime'] as String?,
      collegeEndTime: map['collegeEndTime'] as String?,
      classStartTime: map['classStartTime'] as String?,
      classEndTime: map['classEndTime'] as String?,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  CollegeSchedule copyWith({
    String? date,
    bool? goingToCollege,
    bool? hasClasses,
    String? collegeStartTime,
    String? collegeEndTime,
    String? classStartTime,
    String? classEndTime,
    DateTime? updatedAt,
  }) {
    return CollegeSchedule(
      date: date ?? this.date,
      goingToCollege: goingToCollege ?? this.goingToCollege,
      hasClasses: hasClasses ?? this.hasClasses,
      collegeStartTime: collegeStartTime ?? this.collegeStartTime,
      collegeEndTime: collegeEndTime ?? this.collegeEndTime,
      classStartTime: classStartTime ?? this.classStartTime,
      classEndTime: classEndTime ?? this.classEndTime,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
