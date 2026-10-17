import 'package:drift/drift.dart';

part 'db.g.dart';

/// Durable owner-scoped local records. One row per owned thing (plan, workout, set, food entry, …).
/// `body` is the record in wire shape; the columns beside it are the synchronization metadata.
@DataClassName('Rec')
class Records extends Table {
  TextColumn get ownerId => text()();
  TextColumn get kind => text()();
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get dayKey => text().nullable()();
  TextColumn get body => text()();

  /// Last revision the account authority acknowledged. 0 = the server has never confirmed this record.
  IntColumn get revision => integer().withDefault(const Constant(0))();

  /// Bumped by every local edit. An acknowledgement only replaces `body` when this still matches.
  IntColumn get localRevision => integer().withDefault(const Constant(0))();

  /// synced | pending | conflict | rejected | local (never leaves the phone)
  TextColumn get syncState => text().withDefault(const Constant('synced'))();

  /// The account's version, held for review while this record is in conflict.
  TextColumn get serverBody => text().nullable()();

  /// The version the user did not choose in a conflict. Retained, never silently discarded.
  TextColumn get alternativeBody => text().nullable()();

  @override
  Set<Column> get primaryKey => {ownerId, kind, id};
}

/// Durable outbox. A command is written in the same transaction as the local change it describes.
/// `payload` is immutable; `outbound` is resolved once before first dispatch and reused for every retry.
@DataClassName('Cmd')
class Commands extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get operationId => text().unique()();
  TextColumn get ownerId => text()();
  TextColumn get kind => text()();
  TextColumn get method => text()();
  TextColumn get path => text()();
  TextColumn get payload => text()();
  TextColumn get outbound => text().nullable()();
  TextColumn get targetKind => text()();
  TextColumn get targetId => text()();
  IntColumn get capturedLocalRevision => integer()();
  TextColumn get dependsOn => text().withDefault(const Constant('[]'))();

  /// pending | accepted | conflict | rejected | superseded
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get ack => text().nullable()();
}

/// The stored route of a Run / Walk (docs/RUN_WALK.md › Route format): append-only, ordered by `seq`, owner-scoped.
/// One row per fix or recording event, so the route and every metric can be reproduced.
@DataClassName('TrackRow')
class TrackEntries extends Table {
  TextColumn get ownerId => text()();
  TextColumn get activityId => text()();
  IntColumn get seq => integer()();
  TextColumn get type => text()();
  IntColumn get segment => integer()();

  /// UTC epoch milliseconds.
  IntColumn get t => integer()();
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();
  RealColumn get acc => real().nullable()();
  RealColumn get alt => real().nullable()();
  RealColumn get altAcc => real().nullable()();
  RealColumn get speed => real().nullable()();
  RealColumn get speedAcc => real().nullable()();
  RealColumn get heading => real().nullable()();

  /// Event details as JSON (legacy distance/time, interruption reason).
  TextColumn get meta => text().nullable()();

  @override
  Set<Column> get primaryKey => {ownerId, activityId, seq};
}

@DriftDatabase(tables: [Records, Commands, TrackEntries])
class AppDb extends _$AppDb {
  AppDb(super.e);

  /// v1: initial. v2: adds Records.alternativeBody and Commands.ack (conflict evidence retention).
  /// v3: adds track_entries (Run / Walk routes).
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('CREATE INDEX records_owner_kind_day ON records (owner_id, kind, day_key)');
          await customStatement('CREATE INDEX commands_owner_state ON commands (owner_id, state, seq)');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Additive only: existing records and pending commands keep their identities and payloads.
            await m.addColumn(records, records.alternativeBody);
            await m.addColumn(commands, commands.ack);
          }
          if (from < 3) await m.createTable(trackEntries); // additive: no existing row changes
        },
      );
}
