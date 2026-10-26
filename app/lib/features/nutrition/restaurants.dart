import 'dart:convert';

import '../../data/models.dart';
import 'food_item.dart';
import 'nutrient_coverage.dart';
import 'saved_meals.dart' show MealComponent;

/// Eating out (docs/EATING_OUT.md): verified Canadian restaurant menus, orders built from them, and the deterministic
/// rules that suggest orders. Every value is the catalog's, multiplied by a count; nothing is estimated, and nothing here
/// talks to the network or records food.

/// One menu item exactly as the catalog states it (scripts/build-restaurant-catalog.mjs).
extension type MenuItem(Json j) {
  String get id => j['id'] as String;

  /// The official name ("Rotisserie-Style Chicken"); its size, when the chain sells several, is [size].
  String get name => j['name'] as String;
  String? get size => j['size'] as String?;
  String get displayName => size == null ? name : '$name · $size';
  String get section => j['section'] as String? ?? '';

  /// main | side | dessert | drink
  String get role => j['role'] as String;

  /// sandwich, wrap, salad, bowl, breakfast, pizza, chicken, side, dessert, drink
  String get kind => j['kind'] as String;

  /// What sets apart a different order: a 6-inch and a footlong of the same sub share one.
  String get group => j['group'] as String;

  /// "1 sub (6-inch)", "1 slice (1/6 of a 10-inch small pizza)": what one counts as, in the source's terms.
  String get portion => j['portion'] as String;
  double? get grams => (j['grams'] as num?)?.toDouble();
  double? nutrient(String key) => ((j['nutrients'] as Json?)?[key] as num?)?.toDouble();
  double? extra(String key) => ((j['extra'] as Json?)?[key] as num?)?.toDouble();
  String get build => j['build'] as String? ?? '';
  String get source => j['source'] as String;
  String? get updated => j['updated'] as String?;
  bool get derived => j['derived'] != null;
  int get maxQuantity => j['maxQuantity'] as int? ?? 1;

  /// Only items with stated calories and protein can be ranked against those targets.
  bool get rankable => nutrient('calories') != null && nutrient('protein') != null;
}

extension type RestaurantChain(Json j) {
  String get id => j['id'] as String;
  String get name => j['name'] as String;
  bool get available => j['status'] == 'available';
  String? get unavailable => j['unavailable'] as String?;
  List<Json> get sources => [for (final s in j['sources'] as List? ?? const []) s as Json];
  Json? sourceOf(String id) => sources.where((s) => s['id'] == id).firstOrNull;
  String? buildNote(String build) => (j['builds'] as Json?)?[build] as String?;
  List<MenuItem> get items => [for (final i in j['items'] as List? ?? const []) MenuItem(i as Json)];
  MenuItem? item(String id) => items.where((i) => i.id == id).firstOrNull;
}

class RestaurantCatalog {
  RestaurantCatalog(this.j);
  final Json j;
  String get version => j['version'] as String;

  /// The day the sources were last checked: not the day any of them was published.
  String get checked => j['checked'] as String;
  List<RestaurantChain> get chains => [for (final c in j['chains'] as List) RestaurantChain(c as Json)];
  RestaurantChain? chain(String id) => chains.where((c) => c.id == id).firstOrNull;

  /// The catalog, or null when the text is not one (a cached copy that cannot be read is simply not used).
  static RestaurantCatalog? parse(String text) {
    try {
      final j = jsonDecode(text) as Json;
      final c = RestaurantCatalog(j);
      if (c.version.isEmpty || c.chains.isEmpty || c.chains.any((ch) => ch.items.any((i) => i.portion.isEmpty))) return null;
      return c;
    } on Object {
      return null;
    }
  }

  static const capability = 'restaurants.catalog', interpretCapability = 'restaurants.interpret';

