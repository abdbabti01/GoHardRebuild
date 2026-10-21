import '../../core/language.dart';
import '../../core/units.dart';
import '../../data/models.dart';

/// A named amount of a food. A weight or volume is present only when its source states one.
extension type FoodServing(Json j) {
  String get label => j['label'] as String? ?? 'serving';
  double? get grams => (j['grams'] as num?)?.toDouble();
  double? get milliliters => (j['milliliters'] as num?)?.toDouble();

  /// For a portion the user defined on a food measured per serving: how many of that serving one of these is.
  double? get ofServing => (j['ofServing'] as num?)?.toDouble();

  /// A portion the user defined themselves ("1 slice = 30 g"), as opposed to one its source states.
  bool get isUserDefined => j['definedBy'] == 'user';
}

/// One food in the shape every source is normalized to: a provider's, or one the user wrote.
/// `nutrients` are for exactly one `basis`. Null is unknown; zero is a stated zero.
extension type FoodItem(Json j) {
  /// off | usda | user
  String get source => j['source'] as String? ?? 'user';
  String? get sourceId => j['sourceId'] as String?;

  /// Digits as text, so leading zeros survive.
  String? get barcode => j['barcode'] as String?;
  String get name => j['name'] as String? ?? '';
  String? get brand => j['brand'] as String?;
  String? get description => j['description'] as String?;

  /// 100g | 100ml | serving. For "serving", the first of [servings] is that serving.
  String get basis => j['basis'] as String? ?? perServing;
  Json get nutrients => j['nutrients'] as Json? ?? const {};
  double? nutrient(String key) => (nutrients[key] as num?)?.toDouble();
  List<FoodServing> get servings => [for (final s in j['servings'] as List? ?? const []) FoodServing(s as Json)];
  String? get imageUrl => j['imageUrl'] as String?;
  String? get imageAttribution => j['imageAttribution'] as String?;

  /// Identity of the food itself, the same wherever it is met again (search, scan, recent, saved).
  String get key => '$source:${sourceId ?? name.toLowerCase()}';

  static const per100g = '100g', per100ml = '100ml', perServing = 'serving';
  static const nutrientKeys = ['calories', 'protein', 'carbs', 'fat'];
}

/// Who to credit, and under what terms, wherever a food from that source is shown.
String? sourceCredit(String source) => switch (source) {
      'off' => 'Open Food Facts · Open Database License',
      'usda' => 'USDA FoodData Central',
      _ => null,
    };

//// A way to say how much was eaten. One unit of it is [basisPerUnit] times the amount the nutrients describe.
/// Every unit of a food is defined against that one basis, so any two of them convert into each other exactly.
class FoodUnit {
  const FoodUnit(this.id, this.label, this.basisPerUnit, {this.noun, this.tail = '', this.size});
  final String id, label;
  final double basisPerUnit;

  /// What one of these is called when it can be counted: "egg", "slice", "cup", "serving". Null for g and ml,
  /// and for a portion its source describes as several things at once ("2 biscuits (25 g)").
  final String? noun;

  /// What the source adds after the noun: ", cooked" or " (330 ml)".
  final String tail;

  /// The stated weight or volume of one, "50 g" or "250 ml", when the source or the user gave it.
  final String? size;

  bool get isCount => noun != null;

  /// How the unit reads in a list of units: "egg · 50 g each", "cup, cooked · 158 g each", "g".
  String get menuLabel {
    if (noun == null) return label;
    final shown = '$noun$tail';
    return size == null || shown.contains(size!) ? shown : '$shown · $size each';
  }
}

/// Turning a food and an amount into values for that amount. Nothing here guesses: a gram is never treated as a
/// millilitre, a serving without a stated weight can only be counted in servings, and no weight is ever taken
/// from a food's name.
abstract final class FoodScaling {
  // Words that describe a size rather than name a thing ("1 large"), and measures written the same in the plural.
  static const _unchanged = {'small', 'medium', 'large', 'jumbo', 'regular', 'mini', 'whole', 'tbsp', 'tsp', 'oz', 'lb', 'g', 'kg', 'ml', 'l', 'each'};
  static const _irregular = {'loaf': 'loaves', 'leaf': 'leaves', 'half': 'halves', 'potato': 'potatoes', 'tomato': 'tomatoes', 'mango': 'mangoes', 'knife': 'knives'};
  static final _one = RegExp(r'^1\s+([A-Za-z][A-Za-z \-]*?)(\s*[,(].*)?$');
  static final _measure = RegExp(r'^\d+([.,]\d+)?\s*(g|ml)$', caseSensitive: false);

  static String _size(num? grams, num? milliliters) => (grams ?? 0) > 0 ? '${formatNumber2(grams!)} g' : (milliliters ?? 0) > 0 ? '${formatNumber2(milliliters!)} ml' : '';

