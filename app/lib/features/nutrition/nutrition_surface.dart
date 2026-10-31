import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'nutrient_coverage.dart';
import 'nutrition_assessment.dart';

// Thousands are grouped for reading only ("1,400", "1 400"); stored and editable values are never reformatted.
String _grouped(num v) => formatGrouped(v);

/// Calories as people read them: whole kilocalories, grouped ("1,481"). Display only: totals, goals, comparisons and
/// what is stored keep their exact values; a remainder is worked out exactly and rounded when it is shown.
String formatKcal(num v) => _grouped(v.round());

String _amount(Nutrient n, num v) => n == Nutrient.calories ? formatKcal(v) : _grouped(v);

/// The day's overview on Eat, as a photo panel in the approved Today look: the NUTRITION label, calories in the
/// serif beside the bowl, [action] (Log food) under them, then goals, protein, carbs and fat full width below the
/// photograph. Today's [NutritionSummary] is given the same coverage and goals, so the two screens can never
/// disagree. Unknown nutrients show a dash, never a zero; partial sums are labelled. The bowl is decoration, there
/// on a day with nothing logged too; it is never one of the entries.
/// A goal is drawn only when the person set one; none is ever suggested. Calories and protein are the only goals
/// the app stores, so carbs and fat are known totals and nothing more: one calorie ring, one protein bar.
class NutritionSurface extends StatelessWidget {
  const NutritionSurface({super.key, required this.entries, required this.coverage, this.calorieGoal, this.proteinGoal, this.pending = false, this.action,
      this.showCarbs = true, this.showFat = true, this.footer = const []});
  final List<FoodEntry> entries;
  final Map<Nutrient, NutrientTotal> coverage;
  final int? calorieGoal, proteinGoal;
  final bool pending;

  /// The panel's one button (Eat's Log food), built by the caller from its own context.
  final Widget? action;

  /// Customize tracking: carbs and fat are shown unless the account hid them. Hiding changes nothing logged.
  final bool showCarbs, showFat;

  /// Under everything, full width: the water line and the goals / Customize tracking links.
  final List<Widget> footer;

  static const photo = 'assets/images/nutrition-cover.webp';

  /// Progress toward one goal, in words, from the shared assessment. What is left is stated only when every food has a
  /// value: a remainder worked out from a partial sum would be invented.
  String _detail(AppLocalizations l, NutrientAssessment a) {
    final n = a.nutrient, goal = a.goal!, kcal = a.isCalories;
    final amount = kcal ? l.eatGoalProgressCalories(_amount(n, a.known), _grouped(goal)) : l.eatGoalProgressProtein(_amount(n, a.known), _grouped(goal));
    if (!a.anyKnown) return kcal ? l.eatGoalNoCalorieValue(_grouped(goal)) : l.eatGoalNoProteinValue(_grouped(goal));
    if (a.over case final over?) return kcal ? l.eatGoalOverKcal(amount, _amount(n, over)) : l.eatGoalOverGrams(amount, _amount(n, over));
    if (a.reached) return '$amount · ${goalStatus(l, a)}';
    if (a.left case final left?) return kcal ? l.eatGoalLeftKcal(amount, _amount(n, left)) : l.eatGoalLeftGrams(amount, _amount(n, left));
    return l.eatGoalKnownSoFar(amount);
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

    // Beside the photograph, as on Today: the label, calories in the serif and protein, each against its goal when
    // one was set (the same NutritionSummary), then the button.
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
        if (goals != null) ...[const SizedBox(height: 8), Text(l.eatYourDailyGoal(goals), key: const Key('goal-summary'), style: context.caption)],
      ] else
        NutritionSummary(coverage: coverage, calorieGoal: calorieGoal, proteinGoal: proteinGoal, keyPrefix: 'eat'),
    ]);

    // Carbs and fat, when shown: known totals and nothing more (no goal is stored for them).
    final more = [if (showCarbs) (Nutrient.carbs, l.eatCarbs), if (showFat) (Nutrient.fat, l.eatFat)];
    String value(Nutrient n) => coverage[n]!.hasAnyKnown ? l.eatGramsValue(_grouped(coverage[n]!.knownTotal)) : '—';
    final a = DayAssessment.ofTotals(coverage, calorieGoal: calorieGoal, proteinGoal: proteinGoal, nothingLogged: entries.isEmpty);
    final details = [
      if (calorieGoal != null) _detail(l, a.calories),
      if (proteinGoal != null) _detail(l, a.protein),
    ];
    final below = <Widget>[
      // What is left or over, in words (Eat's own; Today keeps to the figures).
      if (entries.isNotEmpty)
        for (final d in details) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(d, style: context.numStyle(13.5, color: c.secondary, weight: FontWeight.w400))),
      if (entries.isNotEmpty && more.isNotEmpty)
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

