import 'dart:convert';

import '../../core/clock.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import 'plan_rules.dart';

/// Equipment the user has. Keys are stored in drafts.
const equipmentChoices = {'full_gym': 'Full gym', 'dumbbells': 'Dumbbells only', 'bodyweight': 'Bodyweight only'};
const experienceChoices = {'new': 'New to training', 'comfortable': 'Comfortable with the basics', 'experienced': 'Experienced'};

/// Common weekly frequencies and the weekdays they start with (the user can change the days).
const defaultDays = {2: [1, 4], 3: [1, 3, 5], 4: [1, 2, 4, 5], 5: [1, 2, 3, 5, 6], 6: [1, 2, 3, 4, 5, 6], 7: [1, 2, 3, 4, 5, 6, 7]};

// ------------------------------------------------------------------ starter templates

class TemplateWorkout {
  const TemplateWorkout(this.key, this.name, this.exercises);
  final String key, name;
  final List<Json> exercises;
}

/// A familiar split with curated starting exercises. Editable starting point; never a prescription.
class PlanTemplate {
  PlanTemplate(Json j)
      : id = j['id'] as String,
        name = j['name'] as String,
        summary = j['summary'] as String,
        detail = j['detail'] as String,
        defaultSessions = j['defaultSessions'] as int,
        workouts = [
          for (final w in j['workouts'] as List)
            TemplateWorkout((w as Json)['key'] as String, w['name'] as String, [for (final e in w['exercises'] as List) e as Json]),
        ],
        sequences = {for (final e in (j['sequences'] as Json).entries) int.parse(e.key): (e.value as List).cast<String>()};
  final String id, name, summary, detail;
  final int defaultSessions;
  final List<TemplateWorkout> workouts;

  /// Session order for a number of sessions a week, e.g. 6 → Push, Pull, Legs, Push, Pull, Legs.
  final Map<int, List<String>> sequences;
  bool get isCustom => workouts.isEmpty;

  /// The order used with `days` training days: the matching sequence, or the default one rotated across them.
  List<String> sequenceFor(int days) => sequences[days] ?? sequences[defaultSessions] ?? const [];
  bool fitsWeekly(int days) => sequences.containsKey(days);
  TemplateWorkout workout(String key) => workouts.firstWhere((w) => w.key == key);
}

class PlanTemplates {
  PlanTemplates.parse(String text) : this._(jsonDecode(text) as Json);
  PlanTemplates._(Json j)
      : version = j['version'] as int,
        templates = [for (final t in j['templates'] as List) PlanTemplate(t as Json)],
        _swaps = {for (final e in (j['swaps'] as Json).entries) e.key: e.value as Json},
        _swapNames = {for (final e in (j['swapNames'] as Json).entries) e.key: e.value as Json};
  final int version;
  final List<PlanTemplate> templates;
  final Map<String, Json> _swaps, _swapNames;

  PlanTemplate byId(String id) => templates.firstWhere((t) => t.id == id);

  /// A template workout's exercises for the user's equipment: the deterministic swap table, with a swap that would
  /// repeat an exercise already in the workout left out.
  List<Json> exercisesFor(TemplateWorkout w, String equipment) {
    final out = <Json>[];
    for (final e in w.exercises) {
      var x = copyJson(e);
      final swap = _swaps[e['catalogKey']];
      if (equipment != 'full_gym' && swap != null && swap.containsKey(equipment)) {
        final to = swap[equipment] as String?;
        if (to == null) continue;
        final named = _swapNames[to]!;
        x = x..addAll({'catalogKey': to, 'name': named['name'], 'isTimed': named['isTimed']});
      }
      if (out.any((o) => o['catalogKey'] == x['catalogKey'])) continue;
      out.add(x);
    }
    return out;
  }
}

/// The suggested starting structure for the days available, and why. Never a claim that one split is best.
({String templateId, String reason}) suggestTemplate(int days, {String? experience}) => switch (days) {
      <= 3 => (templateId: 'full-body', reason: 'With $days ${days == 1 ? 'day' : 'days'} a week, full-body sessions train every muscle group each time you train.'),
      4 => (templateId: 'upper-lower', reason: 'With 4 days, alternating upper and lower body trains each half twice a week.'),
      5 => (templateId: 'upper-lower-ppl', reason: 'With 5 days, an upper and a lower day plus push, pull and legs trains each area about twice a week.'),
      _ => (templateId: 'push-pull-legs', reason: 'With $days days, repeating push, pull and legs trains each area twice a week${days == 7 ? ' and leaves one day for rest' : ''}.'),
    };

