// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get languageSystem => 'Système';

  @override
  String languageSystemResolved(String language) {
    return 'Langue du téléphone : $language';
  }

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageFootnote =>
      'Conservée sur ce téléphone seulement. Le texte de GoHard change; tes notes, noms d\'aliments et noms d\'exercices saisis restent tels quels.';

  @override
  String get navToday => 'Aujourd\'hui';

  @override
  String get navTrain => 'Entraînement';

  @override
  String get navEat => 'Nutrition';

  @override
  String get navMe => 'Profil';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get busyWorking => 'En cours';

  @override
  String percentValue(int percent) {
    return '$percent pour cent';
  }

  @override
  String get motionDevice => 'Appareil';

  @override
  String get motionReduced => 'Réduit';

  @override
  String get hapticsDevice => 'Appareil';

  @override
  String get hapticsOff => 'Désactivé';

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
  String get unitMph => 'mi/h';

  @override
  String get unitMetre => 'm';

  @override
  String get unitFoot => 'pi';

  @override
  String paceValue(String pace, String unit) {
    return '$pace /$unit';
  }
}

/// The translations for French, as used in Canada (`fr_CA`).
class AppLocalizationsFrCa extends AppLocalizationsFr {
  AppLocalizationsFrCa() : super('fr_CA');
}
