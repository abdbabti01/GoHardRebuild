/// Typed views over wire-shaped JSON (contract version 1). The same shape is used on the wire and in
/// the local store, so a record never passes through a lossy translation.
/// Units: *Kg kilograms, *Seconds seconds, dayKey/…Date calendar `YYYY-MM-DD`, *AtUtc ISO-8601 UTC instants.
library;

import '../core/clock.dart';

typedef Json = Map<String, dynamic>;

Json copyJson(Map j) => {
      for (final e in j.entries)
        e.key as String: e.value is Map
            ? copyJson(e.value as Map)
            : e.value is List
                ? [for (final x in e.value as List) x is Map ? copyJson(x) : x]
                : e.value,
    };

double? _d(Object? v) => (v as num?)?.toDouble();

/// Record kinds in the local store.
abstract final class Kinds {
  static const profile = 'profile', context = 'context', plan = 'plan', workout = 'workout', set = 'set', food = 'food';
  static const run = 'run', metric = 'metric', proposal = 'proposal', catalog = 'catalog', savedFood = 'saved_food';
  /// The owner's private exercises; referenced from prescriptions as `custom:<id>`.
  static const customExercise = 'custom_exercise';
  // Local-only kinds: never dispatched. `planBuilder` is the plan being built or edited ("new", or a plan's ID).
  static const runtime = 'runtime', setupDraft = 'setup_draft', planBuilder = 'plan_builder';
  /// Provider foods this owner has looked at, kept so they can be found again without a connection.
  static const foodCache = 'food_cache';
  static const coachChat = 'coach_chat'; // local-only: this owner's Ask GoHard conversation and unsent question
}

extension type Prescription(Json j) {
  String get occurrenceKey => j['occurrenceKey'] as String? ?? '';
  String? get catalogKey => j['catalogKey'] as String?;
  String get name => j['name'] as String;
  bool get isTimed => j['isTimed'] as bool? ?? false;
  int? get targetSets => j['targetSets'] as int?;
  int? get targetRepsMin => j['targetRepsMin'] as int?;
  int? get targetRepsMax => j['targetRepsMax'] as int?;
  int? get targetDurationSeconds => j['targetDurationSeconds'] as int?;
  int? get restSeconds => j['restSeconds'] as int?;

  /// A target the user set. Never filled in by the app, and never the last recorded load.
  double? get targetLoadKg => _d(j['targetLoadKg']);
  String? get notes => j['notes'] as String?;
}

/// The user's own reusable workout ("Push", "Upper A") inside a plan. Occurrences copy it; they do not point into it.
extension type WorkoutDefinition(Json j) {
  String get id => j['id'] as String;
  String get name => j['name'] as String;
  String? get notes => j['notes'] as String?;
  List<Prescription> get exercises => [for (final e in j['exercises'] as List? ?? const []) Prescription(e as Json)];
}

/// How a built plan's occurrences are laid out. See docs/TRAINING_PLANS.md.
extension type PlanSchedule(Json j) {
  String get mode => j['mode'] as String;
  bool get isRotating => mode == 'rotating';

  /// Fixed: one workout per chosen ISO weekday (1 = Monday). A workout may appear on several days.
  List<({int weekday, String workoutId})> get pattern => [
        for (final p in j['pattern'] as List? ?? const []) (weekday: (p as Json)['weekday'] as int, workoutId: p['workoutId'] as String),
      ];

  /// Rotating: the ordered workouts; the sequence continues across weeks.
  List<String> get cycle => [for (final c in j['cycle'] as List? ?? const []) c as String];
  List<int> get trainingDays => [for (final d in j['trainingDays'] as List? ?? const []) d as int];

  /// The sequence index at which `cycle[0]` applies.
  int get cycleAnchor => j['cycleAnchor'] as int? ?? 0;
}

extension type CustomExercise(Json j) {
  String get id => j['id'] as String;
  String get name => j['name'] as String;
  String get category => j['category'] as String? ?? 'Other';
  String get equipment => j['equipment'] as String? ?? '';
  bool get isTimed => j['isTimed'] as bool? ?? false;
  bool get isArchived => j['isArchived'] as bool? ?? false;
  int get revision => j['revision'] as int? ?? 0;

  /// How a prescription refers to it.
  String get key => 'custom:$id';
}

/// "3 sets · 5–8 reps", "3 sets · 45 s", or an honest "No target" when the prescription has none.
String targetText({int? sets, int? repsMin, int? repsMax, int? seconds}) {
  final parts = <String>[
    if (sets != null) '$sets ${sets == 1 ? 'set' : 'sets'}',
    if (seconds != null) '$seconds s' else if (repsMin != null && repsMax != null && repsMin != repsMax) '$repsMin–$repsMax reps' else if ((repsMin ?? repsMax) != null) '${repsMin ?? repsMax} reps',
  ];
  return parts.isEmpty ? 'No target' : parts.join(' · ');
}

