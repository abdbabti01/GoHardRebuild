/// Typed views over wire-shaped JSON (contract version 1). The same shape is used on the wire and in
/// the local store, so a record never passes through a lossy translation.
/// Units: *Kg kilograms, *Seconds seconds, dayKey/…Date calendar `YYYY-MM-DD`, *AtUtc ISO-8601 UTC instants.
library;

import '../core/clock.dart';
import '../core/format.dart' show ltr;
import '../core/language.dart' show AppLocalizations, currentL10n;

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
  /// `route` (id = the activity's id) tracks the upload of a saved route: pending until the account confirms it whole.
  static const run = 'run', route = 'route', metric = 'metric', proposal = 'proposal', catalog = 'catalog', savedFood = 'saved_food';
  /// Water the owner logged (features/nutrition/water.dart).
  static const water = 'water';
  /// The owner's private exercises; referenced from prescriptions as `custom:<id>`.
  static const customExercise = 'custom_exercise';
  /// Weekly activity targets, one record per effective Monday (id = that Monday's day key). docs/PROGRESS.md.
  static const weeklyGoal = 'weekly_goal';
  /// The load step the owner confirmed for one exercise identity (id = catalogue key or `custom:<id>`). docs/PROGRESSION.md.
  static const exerciseIncrement = 'exercise_increment';
  // Local-only kinds: never dispatched. `planBuilder` is the plan being built or edited ("new", or a plan's ID).
  static const runtime = 'runtime', setupDraft = 'setup_draft', planBuilder = 'plan_builder';
  /// Provider foods this owner has looked at, kept so they can be found again without a connection.
  static const foodCache = 'food_cache';
  /// A day the person chose to rest in a rotation (`{planId, dayKey}`). Local only; it skips and consumes nothing.
  static const restDay = 'rest_day';
  /// This owner's Ask GoHard conversation and unsent question. Local only.
  static const coachChat = 'coach_chat';
  /// Next-target history for one plan exercise (id = `planId|workoutId|occurrenceKey`): the suggestion kept as it is,
  /// and the target before an accepted one. Local only (docs/PROGRESSION.md).
  static const progression = 'progression';
  /// What the server last said about this owner's access (id = the owner): required verification and a legacy grace
  /// deadline. Local only, written only from server answers; never a code or a password. docs/AUTHENTICATION_EMAIL.md.
  static const accountAccess = 'account_access';
  /// Saved meals and recipes: templates, never food eaten (features/nutrition/saved_meals.dart).
  static const savedMeal = 'saved_meal';
  /// An unfinished saved meal or recipe being edited (id = the definition's ID, or `new:meal` / `new:recipe`). Local only.
  static const mealDraft = 'meal_draft';
  /// Eating out on this phone (docs/EATING_OUT.md): `draft` (the order being built, with its chain and preferences) and
  /// `catalog` (the last restaurant catalog the account's server sent). Local only.
  static const eatOut = 'eat_out';
  /// The person's own meal, medication and supplement reminders, and their answers to medication and supplement
  /// occurrences (id = the occurrence key). Local only: never sent to the account (docs/MEAL_HABITS_REMINDERS.md).
  static const reminder = 'reminder', reminderLog = 'reminder_log';
  /// Meal suggestions on this phone: `prefs` (on, off, or not chosen yet, and the meals set aside for a day), and when
  /// each meal was first logged on its own day (id = `day|meal`). Local only.
  static const habit = 'habit', logTime = 'log_time';
}

/// The server's word on whether this account may use its data (docs/AUTHENTICATION_EMAIL.md › Required verification).
extension type AccountAccess(Json j) {
  /// The server refuses this account's data until it verifies its address.
  bool get required => j['required'] as bool? ?? false;
  bool get verified => j['verified'] as bool? ?? false;

  /// The end of a legacy account's grace period; null for a new account (verify at once) and a verified one.
  DateTime? get dueAt => DateTime.tryParse(j['dueAtUtc'] as String? ?? '')?.toLocal();

