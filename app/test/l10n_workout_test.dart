import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/catalog_names.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/plans/plan_rules.dart';
import 'package:gohard_rebuild/features/workout/workout_screen.dart';
import 'package:gohard_rebuild/l10n/app_localizations.dart';

import 'support.dart';
import 'ui_support.dart';

// Workout and progress in French and Arabic: typed loads reach the same canonical kilograms, Arabic plurals, the
// bundled exercise names, and a language change in the middle of a workout that keeps everything.

const _day = '2026-10-12';
const _pid = '6f1c2d3e-4a5b-4c6d-8e7f-90a1b2c3d4e5';

Json _plan() {
  final workouts = [
    {'id': 'push', 'name': 'Push', 'notes': null, 'exercises': [
      {'occurrenceKey': 'push-e1', 'catalogKey': 'bench-press', 'name': 'Bench press', 'isTimed': false, 'targetSets': 3, 'targetRepsMin': 8, 'targetRepsMax': 10, 'restSeconds': 90},
    ]},
  ];
  final schedule = {'mode': 'fixed', 'cycle': <String>[], 'trainingDays': <int>[], 'cycleAnchor': 0, 'pattern': [for (var d = 1; d <= 7; d++) {'weekday': d, 'workoutId': 'push'}]};
  return {
    'id': _pid, 'title': 'Daily push', 'lifecycle': 'active', 'pausedOn': null, 'startDate': _day, 'blockWeeks': 2, 'minRecoveryDays': 0, 'isOngoing': false,
    'timeBudgetMinutes': 45, 'templateId': null, 'workouts': workouts, 'schedule': schedule, 'occasions': PlanRules.generate(_pid, _day, 2, schedule, workouts),
  };
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('French and Arabic loads are the same canonical kilograms; a decimal still being typed is not a number yet', () {
    for (final typed in ['82.5', '82,5', '٨٢٫٥', '۸۲٫۵', ' 82,5 ']) {
      expect(typedLoad(typed), 82.5, reason: typed);
      expect(loadInputToKg(typedLoad(typed)!, LoadUnit.kg), 82.5);
    }
    expect(loadInputToKg(typedLoad('٢٠٫٥')!, LoadUnit.lb), closeTo(9.299, 0.001));
    for (final partial in ['82,', '٨٢٫', '82.', '82, ']) {
      expect(typedLoad(partial), isNull, reason: '"$partial" is still being typed');
    }
    expect(typedLoad(''), isNull);
    expect(parsePositiveInt('١٢'), 12);
  });

  test('Arabic set counts use the right plural form at 0, 1, 2, 3, 11 and 100; English and French keep theirs', () {
    final ar = lookupAppLocalizations(const Locale('ar')), fr = lookupAppLocalizations(const Locale('fr', 'CA')), en = lookupAppLocalizations(const Locale('en'));
    expect([for (final n in [0, 1, 2, 3, 11, 100]) ar.workoutSetsRecorded(n)],
        ['لم تُسجَّل أي مجموعة', 'سُجّلت مجموعة واحدة', 'سُجّلت مجموعتان', 'سُجّلت 3 مجموعات', 'سُجّلت 11 مجموعة', 'سُجّلت 100 مجموعة']);
    expect([for (final n in [0, 1, 2, 3, 11, 100]) ar.workoutSetCount(n)], ['صفر مجموعات', 'مجموعة واحدة', 'مجموعتان', '3 مجموعات', '11 مجموعة', '100 مجموعة']);
    expect([for (final n in [0, 1, 2]) fr.workoutSetsRecorded(n)], ['0 série enregistrée', '1 série enregistrée', '2 séries enregistrées']);
    expect([for (final n in [0, 1, 2]) en.workoutSetsRecorded(n)], ['0 sets recorded', '1 set recorded', '2 sets recorded']);
    expect(en.workoutFinishSummary(1, 2), '1 set across 2 movements recorded.');
    expect(targetText(sets: 4, repsMin: 5, repsMax: 8, l: en), '4 sets · 5–8 reps');
    expect(targetText(sets: 4, repsMin: 5, repsMax: 8, l: fr), '4 séries · 5–8 répétitions');
  });

  test('the bundled exercise names cover the whole catalog with its own English names; custom and renamed names stay', () {
    final catalog = (jsonDecode(File('../api/src/GoHard.Api/Data/exercise-catalog.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final raw = File('assets/data/exercise-names.l10n.json').readAsStringSync();
    final file = (jsonDecode(raw) as Map<String, dynamic>)['exercises'] as Map<String, dynamic>;
    expect(catalog, hasLength(50));
    expect(file.keys.toSet(), {for (final e in catalog) e['key']});
    for (final e in catalog) {
      final x = file[e['key']] as Map<String, dynamic>;
      expect(x['en'], e['name'], reason: e['key'] as String);
      expect((x['fr'] as String).trim(), isNotEmpty);
      expect((x['ar'] as String).trim(), isNotEmpty);
    }
    final names = ExerciseNames.parse(raw);
    const fr = Locale('fr', 'CA'), ar = Locale('ar');
    expect(names.name('bench-press', 'Bench press', fr), 'Développé couché');
    expect(names.name('bench-press', 'Bench press', ar), 'ضغط الصدر بالبار');
    expect(names.name('bench-press', 'Bench press', const Locale('en')), 'Bench press');
    // Renamed, custom and free-text names are shown as stored.
    expect(names.name('bench-press', 'My heavy bench', ar), 'My heavy bench');
    expect(names.name('custom:abc', 'Sled push', fr), 'Sled push');
    expect(names.name(null, 'Bench press', fr), 'Bench press');
    expect(names.category('Legs', ar), 'الساقان');
    expect(names.equipment('Dumbbell', fr), 'Haltères');
    // Distinct variants keep distinct names.
    expect(names.name('dumbbell-bench-press', 'Dumbbell bench press', fr), isNot(names.name('bench-press', 'Bench press', fr)));
  });

  testWidgets('French and Arabic entries record 82.5 kg; a partial "82," is refused; a language change keeps exercise, entry and clock', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = FakeClock(DateTime.utc(2026, 10, 12, 15));
    final container = await pumpApp(
      tester,
      [
        ...(await tester.runAsync(() => overridesFor(day: _day, plans: [_plan()], primaryPlanId: _pid, liveWorkouts: true)))!,
        dbProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        syncProvider.overrideWith((ref) {
          final engine = SyncEngine(db, Api(FakeServer()..offline = true, ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
          ref.onDispose(engine.dispose);
          return engine;
        }),
      ],
      size: const Size(390, 2600), settle: false,
    );
    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<T> run<T>(Future<T> work) async {
      T? out;
      var done = false;
      work.then<void>((v) => out = v).whenComplete(() => done = true);
      for (var i = 0; i < 400 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      return out as T;
    }

    Future<void> tap(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await settle();
    }

    Finder input(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));
    String text(String key) => tester.widget<TextField>(input(key)).controller!.text;
    void language(AppLanguage l) => container.read(devicePrefsProvider.notifier).setLanguage(l);

    await settle();
    language(AppLanguage.frCA);
    await settle();
    await tap('today-details');
    await tap('preview-start');
    final repo = container.read(workoutRepositoryProvider);
    final id = container.read(workoutListProvider).singleWhere((w) => w.isOpen).id;
    Future<List<WorkoutSet>> sets() => run(repo.sets(id));
    final fr = lookupAppLocalizations(const Locale('fr', 'CA'));

    await tester.enterText(input('set-load'), '82,');
    await tester.enterText(input('set-reps'), '8');
    await settle();
    await tap('complete-set');
    expect(await sets(), isEmpty, reason: 'a decimal still being typed is never recorded');
    expect(find.text(fr.workoutInvalidLoadFormat), findsOneWidget);

    await tester.enterText(input('set-load'), '82,5');
    await settle();
    await tap('complete-set');
    expect([for (final s in await sets()) s.loadKg], [82.5]);

    // Mid-workout to Arabic: same exercise, same typed entry, same clock; nothing recreated.
    await tester.enterText(input('set-load'), '٨٢٫٥');
    await settle();
    final clockBefore = tester.widget<Text>(find.descendant(of: find.byKey(const Key('workout-exercise-panel')), matching: find.text('Bench press'))).data;
    language(AppLanguage.ar);
    await settle();
    expect(Directionality.of(tester.element(find.byKey(const Key('complete-set')))), TextDirection.rtl);
    expect(text('set-load'), '٨٢٫٥');
    expect(text('set-reps'), '8');
    expect(find.descendant(of: find.byKey(const Key('workout-exercise-panel')), matching: find.text(clockBefore!)), findsOneWidget, reason: 'the same exercise stays selected');
    expect(find.text(lookupAppLocalizations(const Locale('ar')).workoutRecordAnotherSet), findsNothing);
    expect(find.text(lookupAppLocalizations(const Locale('ar')).workoutRecordSet), findsOneWidget);
    await tap('complete-set');
    expect([for (final s in await sets()) s.loadKg], [82.5, 82.5]);
    expect(find.byKey(const Key('rest-clock')), findsOneWidget, reason: 'the rest deadline started and survives the language');
  });
}
