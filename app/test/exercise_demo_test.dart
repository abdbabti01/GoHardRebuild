import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/widgets.dart' show push;
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/coach/exercise_demo.dart';
import 'package:gohard_rebuild/features/coach/exercise_media.dart';
import 'package:gohard_rebuild/features/coach/guide.dart';
import 'package:gohard_rebuild/features/coach/guide_sheets.dart';
import 'package:gohard_rebuild/features/workout/workout_flow.dart';
import 'package:gohard_rebuild/features/workout/workout_repository.dart';
import 'package:gohard_rebuild/features/workout/workout_runtime.dart';
import 'package:gohard_rebuild/features/workout/workout_screen.dart';
import 'package:video_player/video_player.dart';

import 'support.dart';
import 'ui_support.dart';

/// Exercise demonstrations (docs/EXERCISE_DEMOS.md). Everything here runs on deterministic fixtures: the bundled
/// manifest, a fake fetch writing local bytes, and a fake player standing in for the native one. These tests cannot
/// show that a real phone decodes a clip, how smooth it is, or whether the movement is taught well; the native journey
/// and a person watching do that.

final _manifestText = File('assets/data/exercise-media.json').readAsStringSync();
final _manifest = ExerciseMediaCatalog.parse(_manifestText);
final _guide = CoachGuideContent.parse(File('assets/data/coach-guide.json').readAsStringSync());
final _catalog = [for (final c in jsonDecode(File('../api/src/GoHard.Api/Data/exercise-catalog.json').readAsStringSync()) as List) CatalogExercise(c as Json)]
  ..sort((a, b) => a.name.compareTo(b.name));

/// A clip of [bytes] made-up bytes, described exactly as a manifest entry would describe it.
({DemoVideo video, List<int> data}) _clip(int bytes, {int seed = 1, String name = 'clip.mov'}) {
  final data = List<int>.generate(bytes, (i) => (i * 31 + seed) & 0xff);
  return (
    video: DemoVideo(
      url: Uri.parse('https://wger.de/media/$name'),
      bytes: bytes,
      sha256: sha256.convert(data).toString(),
      durationSeconds: 10,
      width: 640,
      height: 352,
    ),
    data: data,
  );
}

/// The player boundary: records what the sheet asks of it instead of decoding anything.
class FakePlayer extends VideoPlayerController {
  FakePlayer(this.log, {this.fail = false, this.hang = false}) : super.networkUrl(Uri.parse('https://wger.de/fake.mov'));
  final List<String> log;
  final bool fail, hang;
  bool disposed = false;

  @override
  Future<void> initialize() async {
    log.add('init');
    if (hang) return Completer<void>().future;
    if (fail) throw PlatformException(code: 'VideoError', message: 'decoder');
    value = value.copyWith(isInitialized: true, duration: const Duration(seconds: 10), size: const Size(640, 352));
  }

  @override
  Future<void> play() async {
    log.add('play');
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    log.add('pause');
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> setVolume(double volume) async => log.add('volume $volume');
  @override
  Future<void> setLooping(bool looping) async => log.add('loop $looping');
  @override
  Future<void> setPlaybackSpeed(double speed) async {
    log.add('speed $speed');
    value = value.copyWith(playbackSpeed: speed);
  }

  @override
  Future<void> seekTo(Duration position) async => log.add('seek ${position.inSeconds}');

  @override
  Future<void> dispose() async {
    log.add('dispose');
    disposed = true;
    await super.dispose();
  }
}

/// Overrides for the sheet: the bundled manifest and guide, a store in [dir], and players made by [make].
List<Override> _demoOverrides(Directory dir, FakePlayer Function(DemoVideo, File?) make, {DemoFetch? fetch, ExerciseMediaCatalog? media}) => [
  exerciseMediaProvider.overrideWith((ref) async => media ?? _manifest),
  coachGuideProvider.overrideWith((ref) async => _guide),
  demoStoreProvider.overrideWith(
    (ref) =>
        DemoStore(directory: () async => dir, fetch: fetch ?? (url, into, {required maxBytes}) async => throw const DemoDownloadError(DemoFailure.network)),
  ),
  demoPlayerFactoryProvider.overrideWithValue(make),
];

/// Lets the store's real file work finish (it runs outside the test's fake time) and the frames settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 150));
  }
}

