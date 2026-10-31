import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/coach/coach_client.dart' show AskProblem, limitProblem;
import 'package:gohard_rebuild/features/plus/entitlement.dart';
import 'package:gohard_rebuild/features/plus/plus_screen.dart';

import 'support.dart';
import 'ui_support.dart';

/// The account's server for GoHard Plus (docs/PLUS_PREVIEW.md), as the API answers it. Records every call.
class PlusServer implements Transport {
  final calls = <String>[];
  bool offline = false, owner = false;
  String tier = 'free';
  int used = 3;

  Json entitlement() => {
        'tier': tier, 'source': owner && tier == 'plus' ? 'preview_override' : 'default', 'preview': true, 'purchasesAvailable': false,
        'limits': tier == 'plus' ? {'savedPlans': null, 'savedMeals': null} : {'savedPlans': 3, 'savedMeals': 10},
        'features': tier == 'plus' ? [Entitlement.progression, Entitlement.trendExplorer] : [],
        'allowance': {'used': used, 'limit': tier == 'plus' ? 300 : 15, 'remaining': (tier == 'plus' ? 300 : 15) - used, 'periodStartUtc': '2026-10-01T00:00:00Z', 'resetsAtUtc': '2026-11-01T00:00:00Z', 'dailyGuard': 40},
        'canManagePreview': owner, 'issuedAtUtc': '2026-10-31T12:00:00Z', 'validForSeconds': 72 * 3600,
        'compare': {'free': {'savedPlans': 3, 'savedMeals': 10, 'monthlyAi': 15}, 'plus': {'savedPlans': null, 'savedMeals': null, 'monthlyAi': 300}},
      };

  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer}) async {
    calls.add('$method $path');
    if (offline) throw const TransportFailure('offline');
    if (path == '/capabilities') return const ApiResponse(200, {'contractVersion': 2, 'minimumClientContract': 1, 'capabilities': [Entitlement.capability]});
    if (path == '/entitlement') return ApiResponse(200, entitlement());
    if (path == '/preview/entitlement' && method == 'PUT') {
      if (!owner) return const ApiResponse(404, null);
      tier = (data as Map)['tier'] as String;
      return ApiResponse(200, entitlement());
    }
    if (path == '/preview/allowance/reset' && owner) {
      used = 0;
      return ApiResponse(200, entitlement());
    }
    return const ApiResponse(404, null);
  }
}

Entitlement _e(Json j, {DateTime? at}) => Entitlement({'validForSeconds': 72 * 3600, ...j}, receivedAtUtc: at ?? DateTime.utc(2026, 10, 31, 12));
Json _plan(String id, {bool archived = false}) => {'id': id, 'isArchived': archived};

Future<(ProviderContainer, PlusServer, SessionManager, FakeClock)> _container({PlusServer? server, AppDb? db, FakeClock? clock}) async {
  final s = server ?? PlusServer();
  final sessions = SessionManager(MemorySecretStore());
  await sessions.signIn(authFor('one'));
  final store = db ?? AppDb(NativeDatabase.memory());
  final c = clock ?? FakeClock(DateTime.utc(2026, 10, 31, 12));
  final container = ProviderContainer(overrides: [
    sessionsProvider.overrideWithValue(sessions), transportProvider.overrideWithValue(s), dbProvider.overrideWithValue(store), clockProvider.overrideWithValue(c),
  ]);
  addTearDown(container.dispose);
  if (db == null) addTearDown(store.close);
  return (container, s, sessions, c);
}

