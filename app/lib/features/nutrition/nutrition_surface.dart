import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'macro_composition.dart';
import 'nutrient_coverage.dart';
import 'nutrition_assessment.dart';

// Thousands are grouped for reading only ("1,400", "1 400"); stored and editable values are never reformatted.
String _grouped(num v) => formatGrouped(v);

/// Calories as people read them: whole kilocalories, grouped ("1,481"). Display only: totals, goals, comparisons and
/// what is stored keep their exact values; a remainder is worked out exactly and rounded when it is shown.
String formatKcal(num v) => _grouped(v.round());

String _amount(Nutrient n, num v) => n == Nutrient.calories ? formatKcal(v) : _grouped(v);

/// The day's overview on Eat (docs/FOOD_DATA.md › Compact top): the NUTRITION label with how complete the figures are,
/// the calorie and protein rings side by side, [action] (Log food, Saved meals & recipes), then the water line
/// ([footer]) and one row with **Nutrition details** (the recorded macro composition, the share of each goal and the
/// longer explanations, folded until asked for) and [settings] (Nutrition settings). Today's [NutritionSummary] is given
/// the same coverage and goals, so the two screens can never disagree. Unknown nutrients show a dash, never a zero;
/// partial sums say "Known totals" and "Known intake" where the figures are. No photograph: the figures get the width.
/// A goal is drawn only when the person set one (on an earlier day: only the goal recorded for that day); none is ever
/// suggested. Calories and protein are the only goals the app stores, so carbs and fat are composition, never progress.
/// Opening the details works nothing out again, logs nothing and asks nothing.
class NutritionSurface extends StatefulWidget {
  const NutritionSurface({super.key, required this.entries, required this.coverage, this.calorieGoal, this.proteinGoal, this.pending = false, this.action,
      this.showCarbs = true, this.showFat = true, this.pastDay = false, this.footer = const [], this.settings});
  final List<FoodEntry> entries;
  final Map<Nutrient, NutrientTotal> coverage;
  final int? calorieGoal, proteinGoal;
  final bool pending;

  /// The panel's actions (Eat's Log food and Saved meals & recipes), built by the caller from its own context.
  final Widget? action;

  /// Customize tracking: carbs and fat are shown unless the account hid them. Hiding changes nothing logged.
  final bool showCarbs, showFat;

  /// An earlier day: its goals are the ones recorded for it (or none), never today's.
  final bool pastDay;

  /// Under the actions, full width: the water line.
  final List<Widget> footer;

  /// Beside Nutrition details: Nutrition settings (and Set daily goals while there are none).
  final Widget? settings;

  /// Notes under the recorded composition: what its percentages are of, and why that can differ from the recorded
  /// calories (which stay as logged); or why there is no split.
  static List<String> macroNotes(AppLocalizations l, MacroComposition m, NutrientTotal calories) {
    if (!m.complete) return [l.nrMacroPartial];
    if (m.kcal <= 0) return [l.nrMacroZero];
    final recorded = calories.knownTotal, diff = (m.kcal - recorded).abs();
    return [
      l.nrMacroBasis(formatKcal(m.kcal)),
      if (calories.isComplete && diff >= 10 && diff >= recorded * 0.05) l.nrMacroDiffers(formatKcal(recorded)),
    ];
  }

  @override
  State<NutritionSurface> createState() => _NutritionSurfaceState();
}

class _NutritionSurfaceState extends State<NutritionSurface> {
  /// Nutrition details open: for this visit only, closed again when Eat is built afresh.
  bool _details = false;

  // Everything is built under the panel's theme: dark ink on the pale tint, the deep button, in Light and Dark.
  @override
  Widget build(BuildContext context) => PanelTheme(child: Builder(builder: _panel));

