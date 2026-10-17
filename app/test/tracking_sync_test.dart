import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/compatibility.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/nutrition/water.dart';

import 'support.dart';

/// Water / Carbs / Fat visibility on the account (docs/FOOD_DATA.md › Water › What is shown): each phone is a real
/// Drift file, its own platform store and the app's own providers, all talking to one fake account authority.
class _Phone {
  _Phone(this.server);
  final FakeServer server;
  final store = TestStore();
  final sessions = SessionManager(MemorySecretStore());
  final prefs = MemorySecretStore(); // the phone's platform store: survives a restart
  late AppDb db;
  late ProviderContainer c;

  Future<void> open() async {
    db = store.open();
    final tracking = TrackingPrefsStore(prefs);
    await tracking.restore();
    c = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db), sessionsProvider.overrideWithValue(sessions), transportProvider.overrideWithValue(server),
      trackingPrefsStoreProvider.overrideWithValue(tracking),
    ]);
    c.listen(displayMigrationProvider, (_, _) {}); // what the shell keeps alive
    c.listen(profileProvider, (_, _) {});
    await check();
  }

  Future<void> check() => c.read(compatibilityProvider.notifier).check();

  Future<void> signIn(String owner) async {
    await sessions.signIn(authFor(owner));
    await settle();
    await c.read(syncProvider).pull();
    await settle();
  }

  /// Lets the profile stream deliver what was just written, and any upload it triggers be queued.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> sync() async {
    await c.read(syncProvider).flush();
    await settle();
    await c.read(syncProvider).pull();
    await settle();
  }

  NutritionDisplay get shown => c.read(rawNutritionDisplayProvider);

  Future<void> choose(NutritionDisplay d) async {
    await setNutritionDisplay(c.read, d);
    await settle();
  }

  Future<void> restart() async {
    c.dispose();
    await db.close();
    await open();
    await settle();
  }

  Future<void> dispose() async {
    c.dispose();
    await db.close();
    store.dispose();
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true; // two phones, two files: on purpose
  late FakeServer server;
  final phones = <_Phone>[];
  Future<_Phone> phone() async {
    final p = _Phone(server);
    await p.open();
    phones.add(p);
    return p;
  }

  List<Json> profilePuts() => [for (final c in server.calls) if (c.method == 'PUT' && c.path == '/me') jsonDecode(c.body) as Json];

  setUp(() {
    server = FakeServer()
      ..profile = {...authFor('one')['profile'] as Json, 'waterGoalMl': 2000}
      ..capabilities = {'contractVersion': 1, 'minimumClientContract': 1, 'capabilities': ['profile.nutrition-goals', 'water.entries', 'profile.tracking-display']};
  });
  tearDown(() async {
    for (final p in phones) {
      await p.dispose();
    }
    phones.clear();
  });

  test('two phones on one account converge; a fresh phone sends no defaults; hiding keeps the goal', () async {
    final a = await phone();
    await a.signIn('one');
    expect(a.shown, const NutritionDisplay(), reason: 'nothing chosen anywhere: the defaults');
    expect(profilePuts(), isEmpty, reason: 'a fresh phone never writes its defaults to the account');

    await a.choose(const NutritionDisplay(water: true, carbs: false));
    expect(a.shown, const NutritionDisplay(water: true, carbs: false), reason: 'applied at once, before any answer');
    await a.sync();
    expect((server.profile['showWater'], server.profile['showCarbs'], server.profile['showFat']), (true, false, true));

    final b = await phone();
    await b.signIn('one');
    expect(b.shown, const NutritionDisplay(water: true, carbs: false), reason: 'the second phone follows the account');

    await b.choose(const NutritionDisplay(water: false, carbs: false, fat: false));
    await b.sync();
    await a.sync();
    expect(a.shown, const NutritionDisplay(water: false, carbs: false, fat: false), reason: 'and back again: both converge');
    expect(server.profile['waterGoalMl'], 2000, reason: 'hiding water never touches its goal');
    expect(profilePuts().where((p) => p['showWater'] == false), isNotEmpty, reason: 'an explicit false is sent, not left out');
  });

  test('a change made offline survives a restart and syncs; arriving account data does not discard it', () async {
    final a = await phone();
    await a.signIn('one');
    server.offline = true;
    await a.choose(const NutritionDisplay(fat: false));
    await a.c.read(syncProvider).flush(); // attempted; kept on the phone
    await a.restart();
    expect(a.shown, const NutritionDisplay(fat: false), reason: 'the queued edit is the phone\'s view after a restart');

    server.offline = false;
    await a.c.read(syncProvider).pull(); // the account's older profile arrives first
    await a.settle();
    expect(a.shown, const NutritionDisplay(fat: false), reason: 'a pending edit is never replaced by remote data');
    await a.sync();
    expect(server.profile['showFat'], false);
    expect(await a.c.read(syncProvider).commands('one'), isEmpty);
  });

  test('a stale offline edit meets a newer account revision: a conflict to review, nothing overwritten', () async {
    final a = await phone();
    await a.signIn('one');
    server.offline = true;
    await a.choose(const NutritionDisplay(carbs: false));
    server
      ..offline = false
      ..profile = {...server.profile, 'showCarbs': true, 'revision': 2}; // another phone got there first
    await a.c.read(syncProvider).flush();
    await a.settle();
    expect(server.profile['showCarbs'], true, reason: 'the revision check stops a silent overwrite');
    expect((await a.c.read(syncProvider).commands('one')).single.state, 'conflict', reason: 'left for the existing review, not dropped');
    expect(a.shown.carbs, false, reason: 'the person\'s edit is still there to keep or discard');
  });

  test('a choice made before the account could keep it goes up once; an account that has one keeps it', () async {
    server.capabilities = {'contractVersion': 1, 'minimumClientContract': 1, 'capabilities': ['profile.nutrition-goals', 'water.entries']};
    final a = await phone();
    await a.signIn('one');
    await a.choose(const NutritionDisplay(water: true, fat: false));
    expect(profilePuts(), isEmpty, reason: 'an older server is never sent fields it did not declare');
    expect(a.shown, const NutritionDisplay(water: true, fat: false), reason: 'kept on this phone meanwhile');

    // The server is upgraded: the earlier choice is the account's now, sent once.
    server.capabilities = {...server.capabilities, 'capabilities': [...server.capabilities['capabilities'] as List, 'profile.tracking-display']};
    await a.check();
    await a.settle();
    await a.sync();
    expect(profilePuts(), hasLength(1));
    expect((server.profile['showWater'], server.profile['showCarbs'], server.profile['showFat']), (true, true, false));

    // A phone with its own older choice (made here before) meets an account that already has one: the account wins.
    final b = await phone();
    await b.c.read(trackingPrefsStoreProvider).save(); // nothing yet
    b.c.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(carbs: false));
    await b.signIn('one');
    await b.sync();
    expect(b.shown, const NutritionDisplay(water: true, fat: false), reason: 'the stored account choice is not replaced');
    expect(profilePuts(), hasLength(1), reason: 'nothing was sent from the second phone');
  });

  test('other profile changes leave the choice out and keep it; another account has its own', () async {
    final a = await phone();
    await a.signIn('one');
    await a.choose(const NutritionDisplay(water: true, carbs: false, fat: false));
    await a.sync();

    final current = a.c.read(profileProvider).value!;
    await a.c.read(profileRepositoryProvider).setGoals(current, calorieGoal: 2200, proteinGoal: null);
    await a.sync();
    expect(profilePuts().last.containsKey('showCarbs'), isFalse, reason: 'a goals change does not carry the display choice');
    expect((server.profile['showCarbs'], server.profile['calorieGoal']), (false, 2200), reason: 'left out = kept');
    expect(a.shown, const NutritionDisplay(water: true, carbs: false, fat: false));

    // Another account on the same phone: its own profile, nothing of the first one's choice.
    server.profile = {...authFor('two')['profile'] as Json};
    await a.signIn('two');
    expect(a.shown, const NutritionDisplay(), reason: 'one account\'s choice is never another\'s');
    expect(a.c.read(trackingPrefsProvider).owners.keys, ['one']);
  });
}
