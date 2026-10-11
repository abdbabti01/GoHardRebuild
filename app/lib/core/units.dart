/// Lifted load is canonical kilograms everywhere in storage, sync and analytics.
/// Pounds exist only at the input and display boundary.
enum LoadUnit {
  kg,
  lb;

  static LoadUnit parse(String? s) => s == 'lb' ? LoadUnit.lb : LoadUnit.kg;
}

const double kgPerLb = 0.45359237;

double loadInputToKg(double value, LoadUnit unit) => unit == LoadUnit.lb ? value * kgPerLb : value;
double loadKgToDisplay(double kg, LoadUnit unit) => unit == LoadUnit.lb ? kg / kgPerLb : kg;

String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// "62.5 kg" / "137.8 lb". The stored kilograms are never rewritten by a unit preference.
String formatLoad(num? kg, LoadUnit unit) => kg == null ? '—' : '${_trim(loadKgToDisplay(kg.toDouble(), unit))} ${unit.name}';
String formatLoadValue(num kg, LoadUnit unit) => _trim(loadKgToDisplay(kg.toDouble(), unit));

/// Parses user text with either decimal separator. Returns null for blank, negative or non-finite input.
double? parseNonNegative(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || !v.isFinite || v < 0) return null;
  return v;
}

int? parsePositiveInt(String raw) {
  final v = int.tryParse(raw.trim());
  return v == null || v <= 0 ? null : v;
}

String formatNumber(num v) => v == v.roundToDouble() ? v.round().toString() : _trim(v.toDouble());
