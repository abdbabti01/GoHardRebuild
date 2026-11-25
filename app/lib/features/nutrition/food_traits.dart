import 'food_search.dart' show normalizeSearch, searchWords;

/// What a food is, attribute by attribute (docs/FOOD_DATA.md › Food resolution): read the same way from what a person
/// said and from a record's description, so the two can be compared without guessing. Pure: no I/O, no network.
///
/// A value is what the words say. An attribute the words do not mention is absent: unknown, never false ("chicken" has
/// no cut, "potatoes" no peel, no mention of oil no "no added fat"). [any] is a record that says the detail is not
/// specified (USDA's "NS as to …", "NFS"): it stands for "not known", it never proves a value.
enum Attr { family, cut, state, method, skin, fat, variety, addedFat, addition }

/// A record whose description says a detail is not specified.
const any = '*';

/// Attribute → value(s). A record may name several methods at once ("baked, broiled, or roasted").
typedef Traits = Map<Attr, Set<String>>;

// ---------------------------------------------------------------------------- the words

/// Phrases first (longest wins), in English, French and Arabic; words are normalized by [searchWords] (accents folded,
/// singular), so "Pommes de terre" and "pomme de terre" are the same. Each entry sets one attribute to one value.
const _phrases = <String, (Attr, String)>{
  // families named by more than one word
  'sweet potato': (Attr.family, 'sweet-potato'), 'patate douce': (Attr.family, 'sweet-potato'), 'بطاطا حلوة': (Attr.family, 'sweet-potato'),
  'pomme de terre': (Attr.family, 'potato'), 'almond milk': (Attr.family, 'almond-milk'), "lait d amande": (Attr.family, 'almond-milk'),
  'boisson d amande': (Attr.family, 'almond-milk'), 'pois chiche': (Attr.family, 'chickpeas'), 'black bean': (Attr.family, 'beans'),
  'egg white': (Attr.cut, 'white'), "blanc d oeuf": (Attr.cut, 'white'), 'بياض البيض': (Attr.cut, 'white'), 'بياض بيض': (Attr.cut, 'white'),
  'whole egg': (Attr.cut, 'whole'), 'oeuf entier': (Attr.cut, 'whole'),
  'haut de cuisse': (Attr.cut, 'thigh'), 'blanc de poulet': (Attr.cut, 'breast'), 'blanc de dinde': (Attr.cut, 'breast'), 'ground beef': (Attr.cut, 'ground'), 'minced beef': (Attr.cut, 'ground'), 'beef mince': (Attr.cut, 'ground'),
  'boeuf hache': (Attr.cut, 'ground'), 'لحم مفروم': (Attr.cut, 'ground'),
  // how it was cooked, and what the words say about it
  'au four': (Attr.method, 'baked'), 'a la vapeur': (Attr.method, 'steamed'), 'على البخار': (Attr.method, 'steamed'), 'في الفرن': (Attr.method, 'baked'),
  'pan broiled': (Attr.method, 'broiled'), 'pan browned': (Attr.method, 'fried'),
  // skin and peel
  'skin not eaten': (Attr.skin, 'no'), 'peel not eaten': (Attr.skin, 'no'), 'skin eaten': (Attr.skin, 'yes'), 'peel eaten': (Attr.skin, 'yes'),
  'meat only': (Attr.skin, 'no'), 'meat and skin': (Attr.skin, 'yes'), 'flesh and skin': (Attr.skin, 'yes'), 'with skin': (Attr.skin, 'yes'),
  'skin on': (Attr.skin, 'yes'), 'with peel': (Attr.skin, 'yes'), 'avec la peau': (Attr.skin, 'yes'), 'avec peau': (Attr.skin, 'yes'),
  'sans peau': (Attr.skin, 'no'), 'sans la peau': (Attr.skin, 'no'), 'without skin': (Attr.skin, 'no'), 'without peel': (Attr.skin, 'no'),
  'no skin': (Attr.skin, 'no'), 'non pele': (Attr.skin, 'yes'), 'non epluche': (Attr.skin, 'yes'), 'غير مقشر': (Attr.skin, 'yes'), 'بدون جلد': (Attr.skin, 'no'), 'بدون قشر': (Attr.skin, 'no'), 'بالجلد': (Attr.skin, 'yes'), 'مع الجلد': (Attr.skin, 'yes'),
  'بالقشر': (Attr.skin, 'yes'), 'مع القشر': (Attr.skin, 'yes'), 'ns as to skin': (Attr.skin, any),
  // cooking fat
  'no added fat': (Attr.addedFat, 'no'), 'without added fat': (Attr.addedFat, 'no'), 'without oil': (Attr.addedFat, 'no'), 'no oil': (Attr.addedFat, 'no'),
  'without butter': (Attr.addedFat, 'no'), 'no butter': (Attr.addedFat, 'no'), 'without fat': (Attr.addedFat, 'no'), 'sans huile': (Attr.addedFat, 'no'),
  'sans beurre': (Attr.addedFat, 'no'), 'sans matiere grasse': (Attr.addedFat, 'no'), 'بدون زيت': (Attr.addedFat, 'no'), 'بدون زبدة': (Attr.addedFat, 'no'),
  'fried no added fat': (Attr.addedFat, 'no'), 'with oil': (Attr.addedFat, 'yes'), 'with butter': (Attr.addedFat, 'yes'), 'made with oil': (Attr.addedFat, 'yes'),
  'made with butter': (Attr.addedFat, 'yes'), 'made with margarine': (Attr.addedFat, 'yes'), 'fat added': (Attr.addedFat, 'yes'),
  'avec huile': (Attr.addedFat, 'yes'), 'avec du beurre': (Attr.addedFat, 'yes'), 'بالزيت': (Attr.addedFat, 'yes'), 'بالزبدة': (Attr.addedFat, 'yes'),
  'ns as to fat': (Attr.addedFat, any), 'ns as to cooking method': (Attr.method, any), 'unspecified fat content': (Attr.fat, any),
  // fat level
  'fat free': (Attr.fat, 'nonfat'), 'reduced fat': (Attr.fat, '2'), 'low fat': (Attr.fat, 'low'), 'whole milk': (Attr.fat, 'whole'),
  'lait entier': (Attr.fat, 'whole'), 'demi ecreme': (Attr.fat, '2'), 'partiellement ecreme': (Attr.fat, '2'), 'حليب كامل': (Attr.fat, 'whole'),
  'خالي الدسم': (Attr.fat, 'nonfat'), 'قليل الدسم': (Attr.fat, 'low'), 'كامل الدسم': (Attr.fat, 'whole'),
  // kinds
  'whole wheat': (Attr.variety, 'wholewheat'), 'whole grain': (Attr.variety, 'wholewheat'), 'ble entier': (Attr.variety, 'wholewheat'),
  'قمح كامل': (Attr.variety, 'wholewheat'), 'حبوب كاملة': (Attr.variety, 'wholewheat'),
  // what it was made with or into
  'with sauce': (Attr.addition, 'sauce'), 'without sauce': (Attr.addition, 'none'), 'sans sauce': (Attr.addition, 'none'), 'بدون صلصة': (Attr.addition, 'none'),
  'with marinade': (Attr.addition, 'marinade'), 'fast food': (Attr.addition, 'restaurant'),
};

