import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/l10n/app_localizations.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support.dart';

/// French and Arabic on a real install against the local API (docs/LOCALIZATION.md › Verification), in two runs of
/// this file by scripts\test-android.ps1 -Only journey_language_test (not in the default run).
///
/// Phase 1: on the signed-out screen Français is chosen; a new account is created and setup skipped, all in French.
/// A manual workout is set up by finding "développé couché" (Bench press) in the exercise picker. A French load
/// "82,5" and 8 reps are typed but not recorded; the language is changed to العربية from Me while the draft waits
/// (recorded: lang-switch); back in Train the same exercise, the typed "82,5" and the clock are still there, in RTL.
/// Recording it stores 82.5 kg; a second set typed in Arabic digits "٨٢٫٥" / "٨" stores 82.5 kg × 8 too. On Eat,
/// "دجاج" finds the bundled chicken breast. Phase 2 is a new process: still Arabic and RTL, the same open workout
/// with its two sets, and nothing was sent or recorded twice.
const _phase = String.fromEnvironment('GOHARD_PHASE');
const _channel = MethodChannel('plugins.flutter.io/integration_test');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('language phase $_phase', (tester) async {
    final j = Journey(tester, binding);
    final saved = File('${(await getApplicationDocumentsDirectory()).path}/language-journey-workout.txt');
    ProviderContainer scope() => ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    final fr = lookupAppLocalizations(const Locale('fr', 'CA')), ar = lookupAppLocalizations(const Locale('ar'));
    TextDirection direction() => Directionality.of(tester.element(find.byKey(const Key('nav-today'))));
    String field(String key) => tester.widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField))).controller!.text;
    Future<void> realTime(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    }

    List<(double?, int?)> sets(String workoutId) =>
        [for (final s in scope().read(allSetsProvider).value ?? const <Stored<WorkoutSet>>[]) if (s.value.workoutId == workoutId && !s.value.isDeleted) (s.value.loadKg, s.value.reps)];

    if (_phase == '1') {
      await app.main();
      await binding.convertFlutterSurfaceToImage();
      // --- Signed out: the language is chosen before an account exists.
      await j.tapKey('language-button');
      await j.tapKey('language-fr-CA');
      await j.closeSheet();
      await j.shot('lang-01-signin-fr');
      j.email = 'language-journey-${DateTime.now().millisecondsSinceEpoch}@example.test';
      await j.tapKey('auth-toggle');
      await j.type('auth-name', 'Camille');
      await j.type('auth-email', j.email);
      await j.type('auth-password', j.password);
      await j.tapKey('auth-submit');
      await j.waitFor(find.byKey(const Key('setup-skip')), what: 'setup');
      await j.shot('lang-02-setup-fr');
      await j.tapKey('setup-skip');
      await j.waitFor(find.text(fr.navToday), what: 'Today in French');
      expect(direction(), TextDirection.ltr);
      await j.shot('lang-03-today-fr');

      // --- A manual workout: Bench press found by its French name.
      await j.tapKey('nav-train');
      await j.tapKey('start-manual');
      await j.tapKey('manual-add-exercise');
      await j.type('exercise-search', 'développé couché');
      await j.waitFor(find.byKey(const Key('exercise-bench-press')), what: 'Bench press by its French name');
      await j.shot('lang-04-picker-fr');
      await j.tapKey('exercise-bench-press');
      await j.tapKey('manual-start');
      await j.waitFor(find.byKey(const Key('set-load')), what: 'the recorder');
      final workoutId = scope().read(workoutListProvider).single.id;
      await saved.writeAsString(workoutId);
      await j.type('set-load', '82,5');
      await j.type('set-reps', '8');
      FocusManager.instance.primaryFocus?.unfocus();
      await j.settle();
      await j.shot('lang-05-draft-fr');

      // --- Mid-workout, from Me: العربية. The real screen is recorded (the test surface hides it otherwise).
      await _channel.invokeMethod<void>('revertFlutterImage');
      debugPrint('GOHARD_REC:start:lang-switch');
      await realTime(1500);
      await j.tapKey('nav-me');
      await realTime(800);
      await j.tapKey('me-language');
      await realTime(1000);
      await j.tapKey('language-ar');
      await realTime(1500);
      Navigator.of(tester.element(find.byKey(const Key('language-ar')))).pop();
      await realTime(1200);
      await j.tapKey('nav-train');
      await realTime(2500);
      debugPrint('GOHARD_REC:stop');
      await realTime(3000);
      await _channel.invokeMethod<void>('convertFlutterSurfaceToImage');
      await j.settle();

      expect(direction(), TextDirection.rtl);
      expect(find.text(ar.navTrain), findsOneWidget);
      expect(field('set-load'), '82,5', reason: 'the raw French draft is kept, not reinterpreted');
      expect(field('set-reps'), '8');
      expect(sets(workoutId), isEmpty, reason: 'changing language records nothing');
      await j.shot('lang-06-draft-kept-ar');
      await j.tapKey('complete-set');
      await j.waitUntil(() async => sets(workoutId).length == 1, what: 'the first set');
      expect(sets(workoutId).single, (82.5, 8));

      // --- A set typed in Arabic-Indic digits.
      await j.type('set-load', '٨٢٫٥');
      await j.type('set-reps', '٨');
      await j.tapKey('complete-set');
      await j.waitUntil(() async => sets(workoutId).length == 2, what: 'the second set');
      expect(sets(workoutId).last, (82.5, 8));
      await j.shot('lang-07-recorded-ar');

      // --- An Arabic food alias finds the bundled chicken breast.
      await j.tapKey('nav-eat');
      await j.tapKey('log-food');
      await j.type('food-search', 'دجاج');
      await j.waitFor(find.byKey(const Key('common-chicken-breast')), what: 'chicken breast by its Arabic name');
      await j.shot('lang-08-food-alias-ar');
      await scope().read(syncProvider).flush();
    } else {
      // --- A new process: the choice, the direction and the open workout were kept on the phone.
      await app.main();
      await binding.convertFlutterSurfaceToImage();
      await j.waitFor(find.text(ar.navToday), what: 'Today in Arabic after a restart');
      expect(direction(), TextDirection.rtl);
      await j.shot('lang-09-restart-ar');
      final workoutId = await saved.readAsString();
      await j.waitUntil(() async => sets(workoutId).length == 2, what: 'the two sets after the restart');
      expect(sets(workoutId), [(82.5, 8), (82.5, 8)]);
      expect(scope().read(workoutListProvider).singleWhere((w) => w.id == workoutId).finishedAtUtc, isNull, reason: 'the workout is still open');
      await j.tapKey('nav-train');
      await j.waitFor(find.byKey(const Key('set-load')), what: 'the open workout');
      await j.shot('lang-10-workout-after-restart-ar');
    }
  });
}