  /// [item] as a food the rest of the app understands: per serving (the item's own portion), with its weight when the
  /// source states it, its four values and, kept with every copy of it (saved meals, journal snapshots), which chain,
  /// catalog version and source it came from. Sodium, fibre and saturated fat travel only where the source states them.
  FoodItem food(RestaurantChain chain, MenuItem item) {
    final source = chain.sourceOf(item.source) ?? const {};
    return FoodItem({
      'source': FoodItem.restaurant, 'sourceId': item.id, 'name': item.displayName, 'brand': '${chain.name} Canada',
      'basis': FoodItem.perServing,
      'nutrients': {for (final k in FoodItem.nutrientKeys) k: item.nutrient(k)},
      'servings': [{'label': item.portion, 'grams': item.grams, 'milliliters': null}],
      'restaurant': {
        'chain': chain.id, 'chainName': chain.name, 'country': 'CA', 'item': item.id, 'catalogVersion': version,
        'source': item.source, 'sourceTitle': source['title'], 'sourceUrl': source['url'], 'published': source['published'], 'checked': source['checked'] ?? checked,
        'updated': item.updated, 'build': chain.buildNote(item.build), 'derived': item.j['derived'],
        'extra': {for (final k in ['sodiumMg', 'fibreG', 'satFatG']) if (item.extra(k) != null) k: item.extra(k)},
      },
    });
  }
}

/// What the journal and saved meals keep of a restaurant food: its chain, catalog version and source, as they were.
extension type RestaurantOrigin(Json j) {
  static RestaurantOrigin? of(FoodItem item) => item.source == FoodItem.restaurant && item.j['restaurant'] is Map ? RestaurantOrigin(item.j['restaurant'] as Json) : null;
  String get chain => j['chain'] as String? ?? '';
  String get chainName => j['chainName'] as String? ?? '';
  String get catalogVersion => j['catalogVersion'] as String? ?? '';
  String? get sourceTitle => j['sourceTitle'] as String?;
  String? get published => j['published'] as String?;
  String? get checked => j['checked'] as String?;
  String? get build => j['build'] as String?;
  double? extra(String k) => ((j['extra'] as Json?)?[k] as num?)?.toDouble();
}

/// [order] as the foods of an ordinary saved meal: one component per line, each its restaurant food at that count of its
/// own portion. Review and log and Save as meal both start from this, so a logged order is one journal entry per item
/// (no total entry) and a saved one is a normal saved meal.
List<MealComponent> orderComponents(RestaurantCatalog catalog, RestaurantChain chain, RestaurantOrder order) => [
      for (final line in order.lines)
        if (chain.item(line.itemId) case final i?)
          () {
            final food = catalog.food(chain, i);
            final unit = FoodScaling.unit(food, 'serving:0');
            final q = line.quantity.toDouble();
            return MealComponent({'item': food.j, 'quantity': q, 'unit': unit.id, 'name': i.displayName, 'amount': FoodScaling.describe(food, q, unit)});
          }(),
    ];

// ---------------------------------------------------------------------------- orders

/// One item of an order and how many.
class OrderLine {
  const OrderLine(this.itemId, this.quantity);
  final String itemId;
  final int quantity;
  Json toJson() => {'itemId': itemId, 'quantity': quantity};
  @override
  bool operator ==(Object other) => other is OrderLine && other.itemId == itemId && other.quantity == quantity;
  @override
  int get hashCode => Object.hash(itemId, quantity);
}

/// An order at one chain. Its values are each line's catalog values times its count, summed with the app's one coverage
/// rule (a nutrient some item lacks is a known part, never a total).
class RestaurantOrder {
  const RestaurantOrder(this.lines);
  final List<OrderLine> lines;
  bool get isEmpty => lines.isEmpty;
  int get count => lines.fold(0, (n, l) => n + l.quantity);

  Map<Nutrient, NutrientTotal> totals(RestaurantChain chain) => NutrientCoverage.ofParts([
        for (final l in lines)
          if (chain.item(l.itemId) case final i?) {for (final k in FoodItem.nutrientKeys) k: i.nutrient(k) == null ? null : i.nutrient(k)! * l.quantity},
      ]);

  double? total(RestaurantChain chain, Nutrient n) {
    final t = totals(chain)[n]!;
    return t.isComplete ? t.knownTotal : null;
  }

