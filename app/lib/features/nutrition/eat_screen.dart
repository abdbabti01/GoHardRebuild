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

/// The dated food journal: the day's overview, one Log food action, then Breakfast, Lunch, Dinner and Snack,
/// built only from food the user logged as eaten. Each entry is its own row with the name, portion and values
/// that were saved with it; nothing is merged into a meal name or worked out again from a food database.
class EatScreen extends ConsumerStatefulWidget {
  const EatScreen({super.key});
  @override
  ConsumerState<EatScreen> createState() => _EatScreenState();
}

class _EatScreenState extends ConsumerState<EatScreen> {
  /// Null = follow the shared "today"; a picked day stays put when midnight passes.
  String? _picked;

  static const _icons = {'Breakfast': Icons.egg_alt_outlined, 'Lunch': Icons.lunch_dining_outlined, 'Dinner': Icons.dinner_dining_outlined, 'Snack': Icons.cookie_outlined};

  /// The portion as it was saved, then the macros that are known, then how the record stands with the account.
  static String _detail(Stored<FoodEntry> r) {
    final e = r.value;
    final macros = [
      if (e.protein != null) 'P ${formatNumber(e.protein!)} g',
      if (e.carbs != null) 'C ${formatNumber(e.carbs!)} g',
      if (e.fat != null) 'F ${formatNumber(e.fat!)} g',
    ];
    return [
      e.amountDescription,
      if (macros.isNotEmpty) macros.join(' · ') else if (e.calories == null) 'No nutrition entered',
      if (r.needsReview) 'needs review' else if (r.isPending) 'sync pending',
    ].join(' · ');
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
    final profile = ref.watch(profileProvider).value;
    final c = context.c;

    return RefreshIndicator(
      onRefresh: () => refreshFromAccount(ref),
      child: ListView(
        padding: EdgeInsets.fromLTRB(context.inset, 14, context.inset, 28),
        children: [
          TabHeader(
            title: 'Eat', overline: longDate(day),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'Previous day', icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _picked = addDays(day, -1))),
              IconButton(tooltip: 'Next day', icon: const Icon(Icons.chevron_right), onPressed: day.compareTo(today) >= 0 ? null : () => setState(() => _picked = addDays(day, 1) == today ? null : addDays(day, 1))),
            ]),
            below: day == today
                ? null
                : Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(key: const Key('eat-back-to-today'), onPressed: () => setState(() => _picked = null), icon: const Icon(Icons.today, size: 18), label: const Text('Back to today')),
                  ),
          ),
          const SizedBox(height: 14),
          if (rows.hasError)
            const Panel(child: StatusLine(Icons.error_outline, 'Your food journal could not be read from this phone. Pull down to try again.', tone: Tone.error))
          else if (!rows.hasValue)
            const Panel(child: StatusLine(Icons.hourglass_empty, 'Loading your journal…'))
          else ...[
            NutritionSurface(entries: entries, coverage: NutrientCoverage.calculate(entries), calorieGoal: profile?.calorieGoal, proteinGoal: profile?.proteinGoal, pending: live.any((r) => r.isPending)),
            const SizedBox(height: 12),
            PrimaryButton('Log food', key: const Key('log-food'), icon: Icons.add, onPressed: () => openFoodForm(context, dayKey: day)),
            const SizedBox(height: 26),
            SectionHeader(day == today ? 'Today\'s meals' : 'Meals'),
            for (final meal in meals)
              () {
                final mine = [for (final r in live) if (r.value.meal == meal) r];
                final label = meal.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GroupCard(children: [
                    // The meal: its name, what its foods add up to, and a plus that opens Log food for this meal.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(children: [
                        if (MediaQuery.textScalerOf(context).scale(10) <= 15) ...[IconTile(_icons[meal] ?? Icons.restaurant, size: 36), const SizedBox(width: 12)],
                        Expanded(
                          child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
                            Semantics(header: true, child: Text(meal, style: context.sansStyle(17, weight: FontWeight.w700))),
                            Text(mine.isEmpty ? 'Nothing logged' : _mealCalories([for (final r in mine) r.value]), style: context.numStyle(14.5, color: c.secondary, weight: FontWeight.w500)),
                          ]),
                        ),
                        IconButton(key: Key('eat-add-$label'), tooltip: 'Add to $label', icon: Icon(Icons.add_circle_outline, color: c.accent), onPressed: () => openFoodForm(context, dayKey: day, meal: meal)),
                      ]),
                    ),
                    for (final r in mine)
                      GroupRow(
                        key: Key('food-row-${r.value.id}'),
                        title: r.value.name,
                        // Unknown calories are a dash, never a zero.
                        value: '${r.value.calories == null ? '—' : formatNumber(r.value.calories!)} kcal',
                        subtitle: _detail(r),
                        onTap: () => openFoodForm(context, dayKey: day, entry: r.value),
                      ),
                  ]),
                );
              }(),
            const SizedBox(height: 12),
            Text('Only food you logged as eaten appears here.', style: context.caption),
          ],
        ],
      ),
    );
  }
}