/// Shown with every suggestion (docs/TRAINING_PLANS.md › Starter templates).
const splitEvidenceNote = 'Studies comparing splits with the same weekly volume found similar strength and muscle gains, so pick the structure you can keep doing.';

// ------------------------------------------------------------------ the draft being built or edited

/// A plan being built or edited, saved on the phone after every change (record kind `plan_builder`). Nothing here
/// creates, activates or changes a plan; the repository does that from an explicit Activate or Save changes.
class PlanDraft {
  PlanDraft(this.j);
  final Json j;

  /// new | duplicate | edit
  String get mode => j['mode'] as String;
  bool get isEdit => mode == 'edit';

  /// The local record ID: one new plan at a time, or the plan being edited.
  String get draftId => isEdit ? planId : 'new';
  String get planId => j['planId'] as String;

  /// template | custom
  String get path => j['path'] as String;
  int get step => j['step'] as int? ?? 0;
  set step(int v) => j['step'] = v;
  Json get preferences => j['preferences'] as Json;
  List<int> get days => (preferences['days'] as List).cast<int>();
  String get equipment => preferences['equipment'] as String;
  String? get experience => preferences['experience'] as String?;
  String? get templateId => j['templateId'] as String?;
  String get title => j['title'] as String? ?? '';
  set title(String v) => j['title'] = v;
  String get startDate => j['startDate'] as String;
  set startDate(String v) => j['startDate'] = v;
  int? get durationWeeks => j['durationWeeks'] as int?;
  set durationWeeks(int? v) => j['durationWeeks'] = v;
  int? get timeBudgetMinutes => j['timeBudgetMinutes'] as int?;
  set timeBudgetMinutes(int? v) {
    j['timeBudgetMinutes'] = v;
    preferences['timeBudgetMinutes'] = v;
  }

  /// Edit only: changes apply to occurrences on or after this day.
  String? get effectiveDate => j['effectiveDate'] as String?;
  set effectiveDate(String? v) => j['effectiveDate'] = v;

  List<WorkoutDefinition> get workouts => [for (final w in j['workouts'] as List) WorkoutDefinition(w as Json)];
  PlanSchedule get schedule => PlanSchedule(j['schedule'] as Json);
  WorkoutDefinition? workout(String id) => workouts.where((w) => w.id == id).firstOrNull;

  List<Json> get _workouts => (j['workouts'] as List).cast<Json>();
  Json get _schedule => j['schedule'] as Json;
  Json _w(String id) => _workouts.firstWhere((w) => w['id'] == id);

  PlanDraft copy() => PlanDraft(copyJson(j));

  static Json _emptySchedule(String mode) => {'mode': mode, 'pattern': <Json>[], 'cycle': <String>[], 'trainingDays': <int>[], 'cycleAnchor': 0};

  static PlanDraft fresh({required String today, required String path}) => PlanDraft({
        'version': 1, 'mode': 'new', 'planId': SyncEngine.newId(), 'path': path, 'step': 0,
        'preferences': {'days': [1, 3, 5], 'equipment': 'full_gym', 'timeBudgetMinutes': null, 'experience': null},
        'templateId': path == 'custom' ? 'custom' : null, 'title': path == 'custom' ? 'My plan' : '',
        'workouts': <Json>[], 'schedule': _emptySchedule('fixed'), 'startDate': today, 'durationWeeks': 8, 'timeBudgetMinutes': null, 'effectiveDate': null,
      });

  // ---------------------------------------------------------------- preferences and structure

  void setPreferences({List<int>? days, String? equipment, String? experience, bool clearExperience = false}) {
    if (days != null) {
      preferences['days'] = [...days.toSet()]..sort();
      _fitDays();
    }
    if (equipment != null) preferences['equipment'] = equipment;
    if (experience != null || clearExperience) preferences['experience'] = experience;
  }

  /// Copies a template: its workouts become this plan's own, with fresh IDs. `withExercises: false` keeps only the
  /// structure (names and order); the plan is then a draft until every scheduled workout has exercises.
  void applyTemplate(PlanTemplates templates, String templateId, {bool withExercises = true}) {
    final t = templates.byId(templateId);
    j['templateId'] = templateId;
    if (title.trim().isEmpty || templates.templates.any((x) => x.name == title)) title = t.name;
    final ids = {for (final w in t.workouts) w.key: SyncEngine.newId()};
    j['workouts'] = [
      for (final w in t.workouts)
        if (t.sequenceFor(days.length).contains(w.key))
          {
            'id': ids[w.key], 'name': w.name, 'notes': null,
            'exercises': withExercises ? [for (final (i, e) in templates.exercisesFor(w, equipment).indexed) {...e, 'occurrenceKey': 'e${i + 1}'}] : <Json>[],
          },
    ];
    _layOut([for (final k in t.sequenceFor(days.length)) ids[k]!], fixed: t.fitsWeekly(days.length));
  }

