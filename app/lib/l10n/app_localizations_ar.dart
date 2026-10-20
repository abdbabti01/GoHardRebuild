// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get languageSystem => 'النظام';

  @override
  String languageSystemResolved(String language) {
    return 'لغة الهاتف: $language';
  }

  @override
  String get languageTitle => 'اللغة';

  @override
  String get languageFootnote =>
      'تُحفظ على هذا الهاتف فقط. يتغيّر نص GoHard، أما ملاحظاتك وأسماء الأطعمة والتمارين التي كتبتها فتبقى كما هي.';

  @override
  String get navToday => 'اليوم';

  @override
  String get navTrain => 'التدريب';

  @override
  String get navEat => 'التغذية';

  @override
  String get navMe => 'حسابي';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get busyWorking => 'جارٍ التنفيذ';

  @override
  String percentValue(int percent) {
    return '$percent بالمئة';
  }

  @override
  String get motionDevice => 'الجهاز';

  @override
  String get motionReduced => 'مُخفَّضة';

  @override
  String get hapticsDevice => 'الجهاز';

  @override
  String get hapticsOff => 'إيقاف';

  @override
  String durationSeconds(int seconds) {
    return '$seconds ث';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes د';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String get valueUnknown => '—';

  @override
  String get unitKg => 'كغ';

  @override
  String get unitLb => 'رطل';

  @override
  String get unitKm => 'كم';

  @override
  String get unitMi => 'ميل';

  @override
  String get unitKmPerHour => 'كم/س';

  @override
  String get unitMph => 'ميل/س';

  @override
  String get unitMetre => 'م';

  @override
  String get unitFoot => 'قدم';

  @override
  String paceValue(String pace, String unit) {
    return '$pace لكل $unit';
  }
}
