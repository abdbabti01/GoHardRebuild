import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle;

import '../../core/language.dart';
import '../../core/search_fold.dart';
import '../../core/units.dart' show formatNumber2;
import '../../data/models.dart';
import 'food_discovery.dart';
import 'food_item.dart';

/// Finding a food by what people call it: the bundled catalog of everyday foods, and one relevance rule shared by
/// the catalog, the owner's own foods and the wider database's answers. Nothing here touches the network or the
/// journal, and nothing here changes a food: names and aliases only decide what a search finds and in what order.

const _folded = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae', 'ß': 'ss',
};
final _kept = RegExp('[a-z0-9%ء-ي]');

/// Lower case, accents and ligatures folded ("Œufs" → "oeufs"), Arabic folded as [foldForSearch] does ("أرز" =
/// "ارز"), punctuation and repeated spaces removed.
String normalizeSearch(String text) {
  final out = StringBuffer();
  for (final rune in foldForSearch(text).runes) {
    final ch = String.fromCharCode(rune);
    out.write(_folded[ch] ?? (_kept.hasMatch(ch) ? ch : ' '));
  }
  return out.toString().trim().split(RegExp(r'\s+')).join(' ');
}

// ponytail: plain English/French plural endings only; a word list or stemmer if irregular plurals start to matter.
// ponytail: the Arabic article "ال" is dropped from a word of four letters or more, so "الأرز" finds "أرز"; a real
// stemmer if attached prefixes (و، ب، ل) start to matter.
String _singular(String w) {
  if (w.length > 3 && w.startsWith('ال')) return w.substring(2);
  if (w.length > 3 && w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
  if (w.length > 3 && RegExp(r'(ss|x|z|ch|sh|o)es$').hasMatch(w)) return w.substring(0, w.length - 2);
  if (w.length > 2 && w.endsWith('s') && !w.endsWith('ss')) return w.substring(0, w.length - 1);
  return w;
}

/// The words of `text` as a search compares them: normalized, each in its singular.
List<String> searchWords(String text) => [for (final w in normalizeSearch(text).split(' ')) if (w.isNotEmpty) _singular(w)];

/// What a food can be found by. Aliases are other names for the same food; they never stand for another one.
///
/// [names]: the food's own names in other languages (never broader than the food, unlike an alias may be). [qualifier]:
/// its preparation, one line per language, English first.
class SearchFields {
  const SearchFields(this.name, {this.aliases = const [], this.qualifier, this.brand, this.names = const []});
  final String name;
  final List<String> aliases, names;
  final String? qualifier, brand;
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------- how a food was prepared

/// Words that say how a plain food was kept or cooked, by their English word, in English, French and Arabic. A search
/// word and a food's word are the same when they mean the same ("cuite" is "cooked"); "cooked" also finds any way of
/// cooking ("roasted", "boiled"), "raw" finds "uncooked". Nothing else is ever treated as the same word.
final Map<String, String> _stateOf = {
  for (final e in const {
    'raw': 'raw', 'uncooked': 'raw', 'cru': 'raw', 'crue': 'raw', 'نيء': 'raw', 'نيئ': 'raw',
    'cooked': 'cooked', 'cuit': 'cooked', 'cuite': 'cooked', 'مطبوخ': 'cooked', 'مطهو': 'cooked',
    'boiled': 'boiled', 'bouilli': 'boiled', 'bouillie': 'boiled', 'مسلوق': 'boiled',
    'baked': 'baked', 'مخبوز': 'baked', 'roasted': 'roasted', 'rôti': 'roasted', 'rôtie': 'roasted', 'محمر': 'roasted', 'محمص': 'roasted',
    'grilled': 'grilled', 'grillé': 'grilled', 'grillée': 'grilled', 'مشوي': 'grilled', 'broiled': 'broiled',
    'steamed': 'steamed', 'poached': 'poached', 'poché': 'poached', 'stewed': 'stewed', 'braised': 'stewed', 'braisé': 'stewed',
    'fried': 'fried', 'frit': 'fried', 'frite': 'fried', 'مقلي': 'fried', 'sauteed': 'sauteed', 'sauté': 'sauteed', 'sautée': 'sauteed',
    'microwaved': 'microwaved',
  }.entries)
    for (final w in searchWords(e.key)) w: e.value,
};

/// Whether the search word [q] is the food's word [w], counting words of preparation that mean the same.
bool _covers(String q, String w) {
  if (q == w) return true;
  final sq = _stateOf[q], sw = _stateOf[w];
  if (sq == null || sw == null) return false;
  return sq == sw || sq == 'cooked' && sw != 'raw';
}

bool _found(String q, Iterable<String> words) => words.any((w) => _covers(q, w));

/// Raw or cooked, as the food's own words say ([fields]' name and preparation), or null when they say neither or both.
/// Used to ask "Weighed raw or cooked?" instead of assuming one: the weight of the same food differs once cooked.
String? foodState(SearchFields fields) {
  // The name and the preparation in its first (English) words: every language says the same.
  final words = [for (final p in [..._parts(fields.name), ..._parts((fields.qualifier ?? '').split('\n').first)]) ...p];
  final raw = words.any((w) => _stateOf[w] == 'raw'), cooked = words.any((w) => _stateOf[w] != null && _stateOf[w] != 'raw');
  return raw == cooked ? null : raw ? 'raw' : 'cooked';
}

// ---------------------------------------------------------------------------- relevance

/// Words that never make a food less relevant: small words, and words that describe a plain food rather than change it.
final _neutral = {
  for (final w in const [
    'and', 'or', 'with', 'of', 'in', 'the', 'from', 'as', 'to', 'a', 'an', 'by', 'for', 'eaten', 'ns', 'nfs', 'de', 'du', 'la', 'le', 'les', 'et', 'au', 'aux',
    'des', 'en', 'ou', 'avec', 'd', 'l', 'و', 'في', 'مع', 'من',
    'boneless', 'skinless', 'meat', 'only', 'lean', 'whole', 'plain', 'fresh', 'unsalted', 'unsweetened', 'broiler', 'fryer', 'drained', 'regular', 'dry',
    'dried', 'separable', 'trimmed', 'enriched', 'nature',
    // how fat a plain food is: the same food (a "milk" search is about milk whatever its fat)
    'skim', 'nonfat', 'lowfat', 'low', 'reduced', 'fat', 'free', 'part', 'extra', 'ecreme', 'partiellement', 'maigre',
  ])
    ...searchWords(w),
};

/// "2%", "90%": how fat a food is, said as a share.
bool _share(String w) => RegExp(r'^\d+%$').hasMatch(w);

/// Words that say something was added to a food or that it was made into another product. A food named so is less
/// likely to be the plain food searched for, unless the search names that word too.
final _added = {
  for (final w in const [
    'breaded', 'battered', 'batter', 'coated', 'coating', 'sauce', 'gravy', 'glazed', 'honey', 'sweetened', 'candied', 'creamed', 'stuffed', 'marinade',
    'marinated', 'seasoned', 'flavor', 'flavored', 'flavour', 'bbq', 'barbecue', 'deli', 'lunchmeat', 'nugget', 'tender', 'sandwich', 'salad', 'soup',
    'frozen', 'fast', 'restaurant', 'prepackaged', 'dinner', 'entree', 'casserole', 'snack', 'cracker', 'chip', 'fried', 'pane', 'panee',
  ])
    ...searchWords(w),
};

/// Words that say the next word is not there: "without sauce", "sans peau", "non cuit", "غير مطبوخ", "بدون جلد".
final _negations = {for (final w in const ['without', 'no', 'not', 'sans', 'non', 'غير', 'بدون']) ...searchWords(w)};

/// A label's words, by part (a provider title's comma-separated parts), with what is said not to be there taken out:
/// "skin not eaten" is a skinless food, "without sauce" and "no added fat" add nothing.
List<List<String>> _parts(String label) {
  final parts = <List<String>>[];
  for (final segment in label.split(RegExp('[,()/;·\n]'))) {
    final words = searchWords(segment), kept = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w == 'not' && i + 1 < words.length && words[i + 1] == 'eaten') {
        if (kept.isNotEmpty) kept.removeLast();
        i++;
      } else if (w == 'from' && i + 1 < words.length) {
        i++; // "from raw", "from dried": what it was made from, not what it is
      } else if (_negations.contains(w)) {
        i += i + 1 < words.length && words[i + 1] == 'added' ? 2 : 1;
      } else {
        kept.add(w);
      }
    }
    if (kept.isNotEmpty) parts.add(kept);
  }
  return parts;
}

