import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/me/reminders.dart' show Notice, ReminderScheduler, reminderSchedulerProvider;
import 'package:gohard_rebuild/features/nutrition/intake_history.dart' show GoalDay, goalDaysProvider;
import 'package:gohard_rebuild/features/nutrition/nutrition_history.dart' show WeeklyReportScreen;
import 'package:gohard_rebuild/l10n/app_localizations.dart' show lookupAppLocalizations;

import 'food_fakes.dart';
import 'support.dart';
import 'ui_support.dart';

/// Goal colours on Today and Eat, the coach once goals are reached, and the weekly report on screen
/// (docs/EAT_COMPANION.md › Goal colours, What could I eat?, Weekly report). Fixture data only; no AI is asked.

const day = '2026-10-30'; // a Friday
final l = lookupAppLocalizations(const Locale('en'));

class _Quiet implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool?> notificationsAllowed() async => true;
  @override
  Future<void> replaceAll(List<Notice> notices) async {}
}

Future<void> _openEat(WidgetTester tester, {List<Json> food = const [], int? kcal, int? protein, Map<String, GoalDay>? goals, Size size = const Size(390, 1500), double text = 1, String? lang}) async {
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

Json _food(String id, String d, double? kcal, double? protein) => foodEntry(id, d, 'Lunch', 'Pasta', '1 plate', calories: kcal, protein: protein);

Color? _color(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key), skipOffstage: false)).style?.color;

Future<void> _openReport(WidgetTester tester) async {
  // Centred, clear of the floating navigation bar.
  await tester.runAsync(() => Scrollable.ensureVisible(tester.element(find.byKey(const Key('eat-history'))), alignment: 0.5));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('eat-history')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('trends-weekly-report')));
  await tester.pumpAndSettle();
}

