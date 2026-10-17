// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $RecordsTable extends Records with TableInfo<$RecordsTable, Rec> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localRevisionMeta = const VerificationMeta(
    'localRevision',
  );
  @override
  late final GeneratedColumn<int> localRevision = GeneratedColumn<int>(
    'local_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  static const VerificationMeta _serverBodyMeta = const VerificationMeta(
    'serverBody',
  );
  @override
  late final GeneratedColumn<String> serverBody = GeneratedColumn<String>(
    'server_body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alternativeBodyMeta = const VerificationMeta(
    'alternativeBody',
  );
  @override
  late final GeneratedColumn<String> alternativeBody = GeneratedColumn<String>(
    'alternative_body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    kind,
    id,
    parentId,
    dayKey,
    body,
    revision,
    localRevision,
    syncState,
    serverBody,
    alternativeBody,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'records';
  @override
  VerificationContext validateIntegrity(
    Insertable<Rec> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('local_revision')) {
      context.handle(
        _localRevisionMeta,
        localRevision.isAcceptableOrUnknown(
          data['local_revision']!,
          _localRevisionMeta,
        ),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('server_body')) {
      context.handle(
        _serverBodyMeta,
        serverBody.isAcceptableOrUnknown(data['server_body']!, _serverBodyMeta),
      );
    }
    if (data.containsKey('alternative_body')) {
      context.handle(
        _alternativeBodyMeta,
        alternativeBody.isAcceptableOrUnknown(
          data['alternative_body']!,
          _alternativeBodyMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, kind, id};
  @override
  Rec map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Rec(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      localRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_revision'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      serverBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_body'],
      ),
      alternativeBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alternative_body'],
      ),
    );
  }

  @override
  $RecordsTable createAlias(String alias) {
    return $RecordsTable(attachedDatabase, alias);
  }
}

class Rec extends DataClass implements Insertable<Rec> {
  final String ownerId;
  final String kind;
  final String id;
  final String? parentId;
  final String? dayKey;
  final String body;

  /// Last revision the account authority acknowledged. 0 = the server has never confirmed this record.
  final int revision;

  /// Bumped by every local edit. An acknowledgement only replaces `body` when this still matches.
  final int localRevision;

  /// synced | pending | conflict | rejected | local (never leaves the phone)
  final String syncState;

  /// The account's version, held for review while this record is in conflict.
  final String? serverBody;

