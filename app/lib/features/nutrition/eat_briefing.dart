import '../../core/language.dart';
import '../../core/units.dart' show formatNumber2;
import '../../data/models.dart';
import 'food_repository.dart' show mealLabel;
import 'nutrient_coverage.dart';
import 'nutrition_surface.dart' show formatKcal;

/// Eat's briefing (docs/EAT_COMPANION.md › Briefing): the one thing Leon or Leona says on Eat, chosen on the phone from
/// the day shown, its recorded food, the goals the person set, and the time. Pure: no network, no AI, nothing written.
///
/// * Calories and protein are judged separately: an unknown calorie value never makes a known protein total unknown,
///   and an incomplete calorie total never gives an exact allowance ("at least … recorded" instead).
/// * "Left" is against what is recorded, never a claim about everything eaten. Nothing is inferred from a meal not
///   logged, and nothing is projected from the time of day except one thing: "near the target" is only said while
///   there is time left in the day ([BriefRules.dayLeftBefore]).
/// * An earlier day is described looking back; it never gets a live heads-up or "eat this now".
abstract final class BriefRules {
  /// Near the calorie target: what is left is at most this many kcal, or [nearShare] of the target if that is more…
  static const nearKcal = 150, nearShare = 0.10;

  /// …and it is before this local time (minutes after midnight): 17:00.
  static const dayLeftBefore = 17 * 60;

  /// Protein still to go is mentioned from this many grams.
  static const proteinLeftFrom = 5;
}

/// The in-app heads-ups. Each is said at most once a day per account (its id is `day|kind`), and only while heads-ups
/// are on; afterwards the same state is described plainly.
enum HeadsUp { over, near, protein }

enum BriefKind { pastEmpty, past, empty, headsUp, unknownKcal, left, logged }

class Briefing {
  const Briefing(this.kind, {this.headsUp, this.kcal, this.kcalGoal, this.protein, this.proteinGoal, this.kcalComplete = true, this.proteinComplete = true, this.meal, this.noGoals = false});
  final BriefKind kind;
  final HeadsUp? headsUp;

  /// Recorded totals (what is known) and the goals the person set.
  final double? kcal, protein;
  final int? kcalGoal, proteinGoal;
  final bool kcalComplete, proteinComplete;

  /// The meal this is about: the one logged last ([BriefKind.logged]) or the next one ([BriefKind.empty]).
  final String? meal;

  /// No calorie or protein goal is set: the briefing offers ideas and, quietly, the goal editor.
  final bool noGoals;

  /// `day|kind` of the heads-up, for "said once".
  String? seenKey(String day) => headsUp == null ? null : '$day|${headsUp!.name}';
}

/// The briefing for [day]. [seen]: heads-ups already said (`day|kind`); [headsUps]: the person's setting.
/// [nextMeal]: the meal coming up (a meal reminder's time when the person set one, else the time of day).
Briefing eatBriefing({required String day, required String today, required List<FoodEntry> entries, int? kcalGoal, int? proteinGoal, required int nowMinute,
    required String nextMeal, bool headsUps = true, Set<String> seen = const {}}) {
  final t = NutrientCoverage.calculate(entries);
  final kcal = t[Nutrient.calories]!, protein = t[Nutrient.protein]!;
  Briefing b(BriefKind k, {HeadsUp? h, String? meal}) => Briefing(k, headsUp: h, kcal: kcal.hasAnyKnown ? kcal.knownTotal : null, kcalGoal: kcalGoal,
      protein: protein.hasAnyKnown ? protein.knownTotal : null, proteinGoal: proteinGoal, kcalComplete: kcal.isComplete, proteinComplete: protein.isComplete,
      meal: meal, noGoals: kcalGoal == null && proteinGoal == null);

  if (day != today) return entries.isEmpty ? b(BriefKind.pastEmpty) : b(BriefKind.past);
  if (entries.isEmpty) return b(BriefKind.empty, meal: nextMeal);

  bool may(HeadsUp h) => headsUps && !seen.contains('$day|${h.name}');
  if (kcalGoal != null && kcal.isComplete) {
    final left = kcalGoal - kcal.knownTotal;
    if (left < 0 && may(HeadsUp.over)) return b(BriefKind.headsUp, h: HeadsUp.over);
    final near = left <= (kcalGoal * BriefRules.nearShare).clamp(BriefRules.nearKcal, double.infinity);
    if (left > 0 && near && nowMinute < BriefRules.dayLeftBefore && may(HeadsUp.near)) return b(BriefKind.headsUp, h: HeadsUp.near);
  }
  // A known protein total only grows as more values become known: reaching the goal is true even if some are unknown.
  if (proteinGoal != null && protein.knownTotal >= proteinGoal && may(HeadsUp.protein)) return b(BriefKind.headsUp, h: HeadsUp.protein);
  if (kcalGoal != null && !kcal.isComplete) return b(BriefKind.unknownKcal);
  if (kcalGoal != null || proteinGoal != null) return b(BriefKind.left);
  final last = meals.lastWhere((m) => entries.any((e) => e.meal == m));
  return b(BriefKind.logged, meal: last);
}

