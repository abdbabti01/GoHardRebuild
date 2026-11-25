import 'package:dio/dio.dart' show Options;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart' show EatScreen;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Food identity on a device (docs/FOOD_DATA.md › Food identity), one process, a new account against the local branch API
/// on a disposable database whose coach provider is `scripts/coach-stub.mjs` — a STUB with a fixed rule ("I had …", split
/// at commas and "and"), not a model: this proves the app and API path (one request per sentence, local questions, the
/// bones answer, review, one log), never how a live model reads words. Run it with the emulator's large text (font scale
/// 1.6) to check the card at that size. Not in the default run.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('drumsticks offered as drumsticks; weighed with bones, the weight eaten logged; French and Arabic cards', (tester) async {
    final j = Journey(tester, binding);
    final eat = find.byType(EatScreen);
    // The conversation builds lazily and, at large text with the keyboard up, shows little: scroll the answer into view.
    Future<void> see(Finder f, String what) async {
      for (var i = 0; i < 80 && f.evaluate().isEmpty; i++) {
        if (find.byType(Scrollable).evaluate().isNotEmpty) await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 500));
      }
      await j.waitFor(f, what: what, seconds: 2);
      FocusManager.instance.primaryFocus?.unfocus();
      await j.settle(3);
      await tester.ensureVisible(f.first);
      await j.settle(2);
    }

    Finder prefixed(String p) => find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith(p));

    await j.start('Food Identity');
    await j.tapKey('nav-eat');
    await j.settle(6);
    final token = await j.apiToken();
    Future<int> used() async => ((await j.api.get<Map>('/entitlement', options: Options(headers: {'authorization': 'Bearer $token'}))).data!['allowance'] as Map)['used'] as int;
    final before = await used();

    Future<void> describe(String words) async {
      if (find.byKey(const Key('food-describe')).evaluate().isEmpty) await j.tap(find.descendant(of: eat, matching: find.byKey(const Key('log-food'))));
      await j.tapKey('food-describe');
      await j.waitFor(find.byKey(const Key('day-input')), what: 'the coach, ready for a sentence');
      await j.type('day-input', words);
      await j.tapKey('day-send');
    }

    // Back to Add food (the next sentence starts from its Describe my meal).
    Future<void> backToEat() async {
      await j.tapKey('day-close');
      await j.settle(3);
    }

    // Weighed with the bones: the weight eaten worked out from what was left, logged, charged once.
    // (The stub puts the whole phrase in `name`, and the server keeps names of at most 60 characters: a short phrase.)
    await describe('I had 260 g roasted skinless chicken drumsticks on the bone');
    await see(prefixed('day-meal-left-'), 'the weight eaten asked');
    expect(find.textContaining('260 g weighed with bones: how much was eaten?'), findsOneWidget);
    await j.shot('fi-01-bones-question');
    await tester.enterText(prefixed('day-meal-left-').first, '80');
    await j.settle(2);
    await j.tap(find.text('Use 180 g eaten'));
    await see(find.text('Weighed 260 g with bones · 80 g left'), 'the weights kept beside the entry');
    expect(find.textContaining('180 g · Chicken drumstick (Baked, broiled or roasted · skin not eaten)'), findsOneWidget);
    await j.shot('fi-02-bones-ready');
    await j.tap(prefixed('day-meal-review-').last);
    await j.waitFor(find.text('Log meal'), what: 'the meal review');
    await j.tapKey('meal-log');
    await j.waitFor(find.descendant(of: eat, matching: find.textContaining('Chicken drumstick')), what: 'the drumstick in Eat', seconds: 30);
    await j.shot('fi-03-logged');
    await j.waitUntil(() async => ((await j.snapshot(token))['foodEntries'] as List).length == 1, what: 'one entry on the account');
    final entry = ((await j.snapshot(token))['foodEntries'] as List).single as Map;
    final after = await used();
    final kcal = ((entry['macros'] as Map)['calories'] as num).toDouble();
    debugPrint('GOHARD_IDENTITY entry=${entry['name']} amount=${entry['amountDescription']} calories=$kcal allowance before=$before after=$after');
    expect(entry['amountDescription'], contains('180 g'));
    expect(kcal, closeTo(154 * 1.8, 0.6), reason: 'the record\x27s values for the 180 g eaten, never for 260 g');
    expect(after - before, 1, reason: 'one request for the sentence; the choice, the bones answer, review and logging free');

    // The reported screen: drumsticks only, the skin the one question.
    await describe('I had 3 cooked chicken drumsticks');
    await see(find.textContaining('Which matches your 3 cooked chicken drumsticks?'), 'the drumstick choice');
    await see(find.textContaining('Chicken drumstick (Cooked, way not specified · skin eaten)'), 'the second choice');
    expect(find.textContaining('Chicken drumstick (Cooked, way not specified · skin not eaten)'), findsOneWidget);
    expect(find.textContaining(RegExp('liver|giblet|heart|gizzard|which part', caseSensitive: false)), findsNothing);
    await j.shot('fi-04-drumstick-choices');
    await backToEat();

    // The same card in French and Arabic (the interface language; the stub reads only "I had …").
    final prefs = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first)).read(devicePrefsProvider.notifier);
    for (final (lang, words, shot) in [('fr-CA', 'I had 3 pilons de poulet cuits', 'fi-05-fr'), ('ar', 'I had 3 سيقان دجاج مطبوخة', 'fi-06-ar')]) {
      prefs.setLanguage(AppLanguage.parse(lang));
      await j.settle(3);
      await describe(words);
      await see(prefixed('day-meal-pick-'), 'the drumstick choice in $lang');
      expect(find.textContaining(lang == 'ar' ? 'ساق دجاج (دبوس)' : 'Pilon de poulet'), findsWidgets);
      expect(tester.takeException(), isNull);
      await j.shot(shot);
      await backToEat();
    }
    debugPrint('GOHARD_IDENTITY_LANGS done, allowance used=${await used()}');
    prefs.setLanguage(AppLanguage.parse('en'));
  });
}