  Widget _panel(BuildContext context) {
    final w = widget, coverage = w.coverage;
    final c = context.c;
    final l = context.l10n;
    final complete = NutrientCoverage.allComplete(coverage);
    final unknownSomewhere = coverage.values.any((t) => t.unknownEntries > 0);
    // Food logged with no nutrition at all is not "known totals" of anything.
    final anyKnown = coverage.values.any((t) => t.hasAnyKnown);
    final heading = w.entries.isEmpty ? l.eatNoFoodLoggedYet : complete ? l.eatTotals : anyKnown ? l.eatKnownTotals : l.eatNoNutritionForFood;
    final goals = NutritionSummary.goalsText(w.calorieGoal, w.proteinGoal);

    final words = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // The label and how complete the figures are ("Known totals" when some food has no value), or that nothing is logged.
      Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Semantics(header: true, child: Overline(l.eatNutritionOverline)),
        Text(heading, key: const Key('eat-nutrition-heading'), style: context.sansStyle(13.5, color: c.secondary, weight: FontWeight.w600)),
      ]),
      if (w.entries.isEmpty) ...[
        const SizedBox(height: 6),
        Text(l.eatNothingRecorded, style: context.sansStyle(15, color: c.secondary)),
        if (goals != null && !w.pastDay) ...[const SizedBox(height: 4), Text(l.eatYourDailyGoal(goals), key: const Key('goal-summary'), style: context.caption)],
      ] else ...[
        const SizedBox(height: 10),
        NutritionSummary(coverage: coverage, calorieGoal: w.calorieGoal, proteinGoal: w.proteinGoal, keyPrefix: 'eat', prominent: true, pastDay: w.pastDay),
      ],
      if (w.pending) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.phone_iphone, l.eatSyncPending)),
    ]);

    // Nutrition details: carbs and fat are known totals and nothing more (no goal is stored for them). With both shown,
    // the recorded composition: protein, carbs and fat by the energy each contributes; then each goal's share and the
    // longer notes. Nothing to detail before anything is logged.
    final more = [if (w.showCarbs) (Nutrient.carbs, l.eatCarbs), if (w.showFat) (Nutrient.fat, l.eatFat)];
    String value(Nutrient n) => coverage[n]!.hasAnyKnown ? l.eatGramsValue(_grouped(coverage[n]!.knownTotal)) : '—';
    final macros = MacroComposition.recorded(coverage);
    final a = DayAssessment.ofTotals(coverage, calorieGoal: w.calorieGoal, proteinGoal: w.proteinGoal);
    final shares = [
      for (final (n, label) in [(a.calories, l.eatCalories), (a.protein, l.eatProtein)])
        if (n.percent != null) Text(l.eatGoalPercent(label, formatPercent(n.percent! / 100)), key: Key('eat-goal-${n.nutrient.name}-percent'), style: context.sansStyle(14.5, color: c.secondary)),
    ];
    final details = <Widget>[
      if (w.showCarbs && w.showFat)
        Padding(
          key: const Key('eat-macros'), padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: MacroDonut(macros, title: l.nrMacroRecordedTitle, keyPrefix: 'eat', amount: (_, g) => l.eatGramsValue(_grouped(g)),
              notes: NutritionSurface.macroNotes(l, macros, coverage[Nutrient.calories]!)),
        )
      else if (more.isNotEmpty)
        Padding(
          key: const Key('eat-more-nutrients'), padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Wrap(spacing: 28, runSpacing: 8, children: [
            for (final (n, label) in more)
              Semantics(
                label: coverage[n]!.hasAnyKnown ? l.eatNutrientSaid(label, value(n)) : l.eatNutrientUnknownSaid(label),
                child: ExcludeSemantics(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label, style: context.caption),
                  Text(value(n), style: context.titleStyle(19)),
                ])),
              ),
          ]),
        ),
      if (shares.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: shares)),
      if (unknownSomewhere) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l.eatPartialNote, style: context.caption)),
    ];
    final hasDetails = w.entries.isNotEmpty && details.isNotEmpty;
    final open = hasDetails && _details;
    final below = <Widget>[
      ...w.footer,
      // Nutrition details and Nutrition settings, one row while they fit, by words otherwise.
      Wrap(spacing: 4, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (hasDetails)
          // One node: the button and whether it is expanded.
          MergeSemantics(child: Semantics(
            expanded: open,
            // The chevron after the words, as a section's disclosure.
            child: TextButton(
              key: const Key('eat-details'),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: () => setState(() => _details = !open),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(l.eatNutritionDetails)), const SizedBox(width: 4), Icon(open ? Icons.expand_less : Icons.expand_more, size: 20)]),
            ),
          )),
        ?w.settings,
      ]),
      if (open) Padding(key: const Key('eat-details-body'), padding: const EdgeInsets.only(top: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: details)),
    ];
    return PanelSurface(
      below: below,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        words,
        if (w.action != null) ...[const SizedBox(height: 14), w.action!],
      ]),
    );
  }
}

