import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/me/account_repository.dart';
import 'package:gohard_rebuild/features/me/me_screen.dart';
import 'package:gohard_rebuild/features/me/reminders.dart';

import 'ui_support.dart';

const _day = '2026-10-11';

class _Profiles implements ProfileRepository {
  final units = <String?>[];
  @override
  Future<Receipt> setGoals(Profile current, {required int? calorieGoal, required int? proteinGoal, bool withWater = false, int? waterGoalMl}) => throw UnimplementedError();
  @override
  Future<Receipt> setDisplay(Profile current, {required bool water, required bool carbs, required bool fat}) => throw UnimplementedError();
  @override
  Future<Receipt> update(Profile current, {String? displayName, String? appearance, String? loadUnit, bool? remindersEnabled, String? reminderLocalTime, Json? goals}) async {
    units.add(loadUnit);
    return const Receipt('op', 'pending');
  }
}

class _NoReminders implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool?> notificationsAllowed() async => null;
  @override
  Future<void> replaceAll(List<Notice> notices) async {}
}

Rec _issue(String id) => Rec(ownerId: 'one', kind: Kinds.food, id: id, body: '{}', revision: 1, localRevision: 1, syncState: 'conflict');

Future<ProviderContainer> _openMe(WidgetTester tester, List<Override> overrides, {Size size = const Size(390, 1700), double textScale = 1}) async {
  final container = await pumpApp(tester, [...overrides, reminderSchedulerProvider.overrideWithValue(_NoReminders())], size: size, textScale: textScale);
  await tester.tap(find.byKey(const Key('nav-me')));
  await tester.pumpAndSettle();
  return container;
}

Finder _in(String key, Finder what) => find.descendant(of: find.byKey(Key(key)), matching: what);

