import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/language.dart';
import '../../data/models.dart';
import '../../data/sync.dart' show LocalWrite;
import 'nutrient_coverage.dart';
import 'nutrition_assessment.dart';
import 'water.dart';

/// Eat › History & trends (docs/FOOD_DATA.md › History & trends): what was logged per day, week and month, built once
/// from the account's own food and water entries on this phone. Nothing is fetched, estimated or stored here.

enum IntakeMetric {
  calories,
  protein,
  carbs,
  fat,
  water;

  /// "Calories", in the app's language ([intakeMetricLabel]).
  String get label => intakeMetricLabel(currentL10n, this);

  Nutrient? get nutrient => switch (this) {
        calories => Nutrient.calories,
        protein => Nutrient.protein,
        carbs => Nutrient.carbs,
        fat => Nutrient.fat,
        water => null,
      };
}

/// The metric's name: "Calories", "Protein", "Carbs", "Fat", "Water".
String intakeMetricLabel(AppLocalizations l, IntakeMetric m) => switch (m) {
      IntakeMetric.calories => l.eatCalories,
      IntakeMetric.protein => l.eatProtein,
      IntakeMetric.carbs => l.eatCarbs,
      IntakeMetric.fat => l.eatFat,
      IntakeMetric.water => l.waterTitle,
    };

/// The metric as it qualifies "values": "calorie", "protein", "carb", "fat", "water".
String intakeMetricNoun(AppLocalizations l, IntakeMetric m) => switch (m) {
      IntakeMetric.calories => l.trendsNounCalorie,
      IntakeMetric.protein => l.trendsNounProtein,
      IntakeMetric.carbs => l.trendsNounCarb,
      IntakeMetric.fat => l.trendsNounFat,
      IntakeMetric.water => l.trendsNounWater,
    };

/// One day for one metric. [notLogged] means nothing of that kind was logged (food for a nutrient, water for water):
/// not a zero. [unknown]: food was logged but none of it has this value. [partial]: a known sum, some foods without a
/// value. [recorded]: every logged food has the value (or water was logged); a sum of explicit zeroes is a real zero.
enum DayState { future, notLogged, unknown, partial, recorded }

class IntakeDay {
  const IntakeDay(this.dayKey, this.state, {this.value, this.foods = 0, this.unknownFoods = 0, this.waterEntries = 0, this.pending = false, this.review = false});
  final String dayKey;
  final DayState state;

  /// The known sum, full precision (kcal, g, or mL). Null unless [hasValue].
  final double? value;
  final int foods, unknownFoods, waterEntries;

  /// Some of the day's entries are still waiting to reach the account, or need review.
  final bool pending, review;

  bool get hasValue => state == DayState.partial || state == DayState.recorded;
  bool get isZero => hasValue && value == 0;
}

/// The account's live (not deleted) entries grouped by day once per change of the records; every period and metric
/// reads from these maps instead of scanning all entries again.
typedef FoodDays = Map<String, List<Stored<FoodEntry>>>;
typedef WaterDays = Map<String, List<Stored<WaterEntry>>>;

final foodDaysProvider = Provider<AsyncValue<FoodDays>>((ref) => ref.watch(foodJournalProvider).whenData((rows) => _group(rows, (e) => e.isDeleted, (e) => e.dayKey)));
final waterDaysProvider = Provider<AsyncValue<WaterDays>>((ref) => ref.watch(waterEntriesProvider).whenData((rows) => _group(rows, (e) => e.isDeleted, (e) => e.dayKey)));

Map<String, List<Stored<T>>> _group<T>(List<Stored<T>> rows, bool Function(T) deleted, String Function(T) day) {
  final out = <String, List<Stored<T>>>{};
  for (final r in rows) {
    if (!deleted(r.value)) (out[day(r.value)] ??= []).add(r);
  }
  return out;
}

/// The goals in effect on a day, as this phone recorded them ([Kinds.goalDay]). [changed]: they changed during that day,
/// so no single goal applied and the day is not compared with one.
class GoalDay {
  const GoalDay(this.calorieGoal, this.proteinGoal, {this.changed = false});
  final int? calorieGoal, proteinGoal;
  final bool changed;
  static GoalDay of(Json j) => GoalDay(j['calorieGoal'] as int?, j['proteinGoal'] as int?, changed: j['changed'] == true);
}