/// Scrolls the report's own list until [key] is built and clear of the edges.
Future<void> _reportTo(WidgetTester tester, String key) async {
  final list = find.descendant(of: find.byType(WeeklyReportScreen), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(find.byKey(Key(key)), 250, scrollable: list);
  await tester.drag(list, const Offset(0, -150));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bars: calories above the target are red, protein above its goal stays green; words say both; Today reads the same', (tester) async {
    await _openEat(tester, food: [_food('a', day, 2150, 150)], kcal: 2000, protein: 140);
    final panel = GoColors.panelOf(GoColors.of(Accent.blue, Brightness.dark));
    expect(tester.widget<Text>(find.byKey(const Key('eat-goal-calories-status'))).data, '150 kcal over target');
    expect(tester.widget<Text>(find.byKey(const Key('eat-goal-protein-status'))).data, 'Goal reached · 10 g above target');
    expect(_color(tester, 'eat-goal-calories-status'), panel.goalRedText);
    expect(_color(tester, 'eat-goal-protein-status'), panel.goalGreenText, reason: 'exceeding protein is never red');
    expect(find.text('108%'), findsWidgets, reason: 'the real share, rounded up above the target');
    // Today's glance (tab still built) uses the same rule and words.
    expect(tester.widget<Text>(find.byKey(const Key('today-goal-calories-status'), skipOffstage: false)).data, '150 kcal over target');
    // The bar is read out with its state, not only its colour.
    final said = tester.getSemantics(find.ancestor(of: find.byKey(const Key('eat-goal-calories')), matching: find.byType(Semantics)).first);
    expect(said.label, allOf(contains('150 kcal over target'), contains('108%')));
  });

  testWidgets('incomplete calories: "Known intake", neutral, never "room remaining"', (tester) async {
    await _openEat(tester, food: [_food('a', day, 800, 40), _food('b', day, null, 10)], kcal: 2000, protein: 140);
    expect(tester.widget<Text>(find.byKey(const Key('eat-goal-calories-status'))).data, 'Known intake');
    expect(find.text('Room remaining'), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('eat-goal-protein-status'))).data, 'Below target');
  });

  testWidgets('both goals reached: said plainly, the action reads Find something to eat; the coach asks first and continuing gives options', (tester) async {
    await _openEat(tester, food: [_food('a', day, 2000, 150)], kcal: 2000, protein: 140);
    final coach = find.byKey(const Key('eat-coach'));
    expect(find.descendant(of: coach, matching: find.textContaining(l.ebAllReached, findRichText: true)), findsOneWidget);
    expect(find.descendant(of: coach, matching: find.text(l.ebFindSomething)), findsOneWidget);
    await tester.tap(find.descendant(of: coach, matching: find.byKey(const Key('eat-brief-ideas'))));
    await tester.pumpAndSettle();
    expect(find.textContaining(l.dcAssessAllReached), findsOneWidget);
    expect(find.textContaining(l.dcEatIntro), findsNothing, reason: 'no options before the person chooses');
    await tester.tap(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-act-proceed-')));
    await tester.pumpAndSettle();
    expect(find.textContaining(l.dcAddsToCalories), findsOneWidget, reason: 'continuing works and says the calories add');
    expect(find.textContaining(l.dcEatIntro), findsOneWidget);
  });

  testWidgets('weekly report: from History & trends; no goal history said honestly; a day opens in Eat', (tester) async {
    await _openEat(tester, food: [_food('m', '2026-10-26', 2100, 150), _food('t', '2026-10-27', 1800, null), _food('f', day, 900, 60)], kcal: 2000, protein: 140);
    await _openReport(tester);
    expect(find.text(l.wrWeekSoFarLabel), findsOneWidget);
    expect(find.text(l.wrGoalsUnavailable), findsOneWidget, reason: 'today\'s goal is never laid over earlier days');
    expect(find.byKey(const Key('wr-calories-goal')), findsNothing);
    expect(find.text(l.wrDaysLogged(3, 5)), findsOneWidget);
    expect(find.byKey(const Key('trends-next')), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('trends-next'))).onPressed, isNull, reason: 'no future week');
    await _reportTo(tester, 'wr-day-2026-10-26');
    await tester.tap(find.byKey(const Key('wr-day-2026-10-26')));
    await tester.pumpAndSettle();
    expect(find.text('Monday, October 26'), findsOneWidget, reason: 'Eat shows that day, dated');
    expect(find.byKey(const Key('eat-back-to-today')), findsOneWidget);
  });

  testWidgets('weekly report: recorded goals compare each day with its own goal; the previous week opens', (tester) async {
    await _openEat(tester, food: [_food('m', '2026-10-26', 2100, 150), _food('t', '2026-10-27', 1800, 100)], kcal: 2000, protein: 140,
        goals: {'2026-10-26': const GoalDay(2000, 140), '2026-10-27': const GoalDay(2000, 140)});
    await _openReport(tester);
    expect(find.text(l.wrGoalsSome(2, 5)), findsOneWidget);
    expect(find.text(l.wrCalorieGoalDays(2, 1)), findsOneWidget);
    expect(find.text(l.wrProteinGoalDays(2, 1)), findsOneWidget);
    await tester.tap(find.byKey(const Key('trends-previous')));
    await tester.pumpAndSettle();
    expect(find.text(l.wrCompletedWeek), findsOneWidget);
  });

  for (final lang in ['fr-CA', 'ar']) {
    testWidgets('$lang at 320 px with 2× text: the bars and the weekly report fit', (tester) async {
      await _openEat(tester, food: [_food('a', day, 1900, 150), _food('b', '2026-10-28', 2200, null)], kcal: 2000, protein: 140, size: const Size(320, 2400), text: 2, lang: lang);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('eat-goal-calories-status')), findsOneWidget);
      await _openReport(tester);
      expect(tester.takeException(), isNull);
      await _reportTo(tester, 'wr-calories');
      expect(find.byKey(const Key('wr-calories')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