  static FoodUnit _servingUnit(int index, FoodServing s, double basisPerUnit) {
    final size = _size(s.grams, s.milliliters);
    final label = s.label.trim();
    final m = _one.firstMatch(label);
    // "1 egg" is an egg; a serving its source only weighed ("15 g") is a serving of that weight.
    final (String? noun, String tail) = m != null ? (m[1]!.trim(), m[2] ?? '') : _measure.hasMatch(label) ? ('serving', ' ($label)') : (null, '');
    return FoodUnit('serving:$index', label, basisPerUnit, noun: noun, tail: tail, size: size.isEmpty ? null : size);
  }

  /// Only the units that mean something for this food.
  static List<FoodUnit> units(FoodItem item) {
    final servings = item.servings;
    switch (item.basis) {
      case FoodItem.per100g:
        return [
          const FoodUnit('g', 'g', 1 / 100),
          for (final (i, s) in servings.indexed)
            if ((s.grams ?? 0) > 0) _servingUnit(i, s, s.grams! / 100),
        ];
      case FoodItem.per100ml:
        return [
          const FoodUnit('ml', 'ml', 1 / 100),
          for (final (i, s) in servings.indexed)
            if ((s.milliliters ?? 0) > 0) _servingUnit(i, s, s.milliliters! / 100),
        ];
      default:
        final one = servings.firstOrNull;
        return [
          _servingUnit(0, one ?? FoodServing(const {'label': '1 serving'}), 1),
          if ((one?.grams ?? 0) > 0) FoodUnit('g', 'g', 1 / one!.grams!),
          if ((one?.milliliters ?? 0) > 0) FoodUnit('ml', 'ml', 1 / one!.milliliters!),
          // Portions the user defined as a share or a multiple of that serving ("1 slice = 0.125 pizza").
          for (final (i, s) in servings.indexed)
            if (i > 0 && (s.ofServing ?? 0) > 0) _servingUnit(i, s, s.ofServing!),
        ];
    }
  }

  static FoodUnit unit(FoodItem item, String? id) {
    final all = units(item);
    return all.where((u) => u.id == id).firstOrNull ?? all.first;
  }

  /// The quantity a new entry starts with: one of something countable when the food has it, otherwise one of
  /// its servings, otherwise 100 g or 100 ml.
  static (double quantity, FoodUnit unit) initial(FoodItem item) {
    final all = units(item);
    final serving = all.where((u) => u.isCount).firstOrNull ?? all.where((u) => u.id.startsWith('serving')).firstOrNull;
    return serving != null ? (1, serving) : (100, all.first);
  }

  /// The same physical amount said in another unit of the same food: 1 serving of 30 g is 30 g, 45 g is 1.5
  /// servings. Exact up to the two decimals an amount is entered with.
  static double convert(double quantity, FoodUnit from, FoodUnit to) => (quantity * from.basisPerUnit / to.basisPerUnit * 100).roundToDouble() / 100;

  /// The same conversion with nothing rounded away. A form keeps this and rounds only what it shows, so going
  /// from grams to cups and back returns the grams it started with.
  static double exact(double quantity, FoodUnit from, FoodUnit to) => quantity * from.basisPerUnit / to.basisPerUnit;

  /// The values for `quantity` of `unit`, to two decimals like the journal stores them.
  /// An unknown nutrient stays unknown at any amount; a zero stays zero.
  static Map<String, double?> scale(FoodItem item, double quantity, FoodUnit unit) => {
        for (final key in FoodItem.nutrientKeys)
          key: item.nutrient(key) == null ? null : (item.nutrient(key)! * quantity * unit.basisPerUnit * 100).roundToDouble() / 100,
      };

  static String _plural(String noun) {
    final words = noun.split(' '), last = words.last.toLowerCase();
    if (_unchanged.contains(last) || last.endsWith('s') && !last.endsWith('ss')) return noun;
    final plural = _irregular[last] ??
        (RegExp(r'(ss|x|z|ch|sh)$').hasMatch(last) ? '${last}es' : RegExp(r'[^aeiou]y$').hasMatch(last) ? '${last.substring(0, last.length - 1)}ies' : '${last}s');
    return [...words.take(words.length - 1), plural].join(' ');
  }

  /// A count as people say it: "2", "½", "1½", "2.25".
  static String _count(double q) {
    final whole = q.floor();
    final fraction = switch (q - whole) { 0.25 => '¼', 0.5 => '½', 0.75 => '¾', _ => null };
    return fraction == null ? formatNumber2(q) : '${whole == 0 ? '' : whole}$fraction';
  }

