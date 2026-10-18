import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart' show apiProvider, ownerProvider;
import '../../core/compatibility.dart';
import '../../data/models.dart';
import '../../data/session.dart';

/// Exercise demonstrations (docs/EXERCISE_DEMOS.md): the reviewed, bundled manifest (assets/data/exercise-media.json,
/// built by scripts/build-exercise-demos.mjs) and the phone's own store of downloaded clips. Public educational media
/// only: nothing here is part of a plan, a workout or the account, nothing syncs, and no request carries GoHard's
/// credentials or anything about the user.

const maxClipBytes = 20 * 1024 * 1024;
const demoCacheBytes = 100 * 1024 * 1024;

/// Who made a demonstration and on what terms. Footage the owner made is [original]: it has a rights notice and no
/// outside licence; someone else's keeps its creator, licence and source.
@immutable
class DemoCredit {
  const DemoCredit({required this.creator, required this.attribution, this.licence, this.licenceUrl, this.original = false, this.notice});
  final String creator, attribution;
  final String? licence, licenceUrl, notice;
  final bool original;
}

@immutable
class DemoVideo {
  const DemoVideo({required this.url, required this.bytes, required this.sha256, required this.durationSeconds, required this.width, required this.height});
  final Uri url;
  final int bytes;
  final String sha256;
  final double durationSeconds;
  final int width, height;
  double get aspectRatio => width / height;

  /// The saved copy's file name: its content hash, so two keys never share a file by accident and a stale copy is never trusted.
  String get fileName => '$sha256${p.extension(url.path).toLowerCase()}';
}

/// One reviewed demonstration for one catalogue key: a clip (with a poster) or a still (the poster itself). The poster
/// is a bundled asset, or for an owner-published video an HTTPS URL on the approved media origin ([remotePoster]).
@immutable
class ExerciseMedia {
  const ExerciseMedia({required this.catalogKey, required this.poster, required this.variant, required this.credit, required this.changes,
      required this.providerName, this.sourcePage, this.video, this.versionId, this.allowDownload = true});
  final String catalogKey, poster, variant, changes, providerName;
  final String? sourcePage;
  final DemoCredit credit;
  final DemoVideo? video;

  /// The published version this came from (owner videos only).
  final String? versionId;

  /// False for a private preview: it is never saved on the phone.
  final bool allowDownload;
  bool get isVideo => video != null;
  bool get remotePoster => !poster.startsWith('assets/');
  bool get isOwnerVideo => versionId != null;
}

@immutable
class TechniqueSource {
  const TechniqueSource({required this.title, required this.publisher, required this.url, required this.checked});
  final String title, publisher, url, checked;
}

/// Setup, Movement and Common mistakes written from one exercise-specific source.
@immutable
class TechniqueGuide {
  const TechniqueGuide({required this.setup, required this.movement, required this.mistakes, required this.sources});
  final List<String> setup, movement, mistakes;
  final List<TechniqueSource> sources;
}

/// The bundled manifest, after validation. An entry that breaks a rule is left out (and listed in [rejected]) rather
/// than shown: a wrong or unsafe clip is worse than none.
class ExerciseMediaCatalog {
  ExerciseMediaCatalog._(this.version, this.media, this.technique, this.techniqueReviewNote, this.rejected);

  factory ExerciseMediaCatalog.parse(String text) {
    final j = jsonDecode(text) as Json;
    final hosts = {for (final h in j['allowedHosts'] as List? ?? const []) h as String};
    final media = <String, ExerciseMedia>{}, rejected = <String>[];
    for (final raw in j['media'] as List? ?? const []) {
      final e = raw is Json ? raw : const <String, dynamic>{};
      final key = e['catalogKey'];
      try {
        final m = _entry(e, hosts);
        if (media.containsKey(m.catalogKey)) throw const FormatException('listed twice');
        media[m.catalogKey] = m;
      } on Object catch (error) {
        rejected.add('$key: ${error is FormatException ? error.message : error}');
      }
    }
    final sources = {
      for (final s in j['techniqueSources'] as List? ?? const [])
        (s as Json)['id'] as String: TechniqueSource(title: s['title'] as String, publisher: s['publisher'] as String, url: s['url'] as String, checked: s['checked'] as String),
    };
    final technique = <String, TechniqueGuide>{};
    for (final t in j['technique'] as List? ?? const []) {
      final e = t as Json;
      final used = [for (final id in e['sources'] as List) ?sources[id]];
      // Technique text with no resolvable source is not shown as sourced.
      if (used.isEmpty) {
        rejected.add('${e['catalogKey']}: technique without a known source');
        continue;
      }
      List<String> lines(String k) => (e[k] as List? ?? const []).cast<String>();
      technique[e['catalogKey'] as String] = TechniqueGuide(setup: lines('setup'), movement: lines('movement'), mistakes: lines('mistakes'), sources: used);
    }
    if (rejected.isNotEmpty) debugPrint('exercise-media.json: left out ${rejected.join('; ')}');
    return ExerciseMediaCatalog._(j['version'] as int, media, technique, j['techniqueReviewNote'] as String? ?? '', rejected);
  }

