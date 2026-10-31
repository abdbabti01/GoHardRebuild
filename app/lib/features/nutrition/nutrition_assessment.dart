import '../../data/models.dart';
import 'nutrient_coverage.dart';

/// The one reading of a day's calories and protein against the person's own goals (docs/EAT_COMPANION.md › Shared
/// assessment). Eat's briefing, What could I eat?, the ranking of options, the goal bars on Today and Eat and the weekly
/// report all read this; none of them compares a total with a goal on its own. Pure and deterministic: no AI, no clock.
///
/// * Each nutrient is judged on its own: an unknown calorie value never makes known protein unknown.
/// * Unknown is not zero. A total with any unknown value is "known intake": it can establish that a goal was reached
///   (the known part only grows), never an exact amount left.
/// * A day with nothing logged is judged against what was logged (nothing), never as a claim about what was eaten.
/// * Display resolution: an amount is compared with its goal as it is shown, whole kcal and tenths of a gram, so a label
///   never contradicts the figures beside it ("2,300 / 2,300 kcal" is reached, never "0 kcal left" or "over").
///   The 80 % line is judged on the exact value. A shown percentage is the exact share rounded down below the goal, 100 %
///   when reached and rounded up above it, so "80 %" never sits beside "below 80 %" and "100 %" never beside "over".
enum GoalState {
  /// No goal set for this nutrient: neutral, no percentage.
  noGoal,

  /// Some values are unknown and the known part is below the goal: nothing can be said about what is left.
  incomplete,

  /// Below 80 % of the goal.
  below,

  /// From 80 % up to (not including) the goal.
  near,

  /// At the goal at display resolution.
  reached,

  /// Above the goal at display resolution.
  over,
}

/// How a goal bar is coloured. Progress against a goal the person chose: never food quality, health or merit.
enum GoalTone { neutral, green, yellow, red }

class NutrientAssessment {
  NutrientAssessment(this.nutrient, this.total, this.goal, {required this.nothingLogged});
  final Nutrient nutrient;
  final NutrientTotal total;
  final int? goal;

  /// Nothing logged that day: the known total is zero and complete against what was logged.
  final bool nothingLogged;

  bool get isCalories => nutrient == Nutrient.calories;
  bool get hasGoal => goal != null;

  /// Every logged value is known (or nothing was logged).
  bool get complete => nothingLogged || total.isComplete;
  bool get anyKnown => nothingLogged || total.hasAnyKnown;
  double get known => total.knownTotal;

  /// The known total at display resolution: whole kcal, tenths of a gram.
  double get shown => isCalories ? known.roundToDouble() : (known * 10).round() / 10;

  GoalState get state {
    final g = goal;
    if (g == null) return GoalState.noGoal;
    if (shown > g) return GoalState.over;
    if (shown == g) return GoalState.reached; // both exact at display resolution (whole numbers or tenths compared with a whole goal)
    if (!complete) return GoalState.incomplete;
    // 80 % on the exact value, in integers where possible: known × 5 ≥ goal × 4.
    return known * 5 >= g * 4 ? GoalState.near : GoalState.below;
  }

  bool get reached => state == GoalState.reached || state == GoalState.over;

  /// What is left, exact, only when it can be known: a goal, every value known, and below it.
  double? get left => complete && (state == GoalState.below || state == GoalState.near) ? goal! - known : null;

  /// By how much the known total is above the goal (also with unknown values: the known part only grows).
  double? get over => state == GoalState.over ? shown - goal! : null;

  /// The percentage to show, following the display policy above; null without a goal or with nothing known.
  int? get percent {
    final g = goal;
    if (g == null || !anyKnown) return null;
    return switch (state) {
      GoalState.reached => 100,
      GoalState.over => (shown * 100 / g).ceil().clamp(101, 1 << 30),
      // Below the goal on the exact value, rounded down: 79.98 % shows as 79 %, matching "below 80 %".
      _ => (known * 100 / g).floor().clamp(0, 99),
    };
  }

  /// The share of the bar to fill, capped at the goal.
  double get fill => goal == null || !anyKnown ? 0 : (known / goal!).clamp(0.0, 1.0);

  GoalTone get tone => switch (state) {
        GoalState.noGoal || GoalState.incomplete => GoalTone.neutral,
        GoalState.below => isCalories ? GoalTone.green : GoalTone.yellow,
        GoalState.near => GoalTone.yellow,
        GoalState.reached => GoalTone.green,
        // Protein above its goal is still the goal reached; only calories above the chosen target turn red.
        GoalState.over => isCalories ? GoalTone.red : GoalTone.green,
      };
}

/// What the day's food is overall, for the coach: which of the cases in docs/EAT_COMPANION.md › What could I eat? applies.
enum DaySituation { noGoals, remaining, caloriesReachedProteinLeft, proteinReachedCaloriesLeft, bothReached, uncertain }

class DayAssessment {
  DayAssessment._(this.calories, this.protein);

  factory DayAssessment.of(List<FoodEntry> entries, {int? calorieGoal, int? proteinGoal}) {
    final t = NutrientCoverage.calculate(entries);
    return DayAssessment.ofTotals(t, calorieGoal: calorieGoal, proteinGoal: proteinGoal, nothingLogged: entries.isEmpty);
  }

  factory DayAssessment.ofTotals(Map<Nutrient, NutrientTotal> t, {int? calorieGoal, int? proteinGoal, bool nothingLogged = false}) => DayAssessment._(
        NutrientAssessment(Nutrient.calories, t[Nutrient.calories]!, calorieGoal, nothingLogged: nothingLogged),
        NutrientAssessment(Nutrient.protein, t[Nutrient.protein]!, proteinGoal, nothingLogged: nothingLogged),
      );

  final NutrientAssessment calories, protein;

  bool get noGoals => !calories.hasGoal && !protein.hasGoal;

  /// Each goal that is set has been reached (at least one is set).
  bool get allReached => !noGoals && (!calories.hasGoal || calories.reached) && (!protein.hasGoal || protein.reached);

  DaySituation get situation {
    if (noGoals) return DaySituation.noGoals;
    if (allReached) return DaySituation.bothReached;
    final c = calories, p = protein;
    // One goal reached and the other not: the trade-off is said whether or not the other's remainder is exact.
    if (c.hasGoal && c.reached && p.hasGoal && !p.reached) return DaySituation.caloriesReachedProteinLeft;
    if (p.hasGoal && p.reached && c.hasGoal && !c.reached) return DaySituation.proteinReachedCaloriesLeft;
    // Some goal is not reached: what is left is known only when every value it needs is known.
    if ((c.hasGoal && !c.reached && !c.complete) || (p.hasGoal && !p.reached && !p.complete)) return DaySituation.uncertain;
    return DaySituation.remaining;
  }

  /// A fingerprint of everything the assessment depends on, so words worked out from it change when (and only when)
  /// one of those facts changes.
  String get facts => [for (final a in [calories, protein]) '${a.goal}:${a.known}:${a.complete}:${a.anyKnown}'].join('|');
}
