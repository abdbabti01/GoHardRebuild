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
/// A food with no record found stays a name ("needs a food match"): its idea gets no totals. An amount that does not fit
/// any unit of the record is not converted: the record's own starting portion is used and the idea says so.

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

/// The best record for [query] in [pool]: the lowest [matchScore] at most [worst]. A tie keeps the first (the pool's own
/// order), and the chosen record's own name is shown, so it is never silently another food.
FoodCandidate? _best(String query, List<FoodCandidate> pool, {required int worst}) {
  FoodCandidate? best;
  var score = worst + 1;
  for (final c in pool) {
    final s = matchScore(query, c.fields);
    if (s != null && s < score) (best, score) = (c, s);
  }
  return best;
}

/// The unit of [item] the proposed amount is said in, or null when none fits (no conversion is ever made).
FoodUnit? ideaUnit(FoodItem item, String? unit, String? noun, {String? standard}) {
  final units = FoodScaling.units(item);
  switch (unit) {
    case 'g' || 'ml':
      return units.where((u) => u.id == unit).firstOrNull;
    case 'piece':
      final counts = [for (final u in units) if (u.isCount) u];
      if (noun != null) {
        final want = searchWords(noun);
        final named = [for (final u in counts) if (want.isNotEmpty && want.every(searchWords(u.noun!).contains)) u];
        // Several sizes of the same thing (slices): the record's own standard portion, else the one with nothing added.
        final pick = named.where((u) => u.id == standard).firstOrNull ?? named.where((u) => u.tail.isEmpty && searchWords(u.noun!).length == want.length).firstOrNull ?? named.firstOrNull;
        if (pick != null) return pick;
      }
      return counts.length == 1 && counts.single.noun != 'serving' ? counts.single : null;
    case 'serving':
      return units.where((u) => u.id.startsWith('serving')).firstOrNull;
  }
  return null;
}

/// Matches every food of [ideas] (as the server checked them) and returns the ideas as stored on a reply:
/// `{title, parts: [MealComponent], unmatched: [label], startAmounts: [label]}`.
Future<List<Json>> resolveIdeas(List<({String title, List<IdeaFood> foods})> ideas, IdeaSources sources) async {
  var searches = 0;
  final found = <String, FoodCandidate?>{};
  Future<FoodCandidate?> match(IdeaFood f) async {
    final query = [f.name, ?f.preparation].join(' ');
    if (found.containsKey(query)) return found[query];
    // Everyday and own foods: all the words, whole. Then the same name without the preparation, only on the phone's
    // own lists, where the chosen record's preparation is shown with it.
    var c = _best(query, sources.common, worst: 3) ?? _best(query, sources.mine, worst: 3) ?? _best(query, sources.seen, worst: 1);
    c ??= f.preparation == null ? null : _best(f.name, sources.common, worst: 1);
    if (c == null && sources.search != null && searches < sources.maxSearches) {
      searches++;
      try {
        // Only the record's own name or its head, and never a branded product the idea did not name.
        final pool = [for (final i in await sources.search!(query)) if (i.brand == null || i.brand!.trim().isEmpty) candidateOf(i)];
        c = _best(query, pool, worst: 1);
      } on Object {
        c = null; // offline, not set up, rate limited: the food stays a name
      }
    }
    return found[query] = c;
  }

  final out = <Json>[];
  for (final idea in ideas) {
    final parts = <Json>[], unmatched = <String>[], startAmounts = <String>[];
    for (final f in idea.foods) {
      final c = await match(f);
      if (c == null) {
        unmatched.add(f.label);
        continue;
      }
      final item = MealComponent.slim(c.item);
      var unit = f.quantity == null ? null : ideaUnit(item, f.unit, f.noun, standard: c.startUnit);
      var quantity = f.quantity;
      if (unit == null) {
        unit = FoodScaling.unit(item, c.startUnit);
        quantity = unit.id.startsWith('serving') ? 1 : 100;
        startAmounts.add(c.name);
      }
      parts.add({'item': item.j, 'quantity': quantity, 'unit': unit.id, 'name': c.name, 'amount': FoodScaling.describe(item, quantity!, unit), if (c.detail != c.name) 'match': c.detail});
    }
    out.add({'title': idea.title, 'parts': parts, 'unmatched': unmatched, 'startAmounts': startAmounts});
  }
  return out;
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
