import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'db.dart';
import 'models.dart';
import 'session.dart';

/// A record as the account authority reports it.
class ServerRec {
  const ServerRec(this.kind, this.id, this.body, this.revision, {this.parentId, this.dayKey});
  final String kind, id;
  final Json body;
  final int revision;
  final String? parentId, dayKey;
}

/// A local change written atomically with its command.
class LocalWrite {
  const LocalWrite(this.kind, this.id, this.body, {this.parentId, this.dayKey});
  final String kind, id;
  final Json body;
  final String? parentId, dayKey;
}

/// Proof that a change is durably on this phone. `pending` is not an account acknowledgement.
class Receipt {
  const Receipt(this.operationId, this.syncState);
  final String operationId, syncState;
}

/// The local write failed. Nothing was saved, and the caller must keep the user's input on screen.
class LocalSaveFailure implements Exception {
  const LocalSaveFailure(this.cause);
  final Object cause;
  @override
  String toString() => 'LocalSaveFailure($cause)';
}

Json _stripSets(Json workout) => copyJson(workout)..['exercises'] = [for (final e in workout['exercises'] as List? ?? const []) copyJson(e as Map)..remove('sets')];

List<ServerRec> _workout(Json w) => [
      ServerRec(Kinds.workout, w['id'] as String, _stripSets(w), w['revision'] as int, dayKey: w['dayKey'] as String?),
      for (final e in w['exercises'] as List? ?? const [])
        for (final s in (e as Json)['sets'] as List? ?? const [])
          ServerRec(Kinds.set, (s as Json)['id'] as String, s, s['revision'] as int, parentId: w['id'] as String),
    ];

List<ServerRec> _context(Json c, String owner) => [
      ServerRec(Kinds.context, owner, {'contextRevision': c['contextRevision'], 'primaryPlanId': c['primaryPlanId']}, c['contextRevision'] as int),
      for (final p in c['plans'] as List? ?? const []) ServerRec(Kinds.plan, (p as Json)['id'] as String, p, p['revision'] as int),
    ];

ServerRec _simple(String kind, Json j, {String idField = 'id'}) =>
    ServerRec(kind, j[idField] as String, j, j['revision'] as int? ?? 1, dayKey: j['dayKey'] as String?);

/// Maps a command acknowledgement's data onto local records. Unknown kinds map to nothing.
List<ServerRec> recordsFromAck(String kind, dynamic data, String owner) {
  if (data is! Map) return const [];
  final j = data as Json;
  return switch (kind.split('.').first) {
    'set' => [ServerRec(Kinds.set, j['id'] as String, j, j['revision'] as int, parentId: j['workoutId'] as String)],
    'workout' || 'exercise' => _workout(j),
    // A saved meal logged at once answers with all of its entries.
    'food' => kind == 'food.batch' ? [for (final e in j['entries'] as List? ?? const []) _simple(Kinds.food, e as Json)] : [_simple(Kinds.food, j)],
    'water' => [_simple(Kinds.water, j)],
    'run' => [_simple(Kinds.run, j)],
    // route.complete answers with the activity (its routeState); a chunk's answer changes no record.
    'route' => kind == 'route.complete' ? [_simple(Kinds.run, j)] : const [],
    'metric' => [_simple(Kinds.metric, j)],
    'savedfood' => [_simple(Kinds.savedFood, j)],
    'savedmeal' => [_simple(Kinds.savedMeal, j)],
    'customexercise' => [_simple(Kinds.customExercise, j)],
    'weeklygoal' => [_simple(Kinds.weeklyGoal, j, idField: 'weekStart')],
    'exerciseincrement' => [_simple(Kinds.exerciseIncrement, j, idField: 'exerciseKey')],
    'profile' => [_simple(Kinds.profile, j, idField: 'userId')],
    'plan' => kind == 'plan.draft' ? (j['context'] is Map ? _context(j['context'] as Json, owner) : const []) : _context(j, owner),
    'proposal' => kind == 'proposal.create'
        ? [_simple(Kinds.proposal, j)]
        : [_simple(Kinds.proposal, j['proposal'] as Json), if (j['context'] is Map) ..._context(j['context'] as Json, owner)],
    _ => const [],
  };
}