  static ExerciseMedia _entry(Json e, Set<String> hosts) {
    String need(Json j, String k) {
      final v = j[k];
      if (v is! String || v.trim().isEmpty) throw FormatException('missing $k');
      return v;
    }

    final key = need(e, 'catalogKey');
    if (key.startsWith('custom:')) throw const FormatException('custom exercises never get public media');
    if (e['status'] != 'approved') throw const FormatException('not approved');
    final poster = need(e, 'poster');
    if (!poster.startsWith('assets/demos/')) throw const FormatException('poster must be bundled');
    final credit = e['credit'] is Json ? e['credit'] as Json : throw const FormatException('missing credit');
    final licenceUrl = Uri.tryParse(need(credit, 'licenceUrl'));
    if (licenceUrl == null || licenceUrl.scheme != 'https') throw const FormatException('licence link must be HTTPS');
    final provider = e['provider'] is Json ? e['provider'] as Json : throw const FormatException('missing provider');
    DemoVideo? video;
    switch (e['kind']) {
      case 'video':
        final v = e['video'] is Json ? e['video'] as Json : throw const FormatException('missing video');
        final url = Uri.tryParse(need(v, 'url'));
        if (url == null || url.scheme != 'https' || !hosts.contains(url.host)) throw const FormatException('clip must be HTTPS on a reviewed host');
        final bytes = v['bytes'];
        if (bytes is! int || bytes <= 0 || bytes > maxClipBytes) throw const FormatException('clip size missing or over 20 MiB');
        final sha = need(v, 'sha256');
        if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) throw const FormatException('bad sha256');
        final w = v['width'], h = v['height'];
        if (w is! int || h is! int || w <= 0 || h <= 0) throw const FormatException('bad dimensions');
        video = DemoVideo(url: url, bytes: bytes, sha256: sha, durationSeconds: (v['durationSeconds'] as num).toDouble(), width: w, height: h);
      case 'still':
        break;
      default:
        throw const FormatException('unknown kind');
    }
    return ExerciseMedia(
      catalogKey: key, poster: poster, variant: need(e, 'variant'), changes: need(e, 'changes'), video: video,
      sourcePage: need(provider, 'page'), providerName: need(provider, 'name'),
      credit: DemoCredit(creator: need(credit, 'creator'), licence: need(credit, 'licence'), licenceUrl: licenceUrl.toString(), attribution: need(credit, 'attribution')),
    );
  }

  ExerciseMediaCatalog._merged(ExerciseMediaCatalog base, Map<String, ExerciseMedia> remote)
      : version = base.version,
        media = {...base.media, ...remote},
        technique = base.technique,
        techniqueReviewNote = base.techniqueReviewNote,
        rejected = base.rejected;

  /// This catalogue with the owner's published videos over it, key by key. A key the owner has not published (or has
  /// withdrawn) keeps its bundled demonstration; nothing is matched by name.
  ExerciseMediaCatalog withRemote(RemoteMediaCatalog? remote) =>
      remote == null || remote.entries.isEmpty ? this : ExerciseMediaCatalog._merged(this, remote.entries);

  final int version;
  final Map<String, ExerciseMedia> media;
  final Map<String, TechniqueGuide> technique;
  final String techniqueReviewNote;
  final List<String> rejected;

  /// The demonstration for exactly this catalogue key. A custom exercise (or none) never has one, whatever its name.
  ExerciseMedia? forKey(String? catalogKey) => catalogKey == null || catalogKey.startsWith('custom:') ? null : media[catalogKey];
  TechniqueGuide? techniqueFor(String? catalogKey) => catalogKey == null || catalogKey.startsWith('custom:') ? null : technique[catalogKey];
}

