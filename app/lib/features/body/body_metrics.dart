import '../../core/clock.dart';
import '../../core/format.dart' show localDecimal, ltr, withUnit;
import '../../core/language.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../progress/trends.dart' show TrendRange;

/// Body progress (docs/BODY_PROGRESS.md): what a check-in holds, its units, and the projections the screens draw.
/// Pure functions over the stored records; nothing here writes.

enum BodyDimension { mass, length, percent }

/// The measurements a check-in can hold. Left and right are separate fields and are never combined or swapped.
enum BodyField {
  weight('weightKg', BodyDimension.mass),
  waist('waistCm', BodyDimension.length),
  chest('chestCm', BodyDimension.length),
  leftUpperArm('leftUpperArmCm', BodyDimension.length),
  rightUpperArm('rightUpperArmCm', BodyDimension.length),
  leftThigh('leftThighCm', BodyDimension.length),
  rightThigh('rightThighCm', BodyDimension.length),
  bodyFat('bodyFatPercent', BodyDimension.percent);

  const BodyField(this.key, this.dimension);

  /// The wire and storage key of the canonical value (kg, cm or %).
  final String key;
  final BodyDimension dimension;

  /// The same input bounds as the account (not health ranges): weight above 0 and at most 700 kg, circumferences above
  /// 0 and at most 500 cm, body fat 0 to 100 %.
  bool accepts(double canonical) => canonical.isFinite && switch (dimension) {
        BodyDimension.mass => canonical > 0 && canonical <= 700,
        BodyDimension.length => canonical > 0 && canonical <= 500,
        BodyDimension.percent => canonical >= 0 && canonical <= 100,
      };

  /// Circumferences need a server that declares `body-metrics.measurements`.
  bool get needsMeasurementsServer => dimension == BodyDimension.length;
}

/// A field's name in the app's language. Left and right are the person's own (anatomical) sides, in every language.
String bodyFieldLabel(AppLocalizations l, BodyField f) => switch (f) {
      BodyField.weight => l.bodyFieldWeight,
      BodyField.waist => l.bodyFieldWaist,
      BodyField.chest => l.bodyFieldChest,
      BodyField.leftUpperArm => l.bodyFieldLeftUpperArm,
      BodyField.rightUpperArm => l.bodyFieldRightUpperArm,
      BodyField.leftThigh => l.bodyFieldLeftThigh,
      BodyField.rightThigh => l.bodyFieldRightThigh,
      BodyField.bodyFat => l.bodyFieldBodyFat,
    };

const maxNoteLength = 200;

enum LengthUnit {
  cm,
  inch;

  /// Shown in the app's language ("cm", "سم"); [name] stays the stored identifier.
  String get label => this == cm ? currentL10n.bodyUnitCm : currentL10n.bodyUnitIn;
}

/// One inch is exactly 2.54 cm.
const cmPerInch = 2.54;

/// Four decimals, the precision the account stores: a quarter inch (0.635 cm) and pound entries survive a round trip.
double round4(double v) => (v * 10000).roundToDouble() / 10000;

