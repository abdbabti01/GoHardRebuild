// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageSystem => 'System';

  @override
  String languageSystemResolved(String language) {
    return 'Phone language: $language';
  }

  @override
  String get languageTitle => 'Language';

  @override
  String get languageFootnote =>
      'Kept on this phone only. GoHard\'s own text changes; your notes, food names and exercise names you typed stay as written.';

  @override
  String get navToday => 'Today';

  @override
  String get navTrain => 'Train';

  @override
  String get navEat => 'Eat';

  @override
  String get navMe => 'Me';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get busyWorking => 'Working';

  @override
  String percentValue(int percent) {
    return '$percent percent';
  }

  @override
  String get motionDevice => 'Device';

  @override
  String get motionReduced => 'Reduced';

  @override
  String get hapticsDevice => 'Device';

  @override
  String get hapticsOff => 'Off';

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get valueUnknown => '—';

  @override
  String get unitKg => 'kg';

  @override
  String get unitLb => 'lb';

  @override
  String get unitKm => 'km';

  @override
  String get unitMi => 'mi';

  @override
  String get unitKmPerHour => 'km/h';

  @override
  String get unitMph => 'mph';

  @override
  String get unitMetre => 'm';

  @override
  String get unitFoot => 'ft';

  @override
  String paceValue(String pace, String unit) {
    return '$pace /$unit';
  }
}