final bundledMediaProvider = FutureProvider<ExerciseMediaCatalog>((ref) async => ExerciseMediaCatalog.parse(await rootBundle.loadString('assets/data/exercise-media.json')));

/// What the app shows: the bundled library with the owner's published videos over it (docs/OWNER_EXERCISE_VIDEOS.md).
final exerciseMediaProvider = FutureProvider<ExerciseMediaCatalog>((ref) async {
  final remote = ref.watch(remoteMediaProvider);
  return (await ref.watch(bundledMediaProvider.future)).withRemote(remote);
});

// ------------------------------------------------------------------ owner-published videos from the API

/// The API's published demonstrations, after validation: every URL must be on the media origin the server names, over
/// HTTPS (plain HTTP only for a local development origin in a debug build), within the clip limit, with a real hash.
class RemoteMediaCatalog {
  const RemoteMediaCatalog({required this.revision, required this.origin, required this.entries});
  final int revision;
  final String origin;
  final Map<String, ExerciseMedia> entries;

  static bool _localDev(Uri u) => kDebugMode && u.scheme == 'http' && const {'10.0.2.2', 'localhost', '127.0.0.1'}.contains(u.host);

  static RemoteMediaCatalog parse(Json j) {
    final origin = Uri.tryParse(j['mediaOrigin'] as String? ?? '');
    final entries = <String, ExerciseMedia>{};
    final trusted = origin != null && origin.host.isNotEmpty && (origin.scheme == 'https' || _localDev(origin));
    for (final raw in j['entries'] as List? ?? const []) {
      try {
        final e = raw as Json;
        Uri onOrigin(String k) {
          final u = Uri.parse(e[k] as String);
          if (!trusted || u.scheme != origin.scheme || u.host != origin.host || u.port != origin.port || !u.path.startsWith(origin.path)) {
            throw const FormatException('not on the approved media origin');
          }
          return u;
        }

        final key = e['catalogKey'] as String;
        final bytes = e['bytes'] as int, sha = e['sha256'] as String;
        if (key.startsWith('custom:') || bytes <= 0 || bytes > maxClipBytes || !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) throw const FormatException('invalid');
        final original = e['rightsKind'] == 'original';
        final creator = e['creator'] as String, licence = e['licenceName'] as String?;
        if (!original && (licence == null || licence.isEmpty)) throw const FormatException('licensed footage without its licence');
        entries[key] = ExerciseMedia(
          catalogKey: key, poster: onOrigin('posterUrl').toString(), variant: e['variant'] as String, providerName: 'GoHard',
          versionId: e['id'] as String, sourcePage: e['sourceUrl'] as String?,
          changes: e['rightsNotice'] as String? ?? '',
          video: DemoVideo(url: onOrigin('clipUrl'), bytes: bytes, sha256: sha, durationSeconds: (e['durationSeconds'] as num).toDouble(),
              width: e['width'] as int, height: e['height'] as int),
          credit: DemoCredit(
            creator: creator, original: original, licence: licence, licenceUrl: e['licenceUrl'] as String?, notice: e['rightsNotice'] as String?,
            attribution: original ? 'Original footage by $creator' : 'Video by $creator, $licence',
          ),
        );
      } on Object catch (error) {
        debugPrint('exercise media catalogue: left out an entry ($error)');
      }
    }
    return RemoteMediaCatalog(revision: j['revision'] as int? ?? 0, origin: origin?.toString() ?? '', entries: entries);
  }
}

/// How the remote catalogue is fetched and remembered; replaced in tests.
abstract interface class RemoteMediaSource {
  /// GET /exercise-media/catalog with If-None-Match. Null on 304; throws on anything else that is not a catalogue.
  Future<({Json body, String? etag})?> fetch(String? etag);
  Future<String?> readCache();
  Future<void> writeCache(String json);
}

/// The last good owner catalogue, kept on the phone across restarts. Refreshed quietly on foreground and Train entry
/// when older than five minutes, and at once after the owner publishes; a failed refresh never erases it.
class RemoteMedia extends Notifier<RemoteMediaCatalog?> {
  static const minAge = Duration(minutes: 5);
  DateTime? _checkedAt;
  String? _etag;
  Future<void>? _inflight, _loaded;

