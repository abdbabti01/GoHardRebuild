import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/catalog_names.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/theme.dart' show Accent;
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/coach/exercise_media.dart';
import 'package:gohard_rebuild/features/coach/guide.dart';
import 'package:gohard_rebuild/features/coach/guide_sheets.dart';
import 'package:gohard_rebuild/features/workout/workout_flow.dart';
import 'package:gohard_rebuild/features/workout/workout_repository.dart';
import 'package:gohard_rebuild/features/workout/workout_runtime.dart';
import 'package:gohard_rebuild/features/workout/workout_screen.dart';

import 'support.dart';
import 'ui_support.dart';

/// Renders of the exercise demonstrations (docs/EXERCISE_DEMOS.md) with the app's real fonts into
/// `docs/evidence/exercise-demos/<lang>`: the picker, the recorder's thumbnail beside the selected exercise, and the
/// sheet with a clip, pictures and none, light and dark, and 320 px at twice the text size. Test renders, not phone
/// captures: a clip shows its poster here (the player is native). Only with --dart-define=GOHARD_RENDER=true.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/exercise-demos';

final _manifestText = File('assets/data/exercise-media.json').readAsStringSync();
final _catalog = [for (final c in jsonDecode(File('../api/src/GoHard.Api/Data/exercise-catalog.json').readAsStringSync()) as List) CatalogExercise(c as Json)]
  ..sort((a, b) => a.name.compareTo(b.name));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60))); // images decode in real time
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _save(WidgetTester tester, String lang, String name) async {
  await _settle(tester);
  final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!;
  await tester.runAsync(() async {
    final file = File('$_out/$lang/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  });
}

class _Host extends StatelessWidget {
  const _Host(this.open);
  final void Function(BuildContext) open;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: TextButton(key: const Key('open'), onPressed: () => open(context), child: const Text('Open'))));
}

/// 30 s into a 90 s rest, on the replaced movement; nothing is saved.
class _RestingRepo extends WorkoutRepository {
  _RestingRepo(SyncEngine sync, DateTime now) : super(sync, 'one', FakeClock(now));
  @override
  Future<WorkoutRuntime?> runtime(String workoutId) async =>
      WorkoutRuntime.started(DateTime.utc(2026, 10, 12, 15)).withRest(DateTime.utc(2026, 10, 12, 15), 90, 'x1');
  @override
  Future<void> saveRuntime(String workoutId, WorkoutRuntime runtime) async {}
}

void main() {
  if (!_enabled) {
    test('demonstration renders (run with --dart-define=GOHARD_RENDER=true)', () {});
    return;
  }
  setUpAll(loadAppFonts);

  Future<ProviderContainer> pump(WidgetTester tester, Widget home, String lang,
      {ThemeMode mode = ThemeMode.light, Accent accent = Accent.blue, Size size = const Size(390, 844), double text = 1, List<Override> extra = const []}) async {
    final appearance = AppearanceStore(MemorySecretStore())
      ..accent = accent
      ..mode = mode;
    final c = await pumpApp(tester, [
      ...(await tester.runAsync(() => overridesFor(day: '2026-10-12', appearance: appearance, workouts: [_open])))!,
      exerciseMediaProvider.overrideWith((ref) async => ExerciseMediaCatalog.parse(_manifestText, lang: lang)),
      coachGuideProvider.overrideWith((ref) async => CoachGuideContent.parse(File(lang == 'en' ? 'assets/data/coach-guide.json' : 'assets/data/coach-guide.$lang.json').readAsStringSync())),
      exerciseNamesProvider.overrideWithValue(ExerciseNames.parse(File('assets/data/exercise-names.l10n.json').readAsStringSync())),
      exerciseChoicesProvider.overrideWithValue(_catalog),
      demoStoreProvider.overrideWith((ref) => DemoStore(directory: () async => Directory.systemTemp.createTempSync('render'))),
      ...extra,
    ], home: home, size: size, textScale: text, insets: phoneInsets, settle: false);
    if (lang != 'en') c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang == 'fr' ? 'fr-CA' : lang));
    await _settle(tester);
    return c;
  }

  Widget sheet(String key, String name) => _Host((c) => showExerciseDetails(c, exercise: (catalogKey: key, name: name, isTimed: false)));

  for (final lang in ['en', 'fr', 'ar']) {
    testWidgets('$lang: picker, recorder and sheets', (tester) async {
      // The picker: Watch demo, View guide and the plain (i).
      await pump(tester, const ExercisePicker(), lang);
      await tester.enterText(find.byKey(const Key('exercise-search')), lang == 'en' ? 'press' : lang == 'fr' ? 'développé' : 'ضغط');
      await _save(tester, lang, 'picker');
      await tester.enterText(find.byKey(const Key('exercise-search')), lang == 'en' ? 'curl' : lang == 'fr' ? 'flexion' : 'ثني');
      await _save(tester, lang, 'picker-pictures');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());

      // The recorder: the thumbnail beside the selected (replaced) movement, entry fields and Record set below.
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 10, 12, 15, 0, 30);
      final repo = _RestingRepo(SyncEngine(db, Api(FakeServer(), SessionManager(MemorySecretStore())), SessionManager(MemorySecretStore())), now);
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await pump(tester, Scaffold(body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: WorkoutRecorder(workoutId: 'w-open', onLeave: () {})))), lang,
            mode: mode, extra: [workoutRepositoryProvider.overrideWithValue(repo), clockProvider.overrideWithValue(FakeClock(now))]);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
        await _save(tester, lang, 'recorder-${mode.name}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }

      // The sheet: a clip (light and dark), pictures and nothing.
      for (final (key, name, mode) in [
        ('bench-press', 'Bench press', ThemeMode.light),
        ('bench-press', 'Bench press', ThemeMode.dark),
        ('lateral-raise', 'Lateral raise', ThemeMode.light),
        ('walking-lunge', 'Walking lunge', ThemeMode.dark),
        ('back-squat', 'Back squat', ThemeMode.light),
      ]) {
        await pump(tester, sheet(key, name), lang, mode: mode, accent: mode == ThemeMode.dark ? Accent.pink : Accent.blue);
        await tester.tap(find.byKey(const Key('open')));
        await _save(tester, lang, 'sheet-$key-${mode.name}');
        if (key == 'bench-press' && mode == ThemeMode.light) {
          await tester.drag(find.byType(Scrollable).last, const Offset(0, -560));
          await _save(tester, lang, 'sheet-$key-howto');
          await tester.scrollUntilVisible(find.byKey(const Key('exercise-demo-credit')), 400, scrollable: find.byType(Scrollable).last);
          await _save(tester, lang, 'sheet-$key-credits');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }

      // 320 px at twice the text size.
      await pump(tester, sheet('bench-press', 'Bench press'), lang, accent: Accent.green, size: const Size(320, 700), text: 2);
      await tester.tap(find.byKey(const Key('open')));
      await _save(tester, lang, 'sheet-320-large-text');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, const ExercisePicker(), lang, accent: Accent.green, size: const Size(320, 700), text: 2);
      await tester.enterText(find.byKey(const Key('exercise-search')), lang == 'en' ? 'bench' : lang == 'fr' ? 'couché' : 'ضغط');
      await _save(tester, lang, 'picker-320-large-text');
      expect(tester.takeException(), isNull);
    });
  }
}

final _open = {
  'id': 'w-open',
  'kind': 'manual',
  'title': 'Push',
  'dayKey': '2026-10-12',
  'startedAtUtc': '2026-10-12T15:00:00Z',
  'finishedAtUtc': null,
  'isDeleted': false,
  'exercises': [
    {
      'id': 'x1',
      'ordinal': 1,
      'name': 'Dumbbell bench press',
      'catalogKey': 'dumbbell-bench-press',
      'substitutedForKey': 'bench-press',
      'isPrescribed': true,
      'isTimed': false,
      'targetSets': 3,
      'targetRepsMin': 8,
      'targetRepsMax': 12,
      'restSeconds': 90,
      'isDeleted': false,
    },
    {
      'id': 'x2',
      'ordinal': 2,
      'name': 'Lateral raise',
      'catalogKey': 'lateral-raise',
      'isPrescribed': true,
      'isTimed': false,
      'targetSets': 3,
      'targetRepsMin': 12,
      'targetRepsMax': 15,
      'restSeconds': 60,
      'isDeleted': false,
    },
  ],
};
