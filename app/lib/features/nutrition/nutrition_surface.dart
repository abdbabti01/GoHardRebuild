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

/// The day's overview on Eat, as a photo panel in the approved Today look: the NUTRITION label, then the calorie and
/// protein rings beside the bowl, [action] (Log food) under them, then the recorded macro composition, water and the
/// goals / Customize tracking links full width below the photograph. Today's [NutritionSummary] is given the same
/// coverage and goals, so the two screens can never disagree. Unknown nutrients show a dash, never a zero; partial sums
/// are labelled. The bowl is decoration, there on a day with nothing logged too; it is never one of the entries.
/// A goal is drawn only when the person set one (on an earlier day: only the goal recorded for that day); none is ever
/// suggested. Calories and protein are the only goals the app stores, so carbs and fat are composition, never progress.
class NutritionSurface extends StatelessWidget {
  const NutritionSurface({super.key, required this.entries, required this.coverage, this.calorieGoal, this.proteinGoal, this.pending = false, this.action,
      this.showCarbs = true, this.showFat = true, this.pastDay = false, this.footer = const []});
  final List<FoodEntry> entries;
  final Map<Nutrient, NutrientTotal> coverage;
  final int? calorieGoal, proteinGoal;
  final bool pending;

  /// The panel's one button (Eat's Log food), built by the caller from its own context.
  final Widget? action;

  /// Customize tracking: carbs and fat are shown unless the account hid them. Hiding changes nothing logged.
  final bool showCarbs, showFat;

  /// An earlier day: its goals are the ones recorded for it (or none), never today's.
  final bool pastDay;

  /// Under everything, full width: the water line and the goals / Customize tracking links.
  final List<Widget> footer;

  static const photo = 'assets/images/nutrition-cover.webp';

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

  // Everything is built under the panel's theme: dark ink on the pale tint, the deep button, in Light and Dark.
  @override
  Widget build(BuildContext context) => PanelTheme(child: Builder(builder: _panel));

  Widget _panel(BuildContext context) {
    final c = context.c;
    final l = context.l10n;
    final complete = NutrientCoverage.allComplete(coverage);
    final unknownSomewhere = coverage.values.any((t) => t.unknownEntries > 0);
    // Food logged with no nutrition at all is not "known totals" of anything.
    final anyKnown = coverage.values.any((t) => t.hasAnyKnown);
    final heading = entries.isEmpty ? l.eatNoFoodLoggedYet : complete ? l.eatTotals : anyKnown ? l.eatKnownTotals : l.eatNoNutritionForFood;
    final goals = NutritionSummary.goalsText(calorieGoal, proteinGoal);
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;

    // Beside the photograph: the label, then calories and protein as rings against their goals (the same
    // NutritionSummary as Today, larger), then the button.
    final words = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Semantics(header: true, child: Overline(l.eatNutritionOverline)),
        // "Known totals" when some food has no value: the figures are sums of what was entered.
        if (entries.isNotEmpty) Text(heading, style: context.sansStyle(13.5, color: c.secondary, weight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      if (entries.isEmpty) ...[
        Semantics(header: true, child: Text(heading, style: context.pageTitleStyle(30))),
        const SizedBox(height: 6),
        Text(l.eatNothingRecorded, style: context.sansStyle(15, color: c.secondary)),
        if (goals != null && !pastDay) ...[const SizedBox(height: 8), Text(l.eatYourDailyGoal(goals), key: const Key('goal-summary'), style: context.caption)],
      ] else ...[
        const SizedBox(height: 6),
        NutritionSummary(coverage: coverage, calorieGoal: calorieGoal, proteinGoal: proteinGoal, keyPrefix: 'eat', prominent: true, pastDay: pastDay),
      ],
    ]);

    // Carbs and fat are known totals and nothing more (no goal is stored for them). With both shown, the recorded
    // composition replaces the row of figures: protein, carbs and fat by the energy each contributes.
    final more = [if (showCarbs) (Nutrient.carbs, l.eatCarbs), if (showFat) (Nutrient.fat, l.eatFat)];
    String value(Nutrient n) => coverage[n]!.hasAnyKnown ? l.eatGramsValue(_grouped(coverage[n]!.knownTotal)) : '—';
    final macros = MacroComposition.recorded(coverage);
    final below = <Widget>[
      if (entries.isNotEmpty && showCarbs && showFat)
        Padding(
          key: const Key('eat-macros'), padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: MacroDonut(macros, title: l.nrMacroRecordedTitle, keyPrefix: 'eat', amount: (_, g) => l.eatGramsValue(_grouped(g)),
              notes: macroNotes(l, macros, coverage[Nutrient.calories]!)),
        )
      else if (entries.isNotEmpty && more.isNotEmpty)
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
      if (entries.isNotEmpty && unknownSomewhere)
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l.eatPartialNote, style: context.caption)),
      if (pending) Padding(padding: const EdgeInsets.only(bottom: 6), child: StatusLine(Icons.phone_iphone, l.eatSyncPending)),
      ...footer,
    ];
    // With large text the photograph gives its room to the words.
    final pictured = !large;
    return PanelSurface(
      photo: pictured ? const PanelPhoto(photo, key: Key('eat-photo-nutrition'), alignment: Alignment(0.7, 0)) : null,
      below: below,
      child: LayoutBuilder(
        builder: (context, box) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(constraints: BoxConstraints(maxWidth: pictured ? box.maxWidth * PanelSurface.wordsShare : box.maxWidth), child: words),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      ),
    );
  }
}

