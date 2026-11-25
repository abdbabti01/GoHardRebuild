// Describe your meal on screen (docs/FOOD_DATA.md › Describe your meal): the real Add food, coach and meal review screens
// over a real local database for the conversation, the bundled foods for matching, and the server's reading of the words
// SCRIPTED (no AI, no network): these tests prove what the app does with an answer, never that a live model reads well.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart' show Accent, serif;
import 'package:gohard_rebuild/features/coach/coach_avatar.dart' show CoachGuide;
import 'package:gohard_rebuild/features/coach/coach_bubble.dart' show CoachBubble;
import 'package:gohard_rebuild/features/coach/coach_companion.dart' show CoachCompanion;
import 'package:gohard_rebuild/features/coach/coach_prefs.dart' show coachPrefsProvider;
import 'package:gohard_rebuild/features/coach/coach_rig.dart' show rigImageProvider;
import 'package:gohard_rebuild/core/compatibility.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/coach/coach_client.dart' show AskFailure, AskProblem;
import 'package:gohard_rebuild/features/coach/day_coach.dart';
import 'package:gohard_rebuild/features/coach/day_coach_screen.dart';
import 'package:gohard_rebuild/features/nutrition/food_discovery.dart' show LookupProblem;
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/log_food_screen.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals_screens.dart' show MealReviewScreen;
import 'package:gohard_rebuild/features/plus/entitlement.dart';

import 'day_coach_ui_test.dart' show ScriptedDay;
import 'food_fakes.dart';
import 'support.dart';
import 'ui_support.dart';

const day = '2026-10-27';

class _Caps extends CompatibilityController {
  _Caps(this.caps);
  final Set<String>? caps;
  @override
  Compatibility build() => Compatibility(capabilities: caps);
}

Entitlement free(int remaining) => Entitlement({
      'tier': 'free', 'validForSeconds': 72 * 3600,
      'allowance': {'used': 15 - remaining, 'limit': 15, 'remaining': remaining, 'resetsAtUtc': '2026-11-01T00:00:00Z'},
    }, receivedAtUtc: DateTime.utc(2026, 10, 27, 12));

class _Fixture {
  _Fixture({ScriptedDiscovery? discovery}) : fakes = FoodFakes(discovery: discovery);
  final store = TestStore();
  final ai = ScriptedDay();
  final FoodFakes fakes;

  Future<List<Override>> overrides(WidgetTester tester,
      {Set<String>? caps = const {'coach.daily', 'coach.meal-log', 'food.saved-meals', 'food.search'}, Entitlement? plus, bool plusUnknown = false}) async {
    final db = store.open();
    addTearDown(() async {
      await db.close();
      store.dispose();
    });
    return [
      ...(await tester.runAsync(() => overridesFor(day: day, food: const [])))!,
      ...fakes.overrides,
      dbProvider.overrideWithValue(db),
      syncProvider.overrideWith((ref) {
        final engine = SyncEngine(db, Api(FakeServer(), ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
        ref.onDispose(engine.dispose);
        return engine;
      }),
      savedMealsProvider.overrideWith((ref) => Stream.value(const [])),
      mealDraftsProvider.overrideWith((ref) => Stream.value(const {})),
      dayCoachClientProvider.overrideWithValue(ai),
      compatibilityProvider.overrideWith(() => _Caps(caps)),
      plusProvider.overrideWithValue(plusUnknown ? null : plus ?? free(14)),
    ];
  }
}

/// The server's reading of a described meal, as the API checks it (docs/FOOD_DATA.md › Describe your meal).
DayIntent ate(List<Json> foods, {String? meal, String day = 'shown'}) => DayIntent.fromJson({'kind': 'ate', 'day': day, 'meal': meal, 'foods': foods}, ai: true)!;
DayIntent edit(List<Json> edits) => DayIntent.fromJson({'kind': 'edit', 'edits': edits}, ai: true)!;
Json said(String name, [num? q, String? unit, String? noun]) => {'name': name, 'label': name, 'preparation': null, 'brand': null, 'quantity': q, 'unit': unit, 'noun': noun};

Finder _keyed(String prefix) => find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith(prefix));

Future<void> _tap(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await _settle(tester);
}

/// Real time for database I/O and the matching that follows an answer (neither runs on fake time).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pumpAndSettle();
  }
}

/// Brings the end of the conversation into view (the list builds lazily).
Future<void> _toEnd(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

Future<void> _say(WidgetTester tester, String words) async {
  await tester.enterText(find.byKey(const Key('day-input')), words);
  await _tap(tester, find.byKey(const Key('day-send')));
}

/// Opens Add food the way Eat does, and keeps what it returned.
class _Launcher extends StatelessWidget {
  const _Launcher(this.result);
  final List<Object?> result;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const Key('open-add-food'),
            onPressed: () async => result.add(await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(builder: (_) => const LogFoodScreen(dayKey: day, meal: 'Lunch')))),
            child: const Text('Add food'),
          ),
        ),
      );
}

