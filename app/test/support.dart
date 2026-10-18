import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:gohard_rebuild/core/clock.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';

final Json fixture = jsonDecode(File('../contracts/contract_fixture.json').readAsStringSync()) as Json;

class FakeClock implements AppClock {
  FakeClock(this.now);
  DateTime now;
  @override
  DateTime utcNow() => now;
  void advance(Duration d) => now = now.add(d);
}

/// A real on-disk Drift database that tests can close and reopen, like a process restart.
class TestStore {
  TestStore() : dir = Directory.systemTemp.createTempSync('gohard_test_');
  final Directory dir;
  File get file => File('${dir.path}/app.sqlite');
  AppDb open() => AppDb(NativeDatabase(file));
  void dispose() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold the file briefly; the temp folder is disposable either way.
    }
  }
}

Json authFor(String owner) => {
      'accessToken': 'access-$owner', 'refreshToken': 'refresh-$owner',
      'profile': {'userId': owner, 'email': '$owner@example.test', 'displayName': owner, 'appearance': 'dark', 'loadUnit': 'kg', 'revision': 1},
    };

/// A small in-memory account authority with the real contract's semantics for sets, food and finish:
/// terminal operation replay, payload mismatch, revision conflicts and set-dependency checks.
class FakeServer implements Transport {
  final calls = <({String method, String path, String body, String? bearer})>[];
  final operations = <String, (String body, ApiResponse response)>{};
  final sets = <String, Json>{}, food = <String, Json>{}, workouts = <String, Json>{}, savedFoods = <String, Json>{}, water = <String, Json>{};

  /// The account's profile as this authority holds it. A field a request leaves out is kept, as on the real server.
  Json profile = {...authFor('owner-from-server')['profile'] as Json};

  /// Answers for the read-only endpoints: food lookups by path, and what the server says it supports.
  final lookups = <String, ApiResponse>{};
  Json capabilities = {'contractVersion': 1, 'minimumClientContract': 1, 'capabilities': ['food.search', 'food.barcode', 'food.saved', 'profile.nutrition-goals', 'water.entries']};
  bool offline = false, loseNextResponse = false;
  Completer<void>? hold;

  List<({String method, String path, String body, String? bearer})> callsTo(String fragment) => calls.where((c) => c.path.contains(fragment)).toList();

