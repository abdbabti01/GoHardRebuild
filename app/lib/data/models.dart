/// Typed views over wire-shaped JSON (contract version 1). The same shape is used on the wire and in
/// the local store, so a record never passes through a lossy translation.
/// Units: *Kg kilograms, *Seconds seconds, dayKey/…Date calendar `YYYY-MM-DD`, *AtUtc ISO-8601 UTC instants.
library;

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
  static const run = 'run', metric = 'metric', proposal = 'proposal', catalog = 'catalog';
  // Local-only kinds: never dispatched.
  static const runtime = 'runtime', setupDraft = 'setup_draft';
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
  String? get endDate {
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
}
