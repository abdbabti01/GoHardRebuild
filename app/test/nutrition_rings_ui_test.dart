import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/widgets.dart' show ProgressRail, ProgressRing;
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/me/reminders.dart' show Notice, ReminderScheduler, reminderSchedulerProvider;
import 'package:gohard_rebuild/features/nutrition/intake_history.dart' show GoalDay, goalDaysProvider;
import 'package:gohard_rebuild/features/nutrition/nutrient_coverage.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_surface.dart';
import 'package:gohard_rebuild/l10n/app_localizations.dart' show lookupAppLocalizations;

import 'food_fakes.dart';
import 'support.dart';
import 'ui_support.dart';

/// The calorie and protein rings on Today and Eat and the macro composition (docs/NUTRITION_RINGS.md): every state the
/// shared assessment has, the capped arc with the real percentage, no goal vs nothing logged vs a recorded zero,
/// independent missing values, earlier days only against their own recorded goal, one description per chart, large text
/// and Arabic, and Eat's actions. Fixture data only.

const day = '2026-10-30';
const before = '2026-10-29';
final l = lookupAppLocalizations(const Locale('en'));

class _Quiet implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool?> notificationsAllowed() async => true;
  @override
  Future<void> replaceAll(List<Notice> notices) async {}
}

Json _food(String id, String d, {num? kcal, num? protein, num? carbs, num? fat}) => foodEntry(id, d, 'Lunch', 'Pasta', '1 plate', calories: kcal, protein: protein, carbs: carbs, fat: fat);

Future<void> _openEat(WidgetTester tester, {List<Json> food = const [], int? kcal, int? protein, Map<String, GoalDay>? goals, Size size = const Size(390, 1600), double text = 1, String? lang}) async {
  final store = TestStore(), db = store.open();
  addTearDown(() async {
    await db.close();
    store.dispose();
  });
  final c = await pumpApp(tester, [
    ...(await tester.runAsync(() => overridesFor(day: day, food: food, calorieGoal: kcal, proteinGoal: protein)))!,
    ...FoodFakes().overrides,
    reminderSchedulerProvider.overrideWithValue(_Quiet()),
    dbProvider.overrideWithValue(db),
    syncProvider.overrideWith((ref) {
      final engine = SyncEngine(db, Api(FakeServer(), ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
      ref.onDispose(engine.dispose);
      return engine;
    }),
    if (goals != null) goalDaysProvider.overrideWith((ref) => Stream.value(goals)),
  ], size: size, textScale: text);
  for (final id in ['eat.first', 'eat.saved.new', 'eat.saved.shortcut', 'eat.history', 'eat.meals', 'eat.out', 'eat.habits', 'eat.reminders', 'eat.trends']) {
    c.read(coachPrefsProvider.notifier).markSeen('one', id);
  }
  if (lang != null) c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
  await tester.tap(find.byKey(const Key('nav-eat')));
  await tester.pumpAndSettle();
}

/// Just the summary (Eat's larger form unless [today]), for the states.
Future<void> _summary(WidgetTester tester, List<Json> food, {int? kcal, int? protein, bool today = false}) => pumpApp(tester, const [],
    home: Scaffold(
        body: SingleChildScrollView(
            child: NutritionSummary(coverage: NutrientCoverage.calculate([for (final f in food) FoodEntry(f)]), calorieGoal: kcal, proteinGoal: protein, keyPrefix: today ? 'today' : 'eat', prominent: !today))));

String? _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key), skipOffstage: false)).data;
double _ring(WidgetTester tester, String key) => tester.widget<ProgressRing>(find.byKey(Key(key))).value;

