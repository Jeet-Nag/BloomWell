import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../data/datasources/weekly_menu_data.dart';
import '../controllers/app_controller.dart';

class RecipeDetailScreen extends StatefulWidget {
  final WeeklyMenuEntry menuEntry;
  final RecipeData recipe;
  final AppController controller;

  const RecipeDetailScreen({
    super.key,
    required this.menuEntry,
    required this.recipe,
    required this.controller,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isPrepared = false;

  @override
  void initState() {
    super.initState();
    _isPrepared = widget.controller.preparedMealIds.contains(widget.menuEntry.id);
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
    final title = isHindi ? widget.menuEntry.titleHi : widget.menuEntry.title;
    final mealLabel = _getMealTypeLabel(widget.menuEntry.mealType, lang);
    final mealColor = _getMealColor(widget.menuEntry.mealType);
    final steps = isHindi ? widget.recipe.instructionsHi : widget.recipe.instructions;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: AppStrings.get('back', lang: lang),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isHindi ? 'रेसिपी विवरण' : 'Recipe Details',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
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
                        child: Icon(_getMealIcon(widget.menuEntry.mealType), color: mealColor, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        mealLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: mealColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      height: 1.25,
                    ),
                  ),
                  if (isHindi && widget.menuEntry.title != widget.menuEntry.titleHi) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.menuEntry.title,
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Info chips row: Prep, Cook, Servings
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        Icons.timer_outlined,
                        isHindi
                            ? 'तैयारी: ${widget.recipe.prepTimeMinutes} मिनट'
                            : 'Prep: ${widget.recipe.prepTimeMinutes} mins',
                      ),
                      _buildInfoChip(
                        Icons.local_fire_department_outlined,
                        isHindi
                            ? 'पकाना: ${widget.recipe.cookTimeMinutes} मिनट'
                            : 'Cook: ${widget.recipe.cookTimeMinutes} mins',
                      ),
                      _buildInfoChip(
                        Icons.room_service_outlined,
                        isHindi
                            ? '${widget.recipe.servings} व्यक्ति'
                            : '${widget.recipe.servings} Serving',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Ingredients Section
            Text(
              isHindi ? 'सामग्री और मात्रा (Ingredients & Portions)' : 'Ingredients & Portions',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: widget.recipe.ingredients.length,
                separatorBuilder: (_, index) => const Divider(height: 12),
                itemBuilder: (context, idx) {
                  final ing = widget.recipe.ingredients[idx];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle, size: 6, color: AppColors.sagePrimary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ing.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Text(
                        ing.quantity,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sageDark,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 22),

            // Preparation Steps Section
            Text(
              isHindi ? 'बनाने की सरल विधि (Step-by-Step Instructions)' : 'Preparation Steps',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(steps.length, (idx) {
                  final step = steps[idx];
                  return Padding(
                    padding: EdgeInsets.only(bottom: idx == steps.length - 1 ? 0 : 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.sageBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.sagePrimary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.sageDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),

            // Simple Substitutions Section
            if (widget.recipe.substitutions.isNotEmpty) ...[
              Text(
                isHindi ? 'सरल विकल्प (Simple Substitutions)' : 'Simple Substitutions',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lavenderLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.mutedLavender.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: widget.recipe.substitutions.map((sub) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.swap_horiz, size: 18, color: AppColors.mutedLavender),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sub,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textDark,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Mark as Prepared Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPrepared ? AppColors.sageLight : AppColors.sagePrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(
                  _isPrepared ? Icons.check_circle : Icons.done_all,
                  color: Colors.white,
                ),
                label: Text(
                  _isPrepared
                      ? (isHindi ? 'तैयार किया गया ✓' : 'Prepared & Logged ✓')
                      : (isHindi ? 'तैयार हुआ मार्क करें' : 'Mark as Prepared Today'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: () async {
                  await widget.controller.markMealPrepared(
                    widget.menuEntry.id,
                    widget.menuEntry.mealType,
                  );
                  setState(() => _isPrepared = true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isHindi
                              ? 'भोजन दर्ज किया गया! आपकी आदत की प्रगति जारी है।'
                              : 'Meal logged! Your wellness streak continues.',
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.sageDark,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.sageBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.sageDark),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.sageDark,
            ),
          ),
        ],
      ),
    );
  }
}
