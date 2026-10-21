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
class SearchFields {
  const SearchFields(this.name, {this.aliases = const [], this.qualifier, this.brand});
  final String name;
  final List<String> aliases;
  final String? qualifier, brand;
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// How well `query` names a food. Lower is better; null is no match. Every word of the query has to be found.
///
/// 0 the name or an alias, exactly · 1 the head of a provider title ("Rice, white, cooked" for "rice") or the
/// brand, exactly · 2 a name, alias or brand that starts with it (the last word may still be being typed) ·
/// 3 all its words, whole, among name, aliases, preparation and brand · 4 as the beginnings of words ·
/// 5 inside words. An empty query matches everything equally.
int? matchScore(String query, SearchFields f) {
  final q = searchWords(query);
  if (q.isEmpty) return 0;
  final labels = [searchWords(f.name), for (final a in f.aliases) searchWords(a)];
  if (labels.any((l) => _same(l, q))) return 0;
  final brands = [for (final part in (f.brand ?? '').split(',')) searchWords(part)]..removeWhere((b) => b.isEmpty);
  if (_same(searchWords(f.name.split(RegExp(r'[,(]')).first), q) || brands.any((b) => _same(b, q))) return 1;
  bool startsWith(List<String> l) {
    if (l.length < q.length) return false;
    for (var i = 0; i < q.length - 1; i++) {
      if (l[i] != q[i]) return false;
    }
    return l[q.length - 1].startsWith(q.last);
  }

  if (labels.any(startsWith) || brands.any(startsWith)) return 2;
  final words = {for (final l in labels) ...l, for (final b in brands) ...b, ...searchWords(f.qualifier ?? '')};
  if (q.every(words.contains)) return 3;
  if (q.every((t) => words.any((w) => w.startsWith(t)))) return 4;
  if (q.every((t) => t.length >= 3 && words.any((w) => w.contains(t)))) return 5;
  return null;
}

/// `items` that match `query`, best first; equally good ones keep the order they came in. With [keepUnmatched]
/// the rest follow in their own order: a provider's answer is re-ordered, never thinned.
List<T> rankByRelevance<T>(String query, Iterable<T> items, SearchFields Function(T) fields, {bool keepUnmatched = false}) {
  final scored = <(int, int, T)>[], rest = <T>[];
  for (final (i, item) in items.indexed) {
    final score = matchScore(query, fields(item));
    score == null ? rest.add(item) : scored.add((score, i, item));
  }
  scored.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return [for (final s in scored) s.$3, if (keepUnmatched) ...rest];
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
  final FoodItem item;

  /// The food's words by language code ("fr", "ar"), from `common-foods.l10n.json`. English is the main file's.
  final Map<String, FoodWords> words;

  String nameIn(String lang) => words[lang]?.name ?? name;
  String qualifierIn(String lang) => words[lang]?.qualifier ?? qualifier;

  /// [portion] as it reads in `lang`; [portion] itself stays what the unit is found by.
  String? portionIn(String lang) => portion == null ? null : words[lang]?.portion ?? portion;

  /// The provider's own title is one more name the food answers to, and so are its names in every language: a
  /// French or Arabic name finds this same food whatever language the app is in.
  SearchFields get fields => SearchFields(name,
      aliases: [...aliases, item.name, for (final w in words.values) ...[w.name, ...w.aliases]], qualifier: [qualifier, for (final w in words.values) w.qualifier].join(' '));

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
({List<Suggestion> own, List<Suggestion> common}) searchLocal(String query,
    {required CommonFoodCatalog catalog, required List<Json> saved, required List<FoodEntry> journal, required List<FoodItem> seen, String? category}) {
  final own = [
    for (final s in localSuggestions(saved: saved, journal: journal, seen: seen))
      Suggestion(s.item, s.origin, saved: s.saved, entry: s.entry, common: catalog.of(s.item)),
  ];
  final have = {for (final s in own) if (s.common != null) s.item.key};
  final common = [for (final f in catalog.foods) if (!have.contains(f.item.key)) Suggestion(f.item, Origin.common, common: f)];
  bool inCategory(Suggestion s) => category == null || s.common?.category == category;
  // With nothing typed, only the catalog is browsed (by category); the owner's foods have their own lists.
  return (
    own: query.trim().isEmpty && category == null ? const [] : rankByRelevance(query, own.where(inCategory), _fieldsOf),
    common: rankByRelevance(query, common.where(inCategory), _fieldsOf),
  );
}

/// The wider database's answer in the app's order (plain foods before derivatives and snacks), without the
/// foods already listed from the phone, each joined to its catalog entry when it is that very record.
List<Suggestion> rankFound(String query, List<FoodItem> found, {required CommonFoodCatalog catalog, Set<String> shown = const {}}) => rankByRelevance(
    query, [for (final i in found) if (!shown.contains(i.key)) Suggestion(i, Origin.found, common: catalog.of(i))], _fieldsOf, keepUnmatched: true);

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
  final title = common?.nameIn(lang) ?? item.name;
  final tag = switch (s.origin) { Origin.favourite => l.foodTagFavourite, Origin.mine => l.foodTagMine, Origin.recent => l.foodTagRecent, _ => null };
  final about = [?tag, ?(common?.qualifierIn(lang) ?? item.brand)].join(' · ');
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
