import 'dart:convert';

import '../../core/clock.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import 'plan_draft.dart';
import 'plan_projection.dart';
import 'plan_rules.dart';
import 'schedule_rules.dart';

/// The outcome of a plan request that needs the account (draft creation, proposals).
class PlanAnswer {
  const PlanAnswer(this.state, {this.code, this.data});

  /// accepted | conflict | rejected | pending (the account could not be reached; nothing was lost)
  final String state;
  final String? code;
  final Json? data;
  bool get accepted => state == 'accepted';
  bool get unreachable => state == 'pending';
}

/// A reviewed local decision could not be made because the schedule rules refuse it.
class ScheduleRefused implements Exception {
  const ScheduleRefused(this.codes);
  final List<String> codes;
  String get message => ScheduleRules.describe(codes.first);
}

/// Projects a plan's occasions for validation. An occasion is open while an unfinished workout is attached.
List<ScheduleOccasion> scheduleOf(Plan plan, Iterable<Workout> workouts) {
  final open = {for (final w in workouts) if (w.isOpen && w.occasionId != null) w.occasionId};
  final credited = {for (final w in workouts) if (!w.isDeleted && w.qualifiedOccasion) w.occasionId};
  return [
    for (final o in plan.occasions)
      ScheduleOccasion(id: o.id, originalDate: o.originalDate, scheduledDate: o.scheduledDate, weekNumber: o.weekNumber,
          isSkipped: o.isSkipped, isRecorded: o.isRecorded || credited.contains(o.id), isOpen: open.contains(o.id)),
  ];
}

