import '../../core/clock.dart';
import '../../data/models.dart';
import 'food_item.dart';
import 'saved_meals.dart';

/// Meal habits (docs/MEAL_HABITS_REMINDERS.md › Habits): what this account usually logs at a meal, worked out on the
/// phone from its own journal. Pure and deterministic: no network, no AI, nothing written.
///
/// Rules (the thresholds are deliberate and documented):
/// * Only the last [HabitRules.windowDays] days before today count; today never counts as evidence for itself.
/// * A day counts once per meal, as the whole combination logged at that meal that day. Several entries on one day are
///   one day of evidence, never several.
/// * Every food of the combination needs a stable identity: the provider/catalog food it was logged from (source and
///   ID) with the kind of unit it was measured in, or the recipe it came from. A hand-typed entry has none, and a day
///   containing one is not evidence. Names are never compared.
/// * A habit is the same combination on at least [HabitRules.minDays] distinct days, the last of them within
///   [HabitRules.freshDays] days, so an old habit stops being suggested by itself. Edits and deletions are seen at once,
///   because the journal is read as it is now.
/// * The amounts suggested are those of the most recent day of that combination, as logged. Nothing is averaged, and
///   no unit is converted.
abstract final class HabitRules {
  static const windowDays = 28, minDays = 3, freshDays = 14;

  /// Meal reminder times: at least this many distinct days logged on the day itself, most within [timeSpread] minutes.
  static const timeDays = 4, timeSpread = 45;
}

/// A food entry's stable identity for habits, or null when it has none (typed by hand, or a recipe portion without
/// its recipe's ID). The unit kind is part of it: the same food by weight and by count are different habits.
String? habitIdentity(FoodEntry e) {
  final s = e.source;
  if (s == null) return null;
  if (e.isRecipePortion) {
    final id = (s['recipe'] as Map)['id'];
    final unit = (s['portion'] as Map?)?['unit'] == 'g' ? 'g' : 'serving';
    return id is String ? 'recipe:$id:$unit' : null;
  }
  if (s['item'] is! Map) return null;
  final item = FoodItem(s['item'] as Json), id = item.sourceId;
  if (id == null || id.isEmpty) return null;
  final unit = s['unit'] as String? ?? '';
  return '${item.source}:$id:${unit.startsWith('serving') ? 'serving' : unit}';
}

/// The combination logged at one meal on one day, or null when any food in it has no identity.
String? _signature(List<FoodEntry> entries) {
  final ids = [for (final e in entries) habitIdentity(e)];
  if (ids.isEmpty || ids.contains(null)) return null;
  return (ids.cast<String>()..sort()).join('|');
}

/// A usual meal: the combination, on how many recent days it was logged, and the entries of its most recent day.
class UsualMeal {
  const UsualMeal({required this.meal, required this.signature, required this.days, required this.lastDay, required this.entries, this.saved});
  final String meal, signature, lastDay;
  final int days;
  final List<FoodEntry> entries;

  /// The account's saved meal with exactly this combination, when there is one: reviewing then offers its own
  /// Update saved meal and Save as a variation.
  final SavedMeal? saved;

  /// What the review starts from: the saved meal's definition, or the foods and amounts of the most recent day.
  MealBody body(String name) => saved != null
      ? MealBody(copyJson(saved!.body.j))
      : MealBody({'kind': MealBody.meal, 'name': name, 'components': [for (final e in entries) MealComponent.fromEntry(e).j]});
}

/// The usual [meal] before [today] in [journal], or null when the records do not show one.
UsualMeal? usualMeal(Iterable<FoodEntry> journal, {required String today, required String meal, Iterable<SavedMeal> saved = const []}) {
  final from = addDays(today, -HabitRules.windowDays), fresh = addDays(today, -HabitRules.freshDays);
  final byDay = <String, List<FoodEntry>>{};
  for (final e in journal) {
    if (e.isDeleted || e.meal != meal || e.dayKey.compareTo(from) < 0 || e.dayKey.compareTo(today) >= 0) continue;
    (byDay[e.dayKey] ??= []).add(e);
  }
  final days = <String, List<String>>{};
  for (final d in byDay.entries) {
    final s = _signature(d.value);
    if (s != null) (days[s] ??= []).add(d.key);
  }
  String? best;
  for (final e in days.entries) {
    e.value.sort();
    if (e.value.length < HabitRules.minDays || e.value.last.compareTo(fresh) < 0) continue;
    final b = days[best];
    if (b == null || e.value.length > b.length || (e.value.length == b.length && e.value.last.compareTo(b.last) > 0)) best = e.key;
  }
  if (best == null) return null;
  final last = days[best]!.last;
  return UsualMeal(
    meal: meal, signature: best, days: days[best]!.length, lastDay: last, entries: byDay[last]!,
    saved: [for (final m in saved) if (!m.isDeleted && !m.body.isRecipe && mealSignature(m.body) == best) m].firstOrNull,
  );
}

/// A saved meal's combination in the same terms as a logged one, or null when a food in it has no identity.
String? mealSignature(MealBody b) => _signature([
      for (final c in b.components) FoodEntry({'id': '', 'dayKey': '', 'meal': '', 'name': c.name, 'amountDescription': '', 'source': {'item': c.item.j, 'quantity': c.quantity, 'unit': c.unitId}}),
    ]);

/// When [meal] was first logged on a day, on the day itself (minutes after local midnight). Written by this phone when
/// it logs; an entry logged for another day leaves none, so a backdated entry is never evidence of an eating time.
typedef LogTime = ({String day, String meal, int minute});

/// The time the person usually logs [meal] ("09:00"), when [times] support it: at least [HabitRules.timeDays] recent
/// days whose entries are still in the journal ([logged]: `day|meal`), most of them within [HabitRules.timeSpread]
/// minutes of the median. Rounded to a quarter hour. Null otherwise: the person then chooses a time.
String? usualLogTime(Iterable<LogTime> times, {required String meal, required String today, required Set<String> logged}) {
  final from = addDays(today, -HabitRules.windowDays);
  final minutes = [
    for (final t in times)
      if (t.meal == meal && t.day.compareTo(from) >= 0 && t.day.compareTo(today) <= 0 && logged.contains('${t.day}|$meal')) t.minute,
  ]..sort();
  if (minutes.length < HabitRules.timeDays) return null;
  final mid = minutes.length ~/ 2;
  final median = minutes.length.isOdd ? minutes[mid] : (minutes[mid - 1] + minutes[mid]) ~/ 2;
  final close = minutes.where((m) => (m - median).abs() <= HabitRules.timeSpread).length;
  if (close * 4 < minutes.length * 3) return null;
  final q = ((median / 15).round() * 15) % (24 * 60);
  return '${(q ~/ 60).toString().padLeft(2, '0')}:${(q % 60).toString().padLeft(2, '0')}';
}