void main() {
  testWidgets('Add food › Describe your meal: one request reads the meal; raw or cooked and which chicken are asked here; one review logs it once', (tester) async {
    final f = _Fixture();
    final result = <Object?>[];
    await pumpApp(tester, await f.overrides(tester), home: _Launcher(result), size: const Size(390, 2400));
    await _tap(tester, find.byKey(const Key('open-add-food')));
    await _tap(tester, find.byKey(const Key('food-describe')));
    expect(find.byKey(const Key('day-intro')), findsOneWidget);
    expect(find.text('Uses 1 AI request · 14 remaining this month'), findsOneWidget, reason: 'the cost, said before anything is sent');
    expect(f.ai.requests, isEmpty, reason: 'opening, and typing, ask nothing');

    f.ai.reply = (r) async => ate([said('chicken', 120, 'g'), said('potatoes', 100, 'g')]);
    await _say(tester, 'I ate 120 g of chicken and 100 g of potatoes');
    final sent = f.ai.requests.single;
    expect(sent['features'], ['log'], reason: 'asked only of a server that declared it');
    expect(sent.containsKey('draft'), isFalse, reason: 'no meal was being prepared');
    // Nothing guessed: both foods ask how they were weighed; no total pretends to be the meal.
    expect(_keyed('day-meal-raw-'), findsNWidgets(2));
    expect(_keyed('day-meal-review-'), findsNothing);
    expect(find.text('chicken · 120 g: weighed raw or cooked?'), findsOneWidget);
    expect(find.text('Answer the questions above to finish this meal.'), findsOneWidget);

    await _tap(tester, _keyed('day-meal-raw-').first);
    expect(find.text('Which matches your chicken?'), findsOneWidget, reason: 'raw chicken is breast or thigh, with or without skin: the person says which');
    expect(find.text('Not said: which part, skin or peel'), findsOneWidget);
    await _tap(tester, find.textContaining('Chicken breast (Raw · boneless, skinless)'));
    await _tap(tester, _keyed('day-meal-cooked-').first);
    expect(find.text('Which matches your potatoes?'), findsOneWidget, reason: 'cooked potatoes: how, and whether the peel was eaten');
    await _tap(tester, find.textContaining('Potato (Boiled · peeled)'));
    expect(find.text('Ready to review. Nothing is logged until you tap Log meal.'), findsOneWidget);
    expect(find.textContaining('120 g · Chicken breast'), findsOneWidget);
    expect(find.textContaining('100 g · Potato'), findsOneWidget);
    expect(find.textContaining('Total:'), findsOneWidget);
    expect(f.ai.requests.length, 1, reason: 'answering the questions asks no AI');

    await _tap(tester, _keyed('day-meal-review-').first);
    final review = tester.widget<MealReviewScreen>(find.byType(MealReviewScreen));
    expect((review.dayKey, review.meal, review.logLabel), (day, 'Lunch', 'Log meal'), reason: 'the day and meal chosen in Add food');
    expect(find.text('Log meal'), findsOneWidget);
    await tester.pageBack();
    await _settle(tester);
    expect(f.fakes.journal.meals, isEmpty, reason: 'leaving the review logs nothing');
    expect(_keyed('day-meal-review-'), findsOneWidget, reason: 'the draft is still there');

    await _tap(tester, _keyed('day-meal-review-').first);
    await tester.tap(find.byKey(const Key('meal-log')));
    await tester.tap(find.byKey(const Key('meal-log')), warnIfMissed: false); // a second tap
    await _settle(tester);
    expect(f.fakes.journal.meals.length, 1, reason: 'one atomic meal log, once');
    final logged = f.fakes.journal.meals.single;
    expect([for (final d in logged) (d.name, d.quantity, d.unitId, d.dayKey, d.meal)], [('Chicken breast', 120.0, 'g', day, 'Lunch'), ('Potato', 100.0, 'g', day, 'Lunch')]);
    expect(logged.first.item?.sourceId, '2646170', reason: 'the record chosen, with its source identity');
    expect(result, [true], reason: 'Add food closes, as after any log');
    expect(f.ai.requests.length, 1, reason: 'logging never asks the AI');
  });

  testWidgets('a follow-up changes the open draft only, from its words; a late answer after a change here is not applied; a logged meal never changes', (tester) async {
    final f = _Fixture();
    await pumpApp(tester, await f.overrides(tester), home: const DayCoachScreen(day: day, meal: 'Dinner'), size: const Size(390, 2600));
    f.ai.reply = (r) async => ate([said('egg', 2, 'piece', 'egg'), said('olive oil', 1, 'piece', 'tablespoon')]);
    await _say(tester, 'I had 2 eggs and a tablespoon of olive oil');
    expect(find.textContaining('2 eggs (100 g) · Eggs'), findsOneWidget);

    f.ai.reply = (r) async => edit([{'op': 'amount', 'ref': 'd1', 'food': said('egg', 3, 'piece', 'egg')}]);
    await _say(tester, 'make it 3 eggs');
    final followUp = f.ai.requests.last;
    expect(followUp['draft'], [{'ref': 'd1', 'text': 'Eggs · 2 eggs (100 g)'}, {'ref': 'd2', 'text': 'Olive oil · 1 tablespoon (14 g)'}]);
    expect('${followUp['draft']}', isNot(contains('kcal')), reason: 'words only: no values, no journal');
    expect(find.text('Eggs: now 3 egg.'), findsOneWidget);
    expect(find.textContaining('3 eggs (150 g) · Eggs'), findsOneWidget);
    expect(find.text('Replaced by a newer meal below.'), findsOneWidget, reason: 'one draft is open at a time');

    // A follow-up whose answer arrives after the meal was changed here is not applied.
    final held = Completer<DayIntent>();
    f.ai.reply = (r) => held.future;
    // While a request is in flight the coach leans in (an animation), so nothing here waits for the screen to settle.
    await tester.enterText(find.byKey(const Key('day-input')), 'remove the oil');
    await tester.ensureVisible(find.byKey(const Key('day-send')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('day-send')));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(f.ai.requests.length, 3);
    await tester.ensureVisible(_keyed('day-meal-remove-').first);
    await tester.pump();
    await tester.tap(_keyed('day-meal-remove-').first); // the eggs, removed here meanwhile
    await tester.pump();
    held.complete(edit([{'op': 'remove', 'ref': 'd2', 'food': null}]));
    await _settle(tester);
    await _toEnd(tester);
    expect(find.textContaining('Your meal changed while I was reading that'), findsOneWidget);
    expect(find.textContaining('1 tablespoon (14 g) · Olive oil'), findsOneWidget, reason: 'the oil is still there: the late answer changed nothing');

    await _tap(tester, _keyed('day-meal-review-').last);
    await _tap(tester, find.byKey(const Key('meal-log')));
    expect(f.fakes.journal.meals.single.map((d) => d.name), ['Olive oil']);
    expect(find.text('Logged. Change it in Eat from now on.'), findsOneWidget);

    f.ai.reply = (r) async => edit([{'op': 'add', 'ref': null, 'food': said('toast', 1, 'piece', 'slice')}]);
    await _say(tester, 'add a slice of toast');
    expect(f.ai.requests.last.containsKey('draft'), isFalse, reason: 'a logged meal is never sent to be changed');
    expect(find.textContaining('That meal is already logged'), findsOneWidget);
    expect(f.fakes.journal.meals.length, 1, reason: 'nothing logged again');
  });

  testWidgets('allowance used up or no connection: the words and the draft stay, and the draft can still be reviewed and logged', (tester) async {
    final f = _Fixture();
    await pumpApp(tester, await f.overrides(tester, plus: free(1)), home: const DayCoachScreen(day: day, meal: 'Lunch'), size: const Size(390, 2400));
    expect(find.text('Uses 1 AI request · 1 remaining this month'), findsOneWidget);
    f.ai.reply = (r) async => ate([said('egg', 2, 'piece', 'egg')]);
    await _say(tester, 'two eggs');

    f.ai.reply = (r) async => throw const AskFailure(AskProblem.allowance);
    await _say(tester, 'add toast');
    expect(find.text('add toast'), findsOneWidget, reason: 'the words are kept');
    expect(find.textContaining('You’ve used your AI allowance for this month.'), findsOneWidget);
    expect(find.byKey(const Key('day-retry')), findsNothing, reason: 'no retry that would only be refused');

    f.ai.reply = (r) async => throw const AskFailure(AskProblem.unreached);
    await tester.tap(find.byKey(const Key('day-edit')));
    await _settle(tester);
    await _say(tester, 'add toast');
    expect(find.byKey(const Key('day-needs-connection')), findsOneWidget);
    final first = f.ai.requests.last['requestId'];
    await _tap(tester, find.byKey(const Key('day-retry')));
    expect(f.ai.requests.last['requestId'], first, reason: 'Retry is the same request: never charged twice');

    await _tap(tester, _keyed('day-meal-review-').first);
    await _tap(tester, find.byKey(const Key('meal-log')));
    expect(f.fakes.journal.meals.single.single.quantity, 2, reason: 'Log meal is never behind the AI allowance');
  });

  for (final (name, plus, text) in [('an older server', Entitlement.legacy, 'Uses 1 AI request'), ('unknown', null, 'Uses 1 AI request · what remains this month can’t be checked right now')]) {
    testWidgets('the usage line is honest when the allowance is $name', (tester) async {
      final f = _Fixture();
      await pumpApp(tester, await f.overrides(tester, plus: plus, plusUnknown: plus == null), home: const DayCoachScreen(day: day), size: const Size(390, 1400));
      expect(find.text(text), findsOneWidget);
    });
  }

  testWidgets('a server without meal reading says so and sends nothing', (tester) async {
    final f = _Fixture();
    await pumpApp(tester, await f.overrides(tester, caps: const {'coach.daily', 'food.saved-meals'}), home: const DayCoachScreen(day: day, describe: true), size: const Size(390, 1400));
    expect(find.text('Describing a meal isn’t available on this server yet. Add food and logging still work.'), findsOneWidget);
    expect(find.byKey(const Key('day-input')), findsNothing);
    expect(f.ai.requests, isEmpty);
  });

  testWidgets('a suggestion is never a record: "what could I eat?" logs nothing', (tester) async {
    final f = _Fixture();
    await pumpApp(tester, await f.overrides(tester), home: const DayCoachScreen(day: day), size: const Size(390, 1600));
    f.ai.reply = (r) async => const DayIntent('suggest', ai: true);
    await _say(tester, 'What could I eat?');
    expect(_keyed('day-meal-'), findsNothing);
    expect(f.fakes.journal.meals.isEmpty && f.fakes.journal.saved.isEmpty, isTrue);
  });

  for (final lang in ['fr-CA', 'ar']) {
    testWidgets('$lang: a described meal at 320 px with 1.6× text, nothing overflows', (tester) async {
      final f = _Fixture();
      final c = await pumpApp(tester, await f.overrides(tester), home: const DayCoachScreen(day: day, describe: true), size: const Size(320, 1400), textScale: 1.6);
      c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
      await tester.pumpAndSettle();
      f.ai.reply = (r) async => ate([said('chicken', 120, 'g'), said('dragonfruit'), said('egg', 2, 'piece', 'egg')]);
      await _say(tester, lang == 'ar' ? 'أكلت 120 غ دجاج' : 'J’ai mangé 120 g de poulet');
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(_keyed('day-meal-find-'), findsOneWidget, reason: 'a food with no record: Find food, the others kept');
      expect(Directionality.of(tester.element(find.byKey(const Key('day-input')))), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
    });
  }

  group('search on screen', () {
    testWidgets('chicken breast: raw and cooked from the phone at once, the wider search once after the pause, no AI; a misspelling is corrected and said', (tester) async {
      final discovery = ScriptedDiscovery(results: [
        FoodItem({'source': 'usda', 'sourceId': '900101', 'name': 'CHICKEN BREAST', 'brand': 'TYSON', 'basis': '100g', 'nutrients': {'calories': 110, 'protein': 23}, 'servings': []}),
      ]);
      final f = _Fixture(discovery: discovery);
      await pumpApp(tester, await f.overrides(tester), home: const LogFoodScreen(dayKey: day, meal: 'Lunch'), size: const Size(390, 2400));
      await tester.enterText(find.byKey(const Key('food-search')), 'chicken breast');
      await tester.pump();
      expect(find.byKey(const Key('common-chicken-breast')), findsOneWidget, reason: 'the phone\'s foods at once, before any answer');
      expect(find.byKey(const Key('common-chicken-breast-raw')), findsOneWidget);
      expect(discovery.searches, isEmpty, reason: 'never per keystroke');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(discovery.searches, ['chicken breast'], reason: 'asked once after the pause, even with an exact everyday food: other preparations and brands');

      await tester.enterText(find.byKey(const Key('food-search')), 'chiken brest');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Showing results for “chicken breast”.'), findsOneWidget);
      expect(find.byKey(const Key('common-chicken-breast-raw')), findsOneWidget);
      expect(discovery.searches, everyElement('chicken breast'), reason: 'the corrected words are what is asked');

      await tester.enterText(find.byKey(const Key('food-search')), 'tyson');
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(discovery.searches.last, 'tyson', reason: 'asked once, by itself');
      expect(find.text('Brand: Tyson'), findsOneWidget);
      expect(find.text('Chicken breast'), findsWidgets);
      expect(f.ai.requests, isEmpty, reason: 'search never asks the AI');
    });

    testWidgets('French words are searched in English in the wider database, and that is said', (tester) async {
      final discovery = ScriptedDiscovery(results: [
        FoodItem({'source': 'usda', 'sourceId': '2646171', 'name': 'Chicken, thigh, boneless, skinless, raw', 'basis': '100g', 'nutrients': {'calories': 149}, 'servings': []}),
      ]);
      final f = _Fixture(discovery: discovery);
      await pumpApp(tester, await f.overrides(tester), home: const LogFoodScreen(dayKey: day, meal: 'Lunch'), size: const Size(390, 2400));
      await tester.enterText(find.byKey(const Key('food-search')), 'pilon de poulet');
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(discovery.searches, ['pilon chicken'], reason: 'known words translated, small words dropped, unknown words kept');
      expect(find.text('The food database is in English: searched for “pilon chicken”.'), findsOneWidget);
    });

    testWidgets('an exact everyday match still offers more foods and brands: one tap asks once, products after the plain foods, no AI', (tester) async {
      final discovery = ScriptedDiscovery(results: [
        FoodItem({'source': 'usda', 'sourceId': '900101', 'name': 'CHICKEN BREAST', 'brand': 'TYSON', 'basis': '100g', 'nutrients': {'calories': 110, 'protein': 23}, 'servings': []}),
        FoodItem({'source': 'usda', 'sourceId': '171077', 'name': 'Chicken, broilers or fryers, breast, meat only, cooked, roasted', 'basis': '100g', 'nutrients': {'calories': 165}, 'servings': []}),
      ]);
      final f = _Fixture(discovery: discovery);
      await pumpApp(tester, await f.overrides(tester), home: const LogFoodScreen(dayKey: day, meal: 'Lunch'), size: const Size(390, 3000));
      await tester.enterText(find.byKey(const Key('food-search')), 'chicken breast');
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(discovery.searches, ['chicken breast'], reason: 'asked once by itself: an exact everyday food on the phone never hides products');
      expect(find.text('Brand: Tyson'), findsOneWidget, reason: 'branded products are listed, and said to be');
      expect(find.text('Generic'), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const Key('common-chicken-breast-raw'))).dy, lessThan(tester.getTopLeft(find.text('Brand: Tyson')).dy),
          reason: 'no brand named: the plain foods come first, products after');
      expect(f.ai.requests, isEmpty, reason: 'search never asks the AI');
    });
  });

  group('food resolution on the card', () {
    testWidgets('"100 g cooked chicken thighs and 130 g cooked potatoes": one useful choice each; "I\'m not sure" is disclosed and stays an estimate through the log; one request', (tester) async {
      final f = _Fixture();
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, await f.overrides(tester), home: const DayCoachScreen(day: day, meal: 'Lunch'), size: const Size(390, 3000));
      f.ai.reply = (r) async => ate([said('cooked chicken thighs', 100, 'g'), said('cooked potatoes', 130, 'g')]);
      await _say(tester, 'I had 100 g of cooked chicken thighs and 130 g of cooked potatoes');
      expect(find.text('Which matches your cooked chicken thighs?'), findsOneWidget);
      expect(find.text('Not said: skin or peel'), findsOneWidget, reason: 'cooking method left open by records that do not specify it; only the skin is asked');
      expect(find.text('Which matches your cooked potatoes?'), findsOneWidget);
      expect(find.text('Not said: how it was cooked, skin or peel'), findsOneWidget);
      expect(_keyed('day-meal-review-'), findsNothing, reason: 'nothing ready until each is answered');
      expect(find.textContaining('Total:'), findsNothing);

      await _tap(tester, find.textContaining('Chicken thigh (Cooked · skin not eaten)'));
      expect(find.textContaining('100 g · Chicken thigh'), findsOneWidget, reason: 'the said 100 g kept for the record chosen');
      expect(find.text('Which matches your cooked potatoes?'), findsOneWidget, reason: 'the potatoes are untouched');

      await _tap(tester, _keyed('day-meal-notsure-').first);
      expect(find.textContaining('as an estimate?'), findsOneWidget, reason: 'the record and that it may differ are said before anything is used');
      expect(find.text('This record does not say how it was prepared.'), findsOneWidget);
      await _tap(tester, _keyed('day-meal-estimate-').first);
      expect(find.textContaining('130 g · Potato (estimate)'), findsOneWidget);

      await _tap(tester, _keyed('day-meal-review-').first);
      await _tap(tester, find.byKey(const Key('meal-log')));
      expect([for (final e in f.fakes.journal.meals.single) (e.name, e.quantity)], [('Chicken thigh', 100.0), ('Potato (estimate)', 130.0)]);
      expect(f.fakes.journal.meals.single.last.item?.sourceId, '2709382', reason: 'USDA\'s own record for a potato cooked in a way not specified: its values, not an average');
      expect(f.ai.requests.length, 1, reason: 'choices, the estimate, the review and logging ask no AI');
      semantics.dispose();
    });

    testWidgets('Change food starts from the same amount when it means the same weight; a lookup that did not answer keeps the item for Try again', (tester) async {
      final discovery = ScriptedDiscovery(searchProblem: LookupProblem.offline);
      final f = _Fixture(discovery: discovery);
      await pumpApp(tester, await f.overrides(tester), home: const DayCoachScreen(day: day, meal: 'Lunch'), size: const Size(390, 3000));
      f.ai.reply = (r) async => ate([said('roasted skinless chicken breast', 150, 'g'), said('dragonfruit', 100, 'g')]);
      await _say(tester, 'I had 150 g of roasted skinless chicken breast and 100 g of dragonfruit');
      expect(find.textContaining('150 g · Chicken breast'), findsOneWidget, reason: 'every detail said: taken directly, nothing asked');
      expect(find.textContaining('Couldn’t look up dragonfruit right now.'), findsOneWidget, reason: 'offline: said as such, never "not found"');

      await _tap(tester, _keyed('day-meal-change-').first);
      final picker = tester.widget<LogFoodScreen>(find.byType(LogFoodScreen));
      expect((picker.pick, picker.keep?.quantity, picker.keep?.unitId, picker.keep?.state), (true, 150.0, 'g', 'cooked'));
      await tester.pageBack();
      await _settle(tester);
      expect(find.textContaining('150 g · Chicken breast'), findsOneWidget, reason: 'cancelled: nothing changed');
      expect(f.ai.requests.length, 1);
    });
  });

  group('more than twelve foods', () {
    final twelve = [for (final n in ['apple', 'banana', 'orange', 'grapes', 'mango', 'pineapple', 'blueberries', 'strawberries', 'cucumber', 'carrots', 'tomato', 'spinach']) said(n, 100, 'g')];

    testWidgets('the foods past twelve are named on the meal; it is complete only once each is added with Add food or left out', (tester) async {
      final f = _Fixture();
      await pumpApp(tester, await f.overrides(tester), home: const DayCoachScreen(day: day, meal: 'Lunch'), size: const Size(390, 4000));
      f.ai.reply = (r) async => DayIntent.fromJson({'kind': 'ate', 'day': 'shown', 'foods': twelve, 'extra': ['pickles', 'olives'], 'dropped': ['foods']}, ai: true)!;
      await _say(tester, 'I ate fourteen things');
      expect(find.text('I can read up to 12 foods at a time. The others are listed below: add each one with Add food, or leave it out.'), findsOneWidget);
      expect(find.text('pickles: past the first 12 foods. Add it on its own, or leave it out.'), findsOneWidget);
      expect(find.text('olives: past the first 12 foods. Add it on its own, or leave it out.'), findsOneWidget);
      expect(_keyed('day-meal-review-'), findsNothing, reason: 'not complete while a food named is neither added nor left out');
      expect(find.textContaining('So far, without pickles and olives'), findsOneWidget);

      await _tap(tester, _keyed('day-meal-extra-leave-').first);
      expect(find.text('pickles: left out'), findsOneWidget);
      expect(_keyed('day-meal-review-'), findsNothing);

      await _tap(tester, _keyed('day-meal-extra-add-').first);
      final add = tester.widget<LogFoodScreen>(find.byType(LogFoodScreen));
      expect((add.query, add.dayKey, add.meal, add.pick), ('olives', day, 'Lunch', false), reason: 'the usual Add food, for the meal’s day and meal');
      Navigator.of(tester.element(find.byType(LogFoodScreen))).pop(true); // logged there, on its own
      await _settle(tester);
      expect(find.text('olives: added on its own'), findsOneWidget);
      expect(_keyed('day-meal-review-'), findsOneWidget, reason: 'every food dealt with: ready to review');
      expect(find.textContaining('Total:'), findsOneWidget);
      expect(f.ai.requests.length, 1, reason: 'one request for the whole description');
    });

    testWidgets('when the rest could not be named, nothing is invented: the meal says so and asks for the rest separately', (tester) async {
      final f = _Fixture();
      await pumpApp(tester, await f.overrides(tester), home: const DayCoachScreen(day: day, meal: 'Lunch'), size: const Size(390, 4000));
      f.ai.reply = (r) async => DayIntent.fromJson({'kind': 'ate', 'day': 'shown', 'foods': twelve, 'extra': const [], 'dropped': ['foods']}, ai: true)!;
      await _say(tester, 'I ate thirty things');
      expect(find.textContaining('describe the rest in a new message'), findsOneWidget);
      expect(_keyed('day-meal-rest-'), findsWidgets);
      expect(_keyed('day-meal-review-'), findsNothing);
      expect(_keyed('day-meal-extra-'), findsNothing, reason: 'no food is made up');
      await _tap(tester, _keyed('day-meal-rest-leave-').first);
      expect(_keyed('day-meal-review-'), findsOneWidget, reason: 'the rest explicitly left out');
    });
  });

  group('the invitation in Add food', () {
    Finder invite = find.byKey(const Key('food-invite'));

    for (final guide in CoachGuide.values) {
      testWidgets('${guide.name} invites from the top, above search: one Describe my meal; opening Add food sends nothing', (tester) async {
        final f = _Fixture();
        final c = await pumpApp(tester, await f.overrides(tester), home: const LogFoodScreen(dayKey: day, meal: 'Lunch'));
        c.read(coachPrefsProvider.notifier).setGuide(guide);
        await tester.pumpAndSettle();
        expect(tester.widget<CoachCompanion>(find.descendant(of: invite, matching: find.byType(CoachCompanion))).guide, guide, reason: 'the selected guide speaks');
        expect(find.descendant(of: invite, matching: find.byType(CoachBubble)), findsOneWidget, reason: 'the existing speech bubble');
        for (final t in ['What did you eat?', 'Uses 1 AI request when you send.']) {
          expect(find.descendant(of: invite, matching: find.text(t)), findsOneWidget);
        }
        expect(find.descendant(of: invite, matching: find.textContaining('for you to review before anything is logged', findRichText: true)), findsOneWidget);
        expect(find.byKey(const Key('food-describe')), findsOneWidget);
        expect(find.text('Describe my meal'), findsOneWidget, reason: 'exactly one way in');
        expect(find.byKey(const Key('food-describe-row')), findsNothing);
        expect(tester.getBottomLeft(invite).dy, lessThanOrEqualTo(tester.getTopLeft(find.byKey(const Key('food-search'))).dy), reason: 'above search');
        expect(find.byKey(const Key('coach-help-food.search')), findsNothing, reason: 'one face: the portrait is the page’s help');
        expect(tester.getSize(find.byKey(const Key('food-describe'))).height, greaterThanOrEqualTo(48));
        expect(f.ai.requests, isEmpty);

        await tester.tap(find.bySemanticsLabel('Help with finding a food'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('coach-help-sheet')), findsOneWidget, reason: 'the guide’s portrait opens search help');
        expect(f.ai.requests, isEmpty);
      });
    }

    testWidgets('with the coach off: the same invitation as plain content, no portrait; search help beside the title', (tester) async {
      final f = _Fixture();
      final c = await pumpApp(tester, await f.overrides(tester), home: const LogFoodScreen(dayKey: day, meal: 'Lunch'));
      c.read(coachPrefsProvider.notifier).setOnTabs(false);
      await tester.pumpAndSettle();
      expect(find.descendant(of: invite, matching: find.byType(CoachCompanion)), findsNothing);
      expect(find.descendant(of: invite, matching: find.text('What did you eat?')), findsOneWidget);
      expect(find.descendant(of: invite, matching: find.text('Uses 1 AI request when you send.')), findsOneWidget);
      expect(find.byKey(const Key('food-describe')), findsOneWidget);
      expect(find.byKey(const Key('coach-help-food.search')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('food-describe'))).height, greaterThanOrEqualTo(48));
    });

    testWidgets('Describe my meal opens the conversation for the day and meal chosen, an earlier day too; the example is shown, never sent', (tester) async {
      final f = _Fixture();
      await pumpApp(tester, await f.overrides(tester), home: const LogFoodScreen(dayKey: '2026-10-20', meal: 'Lunch'), size: const Size(390, 1400));
      await _tap(tester, find.byKey(const Key('food-meal-select')));
      await tester.tap(find.byKey(const Key('food-meal-option-Dinner')).last);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('food-describe')));
      final convo = tester.widget<DayCoachScreen>(find.byType(DayCoachScreen));
      expect((convo.day, convo.meal, convo.describe), ('2026-10-20', 'Dinner', true));
      expect(find.text('For example: I ate 120 g of chicken and 100 g of potatoes.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('day-input'))).controller!.text, '', reason: 'the example is a hint, not words to send');
      expect(find.text('Uses 1 AI request · 14 remaining this month'), findsOneWidget, reason: 'the server’s count, beside the field');
      expect(f.ai.requests, isEmpty, reason: 'opening Add food, the invitation and the conversation asks nothing');

      f.ai.reply = (r) async => ate([said('egg', 2, 'piece', 'egg')]);
      await _say(tester, 'two eggs');
      final mealFor = (tester.widget<Text>(_keyed('day-meal-for-').first)).data!;
      expect((mealFor.contains('Dinner'), mealFor.contains('October 20')), (true, true), reason: 'the meal is for the day and meal chosen: $mealFor');
    });

    testWidgets('at the monthly limit: the invitation says so and when it resets, offers no new request, and search still works', (tester) async {
      final f = _Fixture();
      await pumpApp(tester, await f.overrides(tester, plus: free(0)), home: const LogFoodScreen(dayKey: day, meal: 'Lunch'), size: const Size(390, 1400));
      expect(find.descendant(of: invite, matching: find.textContaining('come back on', findRichText: true)), findsOneWidget);
      expect(find.byKey(const Key('food-describe')), findsNothing, reason: 'nothing to send until it resets');
      expect(find.text('Uses 1 AI request when you send.'), findsNothing);
      await tester.enterText(find.byKey(const Key('food-search')), 'eggs');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('common-eggs')).hitTestable(), findsOneWidget, reason: 'manual search stays');
    });

    testWidgets('at the limit with a meal already prepared: Finish my meal opens it, and it can still be logged', (tester) async {
      final f = _Fixture();
      await pumpApp(tester, await f.overrides(tester, plus: free(0)), home: const DayCoachScreen(day: day, meal: 'Lunch'), size: const Size(390, 1600));
      expect(find.textContaining('No AI requests left this month · they come back on'), findsOneWidget);
      f.ai.reply = (r) async => ate([said('egg', 2, 'piece', 'egg')]); // read before the limit was reached
      await _say(tester, 'two eggs');
      Navigator.of(tester.element(find.byType(DayCoachScreen))).push(MaterialPageRoute<bool>(builder: (_) => const LogFoodScreen(dayKey: day, meal: 'Lunch')));
      await _settle(tester);
      expect(find.text('Finish my meal'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('food-describe')));
      await _tap(tester, _keyed('day-meal-review-').last);
      await _tap(tester, find.byKey(const Key('meal-log')));
      expect(f.fakes.journal.meals.single.single.quantity, 2, reason: 'Log meal is never behind the allowance');
      expect(f.ai.requests.length, 1);
    });

    for (final (name, plus, unknown, caps, offered) in [
      ('unknown (no count yet)', null, true, const {'coach.daily', 'coach.meal-log', 'food.search'}, true),
      ('an older server without meal reading', free(14), false, const {'coach.daily', 'food.search'}, false),
      ('a server not reached yet (offline at start)', free(14), false, null, true),
    ]) {
      testWidgets('the invitation is honest when the allowance or server is $name', (tester) async {
        final f = _Fixture();
        await pumpApp(tester, await f.overrides(tester, plus: plus, plusUnknown: unknown, caps: caps), home: const LogFoodScreen(dayKey: day, meal: 'Lunch'), size: const Size(390, 1400));
        expect(find.byKey(const Key('food-describe')), offered ? findsOneWidget : findsNothing);
        expect(find.textContaining('isn’t available on this server yet', findRichText: true), offered ? findsNothing : findsOneWidget);
        expect(find.byKey(const Key('food-search')).hitTestable(), findsOneWidget);
        expect(f.ai.requests, isEmpty);
      });
    }

    for (final (lang, size, text, mode) in [
      ('en', const Size(390, 844), 1.0, ThemeMode.light), ('en', const Size(390, 844), 1.0, ThemeMode.dark), ('en', const Size(320, 640), 2.0, ThemeMode.light),
      ('fr-CA', const Size(390, 844), 1.0, ThemeMode.dark), ('fr-CA', const Size(320, 640), 2.0, ThemeMode.light),
      ('ar', const Size(390, 844), 1.0, ThemeMode.light), ('ar', const Size(320, 640), 2.0, ThemeMode.dark),
    ]) {
      testWidgets('$lang ${mode.name} ${size.width.toInt()} px at $text× text: the invitation fits, and typing brings the results under the field', (tester) async {
        final f = _Fixture();
        final store = AppearanceStore(MemorySecretStore())..mode = mode;
        final c = await pumpApp(tester, [...await f.overrides(tester), appearanceStoreProvider.overrideWithValue(store)], home: const LogFoodScreen(dayKey: day, meal: 'Lunch'), size: size, textScale: text);
        c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(Directionality.of(tester.element(invite)), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        final title = {'en': 'What did you eat?', 'fr-CA': 'Qu’as-tu mangé?', 'ar': 'ماذا أكلت؟'}[lang]!;
        expect(find.descendant(of: invite, matching: find.text(title)), findsOneWidget);
        expect(tester.getSize(find.byKey(const Key('food-describe'))).height, greaterThanOrEqualTo(48), reason: 'targets keep their size');
        // Typing: the field comes to the top with results under it, the invitation scrolled away (not removed). At very
        // large text the field may be a short scroll below the invitation: the page scrolls, nothing shrinks.
        await tester.scrollUntilVisible(find.byKey(const Key('food-search')), 150, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('food-search')), 'eggs');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('food-search')).hitTestable(), findsOneWidget);
        expect(tester.getTopLeft(find.byKey(const Key('food-search'))).dy, lessThan(20), reason: 'the field at the top');
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(invite).dy, inInclusiveRange(0, size.height - 48), reason: 'scrolling back shows the invitation again');
      });
    }

    testWidgets('the field pinned at the top stays put when focused or the keyboard reveals it; the results stay under it', (tester) async {
      final f = _Fixture();
      await pumpApp(tester, await f.overrides(tester), home: const LogFoodScreen(dayKey: day, meal: 'Lunch'));
      await tester.enterText(find.byKey(const Key('food-search')), 'chicken breast');
      await tester.pumpAndSettle();
      final page = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final at = page.pixels;
      tester.renderObject(find.byType(EditableText)).showOnScreen(); // what focus, the caret and the keyboard ask for
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(page.pixels, at, reason: 'already in view at the top: focus and the keyboard scroll nothing');
      expect(find.byKey(const Key('food-scan')).hitTestable(), findsOneWidget);
      tester.view.resetViewInsets();
    });

    testWidgets('a screen reader hears the guide, then the invitation, its action and its cost, then search', (tester) async {
      final semantics = tester.ensureSemantics();
      final f = _Fixture();
      await pumpApp(tester, await f.overrides(tester), home: const LogFoodScreen(dayKey: day, meal: 'Lunch'));
      final labels = [for (final n in tester.semantics.simulatedAccessibilityTraversal()) n.label];
      int at(String s) => labels.indexWhere((l) => l.contains(s));
      // The bubble's words (title, promise, cost) are read together, then its button, then search.
      final order = [at('Help with finding a food'), at('What did you eat?'), at('before anything is logged'), at('Uses 1 AI request when you send.'), at('Describe my meal'), at('Scan barcode')];
      expect(order.every((i) => i >= 0), isTrue, reason: '$labels');
      expect(order, [...order]..sort(), reason: 'read in this order: $labels');
      semantics.dispose();
    });
  });

  group('renders', () {
    if (!_render) {
      test('Add food invitation renders are skipped without GOHARD_RENDER', () {});
      return;
    }
    setUpAll(() async {
      final inter = FontLoader('Inter');
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        inter.addFont(File('assets/fonts/Inter-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
      }
      await inter.load();
      await (FontLoader(serif)..addFont(File('assets/fonts/DMSerifDisplay-Regular.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
      await loadArabicFonts();
      final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
    });

    for (final (name, lang, size, text, mode, guide, tabs) in [
      ('en-leon-light-390', 'en', const Size(390, 844), 1.0, ThemeMode.light, CoachGuide.leon, true),
      ('en-leona-dark-390', 'en', const Size(390, 844), 1.0, ThemeMode.dark, CoachGuide.leona, true),
      ('en-leon-320-2x', 'en', const Size(320, 640), 2.0, ThemeMode.light, CoachGuide.leon, true),
      ('fr-leona-light-390', 'fr-CA', const Size(390, 844), 1.0, ThemeMode.light, CoachGuide.leona, true),
      ('ar-leon-dark-320-2x', 'ar', const Size(320, 640), 2.0, ThemeMode.dark, CoachGuide.leon, true),
      ('en-coach-off-light-390', 'en', const Size(390, 844), 1.0, ThemeMode.light, CoachGuide.leon, false),
    ]) {
      testWidgets('Add food invitation: $name', (tester) async {
        final store = AppearanceStore(MemorySecretStore())
          ..accent = Accent.blue
          ..mode = mode;
        final f = _Fixture();
        final c = await pumpApp(tester, [...await f.overrides(tester), appearanceStoreProvider.overrideWithValue(store)], home: const LogFoodScreen(dayKey: day, meal: 'Lunch'),
            size: size, textScale: text, insets: phoneInsets, settle: false);
        c.read(devicePrefsProvider.notifier).setMotion(MotionPref.reduced);
        c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
        c.read(coachPrefsProvider.notifier).setGuide(guide);
        if (!tabs) c.read(coachPrefsProvider.notifier).setOnTabs(false);
        c.read(rigImageProvider(guide));
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!;
        await tester.runAsync(() async {
          final file = File('../docs/evidence/add-food-invitation/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
        });
        expect(tester.takeException(), isNull);
      });
    }

    // The reported sentence's card, after the thigh was answered: the potato choice, "Not said" and the actions.
    for (final (name, lang, size, text, mode, words) in [
      ('card-en-light-390', 'en', const Size(390, 1600), 1.0, ThemeMode.light, ['cooked chicken thighs', 'cooked potatoes']),
      ('card-fr-dark-390', 'fr-CA', const Size(390, 1600), 1.0, ThemeMode.dark, ['cuisses de poulet cuites', 'pommes de terre cuites']),
      ('card-ar-light-320-2x', 'ar', const Size(320, 3200), 2.0, ThemeMode.light, ['أفخاذ دجاج مطبوخة', 'بطاطس مطبوخة']),
    ]) {
      testWidgets('described meal card: $name', (tester) async {
        final store = AppearanceStore(MemorySecretStore())
          ..accent = Accent.blue
          ..mode = mode;
        final f = _Fixture();
        final c = await pumpApp(tester, [...await f.overrides(tester), appearanceStoreProvider.overrideWithValue(store)], home: const DayCoachScreen(day: day, meal: 'Lunch'),
            size: size, textScale: text, insets: phoneInsets, settle: false);
        c.read(devicePrefsProvider.notifier).setMotion(MotionPref.reduced);
        c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
        await _settle(tester);
        f.ai.reply = (r) async => ate([
          {...said('chicken thighs', 100, 'g'), 'label': words[0], 'evidence': '100 g ${words[0]}'},
          {...said('potatoes', 130, 'g'), 'label': words[1], 'evidence': '130 g ${words[1]}'},
        ]);
        await _say(tester, '100 g ${words[0]}, 130 g ${words[1]}');
        await _tap(tester, _keyed('day-meal-pick-').first);
        await _toEnd(tester);
        await tester.drag(find.byType(Scrollable).first, Offset(0, size.height * 0.55));
        await tester.pumpAndSettle();
        final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!;
        await tester.runAsync(() async {
          final file = File('../docs/evidence/food-resolution/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
        });
        expect(tester.takeException(), isNull);
      });
    }
  });
}

const _render = bool.fromEnvironment('GOHARD_RENDER');
