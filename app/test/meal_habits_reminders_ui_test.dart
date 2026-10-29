import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/clock.dart' show addDays;
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/me/reminders.dart';
import 'package:gohard_rebuild/features/me/reminders_screen.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals_screens.dart' show MealReviewScreen;

import 'food_fakes.dart';
import 'ui_support.dart';

/// Eat's usual-meal suggestion and the Reminders pages, as the person meets them: the three choices, nothing logged by
/// looking, nothing suggested on another day or when off; the Reminders pages in Arabic and French on a narrow phone.

const day = '2026-10-29';

final egg = FoodItem({'source': 'usda', 'sourceId': 'egg', 'name': 'Egg', 'basis': FoodItem.per100g,
    'nutrients': {'calories': 143, 'protein': 12.6, 'carbs': 0.7, 'fat': 9.5}, 'servings': [{'label': '1 egg', 'grams': 50, 'milliliters': null}]});

/// The same egg at every meal on the four days before [day]: whatever the time of day, that meal has a habit.
final habitJournal = [
  for (final d in [1, 2, 3, 4])
    for (final m in meals)
      {...foodEntry('$m$d', addDays(day, -d), m, 'Egg', '2 eggs (100 g)', calories: 143, protein: 12.6, carbs: 0.7, fat: 9.5), 'source': {'item': egg.j, 'quantity': 100, 'unit': 'g'}},
];

class _Scheduler implements ReminderScheduler {
  _Scheduler(this.allowed);
  final bool allowed;
  @override
  Future<bool> requestPermission() async => allowed;
  @override
  Future<bool?> notificationsAllowed() async => allowed;
  @override
  Future<void> replaceAll(List<Notice> notices) async {}
}

void main() {
  testWidgets('Eat offers the usual meal with its three choices; reviewing it logs nothing; off or another day, nothing is suggested', (tester) async {
    final fakes = FoodFakes();
    await pumpApp(tester, [...(await tester.runAsync(() => overridesFor(day: day, food: habitJournal, habitPrefs: {'suggest': true})))!, ...fakes.overrides,
        reminderSchedulerProvider.overrideWithValue(_Scheduler(true))], size: const Size(390, 1400));
    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    for (final k in ['habit-review', 'habit-other', 'habit-not-today']) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    expect(find.textContaining('Logged at', findRichText: true), findsOneWidget, reason: 'the reason is said');

    await tester.tap(find.byKey(const Key('habit-review')));
    await tester.pumpAndSettle();
    expect(find.byType(MealReviewScreen), findsOneWidget);
    expect(find.text('Log this time'), findsOneWidget);
    expect(find.text('Save as meal'), findsOneWidget, reason: 'a usual meal that is not saved can become one');
    expect(find.textContaining('100 g'), findsWidgets, reason: 'the amounts as last logged');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(fakes.journal.saved, isEmpty, reason: 'looking and going back log nothing');
    expect(fakes.journal.meals, isEmpty);

    // An earlier day is not greeted as if it were now.
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habit-review')), findsNothing);
  });

  testWidgets('suggestions stay off until chosen', (tester) async {
    for (final prefs in [<String, dynamic>{}, {'suggest': false}]) {
      await pumpApp(tester, [...(await tester.runAsync(() => overridesFor(day: day, food: habitJournal, habitPrefs: prefs)))!, ...FoodFakes().overrides,
          reminderSchedulerProvider.overrideWithValue(_Scheduler(true))], size: const Size(390, 1400));
      await tester.tap(find.byKey(const Key('nav-eat')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('habit-review')), findsNothing, reason: '$prefs');
    }
  });

  testWidgets('Reminders and the editor fit a 320 px phone with large text in Arabic and French; a refusal is explained', (tester) async {
    final dose = {'id': 'd1', 'name': 'Vitamin D', 'category': 'supplement', 'time': '08:00', 'weekdays': [1, 2, 3, 4, 5, 6, 7], 'enabled': true, 'instructions': '1 capsule', 'private': true};
    for (final lang in ['ar', 'fr-CA']) {
      for (final home in [const RemindersScreen(), const ReminderEditorScreen(meal: 'Breakfast'), ReminderEditorScreen(existing: Reminder(dose))]) {
        final c = await pumpApp(tester, [
          ...(await tester.runAsync(() => overridesFor(day: day, food: habitJournal, reminders: [dose], profile: {'remindersEnabled': true},
              logTimes: [for (final d in [1, 2, 3, 4]) (day: addDays(day, -d), meal: 'Breakfast', minute: 535 + d * 2)])))!,
          ...FoodFakes().overrides, reminderSchedulerProvider.overrideWithValue(_Scheduler(false)),
        ], home: home, size: const Size(320, 900), textScale: 1.6, settle: false);
        c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
        await tester.pumpAndSettle();
        final scroll = find.byType(Scrollable).first;
        await tester.drag(scroll, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$lang ${home.runtimeType}');
        expect(Directionality.of(tester.element(find.byType(home.runtimeType))), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        final l = c.read(appL10nProvider);
        if (home is RemindersScreen) {
          await tester.drag(scroll, const Offset(0, 4000));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('reminders-denied')), findsOneWidget, reason: 'notifications refused: said, with the settings action');
          await tester.scrollUntilVisible(find.byKey(const Key('dose-d1')), 100, scrollable: scroll);
          await tester.pumpAndSettle();
          expect(find.descendant(of: find.byKey(const Key('dose-d1')), matching: find.text(l.reminderUnconfirmed)), findsOneWidget, reason: 'no answer is Unconfirmed');
          await tester.tap(find.byKey(const Key('dose-d1')));
          await tester.pumpAndSettle();
          for (final k in ['dose-taken', 'dose-snooze', 'dose-skip']) {
            expect(find.byKey(Key(k)), findsOneWidget);
          }
          expect(tester.takeException(), isNull, reason: '$lang sheet');
        } else if ((home as ReminderEditorScreen).existing == null) {
          // Four same-day logs around 9:00: the time is offered beside Choose my own time, never chosen for the person.
          await tester.drag(scroll, const Offset(0, 4000));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('reminder-suggested')), findsOneWidget);
          expect(find.text(l.reminderOwnTime), findsOneWidget);
        } else {
          expect(find.byKey(const Key('reminder-suggested')), findsNothing, reason: 'an existing schedule is never re-suggested');
          expect(find.byKey(const Key('reminder-delete')), findsOneWidget);
        }
      }
    }
  });
}