/// Calories and protein, each as a ring against its goal, from the shared assessment and the coverage Eat reads:
/// Today's compact glance, and Eat's summary when [prominent] (the ring beside the nutrient's name, the amounts in the
/// serif, then the goal and one line: what is left, or the state in words; the percentage is in Nutrition details). Shown only when something was logged; nothing logged is said in words.
///
/// The layout follows the room it is given and the text size, never the device: side by side, each ring above its
/// figures (Eat: beside its name, the figures under both), when two columns of at least [minColumn] ([minProminentColumn]
/// on Eat) text-scaled pixels fit (at normal text: 360–430 px phones); otherwise one above the other, each ring beside
/// (or, with little room, above) its figures. Text is never shrunk to make either fit; it wraps.
class NutritionSummary extends StatelessWidget {
  const NutritionSummary({super.key, required this.coverage, this.calorieGoal, this.proteinGoal, this.keyPrefix = 'today', this.prominent = false, this.pastDay = false});
  final Map<Nutrient, NutrientTotal> coverage;
  final int? calorieGoal, proteinGoal;

  /// Today's (`today-goal-calories`) and Eat's (`eat-goal-calories`) rings stay apart while both tabs are built.
  final String keyPrefix;
  final bool prominent, pastDay;

  /// The narrowest a side-by-side column may be at normal text, before the text scale: Today's, and Eat's (its ring
  /// beside the name, then the amount in the serif).
  static const minColumn = 92.0, minProminentColumn = 124.0;

  /// "2,200 kcal · 140 g protein" for the goals that were set; null when none was.
  static String? goalsText(int? calorieGoal, int? proteinGoal) {
    final l = currentL10n;
    final goals = [if (calorieGoal != null) l.eatKcalValue(_grouped(calorieGoal)), if (proteinGoal != null) l.eatProteinGramsValue(_grouped(proteinGoal))];
    return goals.isEmpty ? null : goals.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final a = DayAssessment.ofTotals(coverage, calorieGoal: calorieGoal, proteinGoal: proteinGoal);
    const gap = 14.0;
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 2 * MediaQuery.textScalerOf(context).scale(prominent ? minProminentColumn : minColumn) + gap) {
        // Side by side: both rings one size, so the figures start level (Today and Eat alike).
        const ring = 48.0;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: GoalRing(a.calories, keyPrefix: keyPrefix, size: ring, column: ring, prominent: prominent, pastDay: pastDay)),
          const SizedBox(width: gap),
          Expanded(child: GoalRing(a.protein, keyPrefix: keyPrefix, size: ring, column: ring, prominent: prominent, pastDay: pastDay)),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        GoalRing(a.calories, keyPrefix: keyPrefix, size: 56, prominent: prominent, pastDay: pastDay),
        const SizedBox(height: 10),
        GoalRing(a.protein, keyPrefix: keyPrefix, size: 56, prominent: prominent, pastDay: pastDay),
      ]);
    });
  }
}

/// One goal as a ring with its figures beside it: the name, the recorded amount and unit, the goal and percentage,
/// then the state in words in its colour (and, when [prominent], the exact amount left). Presentation only: it is given
/// the shared [NutrientAssessment] and works nothing out, fetches nothing and changes nothing.
///
/// * The arc fills to the goal at most; above it the ring is full and the real percentage and excess are in words.
/// * No goal: a neutral disc with the nutrient's icon instead of a ring, the amount, and "No goal" (on an earlier day,
///   "No goal recorded for this day"); never a percentage.
/// * Unknown values: a dash for the amount, "No value entered yet"; a partial sum keeps "Known intake" in its state.
/// * Read out once, as one description; the drawing and the separate figures are not announced again.
/// * In a [column] (side by side with the other goal) the ring sits above its figures, at the bottom of a box
///   [column] high, so rings of two sizes keep their figures level. Otherwise, with large text or little room, the
///   ring goes above its figures. Text is never shrunk to fit.
class GoalRing extends StatelessWidget {
  const GoalRing(this.a, {super.key, required this.keyPrefix, this.size = 56, this.column, this.prominent = false, this.pastDay = false});
  final NutrientAssessment a;
  final String keyPrefix;
  final double size;

