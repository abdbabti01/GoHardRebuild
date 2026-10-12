import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'food_form.dart';
import 'nutrient_coverage.dart';
import 'nutrition_surface.dart';

/// The dated food journal: Breakfast, Lunch, Dinner and Snack, built only from food the user logged as eaten.
class EatScreen extends ConsumerStatefulWidget {
  const EatScreen({super.key});
  @override
  ConsumerState<EatScreen> createState() => _EatScreenState();
}

class _EatScreenState extends ConsumerState<EatScreen> {
  /// Null = follow the shared "today"; a picked day stays put when midnight passes.
  String? _picked;

  static String _known(FoodEntry e) {
    final parts = [
      if (e.calories != null) '${formatNumber(e.calories!)} kcal',
      if (e.protein != null) 'P ${formatNumber(e.protein!)} g',
      if (e.carbs != null) 'C ${formatNumber(e.carbs!)} g',
      if (e.fat != null) 'F ${formatNumber(e.fat!)} g',
    ];
    return parts.isEmpty ? 'No nutrition entered' : parts.join(' · ');
  }

  /// A meal's calories from its own entries: a sum of what is known, labelled when some are unknown.
  static String _mealCalories(List<FoodEntry> entries) {
    final t = NutrientCoverage.calculate(entries)[Nutrient.calories]!;
    return !t.hasAnyKnown ? 'Calories unknown' : '${formatNumber(t.knownTotal)} kcal${t.isComplete ? '' : ' known'}';
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayKeyProvider);
    final day = _picked ?? today;
    final rows = ref.watch(foodProvider(day));
    final live = [for (final r in rows.value ?? const <Stored<FoodEntry>>[]) if (!r.value.isDeleted) r];
    final entries = [for (final r in live) r.value];
    final pendingCount = live.where((r) => r.isPending).length;

    return RefreshIndicator(
      onRefresh: () => refreshFromAccount(ref),
      child: ListView(
        padding: EdgeInsets.fromLTRB(context.inset, 14, context.inset, 28),
        children: [
          const Heading('Eat'),
          const SizedBox(height: 4),
          Row(children: [
            IconButton(tooltip: 'Previous day', icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _picked = addDays(day, -1))),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(day == today ? 'Today · ${longDate(day)}' : longDate(day), textAlign: TextAlign.center, style: context.sansStyle(15.5, weight: FontWeight.w600)),
              ),
            ),
            IconButton(tooltip: 'Next day', icon: const Icon(Icons.chevron_right), onPressed: day.compareTo(today) >= 0 ? null : () => setState(() => _picked = addDays(day, 1) == today ? null : addDays(day, 1))),
          ]),
          if (day != today) Center(child: TextButton(onPressed: () => setState(() => _picked = null), child: const Text('Back to today'))),
          const SizedBox(height: 10),
          if (rows.hasError)
            const Panel(child: StatusLine(Icons.error_outline, 'Your food journal could not be read from this phone. Pull down to try again.', tone: Tone.error))
          else if (!rows.hasValue)
            const Panel(child: StatusLine(Icons.hourglass_empty, 'Loading your journal…'))
          else ...[
            NutritionSurface(entries: entries, coverage: NutrientCoverage.calculate(entries),
                calorieGoal: ref.watch(profileProvider).value?.calorieGoal, proteinGoal: ref.watch(profileProvider).value?.proteinGoal, pending: pendingCount > 0, onLogFood: () => openFoodForm(context, dayKey: day)),
            const SizedBox(height: 28),
            SectionHeader(day == today ? 'Logged today' : 'Logged this day'),
            const SizedBox(height: 2),
            Text('Only food you logged as eaten appears here.', style: context.caption),
            for (final meal in meals)
              () {
                final mine = [for (final r in live) if (r.value.meal == meal) r];
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Semantics(header: true, child: Text(meal, style: context.sansStyle(17, weight: FontWeight.w700))),
                        Text(mine.isEmpty ? 'Nothing logged' : _mealCalories([for (final r in mine) r.value]), style: context.caption),
                      ]),
                    ),
                    IconButton(
                      key: Key('eat-add-${meal.toLowerCase()}'), tooltip: 'Add to ${meal.toLowerCase()}',
                      icon: Icon(Icons.add_circle_outline, color: context.c.accent), onPressed: () => openFoodForm(context, dayKey: day, meal: meal),
                    ),
                  ]),
                  const Rule(),
                  for (final r in mine)
                    ListRow(
                      key: Key('food-row-${r.value.id}'),
                      title: r.value.name,
                      subtitle: '${r.value.amountDescription} · ${_known(r.value)}${r.needsReview ? ' · needs review' : r.isPending ? ' · sync pending' : ''}',
                      onTap: () => openFoodForm(context, dayKey: day, entry: r.value),
                    ),
                ]);
              }(),
          ],
        ],
      ),
    );
  }
}
