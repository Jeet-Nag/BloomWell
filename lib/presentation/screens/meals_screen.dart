import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../data/datasources/weekly_menu_data.dart';
import '../controllers/app_controller.dart';
import 'recipe_detail_screen.dart';

class MealsScreen extends StatefulWidget {
  final AppController controller;

  const MealsScreen({super.key, required this.controller});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  late int _selectedDay; // 1 = Monday ... 7 = Sunday

  final List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _dayNamesFull = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  final List<String> _dayNamesHi = ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
  final List<String> _dayNamesFullHi = [
    'सोमवार',
    'मंगलवार',
    'बुधवार',
    'गुरुवार',
    'शुक्रवार',
    'शनिवार',
    'रविवार'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().weekday; // defaults to current day of the week
  }

  String _getMealTypeLabel(String mealType, String lang) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return lang == 'hi' ? 'नाश्ता (Breakfast)' : 'Breakfast (Nashta)';
      case 'lunch':
        return lang == 'hi' ? 'दोपहर का खाना (Lunch)' : 'Lunch (Dopahar ka Khana)';
      case 'dinner':
        return lang == 'hi' ? 'रात का खाना (Dinner)' : 'Dinner (Raat ka Khana)';
      default:
        return mealType;
    }
  }

  IconData _getMealIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'lunch':
        return Icons.lunch_dining_outlined;
      case 'dinner':
        return Icons.dinner_dining_outlined;
      default:
        return Icons.restaurant;
    }
  }

  Color _getMealColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return AppColors.softAmber;
      case 'lunch':
        return AppColors.sageDark;
      case 'dinner':
        return AppColors.softBlue;
      default:
        return AppColors.sagePrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.controller.language;
    final isHindi = lang == 'hi';
    final entries = WeeklyMenuData.weeklyMenu.where((e) => e.dayOfWeek == _selectedDay).toList();
    final dayLabel = isHindi ? _dayNamesFullHi[_selectedDay - 1] : _dayNamesFull[_selectedDay - 1];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('mealsTitle', lang: lang)),
      ),
      body: Column(
        children: [
          // Day Selector (Mon - Sun)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final dayNum = index + 1;
                final isSelected = _selectedDay == dayNum;
                final label = isHindi ? _dayNamesHi[index] : _dayNames[index];
                final isToday = dayNum == DateTime.now().weekday;

                return InkWell(
                  onTap: () => setState(() => _selectedDay = dayNum),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.sagePrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (isToday)
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : AppColors.sagePrimary,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 5),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1),

          // Day Heading Subtitle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.sageDark),
                const SizedBox(width: 8),
                Text(
                  isHindi ? '$dayLabel का संतुलित मेनू' : "$dayLabel's Balanced Menu",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                if (_selectedDay == DateTime.now().weekday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.sageBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isHindi ? 'आज' : 'Today',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sageDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Meal Cards List (Breakfast, Lunch, Dinner)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: entries.length,
              itemBuilder: (context, idx) {
                final entry = entries[idx];
                final recipe = WeeklyMenuData.getRecipe(entry.recipeId)!;
                final isPrepared = widget.controller.preparedMealIds.contains(entry.id);
                final mealLabel = _getMealTypeLabel(entry.mealType, lang);
                final mealColor = _getMealColor(entry.mealType);
                final displayName = isHindi ? entry.titleHi : entry.title;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isPrepared ? AppColors.sagePrimary.withValues(alpha: 0.5) : AppColors.borderLight,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => RecipeDetailScreen(
                            menuEntry: entry,
                            recipe: recipe,
                            controller: widget.controller,
                          ),
                        ),
                      ).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: mealColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_getMealIcon(entry.mealType), color: mealColor, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                mealLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: mealColor,
                                ),
                              ),
                              const Spacer(),
                              if (isPrepared)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.sageBackground,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle, size: 14, color: AppColors.sageDark),
                                      const SizedBox(width: 4),
                                      Text(
                                        isHindi ? 'तैयार' : 'Prepared',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.sageDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                isHindi
                                    ? '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} मिनट • ${recipe.servings} व्यक्ति'
                                    : '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} mins • ${recipe.servings} serving',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Text(
                                    isHindi ? 'रेसिपी देखें' : 'View Recipe',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.sageDark,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.chevron_right, size: 16, color: AppColors.sageDark),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
