import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/widgets.dart' show ProgressRail;
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/nutrition/water.dart';

import 'food_fakes.dart';
import 'ui_support.dart';

const _day = '2026-10-11';

/// Records what the water sheet asks to save; the day's entries come from [entries].
class _Water implements WaterRepository {
  final adds = <(String, double)>[];
  final ids = <String?>[];
  final removed = <String>[];
  @override
  Future<Receipt> add(String dayKey, double ml, {String? id}) async {
    adds.add((dayKey, WaterRepository.validate(ml)));
    ids.add(id);
    return const Receipt('op', 'pending');
  }

  final updates = <(String, double)>[];
  @override
  Future<Receipt> update(WaterEntry e, double ml) async {
    updates.add((e.id, WaterRepository.validate(ml)));
    return const Receipt('op', 'pending');
  }
  @override
  Future<Receipt> remove(WaterEntry e) async {
    removed.add(e.id);
    return const Receipt('op', 'pending');
  }
}

Json _entry(String id, double ml, {String day = _day}) => {'id': id, 'dayKey': day, 'volumeMl': ml, 'revision': 1, 'isDeleted': false};

Future<List<Override>> _fixture(WidgetTester tester, {List<Json> water = const [], Json profile = const {}, _Water? repo, RecordingProfiles? profiles, Stream<List<Stored<WaterEntry>>>? waterStream, List<Json> food = const []}) async => [
      ...(await tester.runAsync(() => overridesFor(day: _day, profile: profile, food: food,
          appearance: AppearanceStore(MemorySecretStore())..mode = ThemeMode.dark)))!,
      waterProvider.overrideWith((ref, d) => waterStream ?? Stream.value([for (final w in water) if (w['dayKey'] == d) stored(WaterEntry(w), Kinds.water, w['id'] as String, w)])),
      waterRepositoryProvider.overrideWithValue(repo ?? _Water()),
      waterEntriesProvider.overrideWith((ref) => Stream.value([for (final w in water) stored(WaterEntry(w), Kinds.water, w['id'] as String, w)])),
      profileRepositoryProvider.overrideWithValue(profiles ?? RecordingProfiles()),
    ];

