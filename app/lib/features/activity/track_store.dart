import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/db.dart';
import '../../data/sync.dart' show LocalSaveFailure;
import 'track_math.dart';

/// The stored route of each activity (docs/RUN_WALK.md › Route format). Append-only, ordered, owner-scoped.
/// A failed write throws [LocalSaveFailure]: the caller says so and keeps what it could not store.
class TrackStore {
  TrackStore(this.db);
  final AppDb db;

  /// Entries per uploaded chunk. Chunk n holds seq 500n..500n+499, so a chunk is the same on every attempt.
  static const chunkSize = 500;

  static TrackEntry fromRow(TrackRow r) => TrackEntry(
      seq: r.seq, type: EntryType.values.byName(r.type), segment: r.segment, t: r.t, lat: r.lat, lon: r.lon, acc: r.acc,
      alt: r.alt, altAcc: r.altAcc, speed: r.speed, speedAcc: r.speedAcc, heading: r.heading,
      meta: r.meta == null ? null : (jsonDecode(r.meta!) as Map).cast<String, dynamic>());

  static TrackEntriesCompanion _row(String owner, String activityId, TrackEntry e) => TrackEntriesCompanion.insert(
      ownerId: owner, activityId: activityId, seq: e.seq, type: e.type.name, segment: e.segment, t: e.t,
      lat: Value(e.lat), lon: Value(e.lon), acc: Value(e.acc), alt: Value(e.alt), altAcc: Value(e.altAcc),
      speed: Value(e.speed), speedAcc: Value(e.speedAcc), heading: Value(e.heading), meta: Value(e.meta == null ? null : jsonEncode(e.meta)));

  /// Writes one entry in its own transaction. A second write of the same seq fails rather than overwriting.
  Future<void> append(String owner, String activityId, TrackEntry e) async {
    try {
      await db.into(db.trackEntries).insert(_row(owner, activityId, e));
    } on Object catch (error) {
      throw LocalSaveFailure(error);
    }
  }

  /// Stores entries read from the account (another device's route). Existing entries are kept as they are.
  Future<void> putAll(String owner, String activityId, List<TrackEntry> entries) => db.batch((b) =>
      b.insertAll(db.trackEntries, [for (final e in entries) _row(owner, activityId, e)], mode: InsertMode.insertOrIgnore));

  SimpleSelectStatement<$TrackEntriesTable, TrackRow> _q(String owner, String activityId) =>
      db.select(db.trackEntries)..where((r) => r.ownerId.equals(owner) & r.activityId.equals(activityId));

  /// Every entry in order. Read in pages so a long route never needs one huge query result at a time.
  Stream<TrackEntry> entries(String owner, String activityId, {int fromSeq = 0, int? toSeq}) async* {
    var next = fromSeq;
    while (true) {
      final page = await (_q(owner, activityId)
            ..where((r) => r.seq.isBiggerOrEqualValue(next) & (toSeq == null ? const Constant(true) : r.seq.isSmallerOrEqualValue(toSeq)))
            ..orderBy([(r) => OrderingTerm.asc(r.seq)])
            ..limit(2000))
          .get();
      for (final r in page) {
        yield fromRow(r);
      }
      if (page.length < 2000) return;
      next = page.last.seq + 1;
    }
  }

  Future<List<TrackEntry>> all(String owner, String activityId) => entries(owner, activityId).toList();

  Future<TrackAnalysis> analyze(String owner, String activityId) async {
    final a = TrackAnalysis();
    await for (final e in entries(owner, activityId)) {
      a.add(e);
    }
    return a;
  }

  /// One upload chunk's entries.
  Future<List<TrackEntry>> chunk(String owner, String activityId, int index) =>
      entries(owner, activityId, fromSeq: index * chunkSize, toSeq: index * chunkSize + chunkSize - 1).toList();

  /// (entry count, highest seq or -1).
  Future<(int, int)> extent(String owner, String activityId) async {
    final count = db.trackEntries.seq.count(), top = db.trackEntries.seq.max();
    final row = await (db.selectOnly(db.trackEntries)
          ..addColumns([count, top])
          ..where(db.trackEntries.ownerId.equals(owner) & db.trackEntries.activityId.equals(activityId)))
        .getSingle();
    return (row.read(count) ?? 0, row.read(top) ?? -1);
  }

  Future<void> erase(String owner, String activityId) => (db.delete(db.trackEntries)..where((r) => r.ownerId.equals(owner) & r.activityId.equals(activityId))).go();
}
