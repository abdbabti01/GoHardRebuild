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
  const Candidate(this.record, this.traits, {required this.origin, this.order = 0, this.generic = false, this.brand});
  final T record;
  final Traits traits;
  final Found origin;

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
  const Said(this.traits, {this.confirmed = const {}, this.weighed = false, this.counted = false, this.brand});
  final Traits traits;
  final Map<Attr, String> confirmed;

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
/// [unresolved]: the material details not said that set them apart. [estimate]: a reviewed record to offer as "I'm not
/// sure", with what it would assume ([assumes]). [ask]: a detail to ask before choosing (raw or cooked, for a weighed food).
class Resolution<T> {
  const Resolution(this.outcome,
      {this.chosen, this.options = const [], this.unresolved = const [], this.estimate, this.assumes = const [], this.ask, this.reason = '', this.general = false, this.adequate = false});
  final Outcome outcome;

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

/// The most choices offered at once; the rest are found with "Search for another".
const maxOptions = 5;

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
    return false;
  }

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
  final adequate = compatible.any((c) => c.reviewed && unproven(c).isEmpty && !brandUnproven(c));

  // Weighed, raw or cooked not said, and the records differ or say it: asked first, it decides what the weight means.
  if (stateMatters && state == null && compatible.any((c) => c.traits[Attr.state] != null && !_anyOf(c.traits[Attr.state]))) {
    return Resolution(Outcome.clarify, ask: Attr.state, unresolved: const [Attr.state], reason: 'raw or cooked not said', adequate: adequate);
  }

  int byOrigin(Candidate<T> a, Candidate<T> b) => a.origin.index != b.origin.index ? a.origin.index.compareTo(b.origin.index) : a.order.compareTo(b.order);
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

  // Choices: the records that take the least for granted, reviewed first; equivalent ones (the same material details) once.
  int cost(Candidate<T> c) => assumed(c).length + unknown(c) + unproven(c).length + (brandUnproven(c) ? 1 : 0);
  final specific = [for (final c in compatible) if (!c.generic) c];
  final pool = specific.isEmpty ? compatible : specific;
  final least = pool.map(cost).reduce((a, b) => a < b ? a : b);
  final ranked = [for (final c in pool) if (cost(c) == least || !c.reviewed) c]
    ..sort((a, b) => a.reviewed != b.reviewed ? (a.reviewed ? -1 : 1) : cost(a) != cost(b) ? cost(a).compareTo(cost(b)) : byOrigin(a, b));
  final options = <Candidate<T>>[], seen = <String>{};
  for (final c in ranked) {
    final key = c.reviewed ? [for (final a in [...asked, ...profile.defaultable]) '${a.name}=${(c.traits[a]?.toList()?..sort())?.join('/')}'].join(';') : 'x${options.length}';
    if (seen.add(key)) options.add(c);
    if (options.length == maxOptions) break;
  }
  final unresolved = {for (final c in options) ...assumed(c), for (final c in options) ...unproven(c)}.toList()..sort((a, b) => a.index.compareTo(b.index));

  // "I'm not sure": the reviewed record that takes least for granted, a record that says the details are not specified first.
  final reviewed = [for (final c in compatible) if (c.reviewed) c]
    ..sort((a, b) => a.generic != b.generic ? (a.generic ? -1 : 1) : assumed(a).length != assumed(b).length ? assumed(a).length.compareTo(assumed(b).length) : byOrigin(a, b));
  final estimate = reviewed.firstOrNull;
  return Resolution(Outcome.clarify, options: options, unresolved: unresolved, estimate: estimate,
      assumes: estimate == null ? const [] : assumed(estimate), reason: options.length == 1 ? 'one record, not proven' : 'details not said', adequate: adequate);
}
