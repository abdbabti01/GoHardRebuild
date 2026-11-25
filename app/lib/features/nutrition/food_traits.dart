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
  // parts that are another food than the meat (see [explicitParts]); "Chicken, meat and skin and giblets and neck" is the
  // whole bird, and a record of skin is skin
  'chicken skin': (Attr.cut, 'skin'), 'peau de poulet': (Attr.cut, 'skin'), 'جلد دجاج': (Attr.cut, 'skin'), 'جلد الدجاج': (Attr.cut, 'skin'),
  'giblets and neck': (Attr.cut, 'whole'), 'whole chicken': (Attr.cut, 'whole'), 'poulet entier': (Attr.cut, 'whole'), 'دجاجة كاملة': (Attr.cut, 'whole'),
  'cuisse entiere': (Attr.cut, 'leg'), 'chicken back': (Attr.cut, 'back'), 'dos de poulet': (Attr.cut, 'back'), 'chicken leg': (Attr.cut, 'leg'), 'leg quarter': (Attr.cut, 'leg'),
  // how it was cooked, and what the words say about it
  'au four': (Attr.method, 'baked'), 'a la vapeur': (Attr.method, 'steamed'), 'على البخار': (Attr.method, 'steamed'), 'في الفرن': (Attr.method, 'baked'),
  'pan broiled': (Attr.method, 'broiled'), 'pan browned': (Attr.method, 'fried'),
  // skin and peel
  'skin not eaten': (Attr.skin, 'no'), 'peel not eaten': (Attr.skin, 'no'), 'skin eaten': (Attr.skin, 'yes'), 'peel eaten': (Attr.skin, 'yes'),
  'meat only': (Attr.skin, 'no'), 'meat and skin': (Attr.skin, 'yes'), 'flesh and skin': (Attr.skin, 'yes'), 'with skin': (Attr.skin, 'yes'),
  'skin coating eaten': (Attr.skin, 'yes'), 'skin coating not eaten': (Attr.skin, 'no'), 'not eat the skin': (Attr.skin, 'no'), 't eat the skin': (Attr.skin, 'no'),
  'skin removed': (Attr.skin, 'no'), 'removed the skin': (Attr.skin, 'no'), 'pas mange la peau': (Attr.skin, 'no'), 'لم اكل الجلد': (Attr.skin, 'no'),
  'ns as to skin eaten': (Attr.skin, any),
  'skin on': (Attr.skin, 'yes'), 'with peel': (Attr.skin, 'yes'), 'avec la peau': (Attr.skin, 'yes'), 'avec peau': (Attr.skin, 'yes'),
  'sans peau': (Attr.skin, 'no'), 'sans la peau': (Attr.skin, 'no'), 'without skin': (Attr.skin, 'no'), 'without the skin': (Attr.skin, 'no'), 'without peel': (Attr.skin, 'no'),
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
  'ns as to part': (Attr.cut, any),
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
  'pilon': (Attr.cut, 'drumstick'), 'ساق': (Attr.cut, 'drumstick'), 'سيقان': (Attr.cut, 'drumstick'), 'دبوس': (Attr.cut, 'drumstick'), 'دبابيس': (Attr.cut, 'drumstick'),
  'wing': (Attr.cut, 'wing'), 'aile': (Attr.cut, 'wing'), 'aileron': (Attr.cut, 'wing'), 'drummette': (Attr.cut, 'wing'), 'جناح': (Attr.cut, 'wing'), 'أجنحة': (Attr.cut, 'wing'), 'جوانح': (Attr.cut, 'wing'),
  'leg': (Attr.cut, 'leg'), 'liver': (Attr.cut, 'liver'), 'foie': (Attr.cut, 'liver'), 'كبد': (Attr.cut, 'liver'), 'كبدة': (Attr.cut, 'liver'),
  'heart': (Attr.cut, 'heart'), 'coeur': (Attr.cut, 'heart'), 'قلب': (Attr.cut, 'heart'), 'قلوب': (Attr.cut, 'heart'), 'gizzard': (Attr.cut, 'gizzard'),
  'gesier': (Attr.cut, 'gizzard'), 'قانصة': (Attr.cut, 'gizzard'), 'قوانص': (Attr.cut, 'gizzard'), 'giblet': (Attr.cut, 'giblets'), 'abat': (Attr.cut, 'giblets'),
  'neck': (Attr.cut, 'neck'), 'cou': (Attr.cut, 'neck'), 'feet': (Attr.cut, 'feet'), 'foot': (Attr.cut, 'feet'), 'patte': (Attr.cut, 'feet'),
  'tail': (Attr.cut, 'tail'), 'ground': (Attr.cut, 'ground'),
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
  'puree': (Attr.method, 'mashed'), 'microwaved': (Attr.method, 'microwaved'), 'rotisserie': (Attr.method, 'rotisserie'), 'simmered': (Attr.method, 'simmered'),
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
  'bbq': (Attr.addition, 'sauce'), 'barbecue': (Attr.addition, 'sauce'), 'seasoning': (Attr.addition, 'flavored'), 'seasoned': (Attr.addition, 'flavored'),
  'meatless': (Attr.addition, 'substitute'), 'imitation': (Attr.addition, 'substitute'), 'vegetarian': (Attr.addition, 'substitute'),
};

