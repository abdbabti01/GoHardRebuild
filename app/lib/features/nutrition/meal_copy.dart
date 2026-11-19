import '../../core/clock.dart' show addDays;
import '../../data/models.dart';
import 'food_repository.dart';

/// Repeating and copying a logged meal (docs/MEAL_COPY_WORKOUT_PANEL.md). Pure: no network, no AI, nothing written.
/// A source is always one meal on one day; foods from different days are never combined.

/// [meal] as logged on [day], in its logged order, without deleted entries. (Water is its own record kind, never a
/// food entry, so it is never part of a meal.)
List<FoodEntry> mealOn(Iterable<FoodEntry> journal, String day, String meal) => [
  for (final e in journal)
    if (!e.isDeleted && e.dayKey == day && e.meal == meal) e,
];

/// The calendar day before [day] — the day shown in Eat, not necessarily the phone's today.
String dayBefore(String day) => addDays(day, -1);

/// Earlier days that have [meal], newest first: the last [days] days before [before], each day's meal on its own.
List<({String day, List<FoodEntry> entries})> mealSources(Iterable<FoodEntry> journal, {required String before, required String meal, int days = 14}) {
  final from = addDays(before, -days);
  final byDay = <String, List<FoodEntry>>{};
  for (final e in journal) {
    if (e.isDeleted || e.meal != meal || e.dayKey.compareTo(from) < 0 || e.dayKey.compareTo(before) >= 0) continue;
    (byDay[e.dayKey] ??= []).add(e);
  }
  return [for (final d in byDay.keys.toList()..sort((a, b) => b.compareTo(a))) (day: d, entries: byDay[d]!)];
}

/// Where Copy meal starts (changeable in the review, which says it): an earlier day's meal → today, the same meal; one
/// of today's → today, the meal of the time of day ([mealNow]). The journal shown never changes by itself.
({String day, String meal}) copyDestination({required String sourceDay, required String sourceMeal, required String today, required String mealNow}) =>
    sourceDay == today ? (day: today, meal: mealNow) : (day: today, meal: sourceMeal);

/// How one copied food can be changed: by its food's own amount, as a portion of its frozen recipe batch, or not at all
/// (typed by hand, or an older entry without a usable quantity: kept, removed or replaced by an explicitly chosen food).
enum CopyChange { amount, portion, none }

CopyChange copyChange(FoodDraft d) => d.recipe != null
    ? CopyChange.portion
    : d.item != null
    ? CopyChange.amount
    : CopyChange.none;

/// [d] as the entry it would log, to total a review with the journal's own rules (partial recipe sums included).
FoodEntry previewEntry(FoodDraft d) => FoodEntry({
  'id': '',
  'dayKey': d.dayKey,
  'meal': d.meal,
  'name': d.name,
  'amountDescription': d.amount,
  'macros': d.macros,
  'source': FoodRepository.sourceFields(d)['source'],
});

/// The copies, for the destination chosen at the moment of logging. Each keeps its own snapshot; IDs are made new
/// when they are logged.
List<FoodDraft> placed(List<FoodDraft> drafts, {required String day, required String meal}) => [
  for (final d in drafts)
    FoodDraft(
      dayKey: day,
      meal: meal,
      name: d.name,
      amount: d.amount,
      calories: d.calories,
      protein: d.protein,
      carbs: d.carbs,
      fat: d.fat,
      item: d.item,
      quantity: d.quantity,
      unitId: d.unitId,
      recipe: d.recipe,
      kept: d.kept,
    ),
];