/// Recorded goal days of this account on this phone, by day key.
final goalDaysProvider = StreamProvider<Map<String, GoalDay>>((ref) {
  final owner = ref.watch(ownerProvider);
  if (owner == null) return Stream.value(const {});
  return ref.watch(syncProvider).watch(owner, Kinds.goalDay).map((rows) => {for (final r in rows) r.id: GoalDay.of(jsonDecode(r.body) as Json)});
});

/// Records today's goals as they are now, once the account's profile and the recorded days have loaded: a new day gets
/// its record, and a change during the day keeps the latest goals and marks the day `changed`, except the first goals
/// set on a day that had none (that is the day's goal, not a change between two). Watched by the app root.
/// Nothing is written for a day the app was not open, and nothing is guessed for earlier days.
final goalHistorySyncProvider = Provider<void>((ref) {
  final owner = ref.watch(ownerProvider);
  final profile = ref.watch(profileProvider);
  final days = ref.watch(goalDaysProvider);
  if (owner == null || !profile.hasValue || profile.value == null || !days.hasValue) return;
  final today = ref.watch(todayKeyProvider), p = profile.value!;
  final had = days.value![today];
  if (had != null && had.calorieGoal == p.calorieGoal && had.proteinGoal == p.proteinGoal) return;
  final changed = had != null && (had.changed || had.calorieGoal != null || had.proteinGoal != null);
  final body = {'calorieGoal': p.calorieGoal, 'proteinGoal': p.proteinGoal, 'changed': changed};
  // A failed write only means this day may go unrecorded; nothing else depends on it.
  ref.read(syncProvider).putLocal(owner, LocalWrite(Kinds.goalDay, today, body)).catchError((_) {});
});

IntakeDay intakeDay(String day, IntakeMetric m, {required String today, FoodDays food = const {}, WaterDays water = const {}}) {
  if (day.compareTo(today) > 0) return IntakeDay(day, DayState.future);
  final f = food[day] ?? const [], w = water[day] ?? const [];
  bool pending(List<Stored<Object?>> rows) => rows.any((r) => r.isPending);
  bool review(List<Stored<Object?>> rows) => rows.any((r) => r.needsReview);
  if (m == IntakeMetric.water) {
    if (w.isEmpty) return IntakeDay(day, DayState.notLogged, foods: f.length);
    return IntakeDay(day, DayState.recorded, value: waterTotal([for (final r in w) r.value]), foods: f.length, waterEntries: w.length, pending: pending(w), review: review(w));
  }
  if (f.isEmpty) return IntakeDay(day, DayState.notLogged, waterEntries: w.length);
  final t = NutrientCoverage.calculate([for (final r in f) r.value])[m.nutrient]!;
  final state = !t.hasAnyKnown ? DayState.unknown : t.isComplete ? DayState.recorded : DayState.partial;
  return IntakeDay(day, state, value: t.hasAnyKnown ? t.knownTotal : null, foods: f.length, unknownFoods: t.unknownEntries, waterEntries: w.length, pending: pending(f), review: review(f));
}

enum PeriodKind { week, month }

/// A calendar week (Monday to Sunday) or month, by day keys: calendar arithmetic only, never 24-hour steps.
class Period {
  const Period._(this.kind, this.start, this.end);

  factory Period.containing(PeriodKind kind, String day) {
    final d = parseDayKey(day);
    if (kind == PeriodKind.week) {
      final start = addDays(day, 1 - d.weekday);
      return Period._(kind, start, addDays(start, 6));
    }
    return Period._(kind, dayKeyOf(DateTime.utc(d.year, d.month, 1)), dayKeyOf(DateTime.utc(d.year, d.month + 1, 0)));
  }

  final PeriodKind kind;
  final String start, end;

  int get length => daysBetween(start, end) + 1;
  List<String> get days => [for (var i = 0; i < length; i++) addDays(start, i)];
  bool contains(String day) => day.compareTo(start) >= 0 && day.compareTo(end) <= 0;

