import '../../data/models.dart';
import '../nutrition/food_item.dart';
import '../nutrition/food_search.dart';
import '../../core/units.dart' show formatNumber2;
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
  const IdeaSources({this.common = const [], this.mine = const [], this.seen = const [], this.search, this.maxSearches = 3, this.asIs = const {}});
  final List<FoodCandidate> common, mine, seen;
  final Future<List<FoodItem>> Function(String query)? search;
  final int maxSearches;

  /// The keys of everyday foods eaten as they come ([CommonFoodCatalog.eatenAsIs]: fruit, vegetables, dairy, bananas, eggs…): for these,
  /// "Weighed raw or cooked?" changes nothing that matters and is not asked.
  final Set<String> asIs;
}

FoodCandidate candidateOf(FoodItem item, {String? name}) =>
    (item: item, fields: SearchFields(item.name, brand: item.brand), name: name ?? item.name, detail: item.name, startUnit: FoodScaling.initial(item).$2.id);

/// The most choices offered when a food is ambiguous.
const maxChoices = 3;

/// Every record in [pool] at the best [relevance] for [query] (its tier at most [worst]); distinct records only. The
/// same everyday name for several records (raw and cooked breast, breast and thigh for "chicken") stays several: a
/// choice, never the first one.
List<FoodCandidate> _best(String query, List<FoodCandidate> pool, {required int worst}) {
  Relevance? score;
  final best = <FoodCandidate>[];
  for (final c in pool) {
    final s = relevance(query, c.fields);
    if (s == null || s.tier > worst || score != null && compareRelevance(s, score) > 0) continue;
    if (score == null || compareRelevance(s, score) < 0) {
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

/// Finds the records a food named in words can mean, shared by meal ideas and a meal the person describes: the bundled
/// everyday foods, the person's own foods, foods seen on this phone, then (at most [IdeaSources.maxSearches] times) the
/// account's food search. Every word has to be found; the best-named records win, and several equally good ones stay
/// several. One matcher per request: an answer is reused for the same words.
class FoodMatcher {
  FoodMatcher(this.sources);
  final IdeaSources sources;
  var _searches = 0;
  final _found = <String, List<FoodCandidate>>{};

  /// The records [name] can mean: [sure] (one, or several to choose from) and, when none states [preparation], the
  /// records of the same name in another preparation as [maybe] (offered, never taken). A [brand] is searched with the
  /// name and then only that brand's products count; without one, a branded product is never chosen.
  Future<({List<FoodCandidate> sure, List<FoodCandidate> maybe})> match(String name, {String? preparation, String? brand}) async {
    final query = [?brand, name, ?preparation].join(' ');
    final named = [?brand, name].join(' ');
    bool fits(FoodCandidate c) => brand == null ? (c.item.brand ?? '').trim().isEmpty : relevance(query, c.fields)?.tier == 1;
    List<FoodCandidate> onPhone(String q) {
      for (final pool in [sources.common, sources.mine, sources.seen]) {
        final b = _narrowed(q, named, [for (final c in pool) if (brand == null || fits(c)) c], worst: 2);
        if (b.isNotEmpty) return b;
      }
      return const [];
    }

    var sure = _found[query] ??= onPhone(query);
    if (sure.isEmpty && sources.search != null && _searches < sources.maxSearches) {
      _searches++;
      try {
        final pool = [for (final i in await sources.search!(query)) if (fits(candidateOf(i))) candidateOf(i)];
        sure = _found[query] = _narrowed(query, named, pool, worst: 2);
      } on Object {
        sure = const []; // offline, not set up, rate limited: the food stays a name
      }
    }
    final maybe = sure.isEmpty && preparation != null ? onPhone(named) : const <FoodCandidate>[];
    return (sure: sure, maybe: maybe);
  }
}

/// Matches every food of [ideas] (as the server checked them) and returns the ideas as stored on a reply:
/// `{title, parts: [MealComponent + match], unmatched: [label], confirm: [{confirm: 'record' | 'amount', label, …}]}`.
Future<List<Json>> resolveIdeas(List<({String title, List<IdeaFood> foods})> ideas, IdeaSources sources) async {
  final matcher = FoodMatcher(sources);
  final out = <Json>[];
  for (final idea in ideas) {
    final parts = <Json>[], unmatched = <String>[], confirm = <Json>[];
    for (final f in idea.foods) {
      final m = await matcher.match(f.name, preparation: f.preparation);
      final options = m.sure.length == 1 ? m.sure : [...m.sure, ...m.maybe];
      if (options.isEmpty) {
        unmatched.add(f.label);
      } else if (options.length == 1 && m.sure.length == 1) {
        final placed = placeFood(_food(options.single), label: f.label, quantity: f.quantity, unit: f.unit, noun: f.noun);
        placed['confirm'] == null ? parts.add(placed) : confirm.add(placed);
      } else {
        // A record that does not state the proposed preparation is marked: choosing it asks for a fresh amount.
        confirm.add({'confirm': 'record', 'label': f.label, 'quantity': f.quantity, 'unit': f.unit, 'noun': f.noun,
            'options': [for (final c in options.take(maxChoices)) {..._food(c), if (!m.sure.contains(c)) 'differs': f.preparation}]});
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
    final chosen = Map<String, dynamic>.from(options[option] as Map);
    final asked = chosen.remove('differs');
    // Another preparation than proposed (dry oats for cooked oats): the amount proposed was for that preparation, so it
    // is never reused; the person chooses a fresh one, told why.
    final placed = asked is String
        ? {'confirm': 'amount', 'label': c['label'], 'food': chosen, 'asked': asked}
        : placeFood(chosen, label: c['label'] as String, quantity: (c['quantity'] as num?)?.toDouble(), unit: c['unit'] as String?, noun: c['noun'] as String?);
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

// ---------------------------------------------------------------------------- a meal the person describes

/// One food the person said they ate (docs/FOOD_DATA.md › Describe your meal), as the server checked it: their words and
/// only what they said about it — preparation, brand, amount, unit. Never a record and never a value.
typedef SaidFood = ({String name, String label, String? preparation, String? brand, double? quantity, String? unit, String? noun});

/// The units a described amount may be in: metric, ounces and pounds (converted exactly), or a count of the record's own.
const mealUnits = {'g', 'kg', 'oz', 'lb', 'ml', 'l', 'piece', 'serving'};

/// The most foods one described meal holds (the server reads at most as many).
const maxMealFoods = 12;

Json saidJson(SaidFood f) => {'name': f.name, 'label': f.label, 'preparation': f.preparation, 'brand': f.brand, 'quantity': f.quantity, 'unit': f.unit, 'noun': f.noun};

/// [j] as a said food, or null when it has no name. An amount without a known unit is no amount.
SaidFood? saidOf(Object? j) {
  if (j is! Map) return null;
  String? s(String k) => j[k] is String && (j[k] as String).trim().isNotEmpty ? (j[k] as String).trim() : null;
  final name = s('name');
  if (name == null) return null;
  final q = j['quantity'], unit = s('unit');
  final quantity = q is num && q.isFinite && q > 0 && unit != null && mealUnits.contains(unit) ? q.toDouble() : null;
  return (name: name, label: s('label') ?? name, preparation: s('preparation'), brand: s('brand'), quantity: quantity, unit: quantity == null ? null : unit,
      noun: quantity == null ? null : s('noun'));
}

/// The foods of a server's `ate` answer, read defensively: anything without a name is left out.
List<SaidFood> saidFoodsOf(Object? j) => [for (final f in j is List ? j : const []) ?saidOf(f)];

SaidFood _with(SaidFood f, {String? preparation, double? quantity, String? unit, String? noun, bool amount = false}) => (
      name: f.name, label: f.label, preparation: preparation ?? f.preparation, brand: f.brand,
      quantity: amount ? quantity : f.quantity, unit: amount ? unit : f.unit, noun: amount ? noun : f.noun);

/// An amount said in kilograms, ounces, pounds or litres, in grams or millilitres: exact by definition. Never between a
/// weight and a volume, and never between raw and cooked.
(double, String)? _metric(double q, String unit) => switch (unit) {
      'g' || 'ml' => (q, unit),
      'kg' => (q * 1000, 'g'),
      'oz' => (q * 28.349523125, 'g'),
      'lb' => (q * 453.59237, 'g'),
      'l' => (q * 1000, 'ml'),
      _ => null,
    };

/// Whether the amount was said as a weight or volume: then raw or cooked matters (a cooked weight is not a raw weight).
bool _weighed(SaidFood f) => f.quantity != null && const {'g', 'kg', 'oz', 'lb', 'ml', 'l'}.contains(f.unit);

/// [food] (a matched record) at what the person said: grams or millilitres when weighed, else the said count.
Json _placeSaid(Json food, SaidFood f) {
  final m = f.quantity == null || f.unit == null ? null : _metric(f.quantity!, f.unit!);
  return placeFood(food, label: f.label, quantity: m?.$1 ?? f.quantity, unit: m?.$2 ?? f.unit, noun: f.noun);
}

/// The amount as the person said it ("150 g", "2 egg", "4 oz"), for the reply's words and a follow-up's draft.
String saidAmount(SaidFood f) => f.quantity == null ? '' : '${formatNumber2(f.quantity!)} ${f.unit == 'piece' ? f.noun ?? '' : f.unit}'.trim();

/// One food of a described meal as its draft keeps it: `{ref, said, status, …}`, in the order it was said. `status`:
/// * `ready`: a record and an amount in its own units (`part`, a MealComponent with the record's `match`);
/// * `state`: weighed, no preparation said, and the records say raw or cooked: "Weighed raw or cooked?";
/// * `record`: several records (`options`, at most 3, each maybe `differs`: another preparation than said);
/// * `amount`: a record (`food`) and no amount that fits its units ("How much?"); `asked` when it differs from what was said;
/// * `missing`: no record found: Find food, everything else kept.
Future<Json> resolveSaid(String ref, SaidFood f, FoodMatcher matcher) async {
  // A preparation in the food's own words counts as said ("cooked rice", "riz cuit"), even when not given separately.
  final named = foodState(SearchFields(f.name)) != null;
  final prep = f.preparation ?? (named ? null : foodState(SearchFields(f.label)));
  final m = await matcher.match(f.name, preparation: prep, brand: f.brand);
  Json item(String status, [Json more = const {}]) => {'ref': ref, 'said': saidJson(f), 'status': status, ...more};
  final options = m.sure.length == 1 ? m.sure : [...m.sure, ...m.maybe];
  if (options.isEmpty) return item('missing');
  // Weighed with no preparation said, and a record that says raw or cooked for a food whose weight cooking changes:
  // asked, never assumed. Not for an apple, a yogurt or bread, and never again once said.
  if (prep == null && !named && _weighed(f) && options.any((c) => !matcher.sources.asIs.contains(c.item.key) && foodState(c.fields) != null)) return item('state');
  if (options.length == 1 && m.sure.length == 1) {
    final placed = _placeSaid(_food(options.single), f);
    return placed['confirm'] == null ? item('ready', {'part': placed}) : item('amount', {'food': placed['food']});
  }
  return item('record', {'options': [for (final c in options.take(maxChoices)) {..._food(c), if (!m.sure.contains(c)) 'differs': prep}]});
}

/// Every food of a described meal matched (at most [maxMealFoods]), each with a reference `d1`, `d2`… that a follow-up names.
Future<List<Json>> resolveMeal(List<SaidFood> foods, IdeaSources sources) async {
  final matcher = FoodMatcher(sources);
  return [for (final (i, f) in foods.take(maxMealFoods).indexed) await resolveSaid('d${i + 1}', f, matcher)];
}

/// "Raw" or "Cooked" for an item asking how it was weighed: matched again in that preparation (still maybe a choice, or no
/// record of it: Find food). The amount stays the one the person said: it is what they weighed.
Future<Json> answerState(Json item, String state, IdeaSources sources) async {
  final f = saidOf(item['said']);
  if (item['status'] != 'state' || f == null || !const {'raw', 'cooked'}.contains(state)) return item;
  return resolveSaid(item['ref'] as String, _with(f, preparation: state), FoodMatcher(sources));
}

/// The record chosen for an item asking which one: placed at the said amount, or asking for an amount when the amount does
/// not fit its units, or when it is another preparation than said (the said amount was for that one, so it is cleared).
Json chooseRecord(Json item, int option) {
  final options = item['options'] as List? ?? const [], f = saidOf(item['said']);
  if (item['status'] != 'record' || f == null || option < 0 || option >= options.length) return item;
  final chosen = Map<String, dynamic>.from(options[option] as Map);
  final asked = chosen.remove('differs');
  final base = {'ref': item['ref'], 'said': item['said']};
  if (asked is String) return {...base, 'status': 'amount', 'food': chosen, 'asked': asked};
  final placed = _placeSaid(chosen, f);
  return placed['confirm'] == null ? {...base, 'status': 'ready', 'part': placed} : {...base, 'status': 'amount', 'food': chosen};
}

/// An item with the food and amount the person chose in the usual forms (Choose amount, Find food).
Json readyWith(Json item, Json part) => {'ref': item['ref'], 'said': item['said'], 'status': 'ready', 'part': part};

/// The food an item is about, as shown: its record's name once matched, else the person's word for it.
String itemLabel(Json item) => item['status'] == 'ready'
    ? MealComponent(Map<String, dynamic>.from(item['part'] as Map)).name
    : item['status'] == 'amount' ? '${(item['food'] as Map)['name']}' : saidOf(item['said'])?.label ?? '';

/// The next free reference of a draft (`d1`…`d12`), or null when it is full.
String? nextRef(List<Json> items) {
  final used = {for (final i in items) i['ref']};
  for (var n = 1; n <= maxMealFoods; n++) {
    if (!used.contains('d$n')) return 'd$n';
  }
  return null;
}

/// A change read from a follow-up (kind `edit`), as the server checked it.
typedef MealEdit = ({String op, String? ref, SaidFood? food});

List<MealEdit> mealEditsOf(Object? j) => [
      for (final e in j is List ? j : const [])
        if (e is Map && const {'amount', 'remove', 'add'}.contains(e['op'])) (op: e['op'] as String, ref: e['ref'] as String?, food: saidOf(e['food'])),
    ];

/// [items] with [edits] applied, and what changed (`{op, label, amount}`, for the reply's words). A new amount for a food
/// with a record is placed in that record's units (or asks for one); for one still being confirmed, the food is matched
/// again with it. An added food is matched like the first ones. A reference no longer in the draft changes nothing.
Future<({List<Json> items, List<Json> changes})> applyMealEdits(List<Json> items, List<MealEdit> edits, IdeaSources sources) async {
  final matcher = FoodMatcher(sources);
  final out = [for (final i in items) Map<String, dynamic>.from(i)];
  final changes = <Json>[];
  for (final e in edits) {
    final at = out.indexWhere((i) => i['ref'] == e.ref);
    if (e.op == 'remove' && at >= 0) {
      changes.add({'op': 'remove', 'label': itemLabel(out[at])});
      out.removeAt(at);
    } else if (e.op == 'amount' && at >= 0 && e.food?.quantity != null) {
      final old = out[at], f = saidOf(old['said']);
      if (f == null) continue;
      final said = _with(f, quantity: e.food!.quantity, unit: e.food!.unit, noun: e.food!.noun, amount: true);
      final base = {'ref': old['ref'], 'said': saidJson(said)};
      final part = old['part'] is Map ? Map<String, dynamic>.from(old['part'] as Map) : null;
      final food = part != null
          ? <String, dynamic>{'item': part['item'], 'name': part['name'], 'match': ?part['match']}
          : old['status'] == 'amount' ? Map<String, dynamic>.from(old['food'] as Map) : null;
      Json next;
      if (food != null) {
        final placed = _placeSaid(food, said);
        next = placed['confirm'] == null ? {...base, 'status': 'ready', 'part': placed} : {...base, 'status': 'amount', 'food': food};
      } else {
        next = await resolveSaid(old['ref'] as String, said, matcher);
      }
      out[at] = next;
      changes.add({'op': 'amount', 'label': itemLabel(next), 'amount': saidAmount(said)});
    } else if (e.op == 'add' && e.food != null) {
      final ref = nextRef(out);
      if (ref == null) {
        changes.add({'op': 'full', 'label': e.food!.label});
        continue;
      }
      out.add(await resolveSaid(ref, e.food!, matcher));
      changes.add({'op': 'add', 'label': e.food!.label, 'amount': saidAmount(e.food!)});
    }
  }
  return (items: out, changes: changes);
}

/// The draft's foods in the person's words for a follow-up request: references and words only, never values.
List<Json> draftWords(List<Json> items) => [
      for (final i in items.take(maxMealFoods))
        () {
          final f = saidOf(i['said']);
          final amount = i['status'] == 'ready' ? MealComponent(Map<String, dynamic>.from(i['part'] as Map)).amount : f == null ? '' : saidAmount(f);
          final text = [itemLabel(i), if (amount.isNotEmpty) amount].join(' · ');
          return <String, dynamic>{'ref': i['ref'], 'text': text.length > 100 ? text.substring(0, 100) : text};
        }(),
    ];
