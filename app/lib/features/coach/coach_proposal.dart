import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../data/models.dart';
import '../plans/plan_draft.dart';

/// Ask GoHard's suggested changes (docs/COACH.md › proposal): checked against the CURRENT draft, previewed, applied
/// through PlanDraft's own editor operations and undone only while what they changed is untouched.

/// The draft's opaque revision: a UUIDv5 (SHA-1) of the JSON the rules check and the server is sent ([PlanDraft.planBody]:
/// title, length, time budget, workouts with their exercises, schedule). The builder's step and preferences are not
/// in it, so moving between steps never makes an answer stale; any change to what the plan would contain does.
String draftRevision(PlanDraft d) => const Uuid().v5(Namespace.nil.value, jsonEncode(d.planBody));

const _ops = {'replaceExercise', 'setPrescription', 'addExercise', 'removeExercise'};

/// A suggestion checked against one version of the draft. [next] is that draft with every applicable operation done;
/// [changes] is what differs, one row per exercise (`before`/`after` exercise JSON, null when added/removed), which
/// is what the preview shows and Undo restores; [notApplicable] says why the other operations were left out.
class ProposalCheck {
  const ProposalCheck(this.next, this.changes, this.notApplicable, this.builtOn);
  final PlanDraft next;
  final List<Json> changes;
  final List<String> notApplicable;

  /// [draftRevision] of the draft this was built on: Apply refuses if the draft has moved on since.
  final String builtOn;
  bool get canApply => changes.isNotEmpty;
}

/// Checks [proposal] against [current]. Null when the proposal itself is not one this app understands (unknown
/// scope or operation, no or too many operations): it is never applicable. Nothing is changed in [current].
ProposalCheck? checkProposal(Object? proposal, PlanDraft current, List<CatalogExercise> choices) {
  if (proposal is! Map || proposal['scope'] != 'draft') return null;
  final ops = proposal['operations'];
  if (ops is! List || ops.isEmpty || ops.length > 8 || ops.any((o) => o is! Map || !_ops.contains(o['op']))) return null;

  final next = current.copy();
  final byKey = {for (final c in choices) c.key: c};
  // Per workout: the occurrence key now in `next` → the key it had in `current` (null: added by this suggestion).
  // Operations name keys of the draft that was sent, so a replaced exercise is still found by its old key.
  final origin = <String, Map<String, String?>>{};
  final skipped = <String>[];

  for (final raw in ops.cast<Map>()) {
    final op = Map<String, dynamic>.from(raw);
    final wid = op['workoutId'];
    final w = wid is String ? next.workout(wid) : null;
    if (w == null) {
      skipped.add('${_verb(op)}: the workout it names is no longer in your draft.');
      continue;
    }
    final keys = origin.putIfAbsent(w.id, () => {for (final e in w.exercises) e.occurrenceKey: e.occurrenceKey});
    String? resolve() => keys.entries.where((e) => e.value != null && e.value == op['occurrenceKey']).firstOrNull?.key;
    Prescription? at(String key) => next.workout(w.id)!.exercises.where((e) => e.occurrenceKey == key).firstOrNull;
    final choice = byKey[op['catalogKey']];

    switch (op['op']) {
      case 'removeExercise':
        final key = resolve();
        if (key == null) {
          skipped.add('${_verb(op)}: that exercise is no longer in ${w.name}.');
          continue;
        }
        next.removeExercise(w.id, key);
        keys.remove(key);
      case 'replaceExercise':
        final key = resolve();
        final e = key == null ? null : at(key);
        if (e == null) {
          skipped.add('${_verb(op)}: that exercise is no longer in ${w.name}.');
        } else if (choice == null) {
          skipped.add('Replace ${e.name}: the suggested exercise isn\'t available to your account.');
        } else if (choice.key == e.catalogKey) {
          skipped.add('Replace ${e.name}: it is already that exercise.');
        } else {
          final i = next.workout(w.id)!.exercises.indexWhere((x) => x.occurrenceKey == key);
          next.replaceExercise(w.id, key!, choice);
          final now = next.workout(w.id)!.exercises[i].occurrenceKey;
          keys[now] = keys.remove(key);
        }
      case 'setPrescription':
        final key = resolve();
        final e = key == null ? null : at(key);
        final rx = e == null ? null : _merged(e.j, op);
        if (e == null) {
          skipped.add('${_verb(op)}: that exercise is no longer in ${w.name}.');
        } else if (rx == null) {
          skipped.add('Change ${e.name}: the suggested values are outside what a plan allows.');
        } else {
          _set(next, w.id, key!, e, rx);
        }
      case 'addExercise':
        if (choice == null) {
          skipped.add('Add an exercise to ${w.name}: it isn\'t available to your account.');
          continue;
        }
        final base = Prescription({'isTimed': choice.isTimed, 'targetSets': 3, 'targetRepsMin': choice.isTimed ? null : 8, 'targetRepsMax': choice.isTimed ? null : 12,
            'targetDurationSeconds': choice.isTimed ? 30 : null, 'restSeconds': 90});
        final rx = _merged(base.j, op);
        if (rx == null || w.exercises.length >= 30) {
          skipped.add('Add ${choice.name} to ${w.name}: ${rx == null ? 'the suggested values are outside what a plan allows' : 'the workout already has 30 exercises'}.');
          continue;
        }
        final key = next.addExercise(w.id, choice);
        _set(next, w.id, key, at(key)!, rx);
        keys[key] = null;
    }
  }
  return ProposalCheck(next, _diff(current, next, origin), skipped, draftRevision(current));
}

