import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'clock.dart';
import 'language.dart';

/// Every displayed date, number and duration goes through here, in the resolved app language (core/language.dart).
/// Only presentation is localized: day keys, Monday–Sunday weeks, the Gregorian calendar, canonical units and every
/// stored value are unchanged. Digits are Western (0–9) in all three languages, as `intl` writes Arabic by default.

// The bundled CLDR date names for every locale; filling them in is synchronous.
final bool _dates = () {
  initializeDateFormatting();
  return true;
}();

String get _loc {
  assert(_dates);
  return Intl.canonicalizedLocale(currentLocale.toLanguageTag());
}

/// Western digits in every language, the app's one numeral choice; flutter_localizations' Arabic date data would
/// otherwise write Arabic-Indic digits in dates only.
DateFormat _f(DateFormat f) => f..useNativeDigits = false;

DateTime _date(String dayKey) {
  final d = parseDayKey(dayKey);
  return DateTime(d.year, d.month, d.day);
}

/// ISO weekday of a day key: 1 = Monday … 7 = Sunday.
int weekdayOf(String dayKey) => parseDayKey(dayKey).weekday;

// 1 January 2024 was a Monday.
DateTime _isoDay(int iso) => DateTime(2024, 1, iso);

/// "Monday", "lundi", "الاثنين".
String weekdayName(int iso) => _f(DateFormat.EEEE(_loc)).format(_isoDay(iso));

/// "Mon", "lun.", "الاثنين" (Arabic has no shorter written form).
String weekdayShort(int iso) => _f(DateFormat.E(_loc)).format(_isoDay(iso));

/// One letter for a narrow column header: "M", "L", "ن".
String weekdayNarrow(int iso) => _f(DateFormat.EEEEE(_loc)).format(_isoDay(iso));

/// "Friday, October 9", "vendredi 9 octobre", "الجمعة، 9 أكتوبر".
String longDate(String dayKey) => _f(DateFormat.MMMMEEEEd(_loc)).format(_date(dayKey));

/// "Fri, Oct 9", "ven. 9 oct.", "الجمعة، 9 أكتوبر".
String shortDate(String dayKey) => _f(DateFormat.MMMEd(_loc)).format(_date(dayKey));

/// "Oct 9, 2026", "9 oct. 2026".
String dayMonthYear(String dayKey) => _f(DateFormat.yMMMd(_loc)).format(_date(dayKey));

/// "1:05:09" or "5:09". Digits keep this order in every language.
String clockText(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
  return '${h > 0 ? '$h:' : ''}$mm:${sec.toString().padLeft(2, '0')}';
}

/// "45 min" / "1 h 5 min" / "40 s"
String durationText(int seconds) {
  final l = currentL10n;
  if (seconds < 60) return l.durationSeconds(seconds);
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60;
  return h > 0 ? l.durationHoursMinutes(h, m) : l.durationMinutes(m);
}

/// "Oct", "oct.", "أكتوبر"
String monthShort(int month) => _f(DateFormat.MMM(_loc)).format(DateTime(2024, month));

/// "October", "octobre", "أكتوبر"
String monthName(int month) => _f(DateFormat.MMMM(_loc)).format(DateTime(2024, month));

/// "October 2026", "octobre 2026"
String monthYear(int year, int month) => _f(DateFormat.yMMMM(_loc)).format(DateTime(year, month));

/// "Oct 9", "9 oct.", "9 أكتوبر"
String dayMonth(String dayKey) => _f(DateFormat.MMMd(_loc)).format(_date(dayKey));

/// The decimal mark of the app language in an ASCII number ("82.5" → "82,5" in French). Display only.
String localDecimal(String ascii) => currentLocale.languageCode == 'fr' ? ascii.replaceAll('.', ',') : ascii;

/// A number with thousands grouped for reading ("1,400", "1 400"), at most [decimals] decimals. Display only;
/// stored and editable values are never reformatted.
String formatGrouped(num v, {int decimals = 1}) => (NumberFormat.decimalPattern(_loc)..maximumFractionDigits = decimals).format(v);

/// "72%", "72 %" (French), "72%" (Arabic).
String formatPercent(num fraction) => (NumberFormat.percentPattern(_loc)..maximumFractionDigits = 0).format(fraction);

/// A value and its unit, kept on one line in French and Arabic ("82,5 kg", "82.5 كغ"); English keeps its plain space.
String withUnit(String value, String unit) => currentLocale.languageCode == 'en' ? '$value $unit' : '$value\u00A0$unit';

/// Latin content that must keep its own left-to-right order inside an Arabic line: an email, a barcode, a signed
/// value, a rep range ("8–12"), a URL. A Unicode isolate (LRI … PDI), presentation only: never store the result.
String ltr(String s) => currentIsArabic ? '\u2066$s\u2069' : s;