extension type Occasion(Json j) {
  String get id => j['id'] as String;
  int get weekNumber => j['weekNumber'] as int;
  int get ordinal => j['ordinal'] as int;
  String get title => j['title'] as String;
  String get originalDate => j['originalDate'] as String;
  String get scheduledDate => j['scheduledDate'] as String;
  bool get isSkipped => j['isSkipped'] as bool? ?? false;
  String? get resultOutcome => j['resultOutcome'] as String?;
  String? get resultWorkoutId => j['resultWorkoutId'] as String?;
  List<Prescription> get prescription => [for (final e in j['prescription'] as List? ?? const []) Prescription(e as Json)];
  bool get isRecorded => resultOutcome != null;
  bool get wasMoved => originalDate != scheduledDate;

  /// The plan workout this occurrence was made from; null on plans from before the builder.
  String? get workoutId => j['workoutId'] as String?;

  /// Position in a rotating sequence (0-based); null in fixed-weekday plans.
  int? get sequenceIndex => j['sequenceIndex'] as int?;

  /// Edited on its own ("this workout only"); later plan-wide edits leave it alone.
  bool get isCustomised => j['isCustomised'] as bool? ?? false;

  /// A projected rotating occurrence that has not been started or skipped yet: its date is a plan, not a record.
  bool get isVirtual => j['isVirtual'] as bool? ?? false;
}

extension type Plan(Json j) {
  String get id => j['id'] as String;
  String get title => j['title'] as String;
  String get lifecycle => j['lifecycle'] as String;
  String? get closureIntent => j['closureIntent'] as String?;
  bool get isArchived => j['isArchived'] as bool? ?? false;
  String get startDate => j['startDate'] as String;
  int get blockWeeks => j['blockWeeks'] as int;
  int get minRecoveryDays => j['minRecoveryDays'] as int? ?? 1;
  Json? get setup => j['setup'] as Json?;
  String? get pausedOn => j['pausedOn'] as String?;
  int get revision => j['revision'] as int? ?? 0;
  List<Occasion> get occasions => [for (final o in j['occasions'] as List? ?? const []) Occasion(o as Json)]
    ..sort((a, b) => a.scheduledDate == b.scheduledDate ? a.ordinal.compareTo(b.ordinal) : a.scheduledDate.compareTo(b.scheduledDate));
  bool get isDraft => lifecycle == 'draft';
  bool get isActive => lifecycle == 'active';
  bool get isPaused => lifecycle == 'paused';
  bool get isClosed => lifecycle == 'closed';

  /// Built with the plan builder: it has workout definitions and a schedule. Older plans have neither.
  bool get isBuilt => j['schedule'] is Map;
  PlanSchedule? get schedule => isBuilt ? PlanSchedule(j['schedule'] as Json) : null;
  bool get isRotating => schedule?.isRotating ?? false;
  List<WorkoutDefinition> get workouts => [for (final w in j['workouts'] as List? ?? const []) WorkoutDefinition(w as Json)];

  /// Repeats until stopped (rotating plans only). `blockWeeks` is then 1, for older builds.
  bool get isOngoing => j['isOngoing'] as bool? ?? false;

  /// Planned time the user chose. Not a calculated session length.
  int? get timeBudgetMinutes => j['timeBudgetMinutes'] as int?;
  String? get templateId => j['templateId'] as String?;

  String? get endDate {
    if (isRotating) return isOngoing ? null : addDays(startDate, 7 * blockWeeks - 1);
    final o = occasions;
    return o.isEmpty ? null : o.map((x) => x.scheduledDate).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
  }
}

extension type TrainingCtx(Json j) {
  int get contextRevision => j['contextRevision'] as int? ?? 0;
  String? get primaryPlanId => j['primaryPlanId'] as String?;
}

extension type WorkoutExercise(Json j) {
  String get id => j['id'] as String;
  int get ordinal => j['ordinal'] as int;
  String get name => j['name'] as String;
  String? get catalogKey => j['catalogKey'] as String?;
  String? get occurrenceKey => j['occurrenceKey'] as String?;
  bool get isPrescribed => j['isPrescribed'] as bool? ?? false;
  bool get isTimed => j['isTimed'] as bool? ?? false;
  int? get targetSets => j['targetSets'] as int?;
  int? get targetRepsMin => j['targetRepsMin'] as int?;
  int? get targetRepsMax => j['targetRepsMax'] as int?;
  int? get targetDurationSeconds => j['targetDurationSeconds'] as int?;
  int? get restSeconds => j['restSeconds'] as int?;
  String? get substitutedForKey => j['substitutedForKey'] as String?;
  double? get targetLoadKg => _d(j['targetLoadKg']);
  String? get notes => j['notes'] as String?;
  bool get isDeleted => j['isDeleted'] as bool? ?? false;
  String get target => targetText(sets: targetSets, repsMin: targetRepsMin, repsMax: targetRepsMax, seconds: targetDurationSeconds);
}