  /// A new account: nothing of the app until it verifies. A legacy account past its deadline keeps the app, paused.
  bool get mustVerifyFirst => required && dueAt == null;
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

/// "3 sets · 5–8 reps", "3 sets · 45 s", or an honest "No target" when the prescription has none, in [l] (the
/// resolved app language when omitted).
String targetText({int? sets, int? repsMin, int? repsMax, int? seconds, AppLocalizations? l}) {
  l ??= currentL10n;
  final parts = <String>[
    if (sets != null) l.workoutTargetSets(sets),
    if (seconds != null) l.durationSeconds(seconds)
    else if (repsMin != null && repsMax != null && repsMin != repsMax) l.workoutTargetRepRange(ltr('$repsMin–$repsMax'))
    else if ((repsMin ?? repsMax) != null) l.workoutTargetReps(repsMin ?? repsMax!),
  ];
  return parts.isEmpty ? l.workoutNoTarget : parts.join(' · ');
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

  /// Days the person chose to rest in this rotation ([Kinds.restDay], laid over the plan by `planListProvider`).
  Set<String> get restDays => {...?(j['localRestDays'] as List?)?.cast<String>()};

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
  /// A recipe portion's is `{recipe, portion, partial}` instead (features/nutrition/saved_meals.dart).
  Json? get source => j['source'] as Json?;

  /// One portion of a recipe, with the frozen batch it was taken from.
  bool get isRecipePortion => source?['recipe'] is Map;

  /// For a nutrient some ingredient has no value for: the sum of the values that are known. Its `macros` value is
  /// null (unknown), so an app that does not read this never takes a partial sum for a total.
  double? partial(String key) => _d((source?['partial'] as Map?)?[key]);
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
  /// Optional daily water goal in millilitres; null = none (never suggested).
  int? get waterGoalMl => j['waterGoalMl'] as int?;

  /// What the account chose to see in its nutrition; null = never chosen on the account (an explicit false is a choice).
  bool? get showWater => j['showWater'] as bool?;
  bool? get showCarbs => j['showCarbs'] as bool?;
  bool? get showFat => j['showFat'] as bool?;
  int get revision => j['revision'] as int? ?? 0;

  /// The server says the account's email is verified. Null: a server from before verification (say nothing).
  bool? get emailVerified => j['emailVerified'] as bool?;
}

/// Weekly activity targets effective from [weekStart] (a Monday) until a later record. Null = no target; both null
/// = goals cleared from that week. Never suggested by the app.
extension type WeeklyGoal(Json j) {
  String get weekStart => j['weekStart'] as String;
  int? get workoutsTarget => j['workoutsTarget'] as int?;
  int? get runWalkTarget => j['runWalkTarget'] as int?;
  int get revision => j['revision'] as int? ?? 0;
  bool get isEmpty => workoutsTarget == null && runWalkTarget == null;
}

/// The load step for one exercise identity, in kilograms; null = cleared. Never preselected (docs/PROGRESSION.md).
extension type ExerciseIncrement(Json j) {
  String get exerciseKey => j['exerciseKey'] as String;
  double? get incrementKg => _d(j['incrementKg']);
  int get revision => j['revision'] as int? ?? 0;
}

/// A Run or Walk (docs/RUN_WALK.md). Records from before Run / Walk have no type and are runs.
extension type Run(Json j) {
  String get id => j['id'] as String;
  String get dayKey => j['dayKey'] as String;
  String get startedAtUtc => j['startedAtUtc'] as String;
  String? get finishedAtUtc => j['finishedAtUtc'] as String?;
  int? get activeDurationSeconds => j['activeDurationSeconds'] as int?;
  double? get distanceMeters => _d(j['distanceMeters']);
  bool get isDeleted => j['isDeleted'] as bool? ?? false;
  bool get isOpen => finishedAtUtc == null && !isDeleted;

  /// `run` or `walk`; never changed except by the person's edit.
  String get activityType => j['activityType'] as String? ?? 'run';
  bool get isWalk => activityType == 'walk';
  String? get title => j['title'] as String?;
  String? get notes => j['notes'] as String?;

  /// Derived summary (docs/RUN_WALK.md › Activity record). Empty for a record from before routes.
  Json get metrics => (j['metrics'] as Map?)?.cast<String, dynamic>() ?? const {};
  bool get isLegacy => j['metrics'] == null;
  int? get movingSeconds => metrics['movingSeconds'] as int?;
  int? get elapsedSeconds => metrics['elapsedSeconds'] as int?;
  double? get elevationGainMeters => _d(metrics['elevationGainMeters']);

  /// gps | corrected | manual | none
  String get distanceSource => metrics['distanceSource'] as String? ?? (distanceMeters == null ? 'none' : 'manual');

  /// What the account holds of the route: none | uploading | complete.
  String get routeState => j['routeState'] as String? ?? 'none';
}

/// One body check-in (docs/BODY_PROGRESS.md). Every value is optional; null is "not recorded", never zero.
/// Circumferences (`waistCm`, `chestCm`, `leftUpperArmCm`, …) are read by key through [value].
extension type BodyMetric(Json j) {
  String get id => j['id'] as String;
  String get dayKey => j['dayKey'] as String;
  double? get weightKg => _d(j['weightKg']);
  double? get bodyFatPercent => _d(j['bodyFatPercent']);
  String? get note => j['note'] as String?;
  bool get isDeleted => j['isDeleted'] as bool? ?? false;
  int get revision => j['revision'] as int? ?? 0;

  /// A canonical value by its wire key (kg, cm or %).
  double? value(String key) => _d(j[key]);

  /// When this phone first saved it. Null on check-ins from before it: their order within a day is unknown.
  String? get recordedAtUtc => j['recordedAtUtc'] as String?;
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
