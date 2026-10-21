import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/weather/weather.dart';
import 'package:gohard_rebuild/l10n/app_localizations.dart' show lookupAppLocalizations;

import 'ui_support.dart';

/// The shell in French and Arabic: translated destinations, right-to-left in Arabic with Today still leading, fixed
/// keys, and a language change that keeps the selected tab.
void main() {
  const day = '2026-10-14';
  final keys = ['nav-today', 'nav-train', 'nav-eat', 'nav-me'];
  String label(WidgetTester tester, String key) =>
      tester.widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text))).data!;

  testWidgets('navigation is translated, right-to-left in Arabic with Today on the right, and keys never change', (tester) async {
    final c = await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: day)))!);
    expect([for (final k in keys) label(tester, k)], ['Today', 'Train', 'Eat', 'Me']);

    c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.ar);
    await tester.pumpAndSettle();
    expect([for (final k in keys) label(tester, k)], ['اليوم', 'التدريب', 'التغذية', 'حسابي']);
    expect(Directionality.of(tester.element(find.byType(HomeShell))), TextDirection.rtl);
    expect(tester.getCenter(find.byKey(const Key('nav-today'))).dx, greaterThan(tester.getCenter(find.byKey(const Key('nav-train'))).dx));
    expect(tester.getCenter(find.byKey(const Key('nav-train'))).dx, greaterThan(tester.getCenter(find.byKey(const Key('nav-me'))).dx));

    c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.frCA);
    await tester.pumpAndSettle();
    expect([for (final k in keys) label(tester, k)], ['Aujourd\'hui', 'Entraînement', 'Nutrition', 'Profil']);
    expect(Directionality.of(tester.element(find.byType(HomeShell))), TextDirection.ltr);
  });

  testWidgets('switching en → ar → fr keeps the selected tab', (tester) async {
    final c = await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: day)))!);
    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    for (final language in [AppLanguage.ar, AppLanguage.frCA]) {
      c.read(devicePrefsProvider.notifier).setLanguage(language);
      await tester.pumpAndSettle();
      expect(c.read(shellProvider).tab, 2);
      expect(tester.widget<Semantics>(find.ancestor(of: find.byKey(const Key('nav-eat')), matching: find.byType(Semantics)).first).properties.selected, isTrue);
    }
  });

  test('plurals and weather labels in every language', () {
    final en = lookupAppLocalizations(const Locale('en')), fr = lookupAppLocalizations(const Locale('fr', 'CA')), ar = lookupAppLocalizations(const Locale('ar'));
    expect([for (final n in [1, 2]) en.shellReviewBanner(n)],
        ['1 saved change needs your review. Nothing was lost. Tap to review.', '2 saved changes need your review. Nothing was lost. Tap to review.']);
    expect([for (final n in [0, 1, 2, 3, 11, 100]) ar.todayExerciseCount(n)], ['لا تمارين', 'تمرين واحد', 'تمرينان', '3 تمارين', '11 تمرينًا', '100 تمرين']);
    expect([for (final n in [0, 1, 2]) fr.todaySetCount(n)], ['0 série', '1 série', '2 séries']);
    expect(en.todayPlannedSets(1), '1 planned sets', reason: 'English as before');
    expect(en.todayGreetingNamed('morning', 'Alex'), 'Good morning, Alex!');
    expect(ar.todayGreetingPlain('evening'), 'مساء الخير!');

    const rain = SceneSpec(key: 'rain-day', isWeather: true, label: 'Moderate rain (provider)', code: 63, family: 'rain');
    expect(sceneLabel(en, rain), 'Moderate rain (provider)', reason: 'English keeps the provider\'s words');
    expect(sceneLabel(fr, rain), 'Pluie modérée');
    expect(sceneLabel(ar, const SceneSpec(key: 'fog-day', isWeather: true, family: 'fog', code: 1234)), 'ضباب');
    expect(weatherFallbackText(fr, WeatherFallback.stale), 'La météo n\'est plus à jour');
  });
}