const _words = <String, (Attr, String)>{
  // families
  'chicken': (Attr.family, 'chicken'), 'poulet': (Attr.family, 'chicken'), 'دجاج': (Attr.family, 'chicken'), 'فراخ': (Attr.family, 'chicken'),
  'turkey': (Attr.family, 'turkey'), 'dinde': (Attr.family, 'turkey'), 'beef': (Attr.family, 'beef'), 'boeuf': (Attr.family, 'beef'), 'بقري': (Attr.family, 'beef'),
  'hamburger': (Attr.family, 'beef'), 'pork': (Attr.family, 'pork'), 'porc': (Attr.family, 'pork'), 'salmon': (Attr.family, 'salmon'),
  'saumon': (Attr.family, 'salmon'), 'سلمون': (Attr.family, 'salmon'), 'cod': (Attr.family, 'cod'), 'morue': (Attr.family, 'cod'), 'cabillaud': (Attr.family, 'cod'),
  'tilapia': (Attr.family, 'tilapia'), 'بلطي': (Attr.family, 'tilapia'), 'tuna': (Attr.family, 'tuna'), 'thon': (Attr.family, 'tuna'), 'تونة': (Attr.family, 'tuna'),
  'shrimp': (Attr.family, 'shrimp'), 'crevette': (Attr.family, 'shrimp'), 'جمبري': (Attr.family, 'shrimp'), 'egg': (Attr.family, 'egg'), 'oeuf': (Attr.family, 'egg'),
  'بيض': (Attr.family, 'egg'), 'بيضة': (Attr.family, 'egg'), 'potato': (Attr.family, 'potato'), 'patate': (Attr.family, 'potato'), 'بطاطس': (Attr.family, 'potato'),
  'بطاطا': (Attr.family, 'potato'), 'yam': (Attr.family, 'sweet-potato'), 'rice': (Attr.family, 'rice'), 'riz': (Attr.family, 'rice'), 'أرز': (Attr.family, 'rice'),
  'رز': (Attr.family, 'rice'), 'pasta': (Attr.family, 'pasta'), 'spaghetti': (Attr.family, 'pasta'), 'macaroni': (Attr.family, 'pasta'), 'penne': (Attr.family, 'pasta'),
  'pate': (Attr.family, 'pasta'), 'معكرونة': (Attr.family, 'pasta'), 'مكرونة': (Attr.family, 'pasta'), 'oat': (Attr.family, 'oats'), 'oatmeal': (Attr.family, 'oats'),
  'porridge': (Attr.family, 'oats'), 'avoine': (Attr.family, 'oats'), 'gruau': (Attr.family, 'oats'), 'شوفان': (Attr.family, 'oats'), 'couscous': (Attr.family, 'couscous'),
  'كسكس': (Attr.family, 'couscous'), 'كسكسي': (Attr.family, 'couscous'), 'milk': (Attr.family, 'milk'), 'lait': (Attr.family, 'milk'), 'حليب': (Attr.family, 'milk'),
  'yogurt': (Attr.family, 'yogurt'), 'yoghurt': (Attr.family, 'yogurt'), 'yogourt': (Attr.family, 'yogurt'), 'yaourt': (Attr.family, 'yogurt'), 'زبادي': (Attr.family, 'yogurt'),
  'bread': (Attr.family, 'bread'), 'pain': (Attr.family, 'bread'), 'خبز': (Attr.family, 'bread'), 'toast': (Attr.family, 'bread'), 'bean': (Attr.family, 'beans'),
  'haricot': (Attr.family, 'beans'), 'فاصوليا': (Attr.family, 'beans'), 'chickpea': (Attr.family, 'chickpeas'), 'garbanzo': (Attr.family, 'chickpeas'),
  'lentil': (Attr.family, 'lentils'), 'lentille': (Attr.family, 'lentils'), 'عدس': (Attr.family, 'lentils'),
  // cuts and parts
  'breast': (Attr.cut, 'breast'), 'poitrine': (Attr.cut, 'breast'), 'صدر': (Attr.cut, 'breast'), 'thigh': (Attr.cut, 'thigh'),
  'cuisse': (Attr.cut, 'thigh'), 'cuisses': (Attr.cut, 'thigh'), 'فخذ': (Attr.cut, 'thigh'), 'أفخاذ': (Attr.cut, 'thigh'), 'افخاذ': (Attr.cut, 'thigh'), 'drumstick': (Attr.cut, 'drumstick'),
  'pilon': (Attr.cut, 'drumstick'), 'wing': (Attr.cut, 'wing'), 'aile': (Attr.cut, 'wing'), 'جناح': (Attr.cut, 'wing'), 'ground': (Attr.cut, 'ground'),
  'minced': (Attr.cut, 'ground'), 'hache': (Attr.cut, 'ground'), 'مفروم': (Attr.cut, 'ground'), 'patty': (Attr.cut, 'ground'), 'steak': (Attr.cut, 'steak'),
  // raw or cooked
  'raw': (Attr.state, 'raw'), 'uncooked': (Attr.state, 'raw'), 'cru': (Attr.state, 'raw'), 'crue': (Attr.state, 'raw'), 'نيء': (Attr.state, 'raw'),
  'نيئ': (Attr.state, 'raw'), 'ني': (Attr.state, 'raw'), 'dry': (Attr.state, 'raw'), 'sec': (Attr.state, 'raw'), 'cooked': (Attr.state, 'cooked'),
  'cuit': (Attr.state, 'cooked'), 'cuite': (Attr.state, 'cooked'), 'مطبوخ': (Attr.state, 'cooked'), 'مطهو': (Attr.state, 'cooked'), 'مطبوخة': (Attr.state, 'cooked'), 'مطهوة': (Attr.state, 'cooked'), 'نيئة': (Attr.state, 'raw'),
  // ways of cooking (each also says "cooked")
  'baked': (Attr.method, 'baked'), 'مخبوز': (Attr.method, 'baked'), 'boiled': (Attr.method, 'boiled'), 'bouilli': (Attr.method, 'boiled'),
  'bouillie': (Attr.method, 'boiled'), 'مسلوق': (Attr.method, 'boiled'), 'مسلوقة': (Attr.method, 'boiled'), 'مخبوزة': (Attr.method, 'baked'), 'مشوية': (Attr.method, 'grilled'), 'مقلية': (Attr.method, 'fried'), 'محمرة': (Attr.method, 'roasted'), 'roasted': (Attr.method, 'roasted'), 'roast': (Attr.method, 'roasted'),
  'roti': (Attr.method, 'roasted'), 'rotie': (Attr.method, 'roasted'), 'محمر': (Attr.method, 'roasted'), 'محمص': (Attr.method, 'roasted'),
  'grilled': (Attr.method, 'grilled'), 'grille': (Attr.method, 'grilled'), 'grillee': (Attr.method, 'grilled'), 'مشوي': (Attr.method, 'grilled'),
  'broiled': (Attr.method, 'broiled'), 'steamed': (Attr.method, 'steamed'), 'poached': (Attr.method, 'poached'), 'poche': (Attr.method, 'poached'),
  'stewed': (Attr.method, 'stewed'), 'braised': (Attr.method, 'stewed'), 'braise': (Attr.method, 'stewed'), 'fried': (Attr.method, 'fried'),
  'frit': (Attr.method, 'fried'), 'frite': (Attr.method, 'fried'), 'مقلي': (Attr.method, 'fried'), 'sauteed': (Attr.method, 'fried'), 'saute': (Attr.method, 'fried'),
  'scrambled': (Attr.method, 'scrambled'), 'brouille': (Attr.method, 'scrambled'), 'مخفوق': (Attr.method, 'scrambled'), 'mashed': (Attr.method, 'mashed'),
  'puree': (Attr.method, 'mashed'), 'microwaved': (Attr.method, 'microwaved'),
  // skin and peel in one word
  'skinless': (Attr.skin, 'no'), 'peeled': (Attr.skin, 'no'), 'pele': (Attr.skin, 'no'), 'pelee': (Attr.skin, 'no'), 'epluchee': (Attr.skin, 'no'), 'epluche': (Attr.skin, 'no'), 'مقشر': (Attr.skin, 'no'),
  'مقشرة': (Attr.skin, 'no'), 'unpeeled': (Attr.skin, 'yes'),
  // fat level in one word
  'skim': (Attr.fat, 'nonfat'), 'nonfat': (Attr.fat, 'nonfat'), 'ecreme': (Attr.fat, 'nonfat'), 'lowfat': (Attr.fat, 'low'), '0%': (Attr.fat, 'nonfat'),
  '1%': (Attr.fat, 'low'), '2%': (Attr.fat, '2'), '3.25%': (Attr.fat, 'whole'),
  // kinds
  'white': (Attr.variety, 'white'), 'blanc': (Attr.variety, 'white'), 'blanche': (Attr.variety, 'white'), 'أبيض': (Attr.variety, 'white'), 'ابيض': (Attr.variety, 'white'), 'brown': (Attr.variety, 'brown'), 'brun': (Attr.variety, 'brown'),
  'بني': (Attr.variety, 'brown'), 'wholemeal': (Attr.variety, 'wholewheat'), 'complet': (Attr.variety, 'wholewheat'), 'complete': (Attr.variety, 'wholewheat'),
  'greek': (Attr.variety, 'greek'), 'grec': (Attr.variety, 'greek'), 'يوناني': (Attr.variety, 'greek'),
  // additions and products
  'breaded': (Attr.addition, 'coated'), 'coated': (Attr.addition, 'coated'), 'battered': (Attr.addition, 'coated'), 'pane': (Attr.addition, 'coated'),
  'panee': (Attr.addition, 'coated'), 'sauce': (Attr.addition, 'sauce'), 'gravy': (Attr.addition, 'sauce'), 'glazed': (Attr.addition, 'sauce'),
  'marinated': (Attr.addition, 'marinade'), 'stuffed': (Attr.addition, 'stuffed'), 'flavored': (Attr.addition, 'flavored'), 'sweetened': (Attr.addition, 'flavored'),
  'fruit': (Attr.addition, 'flavored'), 'vanilla': (Attr.addition, 'flavored'), 'restaurant': (Attr.addition, 'restaurant'),
};