  /// [itemId] set to [quantity] (0 removes it); a new item goes at the end.
  RestaurantOrder withQuantity(String itemId, int quantity) {
    final has = lines.any((l) => l.itemId == itemId);
    return RestaurantOrder([
      for (final l in lines)
        if (l.itemId != itemId) l else if (quantity > 0) OrderLine(itemId, quantity),
      if (!has && quantity > 0) OrderLine(itemId, quantity),
    ]);
  }

  int quantityOf(String itemId) => lines.where((l) => l.itemId == itemId).firstOrNull?.quantity ?? 0;

  /// The lines whose items this [chain] still lists (a catalog refresh can retire one; it is reported, never swapped).
  ({RestaurantOrder kept, List<String> missing}) against(RestaurantChain chain) =>
      (kept: RestaurantOrder([for (final l in lines) if (chain.item(l.itemId) != null) l]), missing: [for (final l in lines) if (chain.item(l.itemId) == null) l.itemId]);

  List<Json> toJson() => [for (final l in lines) l.toJson()];
  static RestaurantOrder fromJson(Object? j) => RestaurantOrder([
        for (final l in j as List? ?? const [])
          if (l is Map && l['itemId'] is String && l['quantity'] is int && (l['quantity'] as int) > 0) OrderLine(l['itemId'] as String, l['quantity'] as int),
      ]);

  @override
  bool operator ==(Object other) => other is RestaurantOrder && other.lines.length == lines.length && [for (var i = 0; i < lines.length; i++) other.lines[i] == lines[i]].every((x) => x);
  @override
  int get hashCode => Object.hashAll(lines);
}

// ---------------------------------------------------------------------------- preferences and the ranking rule

/// How suggestions that all fit are put in order. Always shown on screen; never a hidden judgement of what is healthy.
enum OrderPriority { protein, calories, closest }

/// What the person chose: every field optional, nothing filled in for them. Calorie numbers are kcal for the whole order;
/// protein is grams. [keep] items are in every suggestion (with their count); [exclude] items in none; [prefer] limits
/// what is added to those kinds; [avoid] keeps those kinds out.
class OrderPreferences {
  const OrderPreferences({this.maxCalories, this.minCalories, this.minProtein, this.keep = const {}, this.exclude = const {}, this.prefer = const {}, this.avoid = const {}, this.priority});
  final int? maxCalories, minCalories, minProtein;
  final Map<String, int> keep;
  final Set<String> exclude, prefer, avoid;
  final OrderPriority? priority;

  bool get isEmpty => maxCalories == null && minCalories == null && minProtein == null && keep.isEmpty && exclude.isEmpty && prefer.isEmpty && avoid.isEmpty && priority == null;

  /// A minimum above a maximum, or one item both kept and left out: said back, never resolved by guessing.
  bool get contradictory => (minCalories != null && maxCalories != null && minCalories! > maxCalories!) || keep.keys.any(exclude.contains);

  /// The order used when several suggestions fit: the person's choice, else what their targets point to.
  OrderPriority get sortedBy => priority ?? (minProtein != null ? OrderPriority.protein : maxCalories != null ? OrderPriority.closest : OrderPriority.protein);

  OrderPreferences copyWith({int? Function()? maxCalories, int? Function()? minCalories, int? Function()? minProtein, Map<String, int>? keep, Set<String>? exclude,
          Set<String>? prefer, Set<String>? avoid, OrderPriority? Function()? priority}) =>
      OrderPreferences(
        maxCalories: maxCalories == null ? this.maxCalories : maxCalories(), minCalories: minCalories == null ? this.minCalories : minCalories(),
        minProtein: minProtein == null ? this.minProtein : minProtein(), keep: keep ?? this.keep, exclude: exclude ?? this.exclude,
        prefer: prefer ?? this.prefer, avoid: avoid ?? this.avoid, priority: priority == null ? this.priority : priority(),
      );

  Json toJson() => {
        'maxCalories': maxCalories, 'minCalories': minCalories, 'minProtein': minProtein, 'keep': keep, 'exclude': exclude.toList(),
        'prefer': prefer.toList(), 'avoid': avoid.toList(), 'priority': priority?.name,
      };

