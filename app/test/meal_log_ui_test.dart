// Describe your meal on screen (docs/FOOD_DATA.md › Describe your meal): the real Add food, coach and meal review screens
// over a real local database for the conversation, the bundled foods for matching, and the server's reading of the words
// SCRIPTED (no AI, no network): these tests prove what the app does with an answer, never that a live model reads well.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/compatibility.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/coach/coach_client.dart' show AskFailure, AskProblem;
import 'package:gohard_rebuild/features/coach/day_coach.dart';
import 'package:gohard_rebuild/features/coach/day_coach_screen.dart';
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
    expect(find.text('Which chicken?'), findsOneWidget, reason: 'raw chicken is breast or thigh: the person says which');
    await _tap(tester, find.textContaining('Chicken breast (Raw'));
    await _tap(tester, _keyed('day-meal-cooked-').first);
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
    testWidgets('chicken breast: raw and cooked from the phone, no wider search, no AI; a misspelling is corrected and said', (tester) async {
      final discovery = ScriptedDiscovery(results: [
        FoodItem({'source': 'usda', 'sourceId': '900101', 'name': 'CHICKEN BREAST', 'brand': 'TYSON', 'basis': '100g', 'nutrients': {'calories': 110, 'protein': 23}, 'servings': []}),
      ]);
      final f = _Fixture(discovery: discovery);
      await pumpApp(tester, await f.overrides(tester), home: const LogFoodScreen(dayKey: day, meal: 'Lunch'), size: const Size(390, 2400));
      await tester.enterText(find.byKey(const Key('food-search')), 'chicken breast');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('common-chicken-breast')), findsOneWidget);
      expect(find.byKey(const Key('common-chicken-breast-raw')), findsOneWidget);
      expect(discovery.searches, isEmpty, reason: 'an exact everyday food on the phone asks nothing by itself');

      await tester.enterText(find.byKey(const Key('food-search')), 'chiken brest');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Showing results for “chicken breast”.'), findsOneWidget);
      expect(find.byKey(const Key('common-chicken-breast-raw')), findsOneWidget);
      expect(discovery.searches, isEmpty, reason: 'the corrected words name an everyday food exactly');

      await tester.enterText(find.byKey(const Key('food-search')), 'tyson');
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(discovery.searches, ['tyson'], reason: 'nothing on the phone names it: asked once, by itself');
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
  });
}