/// The family a phrase also names when it is consumed whole ("egg white" is an egg, "ground beef" is beef).
const _phraseFamily = <String, String>{
  'egg white': 'egg', 'blanc d oeuf': 'egg', 'بياض البيض': 'egg', 'بياض بيض': 'egg', 'whole egg': 'egg', 'oeuf entier': 'egg',
  'blanc de poulet': 'chicken', 'blanc de dinde': 'turkey', 'ground beef': 'beef', 'minced beef': 'beef', 'beef mince': 'beef', 'boeuf hache': 'beef',
  'whole milk': 'milk', 'lait entier': 'milk', 'حليب كامل': 'milk',
};
final _familyOf = {for (final e in _phraseFamily.entries) searchWords(e.key).join(' '): e.value};

/// The longest phrase, in words, among [_phrases].
final _keys = {for (final e in _phrases.entries) searchWords(e.key).join(' '): e.value, for (final e in _words.entries) searchWords(e.key).join(' '): e.value};

/// What a text says about a food. Phrases are read before single words; "from raw", "from frozen" and "from dried" say what
/// the food was made from, not what it is, and "dry heat" is a way of cooking, not dry food: all three are skipped. A method
/// of cooking also says "cooked". "NFS" ("not further specified") marks a record that does not say how it was cooked.
Traits readTraits(String text) {
  final out = <Attr, Set<String>>{};
  void put(Attr a, String v) => (out[a] ??= <String>{}).add(v);
  final norm = normalizeSearch(text.replaceAll(RegExp(r'\bNFS\b'), ' nfs ').replaceAll("'", ' '));
  final w = searchWords(norm);
  for (var i = 0; i < w.length;) {
    if (w[i] == 'from' && i + 1 < w.length) { i += 2; continue; }                       // from raw, from frozen, from dried
    if (w[i] == 'dry' && i + 1 < w.length && w[i + 1] == 'heat') { i += 2; continue; } // cooked, dry heat
    if (w[i] == 'nfs') { put(Attr.method, any); i++; continue; }
    var taken = 0;
    for (var n = 4; n >= 1 && taken == 0; n--) {
      if (i + n > w.length) continue;
      final phrase = w.sublist(i, i + n).join(' '), hit = _keys[phrase];
      if (hit != null) {
        put(hit.$1, hit.$2);
        if (_familyOf[phrase] case final family?) put(Attr.family, family);
        taken = n;
      }
    }
    i += taken == 0 ? 1 : taken;
  }
  // Lean share of ground meat: "90% lean", "Beef, ground, 90% lean meat / 10% fat".
  for (final m in RegExp(r'(\d{2})% lean').allMatches(norm)) {
    put(Attr.fat, 'lean${m.group(1)}');
  }
  // A way of cooking says it is cooked; "raw" next to a method ("from raw") was skipped above.
  if ((out[Attr.method] ?? const {}).any((m) => m != any) && !(out[Attr.state]?.contains('raw') ?? false)) put(Attr.state, 'cooked');
  return out;
}

