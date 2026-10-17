import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/nutrition/water.dart';

import 'food_fakes.dart';
import 'ui_support.dart';

const _day = '2026-10-11';

/// Records what the water sheet asks to save; the day's entries come from [entries].
class _Water implements WaterRepository {
  final adds = <(String, double)>[];
  final removed = <String>[];
  @override
  Future<Receipt> add(String dayKey, double ml, {String? id}) async {
    adds.add((dayKey, WaterRepository.validate(ml)));
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

Future<List<Override>> _fixture(WidgetTester tester, {List<Json> water = const [], Json profile = const {}, _Water? repo, RecordingProfiles? profiles, Stream<List<Stored<WaterEntry>>>? waterStream}) async => [
      ...(await tester.runAsync(() => overridesFor(day: _day, profile: profile,
          appearance: AppearanceStore(MemorySecretStore())..mode = ThemeMode.dark)))!,
      waterProvider.overrideWith((ref, d) => waterStream ?? Stream.value([for (final w in water) if (w['dayKey'] == d) stored(WaterEntry(w), Kinds.water, w['id'] as String, w)])),
      waterRepositoryProvider.overrideWithValue(repo ?? _Water()),
      profileRepositoryProvider.overrideWithValue(profiles ?? RecordingProfiles()),
    ];

void main() {
  testWidgets('water is off until turned on; hiding and showing it keeps the day\'s water and its goal, on Today and Eat', (tester) async {
    await pumpApp(tester, await _fixture(tester, water: [_entry('a', 500), _entry('b', 250), _entry('old', 900, day: '2026-10-10')], profile: {'waterGoalMl': 2000}),
        size: const Size(390, 1400));
    expect(find.byKey(const Key('today-water')), findsNothing, reason: 'water tracking starts off');

    Future<void> setWater(bool on) async {
      await tester.tap(find.byKey(const Key('today-customize')));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('track-water'));
      if (tester.widget<SwitchListTile>(toggle).value != on) await tester.tap(toggle);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byKey(const Key('track-water')))).pop();
      await tester.pumpAndSettle();
    }

    await setWater(true);
    final row = find.byKey(const Key('today-water'));
    expect(find.descendant(of: row, matching: find.text('750 mL')), findsOneWidget, reason: 'today\'s two entries; yesterday\'s stays on its own day');
    expect(find.descendant(of: row, matching: find.text('of 2 L')), findsOneWidget, reason: 'the goal the person set');

    await setWater(false);
    expect(find.byKey(const Key('today-water')), findsNothing);
    await setWater(true);
    expect(find.descendant(of: find.byKey(const Key('today-water')), matching: find.text('750 mL')), findsOneWidget, reason: 'hiding removed nothing');

    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('eat-water')), matching: find.text('750 mL')), findsOneWidget, reason: 'Eat shows the same day\'s water');
    expect(tester.takeException(), isNull);
  });

  testWidgets('goals from Today: the shared form, in the app\'s own look, saves to the one profile; no number is suggested', (tester) async {
    final profiles = RecordingProfiles();
    final container = await pumpApp(tester, await _fixture(tester, profiles: profiles), size: const Size(390, 1400));
    container.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true));
    await tester.pumpAndSettle();

    expect(find.text('Set daily goals'), findsWidgets, reason: 'no goal yet: offered on Today (and Eat), also with nothing logged');
    await tester.tap(find.byKey(const Key('today-goals')));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(Theme.of(tester.element(sheet)).brightness, Brightness.dark, reason: 'the sheet keeps the app\'s Dark look, not the pale panel\'s');
    expect(find.textContaining('repeat every day'), findsOneWidget);
    for (final k in ['goal-calories', 'goal-protein', 'goal-water']) {
      expect(tester.widget<TextField>(find.byKey(Key(k))).controller!.text, isEmpty, reason: '$k starts empty: nothing is suggested');
    }
    await tester.enterText(find.byKey(const Key('goal-calories')), '2200');
    await tester.enterText(find.byKey(const Key('goal-water')), '2000');
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(profiles.goals.single, (2200, null), reason: 'blank protein stays no goal');
    expect(profiles.waterGoals.single, 2000);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
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
    await tester.tap(find.byKey(const Key('water-quick-add')).first);
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

    await tester.tap(find.byKey(const Key('water-quick-add')).first);
    await tester.pumpAndSettle();
    expect(find.text('+8 fl oz'), findsOneWidget, reason: 'quick additions follow the unit');
    await tester.tap(find.byKey(const Key('water-add-8')));
    await tester.pumpAndSettle();
    expect(repo.adds.single, (_day, 236.588), reason: '8 US fluid ounces, stored once in millilitres');
    expect(find.text('Undo'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('water-custom')), '0');
    await tester.tap(find.byKey(const Key('water-add-custom')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount above zero.'), findsOneWidget);
    expect(repo.adds, hasLength(1), reason: 'nothing invalid is saved');
    expect(tester.takeException(), isNull);
  });
}
