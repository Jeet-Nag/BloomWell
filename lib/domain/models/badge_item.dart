class BadgeItem {
  final String id;
  final String name;
  final String nameHi;
  final String description;
  final String descriptionHi;
  final String category;
  final String icon;
  final DateTime? earnedAt;

  const BadgeItem({
    required this.id,
    required this.name,
    required this.nameHi,
    required this.description,
    required this.descriptionHi,
    required this.category,
    required this.icon,
    this.earnedAt,
  });

  bool get isEarned => earnedAt != null;

  factory BadgeItem.fromJson(Map<String, dynamic> json, {DateTime? earnedAt}) {
    return BadgeItem(
      id: json['id'] as String,
      name: json['name'] as String,
      nameHi: json['nameHi'] as String? ?? json['name'] as String,
      description: json['description'] as String,
      descriptionHi: json['descriptionHi'] as String? ?? json['description'] as String,
      category: json['category'] as String,
      icon: json['icon'] as String? ?? 'workspace_premium',
      earnedAt: earnedAt,
    );
  }

  BadgeItem copyWithEarned(DateTime date) {
    return BadgeItem(
      id: id,
      name: name,
      nameHi: nameHi,
      description: description,
      descriptionHi: descriptionHi,
      category: category,
      icon: icon,
      earnedAt: date,
    );
  }
}