  static OrderPreferences fromJson(Object? o) {
    final j = o is Map ? o : const {};
    Set<String> set(String k) => {for (final v in j[k] as List? ?? const []) if (v is String) v};
    return OrderPreferences(
      maxCalories: j['maxCalories'] as int?, minCalories: j['minCalories'] as int?, minProtein: j['minProtein'] as int?,
      keep: {for (final e in (j['keep'] as Map? ?? const {}).entries) if (e.value is int) e.key as String: e.value as int},
      exclude: set('exclude'), prefer: set('prefer'), avoid: set('avoid'), priority: OrderPriority.values.where((p) => p.name == j['priority']).firstOrNull,
    );
  }
}

/// A target an order does not meet, by how much (kcal or g).
enum MissKind { overCalories, underCalories, underProtein }

class Miss {
  const Miss(this.kind, this.amount);
  final MissKind kind;
  final double amount;
}

class Suggestion {
  const Suggestion(this.order, {required this.calories, required this.protein, required this.misses});
  final RestaurantOrder order;
  final double calories, protein;
  final List<Miss> misses;
  bool get fits => misses.isEmpty;
}

/// [fits]: orders that meet every chosen target, best first by [sortedBy]. When none does, [nearest]: the closest ones,
/// each with what it misses. Kept and excluded items are never relaxed in either list.
class PlanResult {
  const PlanResult({required this.fits, required this.nearest, required this.sortedBy, this.impossible = false});
  final List<Suggestion> fits, nearest;
  final OrderPriority sortedBy;

  /// Nothing can be built at all (contradictory preferences, or every item ruled out).
  final bool impossible;
}

/// The ranking rule (docs/EATING_OUT.md › Ranking). Deterministic: the same catalog and preferences always give the same
/// suggestions in the same order.
///
/// 1. Candidates: the kept items with their counts, plus at most one main item (pizza slices 1 to 3; others one) unless
///    a main is already kept, plus optionally one side; a dessert only when desserts are preferred or one is kept. Only
///    items with stated calories and protein; never an excluded one or an avoided kind; with [OrderPreferences.prefer],
///    added items are of those kinds. So orders stay ordinary: no stack of burgers unless the person builds one.
/// 2. Hard targets: maximum and minimum calories, minimum protein. An order that meets them all fits.
/// 3. Fitting orders, by [OrderPreferences.sortedBy]: protein (most first), calories (fewest first) or closest (nearest
///    under the maximum); then fewer items; then calories; then the item IDs, so ties are always broken the same way.
/// 4. Variety: at most one suggestion per added main (its group: a 6-inch and a footlong count as one), up to [count].
/// 5. None fits: the [count] nearest, by the sum of each miss relative to its target, each listing what it misses.
abstract final class OrderPlanner {
  static const count = 3;