void main() {
  testWidgets('one tap logs one ordinary drink on today, at once; Undo removes exactly that entry; the bar goes away by itself', (tester) async {
    final repo = _Water();
    final container = await pumpApp(tester, await _fixture(tester, repo: repo, water: [_entry('a', 500)], profile: {'waterGoalMl': 2000}), size: const Size(390, 1400));
    container.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true));
    await tester.pumpAndSettle();
    final quick = find.descendant(of: find.byKey(const Key('today-water')), matching: find.byKey(const Key('water-quick-add')));
    expect(find.descendant(of: quick, matching: find.text('+250 mL')), findsOneWidget, reason: 'the amount is on the button');
    await tester.tap(quick);
    await tester.pump();
    expect(repo.adds, [(_day, 250.0)], reason: 'one tap, one entry, no sheet');
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(quick);
    await tester.pump();
    expect(repo.adds, hasLength(2), reason: 'a second drink is a second entry');
    // Undo is in the water line, in Other amount's place: the line keeps its height and nothing is covered.
    final row = find.byKey(const Key('today-water'));
    final height = tester.getSize(row).height;
    expect(find.descendant(of: row, matching: find.byKey(const Key('water-other'))), findsNothing);
    expect(find.byType(SnackBar), findsNothing, reason: 'no bar over the page');
    await tester.tap(find.descendant(of: row, matching: find.byKey(const Key('water-undo'))));
    await tester.pump();
    expect(repo.removed, [repo.ids.last], reason: 'Undo removes the entry just added, not an amount from the total');
    expect(find.descendant(of: row, matching: find.byKey(const Key('water-other'))), findsOneWidget);
    await tester.tap(quick);
    await tester.pump();
    expect(tester.getSize(row).height, height, reason: 'Undo appearing does not move the tiles below');
    await tester.pump(const Duration(seconds: 6));
    expect(find.byKey(const Key('water-undo')), findsNothing, reason: 'Undo goes away by itself');
    expect(find.descendant(of: row, matching: find.byKey(const Key('water-other'))), findsOneWidget);

    // An ounce household gets an ounce drink, stored as what it is.
    container.read(trackingPrefsProvider.notifier).setUnit(VolumeUnit.flOz);
    await tester.pumpAndSettle();
    await tester.tap(quick);
    await tester.pump();
    expect(repo.adds.last, (_day, 236.588), reason: '+8 fl oz shown and 8 fl oz stored, converted once');
    await tester.pump(const Duration(seconds: 6)); // Undo gives Other amount its place back

    // Other amount: one field and Add water.
    await tester.tap(find.descendant(of: find.byKey(const Key('today-water')), matching: find.byKey(const Key('water-other'))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('water-other-amount')), '12');
    await tester.tap(find.byKey(const Key('water-other-add')));
    await tester.pumpAndSettle();
    expect(repo.adds.last.$2, closeTo(354.882, 0.001));
    expect(find.byKey(const Key('water-other-amount')), findsNothing, reason: 'the sheet closes once added');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Eat › History: named, lists the days with entries, and opens an earlier day with its own water, dated; Back to today', (tester) async {
    final repo = _Water();
    final container = await pumpApp(tester, await _fixture(tester, repo: repo, water: [_entry('a', 500), _entry('old', 900, day: '2026-10-10')]), size: const Size(390, 1400));
    container.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true));
    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    final history = find.byKey(const Key('eat-history'));
    expect(find.descendant(of: history, matching: find.text('History & trends')), findsOneWidget, reason: 'a labelled action, not only arrows');
    await tester.ensureVisible(history);
    await tester.pumpAndSettle();
    await tester.tap(history);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('trends-calendar')));
    await tester.tap(find.byKey(const Key('trends-calendar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-calendar')), findsOneWidget);
    final old = find.byKey(const Key('history-day-2026-10-10'));
    expect(find.descendant(of: old, matching: find.text('900 mL water')), findsOneWidget, reason: 'the day\'s real water, from its entries');
    await tester.tap(old);
    await tester.pumpAndSettle();
    expect(find.text('Saturday, October 10'), findsOneWidget, reason: 'the date is unmistakable');
    expect(find.descendant(of: find.byKey(const Key('eat-water')), matching: find.text('900 mL')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('eat-water')), matching: find.byKey(const Key('water-quick-add'))), findsNothing, reason: 'the one-tap drink is for today');
    await tester.tap(find.descendant(of: find.byKey(const Key('eat-water')), matching: find.byKey(const Key('water-other'))));
    await tester.pumpAndSettle();
    expect(find.text('For Saturday, October 10'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('water-other-amount')), '200');
    await tester.tap(find.byKey(const Key('water-other-add')));
    await tester.pumpAndSettle();
    expect(repo.adds.last, ('2026-10-10', 200.0), reason: 'logged on the day being viewed, not today');
    await tester.tap(find.byKey(const Key('eat-back-to-today')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('eat-water')), matching: find.byKey(const Key('water-quick-add'))), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an earlier day without water says "No water logged" in its row and sheet, not 0 mL', (tester) async {
    final container = await pumpApp(tester, await _fixture(tester, profile: {'waterGoalMl': 2000},
        food: [foodEntry('f1', '2026-10-10', 'Lunch', 'Rice', '1 bowl', calories: 400)]), size: const Size(390, 2200));
    container.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true));
    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('eat-water'));
    expect(find.descendant(of: row, matching: find.text('0 / 2,000 mL')), findsOneWidget, reason: 'today keeps its goal progress');
    await tester.tap(find.byKey(const Key('eat-history')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('trends-calendar')));
    await tester.tap(find.byKey(const Key('trends-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-day-2026-10-10')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: row, matching: find.text('No water logged')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('0 mL')), findsNothing);
    expect(find.descendant(of: row, matching: find.byKey(const Key('water-goal-bar'))), findsNothing);
    await tester.tap(find.descendant(of: row, matching: find.byKey(const Key('water-row'))));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('water-sheet-total'))).data, 'No water logged');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('water is off until turned on; hiding and showing it keeps the day\'s water and its goal, on Today and Eat', (tester) async {
    await pumpApp(tester, [
      // Eat is visited several times with nothing logged: the Eating out introduction has had its turn, so the coach's usual words show.
      coachPrefsStoreProvider.overrideWithValue(CoachPrefsStore(MemorySecretStore())..value = const CoachPrefs(dismissed: {'one|eat.out'})),
      ...await _fixture(tester, water: [_entry('a', 500), _entry('b', 250), _entry('old', 900, day: '2026-10-10')], profile: {'waterGoalMl': 2000}),
    ], size: const Size(390, 1400));
    expect(find.byKey(const Key('today-water')), findsNothing, reason: 'water tracking starts off');

    // Customize tracking is in Eat (with the goals); Today shows the result.
    Future<void> setWater(bool on) async {
      await tester.tap(find.byKey(const Key('nav-eat')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('eat-customize')));
      await tester.tap(find.byKey(const Key('eat-customize')));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('track-water'));
      if (tester.widget<SwitchListTile>(toggle).value != on) await tester.tap(toggle);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byKey(const Key('track-water')))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-today')));
      await tester.pumpAndSettle();
    }

    await setWater(true);
    final row = find.byKey(const Key('today-water'));
    expect(find.descendant(of: row, matching: find.text('750 / 2,000 mL')), findsOneWidget, reason: 'today\'s two entries against the saved goal; yesterday\'s stays on its own day');
    expect(find.descendant(of: row, matching: find.text('38%')), findsOneWidget, reason: 'the goal bar with its real share, like the nutrition bars');

    await setWater(false);
    expect(find.byKey(const Key('today-water')), findsNothing);
    await setWater(true);
    expect(find.descendant(of: find.byKey(const Key('today-water')), matching: find.text('750 / 2,000 mL')), findsOneWidget, reason: 'hiding removed nothing');

    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('eat-water')), matching: find.text('750 / 2,000 mL')), findsOneWidget, reason: 'Eat shows the same day\'s water');
    await tester.pump(const Duration(seconds: 3));
    // Customize left Eat scrolled down; the coach is in its header, back at the top of the lazy list.
    await tester.scrollUntilVisible(find.byKey(const Key('eat-coach')), -300, scrollable: find.ancestor(of: find.byKey(const Key('eat-water')), matching: find.byType(Scrollable)).first);
    // The coach speaks about the day's food (docs/EAT_COMPANION.md); water is in the summary row above, not in its words.
    expect(find.descendant(of: find.byKey(const Key('eat-coach')), matching: find.byKey(const Key('eat-brief-ideas'))), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('above the goal the bar stays full and the words keep the real amount; without a goal, only the amount', (tester) async {
    final container = await pumpApp(tester, await _fixture(tester, water: [_entry('a', 1500), _entry('b', 900)], profile: {'waterGoalMl': 2000}), size: const Size(390, 1400));
    container.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true));
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('today-water'));
    expect(find.descendant(of: row, matching: find.text('2,400 / 2,000 mL')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('120%')), findsOneWidget);
    expect(tester.widget<ProgressRail>(find.descendant(of: row, matching: find.byType(ProgressRail))).value, greaterThanOrEqualTo(1));

    await tester.pumpWidget(const SizedBox());
    final noGoal = await pumpApp(tester, await _fixture(tester, water: [_entry('a', 750)]), size: const Size(390, 1400));
    noGoal.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true));
    await tester.pumpAndSettle();
    final plain = find.byKey(const Key('today-water'));
    expect(find.descendant(of: plain, matching: find.text('750 mL')), findsOneWidget);
    expect(find.descendant(of: plain, matching: find.byType(ProgressRail)), findsNothing, reason: 'no goal, no bar');
    expect(find.descendant(of: plain, matching: find.textContaining('%')), findsNothing, reason: 'and no percentage');
  });

  testWidgets('goals are set in Eat, not Today: Today and its water sheet show progress and logging only', (tester) async {
    final container = await pumpApp(tester, await _fixture(tester, water: [_entry('a', 500)], profile: {'waterGoalMl': 2000}), size: const Size(390, 1400));
    container.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-goals')), findsNothing);
    expect(find.descendant(of: find.byKey(const Key('today-module-nutrition')), matching: find.textContaining('goals')), findsNothing, reason: 'no Set or Edit goals on Today');
    expect(find.byKey(const Key('today-customize')), findsNothing, reason: 'Customize tracking is in Eat, with the goals');
    await tester.tap(find.descendant(of: find.byKey(const Key('today-water')), matching: find.byKey(const Key('water-row'))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('water-goal')), findsNothing, reason: 'the water sheet logs, corrects and removes; it does not edit goals');
    expect(find.byKey(const Key('water-add-250')), findsOneWidget);
    expect(find.byKey(const Key('water-delete-a')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('water-add-250')))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('eat-goals')), findsOneWidget, reason: 'goals live in Eat');
  });

  testWidgets('Eat\'s goals: a suggested 2,000 mL starting goal only while none is saved; Use fills, nothing is saved by itself; blank keeps no goal', (tester) async {
    final profiles = RecordingProfiles();
    final container = await pumpApp(tester, await _fixture(tester, profiles: profiles), size: const Size(390, 1400));
    container.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eat-goals')));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(BottomSheet))).brightness, Brightness.dark, reason: 'the sheet keeps the app\'s Dark look');
    for (final k in ['goal-calories', 'goal-protein', 'goal-water']) {
      expect(tester.widget<TextField>(find.byKey(Key(k))).controller!.text, isEmpty, reason: '$k starts empty');
    }
    expect(find.text('Suggested starting goal: 2,000 mL daily.'), findsOneWidget);
    expect(profiles.waterGoals, isEmpty, reason: 'offering it saves nothing');

    await tester.tap(find.byKey(const Key('water-suggestion-info')));
    await tester.pumpAndSettle();
    expect(find.textContaining('general starting point', findRichText: true), findsWidgets);
    expect(find.textContaining('Other drinks and food also contribute', findRichText: true), findsOneWidget);
    expect(find.textContaining('counts only the water you log', findRichText: true), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Continue without a goal: blank stays no goal.
    await tester.enterText(find.byKey(const Key('goal-calories')), '2200');
    await tester.ensureVisible(find.byKey(const Key('goal-save')));
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(profiles.waterGoals.single, isNull);

    // Accept it, then edit it: the field holds the figure, the person decides what is saved.
    await tester.tap(find.byKey(const Key('eat-goals')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('water-suggestion-use')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('goal-water'))).controller!.text, '2000');
    expect(find.byKey(const Key('water-suggestion')), findsNothing);
    expect(profiles.waterGoals, hasLength(1), reason: 'still nothing new saved');
    await tester.enterText(find.byKey(const Key('goal-water')), '2500');
    await tester.ensureVisible(find.byKey(const Key('goal-save')));
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(profiles.waterGoals.last, 2500);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an existing water goal is never replaced by the suggestion; in fl oz the suggestion is in fl oz', (tester) async {
    final container = await pumpApp(tester, await _fixture(tester, profile: {'waterGoalMl': 1500}), size: const Size(390, 1400));
    container.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eat-goals')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('goal-water'))).controller!.text, '1,500', reason: 'the saved goal, kept');
    expect(find.byKey(const Key('water-suggestion')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    final oz = await pumpApp(tester, await _fixture(tester), size: const Size(390, 1400));
    oz.read(trackingPrefsProvider.notifier)
      ..setDisplay('one', const NutritionDisplay(water: true))
      ..setUnit(VolumeUnit.flOz);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eat-goals')));
    await tester.pumpAndSettle();
    expect(find.text('Suggested starting goal: 67.6 fl oz daily.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('water-suggestion-use')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('goal-water'))).controller!.text, '67.6');
  });

  testWidgets('while the day\'s water is still being read, no amount is shown (an unknown amount is not 0 mL)', (tester) async {
    final pending = StreamController<List<Stored<WaterEntry>>>();
    addTearDown(pending.close);
    final container = await pumpApp(tester, await _fixture(tester, waterStream: pending.stream), size: const Size(390, 1400), settle: false);
    container.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('today-water')), findsOneWidget);
    expect(find.byKey(const Key('water-total')), findsNothing);
    expect(find.text('0 mL'), findsNothing);
    pending.add([stored(WaterEntry(_entry('a', 400)), Kinds.water, 'a', _entry('a', 400))]);
    await tester.pump();
    expect(find.descendant(of: find.byKey(const Key('today-water')), matching: find.text('400 mL')), findsOneWidget);
  });

  testWidgets('correcting an entry in its dialog saves the new amount and nothing breaks as the dialog closes', (tester) async {
    final repo = _Water();
    final container = await pumpApp(tester, await _fixture(tester, repo: repo, water: [_entry('a', 330)]), size: const Size(390, 1400));
    container.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('water-row')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('water-entry-a')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('water-edit-field'))).controller!.text, '330');
    await tester.enterText(find.byKey(const Key('water-edit-field')), '300');
    await tester.tap(find.byKey(const Key('water-edit-save')));
    await tester.pumpAndSettle(); // the dialog's closing animation runs to the end
    expect(repo.updates.single, ('a', 300.0));
    expect(tester.takeException(), isNull, reason: 'the field is not used after its controller is gone');
  });

  testWidgets('the water sheet adds in the chosen unit, pins the day, and offers Undo', (tester) async {
    final repo = _Water();
    final container = await pumpApp(tester, await _fixture(tester, repo: repo), size: const Size(390, 1400));
    container.read(trackingPrefsProvider.notifier)
      ..setDisplay('one', const NutritionDisplay(water: true))
      ..setUnit(VolumeUnit.flOz);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('water-row')).first);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('water-add-8')), matching: find.text('+8 fl oz')), findsOneWidget, reason: 'quick additions follow the unit');
    await tester.tap(find.byKey(const Key('water-add-8')));
    await tester.pumpAndSettle();
    expect(repo.adds.single, (_day, 236.588), reason: '8 US fluid ounces, stored once in millilitres');
    expect(find.byKey(const Key('water-undo')), findsOneWidget, reason: 'Undo is offered in the water line');

    await tester.enterText(find.byKey(const Key('water-custom')), '0');
    await tester.tap(find.byKey(const Key('water-add-custom')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount above zero.'), findsOneWidget);
    expect(repo.adds, hasLength(1), reason: 'nothing invalid is saved');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });
}
