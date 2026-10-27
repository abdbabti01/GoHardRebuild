// Help with today and food on screen (docs/COACH.md › Help with today): the real screens over fixed records and a real
// local database for the conversation, with the server's reading of typed words SCRIPTED (no AI, no network): these
// tests prove what the app does with an answer, never that a live model reads well.
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
import 'package:gohard_rebuild/features/nutrition/food_form.dart' show FoodFormScreen;
import 'package:gohard_rebuild/features/nutrition/saved_meals.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals_screens.dart' show MealReviewScreen;

import 'food_fakes.dart';
import 'support.dart';
import 'ui_support.dart';

const day = '2026-10-27';

Json _whey = {'source': 'user', 'sourceId': 'whey', 'name': 'Whey', 'basis': 'serving', 'nutrients': {'calories': 120, 'protein': 24, 'carbs': 3, 'fat': 1.5}, 'servings': [{'label': '1 scoop', 'grams': 30}]};
Json shakeMeal({double scoops = 2, String name = 'Breakfast shake'}) =>
    {'id': 'm-shake', 'revision': 1, 'isDeleted': false, 'body': {'kind': 'meal', 'name': name, 'components': [{'item': _whey, 'quantity': scoops, 'unit': 'serving:0', 'name': 'Whey', 'amount': '$scoops scoops'}]}};
Json _yogurt = {'id': 'f-yog', 'isFavourite': true, 'isDeleted': false,
    'item': {'source': 'off', 'sourceId': 'yog', 'name': 'Greek yogurt', 'basis': '100g', 'nutrients': {'calories': 59, 'protein': 10.3, 'carbs': 3.6, 'fat': 0.4}, 'servings': [{'label': '1 pot', 'grams': 170}]}};
Json food(String id, {double? kcal, double? protein}) =>
    {'id': id, 'dayKey': day, 'meal': 'Breakfast', 'name': 'Toast', 'amountDescription': '1 slice', 'macros': {'calories': kcal, 'protein': protein, 'carbs': null, 'fat': null}, 'isDeleted': false};

/// The server's reading of typed words, scripted. Every request is recorded; nothing is sent anywhere.
class ScriptedDay implements DayCoachClient {
  final requests = <Json>[];
  Future<DayIntent> Function(Json request) reply = (r) async => const DayIntent('today', ai: true);
  @override
  Future<DayIntent> interpret(Json request) {
    requests.add(request);
    return reply(request);
  }
}

class _Caps extends CompatibilityController {
  _Caps(this.caps);
  final Set<String>? caps;
  @override
  Compatibility build() => Compatibility(capabilities: caps);
}

class _Fixture {
  final store = TestStore();
  final ai = ScriptedDay();
  final fakes = FoodFakes();
  final meals = StreamController<List<Stored<SavedMeal>>>.broadcast();
  List<Json> savedMeals = [shakeMeal()];

  Stored<SavedMeal> _row(Json m) => stored(SavedMeal(m), Kinds.savedMeal, m['id'] as String, m);
  void setMeals(List<Json> m) {
    savedMeals = m;
    meals.add([for (final x in m) _row(x)]);
  }