  RemoteMediaSource? get _source => ref.read(remoteMediaSourceProvider);

  @override
  RemoteMediaCatalog? build() {
    _loaded = _load();
    final life = AppLifecycleListener(onResume: refresh);
    ref.onDispose(life.dispose);
    // Asked once a server that has the catalogue is known (sign-in, capabilities), then on foreground and Train.
    ref.listen(remoteMediaSourceProvider, (_, next) {
      if (next != null) refresh();
    }, fireImmediately: true);
    return null;
  }

  Future<void> _load() async {
    final source = _source;
    if (source == null) return;
    try {
      final cached = await source.readCache();
      if (cached == null) return;
      final j = jsonDecode(cached) as Json;
      _etag = j['etag'] as String?;
      _checkedAt = DateTime.tryParse(j['checkedAt'] as String? ?? '');
      if (state == null) state = RemoteMediaCatalog.parse(j['body'] as Json);
    } on Object {
      // An unreadable cache is simply not used; the next refresh replaces it.
    }
  }

  /// Asks the API for changes unless it was asked within [minAge] ([force] skips that). At most one request at a time.
  Future<void> refresh({bool force = false}) => _inflight ??= _refresh(force).whenComplete(() => _inflight = null);

  Future<void> _refresh(bool force) async {
    await _loaded;
    final source = _source;
    final now = ref.read(nowProvider)();
    if (source == null || (!force && _checkedAt != null && now.difference(_checkedAt!) < minAge)) return;
    try {
      final r = await source.fetch(state == null ? null : _etag);
      _checkedAt = now;
      if (r != null) {
        _etag = r.etag;
        state = RemoteMediaCatalog.parse(r.body);
        await source.writeCache(jsonEncode({'etag': r.etag, 'checkedAt': now.toIso8601String(), 'body': r.body}));
        // Downloads of withdrawn or replaced owner videos go (never one that is playing).
        final base = ref.read(bundledMediaProvider).value;
        if (base != null) await ref.read(demoStoreProvider).retireExcept({for (final m in base.withRemote(state).media.values) ?m.video?.sha256});
      }
    } on Object {
      // Offline, an old server, a bad answer: the last good catalogue stays.
    }
  }
}

final nowProvider = Provider<DateTime Function()>((_) => DateTime.now);
/// The API, for a signed-in account on a server that declares the catalogue; none otherwise (an older server keeps
/// the bundled library and is never asked).
final remoteMediaSourceProvider = Provider<RemoteMediaSource?>((ref) {
  final owner = ref.watch(ownerProvider);
  final caps = ref.watch(compatibilityProvider).capabilities;
  if (owner == null || caps == null || !caps.contains('exercises.media-catalog')) return null;
  return _ApiMediaSource(ref.watch(apiProvider));
});

class _ApiMediaSource implements RemoteMediaSource {
  _ApiMediaSource(this._api);
  final Api _api;

  @override
  Future<({Json body, String? etag})?> fetch(String? etag) async {
    final r = await _api.send('GET', '/exercise-media/catalog', headers: {'If-None-Match': ?etag});
    if (r.status == 304) return null;
    if (!r.ok || r.data is! Map) throw StateError('catalogue ${r.status}');
    return (body: r.data as Json, etag: r.etag);
  }

  Future<File> _file() async => File(p.join((await getApplicationSupportDirectory()).path, 'exercise-media-catalog.json'));
  @override
  Future<String?> readCache() async {
    final f = await _file();
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> writeCache(String json) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json);
    await tmp.rename(f.path);
  }
}
final remoteMediaProvider = NotifierProvider<RemoteMedia, RemoteMediaCatalog?>(RemoteMedia.new);

// ------------------------------------------------------------------ downloads on this phone

/// Why a download did not finish. [message] is what the sheet says.
enum DemoFailure {
  network('The demonstration could not be reached. Check your connection and try again.'),
  notFound('The demonstration is no longer at its source. Try again later.'),
  invalid('What arrived was not the reviewed demonstration, so it was not kept. Try again.'),
  storage('There is not enough free space on this phone to save it.');

  const DemoFailure(this.message);
  final String message;
}

class DemoDownloadError implements Exception {
  const DemoDownloadError(this.failure);
  final DemoFailure failure;
  @override
  String toString() => 'DemoDownloadError(${failure.name})';
}

