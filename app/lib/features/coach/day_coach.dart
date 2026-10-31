import 'dart:convert';
import 'dart:math' as math;

import '../../core/format.dart' show longDate;
import '../../core/language.dart';
import '../../core/units.dart' show formatNumber2;
import '../../data/models.dart';
import '../nutrition/food_item.dart';
import '../nutrition/food_repository.dart';
import '../nutrition/food_search.dart' show searchWords;
import '../nutrition/meal_habits.dart' show UsualMeal, habitIdentity;
import '../nutrition/nutrient_coverage.dart';
import '../nutrition/nutrition_assessment.dart';
import '../nutrition/nutrition_surface.dart' show formatKcal;
import '../nutrition/saved_meals.dart';
import '../today/daily.dart';
import '../today/today_greeting.dart' show todayLine;

/// Help with today and food (docs/COACH.md › Help with today): what Leon or Leona says about the day and about food,
/// worked out here from the person's own records with the app's own nutrition code. Pure: no widgets, no network.
///
/// A request becomes a [DayIntent] — from a suggested request on the phone, or from the server's checked reading of
/// typed words, which names saved items by ID and carries the person's own portion words, never a number of its own —
/// and [resolveDay] turns it into a reply: lines of fact, portion cards and allowlisted actions. Every figure in a reply
/// comes from [CoachMath] over the journal, the goals and the saved items on this phone.

enum ItemKind { meal, recipe, food }

/// A saved meal, recipe, or saved food (a favourite or one of My foods) the coach may suggest.
class CoachItem {
  const CoachItem(this.kind, this.id, this.name, {this.body, this.food});
  final ItemKind kind;
  final String id, name;
  final MealBody? body;
  final FoodItem? food;

  /// What its values are worked out from, as text that is the same for the same content: a change shows as another value.
  String get fingerprint => canonical(body?.j ?? food?.j);
}

