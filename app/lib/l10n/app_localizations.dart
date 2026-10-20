import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
    Locale('fr', 'CA'),
  ];

  /// Language choice that follows the phone's own language list.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// Supporting text under the System language choice, naming the language the app resolved to.
  ///
  /// In en, this message translates to:
  /// **'Phone language: {language}'**
  String languageSystemResolved(String language);

  /// Me row and sheet title for the app language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// Explanation under the language choices.
  ///
  /// In en, this message translates to:
  /// **'Kept on this phone only. GoHard\'s own text changes; your notes, food names and exercise names you typed stay as written.'**
  String get languageFootnote;

  /// Bottom navigation tab and page title: the day overview.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// Bottom navigation tab and page title: workouts, plan and progress.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get navTrain;

  /// Bottom navigation tab and page title: food and water.
  ///
  /// In en, this message translates to:
  /// **'Eat'**
  String get navEat;

  /// Bottom navigation tab and page title: profile and settings.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get navMe;

  /// Dismisses a dialog or sheet without doing anything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Screen-reader label for a busy spinner on a button.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get busyWorking;

  /// Screen-reader value of a progress indicator.
  ///
  /// In en, this message translates to:
  /// **'{percent} percent'**
  String percentValue(int percent);

  /// Motion preference: follow the phone's Reduce Motion setting.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get motionDevice;

  /// Motion preference: always reduce motion in this app.
  ///
  /// In en, this message translates to:
  /// **'Reduced'**
  String get motionReduced;

  /// Haptics preference: whatever the phone allows.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get hapticsDevice;

  /// Haptics preference: no touch feedback from this app.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get hapticsOff;

  /// A duration under a minute, abbreviated.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String durationSeconds(int seconds);

  /// A duration in whole minutes, abbreviated.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// A duration of an hour or more, abbreviated.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// Shown where a value is not known (never zero).
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get valueUnknown;

  /// Kilograms, abbreviated, after a load.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// Pounds, abbreviated, after a load.
  ///
  /// In en, this message translates to:
  /// **'lb'**
  String get unitLb;

  /// Kilometres, abbreviated.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get unitKm;

  /// Miles, abbreviated.
  ///
  /// In en, this message translates to:
  /// **'mi'**
  String get unitMi;

  /// Speed in kilometres per hour, abbreviated.
  ///
  /// In en, this message translates to:
  /// **'km/h'**
  String get unitKmPerHour;

  /// Speed in miles per hour, abbreviated.
  ///
  /// In en, this message translates to:
  /// **'mph'**
  String get unitMph;

  /// Metres (elevation), abbreviated.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get unitMetre;

  /// Feet (elevation), abbreviated.
  ///
  /// In en, this message translates to:
  /// **'ft'**
  String get unitFoot;

  /// A pace: minutes:seconds per distance unit.
  ///
  /// In en, this message translates to:
  /// **'{pace} /{unit}'**
  String paceValue(String pace, String unit);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'fr':
      {
        switch (locale.countryCode) {
          case 'CA':
            return AppLocalizationsFrCa();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