  Period shift(int by) {
    if (kind == PeriodKind.week) return Period.containing(kind, addDays(start, 7 * by));
    final d = parseDayKey(start);
    return Period.containing(kind, dayKeyOf(DateTime.utc(d.year, d.month + by, 1)));
  }

  @override
  bool operator ==(Object other) => other is Period && other.kind == kind && other.start == start;
  @override
  int get hashCode => Object.hash(kind, start);
}

/// One period for one metric: every date position, then the totals over elapsed days only.
class IntakeSummary {
  IntakeSummary._(this.period, this.metric, this.today, this.days);

  factory IntakeSummary.build(Period period, IntakeMetric metric, {required String today, FoodDays food = const {}, WaterDays water = const {}}) =>
      IntakeSummary._(period, metric, today, [for (final d in period.days) intakeDay(d, metric, today: today, food: food, water: water)]);

  final Period period;
  final IntakeMetric metric;
  final String today;
  final List<IntakeDay> days;

  /// The period has not ended yet: "so far" / "month to date".
  bool get current => period.contains(today);
  List<IntakeDay> get elapsed => [for (final d in days) if (d.state != DayState.future) d];
  String get lastElapsed => current ? today : period.end;

  /// Days with at least one known value of this metric: a recorded zero counts, unknown-only and unlogged days do not.
  List<IntakeDay> get known => [for (final d in days) if (d.hasValue) d];
  int get partialDays => days.where((d) => d.state == DayState.partial).length;
  int get unknownDays => days.where((d) => d.state == DayState.unknown).length;

  /// Days with food logged (or water, for water), whatever this metric's values.
  int get loggedDays => days.where((d) => metric == IntakeMetric.water ? d.waterEntries > 0 : d.foods > 0).length;

  /// The sum of known daily values at full precision; null (not zero) when nothing is known.
  double? get total => known.isEmpty ? null : known.fold<double>(0, (s, d) => s + d.value!);

  /// [total] over the days with a known value.
  double? get average => known.isEmpty ? null : total! / known.length;
  double get maxValue => known.fold<double>(0, (m, d) => d.value! > m ? d.value! : m);
}

// ---------------------------------------------------------------------------- weekly report

/// One nutrient over one report week (docs/EAT_COMPANION.md › Weekly report): the trends summary, the average over the
/// days whose every logged food has the value, and how the days compare with the goals that applied (recorded ones only).
class WeekNutrient {
  WeekNutrient._(this.summary, this.compared, this.reached, this.over, this.undetermined);

  factory WeekNutrient.build(IntakeSummary s, {FoodDays food = const {}, Map<String, GoalDay> goals = const {}}) {
    final n = s.metric.nutrient!;
    var compared = 0, reached = 0, over = 0, undetermined = 0;
    for (final d in s.elapsed) {
      final g = goals[d.dayKey];
      final goal = g == null || g.changed ? null : n == Nutrient.calories ? g.calorieGoal : g.proteinGoal;
      // Only a goal recorded for that day, and only a day with food: an unlogged day is not zero.
      if (goal == null || d.foods == 0) continue;
      final entries = [for (final r in food[d.dayKey] ?? const <Stored<FoodEntry>>[]) r.value];
      final a = DayAssessment.of(entries, calorieGoal: n == Nutrient.calories ? goal : null, proteinGoal: n == Nutrient.protein ? goal : null);
      final x = n == Nutrient.calories ? a.calories : a.protein;
      // Below the goal with unknown values cannot be judged; reached is established by the known part.
      if (x.state == GoalState.incomplete || !x.anyKnown) {
        undetermined++;
        continue;
      }
      compared++;
      if (x.reached) reached++;
      if (x.state == GoalState.over) over++;
    }
    return WeekNutrient._(s, compared, reached, over, undetermined);
  }

  final IntakeSummary summary;

  /// Days with food and a recorded goal whose state could be judged; of them, at or above the goal, above it. Days with
  /// a recorded goal but unknown values below it are [undetermined].
  final int compared, reached, over, undetermined;

  /// Days where every logged food has this value (a sum of explicit zeros included).
  List<IntakeDay> get completeDays => [for (final d in summary.days) if (d.state == DayState.recorded) d];
  double? get completeAverage => completeDays.isEmpty ? null : completeDays.fold<double>(0, (t, d) => t + d.value!) / completeDays.length;