/// Plan decisions are saved on the phone first, atomically with their command, and stay provisional until
/// the account acknowledges them. Commands that change the primary context are serialized on the context
/// record; schedule edits wait behind them.
class PlanRepository {
  PlanRepository(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;

  static const _setupDraftId = 'current';
  (String, String) get _ctx => (Kinds.context, _owner);
  Json get _ctxRev => {r'$rev': [Kinds.context, _owner]};
  Json _planRev(String id) => {r'$rev': [Kinds.plan, id]};

  Future<Json> _contextBody() async {
    final rec = await _sync.get(_owner, Kinds.context, _owner);
    return rec == null ? {'contextRevision': 0, 'primaryPlanId': null} : jsonDecode(rec.body) as Json;
  }

  Future<Plan?> _plan(String? id) async {
    final rec = id == null ? null : await _sync.get(_owner, Kinds.plan, id);
    return rec == null ? null : Plan(jsonDecode(rec.body) as Json);
  }

  Future<PlanAnswer> _answer(Cmd cmd) async {
    final ack = cmd.ack == null ? null : jsonDecode(cmd.ack!) as Json;
    // These requests changed nothing locally, so a refusal is simply reported; it never lingers as a blocker.
    if (cmd.state == 'conflict' || cmd.state == 'rejected') await _sync.abandon(cmd.operationId);
    return PlanAnswer(cmd.state, code: cmd.lastError, data: ack?['data'] as Json?);
  }

  // ------------------------------------------------------------------ setup and drafts

  /// The retained setup answers (never asked again once given) and any request still in flight.
  Future<Json?> savedSetup() async {
    final rec = await _sync.get(_owner, Kinds.setupDraft, _setupDraftId);
    return rec == null ? null : jsonDecode(rec.body) as Json;
  }

  Future<void> saveSetup(Json setup) async {
    final saved = await savedSetup();
    await _sync.putLocal(_owner, LocalWrite(Kinds.setupDraft, _setupDraftId, {...?saved, 'setup': setup}));
  }

  /// Asks the account for a draft built from the reviewed setup. A retry of the same answers reuses the same
  /// operation and plan IDs, so a lost response can never create a second plan.
  Future<PlanAnswer> createDraft(Json setup, {String? title, List<Json>? manualWorkouts}) async {
    final signature = jsonEncode([setup, title, manualWorkouts]);
    final saved = await savedSetup();
    var op = saved?['operationId'] as String?, planId = saved?['planId'] as String?;
    if (saved?['signature'] != signature || op == null || planId == null) {
      if (op != null) await _sync.abandon(op); // the answers changed: the earlier request must not land later
      (op, planId) = (SyncEngine.newId(), SyncEngine.newId());
      await _sync.putLocal(_owner, LocalWrite(Kinds.setupDraft, _setupDraftId, {'setup': setup, 'signature': signature, 'operationId': op, 'planId': planId}));
    }
    final cmd = await _sync.submitAndWait(_owner, kind: 'plan.draft', path: '/plan-drafts', operationId: op, targetKind: Kinds.plan, targetId: planId,
        payload: {'planId': planId, 'setup': setup, 'title': title, 'manualWorkouts': manualWorkouts});
    final answer = await _answer(cmd);
    if (!answer.unreachable) await _sync.putLocal(_owner, LocalWrite(Kinds.setupDraft, _setupDraftId, {'setup': setup}));
    return PlanAnswer(answer.state, code: answer.code, data: {...?answer.data, 'planId': planId});
  }

  /// Regenerates a draft's dates. The draft is rebuilt by the account so the review always shows real content.
  Future<PlanAnswer> updateDraft(Plan plan, {required String startDate, required List<int> weekdays, required int blockWeeks}) async {
    final sessions = (plan.setup?['sessionsPerWeek'] as int?) ?? weekdays.length;
    final check = ScheduleRules.generate(startDate, weekdays, sessions, blockWeeks, plan.minRecoveryDays);
    if (!ScheduleRules.isDayKey(startDate)) throw const ScheduleRefused([ScheduleRules.invalidDate]);
    if (check.errors.isNotEmpty) throw ScheduleRefused(check.errors);
    return _answer(await _sync.submitAndWait(_owner, kind: 'plan.draft.update', method: 'PUT', path: '/plan-drafts/${plan.id}',
        targetKind: Kinds.plan, targetId: plan.id,
        payload: {'expectedPlanRevision': plan.revision, 'startDate': startDate, 'weekdays': weekdays, 'blockWeeks': blockWeeks, 'title': null}));
  }

  Future<PlanAnswer> continueGoal(Plan plan, String startDate) async {
    final newId = SyncEngine.newId();
    final answer = await _answer(await _sync.submitAndWait(_owner, kind: 'plan.continue', path: '/plans/${plan.id}/continue',
        targetKind: Kinds.plan, targetId: newId, payload: {'newPlanId': newId, 'startDate': startDate}));
    return PlanAnswer(answer.state, code: answer.code, data: {...?answer.data, 'planId': newId});
  }

  // ------------------------------------------------------------------ reviewed lifecycle (local first)

  LocalWrite _write(Json plan) => LocalWrite(Kinds.plan, plan['id'] as String, plan);

  /// Starts the reviewed draft as the primary plan. Replacing a different primary must be named explicitly;
  /// the displaced plan is paused (or closed when its block is being finished). Open workouts are untouched.
  Future<Receipt> activate(Plan draft, {required String today, String? replacePrimaryId, bool closePrimary = false}) async {
    final ctx = await _contextBody();
    final current = ctx['primaryPlanId'] as String?;
    if (current != null && current != draft.id && current != replacePrimaryId) throw const ScheduleRefused(['PRIMARY_EXISTS']);
    final writes = [
      _write(copyJson(draft.j)..['lifecycle'] = 'active'),
      LocalWrite(Kinds.context, _owner, {...ctx, 'primaryPlanId': draft.id}),
    ];
    final old = current != draft.id ? await _plan(current) : null;
    if (old != null) {
      writes.add(_write(copyJson(old.j)
        ..addAll(closePrimary
            ? {'lifecycle': 'closed', 'closureIntent': 'finish_for_now', 'closedOn': today}
            : old.isActive ? {'lifecycle': 'paused', 'pausedOn': today} : {})));
    }
    return _sync.submit(_owner, kind: 'plan.activate', path: '/plans/${draft.id}/activate', targetKind: Kinds.context, targetId: _owner,
        after: [(Kinds.plan, draft.id), if (old != null) (Kinds.plan, old.id)], writes: writes,
        payload: {
          'expectedContextRevision': _ctxRev, 'expectedPlanRevision': _planRev(draft.id), 'startDate': draft.startDate,
          'reviewedDates': [for (final o in draft.occasions) {'occasionId': o.id, 'date': o.scheduledDate}],
          'replacePrimaryId': old?.id, 'closePrimary': closePrimary, 'effectiveDate': today,
        });
  }

  /// Freezes future expectations. It does not touch any workout or its clock.
  Future<Receipt> pause(Plan plan, {required String today}) async => _sync.submit(_owner,
      kind: 'plan.pause', path: '/plans/${plan.id}/pause', targetKind: Kinds.context, targetId: _owner, after: [(Kinds.plan, plan.id)],
      writes: [_write(copyJson(plan.j)..addAll({'lifecycle': 'paused', 'pausedOn': today}))],
      payload: {'expectedContextRevision': _ctxRev, 'expectedPlanRevision': _planRev(plan.id), 'effectiveDate': today});

  /// The date changes a resume from `resumeDate` would make: every pending occasion on or after the pause
  /// shifts by the same number of days, preserving spacing. Recorded, skipped and open occasions never move.
  static List<ScheduleChange> resumeChanges(Plan plan, List<ScheduleOccasion> schedule, String resumeDate) {
    final pending = schedule.where((o) => o.isEligible && (plan.pausedOn == null || o.scheduledDate.compareTo(plan.pausedOn!) >= 0)).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    if (pending.isEmpty) return const [];
    final shift = daysBetween(pending.first.scheduledDate, resumeDate); // calendar days, immune to DST
    if (shift <= 0) return const [];
    return [for (final o in pending) ScheduleChange(o.id, o.scheduledDate, addDays(o.scheduledDate, shift))];
  }

  Future<Receipt> resume(Plan plan, List<ScheduleOccasion> schedule, List<ScheduleChange> changes, {required String today}) async {
    final v = ScheduleRules.validate(schedule, changes, plan.minRecoveryDays);
    if (!v.isValid) throw ScheduleRefused(v.errors);
    final ctx = await _contextBody();
    final current = ctx['primaryPlanId'] as String?;
    final displaced = current != null && current != plan.id ? await _plan(current) : null;
    final body = copyJson(plan.j)..addAll({'lifecycle': 'active', 'pausedOn': null});
    for (final o in body['occasions'] as List) {
      final moved = v.changed.where((c) => c.id == (o as Json)['id']).firstOrNull;
      if (moved != null) (o as Json)['scheduledDate'] = moved.scheduledDate;
    }
    return _sync.submit(_owner, kind: 'plan.resume', path: '/plans/${plan.id}/resume', targetKind: Kinds.context, targetId: _owner,
        after: [(Kinds.plan, plan.id), if (displaced != null) (Kinds.plan, displaced.id)],
        writes: [
          _write(body),
          LocalWrite(Kinds.context, _owner, {...ctx, 'primaryPlanId': plan.id}),
          if (displaced != null && displaced.isActive) _write(copyJson(displaced.j)..addAll({'lifecycle': 'paused', 'pausedOn': today})),
        ],
        payload: {
          'expectedContextRevision': _ctxRev, 'expectedPlanRevision': _planRev(plan.id), 'changes': [for (final c in changes) c.toJson()],
          'switchPrimaryFromId': displaced?.id, 'effectiveDate': today,
        });
  }

  Future<Receipt> _schedule(Plan plan, String action, String occasionId, Json body, {String? from, String? to}) => _sync.submit(_owner,
      kind: 'plan.schedule', path: '/plans/${plan.id}/schedule-changes', targetKind: Kinds.plan, targetId: plan.id, after: [_ctx], writes: [_write(body)],
      payload: {'expectedPlanRevision': _planRev(plan.id), 'action': action, 'occasionId': occasionId, 'from': from, 'to': to});

  Json _withOccasion(Plan plan, String occasionId, void Function(Json o) change) {
    final body = copyJson(plan.j);
    change((body['occasions'] as List).cast<Json>().firstWhere((o) => o['id'] == occasionId));
    return body;
  }

  /// Moves one eligible occasion. It stays the same occasion in the same training week; its original date is kept.
  /// A rotation has no dates to move: its next workout waits, or is skipped.
  Future<Receipt> move(Plan plan, List<ScheduleOccasion> schedule, String occasionId, String to) {
    if (plan.isRotating) throw const ScheduleRefused(['OCCASION_NOT_MOVABLE']);
    final from = schedule.firstWhere((o) => o.id == occasionId).scheduledDate;
    final v = ScheduleRules.validate(schedule, [ScheduleChange(occasionId, from, to)], plan.minRecoveryDays);
    if (!v.isValid) throw ScheduleRefused(v.errors);
    return _schedule(plan, 'move', occasionId, _withOccasion(plan, occasionId, (o) => o['scheduledDate'] = to), from: from, to: to);
  }

  /// A deliberate skip: no sets, no workout and no completion credit are created.
  Future<Receipt> skip(Plan plan, List<ScheduleOccasion> schedule, String occasionId) {
    if (!schedule.firstWhere((o) => o.id == occasionId).isEligible) throw const ScheduleRefused([ScheduleRules.occasionNotEligible]);
    return _schedule(plan, 'skip', occasionId, _withOccasion(plan, occasionId, (o) => o['isSkipped'] = true));
  }

  /// In a rotation only the latest step can be un-skipped: the sequence has already moved past earlier ones.
  Future<Receipt> unskip(Plan plan, String occasionId, {Iterable<Workout> workouts = const []}) {
    if (plan.isRotating && !canUnskip(plan, occasionId, workouts)) throw const ScheduleRefused([ScheduleRules.occasionNotEligible]);
    return _schedule(plan, 'unskip', occasionId, _withOccasion(plan, occasionId, (o) => o['isSkipped'] = false));
  }

  /// Rotation: only the latest step can be un-skipped — none after it exists on the account or was started here.
  static bool canUnskip(Plan plan, String occasionId, Iterable<Workout> workouts) {
    final k = plan.occasions.where((o) => o.id == occasionId).firstOrNull?.sequenceIndex;
    if (k == null) return !plan.isRotating;
    if (plan.occasions.any((o) => (o.sequenceIndex ?? -1) > k)) return false;
    final linked = {for (final w in workouts) if (!w.isDeleted && w.planId == plan.id && w.occasionId != null) w.occasionId};
    for (var j = k + 1; j <= k + 1 + linked.length; j++) {
      if (linked.contains(PlanRules.sequenceId(plan.id, j))) return false;
    }
    return true;
  }

  /// Skip from the projection: a rotation's next workout that the account has not materialized yet is recorded as
  /// skipped today (the account materializes the same occurrence ID); any other occurrence is an ordinary skip.
  Future<Receipt> skipOccurrence(Plan plan, List<Workout> workouts, Occasion o, {required String today}) {
    if (!o.isVirtual) return skip(plan, scheduleOf(plan, workouts), o.id);
    final week = daysBetween(plan.startDate, today) < 0 ? 1 : daysBetween(plan.startDate, today) ~/ 7 + 1;
    final body = copyJson(plan.j);
    (body['occasions'] as List).add(copyJson(o.j)
      ..remove('isVirtual')
      ..addAll({'isSkipped': true, 'originalDate': today, 'scheduledDate': today, 'weekNumber': week}));
    return _sync.submit(_owner,
        kind: 'plan.schedule', path: '/plans/${plan.id}/schedule-changes', targetKind: Kinds.plan, targetId: plan.id, after: [_ctx], writes: [_write(body)],
        payload: {'expectedPlanRevision': _planRev(plan.id), 'action': 'skip', 'occasionId': o.id, 'from': null, 'to': today, 'sequenceIndex': o.sequenceIndex});
  }

  // ------------------------------------------------------------------ the plan builder (docs/TRAINING_PLANS.md)

  /// The plan being built ("new") or edited (its plan ID). Saved on the phone only; never creates anything.
  Future<PlanDraft?> builderDraft(String draftId) async {
    final rec = await _sync.get(_owner, Kinds.planBuilder, draftId);
    return rec == null ? null : PlanDraft(jsonDecode(rec.body) as Json);
  }

  Future<void> saveBuilderDraft(PlanDraft draft) => _sync.putLocal(_owner, LocalWrite(Kinds.planBuilder, draft.draftId, draft.j));
  Future<void> discardBuilderDraft(String draftId) => _sync.deleteLocal(_owner, Kinds.planBuilder, draftId);

  /// Custom exercises the plan uses must reach the account before the plan that names them.
  List<(String, String)> _customAfter(Json body) => [
        for (final w in body['workouts'] as List)
          for (final e in (w as Json)['exercises'] as List)
            if (((e as Json)['catalogKey'] as String?)?.startsWith('custom:') ?? false) (Kinds.customExercise, (e['catalogKey'] as String).substring(7)),
      ];

  /// Activate plan: creates the user's own plan from the draft and makes it the primary plan. Both are saved on the
  /// phone with their commands before any network use, so this works offline; the activation waits for the creation.
  /// Replacing a current primary must be named, and pauses it (history kept), exactly like `activate`.
  Future<Receipt> createAndActivate(PlanDraft draft, {required String today, String? replacePrimaryId}) async {
    final errors = draft.errors;
    if (errors.isNotEmpty) throw ScheduleRefused(errors);
    if (!draft.isUsable) throw const ScheduleRefused([PlanRules.notUsable]);
    final current = (await _contextBody())['primaryPlanId'] as String?;
    if (current != null && current != replacePrimaryId) throw const ScheduleRefused(['PRIMARY_EXISTS']);
    final body = draft.toPlanJson();
    await _sync.submit(_owner, kind: 'plan.create', path: '/plans', targetKind: Kinds.plan, targetId: draft.planId,
        after: [_ctx, ..._customAfter(body)], writes: [_write(body)], payload: draft.createPayload());
    final receipt = await activate(Plan(body), today: today, replacePrimaryId: replacePrimaryId);
    await discardBuilderDraft(draft.draftId);
    return receipt;
  }

  /// Save changes to an existing plan from the draft's effective date on (a draft plan is rebuilt in full). Recorded,
  /// skipped, in-progress and earlier occurrences, and occurrences edited on their own, keep their content and dates;
  /// finished workouts are never touched. The local result is computed by the same rules the account applies.
  Future<Receipt> revise(Plan plan, PlanDraft draft, {required List<Workout> workouts, required String today}) async {
    final errors = draft.errors;
    if (errors.isNotEmpty) throw ScheduleRefused(errors);
    if (!plan.isDraft && !draft.isUsable) throw const ScheduleRefused([PlanRules.notUsable]);
    if (plan.isClosed) throw const ScheduleRefused(['PLAN_NOT_ACTIVE']);
    final mode = plan.schedule?.mode ?? 'fixed';
    if (!plan.isDraft && mode != draft.schedule.mode) throw const ScheduleRefused(['MODE_LOCKED']);
    if (!plan.isDraft && draft.startDate != plan.startDate) throw const ScheduleRefused(['START_LOCKED']);
    if (draft.baseRevision != null && draft.baseRevision != plan.revision) throw const ScheduleRefused(['PLAN_CHANGED_SINCE_EDIT']);

    final p = draft.planBody;
    final schedule = p['schedule'] as Json;
    // Never earlier than today: a missed workout stays on its date, whatever an older draft says.
    final chosen = draft.effectiveDate ?? today;
    final effective = plan.isDraft ? draft.startDate : (chosen.compareTo(today) < 0 ? today : chosen);
    if (schedule['mode'] == 'rotating') {
      final before = plan.schedule;
      final changed = before == null || before.cycle.join(',') != (schedule['cycle'] as List).join(',');
      // A changed cycle starts from its first workout at the next step that has not been started or recorded.
      schedule['cycleAnchor'] = !changed
          ? before.cycleAnchor
          : planOccasions(plan, today, workouts).where((o) => o.isVirtual).firstOrNull?.sequenceIndex ?? plan.occasions.length;
    }
    final weeks = p['durationWeeks'] as int?;
    final workoutsJson = (p['workouts'] as List).cast<Json>();
    final occasions = plan.isDraft
        ? (schedule['mode'] == 'rotating' ? <Json>[] : PlanRules.generate(plan.id, draft.startDate, weeks!, schedule, workoutsJson))
        : PlanRules.revise(planId: plan.id, start: plan.startDate, weeks: weeks, effective: effective,
            occasions: [for (final o in plan.j['occasions'] as List? ?? const []) o as Json],
            // An occurrence any workout points at is never removed or rewritten (same rule as the account).
            pending: {
              for (final s in scheduleOf(plan, workouts))
                if (s.isEligible && !workouts.any((w) => !w.isDeleted && w.occasionId == s.id)) s.id,
            },
            workouts: workoutsJson, schedule: schedule);
    final body = copyJson(plan.j)
      ..addAll({
        'title': p['title'], 'startDate': draft.startDate, 'blockWeeks': weeks ?? 1, 'isOngoing': weeks == null, 'timeBudgetMinutes': p['timeBudgetMinutes'],
        'workouts': workoutsJson, 'schedule': schedule, 'occasions': occasions, 'minRecoveryDays': plan.isBuilt ? plan.minRecoveryDays : 0,
      });
    final receipt = await _sync.submit(_owner, kind: 'plan.revise', method: 'PUT', path: '/plans/${plan.id}', targetKind: Kinds.plan, targetId: plan.id,
        after: [_ctx, ..._customAfter(body)], writes: [_write(body)],
        payload: {
          'expectedPlanRevision': _planRev(plan.id), 'effectiveDate': effective, 'title': p['title'], 'startDate': draft.startDate,
          'durationWeeks': weeks, 'timeBudgetMinutes': p['timeBudgetMinutes'], 'workouts': workoutsJson, 'schedule': schedule,
        });
    await discardBuilderDraft(draft.draftId);
    return receipt;
  }

  /// This workout only: one pending occurrence of a fixed-weekday plan gets its own name and exercises. Later
  /// plan-wide edits leave it as it is.
  Future<Receipt> editOccasion(Plan plan, List<ScheduleOccasion> schedule, Occasion o, {required String title, required List<Json> prescription}) {
    if (o.isVirtual || plan.isRotating) throw const ScheduleRefused(['OCCASION_NOT_MOVABLE']);
    if (!(schedule.where((s) => s.id == o.id).firstOrNull?.isEligible ?? false)) throw const ScheduleRefused([ScheduleRules.occasionNotEligible]);
    final check = PlanRules.validate({
      'title': 'x', 'durationWeeks': 1, 'workouts': [{'id': 'x', 'name': title, 'notes': null, 'exercises': prescription}],
      'schedule': {'mode': 'fixed', 'pattern': [{'weekday': 1, 'workoutId': 'x'}], 'cycle': [], 'trainingDays': [], 'cycleAnchor': 0},
    });
    if (check.isNotEmpty) throw ScheduleRefused(check);
    final body = _withOccasion(plan, o.id, (x) => x.addAll({'title': title.trim(), 'prescription': prescription, 'isCustomised': true}));
    return _sync.submit(_owner, kind: 'plan.occasion', method: 'PUT', path: '/plans/${plan.id}/occasions/${o.id}', targetKind: Kinds.plan, targetId: plan.id,
        after: [_ctx], writes: [_write(body)], payload: {'expectedPlanRevision': _planRev(plan.id), 'title': title.trim(), 'prescription': prescription});
  }

  // ------------------------------------------------------------------ custom exercises (private to this owner)

  /// Creates or changes one of the owner's own exercises. Renaming or archiving never changes recorded workouts,
  /// which keep the name they were recorded with.
  Future<CustomExercise> saveCustomExercise({String? id, required String name, required String category, required String equipment,
      required bool isTimed, bool isArchived = false}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) throw const ScheduleRefused(['EXERCISE_NAME_INVALID']);
    final exId = id ?? SyncEngine.newId();
    final body = {'id': exId, 'name': trimmed, 'category': category, 'equipment': equipment, 'isTimed': isTimed, 'isArchived': isArchived,
      'revision': (await _sync.get(_owner, Kinds.customExercise, exId))?.revision ?? 0};
    await _sync.submit(_owner, kind: 'customexercise.put', method: 'PUT', path: '/custom-exercises/$exId', targetKind: Kinds.customExercise, targetId: exId,
        writes: [LocalWrite(Kinds.customExercise, exId, body)],
        payload: {'expectedRevision': {r'$rev': [Kinds.customExercise, exId]}, 'name': trimmed, 'category': category, 'equipment': equipment, 'isTimed': isTimed, 'isArchived': isArchived});
    return CustomExercise(body);
  }

