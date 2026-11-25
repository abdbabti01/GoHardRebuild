import 'food_traits.dart';

/// Whether a described food may be taken as one record, needs the person to choose, or has nothing suitable
/// (docs/FOOD_DATA.md › Food resolution). Pure: retrieval gives the candidates, this decides; it never searches, never
/// guesses and never mixes values of different records.
///
/// A record is taken without asking only when it is reviewed (the bundled catalog's own attributes), contradicts nothing
/// said, proves everything said, and adds nothing material that was not said. One record found is not proof, nor is a
/// close name: a single unsuitable or underspecified record is still a choice for the person.

/// How a candidate is known. Reviewed records carry the catalog's attributes; the others only what their name says.
enum Found { catalog, saved, seen, remote }

/// One record that could be meant, with its attributes. [T] is the caller's record type.
class Candidate<T> {
  const Candidate(this.record, this.traits, {required this.origin, this.order = 0, this.generic = false, this.brand, this.other = const {}});
  final T record;
  final Traits traits;
  final Found origin;

  /// Words of the record's name that make it another food made with this one ([productWords]: "orange" in "Orange
  /// chicken"); empty for a reviewed record.
  final Set<String> other;

  /// The product's brand, normalized; null for a generic food.
  final String? brand;

  /// Position in its source (catalog order): ties are broken by it, so the same input gives the same answer.
  final int order;

  /// A reviewed record that says the food's details are not specified (USDA's "NFS"): never taken by itself, offered
  /// as "I'm not sure".
  final bool generic;

  bool get reviewed => origin == Found.catalog;
  String? get family => traits[Attr.family]?.first;
}

/// What was said about one food: its attributes, and those the person confirmed since (an answered question).
class Said {
  const Said(this.traits, {this.confirmed = const {}, this.weighed = false, this.counted = false, this.brand, this.words = const {}});
  final Traits traits;
  final Map<Attr, String> confirmed;

  /// Every word said for this food (normalized), in the person's words and the model's name: another food made with it
  /// ("orange chicken") is matched only when its words are among them. Empty: not known, not checked.
  final Set<String> words;

  /// What the person said or confirmed of [a]: never what the plain word means by default.
  Set<String>? stated(Attr a) {
    final c = confirmed[a];
    if (c != null) return {c};
    final s = traits[a];
    return s == null || s.isEmpty ? null : s;
  }

  /// An amount in grams, millilitres or a measure (a cup): how it was weighed matters. [counted]: a count of whole items.
  final bool weighed, counted;
  final String? brand;

  String? get family => traits[Attr.family]?.first;

  /// What is known of [a]: confirmed first, then said, then what the plain word means for the family.
  Set<String>? value(Attr a) {
    final c = confirmed[a];
    if (c != null) return {c};
    final s = traits[a];
    if (s != null && s.isNotEmpty) return s;
    final d = profileOf(family).defaults[a];
    return d == null ? null : {d};
  }
}

enum Outcome { resolved, clarify, none }

/// The answer for one food. [options]: the choices worth offering, best first (one per distinct set of material details).
/// [unresolved]: the material details the person did not say that set them apart ("Not said: skin"); [unshown]: details
/// the person did say that some of the options cannot show (never "not said"). [estimate]: a reviewed record to offer as
/// "I'm not sure", with what it would assume ([assumes]); [substitute]: it is not a record of the food said (USDA's general
/// chicken for drumsticks), offered only when no record of that food is there, said so, and taken only on the person's
/// tap. [ask]: a detail to ask before choosing (raw or cooked, for a weighed food).
class Resolution<T> {
  const Resolution(this.outcome,
      {this.chosen, this.options = const [], this.unresolved = const [], this.unshown = const [], this.estimate, this.assumes = const [], this.substitute = false, this.ask,
      this.reason = '', this.general = false, this.adequate = false});
  final Outcome outcome;
  final List<Attr> unshown;
  final bool substitute;

  /// [chosen] is a reviewed everyday default (a general record: what it does not say is not specified), shown as such.
  final bool general;

  /// A reviewed record matches everything said (whatever else it names): retrieval need not look further. Relevant
  /// candidates may exist without this (a record that cannot show "grilled" is no match for grilled chicken).
  final bool adequate;
  final Candidate<T>? chosen;
  final List<Candidate<T>> options;
  final List<Attr> unresolved;
  final Candidate<T>? estimate;
  final List<Attr> assumes;
  final Attr? ask;
  final String reason;
}

/// The most choices kept for one food (the card shows three, then "More options"); the rest are found with "Search for another".
const maxOptions = 6;

bool _anyOf(Set<String>? v) => v != null && v.contains(any);