/// How much more a label says than the search asked for: nothing for small and plain words, 3 for something added or
/// a product made from the food ("breaded", "deli"), 2 for another word in the part of the title the search names
/// ("rice *noodles*", "chicken breast *tenders*"), 1 for anything else. The last search word may still be being typed.
int _extra(List<String> q, String label, String? qualifier, {bool typing = false}) {
  // A general "cooked" asks for no fat: a sauteed or fried record still says more than was asked.
  bool asked(String w) => q.any((t) => _covers(t, w) && !(_stateOf[t] == 'cooked' && const {'fried', 'sauteed'}.contains(_stateOf[w]))) || typing && w.startsWith(q.last);
  int weight(String w, {bool head = false}) => asked(w) || _neutral.contains(w) || _share(w) || _stateOf[w] != null && !_added.contains(w) && _stateOf[w] != 'sauteed'
      ? 0
      : _added.contains(w) ? 3 : head ? 2 : 1;
  final parts = _parts(label);
  final head = parts.indexWhere((p) => p.any(asked));
  var extra = 0;
  for (final (i, p) in parts.indexed) {
    for (final w in p) {
      // The part the search names, and a provider title's first part (it names the food: "Yogurt, …, milk" is yogurt).
      extra += weight(w, head: i == head || i == 0);
    }
  }
  // The preparation in the language that says least beyond the search (each language says the same thing).
  int? least;
  for (final line in (qualifier ?? '').split('\n')) {
    var e = 0;
    for (final p in _parts(line)) {
      for (final w in p) {
        e += weight(w);
      }
    }
    if (least == null || e < least) least = e;
  }
  return extra + (least ?? 0);
}