void main() {
  testWidgets('Me shows the real identity and no training dashboard, even with a plan and workouts', (tester) async {
    final plan = blockPlan(start: '2026-09-21', recorded: 8);
    final open = openWorkout(plan, 'o3-3', day: _day, recordedSets: 6);
    await _openMe(tester, (await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1', workouts: [open.workout], sets: open.sets)))!);

    expect(tester.widget<Text>(find.byKey(const Key('me-name'))).data, 'Alex Sample', reason: 'the profile\'s own name');
    expect(_in('me-edit-name', find.text('A')), findsOneWidget, reason: 'its initial, not a picture');
    expect(_in('me-edit-name', find.text('Edit profile')), findsOneWidget);
    expect(_in('me-sign-out', find.text('one@example.test')), findsOneWidget, reason: 'the account that is signed in');
    expect(find.textContaining('Babti'), findsNothing);

    for (final section in ['PERSONAL', 'PREFERENCES', 'ACCOUNT']) {
      expect(find.text(section), findsOneWidget);
    }
    for (final key in ['me-body', 'me-goals', 'me-meal-suggestions', 'me-appearance', 'me-units', 'me-motion', 'me-reminders-page', 'me-sync', 'me-delete-account', 'me-sign-out']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(_in('me-appearance', find.text('Blue · System')), findsOneWidget);
    expect(_in('me-units', find.text('Kilograms · °C')), findsOneWidget);
    expect(_in('me-motion', find.text('Device')), findsOneWidget);

    // Training lives in Train. None of it is repeated here.
    for (final gone in ['Your training', 'Strength block', 'Workout history', 'Run history', 'Progress', 'Week history', 'In progress']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(find.textContaining('workouts completed'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byKey(const Key('me-history')), findsNothing);
    expect(find.byKey(const Key('me-plan')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no display name the email stands in; with no profile yet nothing is invented or editable', (tester) async {
    await _openMe(tester, (await tester.runAsync(() => overridesFor(day: _day, profileLoaded: false)))!);
    expect(tester.widget<Text>(find.byKey(const Key('me-name'))).data, 'one@example.test');
    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('Your profile has not loaded on this phone yet.'), findsOneWidget);
    for (final key in ['me-goals', 'me-units']) {
      expect(find.byKey(Key(key)), findsNothing, reason: '$key needs the profile');
    }
    expect(find.byKey(const Key('me-sign-out')), findsOneWidget);
  });

  testWidgets('nutrition goals: nothing is shown as a goal until one is set, then exactly what was set', (tester) async {
    await _openMe(tester, (await tester.runAsync(() => overridesFor(day: _day)))!);
    expect(_in('me-goals', find.text('None set')), findsOneWidget);
    expect(_in('me-goals', find.textContaining('kcal')), findsNothing);
    expect(_in('me-goals', find.textContaining(RegExp(r'\d'))), findsNothing, reason: 'no number stands in for a goal');

    await _openMe(tester, (await tester.runAsync(() => overridesFor(day: _day, calorieGoal: 2200, proteinGoal: 140)))!);
    expect(_in('me-goals', find.text('2,200 kcal · 140 g protein')), findsOneWidget);
    expect(find.text('None set'), findsNothing);

    await _openMe(tester, (await tester.runAsync(() => overridesFor(day: _day, proteinGoal: 120)))!);
    expect(_in('me-goals', find.text('120 g protein')), findsOneWidget, reason: 'only the goal that exists');
    expect(_in('me-goals', find.textContaining('kcal')), findsNothing);
  });

  testWidgets('sync status says Saved only when it is true', (tester) async {
    Future<ProviderContainer> open({int pending = 0, List<Rec> issues = const []}) async =>
        _openMe(tester, (await tester.runAsync(() => overridesFor(day: _day, pending: pending, issues: issues)))!);

    await open();
    expect(_in('me-sync', find.text('Saved')), findsOneWidget);
    expect(_in('me-sync', find.text('Everything is saved to your account')), findsOneWidget);
    expect(_in('me-sync', find.byIcon(Icons.cloud_done_outlined)), findsOneWidget, reason: 'an icon and words, not a colour');

    await open(pending: 2);
    expect(find.text('Saved'), findsNothing);
    expect(_in('me-sync', find.text('Waiting')), findsOneWidget);
    expect(_in('me-sync', find.text('2 changes saved on this phone, waiting to sync')), findsOneWidget);

    await open(pending: 1);
    expect(_in('me-sync', find.text('1 change saved on this phone, waiting to sync')), findsOneWidget);

    // The account cannot be reached: nothing is claimed about it, with or without changes waiting.
    var app = await open();
    app.read(connectionProvider.notifier).report(false);
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Everything is saved to your account'), findsNothing);
    expect(_in('me-sync', find.text('Not synced')), findsOneWidget);
    expect(_in('me-sync', find.text('Can\'t sync right now · tap to try again')), findsOneWidget);

    app = await open(pending: 3);
    app.read(connectionProvider.notifier).report(false);
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(_in('me-sync', find.textContaining('3 changes waiting to sync')), findsOneWidget);
    expect(_in('me-sync', find.textContaining('Can\'t sync right now')), findsOneWidget);

    // A change that needs a decision outranks everything else.
    await open(pending: 2, issues: [_issue('f1')]);
    expect(find.text('Saved'), findsNothing);
    expect(_in('me-sync', find.text('Needs review')), findsOneWidget);
    expect(_in('me-sync', find.textContaining('1 saved change needs review')), findsOneWidget);
    expect(_in('me-sync', find.byIcon(Icons.rule)), findsOneWidget);
    expect(_in('me-sync', find.textContaining('Tap to review')), findsOneWidget);
  });

  testWidgets('every row opens something real: units, motion, appearance, body, goals, delete, sign out', (tester) async {
    final profiles = _Profiles();
    await _openMe(tester, [...(await tester.runAsync(() => overridesFor(day: _day)))!, profileRepositoryProvider.overrideWithValue(profiles)], size: const Size(390, 1900));
    Future<void> tap(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    await tap('me-units');
    expect(find.text('Kilograms · °C'), findsOneWidget, reason: 'the row\'s value');
    expect(find.text('Kilograms'), findsOneWidget, reason: 'the choice in the sheet');
    await tap('unit-lb');
    expect(profiles.units, ['lb'], reason: 'saved through the profile, as before');
    expect(find.byKey(const Key('unit-lb')), findsNothing, reason: 'the sheet closed on the choice');
    await tap('me-units');
    await tap('unit-kg');
    expect(profiles.units, ['lb'], reason: 'choosing the unit already in use changes nothing');
    await tap('me-units');
    await tap('unit-fahrenheit');
    expect(find.textContaining('· °F'), findsOneWidget, reason: 'temperature is a phone setting beside the load unit');
    expect(profiles.units, ['lb'], reason: 'the account is not touched by it');

    for (final (key, title) in [('me-edit-name', 'Edit profile'), ('me-body', 'Body progress'), ('me-goals', 'Nutrition goals'), ('me-appearance', 'Appearance'), ('me-motion', 'Motion & haptics'), ('me-delete-account', 'Delete account')]) {
      await tap(key);
      expect(find.byType(BackButton), findsOneWidget, reason: '$key opens a page');
      expect(find.text(title), findsWidgets, reason: key);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await tap('me-sign-out');
    expect(find.widgetWithText(FilledButton, 'Sign out'), findsOneWidget);
    expect(find.textContaining('stay saved'), findsOneWidget);
  });

  testWidgets('Me and its pages meet contrast, target and label guidelines in all six themes', (tester) async {
    final handle = tester.ensureSemantics();
    for (final accent in Accent.values) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        final store = AppearanceStore(MemorySecretStore())
          ..accent = accent
          ..mode = mode;
        await _openMe(tester, (await tester.runAsync(() => overridesFor(day: _day, appearance: store, calorieGoal: 2200, proteinGoal: 140, pending: 2,
            issues: accent == Accent.green ? [_issue('f1')] : const [], profile: {'remindersEnabled': true, 'reminderLocalTime': '07:30'})))!, size: const Size(390, 1700));
        // Me's list builds lazily: bring a row into view from wherever the list is, up or down.
        Future<void> reveal(Finder f) async {
          final list = find.descendant(of: find.byType(MeScreen), matching: find.byType(Scrollable)).first;
          for (final step in [300.0, -300.0]) {
            try {
              await tester.scrollUntilVisible(f, step, scrollable: list, maxScrolls: 20);
              return;
            } on StateError {
              // Not that way.
            }
          }
        }

        Future<void> check(String what) async {
          final reason = '${accent.name} ${mode.name}: $what';
          await expectLater(tester, meetsGuideline(textContrastGuideline), reason: reason);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: reason);
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline), reason: reason);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: reason);
        }

        await check('Me');
        // Workout reminders live on Me › Reminders with the other reminders.
        await reveal(find.byKey(const Key('me-reminders-page')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('me-reminders-page')));
        await tester.pumpAndSettle();
        await check('reminders');
        expect(tester.getSemantics(_in('me-reminders', find.byType(Switch))), isSemantics(label: 'Workout reminders\nOn days with a planned workout. None while your plan is paused.', hasToggledState: true, isToggled: true, hasTapAction: true, hasEnabledState: true, isEnabled: true, hasFocusAction: true, isFocusable: true),
            reason: 'the switch is announced with what it switches');
        await tester.pageBack();
        await tester.pumpAndSettle();
        for (final key in ['me-motion', 'me-appearance', 'me-delete-account', 'me-edit-name']) {
          await reveal(find.byKey(Key(key)));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(Key(key)));
          await tester.pumpAndSettle();
          await check(key);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        await reveal(find.byKey(const Key('me-units')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('me-units')));
        await tester.pumpAndSettle();
        await check('units sheet');
        await tester.pumpWidget(const SizedBox());
      }
    }
    handle.dispose();
  });

  testWidgets('Me at 320 px with twice the text size: nothing overflows, in its longest states and on its pages', (tester) async {
    final overrides = (await tester.runAsync(() => overridesFor(day: _day, calorieGoal: 10000, proteinGoal: 500, pending: 12,
        profile: {'displayName': 'Alexandria Montgomery-Featherstonehaugh', 'remindersEnabled': true, 'reminderLocalTime': '07:30'})))!;
    (await _openMe(tester, overrides, size: const Size(320, 640), textScale: 2)).read(connectionProvider.notifier).report(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    Future<void> reveal(String key) async {
      final list = find.descendant(of: find.byType(MeScreen), matching: find.byType(Scrollable)).first;
      for (final delta in const [150.0, -150.0]) {
        try {
          await tester.scrollUntilVisible(find.byKey(Key(key)), delta, scrollable: list, maxScrolls: 80);
          break;
        } on StateError {
          // Not in that direction.
        }
      }
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    for (final key in ['me-goals', 'me-meal-suggestions', 'me-appearance', 'me-units', 'me-motion', 'me-reminders-page', 'me-sync', 'me-delete-account', 'me-sign-out']) {
      await reveal(key);
      expect(tester.takeException(), isNull, reason: key);
      expect(tester.getSize(find.byKey(Key(key))).width, lessThanOrEqualTo(320));
    }
    expect(find.textContaining('12 changes waiting to sync'), findsOneWidget);

    for (final key in ['me-motion', 'me-appearance', 'me-delete-account', 'me-reminders-page', 'me-meal-suggestions']) {
      await reveal(key);
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      if (key == 'me-reminders-page') expect(find.byKey(const Key('me-reminder-time')), findsOneWidget, reason: 'the workout time is on Reminders');
      await tester.dragFrom(const Offset(160, 400), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'page behind $key');
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await reveal('me-units');
    await tester.tap(find.byKey(const Key('me-units')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-lb')), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'units sheet');
  });
}
