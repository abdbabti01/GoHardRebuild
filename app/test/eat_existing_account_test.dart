import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/clock.dart' show addDays;
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/me/reminders.dart' show Notice, ReminderScheduler, reminderSchedulerProvider;
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart' show EatScreen;
import 'package:gohard_rebuild/features/nutrition/meal_habits_ui.dart' show usualMealProvider;

import 'food_fakes.dart';
import 'ui_support.dart';

/// Eat with an existing account's stored data (server-shaped entries, a hand-typed food, a recipe portion with a partial
/// value, a deleted entry, earlier days, the person's own reminders, stored preferences).
///
/// Regression: on builds 59–61 Eat was a blank grey page for any account with at least one reminder of its own. The
/// briefing iterated `remindersProvider.value ?? const []`; the untyped empty list made each reminder `dynamic`, and
/// `r.enabled` on an extension type is then a dynamic call on the raw map: NoSuchMethodError while building Eat.

const day = '2026-10-30';

class _Quiet implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool?> notificationsAllowed() async => true;
  @override
  Future<void> replaceAll(List<Notice> notices) async {}
}

final _egg = {'source': 'usda', 'sourceId': '2709215', 'name': 'Egg, whole, raw', 'basis': '100g', 'nutrients': {'calories': 143, 'protein': 12.6, 'carbs': 0.7, 'fat': 9.5},
    'servings': [{'label': '1 egg', 'grams': 50, 'milliliters': null}]};

/// Server-shaped entries: provenance, revision, a typed one without source, a recipe portion with a partial value.
List<Json> journal() => [
      for (final d in [0, 1, 2, 3])
        {'id': 'b$d', 'dayKey': addDays(day, -d), 'meal': 'Breakfast', 'name': 'Egg', 'amountDescription': '2 eggs (100 g)', 'revision': 1, 'isDeleted': false,
          'macros': {'calories': 143, 'protein': 12.6, 'carbs': 0.7, 'fat': 9.5}, 'provenance': {'calories': 'imported', 'protein': 'imported', 'carbs': 'imported', 'fat': 'imported'},
          'source': {'item': _egg, 'quantity': 100, 'unit': 'g'}},
      {'id': 't1', 'dayKey': day, 'meal': 'Lunch', 'name': 'Sandwich', 'amountDescription': '1', 'revision': 2, 'isDeleted': false,
        'macros': {'calories': null, 'protein': 20, 'carbs': null, 'fat': null}, 'provenance': {'calories': 'unknown', 'protein': 'entered', 'carbs': 'unknown', 'fat': 'unknown'}},
      {'id': 'r1', 'dayKey': day, 'meal': 'Dinner', 'name': 'Chili', 'amountDescription': '1 serving', 'revision': 1, 'isDeleted': false,
        'macros': {'calories': null, 'protein': 15.5, 'carbs': 20, 'fat': 5}, 'provenance': {'calories': 'unknown', 'protein': 'imported', 'carbs': 'imported', 'fat': 'imported'},
        'source': {'recipe': {'kind': 'recipe', 'name': 'Chili', 'servings': 4, 'preparedWeightG': null, 'id': 'rec1', 'revision': 2,
          'components': [{'item': _egg, 'quantity': 100, 'unit': 'g'}]}, 'portion': {'quantity': 1, 'unit': 'serving'}, 'partial': {'calories': 300}}},
      {'id': 'x1', 'dayKey': day, 'meal': 'Snack', 'name': 'Gone', 'amountDescription': '1', 'revision': 3, 'isDeleted': true, 'macros': {'calories': 100, 'protein': 1, 'carbs': 1, 'fat': 1}},
    ];

const _reminders = [
  {'id': 'm1', 'name': 'Log lunch', 'category': 'meal', 'meal': 'Lunch', 'time': '12:30', 'weekdays': [1, 2, 3, 4, 5], 'enabled': true},
  {'id': 'd1', 'name': 'Vitamin D', 'category': 'supplement', 'time': '08:00', 'weekdays': [1, 2, 3, 4, 5, 6, 7], 'enabled': false, 'private': false},
];

Future<void> _openEat(WidgetTester tester, {(int?, int?) goals = (null, null), bool coach = true, Json prefs = const {}, List<Override> extra = const []}) async {
  final c = await pumpApp(tester, [
    ...(await tester.runAsync(() => overridesFor(day: day, food: journal(), calorieGoal: goals.$1, proteinGoal: goals.$2, habitPrefs: prefs, reminders: _reminders)))!,
    ...FoodFakes().overrides,
    reminderSchedulerProvider.overrideWithValue(_Quiet()),
    ...extra,
  ], size: const Size(390, 1600));
  if (!coach) c.read(coachPrefsProvider.notifier).setOnTabs(false);
  await tester.tap(find.byKey(const Key('nav-eat')));
  await tester.pumpAndSettle();
}

void main() {
  for (final goals in [(null, null), (2000, 120), (300, 10)]) {
    for (final coach in [true, false]) {
      for (final prefs in [<String, dynamic>{}, {'suggest': true, 'skipped': ['$day|Lunch'], 'seen': ['$day|over'], 'headsUps': true}]) {
        testWidgets('an account with reminders: Eat renders (goals $goals, coach $coach, prefs $prefs)', (tester) async {
          await _openEat(tester, goals: goals, coach: coach, prefs: prefs);
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('log-food')), findsWidgets);
          expect(find.byKey(const Key('food-row-t1')), findsOneWidget, reason: 'the journal is there');
          expect(find.byKey(const Key('eat-coach-problem')), findsNothing);
          expect(find.byKey(Key(coach ? 'eat-coach' : 'eat-brief-panel')), findsOneWidget);
        });
      }
    }
  }

  // Whatever goes wrong in the coach's optional message, the journal and logging stay; the error is reported, not hidden.
  for (final coach in [true, false]) {
    testWidgets('a failing coach message (coach $coach): a notice with Retry, the journal and Log food intact, the error reported', (tester) async {
      await _openEat(tester, coach: coach, prefs: {'suggest': true}, extra: [usualMealProvider.overrideWith((ref, meal) => throw StateError('suggestion failed'))]);
      expect(tester.takeException(), isNotNull, reason: 'reported like any Flutter error (once per build while settling)');
      expect(find.byKey(const Key('eat-coach-problem')), findsOneWidget);
      expect(find.byKey(const Key('eat-coach-retry')), findsOneWidget);
      expect(find.byKey(const Key('log-food')), findsWidgets);
      expect(find.byKey(const Key('food-row-t1')), findsOneWidget);
      expect(find.byType(EatScreen), findsOneWidget);
    });
  }
}
