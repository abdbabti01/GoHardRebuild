import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/format.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/search_fold.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/session.dart';

/// The shared locale boundary and the numeric input policy (docs/LOCALIZATION.md).
void main() {
  group('locale resolution', () {
    test('System takes the first supported language in the phone\'s ordered list', () {
      expect(resolveLocale(AppLanguage.system, const [Locale('fr', 'FR')]), const Locale('fr', 'CA'));
      expect(resolveLocale(AppLanguage.system, const [Locale('fr', 'BE')]), const Locale('fr', 'CA'));
      expect(resolveLocale(AppLanguage.system, const [Locale('ar', 'EG')]), const Locale('ar'));
      expect(resolveLocale(AppLanguage.system, const [Locale('en', 'GB')]), const Locale('en'));
      expect(resolveLocale(AppLanguage.system, const [Locale('de'), Locale('ar', 'MA'), Locale('en')]), const Locale('ar'));
      expect(resolveLocale(AppLanguage.system, const [Locale('de'), Locale('es')]), const Locale('en'));
      expect(resolveLocale(AppLanguage.system, const []), const Locale('en'));
    });

    test('an explicit choice wins over the phone until System is chosen again', () {
      const phone = [Locale('ar', 'SA')];
      expect(resolveLocale(AppLanguage.frCA, phone), const Locale('fr', 'CA'));
      expect(resolveLocale(AppLanguage.en, phone), const Locale('en'));
      expect(resolveLocale(AppLanguage.system, phone), const Locale('ar'));
    });

    test('the choice is kept on the device across a restart, beside the other device preferences', () async {
      final secrets = MemorySecretStore();
      final store = DevicePrefsStore(secrets)
        ..motion = MotionPref.reduced
        ..language = AppLanguage.ar;
      await store.save();
      final restored = DevicePrefsStore(secrets);
      await restored.restore();
      expect(restored.language, AppLanguage.ar);
      expect(restored.motion, MotionPref.reduced);
      // A value saved by a build without a language field restores as System.
      await secrets.write('gohard.rebuild.device-prefs', 'device|device|km|run|off');
      final older = DevicePrefsStore(secrets);
      await older.restore();
      expect(older.language, AppLanguage.system);
    });

    test('the provider follows the explicit choice and a later phone-language change under System', () {
      final container = ProviderContainer(overrides: [devicePrefsStoreProvider.overrideWithValue(DevicePrefsStore(MemorySecretStore()))]);
      addTearDown(container.dispose);
      final phone = container.read(deviceLocalesProvider);
      expect(container.read(appLocaleProvider), resolveLocale(AppLanguage.system, phone));
      container.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.frCA);
      expect(container.read(appLocaleProvider), const Locale('fr', 'CA'));
      expect(container.read(appL10nProvider).navToday, 'Aujourd\'hui');
      container.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.ar);
      expect(container.read(appL10nProvider).navToday, 'اليوم');
      container.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.en);
      expect(container.read(appL10nProvider).navToday, 'Today');
    });
  });

  group('numeric input', () {
    test('French commas, Arabic-Indic digits and the Arabic decimal mark give the same canonical value', () {
      for (final typed in ['82.5', '82,5', '٨٢٫٥', '۸۲٫۵', '٨٢,٥', ' 82.5 ']) {
        expect(parseNonNegative(typed), 82.5, reason: typed);
      }
      expect(loadInputToKg(parseNonNegative('٨٢٫٥')!, LoadUnit.kg), 82.5);
      expect(parsePositiveInt('١٢'), 12);
      expect(parsePositiveInt('۱۲'), 12);
    });

    test('ambiguous or malformed input is rejected, never trimmed into another number', () {
      for (final typed in ['', '1,2,3', '1.480,5', '8 2', '-3', '1e3', 'abc', '82..5', '٨٢٫٥٫١', '1 48', '12 3456']) {
        expect(parseNonNegative(typed, grouping: true), isNull, reason: typed);
      }
      expect(parsePositiveInt('12.5'), isNull);
      expect(parsePositiveInt('0'), isNull);
      // A grouping space is only accepted where grouping makes sense (calories, water), never in a load.
      expect(parseNonNegative('1 480'), isNull);
    });

    test('thousands grouping where it is allowed', () {
      expect(parseNonNegative('1 500', grouping: true), 1500);
      expect(parseNonNegative('1\u202F500', grouping: true), 1500);
      expect(parseNonNegative('1\u00A0500,5', grouping: true), 1500.5);
      expect(parseNonNegative('١٬٥٠٠', grouping: true), 1500);
      expect(parsePositiveInt('1,480', grouping: true), 1480);
      expect(parsePositiveInt('1 480', grouping: true), 1480);
      expect(parsePositiveInt('١٥٠٠', grouping: true), 1500);
    });

    test('a partly typed decimal is a value only once it is a number, and zero stays zero', () {
      expect(parseNonNegative('82,'), 82);
      expect(parseNonNegative('٫'), isNull);
      expect(parseNonNegative(','), isNull);
      expect(parseNonNegative('0'), 0);
      expect(parseNonNegative('٠'), 0);
    });

    test('Arabic digits in a barcode become ASCII with the leading zeros kept', () {
      expect(asciiDigits('٠١٢٣٤٥٦٧٨٩٠٥'), '012345678905');
      expect(asciiDigits('۰۰۴۲'), '0042');
      expect(asciiDigits('0042'), '0042');
    });
  });

  group('display formats', () {
    late ProviderContainer c;
    void use(AppLanguage l) {
      c.read(devicePrefsProvider.notifier).setLanguage(l);
      c.read(appLocaleProvider);
    }

    setUp(() {
      c = ProviderContainer(overrides: [devicePrefsStoreProvider.overrideWithValue(DevicePrefsStore(MemorySecretStore()))]);
    });
    tearDown(() {
      use(AppLanguage.en);
      c.dispose();
    });

    test('English is unchanged', () {
      use(AppLanguage.en);
      expect(longDate('2026-10-09'), 'Friday, October 9');
      expect(shortDate('2026-10-09'), 'Fri, Oct 9');
      expect(dayMonth('2026-10-09'), 'Oct 9');
      expect(weekdayShort(1), 'Mon');
      expect(durationText(3900), '1 h 5 min');
      expect(formatLoad(62.5, LoadUnit.kg), '62.5 kg');
      expect(formatNumber2(17.25), '17.25');
      expect(formatNumber2(30), '30');
      expect(formatGrouped(1400), '1,400');
      expect(DistanceUnit.km.distance(2400), '2.40 km');
      expect(DistanceUnit.km.pace(330), '5:30 /km');
    });

    test('French: decimal comma, French dates, the unit kept on the value\'s line', () {
      use(AppLanguage.frCA);
      expect(longDate('2026-10-09'), 'vendredi 9 octobre');
      expect(formatLoad(82.5, LoadUnit.kg), '82,5\u00A0kg');
      expect(formatNumber2(17.25), '17,25');
      expect(parseNonNegative(formatNumber2(17.25)), 17.25, reason: 'a value put back in a field reads back unchanged');
      expect(DistanceUnit.km.distance(2400), '2,40\u00A0km');
      expect(formatGrouped(12345.5), '12\u00A0345,5');
    });

    test('Arabic: Arabic month and unit names, Western digits, isolated Latin content', () {
      use(AppLanguage.ar);
      expect(longDate('2026-10-09'), 'الجمعة، 9 أكتوبر');
      expect(formatLoad(82.5, LoadUnit.kg), '82.5\u00A0كغ');
      expect(DistanceUnit.km.pace(330), '5:30 لكل كم');
      expect(ltr('8–12'), '\u20668–12\u2069');
      // The calendar itself does not change: a day key is the same day in every language.
      expect(weekdayOf('2026-10-09'), DateTime.friday);
    });
  });

  test('search folding matches accents and Arabic spelling variants without changing distinct words', () {
    expect(foldForSearch('Développé couché'), 'developpe couche');
    expect(foldForSearch('ŒUF'), 'oeuf');
    expect(foldForSearch('الضَّغْط'), foldForSearch('الضغط'));
    expect(foldForSearch('أرز'), foldForSearch('ارز'));
    expect(foldForSearch('شوفان'), isNot(foldForSearch('شعير')));
    expect(foldForSearch('١٠٠'), '100');
  });
}