  /// "Build my own": the user's workout names in order, no exercises yet.
  void setCustomStructure(List<String> names) {
    j['templateId'] = 'custom';
    j['workouts'] = [for (final n in names) {'id': SyncEngine.newId(), 'name': n.trim(), 'notes': null, 'exercises': <Json>[]}];
    _layOut([for (final w in _workouts) w['id'] as String], fixed: names.length == days.length);
  }

  /// One session per chosen day in sequence order (fixed), or the sequence rotating across the days.
  void _layOut(List<String> sequence, {required bool fixed}) {
    if (sequence.isEmpty) return;
    if (fixed) {
      j['schedule'] = _emptySchedule('fixed')..['pattern'] = [for (final (i, d) in days.indexed) {'weekday': d, 'workoutId': sequence[i % sequence.length]}];
    } else {
      j['schedule'] = _emptySchedule('rotating')
        ..['cycle'] = sequence
        ..['trainingDays'] = [...days];
    }
  }

  /// The sequence the schedule currently follows: fixed days in weekday order, or the cycle.
  List<String> get sequence => schedule.isRotating
      ? schedule.cycle
      : [for (final p in [...schedule.pattern]..sort((a, b) => a.weekday.compareTo(b.weekday))) p.workoutId];

  void _fitDays() {
    final seq = sequence;
    if (seq.isEmpty) return;
    if (schedule.isRotating) {
      _schedule['trainingDays'] = [...days];
    } else {
      _layOut(seq, fixed: true);
    }
  }

  /// Switches between fixed weekdays and a rotating sequence, keeping the order of workouts.
  void setMode(String mode) {
    if (mode == schedule.mode) return;
    final seq = sequence;
    if (mode == 'rotating') {
      _layOut(seq, fixed: false);
    } else {
      _layOut(seq, fixed: true);
      durationWeeks ??= 8; // a fixed-weekday plan always has an end
    }
  }

  /// Fixed: the workout on one weekday, or none (a rest day). Several days may use the same workout.
  void assignDay(int weekday, String? workoutId) {
    final pattern = [for (final p in _schedule['pattern'] as List) p as Json]..removeWhere((p) => p['weekday'] == weekday);
    if (workoutId != null) pattern.add({'weekday': weekday, 'workoutId': workoutId});
    pattern.sort((a, b) => (a['weekday'] as int).compareTo(b['weekday'] as int));
    _schedule['pattern'] = pattern;
    preferences['days'] = [for (final p in pattern) p['weekday'] as int];
  }

  /// Rotating: the ordered cycle (a workout may appear more than once).
  void setCycle(List<String> workoutIds) => _schedule['cycle'] = [...workoutIds];
  void setTrainingDays(List<int> weekdays) {
    _schedule['trainingDays'] = [...weekdays.toSet()]..sort();
    preferences['days'] = _schedule['trainingDays'];
  }

  // ---------------------------------------------------------------- workouts

  String addWorkout(String name) {
    final id = SyncEngine.newId();
    _workouts.add({'id': id, 'name': name.trim(), 'notes': null, 'exercises': <Json>[]});
    return id;
  }

  void renameWorkout(String id, String name) => _w(id)['name'] = name.trim();
  void setWorkoutNotes(String id, String? notes) => _w(id)['notes'] = notes == null || notes.trim().isEmpty ? null : notes.trim();

  /// A second, independent workout with the same exercises. Scheduling it is a separate choice.
  String duplicateWorkout(String id, {String? name}) {
    final copy = copyJson(_w(id))
      ..['id'] = SyncEngine.newId()
      ..['name'] = name ?? '${_w(id)['name']} (copy)';
    _workouts.insert(_workouts.indexWhere((w) => w['id'] == id) + 1, copy);
    return copy['id'] as String;
  }

