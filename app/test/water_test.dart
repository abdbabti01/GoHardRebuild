import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/nutrition/water.dart';

import 'support.dart';

/// Water on the REAL Drift database file and the fake account authority: the risks of a new synced record (offline
/// through restart, retries that must not duplicate, the logged day after a late sync, corrections, ownership) and
/// the volume arithmetic.
void main() {
  late Harness h;
  late String owner;
  WaterRepository water() => WaterRepository(h.sync, owner);
  Future<List<WaterEntry>> rows([String? who]) async => [for (final b in await h.bodies(who ?? owner, Kinds.water)) WaterEntry(b)];

  setUp(() async {
    h = Harness();
    owner = await h.signIn('one');
  });
  tearDown(() => h.dispose());

  test('logged offline late in the day: survives restart, syncs once although a response is lost, keeps its day', () async {
    h.server.offline = true;
    final receipt = await water().add('2026-10-09', 250);
    await h.sync.flush(); // attempted, fails; nothing is lost
    await h.restart(); // the process ends before the phone is online again

    expect((await h.sync.commands(owner)).single.operationId, receipt.operationId, reason: 'the same command, kept on the phone');
    expect((await rows()).single.volumeMl, 250);

    // Back online after midnight: the entry is still the day it was logged on. The first answer is lost after the
    // account committed it, so the command is sent again under the same operation.
    h.clock.advance(const Duration(hours: 8));
    h.server
      ..offline = false
      ..loseNextResponse = true;
    await h.sync.flush();
    await h.sync.flush();

    expect(h.server.water, hasLength(1), reason: 'one entry, never two');
    expect(h.server.water.values.single['dayKey'], '2026-10-09');
    expect(h.server.callsTo('/water-entries').map((c) => c.body).toSet(), hasLength(1), reason: 'every retry is byte-identical');
    expect(await h.sync.commands(owner), isEmpty);
    final local = await h.sync.get(owner, Kinds.water, (await rows()).single.id);
    expect((local!.syncState, local.dayKey), ('synced', '2026-10-09'));
  });

  test('a correction and a removal go through revisions; another account never sees the entries', () async {
    await water().add('2026-10-09', 500);
    await h.sync.flush();
    var entry = (await rows()).single;

    await water().update(entry, 330);
    await h.sync.flush();
    expect((h.server.water[entry.id]!['volumeMl'], h.server.water[entry.id]!['revision']), (330, 2));

    entry = (await rows()).single;
    await water().remove(entry);
    await h.sync.flush();
    expect(h.server.water[entry.id]!['isDeleted'], isTrue);
    expect((await rows()).single.isDeleted, isTrue, reason: 'kept as removed, so a late answer cannot bring it back');
    expect(waterTotal(await rows()), 0);

    expect(() => WaterRepository.validate(0), throwsA(isA<InvalidWater>()));
    expect(() => WaterRepository.validate(-5), throwsA(isA<InvalidWater>()));
    expect(() => WaterRepository.validate(5000.4), throwsA(isA<InvalidWater>()));

    final other = await h.signIn('two');
    expect(await rows(other), isEmpty, reason: 'one account\'s water is never another\'s');
  });

  test('pulled entries stay on their own days: a new day starts at zero and yesterday is kept', () async {
    h.server.water.addAll({
      'w1': {'id': 'w1', 'dayKey': '2026-10-08', 'volumeMl': 1000.0, 'revision': 1, 'isDeleted': false},
      'w2': {'id': 'w2', 'dayKey': '2026-10-09', 'volumeMl': 236.588, 'revision': 1, 'isDeleted': false},
      'w3': {'id': 'w3', 'dayKey': '2026-10-09', 'volumeMl': 400.0, 'revision': 2, 'isDeleted': true},
    });
    expect(await h.sync.pull(), isTrue);
    Future<List<WaterEntry>> day(String d) async =>
        [for (final r in await h.sync.watch(owner, Kinds.water, dayKey: d).first) WaterEntry(jsonDecode(r.body) as Json)];
    expect(waterTotal(await day('2026-10-08')), 1000);
    expect(waterTotal(await day('2026-10-09')), 236.588, reason: 'the removed entry does not count');
    expect(await day('2026-10-10'), isEmpty, reason: 'a new day has its own total, starting at nothing');
  });

  test('one canonical volume: fluid ounces convert once, totals are exact sums, display rounds only at the end', () {
    expect(VolumeUnit.flOz.toMl(8), 236.588, reason: '8 US fl oz, kept to three decimals');
    expect(VolumeUnit.ml.toMl(250), 250);
    final eight = WaterEntry({'id': 'a', 'dayKey': 'd', 'volumeMl': VolumeUnit.flOz.toMl(8), 'isDeleted': false});
    final total = waterTotal([eight, eight, eight]);
    expect(VolumeUnit.flOz.format(total), '24 fl oz', reason: 'three 8 fl oz entries read back as 24, with no drift');
    expect(VolumeUnit.ml.format(total), '710 mL');
    expect(VolumeUnit.ml.format(1250), '1,250 mL', reason: 'the chosen unit throughout, never switching to litres');
    expect(VolumeUnit.ml.progress(750, 2000), '750 / 2,000 mL');
    expect(VolumeUnit.ml.progress(2400, 2000), '2,400 / 2,000 mL', reason: 'the real amount above the goal');
    expect(VolumeUnit.flOz.progress(236.5882365, 2000), '8 / 67.6 fl oz');
    expect(VolumeUnit.ml.format(2000), '2,000 mL');
    expect(VolumeUnit.flOz.quick, [4, 8, 16], reason: 'quick additions follow the chosen unit');
    expect(VolumeUnit.ml.quick, [100, 250, 500]);
  });
}
