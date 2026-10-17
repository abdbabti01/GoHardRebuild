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
import '../coach/coach_prefs.dart';
import 'food_form.dart';
import 'nutrient_coverage.dart';
import 'nutrition_surface.dart';
import 'nutrition_tools.dart';
import 'water.dart';

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

  /// One family for the meals, the time of day they belong to: sunrise, sun, moon, and a snack. Outlined Material icons
  /// on the same tile, with the meal's name beside them.
  static const _icons = {'Breakfast': Icons.wb_twilight_outlined, 'Lunch': Icons.light_mode_outlined, 'Dinner': Icons.dark_mode_outlined, 'Snack': Icons.cookie_outlined};

  /// Built-in help with the journal. Ask GoHard answers training questions, so nothing here offers to ask it about food.
  static void _help(BuildContext context) => showCoachHelpSheet(context, title: 'Your food journal', say: const CoachSay(
      'Add food under a meal: search, scan a barcode or enter your own. The totals add up only what you logged. Your daily goals are set from the summary here, on Today or in Me.'));

  /// What the coach says on Eat: fixed words chosen from the account's own settings, never from the AI. Water is
  /// mentioned only where it is shown (turned on, and the server keeps it).
  static CoachSay _say(BuildContext context, WidgetRef ref, {required Profile? profile, required bool water}) {
    final hasGoal = profile != null && (profile.calorieGoal != null || profile.proteinGoal != null || profile.waterGoalMl != null);
    final text = water ? 'Log a meal or some water, and keep an eye on your daily goals.' : hasGoal ? 'Log a meal and see how it adds up against your daily goals.' : 'Log a meal or set your daily goals.';
    return CoachSay(text,
        guide: hasGoal || profile == null ? null : (label: 'Set daily goals', key: const Key('eat-coach-goals'), onPressed: () => showGoalsSheet(context, ref)));
  }

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
    final display = ref.watch(nutritionDisplayProvider);
    final c = context.c;

    final coachOn = ref.watch(coachPrefsProvider.select((p) => p.onTabs));
    final guide = ref.watch(coachPrefsProvider.select((p) => p.guide));

    // With very large text the meal icon gives its room to the words.
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
                // Help with the journal from the same guide: its small avatar here only while the speaking coach is off.
                if (!coachOn) CoachHelpButton(key: const Key('coach-help-eat'), semanticLabel: 'Help with your food journal', onPressed: () => _help(context)),
                IconButton(tooltip: 'Previous day', icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _picked = addDays(day, -1))),
                IconButton(tooltip: 'Next day', icon: const Icon(Icons.chevron_right), onPressed: day.compareTo(today) >= 0 ? null : () => setState(() => _picked = addDays(day, 1) == today ? null : addDays(day, 1))),
              ]),
              below: day == today && !coachOn
                  ? null
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (day != today)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(key: const Key('eat-back-to-today'), onPressed: () => setState(() => _picked = null), icon: const Icon(Icons.today, size: 18), label: const Text('Back to today')),
                        ),
                      if (coachOn)
                        TabCoach(key: const Key('eat-coach'), say: _say(context, ref, profile: profile, water: display.water),
                            avatarLabel: 'Help with your food journal, from ${guide.label}', onAvatarTap: () => _help(context)),
                    ]),
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
                  showCarbs: display.carbs, showFat: display.fat,
                  footer: [if (display.water) WaterRow(key: const Key('eat-water'), day: day), const NutritionTools(keyPrefix: 'eat')],
                  action: PrimaryButton('Log food', key: const Key('log-food'), icon: Icons.restaurant, expand: false, onPressed: () => openFoodForm(context, dayKey: day)),
                ),
                const SizedBox(height: 28),
                Heading(day == today ? 'Today\'s meals' : 'Meals', size: 20),
                const SizedBox(height: 12),
                // One quiet group per meal: the meal as its heading (outlined icon, name, what its foods add up to as a
                // quieter second line), each logged food as its own row, then a small "+ Add food" footer for this meal
                // and day. The footer is subordinate: no tile, regular weight, the accent colour. No photographs here.
                for (final meal in meals) ...[
                  () {
                    final mine = [for (final r in live) if (r.value.meal == meal) r];
                    final label = meal.toLowerCase();
                    return GroupCard(children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(indent, 14, 16, mine.isEmpty ? 2 : 10),
                        child: Row(children: [
                          if (roomy) ...[IconTile(_icons[meal] ?? Icons.restaurant, size: _tile), const SizedBox(width: 12)],
                          Expanded(
                            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
                              Semantics(header: true, child: Text(meal, style: context.sansStyle(18, weight: FontWeight.w700))),
                              if (mine.isNotEmpty) Text(_mealCalories([for (final r in mine) r.value]), style: context.numStyle(14.5, color: c.secondary, weight: FontWeight.w500)),
                            ]),
                          ),
                        ]),
                      ),
                      for (final r in mine) _EntryRow(r, indent: indent, detail: _detail(r), onTap: () => openFoodForm(context, dayKey: day, entry: r.value)),
                      _AddFood(key: Key('eat-add-$label'), meal: label, indent: indent, onTap: () => openFoodForm(context, dayKey: day, meal: meal)),
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

/// A meal's footer: "+ Add food", small and in the accent, below its foods. A full-width 48 px target; read out with
/// its meal ("Add food to lunch"). It opens Log food for this meal and the day shown; nothing is logged until saved.
class _AddFood extends StatelessWidget {
  const _AddFood({super.key, required this.meal, required this.indent, required this.onTap});
  final String meal;
  final double indent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.c.accent;
    return Semantics(
      button: true, label: 'Add food to $meal', excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Targets.minimum),
          child: Padding(
            padding: EdgeInsets.fromLTRB(indent - 2, 4, 12, 6),
            child: Row(children: [
              Icon(Icons.add, size: 18, color: accent),
              const SizedBox(width: 6),
              Flexible(child: Text('Add food', style: context.sansStyle(15, weight: FontWeight.w500, color: accent))),
            ]),
          ),
        ),
      ),
    );
  }
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
