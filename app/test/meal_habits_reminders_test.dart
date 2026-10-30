import 'dart:convert';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/clock.dart' show addDays;
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/coach/day_coach.dart';
import 'package:gohard_rebuild/features/me/reminders.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';
import 'package:gohard_rebuild/features/nutrition/meal_habits.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals.dart';
import 'package:gohard_rebuild/l10n/app_localizations.dart' show lookupAppLocalizations;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support.dart';

/// Meal habits and reminders (docs/MEAL_HABITS_REMINDERS.md): which records count as a habit, the quantities a habit
/// suggests, one food of a saved meal changed for one time, and which notifications exist for which reminders.

final l = lookupAppLocalizations(const Locale('en'));
const today = '2026-10-29'; // a Thursday

FoodItem food(String id, {String source = 'usda', String name = 'Food', bool grams = true}) => FoodItem({
      'source': source, 'sourceId': id, 'name': name, 'basis': grams ? FoodItem.per100g : FoodItem.perServing,
      'nutrients': {'calories': 100, 'protein': 10, 'carbs': 10, 'fat': 1}, 'servings': [{'label': '1 piece', 'grams': grams ? 50 : null, 'milliliters': null}],
    });

var _n = 0;
FoodEntry logged(String day, String meal, FoodItem item, double q, {String unit = 'g', bool deleted = false}) => FoodEntry({
      'id': 'e${_n++}', 'dayKey': day, 'meal': meal, 'name': item.name, 'amountDescription': '$q', 'macros': const {'calories': 1}, 'isDeleted': deleted,
      'source': {'item': item.j, 'quantity': q, 'unit': unit},
    });
FoodEntry typed(String day, String meal) => FoodEntry({'id': 'e${_n++}', 'dayKey': day, 'meal': meal, 'name': 'Toast', 'amountDescription': '1', 'macros': const {}, 'source': null});
String ago(int days) => addDays(today, -days);
String addDaysKey(String d, int n) => addDays(d, n);