  /// "150 g", "250 ml", "2 eggs", "½ slice", "2 cups, cooked", "1 serving (15 g)", "3 × 2 biscuits (25 g)".
  static String amountText(double quantity, FoodUnit unit) {
    if (!unit.id.startsWith('serving')) return '${formatNumber2(quantity)} ${unit.label}';
    final noun = unit.noun;
    if (noun == null) return quantity == 1 ? unit.label : '${formatNumber2(quantity)} × ${unit.label}';
    // "(330 ml)" describes one of them, so several say "each".
    final tail = quantity > 1 && unit.tail.trimLeft().startsWith('(') && unit.tail.endsWith(')') ? '${unit.tail.substring(0, unit.tail.length - 1)} each)' : unit.tail;
    return '${_count(quantity)} ${quantity > 1 ? _plural(noun) : noun}$tail';
  }

  /// The weight or volume of `quantity` of a counted unit, "100 g", when the food's basis makes it known.
  static String? measured(FoodItem item, double quantity, FoodUnit unit) {
    if (!unit.id.startsWith('serving')) return null;
    final measure = item.basis == FoodItem.per100g ? 'g' : item.basis == FoodItem.per100ml ? 'ml' : null;
    if (measure != null) return '${formatNumber2(quantity * unit.basisPerUnit * 100)} $measure';
    final one = item.servings.firstOrNull;
    final per = (one?.grams ?? 0) > 0 ? (one!.grams!, 'g') : (one?.milliliters ?? 0) > 0 ? (one!.milliliters!, 'ml') : null;
    return per == null ? null : '${formatNumber2(quantity * unit.basisPerUnit * per.$1)} ${per.$2}';
  }

  /// The amount in full, as it is shown before logging and kept with the meal: "2 eggs (88 g)", "30 g", "1 jar".
  static String describe(FoodItem item, double quantity, FoodUnit unit) {
    final text = amountText(quantity, unit), weighed = measured(item, quantity, unit);
    return weighed == null || text.contains(weighed) ? text : '$text ($weighed)';
  }

  /// What a portion the user defines is measured in: grams, millilitres, or the food's own serving.
  static String portionMeasure(FoodItem item) => switch (item.basis) {
        FoodItem.per100g => 'g',
        FoodItem.per100ml => 'ml',
        _ => '× ${item.servings.firstOrNull?.label ?? 'serving'}',
      };

  /// The food with one more portion, defined by the user as `amount` of [portionMeasure]. The food's own values
  /// and its other portions are untouched, and the definition travels with every copy of the food.
  static FoodItem withPortion(FoodItem item, String name, double amount) {
    final byWeight = item.basis == FoodItem.per100g, byVolume = item.basis == FoodItem.per100ml;
    // A food on a serving basis must keep that serving first: it is what the values are for.
    final own = [for (final s in item.servings) s.j];
    return FoodItem({
      ...item.j,
      'servings': [
        if (own.isEmpty && !byWeight && !byVolume) {'label': '1 serving', 'grams': null, 'milliliters': null},
        ...own,
        {'label': '1 ${name.trim()}', 'grams': byWeight ? amount : null, 'milliliters': byVolume ? amount : null, if (!byWeight && !byVolume) 'ofServing': amount, 'definedBy': 'user'},
      ],
    });
  }

  /// `item` with the portions the user defined on any other copy of the same food (a saved one, or one logged
  /// before), so a portion defined once is offered wherever that food is met again.
  static FoodItem withKnownPortions(FoodItem item, Iterable<FoodItem> copies) {
    final have = {for (final s in item.servings) s.label};
    final extra = <Json>[];
    for (final c in copies) {
      if (c.key != item.key || c.basis != item.basis) continue;
      for (final s in c.servings) {
        if (s.isUserDefined && have.add(s.label)) extra.add(s.j);
      }
    }
    return extra.isEmpty ? item : FoodItem({...item.j, 'servings': [...[for (final s in item.servings) s.j], ...extra]});
  }

  /// "per 100 g", "per 100 ml", "per 1 jar" (the serving's label is its source's), in `l`'s language.
  static String basisText(FoodItem item, [AppLocalizations? l]) {
    l ??= currentL10n;
    return l.foodBasisPer(switch (item.basis) {
      FoodItem.per100g => '100 g',
      FoodItem.per100ml => '100 ml',
      _ => item.servings.firstOrNull?.label ?? l.foodServingFallback,
    });
  }
}

// Digits only (Arabic-Indic digits read as the same digits), 6 to 14 of them, kept as text. Then Open Food Facts'
/// documented normalization: leading zeros are dropped and the code padded back to 8 digits (short codes) or 13, so
/// a UPC-A and its EAN-13 form are one product. Null for anything that is not a product code, such as a web link.
String? normalizeBarcode(String? raw) {
  final code = asciiDigits((raw ?? '').trim());
  if (code.length < 6 || code.length > 14 || !RegExp(r'^\d+$').hasMatch(code)) return null;
  final stripped = code.replaceFirst(RegExp(r'^0+'), '');
  if (stripped.isEmpty) return null;
  return stripped.padLeft(stripped.length <= 8 ? 8 : 13, '0');
}