/// Today's glance at the same day, for the Nutrition module: calories and protein, each against its goal when the
/// person set one ("1,480 / 2,200 kcal" over a thin bar). It reads the coverage Eat reads. An unknown value is a
/// dash, a partial sum is called "known", an over-goal bar stays full while the number is the real one. What is
/// left or over, carbs, fat and the explanations stay in Eat. Shown only when something was logged.
class NutritionSummary extends StatelessWidget {
  const NutritionSummary({super.key, required this.coverage, this.calorieGoal, this.proteinGoal, this.keyPrefix = 'today'});
  final Map<Nutrient, NutrientTotal> coverage;
  final int? calorieGoal, proteinGoal;

  /// Today's (`today-goal-calories`) and Eat's (`eat-goal-calories`) bars stay apart while both tabs are built.
  final String keyPrefix;

  /// "2,200 kcal · 140 g protein" for the goals that were set; null when none was.
  static String? goalsText(int? calorieGoal, int? proteinGoal) {
    final l = currentL10n;
    final goals = [if (calorieGoal != null) l.eatKcalValue(_grouped(calorieGoal)), if (proteinGoal != null) l.eatProteinGramsValue(_grouped(proteinGoal))];
    return goals.isEmpty ? null : goals.join(' · ');
  }

  /// [display]: the calorie figure in the serif with its unit ("513 kcal"), as Today's panel shows it, and the goal or
  /// "known" under it. Otherwise one line ("6.4 g protein").
  Widget _metric(BuildContext context, NutrientAssessment a, String label, String unit, {required bool display}) {
    final l = context.l10n;
    final n = a.nutrient, t = a.total, goal = a.goal;
    final known = t.hasAnyKnown, partial = known && !t.isComplete, kcal = n == Nutrient.calories;
    final value = known ? _amount(n, t.knownTotal) : '—';
    final quiet = context.sansStyle(display ? 14 : 17, color: context.c.secondary);
    final knownTag = partial ? ' · ${l.eatKnown}' : '';
    final status = goal == null || !known ? null : goalStatus(l, a);
    final percent = a.percent == null ? '' : formatPercent(a.percent! / 100);
    // The state in words beside the amount, in the state's readable colour, so colour is never the only signal.
    final statusText = status == null
        ? null
        : Text(status, key: Key('$keyPrefix-goal-${n.name}-status'), style: context.sansStyle(display ? 14 : 15, color: goalText(context.c, a.tone), weight: FontWeight.w600));
    return Semantics(
      label: [
        !known ? l.eatNutrientUnknownSaid(label) : kcal ? l.eatSaidKcal(label, value) : l.eatSaidGrams(label, value),
        if (partial) l.eatSaidKnownFrom(t.knownEntries, t.knownEntries + t.unknownEntries),
        if (goal != null) kcal ? l.eatSaidGoalKcal(_grouped(goal)) : l.eatSaidGoalGrams(_grouped(goal)),
        if (percent.isNotEmpty) percent,
        ?status,
      ].join(l.eatListSeparator),
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (display) ...[
            Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [Text(value, style: context.pageTitleStyle(44)), Text(unit, style: context.pageTitleStyle(44))]),
            if (goal != null || partial)
              Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [Text(goal == null ? l.eatKnownSoFar : '/ ${withUnit(_grouped(goal), unit)}$knownTag', style: quiet), ?statusText]),
          ] else
            Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 5, children: [
              Text(value, style: context.numStyle(17, color: context.c.text)),
              Text('${goal == null ? unit : '/ ${withUnit(_grouped(goal), unit)}'}$knownTag', style: quiet),
              ?statusText,
            ]),
          if (goal != null)
            Padding(
              key: Key('$keyPrefix-goal-${n.name}'), padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                // Filled up to the goal at most, in the state's colour; the real figures and share are in words.
                Expanded(child: ProgressRail(a.fill, label: kcal ? l.eatCaloriesGoalBar : l.eatProteinGoalBar, height: 6, color: goalFill(context.c, a.tone))),
                // The real share, also over 100 %; nothing for an unknown value.
                ConstrainedBox(constraints: const BoxConstraints(minWidth: 48), child: Text(percent, textAlign: TextAlign.end, style: context.numStyle(13, color: context.c.secondary, weight: FontWeight.w500))),
              ]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = DayAssessment.ofTotals(coverage, calorieGoal: calorieGoal, proteinGoal: proteinGoal);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      _metric(context, a.calories, context.l10n.eatCalories, context.l10n.eatUnitKcal, display: true),
      const SizedBox(height: 4),
      _metric(context, a.protein, context.l10n.eatProtein, context.l10n.eatUnitGramProtein, display: false),
    ]);
  }
}

/// The goal state in words, as the bars show it (docs/EAT_COMPANION.md › Goal colours). "Known intake" stays on any
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
      GoalTone.neutral => c.outline,
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