Future<Entitlement?> _settled(ProviderContainer c) async {
  c.read(entitlementProvider);
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return c.read(plusProvider);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('decisions', () {
    test('Free counts plans that are not archived; Plus has no product limit; unknown never blocks below the smallest Free limit', () {
      final free = _e({'tier': 'free', 'limits': {'savedPlans': 3, 'savedMeals': 10}});
      final plus = _e({'tier': 'plus', 'limits': {'savedPlans': null, 'savedMeals': null}});
      final three = [for (final id in ['a', 'b', 'c']) Plan(_plan(id))];
      expect(planGate(free, three.take(2)), CreateGate.ok);
      expect(planGate(free, three), CreateGate.limit);
      expect(planGate(free, [...three.take(2), Plan(_plan('d', archived: true)), Plan(_plan('e', archived: true))]), CreateGate.ok, reason: 'archived plans free a place');
      expect(planGate(plus, [for (var i = 0; i < 40; i++) Plan(_plan('$i'))]), CreateGate.ok);
      expect(planGate(null, three.take(2)), CreateGate.ok);
      expect(planGate(null, three), CreateGate.unknown, reason: 'not known: explained, never a paywall');
      expect(mealGate(free, 9), CreateGate.ok);
      expect(mealGate(free, 10), CreateGate.limit);
      expect(mealGate(free, 25), CreateGate.limit, reason: 'over the limit after a downgrade: the existing ones stay, a new one is explained');
      expect(mealGate(plus, 500), CreateGate.ok);
      expect(mealGate(Entitlement.legacy, 999), CreateGate.ok, reason: 'a server before entitlements limits nothing');
    });

    test('features come only from the server answer; unknown is Free', () {
      expect(plusFeature(_e({'tier': 'plus', 'features': [Entitlement.progression]}), Entitlement.progression), isTrue);
      expect(plusFeature(_e({'tier': 'free', 'features': []}), Entitlement.progression), isFalse);
      expect(plusFeature(null, Entitlement.trendExplorer), isFalse);
      expect(plusFeature(Entitlement.legacy, Entitlement.trendExplorer), isTrue);
    });

    test('the cache is bounded from its receipt, and moving the phone clock can only shorten it', () {
      final e = _e({'tier': 'plus'});
      expect(e.validAt(DateTime.utc(2026, 10, 31, 12)), isTrue);
      expect(e.validAt(DateTime.utc(2026, 11, 3, 11, 59)), isTrue);
      expect(e.validAt(DateTime.utc(2026, 11, 3, 12)), isFalse, reason: '72 h later');
      expect(e.validAt(DateTime.utc(2026, 10, 31, 11, 59)), isFalse, reason: 'a clock set back before the receipt');
      expect(e.validAt(DateTime.utc(2030)), isFalse, reason: 'a clock moved forward');
    });

    test('only a monthly refusal is the allowance; the daily guard stays the old limit', () {
      expect(limitProblem({'code': 'COACH_LIMIT', 'reason': 'monthly'}), AskProblem.allowance);
      expect(limitProblem({'code': 'COACH_LIMIT'}), AskProblem.limit);
      expect(limitProblem(null), AskProblem.limit);
    });
  });

  group('controller', () {
    test('the answer is cached per account: another account never sees it, and offline keeps it only while valid', () async {
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final (c, server, sessions, clock) = await _container(db: db);
      server.tier = 'plus';
      expect((await _settled(c))?.isPlus, isTrue);

      // Another account on the same phone, offline: nothing of the first account's is used.
      server.offline = true;
      await sessions.signIn(authFor('two'));
      expect(await _settled(c), isNull);

      // The first account again, offline: its own last answer, while valid.
      await sessions.signIn(authFor('one'));
      expect((await _settled(c))?.isPlus, isTrue);
      final rec = await c.read(syncProvider).get('one', Kinds.entitlement, 'one');
      expect((jsonDecode(rec!.body) as Json)['entitlement']['tier'], 'plus');
      expect(await c.read(syncProvider).get('two', Kinds.entitlement, 'two'), isNull);

      // Expired: unknown, never Free shown as a paywall and never Plus extended.
      clock.now = clock.now.add(const Duration(hours: 73));
      await c.read(entitlementProvider.notifier).refresh();
      expect(c.read(plusProvider), isNull);
    });

    test('the owner switch is the server\'s: a refused change leaves the account as it was', () async {
      final (c, server, _, _) = await _container();
      expect((await _settled(c))?.isPlus, isFalse);
      expect(await c.read(entitlementProvider.notifier).setPreviewTier(true), isFalse, reason: 'not the owner: 404');
      expect(c.read(plusProvider)?.isPlus, isFalse);
      server.owner = true;
      expect(await c.read(entitlementProvider.notifier).setPreviewTier(true), isTrue);
      expect(c.read(plusProvider)?.overrideActive, isTrue);
      expect(await c.read(entitlementProvider.notifier).resetAllowance(), isTrue);
      expect(c.read(plusProvider)?.allowance?.used, 0);
    });
  });

  group('screens', () {
    Future<(ProviderContainer, PlusServer)> open(WidgetTester tester, {PlusServer? server, Size size = const Size(390, 844), double textScale = 1, Widget? home, AppearanceStore? appearance}) async {
      final s = server ?? PlusServer();
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final overrides = (await tester.runAsync(() => overridesFor(day: '2026-10-31', appearance: appearance)))!;
      final container = await pumpApp(tester, [...overrides, transportProvider.overrideWithValue(s), dbProvider.overrideWithValue(db), clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 10, 31, 12)))],
          home: home ?? const PlusScreen(), size: size, textScale: textScale, settle: false);
      container.read(entitlementProvider); // as the app does at sign-in
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      return (container, s);
    }

    testWidgets('Free: an honest preview, the comparison and the allowance; no purchase, trial, restore or price; no owner controls', (tester) async {
      final (_, server) = await open(tester, size: const Size(390, 2400));
      expect(find.text('GoHard Plus preview'), findsOneWidget);
      expect(find.text('Purchases aren’t available yet.'), findsOneWidget);
      expect(find.text('This account is on Free.'), findsOneWidget);
      expect(find.text('Up to 3'), findsOneWidget);
      expect(find.text('15 a month'), findsOneWidget);
      expect(find.text('300 a month'), findsOneWidget);
      expect(find.text('3 of 15 used'), findsOneWidget);
      expect(find.textContaining('November'), findsWidgets, reason: 'the reset date');
      for (final word in [RegExp('subscribe', caseSensitive: false), RegExp('trial', caseSensitive: false), RegExp('restore', caseSensitive: false), RegExp(r'\$|CA\$'), RegExp('unlimited', caseSensitive: false)]) {
        expect(find.textContaining(word), findsNothing, reason: '$word');
      }
      expect(find.byKey(const Key('plus-tier-true')), findsNothing);
      expect(find.byKey(const Key('plus-reset-allowance')), findsNothing);
      expect(server.calls.where((c) => !c.startsWith('GET ')), isEmpty, reason: 'opening the page sends nothing but reads');
    });

    testWidgets('owner: the switch goes through the server and the override is shown', (tester) async {
      final (_, server) = await open(tester, server: PlusServer()..owner = true);
      await tester.scrollUntilVisible(find.byKey(const Key('plus-tier-true')), 200);
      await tester.tap(find.byKey(const Key('plus-tier-true')));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(server.calls, contains('PUT /preview/entitlement'));
      await tester.scrollUntilVisible(find.byKey(const Key('plus-override-active')), -200);
      expect(find.byKey(const Key('plus-override-active')), findsOneWidget);
    });

    testWidgets('unknown: says so and offers Try again, no paywall', (tester) async {
      await open(tester, server: PlusServer()..offline = true, size: const Size(390, 1600));
      expect(find.textContaining('couldn’t confirm'), findsOneWidget);
      expect(find.byKey(const Key('plus-retry')), findsOneWidget);
      expect(find.byKey(const Key('plus-allowance')), findsNothing);
    });

    testWidgets('a limit sheet over a page keeps what was typed there, through View Plus and back', (tester) async {
      final host = Builder(builder: (context) => Scaffold(body: Column(children: [
            const TextField(key: Key('draft')),
            TextButton(key: const Key('limit'), onPressed: () => showPlusLimit(context, PlusLimit.meals, gate: CreateGate.limit, existing: 10), child: const Text('save')),
          ])));
      await open(tester, home: host);
      await tester.enterText(find.byKey(const Key('draft')), 'Overnight oats');
      await tester.tap(find.byKey(const Key('limit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('up to 10 saved meals and recipes'), findsOneWidget);
      await tester.tap(find.byKey(const Key('plus-limit-view')));
      await tester.pumpAndSettle();
      expect(find.text('GoHard Plus preview'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plus-limit-back')));
      await tester.pumpAndSettle();
      expect(find.text('Overnight oats'), findsOneWidget);
    });

    for (final lang in ['fr-CA', 'ar']) {
      testWidgets('$lang at 320 px and twice the text size: the page and the limit sheet fit, and Arabic reads right to left', (tester) async {
        if (lang == 'ar') await tester.runAsync(loadArabicFonts);
        final host = Builder(builder: (context) => Scaffold(body: TextButton(key: const Key('limit'),
            onPressed: () => showPlusLimit(context, PlusLimit.plans, gate: CreateGate.limit, existing: 4), child: const Text('save'))));
        final (container, _) = await open(tester, server: PlusServer()..owner = true, size: const Size(320, 700), textScale: 2, home: host);
        container.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('limit')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining(lang == 'ar' ? 'حتى 3' : 'jusqu’à 3'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('plus-limit-view')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('plus-limit-view')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(Directionality.of(tester.element(find.byType(PlusScreen))), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        await tester.scrollUntilVisible(find.byKey(const Key('plus-reset-allowance')), 300);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the Plus page meets contrast, target and label guidelines in all six themes', (tester) async {
      final handle = tester.ensureSemantics();
      for (final accent in Accent.values) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          final store = AppearanceStore(MemorySecretStore())
            ..accent = accent
            ..mode = mode;
          await open(tester, server: PlusServer()..owner = true, size: const Size(390, 2600), appearance: store);
          final reason = '${accent.name} ${mode.name}';
          await expectLater(tester, meetsGuideline(textContrastGuideline), reason: reason);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: reason);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: reason);
          await tester.pumpWidget(const SizedBox());
        }
      }
      handle.dispose();
    });

    testWidgets('320 px at twice the text size: nothing overflows, owner controls included', (tester) async {
      await open(tester, server: PlusServer()..owner = true, size: const Size(320, 700), textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byKey(const Key('plus-reset-allowance')), 300);
      expect(tester.takeException(), isNull);
    });
  });
}