  ApiResponse _ack(String op, String status, int revision, Json? data, [String? code]) =>
      ApiResponse(status == 'accepted' ? 200 : status == 'conflict' ? 409 : 422, {'operationId': op, 'status': status, 'revision': revision, 'data': data, 'code': code});

  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer, Map<String, String>? headers}) async {
    final body = jsonEncode(data);
    calls.add((method: method, path: path, body: body, bearer: bearer));
    if (offline) throw const TransportFailure('offline');
    if (hold != null) await hold!.future;
    final response = _handle(method, path, data is Map ? data as Json : null, body);
    if (loseNextResponse) {
      loseNextResponse = false;
      throw const TransportFailure('response lost after commit');
    }
    return response;
  }

  ApiResponse _handle(String method, String path, Json? d, String body) {
    if (path == '/sync/snapshot') {
      return ApiResponse(200, {
        'profile': profile, 'context': {'contextRevision': 1, 'primaryPlanId': null, 'plans': []},
        'workouts': [for (final w in workouts.values) {...w, 'exercises': [for (final e in w['exercises'] as List) {...e as Json, 'sets': [for (final s in sets.values) if (s['exerciseId'] == e['id']) s]}]}],
        'foodEntries': food.values.toList(), 'runs': [], 'bodyMetrics': [], 'proposals': [], 'catalog': [], 'savedFoods': savedFoods.values.toList(), 'waterEntries': water.values.toList(),
      });
    }
    if (path == '/capabilities') return ApiResponse(200, capabilities);
    if (path.startsWith('/foods/')) return lookups[path] ?? const ApiResponse(404, {'code': 'NOT_FOUND'});
    final op = d?['operationId'] as String?;
    if (op == null) return const ApiResponse(400, null);
    final prior = operations[op];
    if (prior != null) return prior.$1 == body ? prior.$2 : _ack(op, 'rejected', 0, null, 'OPERATION_PAYLOAD_MISMATCH');
    final response = _execute(method, path.split('/').where((s) => s.isNotEmpty).toList(), d!, op);
    if (response.status != 404) operations[op] = (body, response);
    return response;
  }

  ApiResponse _revisioned(Map<String, Json> table, String id, Json d, String op, void Function(Json row) change) {
    final row = table[id];
    if (row == null) return const ApiResponse(404, null);
    if (row['revision'] != d['expectedRevision']) return _ack(op, 'conflict', row['revision'] as int, row, 'REVISION_CONFLICT');
    change(row);
    row['revision'] = (row['revision'] as int) + 1;
    return _ack(op, 'accepted', row['revision'] as int, Map.of(row));
  }

  ApiResponse _execute(String method, List<String> p, Json d, String op) {
    switch (p) {
      case ['workouts']:
        final w = {...d, 'id': d['workoutId'], 'revision': 1, 'finishedAtUtc': null, 'isDeleted': false, 'planId': null}..remove('operationId');
        workouts[w['id'] as String] = w;
        return _ack(op, 'accepted', 1, {...w, 'exercises': [for (final e in w['exercises'] as List) {...e as Json, 'sets': []}]});
      case ['exercises', final exerciseId, 'sets']:
        final workoutId = workouts.values.firstWhere((w) => (w['exercises'] as List).any((e) => (e as Json)['id'] == exerciseId))['id'];
        final s = {'id': d['setId'], 'exerciseId': exerciseId, 'workoutId': workoutId, 'reps': d['reps'], 'loadKg': d['loadKg'], 'durationSeconds': d['durationSeconds'], 'performedAtUtc': d['performedAtUtc'], 'revision': 1, 'isDeleted': false};
        sets[s['id'] as String] = s;
        return _ack(op, 'accepted', 1, Map.of(s));
      case ['sets', final id] when method == 'PUT':
        return _revisioned(sets, id, d, op, (r) => r.addAll({'reps': d['reps'], 'loadKg': d['loadKg'], 'durationSeconds': d['durationSeconds']}));
      case ['sets', final id, 'delete']:
        return _revisioned(sets, id, d, op, (r) => r['isDeleted'] = true);
      case ['workouts', final id, 'finish']:
        final w = workouts[id];
        if (w == null) return const ApiResponse(404, null);
        final live = {for (final s in sets.values) if (s['workoutId'] == id && s['isDeleted'] != true) '${s['id']}@${s['revision']}'};
        final acked = {for (final s in d['acknowledgedSets'] as List) '${(s as Json)['id']}@${s['revision']}'};
        if (live.length != acked.length || !live.containsAll(acked)) return _ack(op, 'conflict', w['revision'] as int, null, 'SET_DEPENDENCY_MISMATCH');
        w.addAll({'finishedAtUtc': d['finishedAtUtc'], 'activeDurationSeconds': d['activeDurationSeconds'], 'outcome': live.isEmpty ? 'no_data' : 'manual_recorded', 'performedSets': live.length, 'revision': 2});
        return _ack(op, 'accepted', 2, {...w, 'exercises': [for (final e in w['exercises'] as List) {...e as Json, 'sets': [for (final s in sets.values) if (s['exerciseId'] == e['id']) s]}]});
      case ['food-entries']:
        final f = {...d, 'id': d['entryId'], 'revision': 1, 'isDeleted': false}..remove('operationId')..remove('entryId');
        food[f['id'] as String] = f;
        return _ack(op, 'accepted', 1, Map.of(f));
      case ['food-entries', final id] when method == 'PUT':
        return _revisioned(food, id, d, op, (r) => r.addAll({for (final k in ['dayKey', 'meal', 'name', 'amountDescription', 'macros', 'source', 'provenance']) k: d[k]}));
      case ['food-entries', final id, 'delete']:
        return _revisioned(food, id, d, op, (r) => r['isDeleted'] = true);
      case ['water-entries']:
        if (water.containsKey(d['entryId'])) return _ack(op, 'conflict', 1, null, 'DUPLICATE_ID');
        final w = {'id': d['entryId'], 'dayKey': d['dayKey'], 'volumeMl': d['volumeMl'], 'revision': 1, 'isDeleted': false};
        water[w['id'] as String] = w;
        return _ack(op, 'accepted', 1, Map.of(w));
      case ['water-entries', final id] when method == 'PUT':
        return _revisioned(water, id, d, op, (r) => r.addAll({'dayKey': d['dayKey'], 'volumeMl': d['volumeMl']}));
      case ['water-entries', final id, 'delete']:
        return _revisioned(water, id, d, op, (r) => r['isDeleted'] = true);
      case ['saved-foods', final id] when method == 'PUT':
        final row = savedFoods[id];
        if ((row?['revision'] ?? 0) != d['expectedRevision']) return row == null ? const ApiResponse(404, null) : _ack(op, 'conflict', row['revision'] as int, row, 'REVISION_CONFLICT');
        final next = {'id': id, 'item': d['item'], 'isFavourite': d['isFavourite'], 'revision': ((row?['revision'] as int?) ?? 0) + 1, 'isDeleted': false};
        savedFoods[id] = next;
        return _ack(op, 'accepted', next['revision'] as int, Map.of(next));
      case ['saved-foods', final id, 'delete']:
        return _revisioned(savedFoods, id, d, op, (r) => r['isDeleted'] = true);
      case ['me'] when method == 'PUT':
        if (profile['revision'] != d['expectedRevision']) return _ack(op, 'conflict', profile['revision'] as int, profile, 'REVISION_CONFLICT');
        profile = {...profile, ...d, 'revision': (profile['revision'] as int) + 1}..remove('operationId')..remove('expectedRevision');
        return _ack(op, 'accepted', profile['revision'] as int, Map.of(profile));
      default:
        return _ack(op, 'accepted', 1, null);
    }
  }
}

/// Everything the data layer needs, wired like the app but with a real file database and the fake authority.
class Harness {
  Harness({TestStore? store, FakeServer? server, SessionManager? sessions, DateTime? now})
      : store = store ?? TestStore(), server = server ?? FakeServer(), sessions = sessions ?? SessionManager(MemorySecretStore()),
        clock = FakeClock(now ?? DateTime.utc(2026, 10, 9, 18)) {
    db = this.store.open();
    sync = SyncEngine(db, Api(this.server, this.sessions), this.sessions);
  }
  final TestStore store;
  final FakeServer server;
  final SessionManager sessions;
  final FakeClock clock;
  late AppDb db;
  late SyncEngine sync;

  Future<String> signIn(String owner) async => (await sessions.signIn(authFor(owner))).ownerId;

  /// Simulates process death and relaunch: same file, same credentials store, fresh objects.
  Future<void> restart() async {
    sync.dispose();
    await sync.idle();
    await db.close();
    db = store.open();
    sync = SyncEngine(db, Api(server, sessions), sessions);
  }

  Future<void> dispose() async {
    sync.dispose();
    await sync.idle();
    await db.close();
    store.dispose();
  }

  Future<List<Json>> bodies(String owner, String kind, {String? parentId}) async =>
      [for (final r in await sync.list(owner, kind, parentId: parentId)) jsonDecode(r.body) as Json];
}