String _g(num v) => formatNumber2((v * 10).round() / 10);

/// What the briefing says, in [l]'s language. One or two short sentences; the question at the end is what its action
/// does.
String briefingText(AppLocalizations l, Briefing b, {required String dayLabel}) {
  final kcal = b.kcal ?? 0, protein = b.protein ?? 0;
  String meal(String m) => mealLabel(l, m).toLowerCase();
  switch (b.kind) {
    case BriefKind.pastEmpty:
      return l.ebPastEmpty(dayLabel);
    case BriefKind.past:
      final parts = [
        !b.kcalComplete ? l.ebAtLeastKcal(formatKcal(kcal)) : l.eatKcalValue(formatKcal(kcal)),
        if (b.protein != null) !b.proteinComplete ? l.ebAtLeastProtein(_g(protein)) : l.eatProteinGramsValue(_g(protein)),
      ];
      final goal = b.kcalGoal != null && b.kcalComplete
          ? (kcal > b.kcalGoal! ? l.ebPastOver(formatKcal(kcal - b.kcalGoal!)) : l.ebPastUnder(formatKcal(b.kcalGoal! - kcal)))
          : null;
      return [l.ebPast(dayLabel, parts.join(l.dcAnd)), ?goal].join(' ');
    case BriefKind.empty:
      return l.ebEmpty(meal(b.meal!));
    case BriefKind.headsUp:
      return switch (b.headsUp!) {
        HeadsUp.over => l.ebOver(formatKcal(kcal - b.kcalGoal!)),
        HeadsUp.near => l.ebNear(formatKcal(b.kcalGoal! - kcal)),
        HeadsUp.protein => l.ebProteinReached(_g(protein), '${b.proteinGoal}'),
      };
    case BriefKind.unknownKcal:
      return l.ebUnknownKcal(formatKcal(kcal));
    case BriefKind.left:
      final kcalLeft = b.kcalGoal == null || !b.kcalComplete ? null : b.kcalGoal! - kcal;
      final proteinLeft = b.proteinGoal == null ? null : b.proteinGoal! - protein;
      final proteinDone = proteinLeft != null && proteinLeft <= 0;
      // Protein still to go is a figure only when every protein value is known; otherwise it is "at least … recorded".
      final proteinSaid = proteinLeft == null || proteinDone
          ? null
          : !b.proteinComplete
              ? l.ebProteinIncomplete(_g(protein))
              : proteinLeft >= BriefRules.proteinLeftFrom
                  ? l.ebProteinLeft(_g(proteinLeft))
                  : null;
      if (kcalLeft != null && kcalLeft < 0) return [l.ebOverPlain(formatKcal(-kcalLeft)), ?proteinSaid].join(' ');
      if (kcalLeft != null && proteinSaid != null && b.proteinComplete) return l.ebLeftBoth(formatKcal(kcalLeft), _g(proteinLeft!));
      return [
        if (kcalLeft != null) l.ebKcalLeft(formatKcal(kcalLeft)),
        if (proteinDone) l.ebProteinDone,
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
