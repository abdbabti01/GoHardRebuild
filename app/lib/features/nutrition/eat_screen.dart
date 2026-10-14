import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../weather/weather.dart';
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

    final roomy = MediaQuery.textScalerOf(context).scale(10) <= 15;
    // Entries line up under their meal's name; with very large text the decorative tile gives its room to the words.
    final indent = roomy ? 16.0 + _tile + 14 : 12.0;

    return RefreshIndicator(
      edgeOffset: MediaQuery.paddingOf(context).top,
      onRefresh: () => refreshFromAccount(ref),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          // The quiet dusk scene behind the date and the title only; everything below sits on the page.
          Stack(children: [
            const Positioned.fill(child: ScenicBackdrop()),
            Padding(
              padding: EdgeInsets.fromLTRB(context.inset, TabHeader.topOnBackdrop(context), context.inset, 18),
              child: TabHeader(
                title: 'Eat', overline: longDate(day), onBackdrop: true,
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
            ),
          ]),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.inset),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (rows.hasError)
                const Panel(child: StatusLine(Icons.error_outline, 'Your food journal could not be read from this phone. Pull down to try again.', tone: Tone.error))
              else if (!rows.hasValue)
                const Panel(child: StatusLine(Icons.hourglass_empty, 'Loading your journal…'))
              else ...[
                NutritionSurface(entries: entries, coverage: NutrientCoverage.calculate(entries), calorieGoal: profile?.calorieGoal, proteinGoal: profile?.proteinGoal, pending: live.any((r) => r.isPending)),
                const SizedBox(height: 14),
                PrimaryButton('Log food', key: const Key('log-food'), icon: Icons.add, onPressed: () => openFoodForm(context, dayKey: day)),
                const SizedBox(height: 28),
                Heading(day == today ? 'Today\'s meals' : 'Meals', size: 28, serif: true),
                const SizedBox(height: 12),
                // All four meals in one group: the meal (tile, name, what its foods add up to, a plus that opens Log
                // food for this meal), then each logged food as its own row.
                GroupCard(children: [
                  for (final meal in meals)
                    () {
                      final mine = [for (final r in live) if (r.value.meal == meal) r];
                      final label = meal.toLowerCase();
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(roomy ? 16 : 12, 10, 12, mine.isEmpty ? 10 : 2),
                          child: Row(children: [
                            if (roomy) ...[IconTile(_icons[meal] ?? Icons.restaurant, size: _tile), const SizedBox(width: 14)],
                            Expanded(
                              child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
                                Semantics(header: true, child: Text(meal, style: context.sansStyle(17, weight: FontWeight.w700))),
                                Text(mine.isEmpty ? 'Nothing logged' : _mealCalories([for (final r in mine) r.value]),
                                    style: mine.isEmpty ? context.sansStyle(14.5, color: c.secondary) : context.numStyle(16, weight: FontWeight.w600)),
                              ]),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              key: Key('eat-add-$label'), tooltip: 'Add to $label', onPressed: () => openFoodForm(context, dayKey: day, meal: meal),
                              style: IconButton.styleFrom(backgroundColor: c.accentSoft), icon: Icon(Icons.add, color: c.accent)),
                          ]),
                        ),
                        for (final r in mine) _EntryRow(r, indent: indent, detail: _detail(r), onTap: () => openFoodForm(context, dayKey: day, entry: r.value)),
                        if (mine.isNotEmpty) const SizedBox(height: 6),
                      ]);
                    }(),
                ]),
                const SizedBox(height: 12),
                Text('Only food you logged as eaten appears here.', style: context.caption),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  static const _tile = 44.0;
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
    final kcal = Text('${e.calories == null ? '—' : formatNumber(e.calories!)} kcal', style: context.numStyle(14.5, color: context.c.secondary, weight: FontWeight.w500));
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