  static PlanResult suggest(RestaurantChain chain, OrderPreferences p, {int count = OrderPlanner.count}) {
    final sortedBy = p.sortedBy;
    if (p.contradictory) return PlanResult(fits: const [], nearest: const [], sortedBy: sortedBy, impossible: true);
    final pool = [for (final i in chain.items) if (i.rankable && !p.exclude.contains(i.id) && !p.avoid.contains(i.kind)) i];
    final kept = [for (final e in p.keep.entries) if (chain.item(e.key) case final i? when i.rankable) (i, e.value)];
    // "A sandwich rather than a salad" narrows the main only; sides and drinks stay possible.
    bool addable(MenuItem i) => !p.keep.containsKey(i.id) && (i.role != 'main' || !p.prefer.any(_mainKinds.contains) || p.prefer.contains(i.kind));
    final keptRoles = {for (final (i, _) in kept) i.role};

    final mains = <(MenuItem, int)?>[
      if (keptRoles.contains('main')) null
      else
        for (final i in pool)
          if (i.role == 'main' && addable(i))
            for (var q = 1; q <= (i.maxQuantity < 1 ? 1 : i.maxQuantity); q++) (i, q),
    ];
    final sides = <MenuItem?>[null, if (!keptRoles.contains('side')) ...pool.where((i) => i.role == 'side' && addable(i))];
    final desserts = <MenuItem?>[null, if (p.prefer.contains('dessert') && !keptRoles.contains('dessert')) ...pool.where((i) => i.role == 'dessert' && addable(i))];
    final drinks = <MenuItem?>[null, if (!keptRoles.contains('drink')) ...pool.where((i) => i.role == 'drink' && addable(i))];

    final all = <(Suggestion, String)>[];
    for (final m in mains.isEmpty ? const <(MenuItem, int)?>[] : mains) {
      for (final s in sides) {
        for (final d in desserts) {
          for (final dr in drinks) {
            final lines = [
              for (final (i, q) in kept) OrderLine(i.id, q),
              if (m != null) OrderLine(m.$1.id, m.$2),
              if (s != null) OrderLine(s.id, 1),
              if (d != null) OrderLine(d.id, 1),
              if (dr != null) OrderLine(dr.id, 1),
            ];
            if (lines.isEmpty) continue;
            final order = RestaurantOrder(lines);
            final kcal = order.total(chain, Nutrient.calories)!, protein = order.total(chain, Nutrient.protein)!;
            all.add((Suggestion(order, calories: kcal, protein: protein, misses: _misses(p, kcal, protein)), m?.$1.group ?? s?.group ?? d?.group ?? dr?.group ?? ''));
          }
        }
      }
    }
    if (all.isEmpty) return PlanResult(fits: const [], nearest: const [], sortedBy: sortedBy, impossible: true);

    int tie(Suggestion a, Suggestion b) {
      final n = a.order.count.compareTo(b.order.count);
      if (n != 0) return n;
      final k = a.calories.compareTo(b.calories);
      if (k != 0) return k;
      return _ids(a.order).compareTo(_ids(b.order));
    }

    int primary(Suggestion a, Suggestion b) => switch (sortedBy) {
          OrderPriority.protein => b.protein.compareTo(a.protein),
          OrderPriority.calories => a.calories.compareTo(b.calories),
          OrderPriority.closest => p.maxCalories == null ? b.protein.compareTo(a.protein) : (p.maxCalories! - a.calories).compareTo(p.maxCalories! - b.calories),
        };

    final fitting = [for (final s in all) if (s.$1.fits) s]..sort((a, b) {
        final c = primary(a.$1, b.$1);
        return c != 0 ? c : tie(a.$1, b.$1);
      });
    if (fitting.isNotEmpty) return PlanResult(fits: _varied(fitting, count), nearest: const [], sortedBy: sortedBy);

    double distance(Suggestion s) => s.misses.fold(0.0, (d, m) => d + switch (m.kind) {
          MissKind.overCalories => m.amount / p.maxCalories!,
          MissKind.underCalories => m.amount / p.minCalories!,
          MissKind.underProtein => m.amount / p.minProtein!,
        });
    final near = [...all]..sort((a, b) {
        final c = distance(a.$1).compareTo(distance(b.$1));
        return c != 0 ? c : tie(a.$1, b.$1);
      });
    return PlanResult(fits: const [], nearest: _varied(near, count), sortedBy: sortedBy);
  }

  static const _mainKinds = {'sandwich', 'wrap', 'salad', 'bowl', 'breakfast', 'pizza', 'chicken'};

  static String _ids(RestaurantOrder o) => [for (final l in o.lines) '${l.itemId}*${l.quantity}'].join(',');

  static List<Miss> _misses(OrderPreferences p, double kcal, double protein) => [
        if (p.maxCalories != null && kcal > p.maxCalories!) Miss(MissKind.overCalories, kcal - p.maxCalories!),
        if (p.minCalories != null && kcal < p.minCalories!) Miss(MissKind.underCalories, p.minCalories! - kcal),
        if (p.minProtein != null && protein < p.minProtein!) Miss(MissKind.underProtein, p.minProtein! - protein),
      ];

  static List<Suggestion> _varied(List<(Suggestion, String)> sorted, int count) {
    final seen = <String>{};
    return [
      for (final (s, group) in sorted)
        if (seen.add(group)) s,
    ].take(count).toList();
  }
}