String _verb(Json op) => switch (op['op']) {
      'removeExercise' => 'Remove an exercise',
      'replaceExercise' => 'Replace an exercise',
      'setPrescription' => 'Change sets and reps',
      _ => 'Add an exercise',
    };

typedef _Rx = ({int? sets, int? lo, int? hi, int? seconds, int? rest});

/// The exercise's values with the operation's given ones laid over them, or null when a value is not a whole number
/// inside the PlanRules limits. A missing or null value keeps what is there. Weight is never part of a suggestion.
_Rx? _merged(Json e, Json op) {
  for (final k in ['targetSets', 'targetRepsMin', 'targetRepsMax', 'targetDurationSeconds', 'restSeconds']) {
    if (op[k] != null && op[k] is! int) return null;
  }
  int? v(String k) => op[k] as int? ?? e[k] as int?;
  final timed = e['isTimed'] as bool? ?? false;
  final rx = (sets: v('targetSets'), lo: timed ? null : v('targetRepsMin'), hi: timed ? null : v('targetRepsMax'), seconds: timed ? v('targetDurationSeconds') : null, rest: v('restSeconds'));
  bool inRange(int? x, int min, int max) => x == null || (x >= min && x <= max);
  final ok = inRange(rx.sets, 1, 20) && inRange(rx.lo, 1, 100) && inRange(rx.hi, 1, 100) && (rx.lo == null || rx.hi == null || rx.lo! <= rx.hi!) &&
      inRange(rx.seconds, 1, 3600) && inRange(rx.rest, 0, 900);
  return ok ? rx : null;
}

/// Sets the values through the editor, keeping the exercise's own weight target and notes.
void _set(PlanDraft d, String workoutId, String key, Prescription e, _Rx rx) => d.setPrescription(workoutId, key,
    sets: rx.sets, repsMin: rx.lo, repsMax: rx.hi, seconds: rx.seconds, restSeconds: rx.rest, targetLoadKg: e.targetLoadKg, notes: e.notes);

List<Json> _diff(PlanDraft before, PlanDraft after, Map<String, Map<String, String?>> origin) {
  final out = <Json>[];
  for (final MapEntry(key: wid, value: keys) in origin.entries) {
    final was = before.workout(wid)!.exercises, now = after.workout(wid)!.exercises;
    final name = after.workout(wid)!.name;
    Json row(Json? b, Json? a, [int? index]) => {'workoutId': wid, 'workoutName': name, 'before': b, 'after': a, 'beforeIndex': index};
    for (final a in now) {
      final from = keys[a.occurrenceKey];
      final b = from == null ? null : was.firstWhere((x) => x.occurrenceKey == from);
      if (b == null || !sameJson(b.j, a.j)) out.add(row(b == null ? null : copyJson(b.j), copyJson(a.j)));
    }
    for (final (i, b) in was.indexed) {
      if (!keys.containsValue(b.occurrenceKey)) out.add(row(copyJson(b.j), null, i));
    }
  }
  return out;
}

/// Order-independent JSON equality (a record read back from the store may list keys in another order).
bool sameJson(Object? a, Object? b) => jsonEncode(_canonical(a)) == jsonEncode(_canonical(b));
Object? _canonical(Object? v) => v is Map
    ? {for (final k in [...v.keys.cast<String>()]..sort()) k: _canonical(v[k])}
    : v is List
        ? [for (final x in v) _canonical(x)]
        : v;

/// Undoes an applied suggestion's [changes] on [current]: restores exactly the exercises it changed and nothing
/// else. Refused (with the reason) when any of them was edited, moved to another workout or removed since.
({PlanDraft? next, String? refused}) undoProposal(PlanDraft current, List<Json> changes) {
  final next = current.copy();
  List<Json>? list(String wid) => ((next.j['workouts'] as List).cast<Json>().where((w) => w['id'] == wid).firstOrNull?['exercises'] as List?)?.cast<Json>();
  int indexOf(List<Json> l, Object? key) => l.indexWhere((x) => x['occurrenceKey'] == key);
  String refuse(Json c) => 'Undo is no longer safe: ${((c['after'] ?? c['before']) as Json)['name']} was changed after the suggestion was applied. Change it in the builder instead.';

  for (final c in changes) {
    final l = list(c['workoutId'] as String);
    final a = c['after'] as Json?, b = c['before'] as Json?;
    if (l == null) return (next: null, refused: refuse(c));
    if (a != null) {
      final i = indexOf(l, a['occurrenceKey']);
      if (i < 0 || !sameJson(l[i], a)) return (next: null, refused: refuse(c));
    }
    // The exercise coming back must not collide with one added since.
    if (b != null && b['occurrenceKey'] != a?['occurrenceKey'] && indexOf(l, b['occurrenceKey']) >= 0) return (next: null, refused: refuse(c));
  }
  for (final c in changes) {
    final l = list(c['workoutId'] as String)!;
    final a = c['after'] as Json?, b = c['before'] as Json?;
    if (a != null && b != null) l[indexOf(l, a['occurrenceKey'])] = copyJson(b);
    if (a != null && b == null) l.removeAt(indexOf(l, a['occurrenceKey']));
  }
  for (final c in [...changes.where((c) => c['after'] == null)]..sort((x, y) => (x['beforeIndex'] as int).compareTo(y['beforeIndex'] as int))) {
    final l = list(c['workoutId'] as String)!;
    l.insert((c['beforeIndex'] as int).clamp(0, l.length), copyJson(c['before'] as Map));
  }
  return (next: next, refused: null);
}