// ---------------------------------------------------------------------------- what matters, by family

/// The details that change what a food is, by family, in the order they are asked (docs/FOOD_DATA.md › Food resolution).
/// [ask]: asked when not said (or offered as choices). [defaultable]: when not said, a record that says the detail is not
/// specified ([any], USDA's "NS as to …") is taken without asking; a record that names a value is a choice. [defaults]: what
/// the plain word itself means (an "egg" is a whole egg). Any other said detail is checked: a record that contradicts it is
/// never taken, and one that does not say it cannot prove it. Families not listed only check what was said.
typedef FamilyProfile = ({List<Attr> ask, Set<Attr> defaultable, Map<Attr, String> defaults});

const FamilyProfile _plain = (ask: [], defaultable: {Attr.addedFat}, defaults: {});

const Map<String, FamilyProfile> familyProfiles = {
  'chicken': (ask: [Attr.cut, Attr.state, Attr.skin], defaultable: {Attr.method, Attr.addedFat}, defaults: {}),
  'turkey': (ask: [Attr.state, Attr.skin], defaultable: {Attr.method, Attr.addedFat}, defaults: {}),
  'beef': (ask: [Attr.cut, Attr.fat, Attr.state], defaultable: {Attr.method, Attr.addedFat}, defaults: {}),
  'pork': (ask: [Attr.state], defaultable: {Attr.method, Attr.addedFat}, defaults: {}),
  'salmon': (ask: [Attr.state], defaultable: {Attr.method, Attr.addedFat}, defaults: {}),
  'cod': (ask: [Attr.state], defaultable: {Attr.method, Attr.addedFat}, defaults: {}),
  'tilapia': (ask: [Attr.state], defaultable: {Attr.method, Attr.addedFat}, defaults: {}),
  'shrimp': (ask: [Attr.state], defaultable: {Attr.method, Attr.addedFat}, defaults: {}),
  'egg': (ask: [Attr.cut], defaultable: {Attr.method, Attr.addedFat, Attr.state}, defaults: {Attr.cut: 'whole'}),
  'potato': (ask: [Attr.state, Attr.method, Attr.skin], defaultable: {Attr.addedFat}, defaults: {}),
  'sweet-potato': (ask: [Attr.state, Attr.method, Attr.skin], defaultable: {Attr.addedFat}, defaults: {}),
  'rice': (ask: [Attr.variety, Attr.state], defaultable: {Attr.addedFat, Attr.method}, defaults: {}),
  'pasta': (ask: [Attr.variety, Attr.state], defaultable: {Attr.addedFat, Attr.method}, defaults: {Attr.variety: 'regular'}),
  'oats': (ask: [Attr.state], defaultable: {Attr.addedFat, Attr.method}, defaults: {}),
  'couscous': (ask: [Attr.state], defaultable: {Attr.addedFat, Attr.method}, defaults: {}),
  'beans': (ask: [Attr.state], defaultable: {Attr.addedFat, Attr.method}, defaults: {}),
  'chickpeas': (ask: [Attr.state], defaultable: {Attr.addedFat, Attr.method}, defaults: {}),
  'lentils': (ask: [Attr.state], defaultable: {Attr.addedFat, Attr.method}, defaults: {}),
  'milk': (ask: [Attr.fat], defaultable: {}, defaults: {}),
  'yogurt': (ask: [Attr.variety, Attr.fat], defaultable: {}, defaults: {}),
  'bread': (ask: [Attr.variety], defaultable: {}, defaults: {}),
};