/// How well a search names a food: [tier] first, then [penalty] (how much more specific the food is than what was
/// asked). Lower is better in both.
typedef Relevance = ({int tier, int penalty});

int compareRelevance(Relevance a, Relevance b) => a.tier != b.tier ? a.tier.compareTo(b.tier) : a.penalty.compareTo(b.penalty);

/// How well `query` names a food, or null when it does not. Every word of the query has to be found.
///
/// Tiers: 0 the name or an alias, exactly · 1 a branded product whose brand the search names, every other word found ·
/// 2 every word, whole, among name, aliases, preparation and brand · 3 the same with the last word still being typed ·
/// 4 every word as the beginning of a word · 5 inside words (3 letters or more). Words of preparation that mean the
/// same are the same word ("cooked" finds "roasted", "cuite" finds "cooked").
///
/// Not exact: an alias that is only part of another of the food's names ("chicken" for a food also called "chicken
/// breast") names something broader, so "chicken" never stands for breast exactly; and a branded product when the
/// search names no brand, which also counts as a little more specific. An empty query matches everything equally.
Relevance? relevance(String query, SearchFields f) {
  final q = searchWords(query);
  if (q.isEmpty) return (tier: 0, penalty: 0);
  final texts = [f.name, ...f.names, ...f.aliases];
  final labels = [for (final t in texts) searchWords(t)];
  final sets = [for (final l in labels) l.toSet()];
  bool broader(int i) => i > f.names.length && sets.indexed.any((o) => o.$1 != i && o.$2.length > sets[i].length && o.$2.containsAll(sets[i]));
  final brandWords = {for (final part in (f.brand ?? '').split(',')) ...searchWords(part)};
  final branded = brandWords.isNotEmpty, brandAsked = branded && q.any(brandWords.contains);
  final unasked = branded && !brandAsked ? 2 : 0;
  // What the food is found by: its words as _parts reads them ("from raw" is not raw, "without sauce" has no sauce).
  Set<String> read(String text) => {for (final p in _parts(text)) ...p};
  final said = [for (final t in texts) read(t)], prepared = read(f.qualifier ?? '');
  final words = {for (final w in said) ...w, ...brandWords, ...prepared};

  int penalty({bool typing = false}) {
    // The label that covers the search best (a French search is measured against the French name, and so on).
    var best = -1;
    for (final (i, own) in [for (final w in said) {...w, ...brandWords, ...prepared}].indexed) {
      if (!q.take(typing ? q.length - 1 : q.length).every((t) => _found(t, own))) continue;
      final e = _extra(q, texts[i], f.qualifier, typing: typing);
      if (best < 0 || e < best) best = e;
    }
    return (best < 0 ? _extra(q, f.name, f.qualifier, typing: typing) : best) + unasked;
  }

  if (labels.indexed.any((l) => !broader(l.$1) && _same(l.$2, q))) return unasked == 0 ? (tier: 0, penalty: 0) : (tier: 2, penalty: unasked);
  if (brandAsked && q.every((t) => _found(t, words))) return (tier: 1, penalty: penalty());
  if (q.every((t) => _found(t, words))) return (tier: 2, penalty: penalty());
  if (q.take(q.length - 1).every((t) => _found(t, words)) && words.any((w) => w.startsWith(q.last))) return (tier: 3, penalty: penalty(typing: true));
  if (q.every((t) => words.any((w) => w.startsWith(t)))) return (tier: 4, penalty: unasked);
  if (q.every((t) => t.length >= 3 && words.any((w) => w.contains(t)))) return (tier: 5, penalty: unasked);
  return null;
}

