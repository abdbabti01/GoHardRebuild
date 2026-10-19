import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';

/// Signing in again only when the account really requires it (docs/ARCHITECTURE.md › Sessions). The server here keeps
/// tokens the way the API does (AuthService): an access token is valid until it expires, and a refresh token works
/// once: refreshing revokes it and issues a new pair. Responses can be held back to set their order exactly.
class TokenServer implements Transport {
  final valid = <String>{'A1'};
  final refresh = <String, bool>{'R1': true}; // token -> still usable
  int issued = 1, refreshCalls = 0;
  final held = <String, Completer<void>>{};
  final requests = <({String path, String? bearer})>[];

  /// Responses for [path] wait until [release].
  void hold(String path) => held[path] = Completer<void>();
  void release(String path) => held.remove(path)!.complete();
  void expireAll() => valid.clear();

  /// What the server answers to a refresh: normally the rotation; a test may replace it (a 503, a lost response…).
  ApiResponse? Function()? refreshOverride;

  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer}) async {
    requests.add((path: path, bearer: bearer));
    // The status is decided when the request ARRIVES (as on a real server); only its delivery is held back.
    final ApiResponse answer;
    if (path == '/auth/refresh') {
      refreshCalls++;
      final token = (data as Json)['refreshToken'] as String;
      final override = refreshOverride?.call();
      if (override != null) {
        answer = override;
      } else if (refresh[token] != true) {
        answer = const ApiResponse(401, {'code': 'INVALID_REFRESH_TOKEN'});
      } else {
        refresh[token] = false;
        issued++;
        valid.add('A$issued');
        refresh['R$issued'] = true;
        answer = ApiResponse(200, {'accessToken': 'A$issued', 'refreshToken': 'R$issued', 'profile': {'userId': 'u1', 'email': 'u1@example.test'}});
      }
    } else {
      answer = valid.contains(bearer) ? ApiResponse(200, {'path': path}) : const ApiResponse(401, null);
    }
    final wait = held[path];
    if (wait != null) await wait.future;
    if (answer.status == -1) throw const TransportFailure('connectionError');
    return answer;
  }
}

Future<(SessionManager, Api, TokenServer, MemorySecretStore)> _signedIn() async {
  final store = MemorySecretStore();
  final sessions = SessionManager(store);
  await sessions.signIn({'accessToken': 'A1', 'refreshToken': 'R1', 'profile': {'userId': 'u1', 'email': 'u1@example.test'}});
  final server = TokenServer();
  return (sessions, Api(server, sessions), server, store);
}

/// A secret store whose writes can fail, as the iOS keychain does for "when unlocked" items while the phone is locked.
class FlakyStore extends MemorySecretStore {
  bool failWrites = false;
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('errSecInteractionNotAllowed');
    await super.write(key, value);
  }
}