class _Host extends StatelessWidget {
  const _Host(this.open);
  final void Function(BuildContext) open;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(key: const Key('open'), onPressed: () => open(context), child: const Text('Open')),
    ),
  );
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('demo_test'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a handle for a moment; the temp folder is cleaned later.
    }
  });

  group('manifest', () {
    test('the bundled manifest is whole: every entry valid, keyed by real catalogue keys, clips HTTPS on wger.de within 20 MiB', () {
      final keys = {for (final c in _catalog) c.key};
      expect(_manifest.rejected, isEmpty);
      expect(_manifest.media.values.where((m) => m.isVideo).map((m) => m.catalogKey).toSet(), {
        'bench-press',
        'incline-dumbbell-press',
        'dumbbell-bench-press',
        'overhead-triceps-extension',
        'dip',
      });
      expect(_manifest.media.values.where((m) => !m.isVideo).length, 7);
      for (final m in _manifest.media.values) {
        expect(keys, contains(m.catalogKey));
        expect(File(m.poster).existsSync(), isTrue, reason: m.poster);
        expect(m.credit.attribution, contains(m.credit.licence));
        if (m.video case final v?) {
          expect((v.url.scheme, v.url.host), ('https', 'wger.de'));
          expect(v.bytes, lessThanOrEqualTo(maxClipBytes));
        }
      }
      for (final t in _manifest.technique.entries) {
        expect(keys, contains(t.key));
        expect(t.value.sources, isNotEmpty);
      }
    });

    test('lookup is by exact catalogue key only: no custom exercise, near name or muscle group gets a clip', () {
      expect(_manifest.forKey('bench-press')!.video!.url.path, contains('/73/'));
      expect(_manifest.forKey(null), isNull);
      expect(_manifest.forKey('custom:bench-press'), isNull, reason: 'a custom key never resolves, even one that looks like a catalogue key');
      expect(_manifest.forKey('Bench press'), isNull, reason: 'a name is not a key');
      expect(_manifest.forKey('bench'), isNull);
      expect(_manifest.forKey('leg-curl'), isNull, reason: 'deliberately unmapped: the entry is generic');
      expect(_manifest.techniqueFor('custom:x'), isNull);
    });

    test('a malformed, unapproved or unsafe entry is left out and the rest still load', () {
      final good = (jsonDecode(_manifestText) as Json)['media'] as List;
      final video = Map<String, dynamic>.from(good.firstWhere((m) => m['catalogKey'] == 'bench-press') as Map);
      Json bad(String key, Json Function(Json v) change) => change({...jsonDecode(jsonEncode(video)) as Json, 'catalogKey': key});
      final doc = {
        ...jsonDecode(_manifestText) as Json,
        'media': [
          video,
          bad('a', (v) => v..['video']['url'] = 'http://wger.de/x.mov'),
          bad('b', (v) => v..['video']['url'] = 'https://example.com/x.mov'),
          bad('c', (v) => v..['video']['bytes'] = maxClipBytes + 1),
          bad('d', (v) => v..['status'] = 'candidate'),
          bad('e', (v) => v..['credit'] = {'creator': 'X'}),
          bad('custom:f', (v) => v),
          bad('g', (v) => v..['video']['sha256'] = 'not-a-hash'),
          bad('h', (v) => v..['poster'] = 'https://wger.de/poster.jpg'),
          bad('i', (v) => v..['kind'] = 'gif'),
          video,
          'not an object',
        ],
      };
      final m = ExerciseMediaCatalog.parse(jsonEncode(doc));
      expect(m.media.keys, ['bench-press']);
      expect(m.rejected, hasLength(12 - 1));
    });
  });

  group('downloads', () {
    test('a download is checked, published whole and found again by a new store (a restart) without the network', () async {
      final c = _clip(4096);
      var fetches = 0;
      final store = DemoStore(
        directory: () async => tmp,
        fetch: (url, into, {required maxBytes}) async {
          fetches++;
          await into.writeAsBytes(c.data);
        },
      );
      expect(await store.fileFor(c.video), isNull);
      await Future.wait([store.download(c.video), store.download(c.video), store.download(c.video)]);
      expect(fetches, 1, reason: 'three requests, one download');
      expect(store.state(c.video), DemoSaved.downloaded);
      expect(tmp.listSync().map((f) => f.uri.pathSegments.last), isNot(contains(endsWith('.part'))));

      final offline = DemoStore(directory: () async => tmp, fetch: (url, into, {required maxBytes}) async => fail('offline: nothing may be fetched'));
      await offline.ready();
      expect(offline.state(c.video), DemoSaved.downloaded);
      final f = await offline.fileFor(c.video);
      expect(await f!.readAsBytes(), c.data);
    });

    test('wrong bytes, too many bytes, no network and no space each leave nothing behind and can be retried', () async {
      final c = _clip(2048);
      var mode = 'wrong';
      final store = DemoStore(
        directory: () async => tmp,
        fetch: (url, into, {required maxBytes}) async {
          switch (mode) {
            case 'wrong':
              await into.writeAsBytes(List.filled(2048, 7));
            case 'long':
              await into.writeAsBytes([...c.data, 1, 2, 3]);
            case 'network':
              await into.writeAsBytes(c.data.take(100).toList());
              throw const DemoDownloadError(DemoFailure.network);
            case 'space':
              throw const FileSystemException('No space left on device', '', OSError('ENOSPC', 28));
            default:
              await into.writeAsBytes(c.data);
          }
        },
      );
      for (final (m, failure) in [
        ('wrong', DemoFailure.invalid),
        ('long', DemoFailure.invalid),
        ('network', DemoFailure.network),
        ('space', DemoFailure.storage),
      ]) {
        mode = m;
        await expectLater(store.download(c.video), throwsA(isA<DemoDownloadError>().having((e) => e.failure, 'failure', failure)), reason: m);
        expect(store.state(c.video), DemoSaved.failed, reason: m);
        expect(tmp.listSync().whereType<File>().where((f) => !f.path.endsWith('index.json')), isEmpty, reason: '$m: partial file removed');
      }
      mode = 'ok';
      await store.download(c.video);
      expect(store.state(c.video), DemoSaved.downloaded, reason: 'Retry works after failures');
    });

    test('a clip over 20 MiB is refused before anything is fetched', () async {
      final big = DemoVideo(url: Uri.parse('https://wger.de/big.mov'), bytes: maxClipBytes + 1, sha256: 'a' * 64, durationSeconds: 1, width: 1, height: 1);
      final store = DemoStore(directory: () async => tmp, fetch: (url, into, {required maxBytes}) async => fail('must not fetch'));
      await expectLater(store.download(big), throwsA(isA<DemoDownloadError>()));
    });

    test('a saved copy that changed on disk is forgotten, not trusted', () async {
      final c = _clip(1000);
      final store = DemoStore(directory: () async => tmp, fetch: (url, into, {required maxBytes}) async => into.writeAsBytes(c.data));
      await store.download(c.video);
      final f = (await store.fileFor(c.video))!;
      await f.writeAsBytes(c.data.take(10).toList());
      expect(await store.fileFor(c.video), isNull);
      expect(store.state(c.video), DemoSaved.none);
      expect(f.existsSync(), isFalse);
    });

    test('the store stays within its limit, least recently used out first, never the clip that is playing', () async {
      final a = _clip(400, seed: 1, name: 'a.mov'), b = _clip(400, seed: 2, name: 'b.mov'), c = _clip(400, seed: 3, name: 'c.mov');
      final data = {a.video.sha256: a.data, b.video.sha256: b.data, c.video.sha256: c.data};
      var t = DateTime.utc(2026, 10, 18);
      final store = DemoStore(
        directory: () async => tmp,
        capacity: 1000,
        now: () => t = t.add(const Duration(minutes: 1)),
        fetch: (url, into, {required maxBytes}) async => into.writeAsBytes(data[[a, b, c].firstWhere((x) => x.video.url == url).video.sha256]!),
      );
      await store.download(a.video);
      await store.download(b.video);
      store.hold(a.video); // a is the oldest, but playing
      await store.download(c.video);
      expect((store.state(a.video), store.state(b.video), store.state(c.video)), (DemoSaved.downloaded, DemoSaved.none, DemoSaved.downloaded));
      expect(store.usedBytes, 800);
      store.release(a.video);
      await store.remove(c.video);
      expect(store.state(c.video), DemoSaved.none);
    });
  });

  group('player and sheet', () {
    testWidgets(
      'nothing loads until Play; Play is muted and repeating; speed and replay; covering, backgrounding and closing pause or end it; reopening starts one new session',
      (tester) async {
        final log = <String>[];
        final players = <FakePlayer>[];
        await pumpApp(tester, [
          ...(await tester.runAsync(() => overridesFor(day: '2026-10-18')))!,
          ..._demoOverrides(tmp, (v, saved) => FakePlayer(log)..let(players.add)),
        ], home: _Host((c) => showExerciseDetails(c, exercise: (catalogKey: 'bench-press', name: 'Bench press', isTimed: false))));
        await tester.tap(find.byKey(const Key('open')));
        await _settle(tester);
        expect(find.byKey(const Key('demo-play')), findsOneWidget);
        expect(players, isEmpty, reason: 'opening the sheet decodes nothing');
        expect(tester.getSize(find.descendant(of: find.byKey(const Key('demo-player')), matching: find.byType(Image))).width, greaterThan(300),
            reason: 'the poster fills the media area, not the size of the Play button');
        expect(find.text('How to do it'), findsOneWidget);
        expect(find.text('Setup'), findsOneWidget);
        expect(find.byKey(const Key('exercise-demo-credit')), findsOneWidget);
        expect(find.textContaining('Video by Goulart, via wger.de, CC BY-SA 4.0'), findsOneWidget);
        expect(find.byKey(const Key('exercise-technique-sources')), findsOneWidget, reason: 'technique sources apart from the media credit');
        expect(find.text('Streams when you press Play · 1.4 MB'), findsOneWidget);

        await tester.tap(find.byKey(const Key('demo-play')));
        await _settle(tester);
        expect(players, hasLength(1));
        expect(log, ['init', 'volume 0.0', 'loop true', 'speed 1.0', 'play']);
        await tester.ensureVisible(find.byKey(const Key('demo-speed-0.5')));
        await tester.tap(find.byKey(const Key('demo-speed-0.5')));
        await tester.tap(find.byKey(const Key('demo-replay')));
        await _settle(tester);
        expect(log.sublist(5), ['speed 0.5', 'seek 0', 'play']);

        // Full screen: the same player, no second one; back to the sheet still playing.
        await tester.tap(find.byKey(const Key('demo-fullscreen')));
        await _settle(tester);
        expect(find.byKey(const Key('demo-fullscreen-page')), findsOneWidget);
        expect(players, hasLength(1));
        expect(players.single.value.isPlaying, isTrue, reason: 'full screen does not pause it');
        await tester.tap(find.byKey(const Key('demo-exit-fullscreen')));
        await _settle(tester);
        expect(find.byKey(const Key('demo-fullscreen-page')), findsNothing);
        expect(players.single.value.isPlaying, isTrue);

        // The app goes to the background: paused.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(players.single.value.isPlaying, isFalse);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.tap(find.byKey(const Key('demo-toggle')));
        await _settle(tester);
        expect(players.single.value.isPlaying, isTrue, reason: 'only the user starts it again');

        // Covered by another page: paused.
        Navigator.of(tester.element(find.byKey(const Key('exercise-info-sheet'))))
            .push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Over'))));
        await _settle(tester);
        expect(players.single.value.isPlaying, isFalse);
        Navigator.of(tester.element(find.text('Over'))).pop();
        await _settle(tester);

        // Closed: disposed. Reopened: one new session, the old one is never touched again.
        Navigator.of(tester.element(find.byKey(const Key('exercise-info-sheet')))).pop();
        await _settle(tester);
        expect(players.single.disposed, isTrue);
        await tester.tap(find.byKey(const Key('open')));
        await _settle(tester);
        await tester.tap(find.byKey(const Key('demo-play')));
        await _settle(tester);
        expect(players, hasLength(2));
        expect(players.where((p) => !p.disposed), hasLength(1));
      },
    );

    testWidgets('a failing clip says "Demonstration unavailable" with Retry and keeps the guide; a clip that never starts fails in finite time', (
      tester,
    ) async {
      final log = <String>[];
      var attempt = 0;
      await pumpApp(tester, [
        ...(await tester.runAsync(() => overridesFor(day: '2026-10-18')))!,
        ..._demoOverrides(tmp, (v, saved) => FakePlayer(log, fail: attempt == 0, hang: attempt == 1)),
      ], home: _Host((c) => showExerciseDetails(c, exercise: (catalogKey: 'dip', name: 'Dip', isTimed: false))));
      await tester.tap(find.byKey(const Key('open')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('demo-play')));
      await _settle(tester);
      expect(find.byKey(const Key('demo-unavailable')), findsOneWidget);
      expect(find.text('Demonstration unavailable'), findsOneWidget);
      expect(find.text('Technique'), findsOneWidget, reason: 'the written guide is still there');

      attempt = 1;
      await tester.tap(find.byKey(const Key('demo-retry')));
      await tester.pump();
      expect(find.text('Loading demonstration…'), findsOneWidget);
      await tester.pump(demoStartTimeout + const Duration(seconds: 1));
      await _settle(tester);
      expect(find.byKey(const Key('demo-unavailable')), findsOneWidget, reason: 'no permanent spinner');

      attempt = 2;
      await tester.tap(find.byKey(const Key('demo-retry')));
      await _settle(tester);
      expect(find.byKey(const Key('demo-toggle')), findsOneWidget, reason: 'Retry plays once it works');
    });

    testWidgets('Download saves on this phone, plays from the file and Remove deletes it; nothing about it is written to the account', (tester) async {
      final c = _manifest.forKey('dip')!.video!;
      final data = List<int>.filled(c.bytes, 0);
      // The fixture cannot reproduce the real clip's hash, so this store checks a fixture description of the same size.
      final fixture = DemoVideo(
        url: c.url,
        bytes: c.bytes,
        sha256: sha256.convert(data).toString(),
        durationSeconds: c.durationSeconds,
        width: c.width,
        height: c.height,
      );
      final sources = <File?>[];
      final m = ExerciseMediaCatalog.parse(
        jsonEncode({
          ...jsonDecode(_manifestText) as Json,
          'media': [
            {
              ...(((jsonDecode(_manifestText) as Json)['media'] as List).firstWhere((x) => x['catalogKey'] == 'dip') as Json),
              'video': {'url': fixture.url.toString(), 'bytes': fixture.bytes, 'sha256': fixture.sha256, 'durationSeconds': 10, 'width': 640, 'height': 352},
            },
          ],
        }),
      );
      final overrides = (await tester.runAsync(() => overridesFor(day: '2026-10-18')))!;
      await pumpApp(tester, [
        ...overrides,
        ..._demoOverrides(
          tmp,
          (v, saved) {
            sources.add(saved);
            return FakePlayer([]);
          },
          fetch: (url, into, {required maxBytes}) async => into.writeAsBytes(data),
          media: m,
        ),
      ], home: _Host((c) => showExerciseDetails(c, exercise: (catalogKey: 'dip', name: 'Dip', isTimed: false))));
      await tester.tap(find.byKey(const Key('open')));
      await _settle(tester);
      await tester.ensureVisible(find.byKey(const Key('demo-download')));
      await tester.tap(find.byKey(const Key('demo-download')));
      for (var i = 0; i < 200 && find.textContaining('Downloaded on this phone').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      expect(find.text('Downloaded on this phone · ${(c.bytes / 1000000).toStringAsFixed(1)} MB'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('demo-play')));
      await tester.tap(find.byKey(const Key('demo-play')));
      for (var i = 0; i < 10 && sources.isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await _settle(tester);
      expect(sources.single, isNotNull, reason: 'a downloaded clip plays from its complete local file');
      await tester.ensureVisible(find.byKey(const Key('demo-remove')));
      await tester.tap(find.byKey(const Key('demo-remove')));
      for (var i = 0; i < 200 && find.byKey(const Key('demo-remove')).evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      expect(find.textContaining('Streams when you press Play'), findsOneWidget);
    });

    for (final (key, name, expectFinder) in [
      ('back-squat', 'Back squat', find.text('No demonstration for this exercise yet.')),
      ('lateral-raise', 'Lateral raise', find.byKey(const Key('demo-still'))),
      ('custom:abc', 'Bench press', find.textContaining('Added by you')),
    ]) {
      testWidgets('$key: no media says so plainly; a still says it is an illustration; a custom exercise gets neither', (tester) async {
        await pumpApp(tester, [
          ...(await tester.runAsync(() => overridesFor(day: '2026-10-18')))!,
          ..._demoOverrides(tmp, (v, saved) => fail('no player for $key')),
        ], home: _Host((c) => showExerciseDetails(c, exercise: (catalogKey: key, name: name, isTimed: false))));
        await tester.tap(find.byKey(const Key('open')));
        await _settle(tester);
        expect(expectFinder, findsOneWidget, reason: key);
        if (key.startsWith('custom:')) {
          expect(find.byKey(const Key('demo-player')), findsNothing, reason: 'a custom "Bench press" is not the catalogue bench press');
          expect(find.byKey(const Key('demo-none')), findsNothing);
        }
        expect(find.byKey(const Key('demo-play')), findsNothing, reason: key);
      });
    }
  });

  group('entry points', () {
    testWidgets('the picker: Demo previews without choosing and keeps the search; the row still chooses; a custom exercise has no Demo or thumbnail', (
      tester,
    ) async {
      final custom = CatalogExercise({
        'key': 'custom:mine',
        'name': 'Bench press (mine)',
        'category': 'Chest',
        'equipment': 'Barbell',
        'isTimed': false,
        'isCustom': true,
      });
      final picked = <CatalogExercise?>[];
      await pumpApp(tester, [
        ...(await tester.runAsync(() => overridesFor(day: '2026-10-18')))!,
        ..._demoOverrides(tmp, (v, saved) => FakePlayer([])),
        exerciseChoicesProvider.overrideWithValue([custom, ..._catalog]),
      ], home: _Host((c) async => picked.add(await push<CatalogExercise>(c, const ExercisePicker()))));
      await tester.tap(find.byKey(const Key('open')));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('exercise-search')), 'bench');
      await _settle(tester);
      expect(find.byKey(const Key('exercise-demo-custom:mine')), findsNothing);
      expect(find.byKey(const Key('exercise-about-custom:mine')), findsNothing);
      expect(find.byKey(const Key('exercise-demo-bench-dip')), findsNothing, reason: 'bench dip has no clip: About, not Demo');
      expect(find.byKey(const Key('exercise-about-bench-dip')), findsOneWidget);

      await tester.tap(find.byKey(const Key('exercise-demo-bench-press')));
      await _settle(tester);
      expect(find.byKey(const Key('exercise-info-sheet')), findsOneWidget);
      expect(find.byKey(const Key('exercise-info-replace')), findsNothing, reason: 'previewing offers no edit');
      Navigator.of(tester.element(find.byKey(const Key('exercise-info-sheet')))).pop();
      await _settle(tester);
      expect(picked, isEmpty, reason: 'Demo chose nothing');
      expect(find.byType(ExercisePicker), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('exercise-search'))).controller?.text ?? find.text('bench').evaluate().length, isNot(''));
      expect(find.byKey(const Key('exercise-bench-press')), findsOneWidget, reason: 'the filtered list is as it was');
      expect(find.byKey(const Key('exercise-back-squat')), findsNothing);

      await tester.tap(find.text('Bench press'));
      await _settle(tester);
      expect(picked.single?.key, 'bench-press', reason: 'the row still chooses');
    });

    testWidgets('320 px at twice the text size: the picker and the sheet with a clip, a still and none do not overflow', (tester) async {
      for (final key in ['bench-press', 'lateral-raise', 'back-squat']) {
        await pumpApp(
          tester,
          [
            ...(await tester.runAsync(() => overridesFor(day: '2026-10-18')))!,
            ..._demoOverrides(tmp, (v, saved) => FakePlayer([])),
            exerciseChoicesProvider.overrideWithValue(_catalog),
          ],
          home: _Host((c) => showExerciseDetails(c, exercise: (catalogKey: key, name: key, isTimed: false))),
          size: const Size(320, 640),
          textScale: 2,
        );
        await tester.tap(find.byKey(const Key('open')));
        await _settle(tester);
        if (key == 'bench-press') {
          await tester.tap(find.byKey(const Key('demo-play')));
          await _settle(tester);
        }
        await tester.drag(find.byKey(const Key('exercise-info-sheet')), const Offset(0, -4000));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: key);
      }
      await pumpApp(
        tester,
        [
          ...(await tester.runAsync(() => overridesFor(day: '2026-10-18')))!,
          ..._demoOverrides(tmp, (v, saved) => FakePlayer([])),
          exerciseChoicesProvider.overrideWithValue(_catalog),
        ],
        home: const ExercisePicker(),
        size: const Size(320, 640),
        textScale: 2,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'picker');
    });

    testWidgets('recording: Demo shows the movement actually selected, and closing it leaves the typed weight, the rest timer and the workout as they were', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 10, 12, 15, 0, 30);
      final open = {
        'id': 'w-open',
        'kind': 'manual',
        'title': 'Push',
        'dayKey': '2026-10-12',
        'startedAtUtc': '2026-10-12T15:00:00Z',
        'finishedAtUtc': null,
        'isDeleted': false,
        'exercises': [
          // Replaced during the workout: the planned barbell bench became the dumbbell bench press.
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
        ],
      };
      final overrides = (await tester.runAsync(() => overridesFor(day: '2026-10-12', workouts: [open])))!;
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = _RestingRepo(SyncEngine(db, Api(FakeServer(), SessionManager(MemorySecretStore())), SessionManager(MemorySecretStore())), now);
      final log = <String>[];
      await pumpApp(
        tester,
        [
          ...overrides,
          ..._demoOverrides(tmp, (v, saved) {
            log.add(v.url.toString());
            return FakePlayer([]);
          }),
          workoutRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(FakeClock(now)),
        ],
        home: const WorkoutScreen(workoutId: 'w-open'),
        settle: false,
        size: const Size(390, 2400), // the whole screen built, entry fields included
      );
      await tester.pump();
      await tester.pump();
      final restBefore = tester.widget<Text>(find.byKey(const Key('rest-clock'))).data;
      final loadField = find.descendant(of: find.byKey(const Key('set-load')), matching: find.byType(TextField));
      await tester.enterText(loadField, '62.5');
      await tester.pump();
      final saves = repo.saved.length;

      await tester.tap(find.byKey(const Key('workout-demo')));
      await _settle(tester);
      expect(find.text('Dumbbell bench press'), findsWidgets);
      await tester.tap(find.byKey(const Key('demo-play')));
      await _settle(tester);
      expect(log.single, contains('/75/'), reason: 'the dumbbell bench press clip (wger exercise 75), not the planned barbell bench press');
      Navigator.of(tester.element(find.byKey(const Key('exercise-info-sheet')))).pop();
      await _settle(tester);

      expect(tester.widget<TextField>(loadField).controller!.text, '62.5', reason: 'typed weight kept');
      expect(tester.widget<Text>(find.byKey(const Key('rest-clock'))).data, restBefore, reason: 'the clock is fixed, so the same rest is left');
      expect(find.text('Pause'), findsOneWidget, reason: 'not paused');
      expect(
        {for (final r in repo.saved.skip(saves)) (r.restRemainingSeconds(now), r.isPaused, r.selectedExerciseId)},
        anyOf(isEmpty, {(60, false, null)}),
        reason: 'only the typed draft may be flushed; rest, pause and selection unchanged',
      );
      expect(repo.recorded, 0, reason: 'no set recorded');
      await tester.pumpWidget(const SizedBox());
    });
  });
}

/// A repository with a workout 30 s into a 90 s rest. Saves are recorded; nothing is recorded as a set here.
class _RestingRepo extends WorkoutRepository {
  _RestingRepo(SyncEngine sync, this.now) : super(sync, 'one', FakeClock(now));
  final DateTime now;
  final saved = <WorkoutRuntime>[];
  int recorded = 0;
  @override
  Future<WorkoutRuntime?> runtime(String workoutId) async =>
      WorkoutRuntime.started(DateTime.utc(2026, 10, 12, 15)).withRest(DateTime.utc(2026, 10, 12, 15), 90, 'x1');
  @override
  Future<void> saveRuntime(String workoutId, WorkoutRuntime runtime) async => saved.add(runtime);
  @override
  Future<WorkoutSet> recordSet(Workout workout, String exerciseId, {int? reps, double? loadKg, int? durationSeconds}) {
    recorded++;
    return super.recordSet(workout, exerciseId, reps: reps, loadKg: loadKg, durationSeconds: durationSeconds);
  }
}

extension<T> on T {
  T let(void Function(T) f) {
    f(this);
    return this;
  }
}