extension type Workout(Json j) {
  String get id => j['id'] as String;
  String? get planId => j['planId'] as String?;
  String? get occasionId => j['occasionId'] as String?;
  String get kind => j['kind'] as String;
  String get title => j['title'] as String;
  String get dayKey => j['dayKey'] as String;
  String get startedAtUtc => j['startedAtUtc'] as String;
  String? get finishedAtUtc => j['finishedAtUtc'] as String?;
  int? get activeDurationSeconds => j['activeDurationSeconds'] as int?;
  String? get outcome => j['outcome'] as String?;
  int get performedSets => j['performedSets'] as int? ?? 0;
  int get performedExercises => j['performedExercises'] as int? ?? 0;
  bool get qualifiedOccasion => j['qualifiedOccasion'] as bool? ?? false;
  bool get isDeleted => j['isDeleted'] as bool? ?? false;
  bool get isManual => kind == 'manual';
  bool get isOpen => finishedAtUtc == null && !isDeleted;
  List<WorkoutExercise> get exercises => [
        for (final e in j['exercises'] as List? ?? const [])
          if (!WorkoutExercise(e as Json).isDeleted) WorkoutExercise(e)
      ]..sort((a, b) => a.ordinal.compareTo(b.ordinal));
}

extension type WorkoutSet(Json j) {
  String get id => j['id'] as String;
  String get exerciseId => j['exerciseId'] as String;
  String get workoutId => j['workoutId'] as String;
  int? get reps => j['reps'] as int?;
  double? get loadKg => _d(j['loadKg']);
  int? get durationSeconds => j['durationSeconds'] as int?;
  String get performedAtUtc => j['performedAtUtc'] as String;
  bool get isDeleted => j['isDeleted'] as bool? ?? false;
}

extension type FoodEntry(Json j) {
  String get id => j['id'] as String;
  String get dayKey => j['dayKey'] as String;
  String get meal => j['meal'] as String;
  String get name => j['name'] as String;
  String get amountDescription => j['amountDescription'] as String;
  Json get macros => j['macros'] as Json? ?? const {};
  // Null means unknown. Zero means the user entered zero. Never coalesce these.
  double? get calories => _d(macros['calories']);
  double? get protein => _d(macros['protein']);
  double? get carbs => _d(macros['carbs']);
  double? get fat => _d(macros['fat']);
  bool get isDeleted => j['isDeleted'] as bool? ?? false;

  /// Where the values came from when this was logged: `{item, quantity, unit}`. Null when typed by hand.
  /// It is this entry's own copy; nothing that happens to the food later changes it.
  Json? get source => j['source'] as Json?;
}

const meals = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

extension type Profile(Json j) {
  String get userId => j['userId'] as String;
  String get email => j['email'] as String;
  String get displayName => j['displayName'] as String;
  String get appearance => j['appearance'] as String? ?? 'dark';
  String get loadUnit => j['loadUnit'] as String? ?? 'kg';
  bool get remindersEnabled => j['remindersEnabled'] as bool? ?? false;
  String? get reminderLocalTime => j['reminderLocalTime'] as String?;

  /// Optional daily goals. Null = none set; the app never suggests one.
  int? get calorieGoal => j['calorieGoal'] as int?;
  int? get proteinGoal => j['proteinGoal'] as int?;
  int get revision => j['revision'] as int? ?? 0;
}

extension type Run(Json j) {
  String get id => j['id'] as String;
  String get dayKey => j['dayKey'] as String;
  String get startedAtUtc => j['startedAtUtc'] as String;
  String? get finishedAtUtc => j['finishedAtUtc'] as String?;
  int? get activeDurationSeconds => j['activeDurationSeconds'] as int?;
  double? get distanceMeters => _d(j['distanceMeters']);
  bool get isDeleted => j['isDeleted'] as bool? ?? false;
  bool get isOpen => finishedAtUtc == null && !isDeleted;
}

extension type BodyMetric(Json j) {
  String get id => j['id'] as String;
  String get dayKey => j['dayKey'] as String;
  double? get weightKg => _d(j['weightKg']);
  double? get bodyFatPercent => _d(j['bodyFatPercent']);
  String? get note => j['note'] as String?;
  bool get isDeleted => j['isDeleted'] as bool? ?? false;
}

extension type Proposal(Json j) {
  String get id => j['id'] as String;
  String get planId => j['planId'] as String;
  String get kind => j['kind'] as String;
  String get state => j['state'] as String;
  String get explanation => j['explanation'] as String? ?? '';
  int get revision => j['revision'] as int? ?? 0;
  Json get change => j['change'] as Json? ?? const {};
  List<Json> get moves => [for (final m in change['moves'] as List? ?? const []) m as Json];
  List<String> get affectedOccasionIds => [for (final i in change['affectedOccasionIds'] as List? ?? const []) i as String];
}

extension type CatalogExercise(Json j) {
  /// Null for a custom movement the user typed: it has no catalog identity and so no cross-session history.
  String? get key => j['key'] as String?;
  String get name => j['name'] as String;
  String get category => j['category'] as String;
  String get equipment => j['equipment'] as String;
  bool get isTimed => j['isTimed'] as bool? ?? false;

  /// One of the owner's own exercises (key `custom:<id>`), not the shared catalog.
  bool get isCustom => j['isCustom'] as bool? ?? false;
}
