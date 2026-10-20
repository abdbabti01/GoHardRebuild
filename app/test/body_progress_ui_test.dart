import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/body/body_screens.dart';

import 'ui_support.dart';

/// Body progress screens over fixture check-ins and a real in-memory database (docs/BODY_PROGRESS.md). None of these
/// numbers ships in the app.

const _day = '2026-10-19';

class _Net implements Transport {
  final paths = <String>[];
  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer}) async {
    paths.add(path);
    return const ApiResponse(503, null);
  }
}

late AppDb _local;
late SyncEngine _engine;

/// A real local database; nothing leaves it (the engine is blocked), so every save stays a pending command to inspect.
Future<List<Override>> _overrides(WidgetTester tester, _Net net, {List<Json> fixtures = const [], bool live = false}) async {
  final base = (await tester.runAsync(() => overridesFor(day: _day, bodyMetrics: fixtures, liveMetrics: live)))!;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  _local = AppDb(NativeDatabase.memory());
  addTearDown(_local.close);
  return [
    ...base,
    transportProvider.overrideWithValue(net),
    dbProvider.overrideWithValue(_local),
    syncProvider.overrideWith((ref) {
      _engine = SyncEngine(_local, Api(net, ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
      ref.onDispose(_engine.dispose);
      return _engine;
    }),
  ];
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Json _m(String id, String day, Map<String, Object?> values, {String? at}) => {'id': id, 'dayKey': day, 'revision': 1, 'isDeleted': false, 'recordedAtUtc': at, ...values};

void main() {
  testWidgets('first entry: measurement-only, inches with a decimal comma, a refused save keeps input, a double tap saves once', (tester) async {
    final net = _Net();
    await pumpApp(tester, await _overrides(tester, net, live: true), home: const BodyProgressScreen(), size: const Size(390, 1400));
    expect(find.text('Nothing recorded yet'), findsOneWidget);
    expect(find.text('0.0 kg'), findsNothing, reason: 'no fake zero');
    await _tap(tester, 'body-log');

    await _tap(tester, 'body-length-inch');
    await _type(tester, 'body-field-waist', '35,5');
    await _type(tester, 'body-field-leftUpperArm', '16,25');
    await _type(tester, 'body-field-chest', '.');
    await _tap(tester, 'body-save');
    expect(find.text('Enter a number, or leave it blank.'), findsOneWidget);
    expect(await _engine.commands('one'), isEmpty, reason: 'nothing saved');
    expect(find.text('35,5'), findsOneWidget, reason: 'the rest of the input is intact');

    await _type(tester, 'body-field-chest', '');
    await tester.tap(find.byKey(const Key('body-save')));
    await tester.tap(find.byKey(const Key('body-save')), warnIfMissed: false);
    await tester.pumpAndSettle();
    final cmds = await _engine.commands('one');
    expect(cmds, hasLength(1), reason: 'one check-in, one command');
    final sent = jsonDecode(cmds.single.payload) as Json;
    expect((sent['waistCm'], sent['leftUpperArmCm'], sent['weightKg'], sent.containsKey('chestCm'), sent['dayKey']), (90.17, 41.275, null, false, _day));

    // Back on the overview: the waist with its date, no invented weight.
    expect(find.byKey(const Key('body-latest-waist')), findsOneWidget);
    expect(find.text('35.5 in'), findsOneWidget);
    expect(find.text('Not recorded'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget, reason: 'no weight in the last 7 days');
    expect(net.paths, isEmpty, reason: 'viewing and saving asks nothing of the AI or the network');
  });

  testWidgets('correcting an entry sends only the changed field; hidden body fat, note and the right thigh stay; Back asks first', (tester) async {
    final net = _Net();
    final container = await pumpApp(tester, await _overrides(tester, net, live: true), home: const SizedBox(), settle: false);
    final existing = _m('e1', '2026-10-12', {'weightKg': 89.81128, 'bodyFatPercent': 21.5, 'note': 'after travel', 'rightThighCm': 60.96});
    await tester.runAsync(() => container.read(syncProvider).putLocal('one', LocalWrite(Kinds.metric, 'e1', existing, dayKey: '2026-10-12')));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => CheckInScreen(existing: BodyMetric(existing))));
    await tester.pumpAndSettle();

    expect(find.text('89.81'), findsOneWidget, reason: 'shown in kg, two decimals');
    await _type(tester, 'body-field-waist', '90');
    // Back with an unsaved change asks; Keep editing keeps it.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('90'), findsOneWidget);

    await _tap(tester, 'body-save');
    final sent = jsonDecode((await _engine.commands('one')).single.payload) as Json;
    expect(sent.keys.toSet(), {'expectedRevision', 'dayKey', 'waistCm', 'operationId'}, reason: 'the untouched 89.81 never overwrites 89.81128');
    final local = BodyMetric(jsonDecode((await _engine.get('one', Kinds.metric, 'e1'))!.body) as Json);
    expect((local.weightKg, local.bodyFatPercent, local.note, local.value('rightThighCm'), local.value('waistCm')), (89.81128, 21.5, 'after travel', 60.96, 90.0));
  });

  testWidgets('compare: real values, a dash and "Not recorded" for a missing one, sides apart; a legacy same-day pair asks to choose', (tester) async {
    final net = _Net();
    final fixtures = [
      _m('a', '2026-10-05', {'weightKg': 90.718474, 'waistCm': 91.44, 'leftUpperArmCm': 41.275}),
      _m('b', '2026-10-19', {'weightKg': 89.811289, 'waistCm': 90.17, 'rightUpperArmCm': 41.91}),
    ];
    await pumpApp(tester, await _overrides(tester, net, fixtures: fixtures), home: const CompareScreen(), size: const Size(390, 1400));
    expect(find.text('Oct 5, 2026'), findsOneWidget);
    expect(find.text('Oct 19, 2026'), findsOneWidget);
    expect(find.textContaining('−0.91 kg'), findsOneWidget, reason: 'weight change, To minus From');
    expect(find.text('−1.27 cm'), findsOneWidget, reason: 'waist change');
    expect(find.text('Not recorded'), findsNWidgets(2), reason: 'left arm missing on Oct 19, right arm missing on Oct 5');
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp(r'Left upper arm: Oct 5 41\.2\d cm, Oct 19 not recorded, change not available')), findsOneWidget);
    semantics.dispose();
    expect(net.paths, isEmpty);

    // Two entries on Oct 19 without saved times: no default for that side.
    await pumpApp(tester, await _overrides(tester, net, fixtures: [...fixtures, _m('c', '2026-10-19', {'weightKg': 89.0})]), home: const CompareScreen(), size: const Size(390, 1400));
    expect(find.byKey(const Key('body-compare-choose')), findsOneWidget);
    await _tap(tester, 'body-compare-to');
    expect(find.text('One of 2 entries this day, order not known\nWeight 89.0 kg'), findsOneWidget);
    await _tap(tester, 'body-pick-c');
    expect(find.byKey(const Key('body-compare-choose')), findsNothing);
    expect(find.textContaining('−1.72 kg'), findsOneWidget);
  });

  testWidgets('overview: latest weight with its own date, a day-weighted 7-day average, a chart point opens the real entry', (tester) async {
    final fixtures = [
      _m('w1', '2026-10-13', {'weightKg': 90.0}), _m('w2', '2026-10-13', {'weightKg': 92.0}), _m('w3', '2026-10-17', {'weightKg': 90.0, 'note': 'morning'}),
      _m('c1', '2026-10-18', {'waistCm': 90.0}),
    ];
    await pumpApp(tester, await _overrides(tester, _Net(), fixtures: fixtures), home: const BodyProgressScreen(), size: const Size(390, 1600));
    expect(find.text('90.0 kg'), findsWidgets);
    expect(find.text('Recorded Oct 17'), findsOneWidget, reason: 'the latest weight day, not the later waist-only day, and never "today"');
    expect(find.text('90.5 kg'), findsOneWidget, reason: 'Oct 13 counts once as 91.0, Oct 17 as 90.0');
    expect(find.text('2 recorded days of 7'), findsOneWidget);
    expect(find.text('Points: each entry · line: daily average'), findsOneWidget);
    await _tap(tester, 'body-range-all');
    // The latest point (Oct 17, the lowest value) sits at the plot's bottom-right corner; tapping it opens that entry.
    final chart = tester.getRect(find.byKey(const Key('trend-chart')));
    await tester.tapAt(Offset(chart.right - 12, chart.bottom - 28));
    await tester.pumpAndSettle();
    expect(find.text('Edit entry'), findsOneWidget);
    expect(find.text('morning'), findsOneWidget, reason: 'the Oct 17 entry with its note');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, 'body-all');
    expect(find.textContaining('one of 2 entries, order not known'), findsNWidgets(2));
    expect(find.textContaining('“morning”'), findsOneWidget);
  });

  testWidgets('320 px at large text: the form and the comparison stack without overflow', (tester) async {
    final fixtures = [_m('a', '2026-10-05', {'waistCm': 91.44, 'bodyFatPercent': 22}), _m('b', '2026-10-19', {'waistCm': 90.17, 'bodyFatPercent': 21.5})];
    await pumpApp(tester, await _overrides(tester, _Net(), fixtures: fixtures), home: const CompareScreen(), size: const Size(320, 900), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Change: −0.5 pts'), findsOneWidget);
    await pumpApp(tester, await _overrides(tester, _Net(), fixtures: fixtures), home: const CheckInScreen(), size: const Size(320, 900), textScale: 2);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'body-choose');
    await _tap(tester, 'body-choose-bodyFat');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('body-field-bodyFat')), findsOneWidget);
  });
}
