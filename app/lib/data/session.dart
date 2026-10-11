import 'dart:convert';

import 'package:dio/dio.dart';

import 'models.dart';

/// One signed-in owner. `epoch` changes on every sign-in and sign-out, so any delayed response or
/// acknowledgement captured under an older epoch is recognised and dropped.
class Session {
  const Session({required this.ownerId, required this.email, required this.accessToken, required this.refreshToken, required this.epoch});
  final String ownerId, email, accessToken, refreshToken;
  final int epoch;

  Json toJson() => {'ownerId': ownerId, 'email': email, 'accessToken': accessToken, 'refreshToken': refreshToken};
}

/// Credentials live in platform secure storage, never in the database or assets.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MemorySecretStore implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Holds the current session and notifies listeners. Signing out is non-destructive: it only removes
/// credentials and bumps the epoch. That owner's local records and pending commands stay on the phone,
/// invisible to any other account, and resume syncing when the same owner signs in again.
class SessionManager {
  SessionManager(this._store);
  static const _key = 'gohard.rebuild.session';
  final SecretStore _store;
  final _listeners = <void Function()>[];
  Session? _current;
  int _epoch = 0;
  String? notice;

  Session? get current => _current;
  int get epoch => _epoch;
  void addListener(void Function() l) => _listeners.add(l);
  void removeListener(void Function() l) => _listeners.remove(l);
  void _notify() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  Future<void> restore() async {
    final raw = await _store.read(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Json;
      _current = Session(ownerId: j['ownerId'] as String, email: j['email'] as String, accessToken: j['accessToken'] as String,
          refreshToken: j['refreshToken'] as String, epoch: ++_epoch);
    } on Object {
      await _store.delete(_key); // unreadable credentials are dropped; owned data is untouched
    }
  }

  /// Called with a register/login response body.
  Future<Session> signIn(Json auth) async {
    final profile = auth['profile'] as Json;
    final s = Session(ownerId: profile['userId'] as String, email: profile['email'] as String,
        accessToken: auth['accessToken'] as String, refreshToken: auth['refreshToken'] as String, epoch: ++_epoch);
    _current = s;
    notice = null;
    await _store.write(_key, jsonEncode(s.toJson()));
    _notify();
    return s;
  }

  /// Token rotation for the SAME owner keeps the epoch: nothing about ownership changed.
  Future<void> rotated(Session from, Json auth) async {
    if (_current?.epoch != from.epoch) return; // the account changed while the refresh was in flight
    _current = Session(ownerId: from.ownerId, email: from.email, accessToken: auth['accessToken'] as String,
        refreshToken: auth['refreshToken'] as String, epoch: from.epoch);
    await _store.write(_key, jsonEncode(_current!.toJson()));
  }

  Future<void> signOut({String? reason}) async {
    _current = null;
    _epoch++;
    notice = reason;
    await _store.delete(_key);
    _notify();
  }
}

class ApiResponse {
  const ApiResponse(this.status, this.data);
  final int status;
  final dynamic data;
  bool get ok => status >= 200 && status < 300;

  /// A command acknowledgement can arrive with 200, 409 or 422; what matters is the body.
  Json? get ack => data is Map && (data as Map)['status'] is String && (data as Map).containsKey('operationId') ? data as Json : null;
}

/// The request did not produce an HTTP response (offline, DNS, timeout). Always retryable.
class TransportFailure implements Exception {
  const TransportFailure(this.message);
  final String message;
  @override
  String toString() => 'TransportFailure($message)';
}

abstract interface class Transport {
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer});
}

class DioTransport implements Transport {
  DioTransport(String apiBase)
      : _dio = Dio(BaseOptions(
          baseUrl: '$apiBase/api/v1',
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          validateStatus: (_) => true, // HTTP statuses are data; only transport problems throw
          contentType: 'application/json',
        ));
  final Dio _dio;

  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer}) async {
    try {
      final r = await _dio.request<dynamic>(path,
          data: data, options: Options(method: method, headers: {if (bearer != null) 'Authorization': 'Bearer $bearer'}));
      return ApiResponse(r.statusCode ?? 0, r.data);
    } on DioException catch (e) {
      throw TransportFailure(e.type.name);
    }
  }
}

/// Adds the owner's token, and rotates it once when the server says it expired.
class Api {
  Api(this._transport, this._sessions);
  final Transport _transport;
  final SessionManager _sessions;
  Future<bool>? _refreshing;

  Future<ApiResponse> send(String method, String path, {Object? data, bool auth = true}) async {
    final s = _sessions.current;
    if (!auth || s == null) return _transport.send(method, path, data: data);
    var r = await _transport.send(method, path, data: data, bearer: s.accessToken);
    if (r.status != 401) return r;
    if (!await (_refreshing ??= _refresh(s).whenComplete(() => _refreshing = null))) return r;
    final next = _sessions.current;
    if (next == null || next.epoch != s.epoch) return r;
    return _transport.send(method, path, data: data, bearer: next.accessToken);
  }

  Future<bool> _refresh(Session s) async {
    final r = await _transport.send('POST', '/auth/refresh', data: {'refreshToken': s.refreshToken});
    if (r.ok) {
      await _sessions.rotated(s, r.data as Json);
      return _sessions.current?.epoch == s.epoch;
    }
    // Expired sign-in pauses protected sync. It never deletes entered training, food or pending work.
    if (r.status == 401 && _sessions.current?.epoch == s.epoch) {
      await _sessions.signOut(reason: 'Your sign-in expired. Sign in again to keep syncing; everything saved on this phone is still here.');
    }
    return false;
  }
}
