import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Ask GoHard against a REAL provider (docs/COACH.md). Not in the default run, and only meaningful against an API
/// that declares `coach.ask`:
///
///     scripts\test-android.ps1 -ApiBase https://gohardrebuild-production.up.railway.app -Only journey_coach_live_test
///
/// A disposable account builds a plan draft (not activated), asks a split question and a follow-up, asks about an
/// exercise, and, when the model offers a change: previews it, sees it flagged as made for an earlier draft after an
/// edit, rebuilds the preview, applies it to the draft and undoes it. The account is deleted at the end, whatever
/// happened. Model answers vary: what was offered is printed as GOHARD_LIVE lines, and nothing here is a fixture.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('coach live: real answers, a real proposal preview, apply to draft and undo', (tester) async {
    final j = Journey(tester, binding);
    Finder prefix(String p) => find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(p));
    // ignore: avoid_print
    void log(String s) => print('GOHARD_LIVE: $s');
    // Paced like a person (Groq allows this model 8K tokens a minute); a "busy" answer is retried once after its wait.
    Future<void> realWait(int seconds) async {
      await Future<void>.delayed(Duration(seconds: seconds));
      await tester.pump();
    }
    // The conversation builds lazily, so earlier answers can be out of the tree: wait for an answer key not seen before.
    final seen = <Key>{};
    Iterable<Key> answerKeys() => prefix('ask-answer-').evaluate().map((e) => e.widget.key!);
    bool fresh() => answerKeys().any((k) => !seen.contains(k));
    Future<void> waitAnswer(int answers) async {
      for (var i = 0; i < 240 && !fresh() && find.byKey(const Key('ask-problem')).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    Future<void> ask(String question, int answers) async {
      if (answers > 1) await realWait(25);
      seen.addAll(answerKeys());
      await j.type('ask-input', question);
      // Send is disabled for a moment while a reopened conversation loads from the phone; tap until it really went.
      bool went() => find.byKey(const Key('ask-sending')).evaluate().isNotEmpty || fresh() || find.byKey(const Key('ask-problem')).evaluate().isNotEmpty;
      for (var attempt = 0; attempt < 4 && !went(); attempt++) {
        if (attempt > 0) log('send tap did not register (attempt $attempt; Ask screens open: ${find.byKey(const Key('ask-context')).evaluate().length})');
        await j.settle(4);
        await tester.tap(find.byKey(const Key('ask-send')).hitTestable().last, warnIfMissed: false);
        await j.settle(2);
      }
      await waitAnswer(answers);
      if (find.byKey(const Key('ask-problem')).evaluate().isNotEmpty && find.textContaining('busy').evaluate().isNotEmpty) {
        log('busy once (Groq per-minute limit); retrying after 25 s');
        await j.shot('l00-live-busy');
        await realWait(25);
        await j.tapKey('ask-retry');
        await waitAnswer(answers);
      }
      if (find.byKey(const Key('ask-problem')).evaluate().isNotEmpty) fail('Ask GoHard answered with a problem state. On screen: ${j.onScreen}');
      if (!fresh()) await j.shot('l99-live-no-answer');
      expect(fresh(), isTrue, reason: 'a real answer arrived (answer $answers of this journey). On screen: ${j.onScreen}');
      await j.settle(4);
    }

    try {
      await j.start('Coach Live');
      await j.settle(12);
      final caps = (await j.api.get<Map>('/capabilities')).data!['capabilities'] as List;
      if (!caps.contains('coach.ask')) fail('This API does not declare coach.ask: no provider is configured');

      // --- A plan draft on the Structure step; nothing is activated in this journey.
      await j.tapKey('today-create-plan');
      await j.tapKey('plan-path-direct');
      await j.tapKey('plan-path-template');
      await j.chooseDays(Journey.daysIncludingToday());
      await j.tapKey('builder-next');
      await j.waitFor(find.byKey(const Key('coach-help-builder.structure')), what: 'the Structure step with its help entry');
      // The guide introduces the step once by itself; if it has already, the help entry opens it.
      if (find.byKey(const Key('coach-spot-builder.structure')).evaluate().isEmpty) await j.tapKey('coach-help-builder.structure');

      // 1–2. A contextual split question and a natural follow-up: Ask me in the guide's bubble.
      await j.tapKey('coach-say-ask');
      await j.waitFor(find.byKey(const Key('ask-context')));
      await ask('Why this split for my schedule?', 1);
      await j.shot('l01-live-split-answer');
      await ask('How would Upper/Lower differ for me?', 2);
      await j.shot('l02-live-follow-up');
      await j.tapKey('ask-close');

      // 3. An exercise question from the workout editor.
      await j.tapKey('builder-next');
      await j.waitFor(find.byKey(const Key('exercise-info-0-0')), what: 'the workout editor');
      await j.tapKey('exercise-info-0-0');
      await j.tapKey('exercise-info-ask');
      await j.waitFor(find.byKey(const Key('ask-context')));
      await ask('Can I replace it with a dumbbell exercise? If so, suggest that change for this workout.', 3);
      await j.shot('l03-live-exercise-answer');

      // 4–8. A real proposal, when the model offers one.
      if (prefix('ask-preview-').evaluate().isEmpty) {
        log('no proposal offered for the replacement question');
        return;
      }
      log('proposal offered');
      await j.tap(prefix('ask-preview-').first);
      await j.waitFor(find.byKey(const Key('ask-apply')), what: 'the preview');
      await j.shot('l04-live-proposal-preview');
      // Keep current: nothing changes. Then the draft is edited, so the suggestion is for an earlier version.
      await j.tapKey('ask-keep');
      await j.tapKey('ask-close');
      await j.tapKey('exercise-0-1');
      await j.type('rx-sets', '5');
      await j.tapKey('rx-save');
      await j.tapKey('coach-help-builder.workouts');
      await j.tapKey('coach-say-ask');
      await j.settle(6);
      // The reopened conversation builds lazily from the top: scroll it until the suggestion's card is built.
      for (var i = 0; i < 20 && prefix('ask-preview-').hitTestable().evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -350));
        await j.settle(2);
      }
      await tester.tap(prefix('ask-preview-').hitTestable().first);
      await j.settle(4);
      await j.waitFor(find.byKey(const Key('ask-draft-changed')), what: 'the stale-draft notice');
      await j.shot('l05-live-proposal-stale');
      await j.tapKey('ask-rebuild');
      await j.waitFor(find.byKey(const Key('ask-apply')));
      await j.tapKey('ask-apply');
      await j.waitFor(prefix('ask-undo-'), what: 'the applied confirmation with Undo');
      await j.shot('l06-live-applied-to-draft');
      await j.tap(prefix('ask-undo-').first);
      await j.settle(6);
      log(prefix('ask-undone-').evaluate().isNotEmpty ? 'undo restored the draft' : 'undo refused: ${j.onScreen}');
      await j.shot('l07-live-undo');
      await j.tapKey('ask-close');
      await j.waitFor(find.textContaining('5 ×'), what: 'the newer edit (5 sets) still in the draft');
    } finally {
      // The disposable account goes, whatever happened above.
      try {
        final token = await j.apiToken();
        final r = await j.api.delete<dynamic>('/account', data: {'password': j.password}, options: Options(headers: {'Authorization': 'Bearer $token'}));
        log('account ${j.email} deletion: HTTP ${r.statusCode}');
      } on Object catch (e) {
        log('account ${j.email} NOT deleted (${e.runtimeType}): delete it with scripts/delete-verify-account.ps1 or by signing in');
      }
    }
  });
}
