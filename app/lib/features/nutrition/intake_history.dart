import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../data/models.dart';
import 'nutrient_coverage.dart';
import 'water.dart';

/// Eat › History & trends (docs/FOOD_DATA.md › History & trends): what was logged per day, week and month, built once
/// from the account's own food and water entries on this phone. Nothing is fetched, estimated or stored here.

enum IntakeMetric {
  calories('Calories', 'calorie'),
  protein('Protein', 'protein'),
  carbs('Carbs', 'carb'),
  fat('Fat', 'fat'),
  water('Water', 'water');

  const IntakeMetric(this.label, this.noun);
  final String label, noun;

  Nutrient? get nutrient => switch (this) {
        calories => Nutrient.calories,
        protein => Nutrient.protein,
        carbs => Nutrient.carbs,
        fat => Nutrient.fat,
        water => null,
      };
}

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