List<ServerRec> recordsFromSnapshot(Json s, String owner) => [
      _simple(Kinds.profile, s['profile'] as Json, idField: 'userId'),
      ..._context(s['context'] as Json, owner),
      for (final w in s['workouts'] as List) ..._workout(w as Json),
      for (final f in s['foodEntries'] as List) _simple(Kinds.food, f as Json),
      for (final r in s['runs'] as List) _simple(Kinds.run, r as Json),
      for (final m in s['bodyMetrics'] as List) _simple(Kinds.metric, m as Json),
      for (final p in s['proposals'] as List) _simple(Kinds.proposal, p as Json),
      for (final c in s['catalog'] as List) ServerRec(Kinds.catalog, (c as Json)['key'] as String, c, 1),
      // Absent on a server from before reusable foods.
      for (final f in s['savedFoods'] as List? ?? const []) _simple(Kinds.savedFood, f as Json),
      // Absent on a server from before the plan builder.
      for (final c in s['customExercises'] as List? ?? const []) _simple(Kinds.customExercise, c as Json),
      // Absent on a server from before water tracking.
      for (final w in s['waterEntries'] as List? ?? const []) _simple(Kinds.water, w as Json),
      // Absent on a server from before weekly goals.
      for (final g in s['weeklyGoals'] as List? ?? const []) _simple(Kinds.weeklyGoal, g as Json, idField: 'weekStart'),
      // Absent on a server from before equipment increments.
      for (final x in s['exerciseIncrements'] as List? ?? const []) _simple(Kinds.exerciseIncrement, x as Json, idField: 'exerciseKey'),
      // Absent on a server from before saved meals and recipes.
      for (final m in s['savedMeals'] as List? ?? const []) _simple(Kinds.savedMeal, m as Json),
    ];

/// Local-first persistence and synchronization.
///
/// * `submit` saves the local change and its command in ONE transaction, before any network use.
/// * Commands dispatch in dependency order with a stable operation ID and an outbound payload that is
///   resolved once and then reused byte-for-byte on every retry.
/// * An acknowledgement only replaces a record's body when no newer local edit is waiting.
/// * Conflicts and rejections keep both versions and wait for an explicit choice.
/// * Every write is keyed by the owner captured at the start; an epoch change publishes nothing.
class SyncEngine {
  SyncEngine(this.db, this._api, this._sessions);
  final AppDb db;
  final Api _api;
  final SessionManager _sessions;
  static const _uuid = Uuid();
  bool _again = false, _disposed = false;
  Future<void>? _running;
  Timer? _retry;

  /// True while this build is known to be too old for the account's server. Nothing is sent or pulled then;
  /// every command stays in the outbox, untouched, for when the check passes again.
  bool Function() isBlocked = () => false;

  /// False for a command this account's server cannot take yet (a Walk or a route on a server from before them).
  /// It stays pending, untouched, and so do the commands that depend on it.
  bool Function(Cmd cmd) mayDispatch = (_) => true;

  /// Test seam: called just before a dispatch, after the outbound payload is persisted.
  Future<void> Function(Cmd cmd)? beforeDispatch;

  static String newId() => _uuid.v4();

  // ---------------------------------------------------------------- reads

  Future<Rec?> get(String owner, String kind, String id) =>
      (db.select(db.records)..where((r) => r.ownerId.equals(owner) & r.kind.equals(kind) & r.id.equals(id))).getSingleOrNull();

  SimpleSelectStatement<$RecordsTable, Rec> _query(String owner, String kind, {String? parentId, String? dayKey}) => db.select(db.records)
    ..where((r) {
      var e = r.ownerId.equals(owner) & r.kind.equals(kind);
      if (parentId != null) e = e & r.parentId.equals(parentId);
      if (dayKey != null) e = e & r.dayKey.equals(dayKey);
      return e;
    });