/// Fetches [url] into [into], stopping with [DemoFailure.invalid] past [maxBytes].
typedef DemoFetch = Future<void> Function(Uri url, File into, {required int maxBytes});

enum DemoSaved { none, downloading, downloaded, failed }

/// Clips the user chose to download, kept in app support storage (not the OS cache, which may be cleared): at most
/// [capacity] bytes in all, least recently used out first, but never a file that is playing. A download goes to a
/// temporary file, is checked against the reviewed size and SHA-256, and only then renamed into place; a partial or
/// wrong file is deleted. Two requests for the same clip share one download.
class DemoStore extends ChangeNotifier {
  DemoStore({required Future<Directory> Function() directory, DemoFetch? fetch, this.capacity = demoCacheBytes, DateTime Function()? now})
      // ignore: prefer_initializing_formals
      : _directory = directory, _fetch = fetch ?? fetchDemo, _now = now ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DemoFetch _fetch;
  final DateTime Function() _now;
  final int capacity;

  Future<Directory>? _dir;
  Map<String, ({int bytes, DateTime used, String file})>? _index;
  final _inflight = <String, Future<void>>{};
  final _failed = <String, DemoFailure>{};
  final _playing = <String, int>{};

  Future<Directory> _root() => _dir ??= () async {
        final d = await _directory();
        await d.create(recursive: true);
        _index = await _read(d);
        _notify();
        return d;
      }();

  Future<Map<String, ({int bytes, DateTime used, String file})>> _read(Directory d) async {
    try {
      final j = jsonDecode(await File(p.join(d.path, 'index.json')).readAsString()) as Json;
      return {
        for (final e in j.entries)
          e.key: (bytes: (e.value as Json)['bytes'] as int, used: DateTime.parse((e.value as Json)['used'] as String), file: (e.value as Json)['file'] as String),
      };
    } on Object {
      return {}; // none yet, or unreadable: start empty (orphan files are removed below on the next save)
    }
  }

  Future<void> _write(Directory d) async {
    final tmp = File(p.join(d.path, 'index.json.tmp'));
    await tmp.writeAsString(jsonEncode({for (final e in _index!.entries) e.key: {'bytes': e.value.bytes, 'used': e.value.used.toIso8601String(), 'file': e.value.file}}));
    await tmp.rename(p.join(d.path, 'index.json'));
  }

  /// Loads the index so [state] is right from the first frame of a sheet.
  Future<void> ready() async {
    try {
      await _root();
    } on Object {
      _dir = null; // no storage right now: try again on the next use, and say so then
    }
  }

  DemoSaved state(DemoVideo v) {
    if (_inflight.containsKey(v.sha256)) return DemoSaved.downloading;
    if (_index?.containsKey(v.sha256) ?? false) return DemoSaved.downloaded;
    return _failed.containsKey(v.sha256) ? DemoSaved.failed : DemoSaved.none;
  }

  DemoFailure? failure(DemoVideo v) => _failed[v.sha256];

  /// The complete, checked local copy, or null. A copy whose file has gone or changed size is forgotten (and its
  /// file removed): it is downloaded again rather than trusted.
  Future<File?> fileFor(DemoVideo v) async {
    final d = await _root();
    final e = _index![v.sha256];
    if (e == null) return null;
    final f = File(p.join(d.path, e.file));
    if (!await f.exists() || await f.length() != v.bytes) {
      _index!.remove(v.sha256);
      await _delete(f);
      await _write(d);
      _notify();
      return null;
    }
    _index![v.sha256] = (bytes: e.bytes, used: _now(), file: e.file);
    await _write(d);
    return f;
  }

  /// Marks a clip as playing (it is never evicted meanwhile). Call [release] when the player is gone.
  void hold(DemoVideo v) => _playing[v.sha256] = (_playing[v.sha256] ?? 0) + 1;
  void release(DemoVideo v) {
    final n = (_playing[v.sha256] ?? 1) - 1;
    if (n <= 0) {
      _playing.remove(v.sha256);
    } else {
      _playing[v.sha256] = n;
    }
  }

  Future<void> download(DemoVideo v) => _inflight[v.sha256] ??= _download(v).whenComplete(() {
        _inflight.remove(v.sha256);
        _notify();
      });

