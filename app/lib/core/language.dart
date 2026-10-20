import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show Intl;

import '../l10n/app_localizations.dart';
import 'device_prefs.dart';

export '../l10n/app_localizations.dart' show AppLocalizations;

/// The app's language choice, kept on this device only (docs/LOCALIZATION.md › Locale selection). [system] follows the
/// phone's ordered preferred languages; the others win until System is chosen again.
enum AppLanguage {
  system('system', null),
  en('en', Locale('en')),
  frCA('fr-CA', Locale('fr', 'CA')),
  ar('ar', Locale('ar'));

  const AppLanguage(this.id, this.locale);

  /// The stable stored identifier.
  final String id;
  final Locale? locale;

  /// Each language named in itself, so it can be found whatever the app is showing. System is translated instead.
  String? get nativeName => switch (this) { system => null, en => 'English', frCA => 'Français', ar => 'العربية' };

  static AppLanguage parse(String? id) => values.firstWhere((l) => l.id == id, orElse: () => system);
}

/// The first supported language in the phone's ordered list: any English → en, any French → fr-CA, any Arabic → ar.
/// Anything else falls back to English.
Locale resolveLocale(AppLanguage choice, List<Locale> device) {
  if (choice.locale != null) return choice.locale!;
  for (final l in device) {
    switch (l.languageCode) {
      case 'en':
        return AppLanguage.en.locale!;
      case 'fr':
        return AppLanguage.frCA.locale!;
      case 'ar':
        return AppLanguage.ar.locale!;
    }
  }
  return AppLanguage.en.locale!;
}

/// The phone's preferred languages, re-read when the phone reports a change (GoHardApp.didChangeLocales).
class DeviceLocales extends Notifier<List<Locale>> {
  @override
  List<Locale> build() => PlatformDispatcher.instance.locales;
  void refresh() => state = PlatformDispatcher.instance.locales;
}

final deviceLocalesProvider = NotifierProvider<DeviceLocales, List<Locale>>(DeviceLocales.new);

/// The one resolved app locale. Changing it rebuilds text only: no route, form, workout or run is recreated.
final appLocaleProvider = Provider<Locale>((ref) {
  final locale = resolveLocale(ref.watch(devicePrefsProvider.select((p) => p.language)), ref.watch(deviceLocalesProvider));
  _current = locale;
  Intl.defaultLocale = Intl.canonicalizedLocale(locale.toLanguageTag());
  return locale;
});

/// Messages in the resolved language, for code with no widget context (notifications, spoken cues, reminders).
/// Read it with `ref.read` at the moment a message is made; never `watch` it from a recorder or other long-lived service.
final appL10nProvider = Provider<AppLocalizations>((ref) => lookupAppLocalizations(ref.watch(appLocaleProvider)));

Locale _current = const Locale('en');

/// The resolved locale for formatting helpers that have no context (core/format.dart, core/units.dart).
Locale get currentLocale => _current;
AppLocalizations get currentL10n => lookupAppLocalizations(_current);
bool get currentIsArabic => _current.languageCode == 'ar';

extension L10nContext on BuildContext {
  /// The app's messages for this context: `context.l10n.todayTitle`.
  AppLocalizations get l10n => AppLocalizations.of(this);
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
  bool get isArabic => Localizations.maybeLocaleOf(this)?.languageCode == 'ar';
}

/// Every element below [root] is rebuilt once, in place, after a language change, so a line computed by a helper
/// without its own dependency on the locale is redrawn too. State, keys, routes and controllers are untouched.
void rebuildAllText(Element root) {
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  root.visitChildren(mark);
}