FamilyProfile profileOf(String? family) => familyProfiles[family] ?? _plain;

/// Whether [family]'s weight depends on being raw or cooked (asked only for an amount weighed or measured).
bool weighsDifferentlyCooked(String? family) => profileOf(family).ask.contains(Attr.state) || profileOf(family).defaultable.contains(Attr.state);

/// A catalog entry's reviewed `attrs` (scripts/common-foods.spec.json) as traits: each value or list of values; `generic`
/// is not an attribute (see [isGeneric]).
Traits traitsOf(Map<String, dynamic>? attrs) => {
      for (final e in (attrs ?? const <String, dynamic>{}).entries)
        if (e.key != 'generic' && Attr.values.any((a) => a.name == e.key))
          Attr.values.byName(e.key): {for (final v in e.value is List ? e.value as List : [e.value]) '$v'},
    };

bool isGeneric(Map<String, dynamic>? attrs) => attrs?['generic'] == true;

/// The words of [text] that name the food itself (its family, its cut, or words this file does not know), without how
/// it was prepared: what a food is looked up by ("cooked chicken thighs" → "chicken thigh").
String identityWords(String text) {
  final w = searchWords(text), out = <String>[];
  for (var i = 0; i < w.length;) {
    var taken = 0;
    for (var n = 4; n >= 1 && taken == 0; n--) {
      if (i + n > w.length) continue;
      final hit = _keys[w.sublist(i, i + n).join(' ')];
      if (hit != null) {
        if (hit.$1 == Attr.family || hit.$1 == Attr.cut) out.addAll(w.sublist(i, i + n));
        taken = n;
      }
    }
    if (taken == 0) {
      if (!const {'of', 'de', 'du', 'des', 'la', 'le', 'les', 'and', 'with', 'from', 'a', 'an', 'the'}.contains(w[i])) out.add(w[i]);
      i++;
    } else {
      i += taken;
    }
  }
  return out.join(' ');
}