/// [relevance]'s tier alone (lower is better), for callers that only need how a food was found.
int? matchScore(String query, SearchFields f) => relevance(query, f)?.tier;

/// The better of how [query] and, when given, [also] (the same search in other words: corrected or in English) name a food.
Relevance? _bestOf(String query, String? also, SearchFields f) {
  final a = relevance(query, f), b = also == null ? null : relevance(also, f);
  return a == null ? b : b == null || compareRelevance(a, b) <= 0 ? a : b;
}

/// `items` that match `query` (or [also]), best first; equally good ones keep the order they came in. With
/// [keepUnmatched] the rest follow in their own order, except those sharing no word at all with the search (a
/// provider's answer to "poitrine de poulet" that only matched "de").
List<T> rankByRelevance<T>(String query, Iterable<T> items, SearchFields Function(T) fields, {bool keepUnmatched = false, String? also}) {
  final scored = <(Relevance, int, T)>[], rest = <T>[];
  final content = {for (final w in [...searchWords(query), ...searchWords(also ?? '')]) if (!_neutral.contains(w)) w};
  for (final (i, item) in items.indexed) {
    final f = fields(item);
    final score = _bestOf(query, also, f);
    if (score != null) {
      scored.add((score, i, item));
    } else if (keepUnmatched) {
      final words = {...searchWords(f.name), for (final a in f.aliases) ...searchWords(a), ...searchWords(f.brand ?? ''), ...searchWords(f.qualifier ?? '')};
      if (content.isEmpty || content.any((t) => _found(t, words))) rest.add(item);
    }
  }
  scored.sort((a, b) => compareRelevance(a.$1, b.$1) != 0 ? compareRelevance(a.$1, b.$1) : a.$2.compareTo(b.$2));
  return [for (final s in scored) s.$3, ...rest];
}

// ---------------------------------------------------------------------------- what a search is taken to mean

/// Everyday food words in French and Arabic with the English words an English-only database knows them by. Only for
/// asking the wider database (USDA is in English); the bundled foods carry their own French and Arabic names.
// ponytail: a short word list of staples; a real translation service if people search the wider database in other languages a lot.
const _english = <String, String>{
  'poulet': 'chicken', 'دجاج': 'chicken', 'فراخ': 'chicken', 'boeuf': 'beef', 'bœuf': 'beef', 'لحم بقري': 'beef', 'porc': 'pork', 'dinde': 'turkey',
  'ديك رومي': 'turkey', 'agneau': 'lamb', 'لحم ضأن': 'lamb', 'خروف': 'lamb', 'poisson': 'fish', 'سمك': 'fish', 'saumon': 'salmon', 'سلمون': 'salmon',
  'thon': 'tuna', 'تونة': 'tuna', 'crevette': 'shrimp', 'جمبري': 'shrimp', 'jambon': 'ham', 'saucisse': 'sausage', 'نقانق': 'sausage', 'oeuf': 'egg',
  'بيض': 'egg', 'بيضة': 'egg', 'poitrine': 'breast', 'صدر': 'breast', 'cuisse': 'thigh', 'فخذ': 'thigh', 'haché': 'ground', 'مفروم': 'ground',
  'riz': 'rice', 'أرز': 'rice', 'رز': 'rice', 'pomme de terre': 'potato', 'patate': 'potato', 'بطاطس': 'potato', 'بطاطا': 'potato', 'pain': 'bread',
  'خبز': 'bread', 'pâtes': 'pasta', 'pâte': 'pasta', 'معكرونة': 'pasta', 'مكرونة': 'pasta', 'avoine': 'oats', 'شوفان': 'oats', 'maïs': 'corn', 'ذرة': 'corn',
  'lait': 'milk', 'حليب': 'milk', 'fromage': 'cheese', 'جبن': 'cheese', 'جبنة': 'cheese', 'yogourt': 'yogurt', 'yaourt': 'yogurt', 'زبادي': 'yogurt',
  'beurre': 'butter', 'زبدة': 'butter', 'huile': 'oil', 'زيت': 'oil', "huile d'olive": 'olive oil', 'زيت زيتون': 'olive oil', 'olive': 'olive',
  'pomme': 'apple', 'تفاح': 'apple', 'banane': 'banana', 'موز': 'banana', 'برتقال': 'orange', 'fraise': 'strawberry', 'فراولة': 'strawberry',
  'raisin': 'grape', 'عنب': 'grape', 'avocat': 'avocado', 'أفوكادو': 'avocado', 'carotte': 'carrot', 'جزر': 'carrot', 'tomate': 'tomato', 'طماطم': 'tomato',
  'oignon': 'onion', 'بصل': 'onion', 'laitue': 'lettuce', 'خس': 'lettuce', 'épinard': 'spinach', 'سبانخ': 'spinach', 'champignon': 'mushroom', 'فطر': 'mushroom',
  'poivron': 'pepper', 'فلفل': 'pepper', 'concombre': 'cucumber', 'خيار': 'cucumber', 'haricot': 'bean', 'فاصوليا': 'bean', 'lentille': 'lentil', 'عدس': 'lentil',
  'pois chiche': 'chickpea', 'حمص': 'chickpea', 'amande': 'almond', 'لوز': 'almond', 'noix': 'walnut', 'sucre': 'sugar', 'سكر': 'sugar', 'miel': 'honey',
  'عسل': 'honey', 'chocolat': 'chocolate', 'شوكولاتة': 'chocolate', 'café': 'coffee', 'قهوة': 'coffee', 'thé': 'tea', 'شاي': 'tea', 'jus': 'juice',
  'عصير': 'juice', 'eau': 'water', 'ماء': 'water', 'soupe': 'soup', 'شوربة': 'soup', 'salade': 'salad', 'سلطة': 'salad', 'sauce': 'sauce',
  'cru': 'raw', 'crue': 'raw', 'نيء': 'raw', 'cuit': 'cooked', 'cuite': 'cooked', 'مطبوخ': 'cooked', 'bouilli': 'boiled', 'مسلوق': 'boiled', 'grillé': 'grilled',
  'مشوي': 'grilled', 'rôti': 'roasted', 'frit': 'fried', 'مقلي': 'fried', 'au four': 'baked', 'مخبوز': 'baked', 'sans peau': 'skinless', 'بدون جلد': 'skinless',
};