  Future<List<Rec>> list(String owner, String kind, {String? parentId, String? dayKey}) => _query(owner, kind, parentId: parentId, dayKey: dayKey).get();
  Stream<List<Rec>> watch(String owner, String kind, {String? parentId, String? dayKey}) => _query(owner, kind, parentId: parentId, dayKey: dayKey).watch();

  Stream<List<Rec>> watchIssues(String owner) =>
      (db.select(db.records)..where((r) => r.ownerId.equals(owner) & r.syncState.isIn(const ['conflict', 'rejected']))).watch();

  Stream<int> watchPendingCount(String owner) =>
      (db.select(db.commands)..where((c) => c.ownerId.equals(owner) & c.state.equals('pending'))).watch().map((l) => l.length);

  Future<List<Cmd>> commands(String owner, {List<String> states = const ['pending', 'conflict', 'rejected']}) =>
      (db.select(db.commands)
            ..where((c) => c.ownerId.equals(owner) & c.state.isIn(states))
            ..orderBy([(c) => OrderingTerm.asc(c.seq)]))
          .get();

  Future<List<Cmd>> _openFor(String owner, String kind, String id) async =>
      (await commands(owner)).where((c) => c.targetKind == kind && c.targetId == id).toList();

  // ---------------------------------------------------------------- local writes

  /// Saves something that never leaves the phone (workout runtime, form drafts).
  Future<void> putLocal(String owner, LocalWrite w) => _guard(() => db.into(db.records).insertOnConflictUpdate(RecordsCompanion.insert(
      ownerId: owner, kind: w.kind, id: w.id, body: jsonEncode(w.body), parentId: Value(w.parentId), dayKey: Value(w.dayKey), syncState: const Value('local'))));

  /// Rewrites a syncable record's local body ahead of a replacement command issued by a resolution.
  Future<void> putLocalPending(String owner, LocalWrite w) => _guard(() => _upsertPending(owner, w));

  Future<void> deleteLocal(String owner, String kind, String id) =>
      (db.delete(db.records)..where((r) => r.ownerId.equals(owner) & r.kind.equals(kind) & r.id.equals(id))).go();

  Future<T> _guard<T>(Future<T> Function() write) async {
    try {
      return await write();
    } on LocalSaveFailure {
      rethrow;
    } on Object catch (e) {
      throw LocalSaveFailure(e);
    }
  }

  Future<void> _upsertPending(String owner, LocalWrite w) async {
    final existing = await get(owner, w.kind, w.id);
    if (existing == null) {
      await db.into(db.records).insert(RecordsCompanion.insert(
          ownerId: owner, kind: w.kind, id: w.id, body: jsonEncode(w.body), parentId: Value(w.parentId), dayKey: Value(w.dayKey),
          localRevision: const Value(1), syncState: const Value('pending')));
    } else {
      await (db.update(db.records)..where((r) => r.ownerId.equals(owner) & r.kind.equals(w.kind) & r.id.equals(w.id))).write(RecordsCompanion(
          body: Value(jsonEncode(w.body)), parentId: Value(w.parentId ?? existing.parentId), dayKey: Value(w.dayKey ?? existing.dayKey),
          localRevision: Value(existing.localRevision + 1),
          syncState: Value(existing.syncState == 'conflict' ? 'conflict' : 'pending')));
    }
  }

