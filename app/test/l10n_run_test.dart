import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/activity/announcer.dart';
import 'package:gohard_rebuild/features/activity/intervals.dart';
import 'package:gohard_rebuild/features/activity/move_prefs.dart';
import 'package:gohard_rebuild/l10n/app_localizations.dart' show lookupAppLocalizations;

/// Run / Walk in French and Arabic: cue words in the resolved language, speech only in an installed offline voice of
/// that language, and typed distances in either language's digits.
class _Voice implements VoiceOut {
  _Voice(this.installed);
  final List<VoiceOption> installed;
  final said = <(String, VoiceOption?)>[];
  @override
  Future<void> speak(String text, {VoiceOption? voice, required double pitch}) async => said.add((text, voice));
  @override
  Future<void> stop() async {}
  @override
  Future<List<VoiceOption>> voices() async => installed;
}

const _en = (name: 'Samantha', locale: 'en-US');
const _frFr = (name: 'Amélie', locale: 'fr-FR');
const _frCa = (name: 'Chantal', locale: 'fr_CA');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a phase cue and a distance update are made in French and Arabic', () {
    const plan = IntervalPlan(run: 60, walk: 90, reps: 2);
    for (final (lang, run, done) in [('fr', 'Cours pendant 1 minute.', 'parcourus.'), ('ar', 'اجرِ لمدة دقيقة واحدة.', 'اكتملت')]) {
      final l = lookupAppLocalizations(Locale(lang));
      final m = CueMarks();
      CueStep at(int s, double d) => recordingCues(
          marks: m, activityId: 'a', plan: plan, skips: const [], activeMs: s * 1000, distanceMeters: d, paceSecondsPerUnit: null,
          unit: DistanceUnit.km, prefs: const MovePrefs(everyDistance: 0.5), l: l);
      at(0, 0);
      at(61, 100); // walk phase
      final c = at(151, 520).cue!; // round 2 run, 0.5 km
      expect(c.text, startsWith(lang == 'fr' ? 'Dernier tour. $run' : 'الجولة الأخيرة. $run'));
      expect(c.text, contains(done));
      expect(c.key, 'a:phase:2', reason: 'the key never depends on the language');
    }
    expect(spokenDuration(90, lookupAppLocalizations(const Locale('fr'))), '1 minute 30 secondes');
    expect(spokenDuration(120, lookupAppLocalizations(const Locale('ar'))), 'دقيقتين');
  });

  test('only a voice of the app language is chosen, the app region first', () {
    final all = [_en, _frFr, _frCa];
    expect(voiceFor(all, 'fr', null), _frCa);
    expect(voiceFor(all, 'fr', _frFr), _frFr, reason: 'a chosen French voice is kept');
    expect(voiceFor(all, 'fr', _en), _frCa, reason: 'an English voice is never used for French');
    expect(voiceFor(all, 'en', null), _en);
    expect(voiceFor(all, 'ar', null), isNull);
  });

  for (final (lang, installed, expected) in [
    ('ar', [_en, _frCa], null),
    ('fr', [_en, _frFr, _frCa], _frCa),
  ]) {
    test('announcer in $lang: speaks only in a $lang offline voice; with none the cue is still shown', () async {
      final voice = _Voice(installed);
      final store = MovePrefsStore(MemorySecretStore())..value = const MovePrefs(voice: true, vibrate: false, voiceName: 'Samantha', voiceLocale: 'en-US');
      final c = ProviderContainer(overrides: [
        voiceOutProvider.overrideWithValue(voice), movePrefsStoreProvider.overrideWithValue(store), ownerProvider.overrideWithValue('one'),
        appLocaleProvider.overrideWithValue(Locale(lang)),
      ]);
      addTearDown(c.dispose);
      c.listen(announcerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final l = c.read(appL10nProvider);
      final cue = Cue(l.runCueRun(spokenDuration(60, l)), key: 'p1', priority: Cue.phase);
      c.read(announcerProvider.notifier).say(cue);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(announcerProvider)?.text, cue.text, reason: 'the words are on screen either way');
      expect(voice.said, expected == null ? isEmpty : [(cue.text, expected)]);
    });
  }

  test('typed distances in French and Arabic', () {
    expect(parseNonNegative('5,2'), 5.2);
    expect(parseNonNegative('٥٫٢'), 5.2);
    expect(parseNonNegative('1 200'), isNull, reason: 'no grouping in a distance');
    expect(parsePositiveInt('١٢ ٠٠٠', grouping: true), 12000, reason: 'a step goal may be grouped');
  });
}
