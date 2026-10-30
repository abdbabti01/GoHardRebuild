import '../../data/models.dart';
import '../nutrition/food_item.dart';
import '../nutrition/food_search.dart';
import '../nutrition/saved_meals.dart' show MealComponent;

/// Meal ideas (docs/EAT_COMPANION.md › Ideas). The model proposes ideas as words: a title and up to six foods, each with
/// an everyday name, a preparation and an amount in g, ml, pieces or servings. Nothing it says is a food record or a
/// value. Here each food is matched to a real record — the bundled everyday foods, the person's own saved foods, foods
/// already seen on this phone, then (bounded) the account's food search — and its amount to one of that record's own
/// units. Every value is then worked out from the record by the app's usual arithmetic.
///
/// Nothing uncertain is decided for the person:
/// * a food with no record stays a name ("needs a food match"), with no totals;
/// * a preparation is never swapped: "cooked rice" is never matched to raw rice, and a proposed preparation that no
///   record states (or several equally good records) becomes a choice the person confirms;
/// * an amount whose unit the record does not have, or that fits several of its units (slice sizes), is never
///   converted or replaced by a standard portion: the person chooses the amount in the usual amount form.
/// An idea gets totals and Review only once every food is matched and confirmed.

/// One food as the model proposed it, after the server's checks.
typedef IdeaFood = ({String name, String label, String? preparation, double? quantity, String? unit, String? noun});

/// A record a food can be matched to, with the words it answers to and the unit a new entry starts in.
/// [detail]: what identifies the record beyond its name (a catalog food's preparation, or the record's own title), shown
/// beside it on the idea.
typedef FoodCandidate = ({FoodItem item, SearchFields fields, String name, String detail, String startUnit});

/// Where records are looked for, best first: bundled everyday foods, then the person's own, then foods seen on this
/// phone. [search] is the account's food search (null offline or on an older server); it is asked at most
/// [maxSearches] times per request, and only for foods nothing on the phone matched.
class IdeaSources {
  const IdeaSources({this.common = const [], this.mine = const [], this.seen = const [], this.search, this.maxSearches = 3});
  final List<FoodCandidate> common, mine, seen;
  final Future<List<FoodItem>> Function(String query)? search;
  final int maxSearches;
}

FoodCandidate candidateOf(FoodItem item, {String? name}) =>
    (item: item, fields: SearchFields(item.name, brand: item.brand), name: name ?? item.name, detail: item.name, startUnit: FoodScaling.initial(item).$2.id);

/// The most choices offered when a food is ambiguous.
const maxChoices = 3;

/// Every record in [pool] at the best [matchScore] for [query] (at most [worst]); distinct records only.
List<FoodCandidate> _best(String query, List<FoodCandidate> pool, {required int worst}) {
  var score = worst + 1;
  final best = <FoodCandidate>[];
  for (final c in pool) {
    final s = matchScore(query, c.fields);
    if (s == null || s > score) continue;
    if (s < score) {
      score = s;
      best.clear();
    }
    if (!best.any((b) => b.item.key == c.item.key)) best.add(c);
  }
  return best;
}

/// The records of [pool] that match [query] (name and preparation) at most [worst], narrowed to those the name alone
/// matches best: the preparation chooses which records count, the name which of them is meant ("raw egg" is the egg,
/// not the raw egg whites). Several left: a choice for the person.
List<FoodCandidate> _narrowed(String query, String name, List<FoodCandidate> pool, {required int worst}) {
  final matching = [for (final c in pool) if ((matchScore(query, c.fields) ?? worst + 1) <= worst) c];
  if (query == name || matching.length < 2) return _best(query, matching, worst: worst);
  final byName = _best(name, matching, worst: 5);
  return byName.isEmpty ? _best(query, matching, worst: worst) : byName;
}

/// The unit of [item] the proposed amount is said in, or null when it is not exactly one of the record's units: no
/// conversion, no standard portion in its place, and no choice between sizes of the same thing.
FoodUnit? ideaUnit(FoodItem item, String? unit, String? noun) {
  final units = FoodScaling.units(item);
  switch (unit) {
    case 'g' || 'ml':
      return units.where((u) => u.id == unit).firstOrNull;
    case 'piece':
      final counts = [for (final u in units) if (u.isCount && u.noun != 'serving') u];
      if (noun == null) return counts.length == 1 ? counts.single : null;
      final want = searchWords(noun);
      final named = [for (final u in counts) if (want.isNotEmpty && want.every(searchWords(u.noun!).contains)) u];
      return named.length == 1 ? named.single : null;
    case 'serving':
      final servings = [for (final u in units) if (u.id.startsWith('serving'))u];
      return servings.length == 1 ? servings.single : null;
  }
  return null;
}

/// A matched record as an idea keeps it before its amount is known.
Json _food(FoodCandidate c) => {'item': MealComponent.slim(c.item).j, 'name': c.name, if (c.detail != c.name) 'match': c.detail};

/// [food] (a matched record) at the proposed amount: a part of the idea, or a confirmation to ask for when the amount
/// does not fit exactly one of the record's units (`{label, food}`).
Json placeFood(Json food, {required String label, double? quantity, String? unit, String? noun}) {
  final item = FoodItem(food['item'] as Json);
  final u = quantity == null ? null : ideaUnit(item, unit, noun);
  if (u == null) return {'confirm': 'amount', 'label': label, 'food': food};
  return {...food, 'quantity': quantity, 'unit': u.id, 'amount': FoodScaling.describe(item, quantity!, u)};
}