  /// The known-value average includes days with some foods missing this value: it may be understated.
  bool get understated => summary.partialDays > 0;

  /// The population standard deviation over complete days; null under [minDaysForSpread] of them.
  double? get spread {
    final v = [for (final d in completeDays) d.value!];
    if (v.length < minDaysForSpread) return null;
    final m = v.reduce((a, b) => a + b) / v.length;
    return math.sqrt(v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / v.length);
  }

  static const minDaysForSpread = 4;
}

enum ObservationKind { coverage, proteinCoverage, steadier, variedMore, proteinGoal, calorieGoal }

enum NextStepKind { completeValues, logDays }

/// A deterministic, factual report of one Monday–Sunday week from local records only: nothing is fetched or asked of
/// an AI. Observations appear only when their calculation supports them; at most [maxObservations].
class WeeklyReport {
  WeeklyReport._(this.week, this.today, this.calories, this.protein, this.loggedDays, this.goalDays, this.observations, this.steps, this.missingValueDays);

  factory WeeklyReport.build(Period week, {required String today, FoodDays food = const {}, Map<String, GoalDay> goals = const {}, IntakeSummary? previousProtein}) {
    final cal = WeekNutrient.build(IntakeSummary.build(week, IntakeMetric.calories, today: today, food: food), food: food, goals: goals);
    final pro = WeekNutrient.build(IntakeSummary.build(week, IntakeMetric.protein, today: today, food: food), food: food, goals: goals);
    final elapsed = cal.summary.elapsed;
    final logged = cal.summary.loggedDays;
    final goalDays = elapsed.where((d) => goals[d.dayKey] != null && !goals[d.dayKey]!.changed).length;
    final missing = elapsed.where((d) => d.foods > 0 && (d.unknownFoods > 0 || pro.summary.days.firstWhere((p) => p.dayKey == d.dayKey).unknownFoods > 0)).length;

    final obs = <(ObservationKind, List<num>)>[];
    if (logged > 0) {
      obs.add((ObservationKind.coverage, [cal.summary.known.length, elapsed.length]));
      if (pro.summary.known.length != cal.summary.known.length) obs.add((ObservationKind.proteinCoverage, [pro.summary.known.length, elapsed.length]));
    }
    if (pro.compared > 0) obs.add((ObservationKind.proteinGoal, [pro.reached, pro.compared]));
    if (cal.compared > 0) obs.add((ObservationKind.calorieGoal, [cal.over, cal.compared]));
    // Spread against the previous week: both weeks need enough complete days, and the difference must be clear.
    final before = previousProtein == null ? null : WeekNutrient.build(previousProtein, food: food).spread, now = pro.spread;
    if (before != null && now != null && (now - before).abs() >= spreadMinGrams) {
      if (now >= before * spreadRatio) obs.add((ObservationKind.variedMore, const []));
      if (now * spreadRatio <= before) obs.add((ObservationKind.steadier, const []));
    }

    final steps = <(NextStepKind, int)>[
      if (missing > 0) (NextStepKind.completeValues, missing),
      if (logged > 0 && logged < elapsed.length && (week.end.compareTo(today) < 0 || elapsed.length - logged > 1)) (NextStepKind.logDays, elapsed.length - logged),
    ];
    return WeeklyReport._(week, today, cal, pro, logged, goalDays, obs.take(maxObservations).toList(), steps.take(2).toList(), missing);
  }

  static const maxObservations = 3;

  /// A change in day-to-day spread is said only when the two weeks differ by this many grams and by this ratio.
  static const spreadMinGrams = 10.0, spreadRatio = 1.5;

  final Period week;
  final String today;
  final WeekNutrient calories, protein;
  final int loggedDays;

  /// Elapsed days with one recorded, unchanged goal record.
  final int goalDays;
  final int missingValueDays;
  final List<(ObservationKind, List<num>)> observations;
  final List<(NextStepKind, int)> steps;

  bool get current => week.contains(today);
  int get elapsed => calories.summary.elapsed.length;
  int get unloggedDays => elapsed - loggedDays;
}
