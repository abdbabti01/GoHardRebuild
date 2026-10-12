import '../../core/units.dart';
import '../../data/models.dart';

/// A named amount of a food. A weight or volume is present only when its source states one.
extension type FoodServing(Json j) {
  String get label => j['label'] as String? ?? 'serving';
  double? get grams => (j['grams'] as num?)?.toDouble();
  double? get milliliters => (j['milliliters'] as num?)?.toDouble();
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

/// A way to say how much was eaten. One unit of it is [basisPerUnit] times the amount the nutrients describe.
class FoodUnit {
  const FoodUnit(this.id, this.label, this.basisPerUnit);
  final String id, label;
  final double basisPerUnit;
}

/// Turning a food and an amount into values for that amount. Nothing here guesses: a gram is never treated as a
/// millilitre, and a serving without a stated weight can only be counted in servings.
abstract final class FoodScaling {
  /// Only the units that mean something for this food.
  static List<FoodUnit> units(FoodItem item) {
    final servings = item.servings;
    switch (item.basis) {
      case FoodItem.per100g:
        return [
          const FoodUnit('g', 'g', 1 / 100),
          for (final (i, s) in servings.indexed)
            if ((s.grams ?? 0) > 0) FoodUnit('serving:$i', s.label, s.grams! / 100),
        ];
      case FoodItem.per100ml:
        return [
          const FoodUnit('ml', 'ml', 1 / 100),
          for (final (i, s) in servings.indexed)
            if ((s.milliliters ?? 0) > 0) FoodUnit('serving:$i', s.label, s.milliliters! / 100),
        ];
      default:
        final one = servings.firstOrNull;
        return [
          FoodUnit('serving:0', one?.label ?? 'serving', 1),
          if ((one?.grams ?? 0) > 0) FoodUnit('g', 'g', 1 / one!.grams!),
          if ((one?.milliliters ?? 0) > 0) FoodUnit('ml', 'ml', 1 / one!.milliliters!),
        ];
    }
  }

  static FoodUnit unit(FoodItem item, String? id) {
    final all = units(item);
    return all.where((u) => u.id == id).firstOrNull ?? all.first;
  }

  /// The quantity a new entry starts with: one serving when the food has one, otherwise 100 g or 100 ml.
  static (double quantity, FoodUnit unit) initial(FoodItem item) {
    final all = units(item);
    final serving = all.where((u) => u.id.startsWith('serving')).firstOrNull;
    return serving != null ? (1, serving) : (100, all.first);
  }

  /// The values for `quantity` of `unit`, to two decimals like the journal stores them.
  /// An unknown nutrient stays unknown at any amount; a zero stays zero.
  static Map<String, double?> scale(FoodItem item, double quantity, FoodUnit unit) => {
        for (final key in FoodItem.nutrientKeys)
          key: item.nutrient(key) == null ? null : (item.nutrient(key)! * quantity * unit.basisPerUnit * 100).roundToDouble() / 100,
      };

  /// "150 g", "250 ml", "1 cup, cooked", "2 × 1 cup, cooked".
  static String amountText(double quantity, FoodUnit unit) => unit.id.startsWith('serving')
      ? (quantity == 1 ? unit.label : '${formatNumber(quantity)} × ${unit.label}')
      : '${formatNumber(quantity)} ${unit.label}';

  /// "per 100 g", "per 100 ml", "per 1 jar".
  static String basisText(FoodItem item) => switch (item.basis) {
        FoodItem.per100g => 'per 100 g',
        FoodItem.per100ml => 'per 100 ml',
        _ => 'per ${item.servings.firstOrNull?.label ?? 'serving'}',
      };
}

/// Digits only, 6 to 14 of them, kept as text. Then Open Food Facts' documented normalization: leading zeros are
/// dropped and the code padded back to 8 digits (short codes) or 13, so a UPC-A and its EAN-13 form are one
/// product. Null for anything that is not a product code, such as a web link from a QR code.
String? normalizeBarcode(String? raw) {
  final code = (raw ?? '').trim();
  if (code.length < 6 || code.length > 14 || !RegExp(r'^\d+$').hasMatch(code)) return null;
  final stripped = code.replaceFirst(RegExp(r'^0+'), '');
  if (stripped.isEmpty) return null;
  return stripped.padLeft(stripped.length <= 8 ? 8 : 13, '0');
}
