import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/models/badge_item.dart';
import '../database/database_helper.dart';

class BadgeRepository {
  final DatabaseHelper dbHelper;
  List<BadgeItem>? _allBadges;

  BadgeRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<BadgeItem>> loadAllBadgesDefinition() async {
    if (_allBadges != null) return _allBadges!;

    final jsonString = await rootBundle.loadString('assets/data/badges.json');
    final List dynamicList = jsonDecode(jsonString) as List;
    _allBadges = dynamicList
        .map((item) => BadgeItem.fromJson(item as Map<String, dynamic>))
        .toList();
    return _allBadges!;
  }

  Future<Map<String, DateTime>> getEarnedBadgeMap() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('earned_badges');
    final result = <String, DateTime>{};
    for (final m in maps) {
      final id = m['badgeId'] as String;
      final date = DateTime.parse(m['earnedAt'] as String);
      result[id] = date;
    }
    return result;
  }

  Future<List<BadgeItem>> getAllBadgesWithStatus() async {
    final defs = await loadAllBadgesDefinition();
    final earnedMap = await getEarnedBadgeMap();

    return defs.map((b) {
      final earnedDate = earnedMap[b.id];
      return BadgeItem(
        id: b.id,
        name: b.name,
        nameHi: b.nameHi,
        description: b.description,
        descriptionHi: b.descriptionHi,
        category: b.category,
        icon: b.icon,
        earnedAt: earnedDate,
      );
    }).toList();
  }

  /// Award a badge if not already earned. Returns true if newly awarded.
  Future<bool> awardBadge(String badgeId, {String reason = ''}) async {
    final db = await dbHelper.database;
    final existing = await db.query(
      'earned_badges',
      where: 'badgeId = ?',
      whereArgs: [badgeId],
    );
    if (existing.isNotEmpty) {
      return false; // Already earned, duplicate prevented!
    }

    await db.insert('earned_badges', {
      'badgeId': badgeId,
      'earnedAt': DateTime.now().toIso8601String(),
      'reason': reason,
    });
    return true;
  }
}