void main() {
  test('an expired access token refreshes silently and the request is repeated with the new one', () async {
    final (sessions, api, server, store) = await _signedIn();
    server.expireAll();
    final r = await api.send('GET', '/sync/snapshot');
    expect(r.status, 200);
    expect((sessions.current!.accessToken, sessions.current!.refreshToken), ('A2', 'R2'));
    expect(sessions.notice, isNull);
    expect(await store.read('gohard.rebuild.session'), contains('R2'), reason: 'the rotated pair is what a restart will use');
  });

  test('THE INCIDENT: a 401 that arrives after another request already refreshed must not sign out', () async {
    final (sessions, api, server, _) = await _signedIn();
    server.expireAll();
    // A (a sync push) is sent with the expired token and its 401 is slow to arrive.
    server.hold('/a');
    final a = api.send('GET', '/a');
    await pumpEventQueue();
    // B (the weather, a pull) gets its 401 at once, refreshes R1 → R2, and succeeds.
    expect((await api.send('GET', '/b')).status, 200);
    expect(sessions.current!.refreshToken, 'R2');
    // Now A's 401 arrives. It must use the new token, not refresh again with the revoked R1.
    server.release('/a');
    final ra = await a;
    expect(sessions.current, isNotNull, reason: 'still signed in');
    expect(sessions.notice, isNull, reason: 'no "Your sign-in expired" notice');
    expect(ra.status, 200, reason: 'A is repeated with the rotated access token');
    expect(server.refreshCalls, 1, reason: 'one refresh, no second one with the revoked refresh token');
  });

  test('requests that fail together share one refresh', () async {
    final (sessions, api, server, _) = await _signedIn();
    server.expireAll();
    server.hold('/auth/refresh');
    final all = [for (final p in ['/a', '/b', '/c']) api.send('GET', p)];
    await pumpEventQueue();
    server.release('/auth/refresh');
    expect([for (final r in await Future.wait(all)) r.status], [200, 200, 200]);
    expect(server.refreshCalls, 1);
    expect(sessions.notice, isNull);
  });

  test('a delayed 401 for a previous account changes nothing for the account signed in now', () async {
    final (sessions, api, server, _) = await _signedIn();
    server.expireAll();
    server.hold('/a');
    final a = api.send('GET', '/a');
    await pumpEventQueue();
    await sessions.signOut();
    await sessions.signIn({'accessToken': 'B1', 'refreshToken': 'S1', 'profile': {'userId': 'u2', 'email': 'u2@example.test'}});
    server.release('/a');
    expect((await a).status, 401, reason: 'answered as it was; never retried as the new account');
    expect(sessions.current!.ownerId, 'u2');
    expect(sessions.notice, isNull);
    expect(server.refreshCalls, 0, reason: 'nothing refreshed for, or with, another account');
    expect(server.requests.where((r) => r.bearer == 'B1'), isEmpty);
  });

  test('a refresh that cannot reach the server, or meets a server error or rate limit, keeps the session', () async {
    for (final failure in [const ApiResponse(-1, null), const ApiResponse(503, null), const ApiResponse(429, null), const ApiResponse(500, null)]) {
      final (sessions, api, server, store) = await _signedIn();
      server.expireAll();
      server.refreshOverride = () => failure;
      try {
        final r = await api.send('GET', '/sync/snapshot');
        expect(r.status, 401, reason: 'the original answer is returned; nothing is decided');
      } on TransportFailure {
        // offline: the caller retries later
      }
      expect((sessions.current?.refreshToken, sessions.notice), ('R1', null), reason: 'status ${failure.status}: still signed in');
      expect(await store.read('gohard.rebuild.session'), contains('R1'));
      // When the server is back, the same refresh token still works.
      server.refreshOverride = null;
      expect((await api.send('GET', '/sync/snapshot')).status, 200);
    }
  });

  test('a genuinely expired or revoked sign-in still asks to sign in again, keeping what is on the phone', () async {
    final (sessions, api, server, store) = await _signedIn();
    server.expireAll();
    server.refresh['R1'] = false; // revoked (signed out elsewhere, expired after 60 days, account changed)
    final r = await api.send('GET', '/sync/snapshot');
    expect(r.status, 401);
    expect(sessions.current, isNull);
    expect(sessions.notice, contains('Your sign-in expired'));
    expect(await store.read('gohard.rebuild.session'), isNull, reason: 'only the credentials are removed');
  });

  test('if the rotated pair cannot be saved (keychain locked), the session goes on and it is saved at the next chance', () async {
    final store = FlakyStore();
    final sessions = SessionManager(store);
    await sessions.signIn({'accessToken': 'A1', 'refreshToken': 'R1', 'profile': {'userId': 'u1', 'email': 'u1@example.test'}});
    final server = TokenServer();
    final api = Api(server, sessions);
    server.expireAll();
    store.failWrites = true;
    expect((await api.send('GET', '/a')).status, 200, reason: 'the request still succeeds');
    expect(sessions.current!.refreshToken, 'R2');
    store.failWrites = false;
    await sessions.persistIfNeeded(); // on the next foreground (or any later save)
    // A cold start now restores the live pair, not the revoked one.
    final restarted = SessionManager(store);
    await restarted.restore();
    expect(restarted.current!.refreshToken, 'R2');
    server.expireAll();
    expect((await Api(server, restarted).send('GET', '/a')).status, 200);
    expect(restarted.notice, isNull);
  });
}
