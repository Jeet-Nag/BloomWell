import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../domain/calculators/weight_metrics_calculator.dart';
import '../controllers/app_controller.dart';

class ProgressScreen extends StatefulWidget {
  final AppController controller;

  const ProgressScreen({super.key, required this.controller});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddWeightDialog() {
    final textController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('recordWeight', lang: widget.controller.language)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppStrings.get('enterWeightKg', lang: widget.controller.language),
                suffixText: 'kg',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: AppStrings.get('notesOptional', lang: widget.controller.language),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get('cancel', lang: widget.controller.language)),
          ),
          ElevatedButton(
            onPressed: () {
              final w = double.tryParse(textController.text.trim());
              if (w != null && w > 20 && w < 300) {
                widget.controller.recordWeight(w, notes: notesController.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: Text(AppStrings.get('save', lang: widget.controller.language)),
          ),
        ],
      ),
    );
  }

  void _exportCsv() {
    final clientName = widget.controller.profile?.name;
    final csv = WeightMetricsCalculator.generateCsv(
      widget.controller.weightEntries,
      clientName: clientName,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          clientName != null && clientName.trim().isNotEmpty
              ? 'Local CSV Export ($clientName)'
              : 'Local CSV Data Export',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              csv,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.controller.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('tabProgress', lang: lang)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: AppStrings.get('exportCsv', lang: lang),
            onPressed: _exportCsv,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.sageDark,
          indicatorColor: AppColors.sagePrimary,
          tabs: [
            Tab(text: AppStrings.get('weightTitle', lang: lang), icon: const Icon(Icons.monitor_weight_outlined)),
            Tab(text: AppStrings.get('badgesTitle', lang: lang), icon: const Icon(Icons.emoji_events_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWeightTab(lang),
          _buildBadgesTab(lang),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.sagePrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(AppStrings.get('recordWeight', lang: lang)),
        onPressed: _showAddWeightDialog,
      ),
    );
  }

  // --- Tab 1: 15-Day Weight History & Charts ---
  Widget _buildWeightTab(String lang) {
    final entries = widget.controller.weightEntries;
    final summary = widget.controller.weightSummary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Headline Metrics Card
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            summary != null && summary.currentWeight > 0 ? '${summary.currentWeight} kg' : '--',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text('Current Weight', style: TextStyle(fontSize: 11, color: AppColors.textMuted), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                    Container(height: 30, width: 1, color: AppColors.borderLight),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            WeightMetricsCalculator.formatDelta(summary?.changeFromPrevious),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.sageDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(AppStrings.get('changeSinceLast', lang: lang), style: const TextStyle(fontSize: 11, color: AppColors.textMuted), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                    Container(height: 30, width: 1, color: AppColors.borderLight),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            WeightMetricsCalculator.formatDelta(summary?.changeFromBaseline),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mutedLavender),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(AppStrings.get('totalChange', lang: lang), style: const TextStyle(fontSize: 11, color: AppColors.textMuted), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCardMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    summary?.statusMessage ?? '',
                    style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Line Chart Card
        if (entries.length >= 2) ...[
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('15-Day Weight Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        titlesData: const FlTitlesData(
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: entries.asMap().entries.map((e) {
                              return FlSpot(e.key.toDouble(), e.value.weightKg);
                            }).toList(),
                            isCurved: true,
                            color: AppColors.sagePrimary,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.sageBackground.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Explanatory Note on Short-Term Shifts
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lavenderLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            AppStrings.get('weightSubtitle', lang: lang),
            style: const TextStyle(fontSize: 12, color: Color(0xFF42355B), height: 1.4),
          ),
        ),
        const SizedBox(height: 14),

        // Date-Stamped Entries List
        Text(
          AppStrings.get('weightHistory', lang: lang),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 8),

        if (entries.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No weight entries yet. Tap + to record baseline.', style: TextStyle(color: AppColors.textMuted)),
            ),
          )
        else
          ...entries.reversed.map((e) {
            final dateStr = DateFormat('dd MMM yyyy').format(e.timestamp);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.monitor_weight_outlined, color: AppColors.sagePrimary),
                title: Text('${e.weightKg.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$dateStr${e.notes != null && e.notes!.isNotEmpty ? ' • ${e.notes}' : ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.gentleCoral),
                  onPressed: () {
                    if (e.id != null) widget.controller.weightRepo.deleteEntry(e.id!);
                    widget.controller.initialize();
                  },
                ),
              ),
            );
          }),
        const SizedBox(height: 60), // FAB space
      ],
    );
  }

  // --- Tab 2: Gamification Badges ---
  Widget _buildBadgesTab(String lang) {
    final badges = widget.controller.badges;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: badges.length,
      itemBuilder: (context, idx) {
        final b = badges[idx];
        final isEarned = b.isEarned;
        final name = lang == 'hi' ? b.nameHi : b.name;
        final desc = lang == 'hi' ? b.descriptionHi : b.description;

        return Card(
          color: isEarned ? Colors.white : AppColors.surfaceCardMuted,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEarned ? AppColors.sageBackground : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getBadgeIcon(b.icon),
                    size: 28,
                    color: isEarned ? AppColors.sageDark : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isEarned ? AppColors.textDark : AppColors.textSubtle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  isEarned
                      ? '${AppStrings.get('earnedOn', lang: lang)} ${DateFormat('dd MMM').format(b.earnedAt!)}'
                      : AppStrings.get('locked', lang: lang),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isEarned ? AppColors.sagePrimary : AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getBadgeIcon(String name) {
    switch (name) {
      case 'water_drop':
        return Icons.water_drop;
      case 'local_drink':
        return Icons.local_drink;
      case 'directions_run':
        return Icons.directions_run;
      case 'map':
        return Icons.map;
      case 'monitor_weight':
        return Icons.monitor_weight;
      case 'event_available':
        return Icons.event_available;
      case 'restaurant':
        return Icons.restaurant;
      case 'nightlight_round':
        return Icons.nightlight_round;
      case 'bolt':
        return Icons.bolt;
      default:
        return Icons.workspace_premium;
    }
  }
}