void main() {
  group('states (shared assessment, no thresholds of its own)', () {
    for (final (name, kcal, ring, percent, status) in [
      ('recorded zero', 0, 0.0, '0%', 'Room remaining'),
      ('below', 1100, 1100 / 2300, '47%', 'Room remaining'),
      ('approaching', 1900, 1900 / 2300, '82%', 'Approaching target'),
      ('reached', 2300, 1.0, '100%', 'Target reached'),
      ('above: the arc stops at one circle, the words keep the real share and excess', 2461, 1.0, '107%', '161 kcal over target'),
    ]) {
      testWidgets('calories $name', (tester) async {
        await _summary(tester, [_food('a', day, kcal: kcal, protein: 0)], kcal: 2300, protein: 160);
        expect(_ring(tester, 'eat-goal-calories'), closeTo(ring, 1e-9));
        expect(_text(tester, 'eat-goal-calories-percent'), percent);
        expect(_text(tester, 'eat-goal-calories-status'), status);
        expect(find.byKey(const Key('eat-goal-calories-left')), kcal < 2300 ? findsOneWidget : findsNothing, reason: 'an exact remainder only below the goal');
        expect(find.text('0'), name == 'recorded zero' ? findsWidgets : findsOneWidget, reason: 'protein: an entered zero is a known zero');
      });
    }

    testWidgets('protein above its goal keeps its own meaning and colour: reached, never red', (tester) async {
      await _summary(tester, [_food('a', day, kcal: 1000, protein: 175)], kcal: 2300, protein: 160);
      expect(_ring(tester, 'eat-goal-protein'), 1.0);
      expect((_text(tester, 'eat-goal-protein-percent'), _text(tester, 'eat-goal-protein-status')), ('110%', 'Goal reached · 15 g above target'));
      // Calories below their goal are green; protein above its goal is the same green, never the calories' red.
      expect(tester.widget<ProgressRing>(find.byKey(const Key('eat-goal-protein'))).color, tester.widget<ProgressRing>(find.byKey(const Key('eat-goal-calories'))).color);
    });

    testWidgets('no goal: the amount and a neutral disc, no ring, no percentage, nothing invented', (tester) async {
      await _summary(tester, [_food('a', day, kcal: 1650, protein: 120)]);
      expect(find.byType(ProgressRing), findsNothing);
      expect(find.text('No goal'), findsNWidgets(2));
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('1,650'), findsOneWidget);
    });

    testWidgets('missing calories do not touch protein, and missing protein does not touch calories', (tester) async {
      await _summary(tester, [_food('a', day, protein: 30)], kcal: 2300, protein: 160);
      expect((_text(tester, 'eat-goal-calories-status'), find.text('—').evaluate().length), ('No value entered yet', 1));
      expect(find.byKey(const Key('eat-goal-calories-percent')), findsNothing, reason: 'no share of a value nobody entered');
      expect(_text(tester, 'eat-goal-protein-left'), '130 g left', reason: 'protein is complete, so its remainder is real');

      await _summary(tester, [_food('a', day, kcal: 900)], kcal: 2300, protein: 160);
      expect(_text(tester, 'eat-goal-protein-status'), 'No value entered yet');
      expect(_text(tester, 'eat-goal-calories-left'), '1,400 kcal left');

      // A partial calorie sum: "Known intake", a neutral arc, no remainder.
      await _summary(tester, [_food('a', day, kcal: 900, protein: 40), _food('b', day, protein: 20)], kcal: 2300, protein: 160);
      expect(_text(tester, 'eat-goal-calories-status'), 'Known intake');
      expect(find.byKey(const Key('eat-goal-calories-left')), findsNothing);
      expect(_text(tester, 'eat-goal-protein-left'), '100 g left');
    });
  });

  testWidgets('Eat: no entries is words (no ring, no zero); a recorded zero is a ring at 0', (tester) async {
    await _openEat(tester, kcal: 2300, protein: 160);
    expect(find.byType(ProgressRing).hitTestable(), findsNothing, reason: 'nothing logged is not zero eaten');
    expect(find.text(l.eatNoFoodLoggedYet), findsOneWidget);
    expect(find.byKey(const Key('eat-macros')), findsNothing);

    await _openEat(tester, food: [_food('a', day, kcal: 0, protein: 0, carbs: 0, fat: 0)], kcal: 2300, protein: 160);
    expect(_ring(tester, 'eat-goal-calories'), 0);
    expect(_text(tester, 'eat-goal-calories-percent'), '0%');
    expect(find.text(l.nrMacroZero), findsOneWidget, reason: 'all macros zero: a neutral composition, no division by zero');
  });

  testWidgets('Eat: the recorded calories stay as logged beside a composition that adds up differently', (tester) async {
    await _openEat(tester, food: [_food('a', day, kcal: 2461, protein: 175, carbs: 260, fat: 95)], kcal: 2300, protein: 160);
    expect(find.text('2,461'), findsOneWidget);
    expect(_text(tester, 'eat-goal-calories-status'), '161 kcal over target', reason: 'judged on the recorded 2,461, not the macros\' 2,595');
    expect((_text(tester, 'eat-macro-protein-percent'), _text(tester, 'eat-macro-carbs-percent'), _text(tester, 'eat-macro-fat-percent')), ('27%', '40%', '33%'));
    expect(find.text(l.nrMacroDiffers('2,461')), findsOneWidget);
    expect(find.byType(ProgressRail).hitTestable(), findsNothing, reason: 'the bars are gone; no duplicate measure');
  });

  testWidgets('Eat: missing fat leaves protein exact; the composition shows known grams and no split', (tester) async {
    await _openEat(tester, food: [_food('a', day, kcal: 900, protein: 40, carbs: 100, fat: 20), _food('b', day, kcal: 300, protein: 20, carbs: 30)], kcal: 2300, protein: 160);
    expect(_text(tester, 'eat-goal-protein-left'), '100 g left');
    expect(_text(tester, 'eat-goal-calories-left'), '1,100 kcal left');
    expect(_text(tester, 'eat-macro-fat'), '20 g · known');
    expect(find.byKey(const Key('eat-macro-fat-percent')), findsNothing);
    expect(find.text(l.nrMacroPartial), findsOneWidget);
  });

  group('earlier days', () {
    Future<void> previousDay(WidgetTester tester) async {
      await tester.tap(find.byTooltip(l.eatPreviousDay));
      await tester.pumpAndSettle();
    }

    testWidgets('with a recorded goal: compared with that day\'s goal', (tester) async {
      await _openEat(tester, food: [_food('y', before, kcal: 1800, protein: 100)], kcal: 2300, protein: 160, goals: {before: const GoalDay(2000, 120)});
      await previousDay(tester);
      expect(_text(tester, 'eat-goal-calories-left'), '200 kcal left', reason: 'against 2,000 that day, not today\'s 2,300');
      expect(_text(tester, 'eat-goal-protein-left'), '20 g left');
    });

    for (final (name, goals) in [('without a record', const <String, GoalDay>{}), ('with goals that changed that day', {before: const GoalDay(2000, 120, changed: true)})]) {
      testWidgets('$name: never today\'s goal', (tester) async {
        await _openEat(tester, food: [_food('y', before, kcal: 1800, protein: 100)], kcal: 2300, protein: 160, goals: goals);
        await previousDay(tester);
        expect(find.byType(ProgressRing).hitTestable(), findsNothing);
        expect(find.text(l.nrNoGoalThatDay), findsNWidgets(2));
        expect(find.textContaining('2,300'), findsNothing, reason: 'today\'s goal is never laid over an earlier day');
      });
    }
  });

  testWidgets('one description per ring and per composition; no duplicate announcements', (tester) async {
    final handle = tester.ensureSemantics();
    await _openEat(tester, food: [_food('a', day, kcal: 1650, protein: 120, carbs: 180, fat: 50)], kcal: 2300, protein: 160);
    expect(find.bySemanticsLabel('Calories 1,650 kilocalories, goal 2,300 kilocalories, 71%, Room remaining, 650 kilocalories remaining'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Protein 120 grams, goal 160 grams, 75%, Below target, 40 grams remaining$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Recorded macro composition\. Protein 120 grams, 29%\. Carbs 180 grams, 44%\. Fat 50 grams, 27%\. Percentages of the 1,650 kcal')), findsOneWidget);
    // The figures, the arcs and the legend are not read again on their own.
    for (final alone in ['1,650', 'kcal', '71%', 'Calories', 'Carbs', '650 kcal left', 'Calories goal']) {
      expect(find.bySemanticsLabel(alone), findsNothing, reason: alone);
    }
    handle.dispose();
  });

  for (final lang in ['fr-CA', 'ar']) {
    testWidgets('$lang at 320 px with 2× text: rings and composition fit, nothing shrunk', (tester) async {
      await _openEat(tester, food: [_food('a', day, kcal: 1650, protein: 120, carbs: 180, fat: 50), _food('b', day, kcal: 200)], kcal: 2300, protein: 160,
          size: const Size(320, 2600), text: 2, lang: lang);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('eat-goal-calories')), findsOneWidget);
      expect(find.byKey(const Key('eat-macros')), findsOneWidget);
      // With little room the ring sits above its figures instead of squeezing them.
      expect(tester.getTopLeft(find.byKey(const Key('eat-goal-calories-status'))).dy, greaterThan(tester.getBottomLeft(find.byKey(const Key('eat-goal-calories'))).dy));
    });
  }

  testWidgets('Arabic: the ring is on the reading side, its figures after it', (tester) async {
    await _openEat(tester, food: [_food('a', day, kcal: 1650, protein: 120, carbs: 180, fat: 50)], kcal: 2300, protein: 160, lang: 'ar');
    expect(tester.getCenter(find.byKey(const Key('eat-goal-calories'))).dx, greaterThan(tester.getCenter(find.byKey(const Key('eat-goal-calories-status'))).dx));
    expect(tester.getCenter(find.byKey(const Key('eat-macro-donut'))).dx, greaterThan(tester.getCenter(find.byKey(const Key('eat-macro-carbs'))).dx));
  });

  testWidgets('Eat\'s actions still work beside the rings: Log food, Saved meals & recipes, Edit goals', (tester) async {
    await _openEat(tester, food: [_food('a', day, kcal: 1650, protein: 120, carbs: 180, fat: 50)], kcal: 2300, protein: 160);
    Future<void> open(String key) async {
      final target = find.byKey(Key(key)).hitTestable(at: Alignment.center).evaluate().isEmpty ? find.byKey(Key(key)).last : find.byKey(Key(key)).hitTestable();
      await tester.runAsync(() => Scrollable.ensureVisible(tester.element(target), alignment: 0.5));
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> back() async {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await open('log-food');
    expect(find.byKey(const Key('food-search')), findsOneWidget);
    await back();
    await open('eat-saved-meals');
    expect(find.byKey(const Key('meals-new')), findsOneWidget);
    await back();
    await open('eat-goals');
    expect(find.byKey(const Key('goal-calories')), findsOneWidget);
  });
}
