import 'format.dart' show localDecimal, withUnit;
import 'language.dart' show currentL10n;

/// Lifted load is canonical kilograms everywhere in storage, sync and analytics.
/// Pounds exist only at the input and display boundary.
enum LoadUnit {
  kg,
  lb;

  static LoadUnit parse(String? s) => s == 'lb' ? LoadUnit.lb : LoadUnit.kg;

  /// The unit as shown in the app's language ("kg", "كغ"). [name] stays the stored identifier.
  String get label => this == kg ? currentL10n.unitKg : currentL10n.unitLb;
}

const double kgPerLb = 0.45359237;

/// Run / Walk display units. Distance is canonical metres everywhere else; pace, speed and elevation follow:
/// km → min/km, km/h, m; mi → min/mi, mph, ft.
enum DistanceUnit {
  km(1000, 1),
  mi(1609.344, 3.28084);

  const DistanceUnit(this.meters, this.feetPerMeter);
  final double meters, feetPerMeter;

  /// Shown in the app's language; [name] stays the stored identifier.
  String get label => this == km ? currentL10n.unitKm : currentL10n.unitMi;
  String get speedLabel => this == km ? currentL10n.unitKmPerHour : currentL10n.unitMph;
  String get elevationLabel => this == km ? currentL10n.unitMetre : currentL10n.unitFoot;

  /// "2.40" (two decimals), the number only.
  String number(double meters) => localDecimal((meters / this.meters).toStringAsFixed(2));
  String distance(double? meters) => meters == null ? '—' : withUnit(number(meters), label);

  /// "12:30" per unit, or "—" when there is no honest pace.
  String paceNumber(double? secondsPerUnit) {
    if (secondsPerUnit == null || !secondsPerUnit.isFinite || secondsPerUnit <= 0 || secondsPerUnit > 5940) return '—';
    final s = secondsPerUnit.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  String pace(double? secondsPerUnit) => paceNumber(secondsPerUnit) == '—' ? '—' : currentL10n.paceValue(paceNumber(secondsPerUnit), label);
  String speed(double? metersPerSecond) =>
      metersPerSecond == null ? '—' : withUnit(localDecimal((metersPerSecond * 3600 / meters).toStringAsFixed(1)), speedLabel);
  String elevation(double? meters) => meters == null ? '—' : withUnit('${(meters * feetPerMeter).round()}', elevationLabel);
}

double loadInputToKg(double value, LoadUnit unit) => unit == LoadUnit.lb ? value * kgPerLb : value;
double loadKgToDisplay(double kg, LoadUnit unit) => unit == LoadUnit.lb ? kg / kgPerLb : kg;

String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return localDecimal(s.endsWith('.0') ? s.substring(0, s.length - 2) : s);
}

/// "62.5 kg" / "137.8 lb" / "62,5 kg". The stored kilograms are never rewritten by a unit preference.
String formatLoad(num? kg, LoadUnit unit) => kg == null ? '—' : withUnit(_trim(loadKgToDisplay(kg.toDouble(), unit)), unit.label);
String formatLoadValue(num kg, LoadUnit unit) => _trim(loadKgToDisplay(kg.toDouble(), unit));

/// Arabic-Indic (٠–٩) and Eastern Arabic-Indic (۰–۹) digits as ASCII; everything else unchanged. Barcodes keep
/// their leading zeros: "٠١٢٣" → "0123".
String asciiDigits(String raw) => String.fromCharCodes(raw.runes.map((c) => c >= 0x660 && c <= 0x669
    ? c - 0x660 + 0x30
    : c >= 0x6F0 && c <= 0x6F9
        ? c - 0x6F0 + 0x30
        : c));

/// Grouping marks between digit groups: space, no-break space, narrow no-break space, thin space, Arabic "٬".
final _group = RegExp('[ \u00A0\u202F\u2009\u066C]');
final _plain = RegExp(r'^(\d+(\.\d*)?|\.\d+)$');
final _three = RegExp(r'^\d{3}$');

/// The canonical number in what a person typed, in any of the app's languages: "82.5", "82,5", "٨٢٫٥" and
/// "۸۲٫۵" are all 82.5. With [grouping], a space, no-break space or "٬" between groups of three digits
/// ("1 480", "١٬٤٨٠") is grouping. One decimal mark ("." "," or "٫") is the decimal point. Anything ambiguous or
/// malformed ("1,2,3", "1.480,5", "8 2", "-3") is null: rejected, never silently trimmed. Only typed input is
/// parsed this way; displayed text is never read back into stored numbers.
double? parseLocalNumber(String raw, {bool grouping = false}) {
  var t = asciiDigits(raw.trim()).replaceAll('\u066B', '.');
  if (t.isEmpty) return null;
  if (_group.hasMatch(t)) {
    if (!grouping) return null;
    final parts = t.split(_group);
    final last = parts.last.split(RegExp('[.,]'));
    final ok = RegExp(r'^\d{1,3}$').hasMatch(parts.first) && parts.length > 1 &&
        parts.sublist(1, parts.length - 1).every(_three.hasMatch) && _three.hasMatch(last.first) && last.length <= 2;
    if (!ok) return null;
    t = parts.join();
  }
  if (RegExp('[.,]').allMatches(t).length > 1) return null;
  t = t.replaceAll(',', '.');
  if (!_plain.hasMatch(t)) return null;
  final v = double.tryParse(t);
  return v == null || !v.isFinite ? null : v;
}

/// A non-negative number typed in any of the app's languages ([parseLocalNumber]). Null for blank, negative,
/// ambiguous or non-finite input.
double? parseNonNegative(String raw, {bool grouping = false}) => parseLocalNumber(raw, grouping: grouping);

/// A whole positive number ("12", "١٢", or "1 200" with [grouping]). Null for anything else, a decimal included.
/// With [grouping], "1,480" and "1.480" are thousands too, since a whole number has no decimal part.
int? parsePositiveInt(String raw, {bool grouping = false}) {
  final t = asciiDigits(raw.trim());
  if (grouping && RegExp(r'^\d{1,3}([,.]\d{3})+$').hasMatch(t)) raw = t.replaceAll(RegExp('[,.]'), '');
  if (RegExp('[.,\u066B]').hasMatch(raw)) return null;
  final v = parseLocalNumber(raw, grouping: grouping);
  return v == null || v <= 0 ? null : v.toInt();
}

/// Up to two decimals, the precision the food journal stores: "161.7", "17.25", "30" ("161,7" in French). Used
/// wherever a stored nutrition value is put back into a field, so showing a value never changes it: the field's text
/// is read back with [parseNonNegative], which accepts the same decimal mark.
String formatNumber2(num v) {
  final s = v.toStringAsFixed(2);
  return localDecimal(s.replaceFirst(RegExp(r'\.?0+$'), ''));
}

String formatNumber(num v) => v == v.roundToDouble() ? '${v.round()}' : _trim(v.toDouble());