  /// The version the user did not choose in a conflict. Retained, never silently discarded.
  final String? alternativeBody;
  const Rec({
    required this.ownerId,
    required this.kind,
    required this.id,
    this.parentId,
    this.dayKey,
    required this.body,
    required this.revision,
    required this.localRevision,
    required this.syncState,
    this.serverBody,
    this.alternativeBody,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['kind'] = Variable<String>(kind);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || dayKey != null) {
      map['day_key'] = Variable<String>(dayKey);
    }
    map['body'] = Variable<String>(body);
    map['revision'] = Variable<int>(revision);
    map['local_revision'] = Variable<int>(localRevision);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || serverBody != null) {
      map['server_body'] = Variable<String>(serverBody);
    }
    if (!nullToAbsent || alternativeBody != null) {
      map['alternative_body'] = Variable<String>(alternativeBody);
    }
    return map;
  }

  RecordsCompanion toCompanion(bool nullToAbsent) {
    return RecordsCompanion(
      ownerId: Value(ownerId),
      kind: Value(kind),
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      dayKey: dayKey == null && nullToAbsent
          ? const Value.absent()
          : Value(dayKey),
      body: Value(body),
      revision: Value(revision),
      localRevision: Value(localRevision),
      syncState: Value(syncState),
      serverBody: serverBody == null && nullToAbsent
          ? const Value.absent()
          : Value(serverBody),
      alternativeBody: alternativeBody == null && nullToAbsent
          ? const Value.absent()
          : Value(alternativeBody),
    );
  }

  factory Rec.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Rec(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      kind: serializer.fromJson<String>(json['kind']),
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      dayKey: serializer.fromJson<String?>(json['dayKey']),
      body: serializer.fromJson<String>(json['body']),
      revision: serializer.fromJson<int>(json['revision']),
      localRevision: serializer.fromJson<int>(json['localRevision']),
      syncState: serializer.fromJson<String>(json['syncState']),
      serverBody: serializer.fromJson<String?>(json['serverBody']),
      alternativeBody: serializer.fromJson<String?>(json['alternativeBody']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'kind': serializer.toJson<String>(kind),
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String?>(parentId),
      'dayKey': serializer.toJson<String?>(dayKey),
      'body': serializer.toJson<String>(body),
      'revision': serializer.toJson<int>(revision),
      'localRevision': serializer.toJson<int>(localRevision),
      'syncState': serializer.toJson<String>(syncState),
      'serverBody': serializer.toJson<String?>(serverBody),
      'alternativeBody': serializer.toJson<String?>(alternativeBody),
    };
  }

  Rec copyWith({
    String? ownerId,
    String? kind,
    String? id,
    Value<String?> parentId = const Value.absent(),
    Value<String?> dayKey = const Value.absent(),
    String? body,
    int? revision,
    int? localRevision,
    String? syncState,
    Value<String?> serverBody = const Value.absent(),
    Value<String?> alternativeBody = const Value.absent(),
  }) => Rec(
    ownerId: ownerId ?? this.ownerId,
    kind: kind ?? this.kind,
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    dayKey: dayKey.present ? dayKey.value : this.dayKey,
    body: body ?? this.body,
    revision: revision ?? this.revision,
    localRevision: localRevision ?? this.localRevision,
    syncState: syncState ?? this.syncState,
    serverBody: serverBody.present ? serverBody.value : this.serverBody,
    alternativeBody: alternativeBody.present
        ? alternativeBody.value
        : this.alternativeBody,
  );
  Rec copyWithCompanion(RecordsCompanion data) {
    return Rec(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      kind: data.kind.present ? data.kind.value : this.kind,
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      body: data.body.present ? data.body.value : this.body,
      revision: data.revision.present ? data.revision.value : this.revision,
      localRevision: data.localRevision.present
          ? data.localRevision.value
          : this.localRevision,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      serverBody: data.serverBody.present
          ? data.serverBody.value
          : this.serverBody,
      alternativeBody: data.alternativeBody.present
          ? data.alternativeBody.value
          : this.alternativeBody,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Rec(')
          ..write('ownerId: $ownerId, ')
          ..write('kind: $kind, ')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('dayKey: $dayKey, ')
          ..write('body: $body, ')
          ..write('revision: $revision, ')
          ..write('localRevision: $localRevision, ')
          ..write('syncState: $syncState, ')
          ..write('serverBody: $serverBody, ')
          ..write('alternativeBody: $alternativeBody')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerId,
    kind,
    id,
    parentId,
    dayKey,
    body,
    revision,
    localRevision,
    syncState,
    serverBody,
    alternativeBody,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Rec &&
          other.ownerId == this.ownerId &&
          other.kind == this.kind &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.dayKey == this.dayKey &&
          other.body == this.body &&
          other.revision == this.revision &&
          other.localRevision == this.localRevision &&
          other.syncState == this.syncState &&
          other.serverBody == this.serverBody &&
          other.alternativeBody == this.alternativeBody);
}

class RecordsCompanion extends UpdateCompanion<Rec> {
  final Value<String> ownerId;
  final Value<String> kind;
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String?> dayKey;
  final Value<String> body;
  final Value<int> revision;
  final Value<int> localRevision;
  final Value<String> syncState;
  final Value<String?> serverBody;
  final Value<String?> alternativeBody;
  final Value<int> rowid;
  const RecordsCompanion({
    this.ownerId = const Value.absent(),
    this.kind = const Value.absent(),
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.body = const Value.absent(),
    this.revision = const Value.absent(),
    this.localRevision = const Value.absent(),
    this.syncState = const Value.absent(),
    this.serverBody = const Value.absent(),
    this.alternativeBody = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordsCompanion.insert({
    required String ownerId,
    required String kind,
    required String id,
    this.parentId = const Value.absent(),
    this.dayKey = const Value.absent(),
    required String body,
    this.revision = const Value.absent(),
    this.localRevision = const Value.absent(),
    this.syncState = const Value.absent(),
    this.serverBody = const Value.absent(),
    this.alternativeBody = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       kind = Value(kind),
       id = Value(id),
       body = Value(body);
  static Insertable<Rec> custom({
    Expression<String>? ownerId,
    Expression<String>? kind,
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? dayKey,
    Expression<String>? body,
    Expression<int>? revision,
    Expression<int>? localRevision,
    Expression<String>? syncState,
    Expression<String>? serverBody,
    Expression<String>? alternativeBody,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (kind != null) 'kind': kind,
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (dayKey != null) 'day_key': dayKey,
      if (body != null) 'body': body,
      if (revision != null) 'revision': revision,
      if (localRevision != null) 'local_revision': localRevision,
      if (syncState != null) 'sync_state': syncState,
      if (serverBody != null) 'server_body': serverBody,
      if (alternativeBody != null) 'alternative_body': alternativeBody,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordsCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? kind,
    Value<String>? id,
    Value<String?>? parentId,
    Value<String?>? dayKey,
    Value<String>? body,
    Value<int>? revision,
    Value<int>? localRevision,
    Value<String>? syncState,
    Value<String?>? serverBody,
    Value<String?>? alternativeBody,
    Value<int>? rowid,
  }) {
    return RecordsCompanion(
      ownerId: ownerId ?? this.ownerId,
      kind: kind ?? this.kind,
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      dayKey: dayKey ?? this.dayKey,
      body: body ?? this.body,
      revision: revision ?? this.revision,
      localRevision: localRevision ?? this.localRevision,
      syncState: syncState ?? this.syncState,
      serverBody: serverBody ?? this.serverBody,
      alternativeBody: alternativeBody ?? this.alternativeBody,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (localRevision.present) {
      map['local_revision'] = Variable<int>(localRevision.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (serverBody.present) {
      map['server_body'] = Variable<String>(serverBody.value);
    }
    if (alternativeBody.present) {
      map['alternative_body'] = Variable<String>(alternativeBody.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordsCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('kind: $kind, ')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('dayKey: $dayKey, ')
          ..write('body: $body, ')
          ..write('revision: $revision, ')
          ..write('localRevision: $localRevision, ')
          ..write('syncState: $syncState, ')
          ..write('serverBody: $serverBody, ')
          ..write('alternativeBody: $alternativeBody, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CommandsTable extends Commands with TableInfo<$CommandsTable, Cmd> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommandsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outboundMeta = const VerificationMeta(
    'outbound',
  );
  @override
  late final GeneratedColumn<String> outbound = GeneratedColumn<String>(
    'outbound',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetKindMeta = const VerificationMeta(
    'targetKind',
  );
  @override
  late final GeneratedColumn<String> targetKind = GeneratedColumn<String>(
    'target_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedLocalRevisionMeta =
      const VerificationMeta('capturedLocalRevision');
  @override
  late final GeneratedColumn<int> capturedLocalRevision = GeneratedColumn<int>(
    'captured_local_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dependsOnMeta = const VerificationMeta(
    'dependsOn',
  );
  @override
  late final GeneratedColumn<String> dependsOn = GeneratedColumn<String>(
    'depends_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ackMeta = const VerificationMeta('ack');
  @override
  late final GeneratedColumn<String> ack = GeneratedColumn<String>(
    'ack',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    operationId,
    ownerId,
    kind,
    method,
    path,
    payload,
    outbound,
    targetKind,
    targetId,
    capturedLocalRevision,
    dependsOn,
    state,
    attempts,
    lastError,
    ack,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'commands';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cmd> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('outbound')) {
      context.handle(
        _outboundMeta,
        outbound.isAcceptableOrUnknown(data['outbound']!, _outboundMeta),
      );
    }
    if (data.containsKey('target_kind')) {
      context.handle(
        _targetKindMeta,
        targetKind.isAcceptableOrUnknown(data['target_kind']!, _targetKindMeta),
      );
    } else if (isInserting) {
      context.missing(_targetKindMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('captured_local_revision')) {
      context.handle(
        _capturedLocalRevisionMeta,
        capturedLocalRevision.isAcceptableOrUnknown(
          data['captured_local_revision']!,
          _capturedLocalRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedLocalRevisionMeta);
    }
    if (data.containsKey('depends_on')) {
      context.handle(
        _dependsOnMeta,
        dependsOn.isAcceptableOrUnknown(data['depends_on']!, _dependsOnMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('ack')) {
      context.handle(
        _ackMeta,
        ack.isAcceptableOrUnknown(data['ack']!, _ackMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  Cmd map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cmd(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      outbound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outbound'],
      ),
      targetKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_kind'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      capturedLocalRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_local_revision'],
      )!,
      dependsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}depends_on'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      ack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ack'],
      ),
    );
  }

  @override
  $CommandsTable createAlias(String alias) {
    return $CommandsTable(attachedDatabase, alias);
  }
}

class Cmd extends DataClass implements Insertable<Cmd> {
  final int seq;
  final String operationId;
  final String ownerId;
  final String kind;
  final String method;
  final String path;
  final String payload;
  final String? outbound;
  final String targetKind;
  final String targetId;
  final int capturedLocalRevision;
  final String dependsOn;

  /// pending | accepted | conflict | rejected | superseded
  final String state;
  final int attempts;
  final String? lastError;
  final String? ack;
  const Cmd({
    required this.seq,
    required this.operationId,
    required this.ownerId,
    required this.kind,
    required this.method,
    required this.path,
    required this.payload,
    this.outbound,
    required this.targetKind,
    required this.targetId,
    required this.capturedLocalRevision,
    required this.dependsOn,
    required this.state,
    required this.attempts,
    this.lastError,
    this.ack,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['operation_id'] = Variable<String>(operationId);
    map['owner_id'] = Variable<String>(ownerId);
    map['kind'] = Variable<String>(kind);
    map['method'] = Variable<String>(method);
    map['path'] = Variable<String>(path);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || outbound != null) {
      map['outbound'] = Variable<String>(outbound);
    }
    map['target_kind'] = Variable<String>(targetKind);
    map['target_id'] = Variable<String>(targetId);
    map['captured_local_revision'] = Variable<int>(capturedLocalRevision);
    map['depends_on'] = Variable<String>(dependsOn);
    map['state'] = Variable<String>(state);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || ack != null) {
      map['ack'] = Variable<String>(ack);
    }
    return map;
  }

  CommandsCompanion toCompanion(bool nullToAbsent) {
    return CommandsCompanion(
      seq: Value(seq),
      operationId: Value(operationId),
      ownerId: Value(ownerId),
      kind: Value(kind),
      method: Value(method),
      path: Value(path),
      payload: Value(payload),
      outbound: outbound == null && nullToAbsent
          ? const Value.absent()
          : Value(outbound),
      targetKind: Value(targetKind),
      targetId: Value(targetId),
      capturedLocalRevision: Value(capturedLocalRevision),
      dependsOn: Value(dependsOn),
      state: Value(state),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      ack: ack == null && nullToAbsent ? const Value.absent() : Value(ack),
    );
  }

  factory Cmd.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cmd(
      seq: serializer.fromJson<int>(json['seq']),
      operationId: serializer.fromJson<String>(json['operationId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      kind: serializer.fromJson<String>(json['kind']),
      method: serializer.fromJson<String>(json['method']),
      path: serializer.fromJson<String>(json['path']),
      payload: serializer.fromJson<String>(json['payload']),
      outbound: serializer.fromJson<String?>(json['outbound']),
      targetKind: serializer.fromJson<String>(json['targetKind']),
      targetId: serializer.fromJson<String>(json['targetId']),
      capturedLocalRevision: serializer.fromJson<int>(
        json['capturedLocalRevision'],
      ),
      dependsOn: serializer.fromJson<String>(json['dependsOn']),
      state: serializer.fromJson<String>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      ack: serializer.fromJson<String?>(json['ack']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'operationId': serializer.toJson<String>(operationId),
      'ownerId': serializer.toJson<String>(ownerId),
      'kind': serializer.toJson<String>(kind),
      'method': serializer.toJson<String>(method),
      'path': serializer.toJson<String>(path),
      'payload': serializer.toJson<String>(payload),
      'outbound': serializer.toJson<String?>(outbound),
      'targetKind': serializer.toJson<String>(targetKind),
      'targetId': serializer.toJson<String>(targetId),
      'capturedLocalRevision': serializer.toJson<int>(capturedLocalRevision),
      'dependsOn': serializer.toJson<String>(dependsOn),
      'state': serializer.toJson<String>(state),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'ack': serializer.toJson<String?>(ack),
    };
  }

  Cmd copyWith({
    int? seq,
    String? operationId,
    String? ownerId,
    String? kind,
    String? method,
    String? path,
    String? payload,
    Value<String?> outbound = const Value.absent(),
    String? targetKind,
    String? targetId,
    int? capturedLocalRevision,
    String? dependsOn,
    String? state,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    Value<String?> ack = const Value.absent(),
  }) => Cmd(
    seq: seq ?? this.seq,
    operationId: operationId ?? this.operationId,
    ownerId: ownerId ?? this.ownerId,
    kind: kind ?? this.kind,
    method: method ?? this.method,
    path: path ?? this.path,
    payload: payload ?? this.payload,
    outbound: outbound.present ? outbound.value : this.outbound,
    targetKind: targetKind ?? this.targetKind,
    targetId: targetId ?? this.targetId,
    capturedLocalRevision: capturedLocalRevision ?? this.capturedLocalRevision,
    dependsOn: dependsOn ?? this.dependsOn,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    ack: ack.present ? ack.value : this.ack,
  );
  Cmd copyWithCompanion(CommandsCompanion data) {
    return Cmd(
      seq: data.seq.present ? data.seq.value : this.seq,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      kind: data.kind.present ? data.kind.value : this.kind,
      method: data.method.present ? data.method.value : this.method,
      path: data.path.present ? data.path.value : this.path,
      payload: data.payload.present ? data.payload.value : this.payload,
      outbound: data.outbound.present ? data.outbound.value : this.outbound,
      targetKind: data.targetKind.present
          ? data.targetKind.value
          : this.targetKind,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      capturedLocalRevision: data.capturedLocalRevision.present
          ? data.capturedLocalRevision.value
          : this.capturedLocalRevision,
      dependsOn: data.dependsOn.present ? data.dependsOn.value : this.dependsOn,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      ack: data.ack.present ? data.ack.value : this.ack,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cmd(')
          ..write('seq: $seq, ')
          ..write('operationId: $operationId, ')
          ..write('ownerId: $ownerId, ')
          ..write('kind: $kind, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('payload: $payload, ')
          ..write('outbound: $outbound, ')
          ..write('targetKind: $targetKind, ')
          ..write('targetId: $targetId, ')
          ..write('capturedLocalRevision: $capturedLocalRevision, ')
          ..write('dependsOn: $dependsOn, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('ack: $ack')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    operationId,
    ownerId,
    kind,
    method,
    path,
    payload,
    outbound,
    targetKind,
    targetId,
    capturedLocalRevision,
    dependsOn,
    state,
    attempts,
    lastError,
    ack,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cmd &&
          other.seq == this.seq &&
          other.operationId == this.operationId &&
          other.ownerId == this.ownerId &&
          other.kind == this.kind &&
          other.method == this.method &&
          other.path == this.path &&
          other.payload == this.payload &&
          other.outbound == this.outbound &&
          other.targetKind == this.targetKind &&
          other.targetId == this.targetId &&
          other.capturedLocalRevision == this.capturedLocalRevision &&
          other.dependsOn == this.dependsOn &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.ack == this.ack);
}

class CommandsCompanion extends UpdateCompanion<Cmd> {
  final Value<int> seq;
  final Value<String> operationId;
  final Value<String> ownerId;
  final Value<String> kind;
  final Value<String> method;
  final Value<String> path;
  final Value<String> payload;
  final Value<String?> outbound;
  final Value<String> targetKind;
  final Value<String> targetId;
  final Value<int> capturedLocalRevision;
  final Value<String> dependsOn;
  final Value<String> state;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<String?> ack;
  const CommandsCompanion({
    this.seq = const Value.absent(),
    this.operationId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.kind = const Value.absent(),
    this.method = const Value.absent(),
    this.path = const Value.absent(),
    this.payload = const Value.absent(),
    this.outbound = const Value.absent(),
    this.targetKind = const Value.absent(),
    this.targetId = const Value.absent(),
    this.capturedLocalRevision = const Value.absent(),
    this.dependsOn = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.ack = const Value.absent(),
  });
  CommandsCompanion.insert({
    this.seq = const Value.absent(),
    required String operationId,
    required String ownerId,
    required String kind,
    required String method,
    required String path,
    required String payload,
    this.outbound = const Value.absent(),
    required String targetKind,
    required String targetId,
    required int capturedLocalRevision,
    this.dependsOn = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.ack = const Value.absent(),
  }) : operationId = Value(operationId),
       ownerId = Value(ownerId),
       kind = Value(kind),
       method = Value(method),
       path = Value(path),
       payload = Value(payload),
       targetKind = Value(targetKind),
       targetId = Value(targetId),
       capturedLocalRevision = Value(capturedLocalRevision);
  static Insertable<Cmd> custom({
    Expression<int>? seq,
    Expression<String>? operationId,
    Expression<String>? ownerId,
    Expression<String>? kind,
    Expression<String>? method,
    Expression<String>? path,
    Expression<String>? payload,
    Expression<String>? outbound,
    Expression<String>? targetKind,
    Expression<String>? targetId,
    Expression<int>? capturedLocalRevision,
    Expression<String>? dependsOn,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<String>? ack,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (operationId != null) 'operation_id': operationId,
      if (ownerId != null) 'owner_id': ownerId,
      if (kind != null) 'kind': kind,
      if (method != null) 'method': method,
      if (path != null) 'path': path,
      if (payload != null) 'payload': payload,
      if (outbound != null) 'outbound': outbound,
      if (targetKind != null) 'target_kind': targetKind,
      if (targetId != null) 'target_id': targetId,
      if (capturedLocalRevision != null)
        'captured_local_revision': capturedLocalRevision,
      if (dependsOn != null) 'depends_on': dependsOn,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (ack != null) 'ack': ack,
    });
  }

  CommandsCompanion copyWith({
    Value<int>? seq,
    Value<String>? operationId,
    Value<String>? ownerId,
    Value<String>? kind,
    Value<String>? method,
    Value<String>? path,
    Value<String>? payload,
    Value<String?>? outbound,
    Value<String>? targetKind,
    Value<String>? targetId,
    Value<int>? capturedLocalRevision,
    Value<String>? dependsOn,
    Value<String>? state,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<String?>? ack,
  }) {
    return CommandsCompanion(
      seq: seq ?? this.seq,
      operationId: operationId ?? this.operationId,
      ownerId: ownerId ?? this.ownerId,
      kind: kind ?? this.kind,
      method: method ?? this.method,
      path: path ?? this.path,
      payload: payload ?? this.payload,
      outbound: outbound ?? this.outbound,
      targetKind: targetKind ?? this.targetKind,
      targetId: targetId ?? this.targetId,
      capturedLocalRevision:
          capturedLocalRevision ?? this.capturedLocalRevision,
      dependsOn: dependsOn ?? this.dependsOn,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      ack: ack ?? this.ack,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (outbound.present) {
      map['outbound'] = Variable<String>(outbound.value);
    }
    if (targetKind.present) {
      map['target_kind'] = Variable<String>(targetKind.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (capturedLocalRevision.present) {
      map['captured_local_revision'] = Variable<int>(
        capturedLocalRevision.value,
      );
    }
    if (dependsOn.present) {
      map['depends_on'] = Variable<String>(dependsOn.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (ack.present) {
      map['ack'] = Variable<String>(ack.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommandsCompanion(')
          ..write('seq: $seq, ')
          ..write('operationId: $operationId, ')
          ..write('ownerId: $ownerId, ')
          ..write('kind: $kind, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('payload: $payload, ')
          ..write('outbound: $outbound, ')
          ..write('targetKind: $targetKind, ')
          ..write('targetId: $targetId, ')
          ..write('capturedLocalRevision: $capturedLocalRevision, ')
          ..write('dependsOn: $dependsOn, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('ack: $ack')
          ..write(')'))
        .toString();
  }
}

class $TrackEntriesTable extends TrackEntries
    with TableInfo<$TrackEntriesTable, TrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _segmentMeta = const VerificationMeta(
    'segment',
  );
  @override
  late final GeneratedColumn<int> segment = GeneratedColumn<int>(
    'segment',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tMeta = const VerificationMeta('t');
  @override
  late final GeneratedColumn<int> t = GeneratedColumn<int>(
    't',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accMeta = const VerificationMeta('acc');
  @override
  late final GeneratedColumn<double> acc = GeneratedColumn<double>(
    'acc',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _altMeta = const VerificationMeta('alt');
  @override
  late final GeneratedColumn<double> alt = GeneratedColumn<double>(
    'alt',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _altAccMeta = const VerificationMeta('altAcc');
  @override
  late final GeneratedColumn<double> altAcc = GeneratedColumn<double>(
    'alt_acc',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedAccMeta = const VerificationMeta(
    'speedAcc',
  );
  @override
  late final GeneratedColumn<double> speedAcc = GeneratedColumn<double>(
    'speed_acc',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headingMeta = const VerificationMeta(
    'heading',
  );
  @override
  late final GeneratedColumn<double> heading = GeneratedColumn<double>(
    'heading',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
    'meta',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    activityId,
    seq,
    type,
    segment,
    t,
    lat,
    lon,
    acc,
    alt,
    altAcc,
    speed,
    speedAcc,
    heading,
    meta,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('segment')) {
      context.handle(
        _segmentMeta,
        segment.isAcceptableOrUnknown(data['segment']!, _segmentMeta),
      );
    } else if (isInserting) {
      context.missing(_segmentMeta);
    }
    if (data.containsKey('t')) {
      context.handle(_tMeta, t.isAcceptableOrUnknown(data['t']!, _tMeta));
    } else if (isInserting) {
      context.missing(_tMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lon')) {
      context.handle(
        _lonMeta,
        lon.isAcceptableOrUnknown(data['lon']!, _lonMeta),
      );
    }
    if (data.containsKey('acc')) {
      context.handle(
        _accMeta,
        acc.isAcceptableOrUnknown(data['acc']!, _accMeta),
      );
    }
    if (data.containsKey('alt')) {
      context.handle(
        _altMeta,
        alt.isAcceptableOrUnknown(data['alt']!, _altMeta),
      );
    }
    if (data.containsKey('alt_acc')) {
      context.handle(
        _altAccMeta,
        altAcc.isAcceptableOrUnknown(data['alt_acc']!, _altAccMeta),
      );
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    if (data.containsKey('speed_acc')) {
      context.handle(
        _speedAccMeta,
        speedAcc.isAcceptableOrUnknown(data['speed_acc']!, _speedAccMeta),
      );
    }
    if (data.containsKey('heading')) {
      context.handle(
        _headingMeta,
        heading.isAcceptableOrUnknown(data['heading']!, _headingMeta),
      );
    }
    if (data.containsKey('meta')) {
      context.handle(
        _metaMeta,
        meta.isAcceptableOrUnknown(data['meta']!, _metaMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, activityId, seq};
  @override
  TrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackRow(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      segment: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment'],
      )!,
      t: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}t'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lon'],
      ),
      acc: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}acc'],
      ),
      alt: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}alt'],
      ),
      altAcc: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}alt_acc'],
      ),
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      ),
      speedAcc: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed_acc'],
      ),
      heading: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}heading'],
      ),
      meta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta'],
      ),
    );
  }

  @override
  $TrackEntriesTable createAlias(String alias) {
    return $TrackEntriesTable(attachedDatabase, alias);
  }
}

class TrackRow extends DataClass implements Insertable<TrackRow> {
  final String ownerId;
  final String activityId;
  final int seq;
  final String type;
  final int segment;

  /// UTC epoch milliseconds.
  final int t;
  final double? lat;
  final double? lon;
  final double? acc;
  final double? alt;
  final double? altAcc;
  final double? speed;
  final double? speedAcc;
  final double? heading;

  /// Event details as JSON (legacy distance/time, interruption reason).
  final String? meta;
  const TrackRow({
    required this.ownerId,
    required this.activityId,
    required this.seq,
    required this.type,
    required this.segment,
    required this.t,
    this.lat,
    this.lon,
    this.acc,
    this.alt,
    this.altAcc,
    this.speed,
    this.speedAcc,
    this.heading,
    this.meta,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['activity_id'] = Variable<String>(activityId);
    map['seq'] = Variable<int>(seq);
    map['type'] = Variable<String>(type);
    map['segment'] = Variable<int>(segment);
    map['t'] = Variable<int>(t);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lon != null) {
      map['lon'] = Variable<double>(lon);
    }
    if (!nullToAbsent || acc != null) {
      map['acc'] = Variable<double>(acc);
    }
    if (!nullToAbsent || alt != null) {
      map['alt'] = Variable<double>(alt);
    }
    if (!nullToAbsent || altAcc != null) {
      map['alt_acc'] = Variable<double>(altAcc);
    }
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<double>(speed);
    }
    if (!nullToAbsent || speedAcc != null) {
      map['speed_acc'] = Variable<double>(speedAcc);
    }
    if (!nullToAbsent || heading != null) {
      map['heading'] = Variable<double>(heading);
    }
    if (!nullToAbsent || meta != null) {
      map['meta'] = Variable<String>(meta);
    }
    return map;
  }

  TrackEntriesCompanion toCompanion(bool nullToAbsent) {
    return TrackEntriesCompanion(
      ownerId: Value(ownerId),
      activityId: Value(activityId),
      seq: Value(seq),
      type: Value(type),
      segment: Value(segment),
      t: Value(t),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lon: lon == null && nullToAbsent ? const Value.absent() : Value(lon),
      acc: acc == null && nullToAbsent ? const Value.absent() : Value(acc),
      alt: alt == null && nullToAbsent ? const Value.absent() : Value(alt),
      altAcc: altAcc == null && nullToAbsent
          ? const Value.absent()
          : Value(altAcc),
      speed: speed == null && nullToAbsent
          ? const Value.absent()
          : Value(speed),
      speedAcc: speedAcc == null && nullToAbsent
          ? const Value.absent()
          : Value(speedAcc),
      heading: heading == null && nullToAbsent
          ? const Value.absent()
          : Value(heading),
      meta: meta == null && nullToAbsent ? const Value.absent() : Value(meta),
    );
  }

  factory TrackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackRow(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      activityId: serializer.fromJson<String>(json['activityId']),
      seq: serializer.fromJson<int>(json['seq']),
      type: serializer.fromJson<String>(json['type']),
      segment: serializer.fromJson<int>(json['segment']),
      t: serializer.fromJson<int>(json['t']),
      lat: serializer.fromJson<double?>(json['lat']),
      lon: serializer.fromJson<double?>(json['lon']),
      acc: serializer.fromJson<double?>(json['acc']),
      alt: serializer.fromJson<double?>(json['alt']),
      altAcc: serializer.fromJson<double?>(json['altAcc']),
      speed: serializer.fromJson<double?>(json['speed']),
      speedAcc: serializer.fromJson<double?>(json['speedAcc']),
      heading: serializer.fromJson<double?>(json['heading']),
      meta: serializer.fromJson<String?>(json['meta']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'activityId': serializer.toJson<String>(activityId),
      'seq': serializer.toJson<int>(seq),
      'type': serializer.toJson<String>(type),
      'segment': serializer.toJson<int>(segment),
      't': serializer.toJson<int>(t),
      'lat': serializer.toJson<double?>(lat),
      'lon': serializer.toJson<double?>(lon),
      'acc': serializer.toJson<double?>(acc),
      'alt': serializer.toJson<double?>(alt),
      'altAcc': serializer.toJson<double?>(altAcc),
      'speed': serializer.toJson<double?>(speed),
      'speedAcc': serializer.toJson<double?>(speedAcc),
      'heading': serializer.toJson<double?>(heading),
      'meta': serializer.toJson<String?>(meta),
    };
  }

  TrackRow copyWith({
    String? ownerId,
    String? activityId,
    int? seq,
    String? type,
    int? segment,
    int? t,
    Value<double?> lat = const Value.absent(),
    Value<double?> lon = const Value.absent(),
    Value<double?> acc = const Value.absent(),
    Value<double?> alt = const Value.absent(),
    Value<double?> altAcc = const Value.absent(),
    Value<double?> speed = const Value.absent(),
    Value<double?> speedAcc = const Value.absent(),
    Value<double?> heading = const Value.absent(),
    Value<String?> meta = const Value.absent(),
  }) => TrackRow(
    ownerId: ownerId ?? this.ownerId,
    activityId: activityId ?? this.activityId,
    seq: seq ?? this.seq,
    type: type ?? this.type,
    segment: segment ?? this.segment,
    t: t ?? this.t,
    lat: lat.present ? lat.value : this.lat,
    lon: lon.present ? lon.value : this.lon,
    acc: acc.present ? acc.value : this.acc,
    alt: alt.present ? alt.value : this.alt,
    altAcc: altAcc.present ? altAcc.value : this.altAcc,
    speed: speed.present ? speed.value : this.speed,
    speedAcc: speedAcc.present ? speedAcc.value : this.speedAcc,
    heading: heading.present ? heading.value : this.heading,
    meta: meta.present ? meta.value : this.meta,
  );
  TrackRow copyWithCompanion(TrackEntriesCompanion data) {
    return TrackRow(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      seq: data.seq.present ? data.seq.value : this.seq,
      type: data.type.present ? data.type.value : this.type,
      segment: data.segment.present ? data.segment.value : this.segment,
      t: data.t.present ? data.t.value : this.t,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      acc: data.acc.present ? data.acc.value : this.acc,
      alt: data.alt.present ? data.alt.value : this.alt,
      altAcc: data.altAcc.present ? data.altAcc.value : this.altAcc,
      speed: data.speed.present ? data.speed.value : this.speed,
      speedAcc: data.speedAcc.present ? data.speedAcc.value : this.speedAcc,
      heading: data.heading.present ? data.heading.value : this.heading,
      meta: data.meta.present ? data.meta.value : this.meta,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackRow(')
          ..write('ownerId: $ownerId, ')
          ..write('activityId: $activityId, ')
          ..write('seq: $seq, ')
          ..write('type: $type, ')
          ..write('segment: $segment, ')
          ..write('t: $t, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('acc: $acc, ')
          ..write('alt: $alt, ')
          ..write('altAcc: $altAcc, ')
          ..write('speed: $speed, ')
          ..write('speedAcc: $speedAcc, ')
          ..write('heading: $heading, ')
          ..write('meta: $meta')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerId,
    activityId,
    seq,
    type,
    segment,
    t,
    lat,
    lon,
    acc,
    alt,
    altAcc,
    speed,
    speedAcc,
    heading,
    meta,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackRow &&
          other.ownerId == this.ownerId &&
          other.activityId == this.activityId &&
          other.seq == this.seq &&
          other.type == this.type &&
          other.segment == this.segment &&
          other.t == this.t &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.acc == this.acc &&
          other.alt == this.alt &&
          other.altAcc == this.altAcc &&
          other.speed == this.speed &&
          other.speedAcc == this.speedAcc &&
          other.heading == this.heading &&
          other.meta == this.meta);
}

class TrackEntriesCompanion extends UpdateCompanion<TrackRow> {
  final Value<String> ownerId;
  final Value<String> activityId;
  final Value<int> seq;
  final Value<String> type;
  final Value<int> segment;
  final Value<int> t;
  final Value<double?> lat;
  final Value<double?> lon;
  final Value<double?> acc;
  final Value<double?> alt;
  final Value<double?> altAcc;
  final Value<double?> speed;
  final Value<double?> speedAcc;
  final Value<double?> heading;
  final Value<String?> meta;
  final Value<int> rowid;
  const TrackEntriesCompanion({
    this.ownerId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.seq = const Value.absent(),
    this.type = const Value.absent(),
    this.segment = const Value.absent(),
    this.t = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.acc = const Value.absent(),
    this.alt = const Value.absent(),
    this.altAcc = const Value.absent(),
    this.speed = const Value.absent(),
    this.speedAcc = const Value.absent(),
    this.heading = const Value.absent(),
    this.meta = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackEntriesCompanion.insert({
    required String ownerId,
    required String activityId,
    required int seq,
    required String type,
    required int segment,
    required int t,
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.acc = const Value.absent(),
    this.alt = const Value.absent(),
    this.altAcc = const Value.absent(),
    this.speed = const Value.absent(),
    this.speedAcc = const Value.absent(),
    this.heading = const Value.absent(),
    this.meta = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       activityId = Value(activityId),
       seq = Value(seq),
       type = Value(type),
       segment = Value(segment),
       t = Value(t);
  static Insertable<TrackRow> custom({
    Expression<String>? ownerId,
    Expression<String>? activityId,
    Expression<int>? seq,
    Expression<String>? type,
    Expression<int>? segment,
    Expression<int>? t,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<double>? acc,
    Expression<double>? alt,
    Expression<double>? altAcc,
    Expression<double>? speed,
    Expression<double>? speedAcc,
    Expression<double>? heading,
    Expression<String>? meta,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (activityId != null) 'activity_id': activityId,
      if (seq != null) 'seq': seq,
      if (type != null) 'type': type,
      if (segment != null) 'segment': segment,
      if (t != null) 't': t,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (acc != null) 'acc': acc,
      if (alt != null) 'alt': alt,
      if (altAcc != null) 'alt_acc': altAcc,
      if (speed != null) 'speed': speed,
      if (speedAcc != null) 'speed_acc': speedAcc,
      if (heading != null) 'heading': heading,
      if (meta != null) 'meta': meta,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackEntriesCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? activityId,
    Value<int>? seq,
    Value<String>? type,
    Value<int>? segment,
    Value<int>? t,
    Value<double?>? lat,
    Value<double?>? lon,
    Value<double?>? acc,
    Value<double?>? alt,
    Value<double?>? altAcc,
    Value<double?>? speed,
    Value<double?>? speedAcc,
    Value<double?>? heading,
    Value<String?>? meta,
    Value<int>? rowid,
  }) {
    return TrackEntriesCompanion(
      ownerId: ownerId ?? this.ownerId,
      activityId: activityId ?? this.activityId,
      seq: seq ?? this.seq,
      type: type ?? this.type,
      segment: segment ?? this.segment,
      t: t ?? this.t,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      acc: acc ?? this.acc,
      alt: alt ?? this.alt,
      altAcc: altAcc ?? this.altAcc,
      speed: speed ?? this.speed,
      speedAcc: speedAcc ?? this.speedAcc,
      heading: heading ?? this.heading,
      meta: meta ?? this.meta,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (segment.present) {
      map['segment'] = Variable<int>(segment.value);
    }
    if (t.present) {
      map['t'] = Variable<int>(t.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (acc.present) {
      map['acc'] = Variable<double>(acc.value);
    }
    if (alt.present) {
      map['alt'] = Variable<double>(alt.value);
    }
    if (altAcc.present) {
      map['alt_acc'] = Variable<double>(altAcc.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (speedAcc.present) {
      map['speed_acc'] = Variable<double>(speedAcc.value);
    }
    if (heading.present) {
      map['heading'] = Variable<double>(heading.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackEntriesCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('activityId: $activityId, ')
          ..write('seq: $seq, ')
          ..write('type: $type, ')
          ..write('segment: $segment, ')
          ..write('t: $t, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('acc: $acc, ')
          ..write('alt: $alt, ')
          ..write('altAcc: $altAcc, ')
          ..write('speed: $speed, ')
          ..write('speedAcc: $speedAcc, ')
          ..write('heading: $heading, ')
          ..write('meta: $meta, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $RecordsTable records = $RecordsTable(this);
  late final $CommandsTable commands = $CommandsTable(this);
  late final $TrackEntriesTable trackEntries = $TrackEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    records,
    commands,
    trackEntries,
  ];
}

typedef $$RecordsTableCreateCompanionBuilder = RecordsCompanion Function({
  required String ownerId,
  required String kind,
  required String id,
  Value<String?> parentId,
  Value<String?> dayKey,
  required String body,
  Value<int> revision,
  Value<int> localRevision,
  Value<String> syncState,
  Value<String?> serverBody,
  Value<String?> alternativeBody,
  Value<int> rowid,
});
typedef $$RecordsTableUpdateCompanionBuilder = RecordsCompanion Function({
  Value<String> ownerId,
  Value<String> kind,
  Value<String> id,
  Value<String?> parentId,
  Value<String?> dayKey,
  Value<String> body,
  Value<int> revision,
  Value<int> localRevision,
  Value<String> syncState,
  Value<String?> serverBody,
  Value<String?> alternativeBody,
  Value<int> rowid,
});

class $$RecordsTableFilterComposer extends Composer<_$AppDb, $RecordsTable> {
  $$RecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverBody => $composableBuilder(
    column: $table.serverBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alternativeBody => $composableBuilder(
    column: $table.alternativeBody,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecordsTableOrderingComposer extends Composer<_$AppDb, $RecordsTable> {
  $$RecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverBody => $composableBuilder(
    column: $table.serverBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alternativeBody => $composableBuilder(
    column: $table.alternativeBody,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordsTableAnnotationComposer
    extends Composer<_$AppDb, $RecordsTable> {
  $$RecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get localRevision => $composableBuilder(
    column: $table.localRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get serverBody => $composableBuilder(
    column: $table.serverBody,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alternativeBody => $composableBuilder(
    column: $table.alternativeBody,
    builder: (column) => column,
  );
}

class $$RecordsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $RecordsTable,
          Rec,
          $$RecordsTableFilterComposer,
          $$RecordsTableOrderingComposer,
          $$RecordsTableAnnotationComposer,
          $$RecordsTableCreateCompanionBuilder,
          $$RecordsTableUpdateCompanionBuilder,
          (Rec, BaseReferences<_$AppDb, $RecordsTable, Rec>),
          Rec,
          PrefetchHooks Function()
        > {
  $$RecordsTableTableManager(_$AppDb db, $RecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String?> dayKey = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> localRevision = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String?> serverBody = const Value.absent(),
                Value<String?> alternativeBody = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion(
                ownerId: ownerId,
                kind: kind,
                id: id,
                parentId: parentId,
                dayKey: dayKey,
                body: body,
                revision: revision,
                localRevision: localRevision,
                syncState: syncState,
                serverBody: serverBody,
                alternativeBody: alternativeBody,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String kind,
                required String id,
                Value<String?> parentId = const Value.absent(),
                Value<String?> dayKey = const Value.absent(),
                required String body,
                Value<int> revision = const Value.absent(),
                Value<int> localRevision = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String?> serverBody = const Value.absent(),
                Value<String?> alternativeBody = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion.insert(
                ownerId: ownerId,
                kind: kind,
                id: id,
                parentId: parentId,
                dayKey: dayKey,
                body: body,
                revision: revision,
                localRevision: localRevision,
                syncState: syncState,
                serverBody: serverBody,
                alternativeBody: alternativeBody,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecordsTable, Rec>(table),
                  BaseReferences<_$AppDb, $RecordsTable, Rec>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $RecordsTable,
      Rec,
      $$RecordsTableFilterComposer,
      $$RecordsTableOrderingComposer,
      $$RecordsTableAnnotationComposer,
      $$RecordsTableCreateCompanionBuilder,
      $$RecordsTableUpdateCompanionBuilder,
      (Rec, BaseReferences<_$AppDb, $RecordsTable, Rec>),
      Rec,
      PrefetchHooks Function()
    >;
typedef $$CommandsTableCreateCompanionBuilder = CommandsCompanion Function({
  Value<int> seq,
  required String operationId,
  required String ownerId,
  required String kind,
  required String method,
  required String path,
  required String payload,
  Value<String?> outbound,
  required String targetKind,
  required String targetId,
  required int capturedLocalRevision,
  Value<String> dependsOn,
  Value<String> state,
  Value<int> attempts,
  Value<String?> lastError,
  Value<String?> ack,
});
typedef $$CommandsTableUpdateCompanionBuilder = CommandsCompanion Function({
  Value<int> seq,
  Value<String> operationId,
  Value<String> ownerId,
  Value<String> kind,
  Value<String> method,
  Value<String> path,
  Value<String> payload,
  Value<String?> outbound,
  Value<String> targetKind,
  Value<String> targetId,
  Value<int> capturedLocalRevision,
  Value<String> dependsOn,
  Value<String> state,
  Value<int> attempts,
  Value<String?> lastError,
  Value<String?> ack,
});

class $$CommandsTableFilterComposer extends Composer<_$AppDb, $CommandsTable> {
  $$CommandsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outbound => $composableBuilder(
    column: $table.outbound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedLocalRevision => $composableBuilder(
    column: $table.capturedLocalRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dependsOn => $composableBuilder(
    column: $table.dependsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ack => $composableBuilder(
    column: $table.ack,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CommandsTableOrderingComposer
    extends Composer<_$AppDb, $CommandsTable> {
  $$CommandsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outbound => $composableBuilder(
    column: $table.outbound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedLocalRevision => $composableBuilder(
    column: $table.capturedLocalRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dependsOn => $composableBuilder(
    column: $table.dependsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ack => $composableBuilder(
    column: $table.ack,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CommandsTableAnnotationComposer
    extends Composer<_$AppDb, $CommandsTable> {
  $$CommandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get outbound =>
      $composableBuilder(column: $table.outbound, builder: (column) => column);

  GeneratedColumn<String> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<int> get capturedLocalRevision => $composableBuilder(
    column: $table.capturedLocalRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dependsOn =>
      $composableBuilder(column: $table.dependsOn, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get ack =>
      $composableBuilder(column: $table.ack, builder: (column) => column);
}

class $$CommandsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CommandsTable,
          Cmd,
          $$CommandsTableFilterComposer,
          $$CommandsTableOrderingComposer,
          $$CommandsTableAnnotationComposer,
          $$CommandsTableCreateCompanionBuilder,
          $$CommandsTableUpdateCompanionBuilder,
          (Cmd, BaseReferences<_$AppDb, $CommandsTable, Cmd>),
          Cmd,
          PrefetchHooks Function()
        > {
  $$CommandsTableTableManager(_$AppDb db, $CommandsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommandsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String?> outbound = const Value.absent(),
                Value<String> targetKind = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<int> capturedLocalRevision = const Value.absent(),
                Value<String> dependsOn = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> ack = const Value.absent(),
              }) => CommandsCompanion(
                seq: seq,
                operationId: operationId,
                ownerId: ownerId,
                kind: kind,
                method: method,
                path: path,
                payload: payload,
                outbound: outbound,
                targetKind: targetKind,
                targetId: targetId,
                capturedLocalRevision: capturedLocalRevision,
                dependsOn: dependsOn,
                state: state,
                attempts: attempts,
                lastError: lastError,
                ack: ack,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String operationId,
                required String ownerId,
                required String kind,
                required String method,
                required String path,
                required String payload,
                Value<String?> outbound = const Value.absent(),
                required String targetKind,
                required String targetId,
                required int capturedLocalRevision,
                Value<String> dependsOn = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> ack = const Value.absent(),
              }) => CommandsCompanion.insert(
                seq: seq,
                operationId: operationId,
                ownerId: ownerId,
                kind: kind,
                method: method,
                path: path,
                payload: payload,
                outbound: outbound,
                targetKind: targetKind,
                targetId: targetId,
                capturedLocalRevision: capturedLocalRevision,
                dependsOn: dependsOn,
                state: state,
                attempts: attempts,
                lastError: lastError,
                ack: ack,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CommandsTable, Cmd>(table),
                  BaseReferences<_$AppDb, $CommandsTable, Cmd>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CommandsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CommandsTable,
      Cmd,
      $$CommandsTableFilterComposer,
      $$CommandsTableOrderingComposer,
      $$CommandsTableAnnotationComposer,
      $$CommandsTableCreateCompanionBuilder,
      $$CommandsTableUpdateCompanionBuilder,
      (Cmd, BaseReferences<_$AppDb, $CommandsTable, Cmd>),
      Cmd,
      PrefetchHooks Function()
    >;
typedef $$TrackEntriesTableCreateCompanionBuilder =
    TrackEntriesCompanion Function({
      required String ownerId,
      required String activityId,
      required int seq,
      required String type,
      required int segment,
      required int t,
      Value<double?> lat,
      Value<double?> lon,
      Value<double?> acc,
      Value<double?> alt,
      Value<double?> altAcc,
      Value<double?> speed,
      Value<double?> speedAcc,
      Value<double?> heading,
      Value<String?> meta,
      Value<int> rowid,
    });
typedef $$TrackEntriesTableUpdateCompanionBuilder =
    TrackEntriesCompanion Function({
      Value<String> ownerId,
      Value<String> activityId,
      Value<int> seq,
      Value<String> type,
      Value<int> segment,
      Value<int> t,
      Value<double?> lat,
      Value<double?> lon,
      Value<double?> acc,
      Value<double?> alt,
      Value<double?> altAcc,
      Value<double?> speed,
      Value<double?> speedAcc,
      Value<double?> heading,
      Value<String?> meta,
      Value<int> rowid,
    });

class $$TrackEntriesTableFilterComposer
    extends Composer<_$AppDb, $TrackEntriesTable> {
  $$TrackEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segment => $composableBuilder(
    column: $table.segment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get t => $composableBuilder(
    column: $table.t,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get acc => $composableBuilder(
    column: $table.acc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get alt => $composableBuilder(
    column: $table.alt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get altAcc => $composableBuilder(
    column: $table.altAcc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speedAcc => $composableBuilder(
    column: $table.speedAcc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heading => $composableBuilder(
    column: $table.heading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrackEntriesTableOrderingComposer
    extends Composer<_$AppDb, $TrackEntriesTable> {
  $$TrackEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segment => $composableBuilder(
    column: $table.segment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get t => $composableBuilder(
    column: $table.t,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get acc => $composableBuilder(
    column: $table.acc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get alt => $composableBuilder(
    column: $table.alt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get altAcc => $composableBuilder(
    column: $table.altAcc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speedAcc => $composableBuilder(
    column: $table.speedAcc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heading => $composableBuilder(
    column: $table.heading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackEntriesTableAnnotationComposer
    extends Composer<_$AppDb, $TrackEntriesTable> {
  $$TrackEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get segment =>
      $composableBuilder(column: $table.segment, builder: (column) => column);

  GeneratedColumn<int> get t =>
      $composableBuilder(column: $table.t, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<double> get acc =>
      $composableBuilder(column: $table.acc, builder: (column) => column);

  GeneratedColumn<double> get alt =>
      $composableBuilder(column: $table.alt, builder: (column) => column);

  GeneratedColumn<double> get altAcc =>
      $composableBuilder(column: $table.altAcc, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<double> get speedAcc =>
      $composableBuilder(column: $table.speedAcc, builder: (column) => column);

  GeneratedColumn<double> get heading =>
      $composableBuilder(column: $table.heading, builder: (column) => column);

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);
}

class $$TrackEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $TrackEntriesTable,
          TrackRow,
          $$TrackEntriesTableFilterComposer,
          $$TrackEntriesTableOrderingComposer,
          $$TrackEntriesTableAnnotationComposer,
          $$TrackEntriesTableCreateCompanionBuilder,
          $$TrackEntriesTableUpdateCompanionBuilder,
          (TrackRow, BaseReferences<_$AppDb, $TrackEntriesTable, TrackRow>),
          TrackRow,
          PrefetchHooks Function()
        > {
  $$TrackEntriesTableTableManager(_$AppDb db, $TrackEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> segment = const Value.absent(),
                Value<int> t = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<double?> acc = const Value.absent(),
                Value<double?> alt = const Value.absent(),
                Value<double?> altAcc = const Value.absent(),
                Value<double?> speed = const Value.absent(),
                Value<double?> speedAcc = const Value.absent(),
                Value<double?> heading = const Value.absent(),
                Value<String?> meta = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackEntriesCompanion(
                ownerId: ownerId,
                activityId: activityId,
                seq: seq,
                type: type,
                segment: segment,
                t: t,
                lat: lat,
                lon: lon,
                acc: acc,
                alt: alt,
                altAcc: altAcc,
                speed: speed,
                speedAcc: speedAcc,
                heading: heading,
                meta: meta,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String activityId,
                required int seq,
                required String type,
                required int segment,
                required int t,
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<double?> acc = const Value.absent(),
                Value<double?> alt = const Value.absent(),
                Value<double?> altAcc = const Value.absent(),
                Value<double?> speed = const Value.absent(),
                Value<double?> speedAcc = const Value.absent(),
                Value<double?> heading = const Value.absent(),
                Value<String?> meta = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackEntriesCompanion.insert(
                ownerId: ownerId,
                activityId: activityId,
                seq: seq,
                type: type,
                segment: segment,
                t: t,
                lat: lat,
                lon: lon,
                acc: acc,
                alt: alt,
                altAcc: altAcc,
                speed: speed,
                speedAcc: speedAcc,
                heading: heading,
                meta: meta,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackEntriesTable, TrackRow>(table),
                  BaseReferences<_$AppDb, $TrackEntriesTable, TrackRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrackEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $TrackEntriesTable,
      TrackRow,
      $$TrackEntriesTableFilterComposer,
      $$TrackEntriesTableOrderingComposer,
      $$TrackEntriesTableAnnotationComposer,
      $$TrackEntriesTableCreateCompanionBuilder,
      $$TrackEntriesTableUpdateCompanionBuilder,
      (TrackRow, BaseReferences<_$AppDb, $TrackEntriesTable, TrackRow>),
      TrackRow,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$RecordsTableTableManager get records =>
      $$RecordsTableTableManager(_db, _db.records);
  $$CommandsTableTableManager get commands =>
      $$CommandsTableTableManager(_db, _db.commands);
  $$TrackEntriesTableTableManager get trackEntries =>
      $$TrackEntriesTableTableManager(_db, _db.trackEntries);
}