void main() {
  final eggs = food('egg', name: 'Egg'), oats = food('oats', name: 'Oats');
  final otherEggs = food('egg-2', source: 'off', name: 'Egg'); // same name, another product

  group('habits', () {
    test('the same combination on three recent days is a habit, with the latest amounts as logged', () {
      final journal = [
        for (final (d, q) in [(9, 40.0), (5, 50.0), (2, 60.0)]) ...[logged(ago(d), 'Breakfast', eggs, 100), logged(ago(d), 'Breakfast', oats, q)],
      ];
      final u = usualMeal(journal, today: today, meal: 'Breakfast')!;
      expect((u.days, u.lastDay), (3, ago(2)));
      expect([for (final e in u.entries) (e.source!['quantity'] as num).toDouble()]..sort(), [60, 100], reason: 'the most recent day, never an average');
      expect(usualMeal(journal, today: today, meal: 'Lunch'), isNull, reason: 'another meal is not evidence');
    });

    test('one day, several entries, today, deletions, typed foods and look-alike names are not evidence', () {
      List<FoodEntry> days(List<int> d, FoodItem f) => [for (final x in d) logged(ago(x), 'Breakfast', f, 100)];
      expect(usualMeal([...days([1, 1, 1, 1], eggs), ...days([2], eggs)], today: today, meal: 'Breakfast'), isNull, reason: 'two distinct days');
      expect(usualMeal([...days([3, 2], eggs), logged(today, 'Breakfast', eggs, 100)], today: today, meal: 'Breakfast'), isNull, reason: 'today never counts');
      expect(usualMeal([...days([3, 2], eggs), logged(ago(1), 'Breakfast', eggs, 100, deleted: true)], today: today, meal: 'Breakfast'), isNull);
      expect(usualMeal([...days([3, 2, 1], eggs), typed(ago(1), 'Breakfast')], today: today, meal: 'Breakfast'), isNull,
          reason: 'a day with a typed food is not comparable');
      expect(usualMeal([...days([3, 2], eggs), ...days([1], otherEggs)], today: today, meal: 'Breakfast'), isNull, reason: 'a name never merges two products');
      expect(usualMeal([...days([3, 2], eggs), logged(ago(1), 'Breakfast', eggs, 1, unit: 'serving:0')], today: today, meal: 'Breakfast'), isNull,
          reason: 'grams and pieces are different habits');
    });

    test('unrelated foods on different days are never combined into a meal', () {
      final journal = [
        logged(ago(4), 'Lunch', eggs, 100), logged(ago(3), 'Lunch', oats, 50),
        logged(ago(2), 'Lunch', eggs, 100), logged(ago(2), 'Lunch', oats, 50), logged(ago(1), 'Lunch', oats, 50),
      ];
      expect(usualMeal(journal, today: today, meal: 'Lunch'), isNull);
    });

    test('an old habit fades: its last day must be within two weeks, and the window is four weeks', () {
      expect(usualMeal([for (final d in [20, 18, 15]) logged(ago(d), 'Dinner', eggs, 100)], today: today, meal: 'Dinner'), isNull);
      expect(usualMeal([for (final d in [30, 29, 2]) logged(ago(d), 'Dinner', eggs, 100)], today: today, meal: 'Dinner'), isNull);
      expect(usualMeal([for (final d in [20, 18, 2]) logged(ago(d), 'Dinner', eggs, 100)], today: today, meal: 'Dinner')?.days, 3);
    });

    test('a saved meal with exactly that combination is the one reviewed; a never-logged one suggests nothing', () {
      final body = MealBody({'kind': 'meal', 'name': 'My eggs', 'components': [{'item': eggs.j, 'quantity': 100, 'unit': 'g'}]});
      final saved = SavedMeal({'id': 's1', 'body': body.j});
      expect(usualMeal(const [], today: today, meal: 'Breakfast', saved: [saved]), isNull);
      final u = usualMeal([for (final d in [3, 2, 1]) logged(ago(d), 'Breakfast', eggs, 100)], today: today, meal: 'Breakfast', saved: [saved])!;
      expect(u.saved?.id, 's1');
    });

    test('a usual logging time needs four same-day logs close together; anything else asks the person', () {
      final logged = {for (var d = 1; d <= 6; d++) '${ago(d)}|Breakfast'};
      LogTime at(int d, int minute) => (day: ago(d), meal: 'Breakfast', minute: minute);
      expect(usualLogTime([at(1, 535), at(2, 548), at(3, 538), at(4, 545)], meal: 'Breakfast', today: today, logged: logged), '09:00');
      expect(usualLogTime([at(1, 545), at(2, 552), at(3, 538), at(4, 560)], meal: 'Breakfast', today: today, logged: logged), '09:15', reason: '9:09 is nearest 9:15');
      expect(usualLogTime([at(1, 545), at(2, 552), at(3, 538)], meal: 'Breakfast', today: today, logged: logged), isNull, reason: 'three days');
      expect(usualLogTime([at(1, 480), at(2, 700), at(3, 900), at(4, 1200)], meal: 'Breakfast', today: today, logged: logged), isNull, reason: 'scattered');
      expect(usualLogTime([at(1, 545), at(2, 552), at(3, 538), at(4, 560)], meal: 'Breakfast', today: today, logged: {'${ago(1)}|Breakfast'}), isNull,
          reason: 'a day whose entries were deleted is no evidence');
    });

    test('only an entry logged on its own day records a logging time, once per meal and day', () async {
      final h = Harness();
      addTearDown(h.dispose);
      final owner = await h.signIn('one');
      var now = DateTime(2026, 10, 29, 9, 5);
      final repo = FoodRepository(h.sync, owner, now: () => now);
      FoodDraft d(String day) => FoodDraft(dayKey: day, meal: 'Breakfast', name: 'Egg', amount: '1 egg', calories: 70);
      await repo.save(d('2026-10-27')); // backdated
      expect(await h.bodies(owner, Kinds.logTime), isEmpty);
      await repo.save(d(today));
      now = DateTime(2026, 10, 29, 11, 40);
      await repo.save(d(today));
      expect(await h.bodies(owner, Kinds.logTime), [{'day': today, 'meal': 'Breakfast', 'minute': 545}]);
    });
  });

  group('one food of a saved meal, this time', () {
    final rice = food('rice', name: 'Rice, white, cooked'), chicken = food('chicken', name: 'Chicken breast'), bun = food('bun', name: 'Bun', grams: false);
    MealComponent c(FoodItem f, double q, String unit) => MealComponent({'item': f.j, 'quantity': q, 'unit': unit});
    final body = MealBody({'kind': 'meal', 'name': 'My chicken meal', 'components': [c(chicken, 120, 'g').j, c(rice, 100, 'g').j, c(bun, 1, 'serving:0').j]});
    final item = CoachItem(ItemKind.meal, 'm1', 'My chicken meal', body: body);
    DayRecords records() => DayRecords(today: today, shown: today, entries: (_) => const [], items: [item], mealNow: 'Lunch');
    Json ask(String words, {double? grams, double? servings}) =>
        resolveDay(DayIntent('portion', items: const [(kind: ItemKind.meal, id: 'm1')], grams: grams, servings: servings, ingredient: words), records(), l);

    test('the named food changes, the saved meal does not, and the values come from the foods', () {
      final r = ask('rice', grams: 150);
      final card = (r['cards'] as List).single as Map;
      expect(card['ingredient'], {'index': 1, 'sourceId': 'rice', 'quantity': 150.0, 'unit': 'g'});
      expect((card['kcal'] as Map)['known'], closeTo(120 + 150 + 100, 1e-9));
      expect(body.components[1].quantity, 100, reason: 'the definition is untouched');
      final parts = ingredientParts(body, card['ingredient'])!;
      expect([for (final p in parts) p.quantity], [120, 150, 1]);
      expect(ingredientParts(body.copyWith(components: [body.components[0]]), card['ingredient']), isNull, reason: 'edited since: not opened');
    });

    test('ambiguous, unknown, unit-incompatible and amount-less requests ask back instead of guessing', () {
      final both = MealBody({...body.j, 'components': [...body.j['components'] as List, c(food('rice2', name: 'Rice, brown'), 80, 'g').j]});
      final r = resolveDay(DayIntent('portion', items: const [(kind: ItemKind.meal, id: 'm1')], grams: 150, ingredient: 'rice'),
          DayRecords(today: today, shown: today, entries: (_) => const [], items: [CoachItem(ItemKind.meal, 'm1', 'My chicken meal', body: both)], mealNow: 'Lunch'), l);
      expect([for (final x in r['cards'] as List) (x as Map)['choice']], [true, true]);
      expect((ask('salmon', grams: 150)['lines'] as List).first, contains('could not find'));
      expect((ask('bun', grams: 150)['lines'] as List).first, contains('no weight'));
      expect((ask('chicken')['lines'] as List).first, contains('How much'));
      for (final r in [ask('salmon', grams: 150), ask('bun', grams: 150), ask('chicken')]) {
        expect([for (final x in r['cards'] as List) (x as Map)['ingredient']], [null], reason: 'only the meal as saved is offered');
      }
    });
  });

  group('reminders', () {
    Reminder r(String id, ReminderCategory cat, String time, {List<int> days = const [1, 2, 3, 4, 5, 6, 7], bool on = true, String? meal, bool private = false}) =>
        Reminder({'id': id, 'name': id, 'category': cat.name, 'meal': meal, 'time': time, 'weekdays': days, 'enabled': on, 'private': private});
    List<Notice> plan(List<Reminder> rs, {Map<String, DoseLog> logs = const {}, int nowMinute = 0, Set<String> loggedToday = const {}, DateTime? nowUtc}) =>
        reminderNotices(rs, logs: logs, today: today, nowMinute: nowMinute, nowUtc: nowUtc ?? DateTime.utc(2026, 10, 29, 12), loggedToday: loggedToday, owner: 'one', l: l);

    test('paused gives none; weekdays and the time already past today are respected; nothing beyond seven days', () {
      expect(plan([r('a', ReminderCategory.supplement, '08:00', on: false)]), isEmpty);
      final weekly = plan([r('b', ReminderCategory.supplement, '08:00', days: const [4])]); // Thursdays
      expect([for (final n in weekly) n.day], [today]);
      expect(plan([r('b', ReminderCategory.supplement, '08:00', days: const [4])], nowMinute: 9 * 60), isEmpty, reason: 'today 08:00 has passed');
      expect(plan([r('c', ReminderCategory.medication, '20:00')]).length, horizonDays);
    });

    test('a meal reminder is not sent once that meal is in today’s journal, and returns tomorrow', () {
      final n = plan([r('m', ReminderCategory.meal, '12:00', meal: 'Lunch')], loggedToday: {'Lunch'});
      expect(n.first.day, addDaysKey(today, 1));
    });

    test('an answered dose occurrence is not sent; a snooze adds one notification and leaves tomorrow alone', () {
      final dose = r('d', ReminderCategory.medication, '20:00');
      final taken = DoseLog({'reminderId': 'd', 'day': today, 'time': '20:00', 'status': 'taken'});
      expect([for (final n in plan([dose], logs: {dose.occurrence(today): taken})) n.day], isNot(contains(today)));
      final until = DateTime.utc(2026, 10, 29, 12, 10);
      final snoozed = DoseLog({'reminderId': 'd', 'day': today, 'time': '08:00', 'status': 'snoozed', 'snoozeUntilUtc': until.toIso8601String()});
      final n = plan([dose], logs: {'d|$today|08:00': snoozed});
      expect([for (final x in n) if (x.atUtc != null) x.atUtc], [until]);
      expect([for (final x in n) if (x.day != null) x.day], [for (var i = 0; i < horizonDays; i++) addDaysKey(today, i)], reason: 'the schedule is unchanged');
      expect(plan([dose], logs: {'d|$today|08:00': snoozed}, nowUtc: until.add(const Duration(minutes: 1))).where((x) => x.atUtc != null), isEmpty);
    });

    test('occurrence identities are stable and distinct; private reminders hide name and instructions', () {
      final a = plan([r('d', ReminderCategory.medication, '20:00')]), b = plan([r('d', ReminderCategory.medication, '20:00')]);
      expect([for (final n in a) n.id], [for (final n in b) n.id]);
      expect({for (final n in a) n.id}.length, a.length);
      final hidden = plan([Reminder({...r('Lisinopril', ReminderCategory.medication, '20:00', private: true).j, 'instructions': '10 mg with water'})]).first;
      expect((hidden.title, hidden.body), (l.reminderHiddenMedication, l.reminderDoseBody), reason: 'the purpose, never the name, dose or instructions');
      final shown = plan([Reminder({...r('Vitamin D', ReminderCategory.supplement, '20:00').j, 'instructions': '1 capsule'})]).first;
      expect((shown.title, shown.body), ('Vitamin D', '1 capsule'));
      final hiddenSupplement = plan([r('Iron', ReminderCategory.supplement, '20:00', private: true)]).first;
      expect('${hiddenSupplement.title} ${hiddenSupplement.body}', allOf(contains('Time for your supplement.'), isNot(contains('Iron'))));
      expect(plan([r('m', ReminderCategory.meal, '12:00', meal: 'Lunch', private: true)]).first.title, 'Time to log lunch.');
      expect(jsonDecode(hidden.payload!), {'o': 'one', 'r': 'Lisinopril', 'k': 'Lisinopril|$today|20:00'});
    });

    test('the budget keeps the earliest whole days and says how far it reaches', () {
      final many = plan([for (var i = 0; i < 10; i++) r('s$i', ReminderCategory.supplement, '${(8 + i).toString().padLeft(2, '0')}:00')]);
      final b = withinBudget(many);
      expect(b.notices.length, lessThanOrEqualTo(noticeBudget));
      expect(b.through, addDaysKey(today, 5));
      expect(b.notices.every((n) => n.day!.compareTo(b.through!) <= 0), isTrue);
      expect(withinBudget(many.take(20).toList()).through, isNull);
    });

    test('daylight saving: a skipped time comes just after the change, a repeated one once', () {
      tzdata.initializeTimeZones();
      final toronto = tz.getLocation('America/Toronto');
      final spring = noticeTime(const Notice(id: 1, title: '', body: '', day: '2026-03-08', time: '02:30'), toronto);
      expect((spring.hour, spring.minute, spring.timeZoneOffset), (3, 30, const Duration(hours: -4)));
      final fall = noticeTime(const Notice(id: 1, title: '', body: '', day: '2026-11-01', time: '01:30'), toronto);
      expect((fall.hour, fall.minute), (1, 30));
      final zurich = noticeTime(const Notice(id: 1, title: '', body: '', day: '2026-10-30', time: '08:00'), tz.getLocation('Europe/Zurich'));
      expect((zurich.hour, zurich.minute), (8, 0), reason: 'a wall-clock time in whatever zone the phone is in');
    });

    test('answers are one per occurrence, kept per account, and survive a restart and a pull', () async {
      final h = Harness();
      addTearDown(h.dispose);
      final one = await h.signIn('one');
      final dose = r('d', ReminderCategory.medication, '20:00');
      await ReminderRepository(h.sync, one).put(dose.j);
      final repo = ReminderRepository(h.sync, one);
      await repo.answer(dose, today, DoseStatus.taken);
      await repo.answer(dose, today, DoseStatus.taken);
      await repo.answer(dose, today, DoseStatus.skipped);
      expect([for (final b in await h.bodies(one, Kinds.reminderLog)) b['status']], ['skipped']);
      await h.sync.pull();
      await h.restart();
      expect((await h.bodies(one, Kinds.reminder)).single['id'], 'd');
      expect(await h.bodies('two', Kinds.reminder), isEmpty, reason: 'another account sees none of it');
      expect(h.server.calls.where((q) => q.path.contains('reminder')), isEmpty, reason: 'nothing is sent to the account');
    });
  });
}