/// "198.0", "16.25", "16.5": up to two decimals, at least one.
String bodyNumber(double v) {
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

/// The units Body progress shows and takes. Storage is always kg, cm and %.
class BodyUnits {
  const BodyUnits(this.mass, this.length);
  final LoadUnit mass;
  final LengthUnit length;

  String label(BodyField f) => switch (f.dimension) { BodyDimension.mass => mass.label, BodyDimension.length => length.label, BodyDimension.percent => '%' };

  double toDisplay(BodyField f, double canonical) => switch (f.dimension) {
        BodyDimension.mass => loadKgToDisplay(canonical, mass),
        BodyDimension.length => length == LengthUnit.inch ? canonical / cmPerInch : canonical,
        BodyDimension.percent => canonical,
      };

  double toCanonical(BodyField f, double shown) => round4(switch (f.dimension) {
        BodyDimension.mass => loadInputToKg(shown, mass),
        BodyDimension.length => length == LengthUnit.inch ? shown * cmPerInch : shown,
        BodyDimension.percent => shown,
      });

  /// The number as it goes into a field: "35.5" ("35,5" in French; [readField] takes either).
  String number(BodyField f, double canonical) => localDecimal(bodyNumber(toDisplay(f, canonical)));

  /// "35.5 in", "21.5 %", or "—" when not recorded.
  String value(BodyField f, double? canonical) => canonical == null ? '—' : withUnit(number(f, canonical), label(f));

  /// To minus From, neutral: "−0.5 in", "+0.25 in", "0.0 in". Body fat is in percentage points.
  String change(BodyField f, double from, double to) {
    final d = double.parse((toDisplay(f, to) - toDisplay(f, from)).toStringAsFixed(2));
    final unit = f.dimension == BodyDimension.percent ? currentL10n.bodyUnitPoints : label(f);
    return withUnit(ltr('${d > 0 ? '+' : d < 0 ? '−' : ''}${localDecimal(bodyNumber(d.abs()))}'), unit);
  }
}

/// A field's text and the canonical value it stands for. Text formatted from a stored value (or converted between
/// units) saves that exact value while it is left as it is, so showing a value never rounds it.
class FieldAnchor {
  const FieldAnchor(this.text, this.canonical);
  final String text;
  final double canonical;
}

/// Why a field's text cannot be saved; the form says it in words ([bodyFieldErrorText]).
enum BodyFieldError { notANumber, outOfRange }

String bodyFieldErrorText(AppLocalizations l, BodyField f, BodyFieldError e) => e == BodyFieldError.notANumber
    ? l.bodyErrorNotANumber
    : switch (f.dimension) {
        BodyDimension.mass => l.bodyErrorWeightRange,
        BodyDimension.length => l.bodyErrorLengthRange,
        BodyDimension.percent => l.bodyErrorFatRange,
      };

/// A field's text read as a canonical number: blank is (null, null), typed text that is not a number is an error.
/// Typed in any of the app's languages ("82,5", "٨٢٫٥"), never with grouping. [checkRange] false is for converting
/// between units, where an out-of-range number still converts.
({double? value, BodyFieldError? error}) readField(BodyField f, String text, FieldAnchor? anchor, BodyUnits units, {bool checkRange = true}) {
  if (anchor != null && text == anchor.text) return (value: anchor.canonical, error: null);
  if (text.trim().isEmpty) return (value: null, error: null);
  final shown = parseNonNegative(text);
  if (shown == null) return (value: null, error: BodyFieldError.notANumber);
  final v = units.toCanonical(f, shown);
  if (checkRange && !f.accepts(v)) return (value: null, error: BodyFieldError.outOfRange);
  return (value: v, error: null);
}

/// Every field's text in [to] units, or null when a field holds text that is not a number (nothing is discarded to
/// convert). Blank stays blank; a value keeps its exact canonical number as the new anchor.
Map<BodyField, FieldAnchor?>? convertFields(Map<BodyField, String> texts, Map<BodyField, FieldAnchor?> anchors, BodyUnits from, BodyUnits to) {
  final out = <BodyField, FieldAnchor?>{};
  for (final MapEntry(key: f, value: text) in texts.entries) {
    final r = readField(f, text, anchors[f], from, checkRange: false);
    if (r.error != null) return null;
    out[f] = r.value == null ? null : FieldAnchor(to.number(f, r.value!), r.value!);
  }
  return out;
}

// ---------------------------------------------------------------------------- chronology

bool has(BodyMetric m, BodyField f) => m.value(f.key) != null;
bool hasMeasurement(BodyMetric m) => BodyField.values.any((f) => has(m, f));

/// Order within a day is known only when every check-in of that day has a first-saved time.
bool orderKnown(Iterable<BodyMetric> sameDay) => sameDay.length < 2 || sameDay.every((m) => m.recordedAtUtc != null);

/// Oldest first: by day, then first-saved time where known, then ID only so the list is stable. The ID says nothing
/// about which came first; screens say so where the order is unknown ([orderKnown]).
int compareCheckIns(BodyMetric a, BodyMetric b) {
  final d = a.dayKey.compareTo(b.dayKey);
  if (d != 0) return d;
  final ta = a.recordedAtUtc, tb = b.recordedAtUtc;
  if (ta != null && tb != null && ta != tb) return DateTime.parse(ta).compareTo(DateTime.parse(tb));
  return a.id.compareTo(b.id);
}

/// A metric's latest known value: from the latest day that has it. With several check-ins that day and a known
/// order, the latest one; with an unknown order, that day's average, labelled as such ([averaged]).
class LatestValue {
  const LatestValue(this.dayKey, this.value, {this.count = 1, this.averaged = false});
  final String dayKey;
  final double value;
  final int count;
  final bool averaged;
}

double _mean(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;

LatestValue? latestOf(List<BodyMetric> checkIns, BodyField f) {
  final withIt = [for (final m in checkIns) if (has(m, f)) m];
  if (withIt.isEmpty) return null;
  final day = withIt.map((m) => m.dayKey).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
  final onDay = [for (final m in withIt) if (m.dayKey == day) m]..sort(compareCheckIns);
  if (onDay.length == 1 || orderKnown(onDay)) return LatestValue(day, onDay.last.value(f.key)!, count: onDay.length);
  return LatestValue(day, _mean(onDay.map((m) => m.value(f.key)!)), count: onDay.length, averaged: true);
}

/// The 7-day average weight: today and the six days before it. Each day with readings counts once, as the mean of
/// that day's readings; missing days are left out, never zero-filled. Null when no day in the window has a weight.
class WeekAverage {
  const WeekAverage(this.kg, this.days, this.from, this.to);
  final double kg;
  final int days;
  final String from, to;
}

WeekAverage? sevenDayWeight(List<BodyMetric> checkIns, String today) {
  final from = addDays(today, -6);
  final byDay = <String, List<double>>{};
  for (final m in checkIns) {
    if (m.weightKg != null && m.dayKey.compareTo(from) >= 0 && m.dayKey.compareTo(today) <= 0) (byDay[m.dayKey] ??= []).add(m.weightKg!);
  }
  if (byDay.isEmpty) return null;
  return WeekAverage(_mean(byDay.values.map(_mean)), byDay.length, from, today);
}

/// One recorded reading of a metric: the check-in it came from and its canonical value.
class BodyPoint {
  const BodyPoint(this.checkIn, this.value);
  final BodyMetric checkIn;
  final double value;
  String get dayKey => checkIn.dayKey;
}

/// Every reading of [f] in [range] (calendar days counted back from [today], inclusive), oldest first. Only observed
/// values; nothing from another field or side.
List<BodyPoint> seriesOf(List<BodyMetric> checkIns, BodyField f, TrendRange range, String today) {
  final from = range.from(today);
  return [
    for (final m in [...checkIns]..sort(compareCheckIns))
      if (has(m, f) && m.dayKey.compareTo(today) <= 0 && (from == null || m.dayKey.compareTo(from) >= 0)) BodyPoint(m, m.value(f.key)!),
  ];
}

/// The mean of each day's readings, oldest first: what the chart's line joins.
List<(String, double)> dailyMeans(List<BodyPoint> points) {
  final byDay = <String, List<double>>{};
  for (final p in points) {
    (byDay[p.dayKey] ??= []).add(p.value);
  }
  return [for (final e in byDay.entries) (e.key, _mean(e.value))];
}

// ---------------------------------------------------------------------------- comparison

/// One metric in a comparison of two saved check-ins. The change exists only when both records hold that metric.
class CompareRow {
  const CompareRow(this.field, this.from, this.to);
  final BodyField field;
  final double? from, to;
  bool get hasChange => from != null && to != null;
}

List<CompareRow> compareCheckInsRows(BodyMetric from, BodyMetric to) => [
      for (final f in BodyField.values)
        if (has(from, f) || has(to, f)) CompareRow(f, from.value(f.key), to.value(f.key)),
    ];

/// The default From and To: the newest two distinct days. A day with one check-in, or several in a known order (the
/// latest), gives a default; a day with several in an unknown order gives null, and the person chooses.
(BodyMetric?, BodyMetric?) defaultPair(List<BodyMetric> eligible) {
  final days = {for (final m in eligible) m.dayKey}.toList()..sort((a, b) => b.compareTo(a));
  if (days.length < 2) return (null, null);
  BodyMetric? pick(String day) {
    final onDay = [for (final m in eligible) if (m.dayKey == day) m]..sort(compareCheckIns);
    return onDay.length == 1 || orderKnown(onDay) ? onDay.last : null;
  }

  return (pick(days[1]), pick(days[0]));
}