  Future<void> _download(DemoVideo v) async {
    _failed.remove(v.sha256);
    _notify();
    File? tmp;
    try {
      final Directory d;
      try {
        d = await _root();
      } on Object {
        _dir = null;
        throw const DemoDownloadError(DemoFailure.storage);
      }
      tmp = File(p.join(d.path, '${v.sha256}.part'));
      if (v.bytes > maxClipBytes || v.bytes > capacity) throw const DemoDownloadError(DemoFailure.invalid);
      await _fetch(v.url, tmp, maxBytes: v.bytes);
      if (await tmp.length() != v.bytes || (await sha256.bind(tmp.openRead()).first).toString() != v.sha256) {
        throw const DemoDownloadError(DemoFailure.invalid);
      }
      await tmp.rename(p.join(d.path, v.fileName));
      _index![v.sha256] = (bytes: v.bytes, used: _now(), file: v.fileName);
      await _evict(d, keep: v.sha256);
      await _write(d);
    } on Object catch (e) {
      if (tmp != null) await _delete(tmp);
      final failure = _failed[v.sha256] = switch (e) {
        DemoDownloadError(:final failure) => failure,
        FileSystemException() => DemoFailure.storage,
        _ => DemoFailure.network,
      };
      throw DemoDownloadError(failure);
    }
  }

  Future<void> _evict(Directory d, {required String keep}) async {
    final byAge = _index!.entries.toList()..sort((a, b) => a.value.used.compareTo(b.value.used));
    var total = _index!.values.fold<int>(0, (s, e) => s + e.bytes);
    for (final e in byAge) {
      if (total <= capacity) break;
      if (e.key == keep || _playing.containsKey(e.key)) continue;
      _index!.remove(e.key);
      total -= e.value.bytes;
      await _delete(File(p.join(d.path, e.value.file)));
    }
  }

  Future<void> remove(DemoVideo v) async {
    final d = await _root();
    final e = _index!.remove(v.sha256);
    _failed.remove(v.sha256);
    if (e != null) await _delete(File(p.join(d.path, e.file)));
    await _write(d);
    _notify();
  }

  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Deletes saved clips that no longer belong to any demonstration (a withdrawn or replaced owner video), except one
  /// that is playing: it goes on a later pass.
  Future<void> retireExcept(Set<String> keep) async {
    final Directory d;
    try {
      d = await _root();
    } on Object {
      return;
    }
    final gone = [for (final sha in _index!.keys) if (!keep.contains(sha) && !_playing.containsKey(sha)) sha];
    if (gone.isEmpty) return;
    for (final sha in gone) {
      await _delete(File(p.join(d.path, _index!.remove(sha)!.file)));
    }
    await _write(d);
    _notify();
  }

  int get usedBytes => _index?.values.fold<int>(0, (s, e) => s + e.bytes) ?? 0;

  static Future<void> _delete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // Already gone, or the OS refuses: nothing points at it any more.
    }
  }
}

/// The real fetch: plain HTTPS GET with no GoHard headers or credentials, bounded in time and size, following
/// redirects only on an HTTPS URL.
Future<void> fetchDemo(Uri url, File into, {required int maxBytes}) async {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 30), responseType: ResponseType.stream, maxRedirects: 3));
  final IOSink sink;
  try {
    sink = into.openWrite();
  } on FileSystemException {
    throw const DemoDownloadError(DemoFailure.storage);
  }
  try {
    final r = await dio.getUri<ResponseBody>(url);
    if (r.realUri.scheme != 'https') throw const DemoDownloadError(DemoFailure.invalid);
    var n = 0;
    await for (final chunk in r.data!.stream) {
      n += chunk.length;
      if (n > maxBytes) throw const DemoDownloadError(DemoFailure.invalid);
      sink.add(chunk);
    }
  } on DioException catch (e) {
    throw DemoDownloadError(e.response?.statusCode == 404 || e.response?.statusCode == 410 ? DemoFailure.notFound : DemoFailure.network);
  } finally {
    await sink.close();
    dio.close(force: true);
  }
}

final demoStoreProvider = Provider<DemoStore>((ref) {
  final store = DemoStore(directory: () async => Directory(p.join((await getApplicationSupportDirectory()).path, 'exercise-demos')));
  ref.onDispose(store.dispose);
  return store;
});