final Map<String, String> _englishWords = {for (final e in _english.entries) searchWords(e.key).join(' '): e.value};

/// [query] in English words for the wider database, or null when nothing in it was French or Arabic: known phrases and
/// words translated (the longest first), small words dropped ("poitrine de poulet cuite" → "breast chicken cooked").
/// Words it does not know are kept as typed.
String? englishQuery(String query) {
  final w = searchWords(query), out = <String>[];
  var changed = false;
  for (var i = 0; i < w.length;) {
    var taken = 0;
    for (var n = 3; n >= 1 && taken == 0; n--) {
      if (i + n > w.length) continue;
      final english = _englishWords[w.sublist(i, i + n).join(' ')];
      if (english != null) {
        out.add(english);
        taken = n;
      }
    }
    if (taken > 0) {
      changed = true;
      i += taken;
    } else {
      if (const {'de', 'du', 'des', 'la', 'le', 'les', 'au', 'aux', 'd', 'l', 'a', 'et', 'en'}.contains(w[i])) {
        changed = true;
      } else {
        out.add(w[i]);
      }
      i++;
    }
  }
  return changed && out.isNotEmpty ? out.join(' ') : null;
}

/// Edits between two words (insert, delete, change, or swap two neighbours), stopping early beyond [max].
int _distance(String a, String b, int max) {
  if ((a.length - b.length).abs() > max) return max + 1;
  var prev2 = <int>[], prev = [for (var j = 0; j <= b.length; j++) j];
  for (var i = 1; i <= a.length; i++) {
    final row = [i, ...List.filled(b.length, 0)];
    var low = row[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var v = [prev[j] + 1, row[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] && prev2[j - 2] + 1 < v) v = prev2[j - 2] + 1;
      row[j] = v;
      if (v < low) low = v;
    }
    if (low > max) return max + 1;
    prev2 = prev;
    prev = row;
  }
  return prev[b.length];
}