  /// Set when side by side: the height of the box the ring sits at the bottom of, above the figures.
  final double? column;
  final bool prominent, pastDay;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.c;
    final n = a.nutrient, t = a.total, goal = a.goal, kcal = a.isCalories;
    final known = t.hasAnyKnown, partial = known && !t.isComplete;
    final label = kcal ? l.eatCalories : l.eatProtein, unit = kcal ? l.eatUnitKcal : l.eatUnitGram;
    final value = known ? _amount(n, t.knownTotal) : '—';
    final percent = a.percent == null ? null : formatPercent(a.percent! / 100);
    final noGoal = pastDay ? l.nrNoGoalThatDay : l.eatGoalNone;
    // Without a goal a partial sum still says it is one ("No goal · Known intake").
    final status = goal == null ? (partial ? '$noGoal · ${l.goalKnownIntake}' : noGoal) : !known ? l.nrNoValue : goalStatus(l, a);
    final left = a.left;
    final quiet = context.sansStyle(prominent ? 14.5 : 14, color: c.secondary);
    // The real share, also above 100 %, beside the goal; nothing without a goal or a known value.
    // "· 44 %" wraps as one piece, never leaving the dot at the end of a line.
    final percentText = percent == null
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: [Text('· ', style: quiet), Text(percent, key: Key('$keyPrefix-goal-${n.name}-percent'), style: quiet)]);
    final statusText = Text(status,
        key: goal == null ? null : Key('$keyPrefix-goal-${n.name}-status'),
        style: context.sansStyle(prominent ? 14.5 : 14, color: goal == null || !known ? c.secondary : goalText(c, a.tone), weight: goal == null ? FontWeight.w400 : FontWeight.w600));

    final name = Text(label, style: context.sansStyle(13.5, color: c.secondary, weight: FontWeight.w600));
    final figures = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // On Eat, side by side, the name is beside the ring instead.
      if (!(prominent && column != null)) name,
      if (prominent) ...[
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
          Text(value, style: context.pageTitleStyle(kcal ? 32 : 24)),
          if (known) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(unit, style: context.sansStyle(15, color: c.secondary))),
        ]),
        if (goal != null) Text(l.nrOfGoal(withUnit(_grouped(goal), unit)), style: quiet),
        // One line: what is left, in the state's colour, whenever it is exact; otherwise the state in words (reached,
        // over by, "Known intake", no goal). Both are read out in full above.
        if (left != null)
          Text(l.nrLeft(withUnit(_amount(n, left), unit)), key: Key('$keyPrefix-goal-${n.name}-left'), style: context.sansStyle(14.5, color: goalText(c, a.tone), weight: FontWeight.w600))
        else
          statusText,
      ] else ...[
        // "1,480 / 2,200 kcal · 67 %" in one line where it fits.
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 5, children: [
          Text(value, style: context.numStyle(18, color: c.text)),
          if (goal != null) Text('/ ${withUnit(_grouped(goal), unit)}', style: quiet) else if (known) Text(unit, style: quiet),
          ?percentText,
        ]),
        statusText,
      ],
    ]);

    // The ring (or, without a goal, a neutral disc): the nutrient's icon in the middle, never a number squeezed in.
    Widget ring(double d) {
      final icon = Icon(kcal ? Icons.local_fire_department_outlined : Icons.set_meal_outlined, size: d * 0.36, color: c.secondary);
      return goal == null
          ? Container(width: d, height: d, decoration: BoxDecoration(color: c.sunken, shape: BoxShape.circle), alignment: Alignment.center, child: icon)
          : ProgressRing(key: Key('$keyPrefix-goal-${n.name}'), value: a.fill, label: label, size: d, stroke: (d / 10).clamp(5, 9).toDouble(), color: goalFill(c, a.tone), center: icon);
    }

    return Semantics(
      container: true,
      label: [
        !known ? l.eatNutrientUnknownSaid(label) : kcal ? l.eatSaidKcal(label, value) : l.eatSaidGrams(label, value),
        if (partial) l.eatSaidKnownFrom(t.knownEntries, t.knownEntries + t.unknownEntries),
        if (goal != null) kcal ? l.eatSaidGoalKcal(_grouped(goal)) : l.eatSaidGoalGrams(_grouped(goal)),
        ?percent,
        status,
        if (left != null) kcal ? l.nrSaidLeftKcal(_amount(n, left)) : l.nrSaidLeftGrams(_amount(n, left)),
      ].join(l.eatListSeparator),
      child: ExcludeSemantics(
        child: column != null && prominent
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [ring(size), const SizedBox(width: 10), Expanded(child: name)]),
                const SizedBox(height: 6),
                figures,
              ])
            : column != null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                SizedBox(height: column, child: Align(alignment: AlignmentDirectional.bottomStart, child: ring(size))),
                const SizedBox(height: 8),
                figures,
              ])
            : LayoutBuilder(builder: (context, box) {
          // Beside its figures when they keep at least ~100 text-scaled pixels (the ring gives up some size first);
          // otherwise above them.
          final room = box.maxWidth - 12 - MediaQuery.textScalerOf(context).scale(100);
          if (room < 48) return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [ring(size), const SizedBox(height: 8), figures]);
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [ring(math.min(size, room)), const SizedBox(width: 12), Expanded(child: figures)]);
        }),
      ),
    );
  }
}

