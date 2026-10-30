import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/coach/day_coach_screen.dart' show DayCoachScreen;
import 'package:gohard_rebuild/features/me/reminders.dart' show Notice, ReminderScheduler, reminderSchedulerProvider;

import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';

import 'food_fakes.dart';
import 'support.dart';
import 'ui_support.dart';

/// Eat's briefing on screen (docs/EAT_COMPANION.md): the day's own words in the coach's bubble, a heads-up said once,
/// the same words and action without the coach, and long translations on a narrow phone. No AI is asked.

const day = '2026-10-30';

class _Quiet implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool?> notificationsAllowed() async => true;
  @override
  Future<void> replaceAll(List<Notice> notices) async {}
}

Future<void> _openEat(WidgetTester tester, {List<Json> food = const [], int? kcal, int? protein, Json prefs = const {}, bool coach = true, Size size = const Size(390, 1500), double text = 1, String? lang}) async {
  // A real local database for the conversation What could I eat? opens; nothing reaches a server.
  final store = TestStore(), db = store.open();
  addTearDown(() async {
    await db.close();
    store.dispose();
  });
  final c = await pumpApp(tester, [
    ...(await tester.runAsync(() => overridesFor(day: day, food: food, calorieGoal: kcal, proteinGoal: protein, habitPrefs: prefs)))!,
    ...FoodFakes().overrides,
    reminderSchedulerProvider.overrideWithValue(_Quiet()),
    dbProvider.overrideWithValue(db),
    syncProvider.overrideWith((ref) {
      final engine = SyncEngine(db, Api(FakeServer(), ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
      ref.onDispose(engine.dispose);
      return engine;
    }),
  ], size: size, textScale: text);
  // The one-time introductions have had their turn: the briefing is what is said.
  for (final id in ['eat.first', 'eat.saved.new', 'eat.saved.shortcut', 'eat.history', 'eat.meals', 'eat.out', 'eat.habits', 'eat.reminders']) {
    c.read(coachPrefsProvider.notifier).markSeen('one', id);
  }
  if (!coach) c.read(coachPrefsProvider.notifier).setOnTabs(false);
  if (lang != null) c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
  await tester.tap(find.byKey(const Key('nav-eat')));
  await tester.pumpAndSettle();
}

Json _lunch(double kcal, double? protein) => foodEntry('l1', day, 'Lunch', 'Pasta', '1 plate', calories: kcal, protein: protein, carbs: 10, fat: 5);

Finder _said(String s) => find.descendant(of: find.byKey(const Key('eat-coach')), matching: find.textContaining(s, findRichText: true));

void main() {
  testWidgets('the bubble says the day: what is left, with What could I eat?', (tester) async {
    await _openEat(tester, food: [_lunch(650, 40)], kcal: 2000, protein: 120);
    expect(_said('You have 1,350 kcal and 80 g protein left.'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('eat-coach')), matching: find.byKey(const Key('eat-brief-ideas'))), findsOneWidget);
    expect(find.byKey(const Key('log-food')), findsWidgets, reason: 'logging stays where it was');

  });

  // One app per test: the coach keeps its words for a session.
  testWidgets('over the target: a heads-up the first time', (tester) async {
    await _openEat(tester, food: [_lunch(2150, 40)], kcal: 2000);
    expect(_said('150 kcal above your target. That’s okay.'), findsOneWidget);
  });

  testWidgets('over the target, already said today: said plainly', (tester) async {
    await _openEat(tester, food: [_lunch(2150, 40)], kcal: 2000, prefs: {'seen': ['$day|over']});
    expect(_said('Recorded calories are 150 kcal above your target today.'), findsOneWidget);
  });

  testWidgets('heads-ups turned off: said plainly', (tester) async {
    await _openEat(tester, food: [_lunch(2150, 40)], kcal: 2000, prefs: {'headsUps': false});
    expect(_said('That’s okay'), findsNothing);
    expect(_said('Recorded calories are 150 kcal above'), findsOneWidget);
  });

  testWidgets('without the coach, the same words and What could I eat? are in a quiet panel; it opens the ideas with no AI', (tester) async {
    await _openEat(tester, food: [_lunch(650, null)], kcal: 2000, coach: false);
    expect(find.descendant(of: find.byKey(const Key('eat-brief-panel')), matching: find.textContaining('You have 1,350 kcal left today.')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('eat-brief-ideas')));
    await tester.tap(find.byKey(const Key('eat-brief-ideas')));
    await tester.pumpAndSettle();
    expect(find.byType(DayCoachScreen), findsOneWidget);
  });

  for (final lang in ['fr-CA', 'ar']) {
    testWidgets('$lang: Eat with a heads-up and incomplete values fits 320 px at 2× text', (tester) async {
      await _openEat(tester, food: [_lunch(650, 40), foodEntry('s1', day, 'Snack', 'Mélange', '1', calories: null, protein: 3)], kcal: 2000, protein: 30,
          size: const Size(320, 1400), text: 2, lang: lang);
      expect(tester.takeException(), isNull);
      expect(Directionality.of(tester.element(find.byKey(const Key('eat-coach')))), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
    });
  }
}
