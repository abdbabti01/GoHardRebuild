/// Lifted load is canonical kilograms everywhere in storage, sync and analytics.
/// Pounds exist only at the input and display boundary.
enum LoadUnit {
  kg,
  lb;

  static LoadUnit parse(String? s) => s == 'lb' ? LoadUnit.lb : LoadUnit.kg;
}

const double kgPerLb = 0.45359237;

/// Run / Walk display units. Distance is canonical metres everywhere else; pace, speed and elevation follow:
/// km → min/km, km/h, m; mi → min/mi, mph, ft.
enum DistanceUnit {
  km('km', 1000, 'km/h', 'm', 1),
  mi('mi', 1609.344, 'mph', 'ft', 3.28084);

  const DistanceUnit(this.label, this.meters, this.speedLabel, this.elevationLabel, this.feetPerMeter);
  final String label, speedLabel, elevationLabel;
  final double meters, feetPerMeter;

  /// "2.40" (two decimals), the number only.
  String number(double meters) => (meters / this.meters).toStringAsFixed(2);
  String distance(double? meters) => meters == null ? '—' : '${number(meters)} $label';

  /// "12:30" per unit, or "—" when there is no honest pace.
  String paceNumber(double? secondsPerUnit) {
    if (secondsPerUnit == null || !secondsPerUnit.isFinite || secondsPerUnit <= 0 || secondsPerUnit > 5940) return '—';
    final s = secondsPerUnit.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  String pace(double? secondsPerUnit) => paceNumber(secondsPerUnit) == '—' ? '—' : '${paceNumber(secondsPerUnit)} /$label';
  String speed(double? metersPerSecond) => metersPerSecond == null ? '—' : '${(metersPerSecond * 3600 / meters).toStringAsFixed(1)} $speedLabel';
  String elevation(double? meters) => meters == null ? '—' : '${(meters * feetPerMeter).round()} $elevationLabel';
}

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

/// Up to two decimals, the precision the food journal stores: "161.7", "17.25", "30". Used wherever a stored
/// nutrition value is put back into a field, so showing a value never changes it.
String formatNumber2(num v) {
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

String formatNumber(num v) => v == v.roundToDouble() ? v.round().toString() : _trim(v.toDouble());