/// Parts that are another food than the meat a family names: never offered for "chicken" or for another part, only when
/// said ("chicken liver"). A record naming several parts is the first of these it names ("Chicken, skin (drumsticks and
/// thighs)" is skin), then the whole bird, then the whole leg ("Chicken leg, drumstick and thigh" is a leg, not a drumstick).
const explicitParts = ['giblets', 'liver', 'heart', 'gizzard', 'neck', 'back', 'feet', 'tail', 'skin'];
const _partOrder = [...explicitParts, 'whole', 'leg'];

/// The family a phrase also names when it is consumed whole ("egg white" is an egg, "ground beef" is beef).
const _phraseFamily = <String, String>{
  'egg white': 'egg', 'blanc d oeuf': 'egg', 'بياض البيض': 'egg', 'بياض بيض': 'egg', 'whole egg': 'egg', 'oeuf entier': 'egg',
  'blanc de poulet': 'chicken', 'blanc de dinde': 'turkey', 'ground beef': 'beef', 'minced beef': 'beef', 'beef mince': 'beef', 'boeuf hache': 'beef',
  'whole milk': 'milk', 'lait entier': 'milk', 'حليب كامل': 'milk',
  'chicken skin': 'chicken', 'peau de poulet': 'chicken', 'جلد دجاج': 'chicken', 'جلد الدجاج': 'chicken', 'whole chicken': 'chicken', 'poulet entier': 'chicken',
  'دجاجة كاملة': 'chicken', 'chicken leg': 'chicken', 'chicken back': 'chicken', 'dos de poulet': 'chicken',
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
    for (var n = 5; n >= 1 && taken == 0; n--) {
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
  // A way of cooking says it is cooked; "raw" next to a method ("from raw") was skipped above. USDA's "NS as to cooking
  // method" is cooked, the way not said.
  if ((out[Attr.method] ?? const {}).any((m) => m != any) && !(out[Attr.state]?.contains('raw') ?? false)) put(Attr.state, 'cooked');
  if (w.join(' ').contains('ns as to cooking method') && out[Attr.state] == null) put(Attr.state, 'cooked');
  // One part per record: the first of [_partOrder] named, else what was named.
  final cuts = out[Attr.cut];
  if (cuts != null && cuts.length > 1) {
    final first = _partOrder.where(cuts.contains).firstOrNull;
    if (first != null) out[Attr.cut] = {first};
  }
  return out;
}

/// Words that put a record's name before its first comma (USDA writes the food first: "Chicken drumstick, rotisserie")
/// but say nothing this file knows: "Orange chicken", "Chicken spread", "Soup, chicken", "Potato chips". Such a record is
/// another food made with this one, matched only when the person said those words too. A leading category ("Fish,
/// salmon", "Nuts, almonds") is skipped to the food it names.
Set<String> productWords(String recordName) {
  final segments = recordName.split(',');
  var at = 0;
  while (at < segments.length - 1 && searchWords(segments[at]).every(_categories.contains)) {
    at++;
  }
  return {
    for (final w in searchWords(segments[at]))
      if (!_known.contains(w) && !_filler.contains(w) && !RegExp(r'^\d').hasMatch(w)) w,
  };
}

/// What a described food is looked up by: the identity words of its English [name], with the family and part the person
/// said ([said]) added when the name leaves them out. The model's name "chicken" for "3 cooked chicken drumsticks" is
/// looked up as "chicken drumstick": plain "chicken" finds feet, liver and dishes first, never a drumstick.
String identityQuery(String name, Traits said) {
  final words = identityWords(name), have = readTraits(words);
  List<String> missing(Attr a) => [for (final v in said[a] ?? const <String>{}) if (v != any && !(have[a]?.contains(v) ?? false)) v.replaceAll('-', ' ')];
  return [...missing(Attr.family), if (words.isNotEmpty) words, ...missing(Attr.cut)].join(' ');
}

/// Whether a record named [recordName] is the food [query] names, rather than another part of it or a dish made with it
/// ("chicken drumstick": a drumstick record, not liver, a whole leg or "Orange chicken"). Null when [query] names no known
/// food, so nothing can be told. The same identity rules as a described meal (docs/FOOD_DATA.md › Food identity).
bool? namesSameFood(String query, String recordName) => sameFood(query, readTraits(recordName), other: productWords(recordName));

/// [namesSameFood] for a record known by its [traits] (a catalog entry's reviewed attributes) and its [other] words.
/// [partsOnly]: only another part than the one named, or a part that is another food, tells it apart (almond milk stays a
/// "milk" result).
bool? sameFood(String query, Traits traits, {Set<String> other = const {}, bool partsOnly = false}) {
  final q = readTraits(query);
  if (q[Attr.family] == null) return null;
  for (final a in [if (!partsOnly) Attr.family, Attr.cut]) {
    final s = q[a];
    if (s != null && !(traits[a]?.intersection(s).isNotEmpty ?? false)) return false;
  }
  final cut = traits[Attr.cut];
  if (cut != null && cut.length == 1 && explicitParts.contains(cut.first) && !(q[Attr.cut]?.contains(cut.first) ?? false)) return false;
  final words = searchWords(query).toSet();
  return other.every(words.contains);
}

/// Whether [text] says a weight was taken with the bones in ("weighed with bones", "bone-in", "on the bone", "avec les
/// os", "بالعظم"): then the weight is not what was eaten, and is never used as if it were.
bool weighedWithBones(String text) {
  final n = ' ${searchWords(text).join(' ')} ';
  return _bones.any((b) => n.contains(' $b '));
}

final _bones = [
  for (final b in ['with bone', 'with the bone', 'bone in', 'on the bone', 'including bone', 'avec os', 'avec les os', 'avec l os', 'bones included', 'بالعظم', 'مع العظم', 'بعظم'])
    searchWords(b).join(' '),
];

/// Whether [part] of a sentence only adds details to the food before it ("…drumsticks weighed with bones and skin; I did
/// not eat the skin"): no food named, only words about how it was eaten, weighed or prepared.
bool detailOnly(String part) {
  final t = readTraits(part);
  if (t[Attr.family] != null) return false;
  final w = searchWords(part);
  return w.isNotEmpty && w.every((x) => _known.contains(x) || _filler.contains(x) || _saying.contains(x));
}

const _saying = {
  'i', 'we', 'me', 'my', 'it', 'them', 'they', 'did', 'didn', 'don', 't', 'not', 'no', 'eat', 'ate', 'eaten', 'had', 'have', 'was', 'were', 'weighed',
  'weigh', 'total', 'about', 'je', 'j', 'n', 'ai', 'pas', 'mange', 'os', 'pese', 'لم', 'عظم', 'وزن', 'اكل',
};

const _categories = {'fish', 'nut', 'seed', 'cereal', 'beverage', 'spice', 'vegetable', 'fruit', 'snack', 'game', 'meat'};
const _filler = {
  'of', 'de', 'du', 'des', 'la', 'le', 'les', 'and', 'or', 'with', 'without', 'from', 'a', 'an', 'the', 'in', 'et', 'ou', 'avec', 'sans',
  'broiler', 'fryer', 'all', 'class', 'meat', 'only', 'fresh', 'frozen', 'plain', 'regular', 'boneless', 'bone', 'ns', 'as', 'to', 'nfs',
  'dark', 'light', 'roasting', 'stewing', 'capon', 'young', 'mature', 'organic', 'natural', 'large', 'medium', 'small', 'piece',
};
final Set<String> _known = {for (final k in _keys.keys) ...k.split(' ')};

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
    for (var n = 5; n >= 1 && taken == 0; n--) {
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
