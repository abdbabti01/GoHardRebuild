import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/go_icon.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'nutrient_coverage.dart';
import 'nutrition_surface.dart' show formatKcal;
import 'water.dart';

/// Eat › History (docs/FOOD_DATA.md › History): a calendar to choose any day, and the days that have something
/// recorded, newest first, each with what was really logged (known calories as known; water). Choosing a day returns
/// its key: Eat then shows that day's meals and water, dated, with Back to today. Nothing is compared with a goal:
/// past days' goals were not kept.
class NutritionHistoryScreen extends ConsumerWidget {
  const NutritionHistoryScreen({super.key, required this.selected});
  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayKeyProvider);
    final food = ref.watch(foodJournalProvider);
    final water = ref.watch(waterEntriesProvider);
    final showWater = ref.watch(nutritionDisplayProvider).water;
    final unit = ref.watch(volumeUnitProvider);
    final loaded = food.hasValue && water.hasValue;
    final byDay = <String, ({List<FoodEntry> food, List<WaterEntry> water})>{};
    for (final r in food.value ?? const <Stored<FoodEntry>>[]) {
      if (r.value.isDeleted) continue;
      (byDay[r.value.dayKey] ??= (food: [], water: [])).food.add(r.value);
    }
    for (final r in water.value ?? const <Stored<WaterEntry>>[]) {
      if (r.value.isDeleted) continue;
      (byDay[r.value.dayKey] ??= (food: [], water: [])).water.add(r.value);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final first = days.isEmpty ? addDays(today, -365) : (days.last.compareTo(addDays(today, -365)) < 0 ? days.last : addDays(today, -365));
    void open(String day) => Navigator.of(context).pop(day);

    String summary(({List<FoodEntry> food, List<WaterEntry> water}) d) {
      final kcal = NutrientCoverage.calculate(d.food)[Nutrient.calories]!;
      return [
        if (d.food.isNotEmpty) '${d.food.length} ${d.food.length == 1 ? 'food' : 'foods'}',
        if (d.food.isNotEmpty) !kcal.hasAnyKnown ? 'calories unknown' : '${formatKcal(kcal.knownTotal)} kcal${kcal.isComplete ? '' : ' known'}',
        if (d.water.isNotEmpty && showWater) '${unit.format(waterTotal(d.water))} water',
      ].join(' · ');
    }

    return AppPage(
      title: 'History',
      subtitle: 'Your meals and water, by day',
      children: [
        Text('Choose a day to see what was logged on it.', style: context.caption),
        CalendarDatePicker(
          key: const Key('history-calendar'),
          initialDate: parseDayKey(selected), firstDate: parseDayKey(first), lastDate: parseDayKey(today), currentDate: parseDayKey(today),
          onDateChanged: (d) => open(dayKeyOf(d)),
        ),
        const SizedBox(height: 8),
        Text('Days with entries', style: context.label),
        const SizedBox(height: 8),
        if (!loaded)
          const StatusLine(Icons.hourglass_empty, 'Reading your journal on this phone…')
        else if (days.isEmpty)
          const EmptyState('Nothing logged yet', 'Days you log food or water on are listed here.')
        else
          GroupCard(children: [
            for (final day in days)
              GroupRow(
                key: Key('history-day-$day'), leading: const GoIcon(GoGlyph.history),
                title: day == today ? 'Today' : longDate(day), subtitle: summary(byDay[day]!),
                onTap: () => open(day),
              ),
          ]),
        if (loaded && days.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Totals add up only what was logged; a food without a calorie value is not counted as zero.', style: context.caption)),
      ],
    );
  }
}
