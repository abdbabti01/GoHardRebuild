import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/models.dart';

/// Exercise demonstrations (docs/EXERCISE_DEMOS.md): the reviewed, bundled manifest (assets/data/exercise-media.json,
/// built by scripts/build-exercise-demos.mjs) and the phone's own store of downloaded clips. Public educational media
/// only: nothing here is part of a plan, a workout or the account, nothing syncs, and no request carries GoHard's
/// credentials or anything about the user.

const maxClipBytes = 20 * 1024 * 1024;
const demoCacheBytes = 100 * 1024 * 1024;

@immutable
class DemoCredit {
  const DemoCredit({required this.creator, required this.licence, required this.licenceUrl, required this.attribution});
  final String creator, licence, licenceUrl, attribution;
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

/// One reviewed demonstration for one catalogue key: a clip (with a bundled poster) or a still (the poster itself).
@immutable
class ExerciseMedia {
  const ExerciseMedia({required this.catalogKey, required this.poster, required this.variant, required this.credit, required this.changes,
      required this.sourcePage, required this.providerName, this.video});
  final String catalogKey, poster, variant, changes, sourcePage, providerName;
  final DemoCredit credit;
  final DemoVideo? video;
  bool get isVideo => video != null;
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

  final int version;
  final Map<String, ExerciseMedia> media;
  final Map<String, TechniqueGuide> technique;
  final String techniqueReviewNote;
  final List<String> rejected;

  /// The demonstration for exactly this catalogue key. A custom exercise (or none) never has one, whatever its name.
  ExerciseMedia? forKey(String? catalogKey) => catalogKey == null || catalogKey.startsWith('custom:') ? null : media[catalogKey];
  TechniqueGuide? techniqueFor(String? catalogKey) => catalogKey == null || catalogKey.startsWith('custom:') ? null : technique[catalogKey];
}

final exerciseMediaProvider = FutureProvider<ExerciseMediaCatalog>((ref) async => ExerciseMediaCatalog.parse(await rootBundle.loadString('assets/data/exercise-media.json')));

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
