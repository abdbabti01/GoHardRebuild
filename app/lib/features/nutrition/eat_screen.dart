import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../coach/coach_avatar.dart';
import '../coach/coach_bubble.dart';
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
    return !t.hasAnyKnown ? 'Calories unknown' : '${formatKcal(t.knownTotal)} kcal${t.isComplete ? '' : ' known'}';
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

    // With very large text the decorative tile gives its room to the words.
    final roomy = MediaQuery.textScalerOf(context).scale(10) <= 15;
    final indent = roomy ? 16.0 : 12.0;

    return RefreshIndicator(
      edgeOffset: MediaQuery.paddingOf(context).top,
      onRefresh: () => refreshFromAccount(ref),
      child: ListView(
        // On the calm wash the shell lays behind Eat, with room for the floating bar at the end.
        padding: EdgeInsets.only(bottom: 28 + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.inset, TabHeader.topInset(context), context.inset, 18),
            child: TabHeader(
              title: 'Eat', overline: longDate(day),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                // Help with the journal from the same guide. Built-in words only: Ask GoHard answers training questions,
                // so nothing here offers to ask it about food.
                CoachHelpButton(
                  key: const Key('coach-help-eat'), semanticLabel: 'Help with your food journal',
                  onPressed: () => showCoachHelpSheet(context, title: 'Your food journal', say: const CoachSay(
                      'Add food under a meal: search, scan a barcode or enter your own. The totals add up only what you logged, and your goals are set in Me › Nutrition goals.')),
                ),
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
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.inset),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (rows.hasError)
                const Panel(child: StatusLine(Icons.error_outline, 'Your food journal could not be read from this phone. Pull down to try again.', tone: Tone.error))
              else if (!rows.hasValue)
                const Panel(child: StatusLine(Icons.hourglass_empty, 'Loading your journal…'))
              else ...[
                // The day's summary as a photo panel, with the one general Log food in it.
                NutritionSurface(
                  entries: entries, coverage: NutrientCoverage.calculate(entries), calorieGoal: profile?.calorieGoal, proteinGoal: profile?.proteinGoal, pending: live.any((r) => r.isPending),
                  action: PrimaryButton('Log food', key: const Key('log-food'), icon: Icons.restaurant, expand: false, onPressed: () => openFoodForm(context, dayKey: day)),
                ),
                const SizedBox(height: 28),
                Heading(day == today ? 'Today\'s meals' : 'Meals', size: 20),
                const SizedBox(height: 12),
                // One quiet group per meal: the meal (tile, name, what its foods add up to), each logged food as its
                // own row, then "Add food to <meal>", which opens Log food for this meal. No photographs here.
                for (final meal in meals) ...[
                  () {
                    final mine = [for (final r in live) if (r.value.meal == meal) r];
                    final label = meal.toLowerCase();
                    return GroupCard(children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(roomy ? 16 : 12, 12, 16, 12),
                        child: Row(children: [
                          if (roomy) ...[IconTile(_icons[meal] ?? Icons.restaurant, size: _tile), const SizedBox(width: 14)],
                          Expanded(
                            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
                              Semantics(header: true, child: Text(meal, style: context.sansStyle(17, weight: FontWeight.w700))),
                              Text(mine.isEmpty ? 'Nothing logged' : _mealCalories([for (final r in mine) r.value]),
                                  style: mine.isEmpty ? context.sansStyle(14.5, color: c.secondary) : context.numStyle(16, weight: FontWeight.w600)),
                            ]),
                          ),
                        ]),
                      ),
                      for (final r in mine) _EntryRow(r, indent: indent, detail: _detail(r), onTap: () => openFoodForm(context, dayKey: day, entry: r.value)),
                      GroupRow(
                        key: Key('eat-add-$label'), icon: Icons.add, title: 'Add food to $label', trailing: const SizedBox.shrink(),
                        onTap: () => openFoodForm(context, dayKey: day, meal: meal)),
                    ]);
                  }(),
                  const SizedBox(height: 12),
                ],
                Text('Only food you logged as eaten appears here.', style: context.caption),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  static const _tile = 40.0;
}

/// One logged food under its meal: the saved name, then the saved portion and known values; its calories at the
/// trailing edge (a dash when unknown, never a zero). Opens the entry for editing. With large text the calories
/// move under the name instead of squeezing it.
class _EntryRow extends StatelessWidget {
  const _EntryRow(this.r, {required this.indent, required this.detail, required this.onTap});
  final Stored<FoodEntry> r;
  final double indent;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = r.value;
    final name = Text(e.name, style: context.sansStyle(15.5, weight: FontWeight.w500));
    final kcal = Text('${e.calories == null ? '—' : formatKcal(e.calories!)} kcal', style: context.numStyle(14.5, color: context.c.secondary, weight: FontWeight.w500));
    return Semantics(
      button: true,
      child: InkWell(
        key: Key('food-row-${e.id}'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Targets.minimum + 8),
          child: Padding(
            padding: EdgeInsets.fromLTRB(indent, 8, 12, 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  if (MediaQuery.textScalerOf(context).scale(10) <= 13)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: name), const SizedBox(width: 12), kcal])
                  else
                    Wrap(spacing: 12, runSpacing: 2, children: [name, kcal]),
                  Padding(padding: const EdgeInsets.only(top: 1), child: Text(detail, style: context.caption)),
                ]),
              ),
              Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.chevron_right, size: 20, color: context.c.secondary)),
            ]),
          ),
        ),
      ),
    );
  }
}