/// [query] with a misspelt word replaced by the closest word [vocabulary] knows ("chiken brest" → "chicken breast"), or
/// null when every word is known, is the start of a known word, or has no close match. One edit for words of 4 to 6
/// letters, two from 7; shorter words are never changed.
String? correctSpelling(String query, Set<String> vocabulary) {
  final words = searchWords(query);
  var changed = false;
  final out = [
    for (final w in words)
      () {
        if (w.length < 4 || vocabulary.contains(w) || _stateOf.containsKey(w) || vocabulary.any((v) => v.startsWith(w))) return w;
        final max = w.length >= 7 ? 2 : 1;
        String? best;
        var bestD = max + 1;
        for (final v in vocabulary) {
          if (v.length < 3) continue;
          final d = _distance(w, v, max);
          if (d < bestD || d == bestD && best != null && (v.length - w.length).abs() < (best.length - w.length).abs()) {
            best = v;
            bestD = d;
          }
        }
        if (best == null) return w;
        changed = true;
        return best;
      }(),
  ];
  return changed ? out.join(' ') : null;
}

/// A typed search as the app takes it: [corrected] spelling (null when nothing was corrected) and the words the
/// English-only wider database is asked for ([remote]).
typedef SearchQuery = ({String typed, String? corrected, String remote});

SearchQuery interpretQuery(String typed, CommonFoodCatalog catalog) {
  final corrected = correctSpelling(typed, catalog.vocabulary);
  final base = corrected ?? typed.trim();
  return (typed: typed.trim(), corrected: corrected, remote: englishQuery(base) ?? base);
}

/// [items] without repeats: the same product listed again under another ID (the same name, brand, basis, values and
/// portions) once, the first time. Different preparations, values or portions are never merged.
List<FoodItem> withoutRepeats(List<FoodItem> items) {
  final seen = <String>{};
  return [
    for (final i in items)
      if (seen.add([normalizeSearch(i.name), normalizeSearch(i.brand ?? ''), i.basis, for (final k in FoodItem.nutrientKeys) i.nutrient(k),
          for (final s in i.servings) '${s.label}:${s.grams}:${s.milliliters}'].join('|')))
        i,
  ];
}

/// A catalog food's everyday name, preparation, start portion and other names in one language. Words only: the
/// food and its values are the main file's.
typedef FoodWords = ({String name, String qualifier, String? portion, List<String> aliases});

/// One everyday food of the bundled catalog: a provider record ([item], untouched) with the name people use for
/// it, its preparation, a category, and other names it is searched by.
class CommonFood {
  CommonFood(Json j, [Json? words])
      : id = j['id'] as String,
        name = j['name'] as String,
        qualifier = j['qualifier'] as String,
        category = j['category'] as String,
        aliases = [for (final a in j['aliases'] as List? ?? const []) a as String],
        portion = j['portion'] as String?,
        attrs = j['attrs'] is Map ? Map<String, dynamic>.from(j['attrs'] as Map) : const {},
        item = FoodItem(j['item'] as Json),
        words = {
          for (final e in (words ?? const <String, dynamic>{}).entries)
            if (e.value case final Map w)
              e.key: (name: w['name'] as String, qualifier: w['qualifier'] as String, portion: w['portion'] as String?, aliases: [for (final a in w['aliases'] as List? ?? const []) a as String]),
        };

  final String id, name, qualifier, category;
  final List<String> aliases;

  /// The label of the source-stated portion a new entry starts from ("1 egg"), or null to start at 100 g.
  final String? portion;

  /// The record's reviewed details (family, cut, raw or cooked, method, skin, fat…; docs/FOOD_DATA.md › Food resolution):
  /// GoHard's labels for matching a description, never USDA data. Empty when nothing was reviewed.
  final Map<String, dynamic> attrs;
  final FoodItem item;

  /// The food's words by language code ("fr", "ar"), from `common-foods.l10n.json`. English is the main file's.
  final Map<String, FoodWords> words;

  String nameIn(String lang) => words[lang]?.name ?? name;
  String qualifierIn(String lang) => words[lang]?.qualifier ?? qualifier;

  /// [portion] as it reads in `lang`; [portion] itself stays what the unit is found by.
  String? portionIn(String lang) => portion == null ? null : words[lang]?.portion ?? portion;

  /// The provider's own title is one more name the food answers to, and so are its names in every language: a
  /// French or Arabic name finds this same food whatever language the app is in.
  SearchFields get fields => SearchFields(name, names: [for (final w in words.values) w.name],
      aliases: [...aliases, item.name, for (final w in words.values) ...w.aliases], qualifier: [qualifier, for (final w in words.values) w.qualifier].join('\n'));

  /// The unit a new entry starts in: [portion] when the record states it, otherwise the food's own measure.
  String get unitId {
    final index = portion == null ? -1 : item.servings.indexWhere((s) => s.label == portion);
    return FoodScaling.unit(item, index < 0 ? null : 'serving:$index').id;
  }
}

