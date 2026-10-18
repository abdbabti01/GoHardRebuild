import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/widgets.dart' show push;
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/coach/exercise_demo.dart';
import 'package:gohard_rebuild/features/coach/exercise_media.dart';
import 'package:gohard_rebuild/features/coach/media_manager.dart';
import 'package:gohard_rebuild/features/me/me_screen.dart';

import 'ui_support.dart';

/// Owner-published exercise videos on the phone (docs/OWNER_EXERCISE_VIDEOS.md): the remote catalogue and its merge over
/// the bundled library, and the owner's manager over a scripted server. No network, storage or player is real here;
/// the real round trip is scripts/media-roundtrip.mjs and the device journey.

final _bundled = ExerciseMediaCatalog.parse(File('assets/data/exercise-media.json').readAsStringSync());
final _catalog = [for (final c in jsonDecode(File('../api/src/GoHard.Api/Data/exercise-catalog.json').readAsStringSync()) as List) CatalogExercise(c as Json)];
const _origin = 'https://media.example.test';
final _sha = sha256.convert(utf8.encode('clip')).toString();

Json _entry(String key, {String? clip, String? poster, String rights = 'original', String? licence, int bytes = 2000000, String id = 'v1'}) => {
      'id': id, 'catalogKey': key, 'clipUrl': clip ?? '$_origin/clips/$key/$_sha.mp4', 'posterUrl': poster ?? '$_origin/posters/$key/$_sha.jpg',
      'bytes': bytes, 'sha256': _sha, 'durationSeconds': 9.5, 'width': 1280, 'height': 720, 'variant': 'Owner variant of $key', 'title': key,
      'creator': 'GoHard', 'rightsKind': rights, 'licenceName': licence, 'licenceUrl': null, 'sourceUrl': null,
      'rightsNotice': 'Original footage, published by GoHard.', 'publishedAtUtc': '2026-10-18T00:00:00Z',
    };
Json _catalogue(List<Json> entries, {int revision = 1}) => {'revision': revision, 'mediaOrigin': _origin, 'entries': entries};

/// A scripted catalogue endpoint and an in-memory cache file.
class FakeSource implements RemoteMediaSource {
  Json? body;
  String etag = '"m1"';
  int fetches = 0;
  final sentEtags = <String?>[];
  bool fail = false;
  String? cache;

  @override
  Future<({Json body, String? etag})?> fetch(String? ifNoneMatch) async {
    fetches++;
    sentEtags.add(ifNoneMatch);
    if (fail) throw const TransportFailure('offline');
    if (ifNoneMatch == etag) return null;
    return (body: body!, etag: etag);
  }

  @override
  Future<String?> readCache() async => cache;
  @override
  Future<void> writeCache(String json) async => cache = json;
}