  Future<List<Override>> overrides(WidgetTester tester, {int? proteinGoal = 140, List<Json>? journal, Set<String>? caps = const {'coach.daily', 'food.saved-meals'}, int pending = 0, List<Json>? foods}) async {
    final db = store.open();
    addTearDown(() async {
      await db.close();
      store.dispose();
    });
    return [
      ...(await tester.runAsync(() => overridesFor(day: day, proteinGoal: proteinGoal, food: journal ?? [food('a', kcal: 400, protein: 80)], savedFoods: foods ?? [_yogurt], pending: pending)))!,
      ...fakes.overrides,
      dbProvider.overrideWithValue(db),
      syncProvider.overrideWith((ref) {
        final engine = SyncEngine(db, Api(FakeServer(), ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
        ref.onDispose(engine.dispose);
        return engine;
      }),
      savedMealsProvider.overrideWith((ref) async* {
        yield [for (final m in savedMeals) _row(m)];
        yield* meals.stream;
      }),
      mealDraftsProvider.overrideWith((ref) => Stream.value(const {})),
      dayCoachClientProvider.overrideWithValue(ai),
      compatibilityProvider.overrideWith(() => _Caps(caps)),
    ];
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  // The conversation is a lazy list: an item far down is built only once scrolled to.
  if (f.evaluate().isEmpty) await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Send (or Retry), then real time for the local flush that goes first (database I/O is not fake time).
Future<void> _sendTap(WidgetTester tester, [Key key = const Key('day-send')]) async {
  await _tap(tester, find.byKey(key));
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pumpAndSettle();
  }
}

String _answerText(WidgetTester tester) => [for (final t in tester.widgetList<Text>(find.byWidgetPredicate((w) => w is Text && w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-answer-')))) t.data].join('\n');

void main() {
  testWidgets('suggested requests answer from the records with no request to the server; the reply says what it used', (tester) async {
    final f = _Fixture();
    await pumpApp(tester, await f.overrides(tester), home: const DayCoachScreen(day: day), size: const Size(390, 1600));
    expect(find.byKey(const Key('day-privacy')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('day-chip-goal')));
    expect(f.ai.requests, isEmpty, reason: 'a built-in request never asks the AI');
    expect(_answerText(tester), contains('80 g of your 140 g protein goal is logged: 60 g to go.'));
    expect(find.text('Built in · from your records'), findsOneWidget);
    expect(find.text('Breakfast shake'), findsOneWidget);
    expect(find.text('240 kcal · 48 g protein'), findsOneWidget);
    expect(find.text('Adds 48 g protein: 128 of 140 g logged after this.'), findsOneWidget);
    expect(f.fakes.journal.saved.isEmpty && f.fakes.journal.meals.isEmpty, isTrue, reason: 'answering logs nothing');
  });

  testWidgets('Review opens the exact portion and day; cancelling logs nothing; Log meal logs once through the meal batch', (tester) async {
    final f = _Fixture();
    await pumpApp(tester, await f.overrides(tester, foods: const []), home: const DayCoachScreen(day: day), size: const Size(390, 1600));
    await _tap(tester, find.byKey(const Key('day-chip-goal')));
    await _tap(tester, find.byKey(const Key('day-chip-portionsmaller')));
    expect(find.text('180 kcal · 36 g protein'), findsOneWidget, reason: '0.75× of the saved two scoops');
    await _tap(tester, find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-review-')).last);
    final review = tester.widget<MealReviewScreen>(find.byType(MealReviewScreen));
    expect((review.dayKey, review.initialFactor, review.saved?.id), (day, 0.75, 'm-shake'));
    expect(find.text('0.75×'), findsOneWidget, reason: 'the custom multiplier is selected');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(f.fakes.journal.meals, isEmpty, reason: 'leaving the review logs nothing');
    await _tap(tester, find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-review-')).last);
    await _tap(tester, find.byKey(const Key('meal-log')));
    expect(f.fakes.journal.meals.length, 1);
    final logged = f.fakes.journal.meals.single.single;
    expect((logged.dayKey, logged.quantity, logged.calories, logged.protein), (day, 1.5, 180.0, 36.0));
  });

  testWidgets('a saved food opens its own amount form at the suggested amount', (tester) async {
    final f = _Fixture()..savedMeals = [];
    await pumpApp(tester, await f.overrides(tester), home: const DayCoachScreen(day: day), size: const Size(390, 1600));
    await _tap(tester, find.byKey(const Key('day-chip-suggest')));
    expect(find.text('Greek yogurt'), findsOneWidget);
    await _tap(tester, find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-review-')).first);
    final form = tester.widget<FoodFormScreen>(find.byType(FoodFormScreen));
    expect((form.draft.dayKey, form.draft.quantity, form.draft.unitId, form.draft.protein), (day, 1.0, 'serving:0', 17.51));
    expect(f.fakes.journal.saved, isEmpty);
  });

  testWidgets('typed words: one request with no journal values; the reply is worked out here; a changed record makes it stale', (tester) async {
    final f = _Fixture();
    f.ai.reply = (r) async => const DayIntent('portion', items: [(kind: ItemKind.meal, id: 'm-shake')], factor: 0.5, ai: true);
    await pumpApp(tester, await f.overrides(tester), home: const DayCoachScreen(day: day), size: const Size(390, 1600));
    await tester.enterText(find.byKey(const Key('day-input')), 'My breakfast shake, but half');
    await _sendTap(tester);
    final sent = f.ai.requests.single;
    expect((sent['dayKey'], sent['isToday'], sent['question']), (day, true, 'My breakfast shake, but half'));
    expect(sent.keys.toSet(), {'requestId', 'question', 'language', 'dayKey', 'isToday', 'history', 'focus', 'contextRevision'}, reason: 'no journal value, goal or total is sent');
    expect(sent['history'], isEmpty);
    expect(sent['focus'], isEmpty);
    expect(find.text('Request read by AI · numbers from your records'), findsOneWidget);
    expect(find.text('120 kcal · 24 g protein'), findsOneWidget);

    f.setMeals([shakeMeal(scoops: 3)]);
    await tester.pumpAndSettle();
    expect(find.text('Your records changed since this answer.'), findsOneWidget);
    await _tap(tester, find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-review-')).last);
    expect(find.byType(MealReviewScreen), findsNothing, reason: 'a stale suggestion opens no review');
    await _tap(tester, find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-recalc-')));
    expect(find.text('180 kcal · 36 g protein'), findsOneWidget, reason: 'half of the three scoops now saved');
    expect(find.text('Your records changed since this answer.'), findsNothing);
    expect(f.ai.requests.length, 1, reason: 'recalculating asks nothing');

    // A follow-up names the last suggestion as its focus, by ID only. (First the toast goes, so the field can be tapped.)
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    f.ai.reply = (r) async => const DayIntent('portion', change: 'smaller', ai: true);
    await tester.enterText(find.byKey(const Key('day-input')), 'smaller');
    await _sendTap(tester);
    expect(f.ai.requests.last['focus'], [{'kind': 'meal', 'id': 'm-shake'}]);
    expect(_answerText(tester), contains("That's the smallest practical portion I can suggest for this."), reason: 'half is the smallest step; nothing below it is invented');
    expect(find.text('180 kcal · 36 g protein'), findsNWidgets(2), reason: 'the card stays at the half');
  });

  testWidgets('a failure keeps the question with Retry under the same request; built-in help still works; no capability means no request', (tester) async {
    final f = _Fixture();
    f.ai.reply = (r) async => throw const AskFailure(AskProblem.busy);
    await pumpApp(tester, await f.overrides(tester), home: const DayCoachScreen(day: day), size: const Size(390, 1600));
    await tester.enterText(find.byKey(const Key('day-input')), 'What should I eat?');
    await _sendTap(tester);
    expect(find.byKey(const Key('day-problem')), findsOneWidget);
    expect(find.text('What should I eat?'), findsOneWidget);
    f.ai.reply = (r) async => const DayIntent('suggest', ai: true);
    await _sendTap(tester, const Key('day-retry'));
    expect(f.ai.requests.map((r) => r['requestId']).toSet().length, 1, reason: 'Retry reuses the request ID');
    expect(find.text('Breakfast shake'), findsOneWidget);
  });

  testWidgets('an older server: the field says so, nothing is sent, and the suggested requests still answer', (tester) async {
    final f = _Fixture();
    await pumpApp(tester, await f.overrides(tester, caps: {'coach.ask'}), home: const DayCoachScreen(day: day), size: const Size(390, 1600));
    expect(find.byKey(const Key('day-no-ai')), findsOneWidget);
    expect(find.byKey(const Key('day-input')), findsNothing);
    await _tap(tester, find.byKey(const Key('day-chip-today')));
    expect(_answerText(tester), contains('Foods in the journal: 1'));
    expect(f.ai.requests, isEmpty);
  });

  testWidgets('no goal: the coach says so and offers Edit goals; nothing is written', (tester) async {
    final f = _Fixture();
    final c = await pumpApp(tester, await f.overrides(tester, proteinGoal: null), home: const DayCoachScreen(day: day), size: const Size(390, 1600));
    await _tap(tester, find.byKey(const Key('day-chip-goal')));
    expect(_answerText(tester), contains("You haven't set a daily protein goal."));
    expect(find.text('Edit goals'), findsOneWidget);
    expect(find.text('Breakfast shake'), findsNothing, reason: 'no target is invented to rank against');
    expect(f.fakes.profiles.toString(), isNot(contains('proteinGoal')));
    expect(c.read(profileProvider).value?.proteinGoal, isNull);
  });

  testWidgets('the conversation survives closing the screen; Today opens it and opening sends nothing', (tester) async {
    final f = _Fixture();
    final o = await f.overrides(tester);
    await pumpApp(tester, o, home: const DayCoachScreen(day: day), size: const Size(390, 1600));
    await _tap(tester, find.byKey(const Key('day-chip-recorded')));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await pumpApp(tester, o, home: const DayCoachScreen(day: day), size: const Size(390, 1600));
    await tester.pumpAndSettle();
    expect(_answerText(tester), contains('This is what was logged'));
    expect(f.ai.requests, isEmpty);
  });

  for (final (name, size, text, lang) in [('narrow-large-fr', const Size(320, 900), 1.6, 'fr'), ('arabic', const Size(390, 900), 1.0, 'ar')]) {
    testWidgets('$name: cards and actions stack, nothing overflows', (tester) async {
      final f = _Fixture();
      final o = await f.overrides(tester);
      final c = await pumpApp(tester, o, home: const DayCoachScreen(day: day), size: size, textScale: text);
      c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang == 'fr' ? 'fr-CA' : lang));
      await tester.pumpAndSettle();
      expect(Directionality.of(tester.element(find.byKey(const Key('day-context')))), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      await _tap(tester, find.byKey(const Key('day-chip-goal')));
      expect(tester.takeException(), isNull);
      expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-review-')), findsWidgets);
    });
  }
}
