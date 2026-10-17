import 'dart:convert';

import '../../data/db.dart' show Cmd;
import '../../data/models.dart';
import '../../data/session.dart';
import '../../data/sync.dart';
import 'track_math.dart';
import 'track_store.dart';

/// Run / Walk records and their routes, through the outbox (docs/RUN_WALK.md › Sync contract).
/// Everything is committed on this phone first; the account follows when it can.
class RunRepository {
  RunRepository(this._sync, this._owner, this._track, this._api);
  final SyncEngine _sync;
  final String _owner;
  final TrackStore _track;
  final Api _api;

  /// Whether this account's server can take [cmd] yet. A Walk, an edit, metrics-only details or a route sent to a
  /// server without them would be stored as something else (a plain run) or refused, so they wait. Unknown
  /// capabilities (no answer yet) wait too; everything else is sent as before.
  static bool serverTakes(Cmd cmd, Set<String>? capabilities) {
    bool has(String c) => capabilities?.contains(c) ?? false;
    if (cmd.kind.startsWith('route.')) return has('runs.routes');
    if (cmd.kind == 'run.update') return has('runs.activity-type');
    if (cmd.kind == 'run.start' && (jsonDecode(cmd.payload) as Map)['activityType'] == 'walk') return has('runs.activity-type');
    return true;
  }

  /// Creates the activity and its recorder state in one local transaction; nothing is recorded if it fails.
  Future<Run> start({required String id, required String dayKey, required DateTime startedAtUtc, required String type, required Json runtime}) async {
    final at = startedAtUtc.toIso8601String();
    final body = <String, dynamic>{
      'id': id, 'dayKey': dayKey, 'startedAtUtc': at, 'finishedAtUtc': null, 'activeDurationSeconds': null, 'distanceMeters': null,
      'revision': 0, 'isDeleted': false, 'activityType': type,
    };
    await _sync.submit(_owner, kind: 'run.start', path: '/runs', targetKind: Kinds.run, targetId: id,
        writes: [LocalWrite(Kinds.run, id, body, dayKey: dayKey)], locals: [LocalWrite(Kinds.runtime, id, runtime)],
        payload: {'runId': id, 'dayKey': dayKey, 'startedAtUtc': at, 'activityType': type});
    return Run(body);
  }

  /// Saves the finished activity and queues its route, all in one local transaction: either the whole save is on
  /// this phone, or nothing changed and the activity is still open with its route.
  Future<void> save(Run run, {required DateTime finishedAtUtc, required int activeSeconds, required double? distanceMeters,
      required String title, required String? notes, required Json metrics}) async {
    final at = finishedAtUtc.toIso8601String();
    final (count, top) = await _track.extent(_owner, run.id);
    final chunks = top < 0 ? 0 : top ~/ TrackStore.chunkSize + 1;
    final routeChunks = [for (var i = 0; i < chunks; i++) await _track.chunk(_owner, run.id, i)];
    final hasFixes = metrics['routeState'] != 'none';
    await _sync.db.transaction(() async {
      await _sync.submit(_owner, kind: 'run.finish', path: '/runs/${run.id}/finish', targetKind: Kinds.run, targetId: run.id, dispatch: false,
          writes: [
            LocalWrite(Kinds.run, run.id, copyJson(run.j)..addAll({
              'finishedAtUtc': at, 'activeDurationSeconds': activeSeconds, 'distanceMeters': distanceMeters, 'title': title, 'notes': notes, 'metrics': metrics,
            }), dayKey: run.dayKey),
          ],
          payload: {
            'expectedRevision': {r'$rev': [Kinds.run, run.id]}, 'activeDurationSeconds': activeSeconds, 'distanceMeters': distanceMeters,
            'finishedAtUtc': at, 'title': title, 'notes': ?notes, 'metrics': metrics,
          });
      await _sync.deleteLocal(_owner, Kinds.runtime, run.id);
      if (!hasFixes || count == 0) return; // a timer-only activity has no route to keep on the account
      for (final (i, entries) in routeChunks.indexed) {
        await _sync.submit(_owner, kind: 'route.chunk', method: 'PUT', path: '/runs/${run.id}/route/chunks/$i', targetKind: Kinds.route, targetId: run.id,
            after: [(Kinds.run, run.id)], dispatch: false,
            writes: i == 0 ? [LocalWrite(Kinds.route, run.id, {'id': run.id, 'chunkCount': chunks, 'entryCount': count})] : const [],
            payload: {'firstSeq': entries.first.seq, 'lastSeq': entries.last.seq, 'entries': [for (final e in entries) e.toJson()]});
      }
      await _sync.submit(_owner, kind: 'route.complete', path: '/runs/${run.id}/route/complete', targetKind: Kinds.route, targetId: run.id,
          dispatch: false, payload: {'chunkCount': chunks, 'entryCount': count});
    });
    _sync.kick();
  }

  /// An edit of a saved activity. A distance correction keeps the GPS measurement in the metrics.
  Future<void> update(Run run, {required String type, required String title, required String? notes, required double? distanceMeters, required Json metrics}) =>
      _sync.submit(_owner, kind: 'run.update', method: 'PUT', path: '/runs/${run.id}', targetKind: Kinds.run, targetId: run.id,
          writes: [
            LocalWrite(Kinds.run, run.id, copyJson(run.j)..addAll({'activityType': type, 'title': title, 'notes': notes, 'distanceMeters': distanceMeters, 'metrics': metrics}),
                dayKey: run.dayKey),
          ],
          payload: {
            'expectedRevision': {r'$rev': [Kinds.run, run.id]}, 'activityType': type, 'title': title, 'notes': notes ?? '',
            'distanceMeters': distanceMeters, 'metrics': metrics,
          });

  /// Deletes (or discards) an activity: the record is marked deleted for sync, queued route uploads are withdrawn,
  /// and the route and recorder state are erased from this phone.
  Future<void> delete(Run run) async {
    await _sync.submit(_owner, kind: 'run.delete', path: '/runs/${run.id}/delete', targetKind: Kinds.run, targetId: run.id,
        writes: [LocalWrite(Kinds.run, run.id, copyJson(run.j)..['isDeleted'] = true, dayKey: run.dayKey)],
        payload: {'expectedRevision': {r'$rev': [Kinds.run, run.id]}});
    await _sync.withdraw(_owner, Kinds.route, run.id);
    await _sync.deleteLocal(_owner, Kinds.runtime, run.id);
    await _track.erase(_owner, run.id);
  }

  /// The route of an activity recorded on another phone, read page by page from the account and kept here.
  /// Returns false when it could not be read now (offline, or the account has none).
  Future<bool> fetchRoute(Run run) async {
    int? from = 0;
    try {
      while (from != null) {
        final r = await _api.send('GET', '/runs/${run.id}/route?fromIndex=$from');
        if (!r.ok || r.data is! Map) return false;
        final page = r.data as Json;
        for (final c in page['chunks'] as List) {
          await _track.putAll(_owner, run.id, [for (final e in (c as Json)['entries'] as List) TrackEntry.fromJson((e as Map).cast<String, dynamic>())]);
        }
        from = page['nextIndex'] as int?;
      }
      return true;
    } on TransportFailure {
      return false;
    }
  }
}
