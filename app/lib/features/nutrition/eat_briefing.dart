import '../../core/language.dart';
import '../../core/units.dart' show formatNumber2;
import '../../data/models.dart';
import 'food_repository.dart' show mealLabel;
import 'nutrition_assessment.dart';
import 'nutrition_surface.dart' show formatKcal;

/// Eat's briefing (docs/EAT_COMPANION.md › Briefing): the one thing Leon or Leona says on Eat, chosen on the phone from
/// the day shown, its recorded food, the goals that applied, and the time. Pure: no network, no AI, nothing written.
/// Every goal state comes from the shared assessment ([DayAssessment]), the same one the bars and the coach read.
///
/// * Calories and protein are judged separately: an unknown calorie value never makes a known protein total unknown,
///   and an incomplete calorie total never gives an exact allowance ("at least … recorded" instead).
/// * "Left" is against what is recorded, never a claim about everything eaten. Nothing is inferred from a meal not
///   logged, and nothing is projected from the time of day except one thing: "near the target" is only said while
///   there is time left in the day ([BriefRules.dayLeftBefore]).
/// * Once every goal is reached, the briefing says so and stops offering food; it never decides the person is done.
/// * An earlier day is described looking back, against the goals recorded for that day only (never today's goals);
///   it never gets a live heads-up or "eat this now".
abstract final class BriefRules {
  /// Near the calorie target: what is left is at most this many kcal, or [nearShare] of the target if that is more,
  /// and the bar is in its "approaching" state (80 % or more), so the heads-up never contradicts the bar…
  static const nearKcal = 150, nearShare = 0.10;

  /// …and it is before this local time (minutes after midnight): 17:00.
  static const dayLeftBefore = 17 * 60;

  /// Protein still to go is mentioned from this many grams.
  static const proteinLeftFrom = 5;
}

/// The in-app heads-ups. Each is said at most once a day per account (its id is `day|kind`), and only while heads-ups
/// are on; afterwards the same state is described plainly.
enum HeadsUp { over, near, protein }

enum BriefKind { pastEmpty, past, empty, headsUp, reached, unknownKcal, left, logged }

class Briefing {
  const Briefing(this.kind, this.a, {this.headsUp, this.meal});
  final BriefKind kind;
  final DayAssessment a;
  final HeadsUp? headsUp;

  /// The meal this is about: the one logged last ([BriefKind.logged]) or the next one ([BriefKind.empty]).
  final String? meal;

  /// Recorded totals (what is known) and the goals that applied.
  double? get kcal => a.calories.anyKnown ? a.calories.known : null;
  double? get protein => a.protein.anyKnown ? a.protein.known : null;
  int? get kcalGoal => a.calories.goal;
  int? get proteinGoal => a.protein.goal;
  bool get kcalComplete => a.calories.complete;
  bool get proteinComplete => a.protein.complete;

  /// No calorie or protein goal is set: the briefing offers ideas and, quietly, the goal editor.
  bool get noGoals => a.noGoals;

  /// Every goal set has been reached: the action becomes "Find something to eat" (still there, never pushed).
  bool get allReached => a.allReached;

  /// `day|kind` of the heads-up, for "said once".
  String? seenKey(String day) => headsUp == null ? null : '$day|${headsUp!.name}';
}

/// The briefing for [day]. [seen]: heads-ups already said (`day|kind`); [headsUps]: the person's setting.
/// [nextMeal]: the meal coming up (a meal reminder's time when the person set one, else the time of day).
/// For an earlier day, [kcalGoal] and [proteinGoal] must be the goals recorded for that day (null when unknown).
Briefing eatBriefing({required String day, required String today, required List<FoodEntry> entries, int? kcalGoal, int? proteinGoal, required int nowMinute,
    required String nextMeal, bool headsUps = true, Set<String> seen = const {}}) {
  final a = DayAssessment.of(entries, calorieGoal: kcalGoal, proteinGoal: proteinGoal);
  Briefing b(BriefKind k, {HeadsUp? h, String? meal}) => Briefing(k, a, headsUp: h, meal: meal);
  final kcal = a.calories, protein = a.protein;

  if (day != today) return entries.isEmpty ? b(BriefKind.pastEmpty) : b(BriefKind.past);
  if (entries.isEmpty) return b(BriefKind.empty, meal: nextMeal);

  bool may(HeadsUp h) => headsUps && !seen.contains('$day|${h.name}');
  if (kcal.state == GoalState.over && kcal.complete && may(HeadsUp.over)) return b(BriefKind.headsUp, h: HeadsUp.over);
  if (kcal.left case final left? when kcal.state == GoalState.near) {
    final near = left <= (kcal.goal! * BriefRules.nearShare).clamp(BriefRules.nearKcal, double.infinity);
    if (near && nowMinute < BriefRules.dayLeftBefore && may(HeadsUp.near)) return b(BriefKind.headsUp, h: HeadsUp.near);
  }
  // Every goal reached: said plainly, without offering more food (the protein heads-up would ask "Want ideas?").
  if (a.allReached) return b(BriefKind.reached);
  // A known protein total only grows as more values become known: reaching the goal is true even if some are unknown.
  if (protein.reached && may(HeadsUp.protein)) return b(BriefKind.headsUp, h: HeadsUp.protein);
  if (kcal.hasGoal && !kcal.complete && !kcal.reached) return b(BriefKind.unknownKcal);
  if (!a.noGoals) return b(BriefKind.left);
  final last = meals.lastWhere((m) => entries.any((e) => e.meal == m));
  return b(BriefKind.logged, meal: last);
}