/// Matches every food of [ideas] (as the server checked them) and returns the ideas as stored on a reply:
/// `{title, parts: [MealComponent + match], unmatched: [label], confirm: [{confirm: 'record' | 'amount', label, …}]}`.
Future<List<Json>> resolveIdeas(List<({String title, List<IdeaFood> foods})> ideas, IdeaSources sources) async {
  var searches = 0;
  final found = <String, List<FoodCandidate>>{};
  // The records [f] can mean: one, several (ask), or none. With a preparation, only records that state it count; the
  // same name without it is only offered as a choice, never taken.
  Future<({List<FoodCandidate> sure, List<FoodCandidate> maybe})> match(IdeaFood f) async {
    final query = [f.name, ?f.preparation].join(' ');
    List<FoodCandidate> onPhone(String q) {
      for (final (pool, worst) in [(sources.common, 3), (sources.mine, 3), (sources.seen, 1)]) {
        final b = _narrowed(q, f.name, pool, worst: worst);
        if (b.isNotEmpty) return b;
      }
      return const [];
    }

    var sure = found[query] ??= onPhone(query);
    if (sure.isEmpty && sources.search != null && searches < sources.maxSearches) {
      searches++;
      try {
        // Only the record's own name or its head, and never a branded product the idea did not name.
        final pool = [for (final i in await sources.search!(query)) if (i.brand == null || i.brand!.trim().isEmpty) candidateOf(i)];
        sure = found[query] = _narrowed(query, f.name, pool, worst: 1);
      } on Object {
        sure = const []; // offline, not set up, rate limited: the food stays a name
      }
    }
    final maybe = sure.isEmpty && f.preparation != null ? onPhone(f.name) : const <FoodCandidate>[];
    return (sure: sure, maybe: maybe);
  }

  final out = <Json>[];
  for (final idea in ideas) {
    final parts = <Json>[], unmatched = <String>[], confirm = <Json>[];
    for (final f in idea.foods) {
      final m = await match(f);
      final options = m.sure.length == 1 ? m.sure : [...m.sure, ...m.maybe];
      if (options.isEmpty) {
        unmatched.add(f.label);
      } else if (options.length == 1 && m.sure.length == 1) {
        final placed = placeFood(_food(options.single), label: f.label, quantity: f.quantity, unit: f.unit, noun: f.noun);
        placed['confirm'] == null ? parts.add(placed) : confirm.add(placed);
      } else {
        confirm.add({'confirm': 'record', 'label': f.label, 'quantity': f.quantity, 'unit': f.unit, 'noun': f.noun,
            'options': [for (final c in options.take(maxChoices)) _food(c)]});
      }
    }
    out.add({'title': idea.title, 'parts': parts, 'unmatched': unmatched, 'confirm': confirm});
  }
  return out;
}

/// [idea] with its confirmation [index] answered: a record chosen ([option], its amount then placed as proposed, which
/// may still ask for an amount), or an amount chosen ([part], from the amount form). Pure.
Json confirmIdeaFood(Json idea, int index, {int? option, Json? part}) {
  final confirm = [for (final c in idea['confirm'] as List? ?? const []) Map<String, dynamic>.from(c as Map)];
  if (index < 0 || index >= confirm.length) return idea;
  final c = confirm.removeAt(index);
  final parts = [for (final p in idea['parts'] as List? ?? const []) Map<String, dynamic>.from(p as Map)];
  if (part != null) {
    parts.add(part);
  } else if (option != null && c['confirm'] == 'record') {
    final options = c['options'] as List;
    if (option < 0 || option >= options.length) return idea;
    final placed = placeFood(Map<String, dynamic>.from(options[option] as Map), label: c['label'] as String,
        quantity: (c['quantity'] as num?)?.toDouble(), unit: c['unit'] as String?, noun: c['noun'] as String?);
    placed['confirm'] == null ? parts.add(placed) : confirm.insert(index, placed);
  } else {
    return idea;
  }
  return {...idea, 'parts': parts, 'confirm': confirm};
}

/// The ideas in a server answer (`intent.ideas`), read defensively: anything malformed is left out.
List<({String title, List<IdeaFood> foods})> ideasOf(Object? j) => [
      for (final i in j is List ? j : const [])
        if (i is Map && i['title'] is String && i['foods'] is List)
          (
            title: i['title'] as String,
            foods: [
              for (final f in i['foods'] as List)
                if (f is Map && f['name'] is String && (f['name'] as String).trim().isNotEmpty)
                  (
                    name: (f['name'] as String).trim(), label: (f['label'] as String?)?.trim().isNotEmpty == true ? (f['label'] as String).trim() : (f['name'] as String).trim(),
                    preparation: (f['preparation'] as String?)?.trim().isEmpty ?? true ? null : (f['preparation'] as String).trim(),
                    quantity: (f['quantity'] as num?)?.toDouble(), unit: f['unit'] as String?, noun: f['noun'] as String?,
                  ),
            ],
          ),
    ];