ProviderContainer _container(FakeSource source, Directory dir, {DateTime Function()? now}) {
  final c = ProviderContainer(overrides: [
    remoteMediaSourceProvider.overrideWithValue(source),
    bundledMediaProvider.overrideWith((ref) async => _bundled),
    demoStoreProvider.overrideWith((ref) => DemoStore(directory: () async => dir)),
    if (now != null) nowProvider.overrideWithValue(now),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('owner_media'));

  group('remote catalogue', () {
    test('entries map by exact key; only HTTPS URLs on the approved origin, real hashes, the clip limit and a real licence are taken', () {
      final r = RemoteMediaCatalog.parse(_catalogue([
        _entry('bench-press'),
        _entry('dip', clip: 'https://evil.example.test/clip.mp4'),
        _entry('pull-up', poster: 'https://media.example.test.evil.test/p.jpg'),
        _entry('plank', clip: 'http://media.example.test/clips/plank.mp4'),
        _entry('custom:abc'),
        _entry('lateral-raise', rights: 'licensed'),
        _entry('back-squat', bytes: maxClipBytes + 1),
        {..._entry('deadlift'), 'sha256': 'nope'},
        _entry('face-pull', rights: 'licensed', licence: 'CC BY-SA 4.0'),
      ]));
      expect(r.entries.keys.toSet(), {'bench-press', 'face-pull'});
      final bench = r.entries['bench-press']!;
      expect((bench.isOwnerVideo, bench.remotePoster, bench.credit.original, bench.credit.licenceUrl), (true, true, true, null));
      expect(r.entries['face-pull']!.credit.attribution, 'Video by GoHard, CC BY-SA 4.0');

      // An origin the server names over plain HTTP is not trusted, except a local development address in a debug build.
      expect(RemoteMediaCatalog.parse({..._catalogue([_entry('bench-press', clip: 'http://media.example.test/c.mp4', poster: 'http://media.example.test/p.jpg')]),
        'mediaOrigin': 'http://media.example.test'}).entries, isEmpty);
      expect(RemoteMediaCatalog.parse({..._catalogue([_entry('bench-press', clip: 'http://10.0.2.2:8333/gohard-public/c.mp4', poster: 'http://10.0.2.2:8333/gohard-public/p.jpg')]),
        'mediaOrigin': 'http://10.0.2.2:8333/gohard-public'}).entries.keys, ['bench-press']);
    });

    test('an owner video replaces the bundled one for its key only; withdrawing it brings the bundled one back', () {
      final merged = _bundled.withRemote(RemoteMediaCatalog.parse(_catalogue([_entry('bench-press'), _entry('face-pull')])));
      expect(merged.forKey('bench-press')!.isOwnerVideo, isTrue);
      expect(merged.forKey('face-pull')!.isOwnerVideo, isTrue, reason: 'a key with no bundled demonstration gains one');
      expect(merged.forKey('dip')!.credit.creator, 'Goulart', reason: 'other keys keep their third-party credit');
      expect(merged.forKey('custom:bench-press'), isNull);
      expect(merged.techniqueFor('bench-press'), isNotNull, reason: 'technique text and its review status are untouched');
      final withdrawn = _bundled.withRemote(RemoteMediaCatalog.parse(_catalogue([])));
      expect(withdrawn.forKey('bench-press')!.isOwnerVideo, isFalse);
      expect(withdrawn.forKey('face-pull'), isNull);
    });

    test('refresh: remembered across a restart, conditional (304), a failure keeps the last good catalogue, at most every five minutes', () async {
      var now = DateTime(2026, 10, 18, 12);
      final source = FakeSource()..body = _catalogue([_entry('bench-press')]);
      final c = _container(source, tmp, now: () => now);
      final media = c.read(remoteMediaProvider.notifier);
      await media.refresh();
      expect(c.read(remoteMediaProvider)!.entries.keys, ['bench-press']);
      expect((await c.read(exerciseMediaProvider.future)).forKey('bench-press')!.isOwnerVideo, isTrue);

      await media.refresh();
      expect(source.fetches, 1, reason: 'no second request within five minutes (not per rebuild, row or frame)');
      now = now.add(const Duration(minutes: 6));
      await media.refresh();
      expect((source.fetches, source.sentEtags.last), (2, '"m1"'), reason: 'conditional: unchanged costs a 304');
      expect(c.read(remoteMediaProvider)!.entries.keys, ['bench-press']);

      source.fail = true;
      await media.refresh(force: true);
      expect(c.read(remoteMediaProvider)!.entries.keys, ['bench-press'], reason: 'a failed refresh never erases the last good catalogue');

      // A restart offline: the persisted catalogue is used.
      final restarted = _container(FakeSource()..fail = true..cache = source.cache, tmp, now: () => now);
      await restarted.read(remoteMediaProvider.notifier).refresh(force: true);
      expect(restarted.read(remoteMediaProvider)!.entries.keys, ['bench-press']);
      expect((await restarted.read(exerciseMediaProvider.future)).forKey('bench-press')!.isOwnerVideo, isTrue);
    });

    test('an older or unconfigured server is never asked; the bundled library works as before', () async {
      final c = ProviderContainer(overrides: [
        remoteMediaSourceProvider.overrideWithValue(null),
        bundledMediaProvider.overrideWith((ref) async => _bundled),
      ]);
      addTearDown(c.dispose);
      await c.read(remoteMediaProvider.notifier).refresh(force: true);
      expect(c.read(remoteMediaProvider), isNull);
      expect((await c.read(exerciseMediaProvider.future)).forKey('bench-press')!.credit.creator, 'Goulart');
    });

    test('withdrawal retires the saved copy on the next refresh, but never a clip that is playing', () async {
      final data = utf8.encode('clip');
      final source = FakeSource()..body = _catalogue([_entry('bench-press', bytes: data.length)]);
      final store = DemoStore(directory: () async => tmp, fetch: (url, into, {required maxBytes}) async => into.writeAsBytes(data));
      final c = ProviderContainer(overrides: [
        remoteMediaSourceProvider.overrideWithValue(source),
        bundledMediaProvider.overrideWith((ref) async => _bundled),
        demoStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(c.dispose);
      await c.read(bundledMediaProvider.future);
      await c.read(remoteMediaProvider.notifier).refresh();
      final video = (await c.read(exerciseMediaProvider.future)).forKey('bench-press')!.video!;
      await store.download(video);
      final reopened = store;
      expect(reopened.state(video), DemoSaved.downloaded);
      reopened.hold(video); // playing
      source
        ..body = _catalogue([], revision: 2)
        ..etag = '"m2"';
      await c.read(remoteMediaProvider.notifier).refresh(force: true);
      expect(reopened.state(video), DemoSaved.downloaded, reason: 'playback is not interrupted');
      reopened.release(video);
      source
        ..body = _catalogue([], revision: 3)
        ..etag = '"m3"';
      await c.read(remoteMediaProvider.notifier).refresh(force: true);
      expect(reopened.state(video), DemoSaved.none);
      expect(store.state(_bundled.forKey('dip')!.video!), DemoSaved.none, reason: 'bundled clips are not affected');
    });
  });

  testWidgets('a remote poster that cannot load shows a plain panel, not an error', (tester) async {
    final m = RemoteMediaCatalog.parse(_catalogue([_entry('bench-press')])).entries['bench-press']!;
    await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: '2026-10-18')))!,
        home: Scaffold(body: Center(child: SizedBox(width: 200, height: 120, child: DemoPoster(m)))));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget, reason: 'the static fallback');
  });

  group('owner manager', () {
    testWidgets('Me shows Manage exercise videos only to the account the server says may manage', (tester) async {
      for (final canManage in [false, true]) {
        await pumpApp(tester, [
          ...(await tester.runAsync(() => overridesFor(day: '2026-10-18')))!,
          mediaAccessProvider.overrideWith((ref) async => MediaAccess(canManage: canManage, ready: true)),
        ], home: const MeScreen());
        await tester.pumpAndSettle();
        await tester.dragUntilVisible(find.text('Delete account'), find.byType(Scrollable).first, const Offset(0, -300));
        expect(find.byKey(const Key('me-manage-videos')), canManage ? findsOneWidget : findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('pick → details and rights → upload with progress → processing → preview → explicit Publish to everyone', (tester) async {
      final server = _ManageServer();
      final picked = File('${tmp.path}/clip.mov')..writeAsBytesSync(List.filled(4096, 1));
      final uploads = <String>[];
      var forced = 0;
      await pumpApp(tester, [
        ...(await tester.runAsync(() => overridesFor(day: '2026-10-18')))!,
        transportProvider.overrideWithValue(server),
        mediaAccessProvider.overrideWith((ref) async => const MediaAccess(canManage: true, ready: true)),
        exerciseChoicesProvider.overrideWithValue([for (final c in _catalog) c]),
        bundledMediaProvider.overrideWith((ref) async => _bundled),
        videoPickerProvider.overrideWithValue(() async => picked),
        videoDurationProvider.overrideWithValue((_) async => const Duration(seconds: 9)),
        mediaUploaderProvider.overrideWithValue((url, headers, file, bytes, {required onProgress, required cancel}) async {
          expect(headers.keys, ['Content-Type'], reason: 'storage gets the declared type, never a GoHard token');
          uploads.add(url);
          onProgress(bytes ~/ 2);
          onProgress(bytes);
          server.uploaded = true;
        }),
        remoteMediaSourceProvider.overrideWithValue(FakeSource()..body = _catalogue([])..fail = false),
        remoteMediaProvider.overrideWith(() => _CountingRemote(() => forced++)),
      ], home: Builder(builder: (context) => Scaffold(body: TextButton(onPressed: () => push(context, const ManageExerciseVideoScreen(catalogKey: 'bench-press')), child: const Text('Open')))), size: const Size(390, 2600));
      await tester.tap(find.text('Open'));
      await _settle(tester);
      expect(find.textContaining('The bundled demonstration'), findsOneWidget, reason: 'what everyone sees now, apart from the draft');

      await tester.tap(find.byKey(const Key('video-pick')));
      await _settle(tester);
      await tester.ensureVisible(find.byKey(const Key('video-start-upload')));
      await tester.tap(find.byKey(const Key('video-start-upload')));
      await _settle(tester);
      expect(find.textContaining('Say what the video shows'), findsOneWidget, reason: 'nothing uploads without the details');
      expect(uploads, isEmpty);
      await tester.enterText(find.byKey(const Key('video-variant')), 'Barbell on a flat bench, side view');
      await tester.ensureVisible(find.byKey(const Key('video-rights')));
      await tester.tap(find.byKey(const Key('video-rights')));
      await _settle(tester);
      await tester.ensureVisible(find.byKey(const Key('video-start-upload')));
      await tester.tap(find.byKey(const Key('video-start-upload')));
      await _settle(tester);
      expect(uploads.single, startsWith('https://storage.test/'));
      expect(server.created!['catalogKey'], 'bench-press');
      expect(server.details!['rightsConfirmed'], isTrue);
      expect(find.byKey(const Key('video-processing')), findsOneWidget);

      server.status = 'ready';
      await tester.pump(const Duration(seconds: 4));
      await _settle(tester);
      expect(find.byKey(const Key('video-ready')), findsOneWidget);
      expect(find.byKey(const Key('video-preview')), findsOneWidget, reason: 'the processed result in the existing player');
      expect(find.byKey(const Key('demo-download')), findsNothing, reason: 'a private preview is never saved on the phone');
      expect(server.published, isFalse, reason: 'nothing is published by itself');

      await tester.ensureVisible(find.byKey(const Key('video-publish')));
      await tester.tap(find.byKey(const Key('video-publish')));
      await _settle(tester);
      expect(find.textContaining('available to everyone using GoHard'), findsWidgets);
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(FilledButton, 'Publish')));
      await _settle(tester);
      expect(server.published, isTrue);
      expect(forced, 1, reason: 'the owner sees it at once');
    });
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

class _CountingRemote extends RemoteMedia {
  _CountingRemote(this.onForced);
  final void Function() onForced;
  @override
  Future<void> refresh({bool force = false}) async {
    if (force) onForced();
  }
}

/// The manage API as the server answers it, for one draft.
class _ManageServer implements Transport {
  Json? created, details;
  String status = 'awaiting_upload';
  bool uploaded = false, published = false;
  int revision = 1;

  Json get _draft => {
        'id': 'd1', 'catalogKey': 'bench-press', 'status': status, 'variant': details?['variant'] ?? '', 'title': 'Bench press', 'creator': 'GoHard',
        'rightsKind': 'original', 'rightsNotice': '', 'rightsConfirmed': details?['rightsConfirmed'] ?? false, 'declaredBytes': 4096,
        'bytes': status == 'ready' || published ? 1234 : null, 'durationSeconds': 9.5, 'width': 1280, 'height': 720, 'revision': revision,
      };
  ApiResponse _ack(Json? data) => ApiResponse(200, {'operationId': 'op', 'status': 'accepted', 'revision': revision, 'data': data});

  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer, Map<String, String>? headers}) async {
    final body = data as Json?;
    switch (path) {
      case '/exercise-media/manage':
        return ApiResponse(200, {'drafts': [if (created != null) _draft], 'active': [if (published) _entry('bench-press')]});
      case '/exercise-media/manage/drafts':
        created = body;
        return _ack(_draft);
      case '/exercise-media/manage/drafts/d1/details':
        details = body;
        revision++;
        return _ack(_draft);
      case '/exercise-media/manage/drafts/d1/upload-url':
        return ApiResponse(200, {'url': 'https://storage.test/staging/originals/x?sig', 'method': 'PUT', 'headers': {'Content-Type': 'video/quicktime'}});
      case '/exercise-media/manage/drafts/d1/complete':
        if (!uploaded) return const ApiResponse(422, {'operationId': 'op', 'status': 'rejected', 'revision': 0, 'code': 'UPLOAD_MISSING'});
        status = 'queued';
        return _ack(_draft);
      case '/exercise-media/manage/drafts/d1/preview':
        return const ApiResponse(200, {'clipUrl': 'https://storage.test/p.mp4?sig', 'posterUrl': 'https://storage.test/p.jpg?sig'});
      case '/exercise-media/manage/drafts/d1/publish':
        published = true;
        status = 'published';
        return _ack(_entry('bench-press'));
    }
    return const ApiResponse(404, null);
  }
}

