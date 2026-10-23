import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/me/account_repository.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';

import 'support.dart';

/// docs/AUTHENTICATION_EMAIL.md › Required verification, on the phone: the server's word on access is kept per account,
/// a refusal pauses the outbox without touching it, and verification sends the waiting changes once.

/// The account authority, refusing data while the account must verify, as the real API does (403
/// EMAIL_VERIFICATION_REQUIRED); `/me`, registration and capabilities stay open.
class _Gated extends FakeServer {
  bool required = true;
  String? dueAtUtc = '2026-10-01T12:00:00Z'; // an existing account whose grace period has ended

  Json get _profile => {...profile, 'emailVerified': !required, 'verificationRequired': required, 'verificationDueAtUtc': required ? dueAtUtc : null};

  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer}) async {
    if (path == '/me' || path == '/auth/register' || (required && path != '/capabilities')) {
      calls.add((method: method, path: path, body: jsonEncode(data), bearer: bearer));
      if (offline) throw const TransportFailure('offline');
      if (path == '/me') return ApiResponse(200, _profile);
      if (path == '/auth/register') return ApiResponse(200, {...authFor('new-one'), 'profile': {...authFor('new-one')['profile'] as Json, 'emailVerified': false, 'verificationRequired': true, 'verificationDueAtUtc': null}});
      return const ApiResponse(403, {'code': 'EMAIL_VERIFICATION_REQUIRED'});
    }
    final r = await super.send(method, path, data: data, bearer: bearer);
    if (path == '/sync/snapshot' && r.ok) (r.data as Json)['profile'] = _profile;
    return r;
  }
}

Future<AccountAccess?> _access(Harness h, String owner) async {
  final r = await h.sync.get(owner, Kinds.accountAccess, owner);
  return r == null ? null : AccountAccess(jsonDecode(r.body) as Json);
}

void main() {
  test('a refusal pauses the outbox untouched; restart and lost answers keep it; verifying sends each change once', () async {
    final server = _Gated();
    final h = Harness(server: server);
    addTearDown(h.dispose);
    final owner = await h.signIn('one');

    // An entry saved while the account may not upload: kept, its command pending and not counted as a failure.
    await FoodRepository(h.sync, owner).save(FoodDraft(dayKey: '2026-10-21', meal: 'Breakfast', name: 'Oats', amount: '60 g', calories: 230));
    await h.sync.flush();
    var cmd = (await h.sync.commands(owner)).single;
    expect((cmd.state, cmd.attempts, cmd.lastError), ('pending', 0, null));
    expect((await _access(h, owner))!.required, isTrue, reason: 'the refusal was explained by /me');
    expect((await _access(h, owner))!.mustVerifyFirst, isFalse, reason: 'an existing account keeps the app, paused');
    expect(server.callsTo('/food-entries'), hasLength(1));
    await h.sync.flush();
    expect(server.callsTo('/food-entries'), hasLength(1), reason: 'paused: nothing is retried against the refusal');

    // A restart keeps the state and the entry.
    await h.restart();
    expect((await _access(h, owner))!.required, isTrue);
    expect((await h.bodies(owner, Kinds.food)).single['name'], 'Oats');

    // No answer changes nothing.
    server.offline = true;
    expect(await h.sync.refreshAccess(), isFalse);
    expect(await h.sync.pull(), isFalse);
    expect((await _access(h, owner))!.required, isTrue);

    // Verified (on another phone): the next pull recognizes it and the waiting change goes, once, with its id.
    server
      ..offline = false
      ..required = false;
    expect(await h.sync.pull(), isTrue);
    await h.sync.flush();
    cmd = (await h.sync.commands(owner, states: const ['pending', 'accepted'])).single;
    expect(cmd.state, 'accepted');
    expect(server.food.values.single['name'], 'Oats');
    expect(server.callsTo('/food-entries').map((c) => jsonDecode(c.body)['operationId']).toSet(), {cmd.operationId});
    expect((await _access(h, owner))!.required, isFalse);

    // An interrupted check never downgrades a verified account.
    server.offline = true;
    expect(await h.sync.pull(), isFalse);
    expect((await _access(h, owner))!.required, isFalse);
  });

  test('a new account\'s access is kept before its session starts, and only for that account', () async {
    final server = _Gated();
    final h = Harness(server: server);
    addTearDown(h.dispose);
    AccountAccess? seenAtSignIn;
    h.sessions.addListener(() async => seenAtSignIn ??= h.sessions.current == null ? null : await _access(h, h.sessions.current!.ownerId));
    String? created;
    await AuthRepository(Api(server, h.sessions), h.sessions, h.sync).register('new-one@example.test', 'a long enough passphrase', 'New', onCreated: (o) => created = o);
    await Future<void>.delayed(Duration.zero);
    expect(created, 'new-one');
    expect(seenAtSignIn?.mustVerifyFirst, isTrue, reason: 'the gate is known the moment the account opens: no Today first');
    expect(await _access(h, 'one'), isNull, reason: 'another account on this phone is untouched');
  });
}