  /// Removes the workout and every place the schedule used it. Occurrences already recorded keep their copy.
  void deleteWorkout(String id) {
    _workouts.removeWhere((w) => w['id'] == id);
    _schedule['pattern'] = [for (final p in _schedule['pattern'] as List) if ((p as Json)['workoutId'] != id) p];
    _schedule['cycle'] = [for (final c in _schedule['cycle'] as List) if (c != id) c];
  }

  /// Moves a workout up (-1) or down (+1) in the list: the accessible alternative to dragging.
  void moveWorkout(String id, int delta) => _move(_workouts, _workouts.indexWhere((w) => w['id'] == id), delta);

  /// Copies another workout's exercises (from this plan, another of the user's plans, or a recorded workout's
  /// prescription) into a new workout of this plan. Nothing links back to the source.
  String copyWorkout(String name, List<Prescription> exercises) {
    final id = addWorkout(name);
    _w(id)['exercises'] = [for (final (i, e) in exercises.indexed) copyJson(e.j)..['occurrenceKey'] = 'e${i + 1}'];
    return id;
  }

  // ---------------------------------------------------------------- exercises

  List<Json> _ex(String workoutId) => (_w(workoutId)['exercises'] as List).cast<Json>();
  String _newKey(String workoutId) {
    final used = {for (final e in _ex(workoutId)) e['occurrenceKey']};
    var n = _ex(workoutId).length + 1;
    while (used.contains('e$n')) {
      n++;
    }
    return 'e$n';
  }

  /// Adds a catalog or custom exercise with a starting prescription the user can change.
  String addExercise(String workoutId, CatalogExercise e) {
    final key = _newKey(workoutId);
    _ex(workoutId).add({
      'occurrenceKey': key, 'catalogKey': e.key, 'name': e.name, 'isTimed': e.isTimed, 'targetSets': 3,
      'targetRepsMin': e.isTimed ? null : 8, 'targetRepsMax': e.isTimed ? null : 12, 'targetDurationSeconds': e.isTimed ? 30 : null, 'restSeconds': 90,
    });
    return key;
  }

  /// Another exercise in the same place with the same sets, reps and rest. It gets a new identity: it never takes
  /// on the replaced exercise's history, and an optional weight target is cleared.
  void replaceExercise(String workoutId, String occurrenceKey, CatalogExercise e) {
    final list = _ex(workoutId);
    final i = list.indexWhere((x) => x['occurrenceKey'] == occurrenceKey);
    list[i] = copyJson(list[i])
      ..addAll({'occurrenceKey': _newKey(workoutId), 'catalogKey': e.key, 'name': e.name, 'isTimed': e.isTimed})
      ..remove('targetLoadKg');
    if (e.isTimed && list[i]['targetDurationSeconds'] == null) list[i].addAll({'targetDurationSeconds': 30, 'targetRepsMin': null, 'targetRepsMax': null});
    if (!e.isTimed && list[i]['targetDurationSeconds'] != null) list[i].addAll({'targetDurationSeconds': null, 'targetRepsMin': 8, 'targetRepsMax': 12});
  }

  void removeExercise(String workoutId, String occurrenceKey) => _ex(workoutId).removeWhere((x) => x['occurrenceKey'] == occurrenceKey);
  void moveExercise(String workoutId, String occurrenceKey, int delta) => _move(_ex(workoutId), _ex(workoutId).indexWhere((x) => x['occurrenceKey'] == occurrenceKey), delta);

  /// Sets, reps, time, rest, optional weight target (kg) and notes. Null clears a value.
  void setPrescription(String workoutId, String occurrenceKey, {int? sets, int? repsMin, int? repsMax, int? seconds, int? restSeconds, double? targetLoadKg, String? notes}) {
    final e = _ex(workoutId).firstWhere((x) => x['occurrenceKey'] == occurrenceKey);
    final timed = e['isTimed'] as bool? ?? false;
    e.addAll({
      'targetSets': sets, 'restSeconds': restSeconds,
      'targetRepsMin': timed ? null : repsMin, 'targetRepsMax': timed ? null : repsMax, 'targetDurationSeconds': timed ? seconds : null,
    });
    if (targetLoadKg == null) {
      e.remove('targetLoadKg');
    } else {
      e['targetLoadKg'] = targetLoadKg;
    }
    if (notes == null || notes.trim().isEmpty) {
      e.remove('notes');
    } else {
      e['notes'] = notes.trim();
    }
  }

  static void _move(List<Json> list, int i, int delta) {
    final to = i + delta;
    if (i < 0 || to < 0 || to >= list.length) return;
    list.insert(to, list.removeAt(i));
  }

