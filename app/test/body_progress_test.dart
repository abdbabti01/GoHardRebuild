import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/body/body_metrics.dart';
import 'package:gohard_rebuild/features/body/body_repository.dart';
import 'package:gohard_rebuild/features/progress/trends.dart' show TrendRange;

import 'support.dart';

/// Body progress (docs/BODY_PROGRESS.md): the projections, units and form rules, then the check-in pipeline on the
/// REAL Drift database file and the fake account authority. Every value here is a test fixture.

double lb(double v) => v * kgPerLb;
var _n = 0;
BodyMetric m(String day, {double? weightKg, double? waistCm, double? leftArm, double? rightArm, double? fat, String? at, String? id}) => BodyMetric({
      'id': id ?? 'm${_n++}', 'dayKey': day, 'weightKg': weightKg, 'waistCm': waistCm, 'leftUpperArmCm': leftArm, 'rightUpperArmCm': rightArm,
      'bodyFatPercent': fat, 'recordedAtUtc': at, 'revision': 1, 'isDeleted': false,
    });

void main() {
  const lbUnits = BodyUnits(LoadUnit.lb, LengthUnit.inch), metric = BodyUnits(LoadUnit.kg, LengthUnit.cm);

  group('projections', () {
    test('7-day average: each recorded day counts once, missing days are left out, no records is unavailable', () {
      const today = '2026-10-19';
      final four = [m('2026-10-13', weightKg: lb(199.0)), m('2026-10-15', weightKg: lb(198.8)), m('2026-10-17', weightKg: lb(198.6)), m('2026-10-19', weightKg: lb(198.0))];
      final avg = sevenDayWeight(four, today)!;
      expect((lbUnits.number(BodyField.weight, avg.kg), avg.days, avg.from), ('198.6', 4, '2026-10-13'));
      // Two weigh-ins on the first day (198.0 and 200.0) still make that day 199.0, and the result is the same.
      final split = [m('2026-10-13', weightKg: lb(198.0)), m('2026-10-13', weightKg: lb(200.0)), ...four.skip(1)];
      expect((lbUnits.number(BodyField.weight, sevenDayWeight(split, today)!.kg), sevenDayWeight(split, today)!.days), ('198.6', 4));
      // Outside the window (8 days back) or measurement-only check-ins never count; nothing at all is null, not 0.
      expect(sevenDayWeight([m('2026-10-12', weightKg: 90), m('2026-10-19', waistCm: 90)], today), isNull);
    });

    test('latest per metric: the latest day holding that metric; unknown same-day order is an average, labelled', () {
      final checkIns = [
        m('2026-10-10', weightKg: 90, waistCm: 92),
        m('2026-10-19', waistCm: 91), // circumference only: not the latest weight
        m('2026-10-12', weightKg: 89, id: 'b'), m('2026-10-12', weightKg: 91, id: 'a'), // legacy, no saved time
      ];
      final w = latestOf(checkIns, BodyField.weight)!;
      expect((w.dayKey, w.value, w.averaged, w.count), ('2026-10-12', 90.0, true, 2));
      expect(latestOf(checkIns, BodyField.waist)!.dayKey, '2026-10-19');
      expect(latestOf(checkIns, BodyField.chest), isNull);
      // A known order picks the later entry, never by ID.
      final known = [m('2026-10-12', weightKg: 89, id: 'z', at: '2026-10-12T07:00:00Z'), m('2026-10-12', weightKg: 91, id: 'a', at: '2026-10-12T19:00:00Z')];
      expect((latestOf(known, BodyField.weight)!.value, latestOf(known, BodyField.weight)!.averaged), (91.0, false));
    });

    test('ranges are calendar days across the year end; only observed values of that exact field and side', () {
      final checkIns = [m('2025-12-13', leftArm: 40), m('2025-12-14', leftArm: 41, rightArm: 42), m('2026-01-10', rightArm: 43), m('2026-01-11', leftArm: 44)];
      final left = seriesOf(checkIns, BodyField.leftUpperArm, TrendRange.weeks4, '2026-01-10');
      expect([for (final p in left) (p.dayKey, p.value)], [('2025-12-14', 41.0)], reason: '28 days including Jan 10 starts Dec 14; Jan 11 is in the future');
      expect([for (final p in seriesOf(checkIns, BodyField.rightUpperArm, TrendRange.all, '2026-01-11')) p.value], [42.0, 43.0]);
      expect(dailyMeans([...seriesOf([m('2026-01-01', waistCm: 90), m('2026-01-01', waistCm: 92)], BodyField.waist, TrendRange.all, '2026-01-02')]), [('2026-01-01', 91.0)]);
    });

    test('comparison: real values only, a change only where both hold that metric, body fat in points, sides kept apart', () {
      final from = m('2026-10-05', weightKg: lb(200), waistCm: 36 * 2.54, leftArm: 16.25 * 2.54, fat: 22);
      final to = m('2026-10-19', weightKg: lb(198), waistCm: 35.5 * 2.54, rightArm: 16.5 * 2.54, fat: 21.5);
      final rows = {for (final r in compareCheckInsRows(from, to)) r.field: r};
      expect(lbUnits.change(BodyField.weight, rows[BodyField.weight]!.from!, rows[BodyField.weight]!.to!), '−2.0 lb');
      expect(lbUnits.change(BodyField.waist, rows[BodyField.waist]!.from!, rows[BodyField.waist]!.to!), '−0.5 in');
      expect(lbUnits.change(BodyField.bodyFat, 22, 21.5), '−0.5 pts');
      expect((rows[BodyField.leftUpperArm]!.hasChange, rows[BodyField.leftUpperArm]!.to), (false, null), reason: 'the right arm is not the left arm');
      expect((rows[BodyField.rightUpperArm]!.hasChange, rows[BodyField.rightUpperArm]!.from), (false, null));
      expect(rows.containsKey(BodyField.chest), isFalse);
      expect(lbUnits.change(BodyField.waist, 91.44, 91.44), '0.0 in');
    });

    test('default pair: the newest two days; a day with entries in unknown order asks the person to choose', () {
      expect(defaultPair([m('2026-10-19', waistCm: 1)]), (null, null));
      final a = m('2026-10-05', waistCm: 90, id: 'a'), b = m('2026-10-19', waistCm: 89, id: 'b');
      expect(defaultPair([a, b, m('2026-10-01', waistCm: 91)]), (a, b));
      final legacy = [a, m('2026-10-19', weightKg: 80, id: 'x'), m('2026-10-19', weightKg: 81, id: 'y')];
      expect(defaultPair(legacy), (a, null));
    });
  });

  group('units and form rules', () {
    test('quarter inches, decimal comma, kg/lb round trips and range errors', () {
      expect(readField(BodyField.leftUpperArm, '16,25', null, lbUnits).value, 41.275);
      expect(lbUnits.number(BodyField.leftUpperArm, 41.275), '16.25');
      final kg = readField(BodyField.weight, '198.25', null, lbUnits).value!;
      expect((kg, lbUnits.number(BodyField.weight, kg)), (89.9247, '198.25'));
      expect(readField(BodyField.waist, '', null, lbUnits), (value: null, error: null), reason: 'blank is missing, never zero');
      expect(readField(BodyField.waist, '3o', null, lbUnits).error, isNotNull, reason: 'typed text that is not a number is not blank');
      expect(readField(BodyField.waist, '0', null, lbUnits).error, isNotNull);
      expect(readField(BodyField.waist, '196.85', null, lbUnits).error, isNull);
      expect(readField(BodyField.waist, '196.9', null, lbUnits).error, isNotNull, reason: 'above 500 cm');
      expect(readField(BodyField.bodyFat, '0', null, metric).value, 0.0);
    });

    test('changing units converts a filled draft, keeps untouched stored precision, and refuses to drop bad text', () {
      // A stored 89.81128 kg shown as "198.0" lb saves exactly 89.81128 while the text is untouched.
      const stored = FieldAnchor('198.0', 89.81128);
      expect(readField(BodyField.weight, '198.0', stored, lbUnits).value, 89.81128);
      final converted = convertFields({BodyField.weight: '198.0', BodyField.waist: '16.5', BodyField.chest: ''}, {BodyField.weight: stored}, lbUnits, metric)!;
      expect((converted[BodyField.weight]!.text, converted[BodyField.weight]!.canonical), ('89.81', 89.81128));
      expect((converted[BodyField.waist]!.text, converted[BodyField.waist]!.canonical), ('41.91', 41.91));
      expect(converted[BodyField.chest], isNull);
      // Back again: still the exact values, shown as typed.
      final back = convertFields({BodyField.weight: '89.81', BodyField.waist: '41.91'}, converted, metric, lbUnits)!;
      expect((back[BodyField.weight]!.text, back[BodyField.weight]!.canonical, back[BodyField.waist]!.text), ('198.0', 89.81128, '16.5'));
      expect(convertFields({BodyField.waist: '16.5x'}, const {}, lbUnits, metric), isNull);
    });
  });

  group('sync', () {
    late Harness h;
    late String owner;
    BodyRepository repo([Harness? on, String? who]) => BodyRepository((on ?? h).sync, who ?? owner);
    const caps = {'body-metrics.measurements'};

    setUp(() async {
      h = Harness();
      owner = await h.signIn('one');
    });
    tearDown(() => h.dispose());

    test('saved offline: survives restart, sent once through a lost response, converges on a second phone', () async {
      h.server.offline = true;
      await repo().create('c1', '2026-10-09', {BodyField.waist: 91.44, BodyField.leftUpperArm: 41.275, BodyField.rightUpperArm: null}, nowUtc: h.clock.utcNow());
      await h.sync.flush();
      await h.restart();
      expect((await h.bodies(owner, Kinds.metric)).single['waistCm'], 91.44);

      h.server
        ..offline = false
        ..loseNextResponse = true;
      await h.sync.flush();
      await h.sync.flush();
      expect(h.server.bodyMetrics.keys, ['c1']);
      expect(h.server.callsTo('/body-metrics').map((c) => c.body).toSet(), hasLength(1), reason: 'every retry is byte-identical');
      final sent = jsonDecode(h.server.callsTo('/body-metrics').first.body) as Json;
      expect(sent.containsKey('rightUpperArmCm'), isFalse, reason: 'blank is not sent as a value');
      expect(sent['recordedAtUtc'], '2026-10-09T18:00:00.000Z');
      expect((await h.sync.get(owner, Kinds.metric, 'c1'))!.syncState, 'synced');

      final second = Harness(server: h.server);
      addTearDown(second.dispose);
      final there = await second.signIn('one');
      expect(await second.sync.pull(), isTrue);
      final copy = BodyMetric((await second.bodies(there, Kinds.metric)).single);
      expect((copy.value('waistCm'), copy.value('leftUpperArmCm'), copy.value('rightUpperArmCm'), copy.recordedAtUtc), (91.44, 41.275, null, '2026-10-09T18:00:00.000Z'));
    });

    test('offline create, correct, delete replays in order; a correction sends only what changed', () async {
      h.server.offline = true;
      await repo().create('c2', '2026-10-09', {BodyField.weight: 80, BodyField.bodyFat: 20, BodyField.waist: 90}, note: 'morning', nowUtc: h.clock.utcNow());
      final local = BodyMetric((await h.bodies(owner, Kinds.metric)).single);
      // Waist cleared, chest added; weight untouched; body fat and note not part of this form.
      await repo().update(local, '2026-10-09', {BodyField.waist: null, BodyField.chest: 100});
      final edited = BodyMetric((await h.bodies(owner, Kinds.metric)).single);
      expect((edited.weightKg, edited.bodyFatPercent, edited.note, edited.value('waistCm'), edited.value('chestCm')), (80.0, 20.0, 'morning', null, 100.0));
      expect(() => repo().update(edited, '2026-10-09', {BodyField.weight: null, BodyField.bodyFat: null, BodyField.chest: null}), throwsA(isA<BodyInputError>()),
          reason: 'an edit that leaves nothing measured is refused; delete is the way');
      await repo().delete(edited);

      final before = h.server.calls.length;
      h.server.offline = false;
      await h.sync.flush();
      final kinds = [for (final c in h.server.calls.skip(before).where((c) => c.path.contains('body-metrics'))) c.method];
      expect(kinds, ['POST', 'PUT', 'POST']);
      final put = jsonDecode(h.server.callsTo('/body-metrics/c2').first.body) as Json;
      expect(put.keys.toSet(), {'operationId', 'expectedRevision', 'dayKey', 'waistCm', 'chestCm'});
      expect((put['expectedRevision'], put['waistCm']), (1, null));
      final row = h.server.bodyMetrics['c2']!;
      expect((row['isDeleted'], row['weightKg'], row['bodyFatPercent'], row['note'], row['revision']), (true, 80, 20, 'morning', 3));
    });

    test('an older server: weight-only check-ins go; circumferences and corrections wait, untouched', () async {
      Set<String>? known = const {};
      h.sync.mayDispatch = (cmd) => BodyRepository.serverTakes(cmd, known);
      await repo().create('w1', '2026-10-09', {BodyField.weight: 80}, nowUtc: h.clock.utcNow(), measurementsServer: false);
      await repo().create('c3', '2026-10-09', {BodyField.waist: 90}, nowUtc: h.clock.utcNow());
      expect(() => repo().create('c4', '2026-10-09', {BodyField.waist: 90}, nowUtc: h.clock.utcNow(), measurementsServer: false), throwsA(isA<BodyInputError>()));
      await h.sync.flush();
      expect(h.server.bodyMetrics.keys, ['w1']);
      expect((jsonDecode(h.server.callsTo('/body-metrics').single.body) as Json).keys.toSet(), {'operationId', 'metricId', 'dayKey', 'weightKg', 'bodyFatPercent', 'note'},
          reason: 'the shape an older server knows; nothing it would drop');
      expect((await h.sync.commands(owner)).single.kind, 'metric.create');

      known = caps; // the server is updated
      await h.sync.flush();
      expect(h.server.bodyMetrics.keys, ['w1', 'c3']);
    });
  });
}