/// The versioned catalog bundled with the app (`assets/data/common-foods.json`), so everyday foods are found
/// with no connection. A catalog food and the same record met in a wider search are one food: same [FoodItem.key].
class CommonFoodCatalog {
  CommonFoodCatalog({required this.version, required this.provenance, required this.categories, required this.foods}) : _byKey = {for (final f in foods) f.item.key: f};
  /// With [overlay] (`assets/data/common-foods.l10n.json`) each food also gets its French and Arabic words, by id.
  factory CommonFoodCatalog.parse(String source, {String? overlay}) {
    final j = jsonDecode(source) as Json;
    final words = overlay == null ? const <String, dynamic>{} : (jsonDecode(overlay) as Json)['foods'] as Json;
    return CommonFoodCatalog(
      version: j['version'] as int, provenance: j['provenance'] as Json,
      categories: [for (final c in j['categories'] as List) c as String],
      foods: [for (final f in (j['foods'] as List).cast<Json>()) CommonFood(f, words[f['id']] as Json?)]);
  }
  static final empty = CommonFoodCatalog(version: 0, provenance: const {}, categories: const [], foods: const []);

  /// Every word the app knows a food by (each food's names, preparations and aliases in every language, and the
  /// translated staples): what a misspelt search word is corrected to.
  late final Set<String> vocabulary = {
    for (final f in foods) ...[for (final l in [f.fields.name, ...f.fields.aliases, f.fields.qualifier ?? '']) ...searchWords(l)],
    for (final e in _englishWords.entries) ...[...e.key.split(' '), ...searchWords(e.value)],
    ..._stateOf.keys,
  }..removeWhere((w) => w.length < 3 || RegExp(r'\d').hasMatch(w));

  final int version;
  final Json provenance;
  final List<String> categories;
  final List<CommonFood> foods;
  final Map<String, CommonFood> _byKey;

  /// The catalog entry for exactly this record, by source identity. Never by a similar name.
  CommonFood? of(FoodItem item) => _byKey[item.key];
}

/// The bundled catalog with its French and Arabic words, read from `bundle` (the app's `rootBundle`).
Future<CommonFoodCatalog> loadCommonFoods(AssetBundle bundle) async {
  Future<String> read(String path) async => utf8.decode(Uint8List.sublistView(await bundle.load(path)));
  return CommonFoodCatalog.parse(await read('assets/data/common-foods.json'), overlay: await read('assets/data/common-foods.l10n.json'));
}

/// A catalog category's name from its stored id ("Fats & Oils"); [short] is the chip's ("Carbs").
String foodCategoryLabel(AppLocalizations l, String id, {bool short = false}) => switch (id) {
      'Proteins' => l.foodCategoryProteins,
      'Carbohydrates' => short ? l.foodCategoryCarbsShort : l.foodCategoryCarbohydrates,
      'Vegetables' => l.foodCategoryVegetables,
      'Fruits' => l.foodCategoryFruits,
      'Dairy' => l.foodCategoryDairy,
      'Fats & Oils' => l.foodCategoryFatsOils,
      'Snacks' => l.foodCategorySnacks,
      'Beverages' => l.foodCategoryBeverages,
      _ => id,
    };

/// The language code [CommonFood.words] are kept under: "en", "fr", "ar".
String foodLang(AppLocalizations l) => l.localeName.split('_').first;

SearchFields _fieldsOf(Suggestion s) => s.common?.fields ?? SearchFields(s.item.name, brand: s.item.brand);

/// What the phone can answer by itself for `query`: the owner's foods (favourites, their own, logged before, seen
/// before) and the catalog's, each best match first. A food the owner already has is listed once, among theirs.
/// With a `category`, only foods the catalog classifies in it are returned: nothing unclassified slips through.
/// [also]: the same search in other words (its spelling corrected, or in English for foods kept in English).
({List<Suggestion> own, List<Suggestion> common}) searchLocal(String query,
    {required CommonFoodCatalog catalog, required List<Json> saved, required List<FoodEntry> journal, required List<FoodItem> seen, String? category, String? also}) {
  final own = [
    for (final s in localSuggestions(saved: saved, journal: journal, seen: seen))
      Suggestion(s.item, s.origin, saved: s.saved, entry: s.entry, common: catalog.of(s.item)),
  ];
  final have = {for (final s in own) if (s.common != null) s.item.key};
  final common = [for (final f in catalog.foods) if (!have.contains(f.item.key)) Suggestion(f.item, Origin.common, common: f)];
  bool inCategory(Suggestion s) => category == null || s.common?.category == category;
  // With nothing typed, only the catalog is browsed (by category); the owner's foods have their own lists.
  return (
    own: query.trim().isEmpty && category == null ? const [] : rankByRelevance(query, own.where(inCategory), _fieldsOf, also: also),
    common: rankByRelevance(query, common.where(inCategory), _fieldsOf, also: also),
  );
}