/// The account's saved items on this phone, by name: deleted ones and nameless ones left out.
List<CoachItem> coachItems(Iterable<SavedMeal> meals, Iterable<SavedFood> foods) => [
      for (final m in meals)
        if (!m.isDeleted && m.body.name.trim().isNotEmpty) CoachItem(m.body.isRecipe ? ItemKind.recipe : ItemKind.meal, m.id, m.body.name.trim(), body: m.body),
      for (final f in foods)
        if (!f.isDeleted && (f.isFavourite || f.isMine) && f.item.name.trim().isNotEmpty) CoachItem(ItemKind.food, f.id, f.item.name.trim(), food: f.item),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

/// How much of an item: a multiplier of a saved meal ('x'), servings or grams of a recipe ('serving' | 'g'), or a
/// quantity of one of a food's own units (its [FoodUnit] id).
class Portion {
  const Portion(this.amount, this.unit);
  final double amount;
  final String unit;
  Json toJson() => {'amount': amount, 'unit': unit};
  static Portion? fromJson(Object? j) => j is Map && j['amount'] is num && j['unit'] is String ? Portion((j['amount'] as num).toDouble(), j['unit'] as String) : null;
  @override
  bool operator ==(Object other) => other is Portion && other.amount == amount && other.unit == unit;
  @override
  int get hashCode => Object.hash(amount, unit);
}

typedef Values = Map<Nutrient, NutrientTotal>;

/// Portions and their values, through the saved-meal and food arithmetic every screen uses (MealMath, FoodScaling,
/// NutrientCoverage): exact values, unknown kept unknown, a zero kept zero, nothing rounded before it is shown.
abstract final class CoachMath {
  /// Practical steps around the usual portion. Suggestions and "smaller"/"larger" move between these, never to extremes.
  static const steps = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  static FoodUnit? _unit(FoodItem f, String id) => FoodScaling.units(f).where((u) => u.id == id).firstOrNull;

  /// The usual portion: the saved meal as saved, one serving of a recipe, the food's own starting amount.
  static Portion base(CoachItem i) => switch (i.kind) {
        ItemKind.meal => const Portion(1, 'x'),
        ItemKind.recipe => const Portion(1, 'serving'),
        ItemKind.food => () {
            final (q, u) = FoodScaling.initial(i.food!);
            return Portion(q, u.id);
          }(),
      };

  /// The values of [p] of [i], or null when [p] cannot be measured for it (grams of a recipe never weighed, a unit the
  /// food does not have, nothing above zero).
  static Values? values(CoachItem i, Portion p) {
    if (!(p.amount > 0) || !p.amount.isFinite) return null;
    switch (i.kind) {
      case ItemKind.meal:
        if (p.unit != 'x' || p.amount > MealMath.maxMultiplier) return null;
        return {for (final e in i.body!.totals.entries) e.key: e.value.times(p.amount)};
      case ItemKind.recipe:
        if (p.unit != 'g' && p.unit != 'serving') return null;
        final share = MealMath.share(i.body!, p.amount, p.unit == 'g' ? PortionMeasure.gram : PortionMeasure.serving);
        return share == null ? null : {for (final e in i.body!.totals.entries) e.key: e.value.times(share)};
      case ItemKind.food:
        final f = i.food!, unit = _unit(f, p.unit);
        if (unit == null) return null;
        return NutrientCoverage.ofParts([
          {for (final k in FoodItem.nutrientKeys) k: f.nutrient(k) == null ? null : f.nutrient(k)! * p.amount * unit.basisPerUnit},
        ]);
    }
  }

  static bool _measure(String unit) => unit == 'g' || unit == 'ml';
  static double _round(double v, String unit) => _measure(unit) ? math.max(5, (v / 5).round() * 5).toDouble() : math.max(0.25, (v * 4).round() / 4);

  /// The steps for [i] in [unit]: around one serving's weight for a weighed recipe in grams, around the food's starting
  /// amount said in that unit. Empty when the unit cannot be used.
  static List<Portion> ladder(CoachItem i, String unit) {
    final double around;
    switch (i.kind) {
      case ItemKind.meal:
        around = 1;
      case ItemKind.recipe:
        final b = i.body!;
        if (unit == 'g') {
          if (b.preparedWeightG == null || b.servings == null) return const [];
          around = b.preparedWeightG! / b.servings!;
        } else {
          around = 1;
        }
      case ItemKind.food:
        final f = i.food!, start = base(i), to = _unit(f, unit), from = _unit(f, start.unit);
        if (to == null || from == null) return const [];
        around = FoodScaling.exact(start.amount, from, to);
    }
    final out = <Portion>[];
    for (final s in steps) {
      final p = Portion(_round(around * s, unit), unit);
      if (!out.contains(p) && values(i, p) != null) out.add(p);
    }
    return out;
  }

  /// One practical step smaller or larger than [from]; null at the end of the steps.
  static Portion? step(CoachItem i, Portion from, {required bool smaller}) {
    final l = ladder(i, from.unit);
    return smaller ? l.where((p) => p.amount < from.amount - 1e-9).lastOrNull : l.where((p) => p.amount > from.amount + 1e-9).firstOrNull;
  }

  /// The person's own words as a portion of [i]: grams, servings, or a multiplier of [from]. Null when the words do not
  /// fit how [i] is measured: no weight is ever guessed for a serving, no serving for a weight.
  static Portion? explicit(CoachItem i, Portion from, {double? factor, double? servings, double? grams}) {
    Portion? p;
    if (grams != null) {
      p = switch (i.kind) { ItemKind.meal => null, ItemKind.recipe => Portion(grams, 'g'), ItemKind.food => Portion(grams, 'g') };
    } else if (servings != null) {
      p = switch (i.kind) {
        ItemKind.meal => Portion(servings, 'x'),
        ItemKind.recipe => Portion(servings, 'serving'),
        ItemKind.food => Portion(servings, FoodScaling.units(i.food!).where((u) => u.id.startsWith('serving')).firstOrNull?.id ?? ''),
      };
    } else if (factor != null) {
      p = Portion(_round(from.amount * factor, from.unit), from.unit);
    }
    return p != null && values(i, p) != null ? p : null;
  }
}

/// One suggested portion and its values. [overKcal] / [underProtein]: by how much it misses a target (never shown as fitting).
class Pick {
  const Pick(this.item, this.portion, this.values, {this.overKcal, this.underProtein});
  final CoachItem item;
  final Portion portion;
  final Values values;
  final double? overKcal, underProtein;
  bool get fits => overKcal == null && underProtein == null;
}

class Suggestions {
  const Suggestions(this.picks, {this.fits = true, this.leftOut = 0});
  final List<Pick> picks;

  /// False: nothing met every target, and [picks] are the nearest, each with what it misses.
  final bool fits;

  /// Items left out because a value a target needs is unknown for them.
  final int leftOut;
}

/// Up to three portions from [items] for this meal. Without a target: the usual portions (by protein when [byProtein]).
/// With targets (calories at most [maxKcal], protein at least [minProtein]): for each item the practical step closest to
/// its usual portion that meets them, by most protein (or nearest the calorie limit); a value a target needs must be
/// known. Nothing fits: the nearest, labelled with their misses. A target is never relaxed to make something fit.
Suggestions suggest(List<CoachItem> items, {int? maxKcal, int? minProtein, ItemKind? source, bool byProtein = false}) {
  final pool = [for (final i in items) if (source == null || i.kind == source || (source == ItemKind.meal && i.kind == ItemKind.recipe)) i];
  final kcal = Nutrient.calories, protein = Nutrient.protein;
  if (maxKcal == null && minProtein == null) {
    final picks = [
      for (final i in pool)
        if (CoachMath.values(i, CoachMath.base(i)) case final v? when !byProtein || v[protein]!.isComplete) Pick(i, CoachMath.base(i), v),
    ];
    if (byProtein) picks.sort((a, b) => b.values[protein]!.knownTotal.compareTo(a.values[protein]!.knownTotal));
    return Suggestions(picks.take(3).toList(), leftOut: pool.length - picks.length);
  }
  bool known(Values v) => (maxKcal == null || v[kcal]!.isComplete) && (minProtein == null || v[protein]!.isComplete);
  final fits = <Pick>[], near = <(double, Pick)>[];
  var leftOut = 0;
  for (final i in pool) {
    final base = CoachMath.base(i);
    final options = [for (final p in CoachMath.ladder(i, base.unit)) if (CoachMath.values(i, p) case final v? when known(v)) Pick(i, p, v)];
    if (options.isEmpty) {
      leftOut++;
      continue;
    }
    double distance(Pick p) => (math.log(p.portion.amount / base.amount)).abs();
    final ok = options.where((p) => (maxKcal == null || p.values[kcal]!.knownTotal <= maxKcal) && (minProtein == null || p.values[protein]!.knownTotal >= minProtein)).toList()
      ..sort((a, b) => distance(a).compareTo(distance(b)));
    if (ok.isNotEmpty) {
      fits.add(ok.first);
      continue;
    }
    // The nearest step: the smallest total miss, each relative to its target.
    (double, Pick)? best;
    for (final p in options) {
      final over = maxKcal == null ? 0.0 : math.max(0.0, p.values[kcal]!.knownTotal - maxKcal);
      final under = minProtein == null ? 0.0 : math.max(0.0, minProtein - p.values[protein]!.knownTotal);
      final score = (maxKcal == null ? 0.0 : over / maxKcal) + (minProtein == null ? 0.0 : under / minProtein);
      if (best == null || score < best.$1) best = (score, Pick(i, p.portion, p.values, overKcal: over > 0 ? over : null, underProtein: under > 0 ? under : null));
    }
    near.add(best!);
  }
  if (fits.isNotEmpty) {
    fits.sort((a, b) => minProtein != null || maxKcal == null || byProtein
        ? b.values[protein]!.knownTotal.compareTo(a.values[protein]!.knownTotal)
        : b.values[kcal]!.knownTotal.compareTo(a.values[kcal]!.knownTotal));
    return Suggestions(fits.take(3).toList(), leftOut: leftOut);
  }
  near.sort((a, b) => a.$1.compareTo(b.$1));
  return Suggestions([for (final n in near.take(2)) n.$2], fits: false, leftOut: leftOut);
}

/// [parts] at the practical step closest to their proposed amounts that meets the person's own limits, or the nearest
/// with what it misses. Steps scale every amount together, from the proposed amounts (never drifting). [unknown]: a
/// value a limit needs is unknown, so no step can be promised to meet it.
({List<MealComponent> parts, Values values, double? overKcal, double? underProtein, bool unknown}) fitIdea(List<MealComponent> parts, {int? maxKcal, int? minProtein}) {
  String describe(MealComponent c, double q) => FoodScaling.describe(c.item, q, c.unit);
  Values valuesOf(List<MealComponent> p) => NutrientCoverage.ofParts(p.map((c) => c.values));
  final base = valuesOf(parts);
  if (maxKcal == null && minProtein == null || parts.isEmpty) return (parts: parts, values: base, overKcal: null, underProtein: null, unknown: false);
  final kcal = Nutrient.calories, protein = Nutrient.protein;
  if ((maxKcal != null && !base[kcal]!.isComplete) || (minProtein != null && !base[protein]!.isComplete)) {
    return (parts: parts, values: base, overKcal: null, underProtein: null, unknown: true);
  }
  ({List<MealComponent> parts, Values values, double over, double under}) at(double f) {
    final p = f == 1 ? parts : MealMath.scaled(parts, f, describe), v = valuesOf(p);
    return (parts: p, values: v, over: maxKcal == null ? 0 : math.max(0, v[kcal]!.knownTotal - maxKcal), under: minProtein == null ? 0 : math.max(0, minProtein - v[protein]!.knownTotal));
  }
  final steps = [...CoachMath.steps]..sort((a, b) => math.log(a).abs().compareTo(math.log(b).abs()));
  for (final f in steps) {
    final o = at(f);
    if (o.over == 0 && o.under == 0) return (parts: o.parts, values: o.values, overKcal: null, underProtein: null, unknown: false);
  }
  final o = at(1);
  return (parts: o.parts, values: o.values, overKcal: o.over > 0 ? o.over : null, underProtein: o.under > 0 ? o.under : null, unknown: false);
}

/// A stable short fingerprint (FNV-1a) of [text]: the same records give the same revision on any run.
String fingerprint(String text) {
  var h = 0x811c9dc5;
  for (final c in utf8.encode(text)) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

// ---------------------------------------------------------------------------- one food of a saved meal, this time

/// The foods of [b] named by [words]: every word the person used is a word of the food's name (case, accents and plurals
/// ignored). Never a guess from a similar name: no match is none, several are several.
List<int> ingredientMatches(MealBody b, String words) {
  final want = searchWords(words);
  if (want.isEmpty) return const [];
  return [
    for (final (i, c) in b.components.indexed)
      if (want.every(searchWords(c.name).toSet().contains)) i,
  ];
}

/// Food [c] at the person's own amount: grams only when the food has a weight, servings only when it has a serving, a
/// factor of its own amount. Null when the amount does not fit how the food is measured: no unit is ever swapped.
MealComponent? changedIngredient(MealComponent c, {double? grams, double? servings, double? factor}) {
  final f = c.item, units = FoodScaling.units(f);
  final (double? q, FoodUnit? u) = grams != null
      ? (grams, units.where((u) => u.id == 'g').firstOrNull)
      : servings != null
          ? (servings, units.where((u) => u.id.startsWith('serving')).firstOrNull)
          : factor != null
              ? (c.quantity * factor, c.unit)
              : (null, null);
  if (q == null || u == null || !(q > 0) || q > MealMath.maxQuantity) return null;
  return c.withAmount(q, u.id, FoodScaling.describe(f, q, u));
}

/// The foods of saved meal [b] with the change a reply's card describes (`{index, sourceId, quantity, unit}`), or null
/// when the meal no longer has that food at that place (it was edited since): the review is then not opened.
List<MealComponent>? ingredientParts(MealBody b, Object? change) {
  if (change is! Map || change['index'] is! int || change['quantity'] is! num || change['unit'] is! String) return null;
  final parts = b.components, i = change['index'] as int;
  if (i < 0 || i >= parts.length || parts[i].item.sourceId != change['sourceId']) return null;
  final q = (change['quantity'] as num).toDouble(), unit = FoodScaling.units(parts[i].item).where((u) => u.id == change['unit']).firstOrNull;
  if (unit == null) return null;
  return [...parts]..[i] = parts[i].withAmount(q, unit.id, FoodScaling.describe(parts[i].item, q, unit));
}

// ---------------------------------------------------------------------------- requests

/// What was asked: built on the phone for a suggested request, or read from the server's checked answer for typed words.
class DayIntent {
  const DayIntent(this.kind,
      {this.today = false, this.nutrient, this.source, this.items = const [], this.change, this.factor, this.servings, this.grams, this.maxCalories, this.minProtein,
      this.meal, this.clarification, this.unknownItems = const [], this.ai = false, this.ingredient, this.ideas = const [], this.preferences = const [], this.proposed, this.proceed = false});

  /// `eat` only: the person chose to go on after being told where the day stands (a goal reached): the options follow
  /// without the question again. Set on the phone only; a server answer never sets it.
  final bool proceed;

  /// `ideas` only: the ideas as matched on the phone (`{title, parts, unmatched, confirm}`, features/coach/meal_ideas.dart).
  final List<Json> ideas;

  /// `ideas` only, in a server answer: the model's ideas as words, before matching. Never stored.
  final Object? proposed;
  final List<String> preferences;

  DayIntent withIdeas(List<Json> matched) => DayIntent(kind, today: today, nutrient: nutrient, source: source, items: items, change: change, factor: factor,
      servings: servings, grams: grams, maxCalories: maxCalories, minProtein: minProtein, meal: meal, clarification: clarification, unknownItems: unknownItems,
      ai: ai, ingredient: ingredient, ideas: matched, preferences: preferences, proceed: proceed);

  /// today | recorded | goal | suggest | portion | compare | training | restaurant | clarify | unsupported
  final String kind;

  /// The request explicitly asks about today while another day is shown.
  final bool today;
  final Nutrient? nutrient;
  final ItemKind? source;
  final List<({ItemKind kind, String id})> items;
  final String? change, meal, clarification;
  final double? factor, servings, grams;
  final int? maxCalories, minProtein;
  final List<String> unknownItems;

  /// One food inside a saved meal whose amount changes this time, in the person's words ("rice"): [grams],
  /// [servings] or [factor] then apply to that food, not to the meal.
  final String? ingredient;

  /// Read from typed words by the server's model (said on the reply), as opposed to a built-in request.
  final bool ai;

  /// `eat`: What could I eat? on the phone (no AI). `ideas`: new ideas the server's model proposed as words, matched to
  /// real food records on the phone before they are stored here (features/coach/meal_ideas.dart).
  static const kinds = {'today', 'recorded', 'goal', 'suggest', 'portion', 'compare', 'training', 'restaurant', 'clarify', 'unsupported', 'eat', 'ideas'};

  /// Preferences the person said, from the allowlist. Only protein and calories are checked by GoHard; the others are
  /// passed on as asked and said to be unchecked.
  static const preferenceIds = {'quick', 'sweet', 'noCooking', 'vegetarian', 'cheaper', 'moreProtein', 'lighter', 'different'};

  Json toJson() => {
        'kind': kind, 'today': today, 'nutrient': nutrient?.name, 'source': source?.name, 'items': [for (final i in items) {'kind': i.kind.name, 'id': i.id}],
        'change': change, 'factor': factor, 'servings': servings, 'grams': grams, 'maxCalories': maxCalories, 'minProtein': minProtein, 'meal': meal,
        'clarification': clarification, 'unknownItems': unknownItems, 'ai': ai, 'ingredient': ingredient, 'ideas': ideas, 'preferences': preferences,
        if (proceed) 'proceed': true,
      };

  /// [j] as stored here, or the server's intent (`items`, `portion`, `day`). Anything off the allowlist reads as nothing.
  static DayIntent? fromJson(Object? j, {bool ai = false}) {
    if (j is! Map || j['kind'] is! String || !kinds.contains(j['kind'])) return null;
    T? pick<T extends Enum>(List<T> values, Object? v) => values.where((e) => e.name == v).firstOrNull;
    double? n(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
    final portion = j['portion'] is Map ? j['portion'] as Map : j;
    return DayIntent(j['kind'] as String,
        today: j['today'] == true || j['day'] == 'today', nutrient: pick(Nutrient.values, j['nutrient']), source: pick(ItemKind.values, j['source']),
        items: [
          for (final i in j['items'] as List? ?? const [])
            if (i is Map && pick(ItemKind.values, i['kind']) != null && i['id'] is String) (kind: pick(ItemKind.values, i['kind'])!, id: i['id'] as String),
        ],
        change: const {'smaller', 'larger'}.contains(portion['change']) ? portion['change'] as String : null,
        factor: n(portion['factor']), servings: n(portion['servings']), grams: n(portion['grams']),
        maxCalories: j['maxCalories'] is int ? j['maxCalories'] as int : null, minProtein: j['minProtein'] is int ? j['minProtein'] as int : null,
        meal: meals.contains(j['meal']) ? j['meal'] as String : null, clarification: j['clarification'] is String ? j['clarification'] as String : null,
        unknownItems: [for (final u in j['unknownItems'] as List? ?? const []) if (u is String) u], ai: ai || j['ai'] == true,
        ingredient: switch (portion['ingredient'] ?? j['ingredient']) { final String i when i.trim().isNotEmpty && i.length <= 60 => i.trim(), _ => null },
        // Stored ideas are the phone's own matched ones; a server answer's raw ideas are read by meal_ideas.dart instead.
        ideas: [for (final i in j['ideas'] as List? ?? const []) if (i is Map && i['parts'] is List) Map<String, dynamic>.from(i)],
        preferences: [for (final p in j['preferences'] as List? ?? const []) if (p is String && preferenceIds.contains(p)) p],
        proposed: ai && j['kind'] == 'ideas' ? j['ideas'] : null, proceed: !ai && j['proceed'] == true);
  }
}

// ---------------------------------------------------------------------------- the day's records

/// Everything a reply may use, from the records on this phone. [entries] is null while that day's journal is loading.
class DayRecords {
  const DayRecords({required this.today, required this.shown, this.snapshot, this.workouts = const [], this.entries, this.calorieGoal, this.proteinGoal,
      this.items = const [], this.pending = 0, this.runOpen = false, required this.mealNow, this.usual});

  /// The usual meal for [mealNow] today, when meal suggestions are on and the journal shows one.
  final UsualMeal? usual;
  final String today, shown, mealNow;
  final DailySnapshot? snapshot;
  final List<Workout> workouts;
  final List<FoodEntry>? Function(String day)? entries;
  final int? calorieGoal, proteinGoal;
  final List<CoachItem> items;
  final int pending;
  final bool runOpen;

  CoachItem? item(String id) => items.where((i) => i.id == id).firstOrNull;
}

/// The revision of what a reply about [day] used: the day's journal, the goals, the items on its cards and (for a reply
/// about today's training) the day's workouts. Any change gives another value, so a reply made earlier is recognised.
String dayRevision(DayRecords r, String day, {Iterable<String> itemIds = const [], bool training = false}) {
  final entries = [for (final e in r.entries?.call(day) ?? const <FoodEntry>[]) '${e.id}:${canonical(e.macros)}:${e.partial('calories')}:${e.partial('protein')}']..sort();
  final items = [for (final id in itemIds) '$id:${r.item(id)?.fingerprint ?? '-'}'];
  final s = r.snapshot;
  final work = training && s != null
      ? [s.training.runtimeType, for (final o in s.todaysOccasions) '${o.id}:${o.isSkipped}', for (final w in [...s.inProgress, ...s.finishedToday]) '${w.id}:${w.isOpen}', r.runOpen].join(',')
      : '';
  return fingerprint([day, r.entries?.call(day) == null ? 'loading' : entries.join('|'), r.calorieGoal, r.proteinGoal, items.join('|'), work].join('#'));
}

// ---------------------------------------------------------------------------- replies

/// An allowlisted next step. [card] points at the reply's card it is about; [intent] is a built-in follow-up request.
Json _action(String id, {int? card, Json? intent, String? planId, String? occasionId, String? workoutId}) =>
    {'id': id, 'card': ?card, 'intent': ?intent, 'planId': ?planId, 'occasionId': ?occasionId, 'workoutId': ?workoutId};

/// A nutrient's total as stored on a card: what is known, and whether it is all known.
Json _total(NutrientTotal t) => {'known': t.knownTotal, 'complete': t.isComplete, 'any': t.hasAnyKnown};

String kcalSaid(AppLocalizations l, Json t) => t['any'] != true
    ? l.eatCaloriesUnknown
    : t['complete'] == true
        ? l.eatKcalValue(formatKcal(t['known'] as num))
        : l.eatKcalKnown(formatKcal(t['known'] as num));

String proteinSaid(AppLocalizations l, Json t) => t['any'] != true
    ? l.dcProteinUnknown
    : t['complete'] == true
        ? l.eatProteinGramsValue(_g(t['known'] as num))
        : l.dcProteinKnown(_g(t['known'] as num));

String _g(num v) => formatNumber2((v * 10).round() / 10);

/// "1½× the saved amounts", "2 servings", "150 g", "2 eggs (100 g)".
String portionSaid(AppLocalizations l, CoachItem i, Portion p) => switch (i.kind) {
      ItemKind.meal => l.dcTimesSaved(formatNumber2(p.amount)),
      ItemKind.recipe => p.unit == 'g' ? l.eatGramsValue(formatNumber2(p.amount)) : l.mealsServingsAmount(p.amount, MealMath.count(p.amount)),
      ItemKind.food => FoodScaling.describe(i.food!, p.amount, FoodScaling.unit(i.food!, p.unit)),
    };

/// The reply to [intent] from [r], in [l]'s language: `{dayKey, revision, lines, cards, actions, intent, ai}`. Cards
/// carry the item, the portion and its values as worked out now; [focus] is the last reply's card(s), for follow-ups.
Json resolveDay(DayIntent intent, DayRecords r, AppLocalizations l, {List<Json> focus = const []}) {
  final lines = <String>[], cards = <Json>[], actions = <Json>[];
  var day = intent.today ? r.today : r.shown;
  var training = false;

  void switchToToday() {
    if (day != r.today) lines.add(l.dcSwitchedToToday(longDate(r.today)));
    day = r.today;
  }

  List<FoodEntry>? entries() => r.entries?.call(day);
  Values? logged() => entries() == null ? null : NutrientCoverage.calculate(entries()!);

  /// The shared assessment of the day (features/nutrition/nutrition_assessment.dart); null while the journal loads.
  DayAssessment? assessed() => entries() == null ? null : DayAssessment.of(entries()!, calorieGoal: r.calorieGoal, proteinGoal: r.proteinGoal);

  /// What [adds] would make of each goal that is set, today, when the day's value and the option's are both fully known:
  /// calories always said with their real total (also above the target), protein while it is still a goal to reach.
  List<String> towards(Values adds) {
    final a = assessed();
    if (a == null || day != r.today) return const [];
    return [
      for (final x in [a.calories, a.protein])
        if (x.hasGoal && x.complete && adds[x.nutrient]!.isComplete && (x.isCalories || !x.reached))
          x.isCalories
              ? l.dcAddsKcal(formatKcal(adds[x.nutrient]!.knownTotal), formatKcal(x.known + adds[x.nutrient]!.knownTotal), formatKcal(x.goal!))
              : l.dcAddsProtein(_g(adds[x.nutrient]!.knownTotal), _g(x.known + adds[x.nutrient]!.knownTotal), x.goal.toString()),
    ];
  }

  /// Where the day stands against the goals, said before any option (docs/EAT_COMPANION.md › What could I eat?). True when
  /// the reply stops at a question (a goal reached): the person chooses to go on, and nothing is offered meanwhile.
  bool assess(DayAssessment a) {
    final c = a.calories, p = a.protein;
    String kcalLine() => c.left != null ? l.dcAssessKcalLeft(formatKcal(c.left!)) : c.reached ? l.dcAssessKcalReached : l.dcAssessKcalUnknown(formatKcal(c.known));
    String proteinLine() => p.left != null ? l.dcAssessProteinLeft(_g(p.left!)) : p.reached ? l.dcAssessProteinReached : l.dcAssessProteinUnknown(_g(p.known));
    switch (a.situation) {
      case DaySituation.noGoals:
        lines.add(l.dcAssessNoGoals);
        actions.add(_action('goals'));
        return false;
      case DaySituation.bothReached:
        if (intent.proceed) break;
        lines.add(c.hasGoal && p.hasGoal ? l.dcAssessAllReached : c.hasGoal ? l.dcAssessOnlyKcalReached : l.dcAssessOnlyProteinReached);
        if (c.over != null) lines.add(l.ebOverPlain(formatKcal(c.over!)));
        actions.addAll([_action('proceed'), _action('summary')]);
        return true;
      case DaySituation.caloriesReachedProteinLeft:
        if (intent.proceed) break;
        lines.add(p.left != null ? l.dcAssessKcalReachedProteinLeft(_g(p.left!)) : l.dcAssessKcalReachedProteinUnknown(_g(p.known)));
        if (c.over != null) lines.add(l.ebOverPlain(formatKcal(c.over!)));
        actions.addAll([_action('proteinOptions'), _action('proceed'), _action('summary')]);
        return true;
      case DaySituation.proteinReachedCaloriesLeft:
        lines.add(c.left != null ? l.dcAssessProteinReachedKcalLeft(formatKcal(c.left!)) : l.dcAssessProteinReachedKcalUnknown(formatKcal(c.known)));
      case DaySituation.remaining:
        lines.add(c.hasGoal && p.hasGoal ? l.dcAssessBothLeft(formatKcal(c.left!), _g(p.left!)) : c.hasGoal ? kcalLine() : proteinLine());
      case DaySituation.uncertain:
        if (c.hasGoal) lines.add(kcalLine());
        if (p.hasGoal) lines.add(proteinLine());
    }
    // Going on after a goal was reached: anything chosen adds to the calorie total, and each option says by how much.
    if (intent.proceed && c.hasGoal && c.reached) lines.add(l.dcAddsToCalories);
    return false;
  }

  Json card(Pick p, {Nutrient? toward, bool all = false}) {
    final c = {
      'kind': p.item.kind.name, 'id': p.item.id, 'name': p.item.name, 'portion': p.portion.toJson(), 'amount': portionSaid(l, p.item, p.portion),
      'kcal': _total(p.values[Nutrient.calories]!), 'protein': _total(p.values[Nutrient.protein]!),
      if (p.overKcal != null) 'overKcal': p.overKcal, if (p.underProtein != null) 'underProtein': p.underProtein,
    };
    // What it adds toward a goal, only when the day's logged value and the item's are both fully known.
    final t = logged();
    if (all) {
      final said = towards(p.values);
      if (said.isNotEmpty) c['toward'] = said.join('\n');
    } else if (toward != null && day == r.today && t != null) {
      final goal = toward == Nutrient.protein ? r.proteinGoal : r.calorieGoal, have = t[toward]!, adds = p.values[toward]!;
      if (goal != null && have.isComplete && adds.isComplete) {
        c['toward'] = toward == Nutrient.protein
            ? l.dcAddsProtein(_g(adds.knownTotal), _g(have.knownTotal + adds.knownTotal), '$goal')
            : l.dcAddsKcal(formatKcal(adds.knownTotal), formatKcal(have.knownTotal + adds.knownTotal), formatKcal(goal));
      }
    }
    cards.add(c);
    actions.add(_action('review', card: cards.length - 1));
    return c;
  }

  void journalLine() {
    final e = entries();
    if (e == null) return lines.add(l.dcJournalLoading);
    if (e.isEmpty) return lines.add(l.dcJournalEmpty);
    final t = NutrientCoverage.calculate(e);
    lines.add(l.dcJournalLine('${e.length}', kcalSaid(l, _total(t[Nutrient.calories]!)), proteinSaid(l, _total(t[Nutrient.protein]!))));
  }

  void goalLine(Nutrient n) {
    final goal = n == Nutrient.protein ? r.proteinGoal : r.calorieGoal, t = logged()?[n];
    final p = n == Nutrient.protein;
    if (goal == null) {
      lines.add(p ? l.dcGoalProteinNotSet : l.dcGoalCaloriesNotSet);
      if (!actions.any((a) => a['id'] == 'goals')) actions.add(_action('goals'));
      return;
    }
    if (t == null) return lines.add(l.dcJournalLoading);
    final a = assessed()!, x = p ? a.protein : a.calories;
    final g = '$goal', have = t.knownTotal;
    if (!t.hasAnyKnown) {
      lines.add(p ? l.dcGoalProteinNone(g) : l.dcGoalKcalNone(formatKcal(goal)));
    } else if (x.reached) {
      // Known values at or above the goal establish it, even with some unknown.
      lines.add(p ? l.dcGoalProteinReached(_g(have), g) : l.dcGoalKcalReached(formatKcal(have), formatKcal(goal)));
    } else if (x.left case final left?) {
      lines.add(p ? l.dcGoalProteinLeft(_g(have), g, _g(left)) : l.dcGoalKcalLeft(formatKcal(have), formatKcal(goal), formatKcal(left)));
    } else {
      lines.add(p ? l.dcGoalProteinPartial(_g(have), g) : l.dcGoalKcalPartial(formatKcal(have), formatKcal(goal)));
    }
  }

  List<CoachItem> named() => [for (final i in intent.items) ?r.item(i.id)];

  /// What could I eat?, with no AI: the usual meal, a couple of the person's own saved items, and the ways to Eating
  /// out, Find food and Saved meals. New ideas are one tap further (the screen's idea requests).
  void eatChoices() {
    final a = assessed();
    if (a == null) return lines.add(l.dcJournalLoading);
    if (assess(a)) return;
    final c = a.calories, p = a.protein;
    lines.add(l.dcEatIntro);
    if (r.usual case final u?) {
      final v = NutrientCoverage.calculate(u.entries);
      cards.add({'kind': 'usual', 'id': 'usual', 'name': u.saved?.body.name ?? l.habitUsualName(mealLabel(l, u.meal)), 'amount': [for (final e in u.entries) e.amountDescription].join(' · '),
          'kcal': _total(v[Nutrient.calories]!), 'protein': _total(v[Nutrient.protein]!), 'meal': u.meal});
      actions.add(_action('usual', card: cards.length - 1));
    }
    // Ranked against the goals that still apply: within the calories left when that is known, by protein only while the
    // protein goal is still to reach; with the calorie target reached, protein-focused means most protein per kcal.
    final proteinStill = p.hasGoal && !p.reached;
    final List<Pick> picks;
    if (c.reached && intent.nutrient == Nutrient.protein) {
      final known = [
        for (final i in r.items)
          if (CoachMath.values(i, CoachMath.base(i)) case final v? when v[Nutrient.protein]!.isComplete && v[Nutrient.calories]!.isComplete && v[Nutrient.calories]!.knownTotal > 0)
            Pick(i, CoachMath.base(i), v),
      ];
      double density(Pick x) => x.values[Nutrient.protein]!.knownTotal / x.values[Nutrient.calories]!.knownTotal;
      picks = (known..sort((x, y) => density(y).compareTo(density(x)))).take(2).toList();
      if (picks.isNotEmpty) lines.add(l.dcProteinFocused);
    } else if (c.left != null) {
      final s = suggest(r.items, maxKcal: c.left!.floor(), byProtein: proteinStill);
      picks = s.picks.take(2).toList();
      if (picks.isNotEmpty) lines.add(s.fits ? l.dcFitsLeft(formatKcal(c.left!)) : l.dcNoneFitsLeft(formatKcal(c.left!)));
    } else {
      picks = suggest(r.items, byProtein: proteinStill).picks.take(2).toList();
    }
    for (final x in picks) {
      card(x, all: true);
    }
    actions.addAll([_action('eatingOut'), _action('addFood'), _action('meals')]);
  }

  /// The model's ideas, as matched on the phone: totals from the food records only, at the person's own limits when
  /// they gave one (a practical step of every amount), with what still needs a food match or does not fit said plainly.
  void ideaCards() {
    final usualIds = {for (final e in r.usual?.entries ?? const <FoodEntry>[]) ?habitIdentity(e)};
    var ideas = [
      for (final (n, i) in intent.ideas.indexed)
        (index: n, title: i['title'] as String? ?? '', parts: [for (final p in i['parts'] as List? ?? const []) MealComponent(Map<String, dynamic>.from(p as Map))],
            unmatched: [for (final u in i['unmatched'] as List? ?? const []) '$u'], confirm: [for (final c in i['confirm'] as List? ?? const []) Map<String, dynamic>.from(c as Map)]),
    ];
    if (intent.preferences.contains('different') && usualIds.isNotEmpty) {
      String? id(MealComponent c) => habitIdentity(FoodEntry({'source': {'item': c.item.j, 'quantity': c.quantity, 'unit': c.unitId}}));
      ideas = [for (final i in ideas) if (!i.parts.any((c) => usualIds.contains(id(c)))) i];
    }
    if (ideas.isEmpty) {
      lines.add(l.dcNoIdeas);
      actions.addAll([_action('addFood'), _action('meals'), _action('eatingOut')]);
      return;
    }
    final built = <(Json, double)>[];
    final goals = assessed();
    var anyOver = false, anyWithin = false;
    for (final i in ideas) {
      final fit = fitIdea(i.parts, maxKcal: intent.maxCalories, minProtein: intent.minProtein);
      // Totals only once every food is matched and nothing is left for the person to confirm.
      final complete = i.unmatched.isEmpty && i.confirm.isEmpty && i.parts.isNotEmpty;
      final c = <String, dynamic>{
        'kind': 'idea', 'id': 'idea', 'idea': i.index, 'name': i.title, 'parts': [for (final p in fit.parts) p.j], 'unmatched': i.unmatched, 'confirm': i.confirm,
        'amount': [for (final p in fit.parts) '${p.amount} ${p.name}'].join(' · '),
        if (complete) ...{'kcal': _total(fit.values[Nutrient.calories]!), 'protein': _total(fit.values[Nutrient.protein]!)},
        if (complete && fit.overKcal != null) 'overKcal': fit.overKcal, if (complete && fit.underProtein != null) 'underProtein': fit.underProtein,
        if (complete && fit.unknown) 'unknownTarget': true,
      };
      // How it sits with each of the day's goals, only when the day's value and the idea's are both fully known.
      if (complete) {
        final said = towards(fit.values);
        if (said.isNotEmpty) c['toward'] = said.join('\n');
      }
      final kcalOf = fit.values[Nutrient.calories]!, proteinOf = fit.values[Nutrient.protein]!;
      final double sort;
      if (!complete) {
        sort = double.infinity;
      } else if (intent.preferences.contains('lighter')) {
        sort = kcalOf.knownTotal;
      } else if (intent.preferences.contains('moreProtein')) {
        sort = -proteinOf.knownTotal;
      } else if (goals != null && goals.calories.left != null && kcalOf.isComplete) {
        // Within the calories left first (most protein first while protein is still to reach), then the rest by how far over.
        final over = kcalOf.knownTotal - goals.calories.left!;
        sort = over > 0 ? 1e6 + over : (goals.protein.hasGoal && !goals.protein.reached && proteinOf.isComplete ? -proteinOf.knownTotal : built.length.toDouble());
        if (over > 0) {
          anyOver = true;
        } else {
          anyWithin = true;
        }
      } else if (goals != null && goals.calories.reached && goals.protein.hasGoal && !goals.protein.reached && kcalOf.isComplete && proteinOf.isComplete && kcalOf.knownTotal > 0) {
        sort = -proteinOf.knownTotal / kcalOf.knownTotal; // protein per kcal; the calories each adds are said on its card
      } else {
        sort = built.length.toDouble();
      }
      built.add((c, sort));
    }
    built.sort((a, b) => a.$2.compareTo(b.$2));
    lines.add(l.dcIdeasHeading);
    // Nothing within the calories left: said, never relaxed silently.
    if (anyOver && !anyWithin && goals?.calories.left != null) lines.add(l.dcIdeasNoneFitLeft(formatKcal(goals!.calories.left!)));
    if (goals != null && goals.calories.reached) lines.add(l.dcAddsToCalories);
    for (final (c, _) in built.take(3)) {
      cards.add(c);
      // Review once complete; Find food for a food with no record. A confirmation is answered on the card itself.
      if (c['kcal'] is Map) {
        actions.add(_action('reviewIdea', card: cards.length - 1));
      } else if ((c['unmatched'] as List).isNotEmpty) {
        actions.add(_action('findFood', card: cards.length - 1));
      }
    }
    // What GoHard cannot check is said, never implied: it has no prices, preparation times or dietary labels.
    for (final p in intent.preferences) {
      final note = switch (p) { 'cheaper' => l.dcNoPrices, 'quick' || 'noCooking' => l.dcNotTimed, 'vegetarian' => l.dcNotChecked, _ => null };
      if (note != null && !lines.contains(note)) lines.add(note);
    }
    actions.addAll([_action('another'), _action('addFood')]);
  }

  /// "My chicken meal, but with 150 g of rice today": one food of one saved meal, at the person's own amount, for this
  /// time. Anything unclear is asked back; the card opens the ordinary review, whose Log is the only thing that logs.
  void ingredient(CoachItem item, String words) {
    final base = Pick(item, CoachMath.base(item), CoachMath.values(item, CoachMath.base(item))!);
    if (item.kind != ItemKind.meal) {
      lines.add(l.dcIngredientMealOnly);
      card(base);
      return;
    }
    final parts = item.body!.components, found = ingredientMatches(item.body!, words);
    if (found.length > 1) {
      lines.add(l.dcIngredientWhich(item.name));
      for (final i in found) {
        cards.add({'kind': item.kind.name, 'id': item.id, 'name': parts[i].name, 'choice': true});
        actions.add(_action('ask', card: cards.length - 1, intent: DayIntent('portion', items: [(kind: item.kind, id: item.id)], factor: intent.factor,
            servings: intent.servings, grams: intent.grams, meal: intent.meal, today: intent.today, ingredient: parts[i].name).toJson()));
      }
      return;
    }
    if (found.isEmpty) {
      lines.add(l.dcIngredientNotFound(words, item.name));
      card(base);
      return;
    }
    final i = found.single, c = parts[i];
    if (intent.grams == null && intent.servings == null && intent.factor == null) {
      lines.add(l.dcIngredientNeedAmount(c.name));
      card(base);
      return;
    }
    final changed = changedIngredient(c, grams: intent.grams, servings: intent.servings, factor: intent.factor);
    if (changed == null) {
      lines.add(intent.grams != null ? l.dcIngredientCantGrams(c.name) : l.dcIngredientCantMeasure(c.name));
      card(base);
      return;
    }
    final now = [...parts]..[i] = changed;
    final values = NutrientCoverage.ofParts(now.map((p) => p.values));
    lines.add(l.dcIngredientLine(item.name, changed.amount, c.name));
    cards.add({
      'kind': item.kind.name, 'id': item.id, 'name': item.name, 'portion': CoachMath.base(item).toJson(), 'amount': l.dcIngredientAmount(c.name, changed.amount),
      'kcal': _total(values[Nutrient.calories]!), 'protein': _total(values[Nutrient.protein]!),
      'ingredient': {'index': i, 'sourceId': c.item.sourceId, 'quantity': changed.quantity, 'unit': changed.unitId},
    });
    actions.add(_action('review', card: cards.length - 1));
  }

  switch (intent.kind) {
    case 'today':
      switchToToday();
      training = true;
      final s = r.snapshot;
      if (s == null) {
        lines.add(l.dcTrainingLoading);
      } else {
        lines.add(todayLine(l, s, r.workouts) ?? switch (s.training) { CreatePlan() || ReviewDraft() => l.dcTrainingNoPlan, _ => l.dcTrainingNothingDefinite });
        if (s.recordedToday.isNotEmpty) lines.add(l.dcWorkoutsRecorded('${s.recordedToday.length}'));
        if (r.runOpen) lines.add(l.dcRunOpen);
        // The workout to look at: an open one first, else today's lead planned workout. Viewing starts nothing.
        final open = s.inProgress.firstOrNull;
        final lead = switch (s.training) { PlannedToday(:final plan, :final occasions) => (plan, occasions.firstOrNull), _ => null };
        if (open != null) {
          actions.add(_action('workout', workoutId: open.id));
        } else if (lead != null && lead.$2 != null) {
          actions.add(_action('workout', planId: lead.$1.id, occasionId: lead.$2!.id));
        }
      }
      journalLine();
      lines.add(l.dcTodayChoice);
      actions.add(_action('ask', intent: const DayIntent('suggest').toJson()));
      actions.add(_action('journal'));
    case 'recorded':
      training = day == r.today;
      journalLine();
      if (day == r.today && r.snapshot != null) {
        final done = r.snapshot!.finishedToday.length;
        lines.add(done == 0 ? l.dcNoWorkoutRecorded : l.dcWorkoutsRecorded('$done'));
        if (r.runOpen) lines.add(l.dcRunOpen);
      }
      lines.add(l.dcLoggedOnly);
      actions.add(_action('journal'));
    case 'goal':
      switchToToday();
      final ns = intent.nutrient == null ? [Nutrient.protein, Nutrient.calories] : [intent.nutrient!];
      for (final n in ns) {
        goalLine(n);
      }
      final n = intent.nutrient ?? Nutrient.protein;
      final hasGoal = (n == Nutrient.protein ? r.proteinGoal : r.calorieGoal) != null;
      if (!hasGoal) break;   // asks what the person wants instead of inventing a target
      final s = suggest(r.items, byProtein: n == Nutrient.protein);
      if (s.picks.isEmpty) {
        lines.add(r.items.isEmpty ? l.dcNoItems : l.dcNoProteinKnown);
        actions.addAll([_action('addFood'), _action('meals')]);
        break;
      }
      lines.add(l.dcFromSaved);
      for (final p in s.picks) {
        card(p, toward: n);
      }
      lines.add(l.dcGoalNotMealSize);
    case 'suggest':
      if (r.items.isEmpty) {
        lines.add(l.dcNoItems);
        actions.addAll([_action('addFood'), _action('eatingOut')]);
        break;
      }
      final targets = [if (intent.maxCalories != null) l.dcUnderKcal(formatKcal(intent.maxCalories!)), if (intent.minProtein != null) l.dcAtLeastProtein('${intent.minProtein}')].join(l.dcAnd);
      final s = suggest(r.items, maxKcal: intent.maxCalories, minProtein: intent.minProtein, source: intent.source, byProtein: intent.nutrient == Nutrient.protein);
      if (s.picks.isEmpty) {
        lines.add(targets.isEmpty ? l.dcNoProteinKnown : l.dcNothingKnownFits(targets));
        actions.addAll([_action('addFood'), _action('eatingOut')]);
        break;
      }
      lines.add(targets.isEmpty ? l.dcFromSaved : s.fits ? l.dcFitsHeading(targets) : l.dcNothingFits(targets));
      for (final p in s.picks) {
        card(p, toward: intent.nutrient ?? (intent.minProtein != null ? Nutrient.protein : null));
      }
      if (s.leftOut > 0 && targets.isNotEmpty) lines.add(l.dcUnknownLeftOut);
      if (!s.fits) lines.add(l.dcChangeWhich);
    case 'portion':
      final found = named();
      if (found.length > 1) {
        lines.add(l.dcChoose);
        for (final i in found) {
          cards.add({'kind': i.kind.name, 'id': i.id, 'name': i.name, 'choice': true});
          actions.add(_action('ask', card: cards.length - 1, intent: DayIntent('portion', items: [(kind: i.kind, id: i.id)], change: intent.change, factor: intent.factor,
              servings: intent.servings, grams: intent.grams, meal: intent.meal, today: intent.today).toJson()));
        }
        break;
      }
      final last = focus.length == 1 ? focus.single : null;
      final item = found.firstOrNull ?? (intent.items.isEmpty && last != null ? r.item(last['id'] as String) : null);
      if (item == null) {
        if (intent.unknownItems.isNotEmpty || intent.items.isNotEmpty) {
          lines.add(l.dcNotFound(intent.unknownItems.isEmpty ? l.dcThatItem : intent.unknownItems.map((u) => '"$u"').join(l.dcAnd)));
          actions.addAll([_action('addFood'), _action('meals')]);
        } else {
          lines.add(l.dcNeedItem);
        }
        break;
      }
      if (intent.ingredient case final words?) {
        ingredient(item, words);
        break;
      }
      final from = last != null && last['id'] == item.id ? Portion.fromJson(last['portion']) ?? CoachMath.base(item) : CoachMath.base(item);
      Portion? to;
      if (intent.change != null) {
        to = CoachMath.step(item, from, smaller: intent.change == 'smaller');
        if (to == null) lines.add(intent.change == 'smaller' ? l.dcSmallest : l.dcLargest);
      } else if (intent.factor != null || intent.servings != null || intent.grams != null) {
        to = CoachMath.explicit(item, from, factor: intent.factor, servings: intent.servings, grams: intent.grams);
        if (to == null) lines.add(intent.grams != null && item.kind != ItemKind.food ? l.dcCantGrams : l.dcCantMeasure);
      } else {
        to = from;
      }
      final p = to ?? from;
      card(Pick(item, p, CoachMath.values(item, p)!), toward: r.proteinGoal != null ? Nutrient.protein : null);
    case 'compare':
      final found = named();
      if (found.length < 2) {
        lines.add(intent.unknownItems.isEmpty ? l.dcNeedItem : l.dcNotFound(intent.unknownItems.map((u) => '"$u"').join(l.dcAnd)));
        break;
      }
      final a = found[0], b = found[1];
      final va = CoachMath.values(a, CoachMath.base(a))!, vb = CoachMath.values(b, CoachMath.base(b))!;
      card(Pick(a, CoachMath.base(a), va));
      card(Pick(b, CoachMath.base(b), vb));
      var said = false;
      for (final n in [Nutrient.protein, Nutrient.calories]) {
        if (!va[n]!.isComplete || !vb[n]!.isComplete) continue;
        final d = va[n]!.knownTotal - vb[n]!.knownTotal;
        final (more, less) = d >= 0 ? (a.name, b.name) : (b.name, a.name);
        lines.add(d.abs() < 0.05
            ? (n == Nutrient.protein ? l.dcSameProtein : l.dcSameKcal)
            : n == Nutrient.protein
                ? l.dcMoreProtein(more, _g(d.abs()), less)
                : l.dcMoreKcal(more, formatKcal(d.abs()), less));
        said = true;
      }
      if (!said || !va.values.every((t) => t.isComplete) || !vb.values.every((t) => t.isComplete)) lines.add(l.dcCompareUnknown);
    case 'training':
      lines.add(l.dcTraining);
      actions.add(_action('training'));
    case 'eat' || 'ideas':
      // Ideas are about what to have next: on an earlier day they would read as "eat this now".
      if (day != r.today) {
        lines.add(l.dcIdeasToday);
        actions.add(_action('addFood'));
        break;
      }
      if (intent.kind == 'eat') {
        eatChoices();
      } else {
        ideaCards();
      }
    case 'restaurant':
      lines.add(l.dcRestaurant);
      actions.add(_action('eatingOut'));
    case 'clarify':
      lines.add(intent.clarification ?? l.dcClarify);
    default:
      lines.add(l.dcUnsupported);
  }
  if (r.pending > 0 && intent.kind != 'training' && intent.kind != 'restaurant' && intent.kind != 'unsupported') lines.add(l.dcPending);
  return {
    'dayKey': day, 'revision': dayRevision(r, day, itemIds: [for (final c in cards) c['id'] as String], training: training), 'training': training,
    'lines': lines, 'cards': cards, 'actions': actions, 'intent': intent.toJson(), 'ai': intent.ai,
  };
}

/// A reply in plain words for the next request's history (the server reads it as the person's own context).
String replyText(Json reply, AppLocalizations l) => [
      ...(reply['lines'] as List? ?? const []).cast<String>(),
      for (final c in (reply['cards'] as List? ?? const []).cast<Map>())
        c['choice'] == true || c['kcal'] is! Map
            ? '${c['name']}${c['amount'] is String ? ': ${c['amount']}' : ''}'
            : '${c['name']}: ${c['amount']}, ${kcalSaid(l, Map<String, dynamic>.from(c['kcal'] as Map))}, ${proteinSaid(l, Map<String, dynamic>.from(c['protein'] as Map))}',
    ].join('\n');

/// The draft a card's Review opens: the food's own amount form for a saved food, at the suggested amount, for [day] and
/// [meal]. Null when the item is gone or the amount no longer applies.
FoodDraft? foodDraft(CoachItem i, Portion p, {required String day, required String meal}) {
  if (i.kind != ItemKind.food || CoachMath.values(i, p) == null) return null;
  final unit = FoodScaling.unit(i.food!, p.unit), v = FoodScaling.scale(i.food!, p.amount, unit);
  return FoodDraft(dayKey: day, meal: meal, name: i.name, amount: FoodScaling.describe(i.food!, p.amount, unit), item: i.food, quantity: p.amount, unitId: unit.id,
      calories: v['calories'], protein: v['protein'], carbs: v['carbs'], fat: v['fat']);
}