  /// Saves `writes` and one command atomically, then starts a background dispatch.
  ///
  /// `payload` may contain placeholders resolved once before first dispatch:
  /// `{"\$rev": [kind, id]}` → that record's acknowledged revision, `{"\$sets": workoutId}` → its live sets.
  /// `after` lists other records whose open commands must be acknowledged first.
  /// [dispatch] false: a caller that submits several commands inside its own transaction starts the dispatch itself,
  /// after that transaction (a dispatch started inside it would outlive it).
  Future<Receipt> submit(String owner, {
    required String kind, String method = 'POST', required String path, required Json payload,
    required String targetKind, required String targetId, List<LocalWrite> writes = const [],
    List<(String, String)> after = const [], String? operationId, List<String> extraDependsOn = const [],
    List<LocalWrite> locals = const [], bool dispatch = true,
  }) async {
    final op = operationId ?? newId();
    await _guard(() => db.transaction(() async {
          for (final w in writes) {
            await _upsertPending(owner, w);
          }
          for (final w in locals) {
            await db.into(db.records).insertOnConflictUpdate(RecordsCompanion.insert(ownerId: owner, kind: w.kind, id: w.id,
                body: jsonEncode(w.body), parentId: Value(w.parentId), dayKey: Value(w.dayKey), syncState: const Value('local')));
          }
          final target = await get(owner, targetKind, targetId);
          final open = await commands(owner);
          final deps = {
            ...extraDependsOn,
            for (final c in open)
              if ((c.targetKind == targetKind && c.targetId == targetId) || after.contains((c.targetKind, c.targetId))) c.operationId,
          };
          await db.into(db.commands).insert(CommandsCompanion.insert(
              operationId: op, ownerId: owner, kind: kind, method: method, path: path,
              payload: jsonEncode({...payload, 'operationId': op}), targetKind: targetKind, targetId: targetId,
              capturedLocalRevision: target?.localRevision ?? 0, dependsOn: Value(jsonEncode(deps.toList()))));
        }));
    if (dispatch) kick();
    return Receipt(op, 'pending');
  }

  // ---------------------------------------------------------------- dispatch

  void kick() {
    if (!_disposed) flush().ignore(); // background pass: failures leave commands pending for the next trigger
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
  }