/// Calories and protein, each as a ring against its goal, from the shared assessment and the coverage Eat reads:
/// Today's compact glance, and Eat's summary when [prominent] (a larger calorie ring, the amounts in the serif, the
/// exact amount left on its own line). Side by side when there is room for both, otherwise one above the other.
/// Shown only when something was logged; nothing logged is said in words, never as a zero.
class NutritionSummary extends StatelessWidget {
  const NutritionSummary({super.key, required this.coverage, this.calorieGoal, this.proteinGoal, this.keyPrefix = 'today', this.prominent = false, this.pastDay = false});
  final Map<Nutrient, NutrientTotal> coverage;
  final int? calorieGoal, proteinGoal;

  /// Today's (`today-goal-calories`) and Eat's (`eat-goal-calories`) rings stay apart while both tabs are built.
  final String keyPrefix;
  final bool prominent, pastDay;

  /// "2,200 kcal · 140 g protein" for the goals that were set; null when none was.
  static String? goalsText(int? calorieGoal, int? proteinGoal) {
    final l = currentL10n;
    final goals = [if (calorieGoal != null) l.eatKcalValue(_grouped(calorieGoal)), if (proteinGoal != null) l.eatProteinGramsValue(_grouped(proteinGoal))];
    return goals.isEmpty ? null : goals.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final a = DayAssessment.ofTotals(coverage, calorieGoal: calorieGoal, proteinGoal: proteinGoal);
    final calories = GoalRing(a.calories, keyPrefix: keyPrefix, size: prominent ? 84 : 56, prominent: prominent, pastDay: pastDay);
    final protein = GoalRing(a.protein, keyPrefix: keyPrefix, size: prominent ? 64 : 56, prominent: prominent, pastDay: pastDay);
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= MediaQuery.textScalerOf(context).scale(prominent ? 420 : 360)
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: calories), const SizedBox(width: 16), Expanded(child: protein)])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [calories, SizedBox(height: prominent ? 14 : 10), protein]),
    );
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
/// * With large text or little room the ring goes above its figures; text is never shrunk to fit.
class GoalRing extends StatelessWidget {
  const GoalRing(this.a, {super.key, required this.keyPrefix, this.size = 56, this.prominent = false, this.pastDay = false});
  final NutrientAssessment a;
  final String keyPrefix;
  final double size;
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

    final figures = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: context.sansStyle(13.5, color: c.secondary, weight: FontWeight.w600)),
      if (prominent) ...[
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
          Text(value, style: context.pageTitleStyle(kcal ? 32 : 24)),
          if (known) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(unit, style: context.sansStyle(15, color: c.secondary))),
        ]),
        if (goal != null) Wrap(spacing: 5, children: [Text(l.nrOfGoal(withUnit(_grouped(goal), unit)), style: quiet), ?percentText]),
        statusText,
        if (left != null) Text(l.nrLeft(withUnit(_amount(n, left), unit)), key: Key('$keyPrefix-goal-${n.name}-left'), style: quiet),
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
        child: LayoutBuilder(builder: (context, box) {
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