/// The wider database's answer in the app's order (plain foods before derivatives and snacks; with a brand named, that
/// brand's products first), without the foods already listed from the phone or repeats of one product, each joined to
/// its catalog entry when it is that very record. [also]: the words the database was asked for, when they differ.
List<Suggestion> rankFound(String query, List<FoodItem> found, {required CommonFoodCatalog catalog, Set<String> shown = const {}, String? also}) => rankByRelevance(
    query, [for (final i in withoutRepeats(found)) if (!shown.contains(i.key)) Suggestion(i, Origin.found, common: catalog.of(i))], _fieldsOf,
    keepUnmatched: true, also: also);

/// A product name the source wrote in capitals ("CHICKEN BREAST") as a sentence ("Chicken breast"), for reading only:
/// the record keeps the source's own name. Any other name is shown as it is.
String readableName(String name, {bool everyWord = false}) {
  if (name != name.toUpperCase() || !RegExp('[A-Z]').hasMatch(name)) return name;
  String cap(String w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);
  final lower = name.toLowerCase();
  return everyWord ? lower.split(' ').map(cap).join(' ') : cap(lower);
}

/// What one row says about a food: its name, what tells it apart, and the values for a stated amount.
class RowFacts {
  const RowFacts({required this.title, this.detail, required this.basis, this.calories, this.protein});
  final String title, basis;
  final String? detail;

  /// For [basis]. Null is unknown and is shown as a dash, never as zero.
  final double? calories, protein;
}

/// In `l`'s language (the app's when not given): a catalog food by its everyday name there; any other food, and
/// whatever was logged, as stored.
RowFacts rowFacts(Suggestion s, [AppLocalizations? l]) {
  l ??= currentL10n;
  final lang = foodLang(l);
  final e = s.entry, item = s.item, common = s.common;
  final title = common?.nameIn(lang) ?? readableName(item.name);
  final tag = switch (s.origin) { Origin.favourite => l.foodTagFavourite, Origin.mine => l.foodTagMine, Origin.recent => l.foodTagRecent, _ => null };
  // What it is: a product of a brand, or a generic food of the database (never left for the reader to guess).
  final brand = item.brand?.trim();
  final kind = common?.qualifierIn(lang) ??
      (brand != null && brand.isNotEmpty ? l.foodTagBrand(readableName(brand, everyWord: true)) : item.source == 'usda' && e == null ? l.foodTagGeneric : null);
  final about = [?tag, ?kind].join(' · ');
  // A food logged before is offered as it was logged: that amount, those values.
  if (e != null) return RowFacts(title: title, detail: e.source == null ? l.foodAsYouLoggedIt : about, basis: e.amountDescription, calories: e.calories, protein: e.protein);
  final (quantity, unit) = startAmount(item, common);
  final values = FoodScaling.scale(item, quantity, unit);
  return RowFacts(title: title, detail: about.isEmpty ? null : about, basis: describeAmount(item, quantity, unit, common, lang), calories: values['calories'], protein: values['protein']);
}

/// [FoodScaling.describe], with a catalog food's start portion said in `lang` ("1 poitrine moyenne (120 g)"). Other
/// units keep their source's label; the amount and its weight are the same in every language.
String describeAmount(FoodItem item, double quantity, FoodUnit unit, CommonFood? common, String lang) {
  final local = common == null || unit.label != common.portion ? null : common.portionIn(lang);
  if (local == null || local == unit.label) return FoodScaling.describe(item, quantity, unit);
  final text = quantity == 1 ? local : '${formatNumber2(quantity)} × $local', weighed = FoodScaling.measured(item, quantity, unit);
  return weighed == null ? text : '$text ($weighed)';
}

/// The stated amount a row gives a food's values for: the catalog's chosen portion ("1 egg"), which is also
/// where a new entry of that food starts; otherwise the basis the values are given on: 100 g, 100 ml, one serving.
(double, FoodUnit) startAmount(FoodItem item, CommonFood? common) {
  final unit = FoodScaling.unit(item, common?.unitId);
  return (unit.id.startsWith('serving') ? 1 : 100, unit);
}