  /// Closes the block and frees the primary slot. Open workouts keep their links and can still be finished.
  Future<Receipt> close(Plan plan, {required String intent, required String today}) async {
    final ctx = await _contextBody();
    return _sync.submit(_owner, kind: 'plan.close', path: '/plans/${plan.id}/close', targetKind: Kinds.context, targetId: _owner, after: [(Kinds.plan, plan.id)],
        writes: [
          _write(copyJson(plan.j)..addAll({'lifecycle': 'closed', 'closureIntent': intent, 'closedOn': today})),
          if (ctx['primaryPlanId'] == plan.id) LocalWrite(Kinds.context, _owner, {...ctx, 'primaryPlanId': null}),
        ],
        payload: {'expectedContextRevision': _ctxRev, 'expectedPlanRevision': _planRev(plan.id), 'intent': intent, 'effectiveDate': today});
  }

  /// Visibility only. Lifecycle and closure outcome are not changed.
  Future<Receipt> archive(Plan plan, bool archived) => _sync.submit(_owner,
      kind: 'plan.archive', path: '/plans/${plan.id}/archive', targetKind: Kinds.plan, targetId: plan.id, after: [_ctx],
      writes: [_write(copyJson(plan.j)..['isArchived'] = archived)], payload: {'expectedPlanRevision': _planRev(plan.id), 'isArchived': archived});

