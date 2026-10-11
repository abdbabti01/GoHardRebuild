import 'clock.dart';

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// ISO weekday of a day key: 1 = Monday … 7 = Sunday.
int weekdayOf(String dayKey) => parseDayKey(dayKey).weekday;
String weekdayName(int iso) => _weekdays[iso - 1];
String weekdayShort(int iso) => _weekdays[iso - 1].substring(0, 3);

/// "Friday, October 9"
String longDate(String dayKey) {
  final d = parseDayKey(dayKey);
  return '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
}

/// "Fri, Oct 9"
String shortDate(String dayKey) {
  final d = parseDayKey(dayKey);
  return '${weekdayShort(d.weekday)}, ${_months[d.month - 1].substring(0, 3)} ${d.day}';
}

/// "1:05:09" or "5:09"
String clockText(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
  return '${h > 0 ? '$h:' : ''}$mm:${sec.toString().padLeft(2, '0')}';
}

/// "45 min" / "1 h 5 min" / "40 s"
String durationText(int seconds) {
  if (seconds < 60) return '$seconds s';
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60;
  return h > 0 ? '$h h $m min' : '$m min';
}