String _g(num v) => formatNumber2((v * 10).round() / 10);

/// What the briefing says, in [l]'s language. One or two short sentences; a question at the end is what its action
/// does, and there is none once every goal is reached or the calorie target is.
String briefingText(AppLocalizations l, Briefing b, {required String dayLabel}) {
  final kcal = b.kcal ?? 0, protein = b.protein ?? 0;
  final c = b.a.calories, p = b.a.protein;
  String meal(String m) => mealLabel(l, m).toLowerCase();
  switch (b.kind) {
    case BriefKind.pastEmpty:
      return l.ebPastEmpty(dayLabel);
    case BriefKind.past:
      final parts = [
        !b.kcalComplete ? l.ebAtLeastKcal(formatKcal(kcal)) : l.eatKcalValue(formatKcal(kcal)),
        if (b.protein != null) !b.proteinComplete ? l.ebAtLeastProtein(_g(protein)) : l.eatProteinGramsValue(_g(protein)),
      ];
      // Only against a goal recorded for that day; none recorded, nothing compared.
      final goal = c.over != null
          ? l.ebPastOver(formatKcal(c.over!))
          : c.state == GoalState.reached
              ? l.ebPastAtTarget
              : c.left != null
                  ? l.ebPastUnder(formatKcal(c.left!))
                  : null;
      return [l.ebPast(dayLabel, parts.join(l.dcAnd)), ?goal].join(' ');
    case BriefKind.empty:
      return l.ebEmpty(meal(b.meal!));
    case BriefKind.headsUp:
      return switch (b.headsUp!) {
        HeadsUp.over => l.ebOver(formatKcal(c.over!)),
        HeadsUp.near => l.ebNear(formatKcal(c.left!)),
        HeadsUp.protein => l.ebProteinReached(_g(protein), '${b.proteinGoal}'),
      };
    case BriefKind.reached:
      final over = c.over == null ? null : l.ebOverPlain(formatKcal(c.over!));
      final reached = c.hasGoal && p.hasGoal ? l.ebAllReached : c.hasGoal ? l.ebKcalTargetReached : l.ebProteinTargetReached;
      return [reached, ?over].join(' ');
    case BriefKind.unknownKcal:
      return l.ebUnknownKcal(formatKcal(kcal));
    case BriefKind.left:
      // Protein still to go is a figure only when every protein value is known; otherwise it is "at least … recorded".
      final proteinSaid = !p.hasGoal || p.reached
          ? null
          : p.left == null
              ? l.ebProteinIncomplete(_g(protein))
              : p.left! >= BriefRules.proteinLeftFrom
                  ? l.ebProteinLeft(_g(p.left!))
                  : null;
      if (c.over != null) return [l.ebOverPlain(formatKcal(c.over!)), ?proteinSaid].join(' ');
      // The calorie target reached with protein still to go: the trade-off is the coach's to explain, on request.
      if (c.state == GoalState.reached) return [l.ebKcalReachedPlain, ?proteinSaid].join(' ');
      if (c.left != null && proteinSaid != null && p.left != null) return l.ebLeftBoth(formatKcal(c.left!), _g(p.left!));
      return [
        if (c.left != null) l.ebKcalLeft(formatKcal(c.left!)),
        if (p.reached) l.ebProteinDone,
        ?proteinSaid,
        l.ebWantOptions,
      ].join(' ');
    case BriefKind.logged:
      return l.ebLogged(mealLabel(l, b.meal!));
  }
}

/// The meal coming up for the person: the next of their own meal reminders today (an explicit time they chose), else
/// the meal of the time of day.
String nextMealAt(int nowMinute, {List<({String meal, int minute})> reminders = const []}) {
  final next = ([for (final r in reminders) if (r.minute > nowMinute) r]..sort((a, b) => a.minute.compareTo(b.minute))).firstOrNull;
  if (next != null) return next.meal;
  final h = nowMinute ~/ 60;
  return h < 11 ? 'Breakfast' : h < 16 ? 'Lunch' : h < 21 ? 'Dinner' : 'Snack';
}