/// [said] against [candidates]. See the class comments; docs/FOOD_DATA.md › Food resolution has the rules with examples.
Resolution<T> resolveFood<T>(Said said, List<Candidate<T>> candidates) {
  final family = said.family;
  final profile = profileOf(family);
  final state = said.value(Attr.state);
  // Raw or cooked matters for a weight, never for a count of whole items (two eggs, one breast).
  final stateMatters = said.weighed && weighsDifferentlyCooked(family);
  final asked = {...profile.ask.where((a) => a != Attr.state || stateMatters)};

  bool contradicts(Candidate<T> c) {
    if (family != null && c.family != null && c.family != family) return true;
    // A brand said is that brand's product (another brand contradicts it); no brand said is never a branded product.
    if (said.brand != null ? c.brand != null && c.brand != said.brand : c.brand != null) return true;
    for (final a in Attr.values) {
      if (a == Attr.family) continue;
      final s = said.value(a), r = c.traits[a];
      if (s == null || r == null || _anyOf(r)) continue;
      if (a == Attr.state && s.contains('cooked') && !r.contains('raw')) continue;
      if (r.intersection(s).isEmpty) return true;
    }
    // Something made of the food (breaded, in sauce, flavoured, from a restaurant) only when it was said.
    final add = c.traits[Attr.addition] ?? (c.reviewed ? const {'none'} : null);
    if (add != null && !add.contains('none') && !_anyOf(add) && said.value(Attr.addition) == null) return true;
    // A part that is another food than the meat (liver, heart, gizzard, giblets, skin…) only when that part was said.
    final cut = c.traits[Attr.cut];
    if (cut != null && cut.length == 1 && explicitParts.contains(cut.first) && !(said.value(Attr.cut)?.contains(cut.first) ?? false)) return true;
    // Another food made with this one ("Orange chicken", "Chicken spread", "Soup, chicken") only when its words were said.
    if (said.words.isNotEmpty && c.other.any((w) => !said.words.contains(w))) return true;
    return false;
  }

  // The food itself: a record shows the family said and, for a known family, the part said ("drumstick"). One that does
  // not (a remote "Chicken, broilers or fryers, meat only", USDA's "Chicken, NS as to part") is not this food: never taken,
  // never a choice, at most a disclosed substitute when nothing else is there. Unknown is neither a match nor a contradiction.
  final part = family == null ? null : said.stated(Attr.cut);
  bool establishes(Candidate<T> c) =>
      (family == null || (c.traits[Attr.family]?.contains(family) ?? false)) &&
      (part == null || !_anyOf(c.traits[Attr.cut]) && (c.traits[Attr.cut]?.intersection(part).isNotEmpty ?? false));

  // What a record would take for granted: material details not said that it names (more specific than what was said).
  List<Attr> assumed(Candidate<T> c) => [
        for (final a in [...asked, ...profile.defaultable])
          // "none" is a raw record's method: not cooked at all, nothing assumed about how.
          if (said.value(a) == null && c.traits[a] != null && !(c.traits[a]!.contains('none')) && !(_anyOf(c.traits[a]) && profile.defaultable.contains(a)) && !(a == Attr.state && !stateMatters))
            a,
      ];
  // What was said that the record cannot show: it says nothing of it, or that it is not specified.
  // A reviewed record lists what was added to the food; saying it has none, it has none.
  Set<String>? recorded(Candidate<T> c, Attr a) => c.traits[a] ?? (a == Attr.addition && c.reviewed ? const {'none'} : null);
  List<Attr> unproven(Candidate<T> c) => [
        for (final a in Attr.values)
          if (a != Attr.family && (said.traits[a] != null || said.confirmed[a] != null) && (recorded(c, a) == null || _anyOf(recorded(c, a))))
            a,
      ];
  // A branded product said, and a generic record: the brand is not shown by it.
  bool brandUnproven(Candidate<T> c) => said.brand != null && c.brand == null;
  // Material details the record leaves unknown (an external record's name says nothing about them).
  int unknown(Candidate<T> c) => [for (final a in asked) if (said.value(a) == null && c.traits[a] == null && !c.reviewed) a].length;

  var compatible = [for (final c in candidates) if (!contradicts(c)) c];
  // For whole items eaten, a raw record is not what was eaten when a cooked one is there.
  if (!said.weighed && state == null && weighsDifferentlyCooked(family) && compatible.any((c) => c.traits[Attr.state]?.contains('cooked') ?? false)) {
    compatible = [for (final c in compatible) if (!(c.traits[Attr.state]?.contains('raw') ?? false)) c];
  }
  if (compatible.isEmpty) return Resolution(Outcome.none, reason: candidates.isEmpty ? 'nothing found' : 'nothing compatible');
  int byOrigin(Candidate<T> a, Candidate<T> b) => a.origin.index != b.origin.index ? a.origin.index.compareTo(b.origin.index) : a.order.compareTo(b.order);
  final broader = [for (final c in compatible) if (!establishes(c)) c];
  compatible = [for (final c in compatible) if (establishes(c)) c];
  if (compatible.isEmpty) {
    // No record of the food said: a reviewed broader record (the general chicken for drumsticks) may be offered, said to be
    // another record, and taken only on the person's tap. Otherwise nothing suitable: Find food.
    final sub = ([for (final c in broader) if (c.reviewed) c]..sort((a, b) => a.generic != b.generic ? (a.generic ? -1 : 1) : byOrigin(a, b))).firstOrNull;
    if (sub == null) return const Resolution(Outcome.none, reason: 'no record of this food');
    return Resolution(Outcome.clarify, estimate: sub, assumes: assumed(sub), substitute: true, reason: 'only a broader record');
  }
  final adequate = compatible.any((c) => c.reviewed && unproven(c).isEmpty && !brandUnproven(c));

  // Weighed, raw or cooked not said, and the records differ or say it: asked first, it decides what the weight means.
  if (stateMatters && state == null && compatible.any((c) => c.traits[Attr.state] != null && !_anyOf(c.traits[Attr.state]))) {
    return Resolution(Outcome.clarify, ask: Attr.state, unresolved: const [Attr.state], reason: 'raw or cooked not said', adequate: adequate);
  }

  final auto = [for (final c in compatible) if (c.reviewed && !c.generic && assumed(c).isEmpty && unproven(c).isEmpty && !brandUnproven(c)) c]..sort(byOrigin);
  if (auto.isNotEmpty) return Resolution(Outcome.resolved, chosen: auto.first, reason: 'every detail agrees', adequate: true);

  // A reviewed everyday default (docs/FOOD_DATA.md › Everyday defaults): a record the catalog marks `generic` — USDA's own
  // record for the food when details are not specified ("Potato, NFS", "Egg, whole, cooked, NS as to cooking method") —
  // taken without a question when it shows everything said and names nothing that was not; it is said to be general, and
  // Change food stays. Never a record only because it is the only one.
  List<Attr> named(Candidate<T> c) => [
        for (final a in Attr.values)
          if (a != Attr.family && said.value(a) == null && c.traits[a] != null && !_anyOf(c.traits[a]) && !c.traits[a]!.contains('none') && !(a == Attr.state && !stateMatters))
            a,
      ];
  final general = [for (final c in compatible) if (c.reviewed && c.generic && unproven(c).isEmpty && !brandUnproven(c) && named(c).isEmpty) c]..sort(byOrigin);
  if (general.isNotEmpty) return Resolution(Outcome.resolved, chosen: general.first, general: true, reason: 'a general record', adequate: true);

  // Choices, ranked by: what was said and the record shows (a record that cannot show a said detail comes after every one
  // that can), then the fewest details taken for granted or left unknown, then reviewed first, then source order. Only the
  // best rank is offered (a better record is never listed with worse ones), each set of material details once.
  int misses(Candidate<T> c) => unproven(c).length + (brandUnproven(c) ? 1 : 0);
  int extra(Candidate<T> c) => assumed(c).length + unknown(c);
  int rank(Candidate<T> a, Candidate<T> b) => misses(a) != misses(b) ? misses(a).compareTo(misses(b)) : extra(a) != extra(b) ? extra(a).compareTo(extra(b))
      : a.reviewed != b.reviewed ? (a.reviewed ? -1 : 1) : byOrigin(a, b);
  final specific = [for (final c in compatible) if (!c.generic) c];
  final ranked = [...(specific.isEmpty ? compatible : specific)]..sort(rank);
  final best = ranked.first;
  final options = <Candidate<T>>[], seen = <String>{};
  for (final c in ranked) {
    if (misses(c) != misses(best) || extra(c) != extra(best)) break;
    final key = [for (final a in [...asked, ...profile.defaultable]) '${a.name}=${(c.traits[a]?.toList()?..sort())?.join('/')}', ...unproven(c).map((a) => a.name)].join(';');
    if (seen.add(key)) options.add(c);
    if (options.length == maxOptions) break;
  }
  List<Attr> sorted(Iterable<Attr> s) => s.toSet().toList()..sort((a, b) => a.index.compareTo(b.index));

  // "I'm not sure": the reviewed record that takes least for granted, a record that says the details are not specified
  // first (USDA's general chicken rather than a guess at the skin), then one of this food. A general record that does not
  // show the part said is a substitute, and said to be one.
  final reviewed = [for (final c in [...compatible, ...broader]) if (c.reviewed) c]
    ..sort((a, b) => a.generic != b.generic ? (a.generic ? -1 : 1) : establishes(a) != establishes(b) ? (establishes(a) ? -1 : 1)
        : assumed(a).length != assumed(b).length ? assumed(a).length.compareTo(assumed(b).length) : byOrigin(a, b));
  final estimate = [for (final c in reviewed) if (c.generic || establishes(c)) c].firstOrNull;
  return Resolution(Outcome.clarify, options: options, unresolved: sorted([for (final c in options) ...assumed(c)]), unshown: sorted([for (final c in options) ...unproven(c)]),
      estimate: estimate, assumes: estimate == null ? const [] : assumed(estimate), substitute: estimate != null && !establishes(estimate),
      reason: options.length == 1 ? 'one record, not proven' : 'details not said', adequate: adequate);
}