/// The goal state in words, as the rings show it (docs/EAT_COMPANION.md › Goal colours). "Known intake" stays on any
/// state worked out from a total with unknown values.
String goalStatus(AppLocalizations l, NutrientAssessment a) {
  final kcal = a.isCalories;
  final said = switch (a.state) {
    GoalState.noGoal => '',
    GoalState.incomplete => l.goalKnownIntake,
    GoalState.below => kcal ? l.goalRoomRemaining : l.goalBelowTarget,
    GoalState.near => kcal ? l.goalApproaching : l.goalNearlyThere,
    GoalState.reached => kcal ? l.goalTargetReached : l.goalReached,
    GoalState.over => kcal ? l.goalOverKcal(formatKcal(a.over!)) : l.goalAboveGrams(_grouped(a.over!)),
  };
  return !a.complete && a.state != GoalState.incomplete ? '$said · ${l.goalKnownIntake}' : said;
}

Color goalFill(GoColors c, GoalTone t) => switch (t) {
      GoalTone.neutral => c.secondary,
      GoalTone.green => c.goalGreen,
      GoalTone.yellow => c.goalYellow,
      GoalTone.red => c.goalRed,
    };

Color goalText(GoColors c, GoalTone t) => switch (t) {
      GoalTone.neutral => c.secondary,
      GoalTone.green => c.goalGreenText,
      GoalTone.yellow => c.goalYellowText,
      GoalTone.red => c.goalRedText,
    };

/// One line under Today's nutrition values when any food has no value for any nutrient. It says so and leads to
/// Eat, where the journal explains which. Nothing is drawn when every value is known.
class NutritionMissingNote extends StatelessWidget {
  const NutritionMissingNote({super.key, required this.coverage, required this.onDetails});
  final Map<Nutrient, NutrientTotal> coverage;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => !coverage.values.any((t) => t.unknownEntries > 0)
      ? const SizedBox.shrink()
      : Semantics(
          button: true, hint: context.l10n.eatOpensJournalHint,
          child: InkWell(
            key: const Key('today-nutrition-missing'),
            borderRadius: BorderRadius.circular(Radii.field),
            onTap: onDetails,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Targets.minimum),
              child: Row(children: [
                Expanded(child: StatusLine(Icons.info_outline, coverage.values.any((t) => t.hasAnyKnown) ? context.l10n.eatSomeValuesMissing : context.l10n.eatNoValuesYet)),
                Icon(Icons.chevron_right, size: 22, color: context.c.secondary),
              ]),
            ),
          ),
        );
}