  // ---------------------------------------------------------------- checks and output

  /// What the rules check, and what is sent.
  Json get planBody => {
        'title': title.trim(), 'durationWeeks': durationWeeks, 'timeBudgetMinutes': timeBudgetMinutes,
        'workouts': [for (final w in _workouts) copyJson(w)..['name'] = (w['name'] as String).trim()], 'schedule': copyJson(_schedule),
      };
  List<String> get errors => PlanRules.validate(planBody);

  /// Every scheduled workout has an exercise. Until then it is a draft and cannot be activated.
  bool get isUsable => errors.isEmpty && PlanRules.usable(planBody);

  /// The real dated schedule for a fixed plan (the review shows these), empty for a rotation.
  List<Json> occurrences() => schedule.isRotating || durationWeeks == null
      ? const []
      : PlanRules.generate(planId, startDate, durationWeeks!, _schedule, planBody['workouts'] as List<Json>);

  /// The plan record as the account will hold it once created (lifecycle draft).
  Json toPlanJson() => {
        'id': planId, 'title': title.trim(), 'lifecycle': 'draft', 'closureIntent': null, 'isArchived': false, 'startDate': startDate,
        'blockWeeks': durationWeeks ?? 1, 'minRecoveryDays': 0, 'setup': null, 'baselineId': null, 'pausedOn': null, 'closedOn': null, 'revision': 0,
        'occasions': occurrences(), 'workouts': planBody['workouts'], 'schedule': copyJson(_schedule), 'isOngoing': durationWeeks == null,
        'timeBudgetMinutes': timeBudgetMinutes, 'templateId': templateId,
      };

  Json createPayload() => {
        'planId': planId, 'title': title.trim(), 'startDate': startDate, 'durationWeeks': durationWeeks, 'timeBudgetMinutes': timeBudgetMinutes,
        'templateId': templateId, 'workouts': planBody['workouts'], 'schedule': copyJson(_schedule),
      };

  /// Edit an existing plan, or start a new one from it. A plan from before the builder is read back as workouts:
  /// one per distinct workout name in its first week, on the weekdays it used.
  static PlanDraft fromPlan(Plan plan, {required bool duplicate, required String today}) {
    final Json schedule;
    final List<Json> workouts;
    if (plan.isBuilt) {
      workouts = [for (final w in plan.workouts) copyJson(w.j)];
      schedule = copyJson(plan.schedule!.j);
    } else {
      final firstWeek = [for (final o in plan.occasions) if (o.weekNumber == 1) o]..sort((a, b) => a.originalDate.compareTo(b.originalDate));
      final ids = <String, String>{};
      workouts = [];
      for (final o in firstWeek) {
        if (ids.containsKey(o.title)) continue;
        ids[o.title] = SyncEngine.newId();
        workouts.add({'id': ids[o.title], 'name': o.title, 'notes': null, 'exercises': [for (final p in o.prescription) copyJson(p.j)]});
      }
      final seen = <int>{};
      schedule = _emptySchedule('fixed')
        ..['pattern'] = [
          for (final o in firstWeek)
            if (seen.add(parseDayKey(o.originalDate).weekday)) {'weekday': parseDayKey(o.originalDate).weekday, 'workoutId': ids[o.title]},
        ];
    }
    final s = PlanSchedule(schedule);
    final days = s.isRotating ? s.trainingDays : [for (final p in s.pattern) p.weekday];
    final start = duplicate || plan.isDraft ? (plan.startDate.compareTo(today) < 0 ? today : plan.startDate) : plan.startDate;
    return PlanDraft({
      'version': 1, 'mode': duplicate ? 'duplicate' : 'edit', 'planId': duplicate ? SyncEngine.newId() : plan.id,
      'path': plan.templateId == null || plan.templateId == 'custom' ? 'custom' : 'template', 'step': duplicate ? 2 : 1,
      'preferences': {'days': [...days]..sort(), 'equipment': 'full_gym', 'timeBudgetMinutes': plan.timeBudgetMinutes, 'experience': null},
      'templateId': plan.templateId, 'title': duplicate ? '${plan.title} (copy)' : plan.title,
      'workouts': workouts, 'schedule': schedule, 'startDate': start, 'durationWeeks': plan.isOngoing ? null : plan.blockWeeks,
      'timeBudgetMinutes': plan.timeBudgetMinutes,
      'effectiveDate': duplicate || plan.isDraft ? null : (today.compareTo(plan.startDate) < 0 ? plan.startDate : today),
    });
  }
}