  /// Dispatches everything currently dispatchable for the signed-in owner. Single flight.
  /// A caller that arrives while a pass is running waits for that pass plus one more, so "await flush()"
  /// always means everything dispatchable at the time of the call has been tried.
  Future<void> flush() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _passes().whenComplete(() => _running = null);
  }

  Future<void> _passes() async {
    do {
      _again = false;
      try {
        await _drain();
      } on Object {
        // Storage closing underneath a background pass (app shutdown) is not an error: commands stay pending.
        if (!_disposed) rethrow;
      }
    } while (_again && !_disposed);
  }

  /// Completes when no dispatch pass is running. Used before closing the database.
  Future<void> idle() async {
    try {
      await _running;
    } on Object {
      // The pass's own awaiter reports its failure.
    }
  }

  Future<Cmd?> _nextDispatchable(String owner) async {
    final pending = await commands(owner, states: const ['pending']);
    if (pending.isEmpty) return null;
    final states = {for (final c in await (db.select(db.commands)..where((c) => c.ownerId.equals(owner))).get()) c.operationId: c.state};
    for (final c in pending) {
      final deps = (jsonDecode(c.dependsOn) as List).cast<String>();
      // A dependency in conflict or rejected blocks its dependents until the user decides.
      if (deps.every((d) => const ['accepted', 'superseded', null].contains(states[d])) && mayDispatch(c)) return c;
    }
    return null;
  }

  Future<dynamic> _resolve(String owner, dynamic node) async {
    if (node is List) return [for (final x in node) await _resolve(owner, x)];
    if (node is! Map) return node;
    if (node.length == 1 && node.containsKey(r'$rev')) {
      final ref = node[r'$rev'] as List;
      return (await get(owner, ref[0] as String, ref[1] as String))?.revision ?? 0;
    }
    if (node.length == 1 && node.containsKey(r'$sets')) {
      final sets = await list(owner, Kinds.set, parentId: node[r'$sets'] as String);
      return [
        for (final s in sets)
          if (!WorkoutSet(jsonDecode(s.body) as Json).isDeleted) {'id': s.id, 'revision': s.revision}
      ];
    }
    return {for (final e in node.entries) e.key as String: await _resolve(owner, e.value)};
  }

  // ---------------------------------------------------------------- account access (required verification)

  static bool _verificationRequired(ApiResponse r) => r.status == 403 && r.data is Map && (r.data as Map)['code'] == 'EMAIL_VERIFICATION_REQUIRED';

  /// Keeps what a server answer says about [owner]'s access. A server from before required verification says nothing,
  /// and nothing is written; no answer at all never downgrades anything.
  Future<void> adoptAccess(String owner, Json profile) async {
    if (profile['verificationRequired'] is! bool) return;
    await putLocal(owner, LocalWrite(Kinds.accountAccess, owner,
        {'required': profile['verificationRequired'], 'verified': profile['emailVerified'], 'dueAtUtc': profile['verificationDueAtUtc']}));
  }

  Future<bool> _accessPaused(String owner) async {
    final r = await get(owner, Kinds.accountAccess, owner);
    return r != null && AccountAccess(jsonDecode(r.body) as Json).required;
  }

  /// Asks the account (`/me`, open while verification is pending) and keeps its answer. True when it answered.
  Future<bool> refreshAccess() async {
    final s = _sessions.current;
    if (s == null) return false;
    final ApiResponse r;
    try {
      r = await _api.send('GET', '/me');
    } on TransportFailure {
      return false;
    }
    if (!r.ok || r.data is! Json || _sessions.current?.epoch != s.epoch) return false;
    await adoptAccess(s.ownerId, r.data as Json);
    if (!await _accessPaused(s.ownerId)) kick(); // verified elsewhere: the waiting changes can go
    return true;
  }

  Future<void> _drain() async {
    final s = _sessions.current;
    if (s == null || isBlocked()) return;
    // Waiting for verification: every command stays pending, untouched, and goes once the account may take it.
    if (await _accessPaused(s.ownerId)) return;
    while (!_disposed) {
      if (_sessions.current?.epoch != s.epoch) return;
      final cmd = await _nextDispatchable(s.ownerId);
      if (cmd == null) return;

      // Resolve references ONCE and persist the exact outbound bytes before the first dispatch.
      var outbound = cmd.outbound;
      if (outbound == null) {
        outbound = jsonEncode(await _resolve(s.ownerId, jsonDecode(cmd.payload)));
        await (db.update(db.commands)..where((c) => c.seq.equals(cmd.seq))).write(CommandsCompanion(outbound: Value(outbound)));
      }
      await beforeDispatch?.call(cmd);

      ApiResponse r;
      try {
        r = await _api.send(cmd.method, cmd.path, data: jsonDecode(outbound));
      } on TransportFailure catch (e) {
        await _attempt(cmd, e.message);
        return;
      }
      // The account changed while this was in flight: publish nothing. The command stays pending for its owner.
      if (_sessions.current?.epoch != s.epoch) return;
      if (r.status == 401) return;
      if (_verificationRequired(r)) {
        await refreshAccess(); // pauses the outbox; this command was not taken and stays as it is
        return;
      }
      if (r.ack == null && (r.status >= 500 || r.status == 429 || r.status == 408)) {
        await _attempt(cmd, 'HTTP_${r.status}');
        return;
      }
      await _settle(s.ownerId, cmd, r);
    }
  }

  Future<void> _attempt(Cmd cmd, String error) async {
    await (db.update(db.commands)..where((c) => c.seq.equals(cmd.seq))).write(CommandsCompanion(attempts: Value(cmd.attempts + 1), lastError: Value(error)));
    _retry?.cancel();
    final seconds = [5, 15, 30, 60, 120][cmd.attempts.clamp(0, 4)];
    if (!_disposed) _retry = Timer(Duration(seconds: seconds), kick);
  }

  Future<void> _settle(String owner, Cmd cmd, ApiResponse r) async {
    final ack = r.ack;
    final status = ack?['status'] as String? ?? 'rejected';
    final code = ack?['code'] as String? ?? (r.status == 404 ? 'NOT_FOUND' : 'HTTP_${r.status}');
    await db.transaction(() async {
      final ackJson = ack == null ? null : jsonEncode(ack);
      if (status == 'accepted') {
        await (db.update(db.commands)..where((c) => c.seq.equals(cmd.seq))).write(CommandsCompanion(state: const Value('accepted'), ack: Value(ackJson),
            // An acknowledged route chunk is never sent again: its copy of the route (the phone keeps the route itself) is dropped.
            payload: cmd.kind == 'route.chunk' ? const Value('{}') : const Value.absent(), outbound: cmd.kind == 'route.chunk' ? const Value('{}') : const Value.absent()));
        for (final rec in recordsFromAck(cmd.kind, ack!['data'], owner)) {
          await _merge(owner, rec, exceptSeq: cmd.seq);
        }
        // A target with no remaining work is settled even when the ack carried no body for it.
        if ((await _openFor(owner, cmd.targetKind, cmd.targetId)).isEmpty) {
          await (db.update(db.records)..where((x) => x.ownerId.equals(owner) & x.kind.equals(cmd.targetKind) & x.id.equals(cmd.targetId) & x.syncState.equals('pending')))
              .write(const RecordsCompanion(syncState: Value('synced')));
        }
      } else {
        // Conflict or rejection: keep the local version, hold the account's version beside it, and wait for a choice.
        await (db.update(db.commands)..where((c) => c.seq.equals(cmd.seq)))
            .write(CommandsCompanion(state: Value(status == 'conflict' ? 'conflict' : 'rejected'), ack: Value(ackJson), lastError: Value(code)));
        final server = recordsFromAck(cmd.kind, ack?['data'], owner).where((x) => x.kind == cmd.targetKind && x.id == cmd.targetId).firstOrNull;
        await (db.update(db.records)..where((x) => x.ownerId.equals(owner) & x.kind.equals(cmd.targetKind) & x.id.equals(cmd.targetId))).write(RecordsCompanion(
            syncState: Value(status == 'conflict' ? 'conflict' : 'rejected'),
            serverBody: Value(server == null ? null : jsonEncode(server.body)),
            revision: server == null ? const Value.absent() : Value(server.revision)));
      }
    });
  }

  /// Submits a command that has no optimistic local change and waits for the account's answer.
  /// Returns the settled command; `state` stays `pending` when the account could not be reached.
  Future<Cmd> submitAndWait(String owner, {
    required String kind, String method = 'POST', required String path, required Json payload,
    required String targetKind, required String targetId, String? operationId, List<(String, String)> after = const [],
  }) async {
    final existing = operationId == null ? null : await command(operationId);
    final op = existing?.operationId ??
        (await submit(owner, kind: kind, method: method, path: path, payload: payload, targetKind: targetKind, targetId: targetId, operationId: operationId, after: after)).operationId;
    await flush();
    return (await command(op))!;
  }

  /// Withdraws a command that changed nothing locally (for example a refused draft request).
  Future<void> abandon(String operationId) =>
      (db.update(db.commands)..where((c) => c.operationId.equals(operationId) & c.state.isNotValue('accepted'))).write(const CommandsCompanion(state: Value('superseded')));

  /// Withdraws every unsent command for a record and removes the record (an erased route's queued uploads).
  Future<void> withdraw(String owner, String kind, String id) => _guard(() => db.transaction(() async {
        await (db.update(db.commands)..where((c) => c.ownerId.equals(owner) & c.targetKind.equals(kind) & c.targetId.equals(id) & c.state.isNotIn(const ['accepted', 'superseded'])))
            .write(const CommandsCompanion(state: Value('superseded')));
        await deleteLocal(owner, kind, id);
      }));

  /// Applies the account's version of a record without ever overwriting a newer local edit.
  Future<void> _merge(String owner, ServerRec r, {int? exceptSeq, bool force = false, bool keepAlternative = false}) async {
    final existing = await get(owner, r.kind, r.id);
    if (existing == null) {
      await db.into(db.records).insert(RecordsCompanion.insert(ownerId: owner, kind: r.kind, id: r.id, body: jsonEncode(r.body),
          parentId: Value(r.parentId), dayKey: Value(r.dayKey), revision: Value(r.revision)));
      return;
    }
    if (!force && existing.revision > r.revision) return; // a stale read never regresses a record
    final where = db.update(db.records)..where((x) => x.ownerId.equals(owner) & x.kind.equals(r.kind) & x.id.equals(r.id));
    final open = (await _openFor(owner, r.kind, r.id)).where((c) => c.seq != exceptSeq);
    if (!force && (open.isNotEmpty || existing.syncState == 'conflict' || existing.syncState == 'rejected')) {
      await where.write(RecordsCompanion(revision: Value(r.revision))); // older ack: newer local change is kept
      return;
    }
    final body = jsonEncode(r.body);
    await where.write(RecordsCompanion(body: Value(body), revision: Value(r.revision), parentId: Value(r.parentId ?? existing.parentId),
        dayKey: Value(r.dayKey ?? existing.dayKey), syncState: const Value('synced'), serverBody: const Value(null),
        alternativeBody: keepAlternative && existing.syncState != 'synced' && existing.body != body ? Value(existing.body) : const Value.absent()));
  }

  /// Fetches the owner's account state and merges it. Returns false when offline or signed out.
  // ponytail: full-snapshot pull; add a `since` cursor when histories grow beyond a few thousand records.
  Future<bool> pull() async {
    final s = _sessions.current;
    if (s == null || isBlocked()) return false;
    ApiResponse r;
    try {
      r = await _api.send('GET', '/sync/snapshot');
    } on TransportFailure {
      return false;
    }
    if (_verificationRequired(r) && _sessions.current?.epoch == s.epoch) {
      await refreshAccess();
      return false;
    }
    if (!r.ok || _sessions.current?.epoch != s.epoch) return false; // late response for a previous owner is dropped
    final paused = await _accessPaused(s.ownerId);
    await db.transaction(() async {
      for (final rec in recordsFromSnapshot(r.data as Json, s.ownerId)) {
        await _merge(s.ownerId, rec);
      }
      await adoptAccess(s.ownerId, (r.data as Json)['profile'] as Json);
    });
    if (paused) kick(); // the account may take its waiting changes again
    return true;
  }

  // ---------------------------------------------------------------- explicit resolution

  Future<Cmd?> command(String operationId) => (db.select(db.commands)..where((c) => c.operationId.equals(operationId))).getSingleOrNull();

  /// The open conflict/rejected command for a record, if any.
  Future<Cmd?> issueFor(String owner, String kind, String id) async =>
      (await _openFor(owner, kind, id)).where((c) => c.state != 'pending').firstOrNull;

  Future<Set<String>> _supersede(String owner, Cmd root, {bool sameTarget = true}) async {
    final all = await commands(owner);
    final gone = <String>{root.operationId};
    if (sameTarget) gone.addAll(all.where((c) => c.targetKind == root.targetKind && c.targetId == root.targetId).map((c) => c.operationId));
    await (db.update(db.commands)..where((c) => c.operationId.isIn(gone))).write(const CommandsCompanion(state: Value('superseded')));
    return gone;
  }

  /// "Use the account's version": the server body becomes current, the local version is retained as the
  /// alternative. No record is created or removed, so a set conflict can never change the set count.
  Future<void> resolveUseServer(String owner, String operationId) async {
    final cmd = await command(operationId);
    if (cmd == null || cmd.ownerId != owner) return;
    await db.transaction(() async {
      await _supersede(owner, cmd);
      final rec = await get(owner, cmd.targetKind, cmd.targetId);
      final ack = cmd.ack == null ? null : jsonDecode(cmd.ack!) as Json;
      final server = recordsFromAck(cmd.kind, ack?['data'], owner);
      if (rec != null) {
        await (db.update(db.records)..where((x) => x.ownerId.equals(owner) & x.kind.equals(cmd.targetKind) & x.id.equals(cmd.targetId)))
            .write(RecordsCompanion(alternativeBody: Value(rec.body), syncState: const Value('synced'), serverBody: const Value(null)));
      }
      for (final s in server) {
        // Other records this change touched locally (for example both plans of a primary conflict) keep their local version too.
        await _merge(owner, s, force: s.kind == cmd.targetKind && s.id == cmd.targetId, keepAlternative: true);
      }
    });
    kick();
    unawaited(pull());
  }

  /// "Keep mine": supersedes the conflicting command and issues ONE new command (new operation ID) built by
  /// `rebuild` from the current local record against the account's revision. The account's version is retained.
  Future<Receipt?> resolveKeepLocal(String owner, String operationId, {required String kind, String method = 'POST', required String path, required Json payload}) async {
    final cmd = await command(operationId);
    if (cmd == null || cmd.ownerId != owner) return null;
    final next = newId();
    await db.transaction(() async {
      final gone = await _supersede(owner, cmd);
      final rec = await get(owner, cmd.targetKind, cmd.targetId);
      await (db.update(db.records)..where((x) => x.ownerId.equals(owner) & x.kind.equals(cmd.targetKind) & x.id.equals(cmd.targetId)))
          .write(RecordsCompanion(alternativeBody: Value(rec?.serverBody), serverBody: const Value(null), syncState: const Value('pending')));
      // Commands on other records that waited for the superseded ones now wait for the replacement.
      for (final c in await commands(owner)) {
        final deps = (jsonDecode(c.dependsOn) as List).cast<String>();
        if (deps.any(gone.contains)) {
          await (db.update(db.commands)..where((x) => x.seq.equals(c.seq))).write(CommandsCompanion(dependsOn: Value(jsonEncode([...deps, next]))));
        }
      }
    });
    return submit(owner, kind: kind, method: method, path: path, payload: payload, targetKind: cmd.targetKind, targetId: cmd.targetId, operationId: next);
  }

  /// Drops a rejected change the user chose not to keep. A record the account never accepted is removed
  /// only by this explicit action; an accepted record is restored from the account on the next pull.
  Future<void> discard(String owner, String operationId) async {
    final cmd = await command(operationId);
    if (cmd == null || cmd.ownerId != owner) return;
    await db.transaction(() async {
      await _supersede(owner, cmd);
      final rec = await get(owner, cmd.targetKind, cmd.targetId);
      if (rec == null) return;
      if (rec.revision == 0) {
        await deleteLocal(owner, cmd.targetKind, cmd.targetId);
        // Children of a parent the account never accepted go with it, by this same explicit choice.
        final children = await (db.select(db.records)..where((r) => r.ownerId.equals(owner) & r.parentId.equals(cmd.targetId))).get();
        for (final child in children) {
          await (db.update(db.commands)..where((c) => c.ownerId.equals(owner) & c.targetKind.equals(child.kind) & c.targetId.equals(child.id) & c.state.isNotValue('accepted')))
              .write(const CommandsCompanion(state: Value('superseded')));
          await deleteLocal(owner, child.kind, child.id);
        }
        await deleteLocal(owner, Kinds.runtime, cmd.targetId);
      } else {
        await (db.update(db.records)..where((x) => x.ownerId.equals(owner) & x.kind.equals(cmd.targetKind) & x.id.equals(cmd.targetId)))
            .write(RecordsCompanion(alternativeBody: Value(rec.body), syncState: const Value('synced'), serverBody: const Value(null)));
      }
    });
    kick();
    unawaited(pull());
  }

  /// Number of records this owner has saved on the phone that the account has not confirmed yet.
  Future<int> unsyncedCount(String owner) async => (await commands(owner)).length;

  /// Explicit account erasure only: removes this owner's local data after the server confirmed deletion.
  Future<void> eraseOwner(String owner) => db.transaction(() async {
        await (db.delete(db.records)..where((r) => r.ownerId.equals(owner))).go();
        await (db.delete(db.commands)..where((c) => c.ownerId.equals(owner))).go();
        await (db.delete(db.trackEntries)..where((r) => r.ownerId.equals(owner))).go();
      });
}