  // ------------------------------------------------------------------ proposals (reviewed with the account)

  Future<PlanAnswer> proposeMove(Plan plan, List<ScheduleChange> moves) => _propose(plan, 'schedule', {'moves': [for (final m in moves) m.toJson()]});
  Future<PlanAnswer> proposeSubstitution(Plan plan, String fromKey, String toKey) => _propose(plan, 'substitution', {'fromCatalogKey': fromKey, 'toCatalogKey': toKey});

  Future<PlanAnswer> _propose(Plan plan, String kind, Json extra) async {
    final id = SyncEngine.newId();
    return _answer(await _sync.submitAndWait(_owner, kind: 'proposal.create', path: '/proposals', targetKind: Kinds.proposal, targetId: id,
        after: [(Kinds.plan, plan.id), _ctx], payload: {'proposalId': id, 'planId': plan.id, 'kind': kind, 'moves': null, 'fromCatalogKey': null, 'toCatalogKey': null, ...extra}));
  }

  /// Accept applies exactly the reviewed scope; Keep current declines and suppresses the unchanged proposal.
  Future<PlanAnswer> decide(Proposal proposal, {required bool accept}) async => _answer(await _sync.submitAndWait(_owner,
      kind: accept ? 'proposal.accept' : 'proposal.decline', path: '/proposals/${proposal.id}/${accept ? 'accept' : 'decline'}',
      targetKind: Kinds.proposal, targetId: proposal.id, after: [(Kinds.plan, proposal.planId), _ctx],
      payload: {'expectedProposalRevision': proposal.revision, 'expectedPlanRevision': accept ? _planRev(proposal.planId) : null}));
}
