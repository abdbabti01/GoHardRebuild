import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/l10n/app_localizations.dart' show lookupAppLocalizations;
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/coach/coach_avatar.dart';
import 'package:gohard_rebuild/features/coach/coach_bubble.dart';
import 'package:gohard_rebuild/features/coach/coach_client.dart';
import 'package:gohard_rebuild/features/coach/coach_contract.dart';
import 'package:gohard_rebuild/features/coach/coach_rig.dart';
import 'package:gohard_rebuild/features/coach/guide.dart';

/// Coach localization (docs/LOCALIZATION.md): the translated guide with its English fallback, the reply language sent
/// with an explicit question, and Leon/Leona right to left (on the left, as painted, the tail at the mouth).

/// Serves only the files it is given; anything else is missing.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, String> files;
  @override
  Future<ByteData> load(String key) async {
    final f = files[key];
    if (f == null) throw FlutterError('missing $key');
    return ByteData.sublistView(utf8.encode(f));
  }
}

final _en = File('assets/data/coach-guide.json').readAsStringSync();
String _renamed(String note) => jsonEncode({...jsonDecode(_en) as Json, 'reviewNote': note});

void main() {
  group('guide loader', () {
    test('French and Arabic files are used for their language; English otherwise', () async {
      final b = _Bundle({'assets/data/coach-guide.json': _en, 'assets/data/coach-guide.fr.json': _renamed('fr note'), 'assets/data/coach-guide.ar.json': _renamed('ar note')});
      Future<String> note(Locale l) async => (await loadCoachGuide(l, CoachGuideContent.parse, bundle: b)).reviewNote;
      expect(await note(const Locale('fr', 'CA')), 'fr note');
      expect(await note(const Locale('ar')), 'ar note');
      expect(await note(const Locale('en')), CoachGuideContent.parse(_en).reviewNote);
    });

    test('a missing or unreadable translation falls back to the English original', () async {
      final english = CoachGuideContent.parse(_en).reviewNote;
      final b = _Bundle({'assets/data/coach-guide.json': _en, 'assets/data/coach-guide.ar.json': '{"version": 1, "sources": ['});
      expect((await loadCoachGuide(const Locale('fr', 'CA'), CoachGuideContent.parse, bundle: b)).reviewNote, english, reason: 'missing');
      expect((await loadCoachGuide(const Locale('ar'), CoachGuideContent.parse, bundle: b)).reviewNote, english, reason: 'unparseable');
    });

    test('the bundled translations, when present, keep every ID, source link and term of the original', () {
      final en = CoachGuideContent.parse(_en);
      for (final lang in ['fr', 'ar']) {
        final f = File('assets/data/coach-guide.$lang.json');
        if (!f.existsSync()) continue;
        final t = CoachGuideContent.parse(f.readAsStringSync());
        expect(t.splits.keys, en.splits.keys, reason: lang);
        expect(t.exercises.keys, en.exercises.keys, reason: lang);
        expect({for (final s in t.sources.values) s.id: s.url}, {for (final s in en.sources.values) s.id: s.url}, reason: lang);
        expect(t.terms.keys, en.terms.keys, reason: lang);
      }
    });
  });

  test('an explicit question carries a validated reply language; the question is sent as typed', () {
    const coach = CoachContext(label: 'Upper / Lower');
    Json body(Locale l) => askRequestBody('r1', 'Pourquoi?', const [{'role': 'user', 'text': 'Earlier'}], coach, null, l);
    expect(body(const Locale('fr', 'CA'))['language'], 'fr-CA');
    expect(body(const Locale('ar'))['language'], 'ar');
    expect(body(const Locale('en'))['language'], 'en');
    expect(body(const Locale('de'))['language'], 'en', reason: 'only the allowlist is ever sent');
    expect(body(const Locale('ar'))['question'], 'Pourquoi?');
    expect(body(const Locale('ar'))['history'], [{'role': 'user', 'text': 'Earlier'}], reason: 'earlier messages keep their words');
  });

  group('right to left', () {
    Future<void> pump(WidgetTester tester, Locale locale, RigFrame frame) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          locale: locale, localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
          theme: goTheme(Accent.blue, Brightness.light),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 80),
              child: CoachSpeech(say: const CoachSay('مرحبًا! حصة تدريبية مخطط لها اليوم.'), portrait: const Size(92, 114), frame: frame, bleed: frame == RigFrame.edge ? 16 : 0),
            ),
          ),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    dynamic tail(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.descendant(of: find.byType(CoachSpeech), matching: find.byType(CustomPaint)))
        .map((p) => p.painter)
        .firstWhere((p) => p.runtimeType.toString() == '_TailPainter');

    for (final frame in RigFrame.values) {
      testWidgets('$frame: the guide is on the left, the tail runs from the bubble to its mouth, the art is not flipped', (tester) async {
        await pump(tester, const Locale('ar'), frame);
        final face = tester.getRect(find.byType(RigPortrait));
        final bubble = tester.getRect(find.byType(CoachBubble));
        expect(face.center.dx, lessThan(bubble.left), reason: 'the guide on the trailing (left) side');
        final t = tail(tester);
        expect(t.right, isFalse);
        final at = t.locate();
        expect(at, isNotNull);
        final Rect b = at.bubble;
        final Offset mouth = at.mouth;
        expect(mouth.dx, lessThan(b.left), reason: 'the tail leaves the bubble towards the guide');
        expect(mouth.dy, inInclusiveRange(b.top, b.bottom));
        // No mirroring: no negative x-scale anywhere, and the rig draws the painting as painted.
        for (final tr in tester.widgetList<Transform>(find.byType(Transform))) {
          expect(tr.transform.storage[0], greaterThanOrEqualTo(0), reason: 'a flipped Transform');
        }
        expect(RigGeometry(RigArt.leon, frame, const Size(92, 114), direction: TextDirection.rtl).mirrored, isFalse);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('left to right is unchanged: the edge guide is on the right, mirrored to face its words', (tester) async {
      await pump(tester, const Locale('en'), RigFrame.edge);
      expect(tester.getRect(find.byType(RigPortrait)).center.dx, greaterThan(tester.getRect(find.byType(CoachBubble)).right));
      expect(tail(tester).right, isTrue);
      expect(RigGeometry(RigArt.leon, RigFrame.edge, const Size(92, 114)).mirrored, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('coach names are translated for display only', () {
    final ar = lookupAppLocalizations(const Locale('ar')), fr = lookupAppLocalizations(const Locale('fr'));
    expect(CoachGuide.leon.displayName(ar), 'ليون');
    expect(CoachGuide.leona.displayName(ar), 'ليونا');
    expect(CoachGuide.leona.displayName(fr), 'Leona');
    expect(CoachGuide.leona.name, 'leona');
  });
}
