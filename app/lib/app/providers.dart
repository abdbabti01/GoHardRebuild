import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/compatibility.dart';
import '../core/config.dart';
import '../core/units.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../data/sync.dart';
import '../features/me/account_repository.dart';
import '../features/nutrition/food_discovery.dart';
import '../features/nutrition/food_item.dart';
import '../features/nutrition/food_repository.dart';
import '../features/nutrition/food_search.dart';
import '../features/nutrition/nutrient_coverage.dart';
import '../features/nutrition/water.dart';
import '../features/plans/plan_draft.dart';
import '../features/plans/plan_repository.dart';
import '../features/today/daily.dart';
import '../features/workout/progress.dart';
import '../features/workout/workout_repository.dart';
import '../features/workout/workout_runtime.dart';

/// Composition root. Widgets read feature state from providers; providers talk to repositories;
/// repositories talk to the local store and the sync engine. Widgets never touch Dio or Drift.

final dbProvider = Provider<AppDb>((_) => throw StateError('dbProvider must be overridden at startup'));
final sessionsProvider = Provider<SessionManager>((_) => throw StateError('sessionsProvider must be overridden at startup'));
final clockProvider = Provider<AppClock>((_) => const SystemClock());
final transportProvider = Provider<Transport>((_) => DioTransport(AppConfig.apiBase));
final apiProvider = Provider<Api>((ref) => Api(ref.watch(transportProvider), ref.watch(sessionsProvider)));

final syncProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(ref.watch(dbProvider), ref.watch(apiProvider), ref.watch(sessionsProvider));
  // Read at the moment of use: a build the server no longer accepts sends and pulls nothing, and keeps its outbox.
  engine.isBlocked = () => ref.read(compatibilityProvider).blocked;
  ref.onDispose(engine.dispose);
  return engine;
});

/// The signed-in owner. Everything owner-scoped watches this, so an account change tears down every
/// stream of the previous owner before the next owner's data is read.
class SessionNotifier extends Notifier<Session?> {
  @override
  Session? build() {
    final manager = ref.watch(sessionsProvider);
    void listener() => state = manager.current;
    manager.addListener(listener);
    ref.onDispose(() => manager.removeListener(listener));
    return manager.current;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);
final ownerProvider = Provider<String?>((ref) => ref.watch(sessionProvider)?.ownerId);

final dateServiceProvider = Provider<BusinessDateService>((ref) {
  final service = BusinessDateService(ref.watch(clockProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// The shared local calendar day for Today and Eat.
class TodayKey extends Notifier<String> {
  @override
  String build() {
    final service = ref.watch(dateServiceProvider);
    final sub = service.changes.listen((key) => state = key);
    ref.onDispose(sub.cancel);
    return service.dayKey;
  }
}

final todayKeyProvider = NotifierProvider<TodayKey, String>(TodayKey.new);

/// A stored record with its synchronization state, decoded once.
class Stored<T> {
  const Stored(this.value, this.rec);
  final T value;
  final Rec rec;
  bool get isPending => rec.syncState == 'pending';
  bool get needsReview => rec.syncState == 'conflict' || rec.syncState == 'rejected';
  Json? get serverBody => rec.serverBody == null ? null : jsonDecode(rec.serverBody!) as Json;
  Json? get alternativeBody => rec.alternativeBody == null ? null : jsonDecode(rec.alternativeBody!) as Json;
}

Stream<List<Stored<T>>> _rows<T>(Ref ref, String kind, T Function(Json) wrap, {String? parentId, String? dayKey}) {
  final owner = ref.watch(ownerProvider);
  if (owner == null) return Stream.value(const []);
  return ref.watch(syncProvider).watch(owner, kind, parentId: parentId, dayKey: dayKey).map((recs) => [for (final r in recs) Stored(wrap(jsonDecode(r.body) as Json), r)]);
}

final profileProvider = StreamProvider<Profile?>((ref) => _rows(ref, Kinds.profile, Profile.new).map((l) => l.firstOrNull?.value));
final contextRowProvider = StreamProvider<Stored<TrainingCtx>?>((ref) => _rows(ref, Kinds.context, TrainingCtx.new).map((l) => l.firstOrNull));
final plansProvider = StreamProvider<List<Stored<Plan>>>((ref) => _rows(ref, Kinds.plan, Plan.new));
final workoutsProvider = StreamProvider<List<Stored<Workout>>>((ref) => _rows(ref, Kinds.workout, Workout.new));
final allSetsProvider = StreamProvider<List<Stored<WorkoutSet>>>((ref) => _rows(ref, Kinds.set, WorkoutSet.new));
final setsProvider = StreamProvider.family<List<Stored<WorkoutSet>>, String>((ref, workoutId) => _rows(ref, Kinds.set, WorkoutSet.new, parentId: workoutId));
final runtimesProvider = StreamProvider<List<Stored<Json>>>((ref) => _rows(ref, Kinds.runtime, (j) => j));
final foodProvider = StreamProvider.family<List<Stored<FoodEntry>>, String>((ref, dayKey) => _rows(ref, Kinds.food, FoodEntry.new, dayKey: dayKey));
/// One day's water entries, deleted ones included (the readers leave them out), on the day they were logged.
final waterProvider = StreamProvider.family<List<Stored<WaterEntry>>, String>((ref, dayKey) => _rows(ref, Kinds.water, WaterEntry.new, dayKey: dayKey));
/// Every food entry of the owner, for "recent": the journal itself is the history of what was eaten.
final foodJournalProvider = StreamProvider<List<Stored<FoodEntry>>>((ref) => _rows(ref, Kinds.food, FoodEntry.new));
final savedFoodsProvider = StreamProvider<List<Stored<SavedFood>>>((ref) => _rows(ref, Kinds.savedFood, SavedFood.new));
/// Provider foods kept on this phone for this owner, newest first.
final seenFoodsProvider = StreamProvider<List<FoodItem>>((ref) => _rows(ref, Kinds.foodCache, (j) => j).map((rows) =>
    [for (final r in [...rows]..sort((a, b) => (b.value['cachedAtUtc'] as String).compareTo(a.value['cachedAtUtc'] as String))) FoodItem(r.value['item'] as Json)]));
final runsProvider = StreamProvider<List<Stored<Run>>>((ref) => _rows(ref, Kinds.run, Run.new));
final metricsProvider = StreamProvider<List<Stored<BodyMetric>>>((ref) => _rows(ref, Kinds.metric, BodyMetric.new));
final proposalsProvider = StreamProvider<List<Stored<Proposal>>>((ref) => _rows(ref, Kinds.proposal, Proposal.new));
final catalogProvider = StreamProvider<List<CatalogExercise>>((ref) =>
    _rows(ref, Kinds.catalog, CatalogExercise.new).map((l) => [for (final r in l) r.value]..sort((a, b) => a.name.compareTo(b.name))));
final customExercisesProvider = StreamProvider<List<CustomExercise>>((ref) =>
    _rows(ref, Kinds.customExercise, CustomExercise.new).map((l) => [for (final r in l) r.value]..sort((a, b) => a.name.compareTo(b.name))));

/// Everything an exercise can be chosen from: the shared catalog and the owner's own (not archived) exercises, as
/// [CatalogExercise] values. A custom one has key `custom:<id>` and category/equipment as the owner gave them.
final exerciseChoicesProvider = Provider<List<CatalogExercise>>((ref) => [
      for (final c in ref.watch(customExercisesProvider).value ?? const <CustomExercise>[])
        if (!c.isArchived) CatalogExercise({'key': c.key, 'name': c.name, 'category': c.category, 'equipment': c.equipment, 'isTimed': c.isTimed, 'isCustom': true}),
      ...ref.watch(catalogProvider).value ?? const <CatalogExercise>[],
    ]);

/// The bundled starter templates (same for every account, no connection needed).
final planTemplatesProvider = FutureProvider<PlanTemplates>((ref) async => PlanTemplates.parse(await rootBundle.loadString('assets/data/plan-templates.json')));

/// Records that cannot converge without a decision. Ordinary pending upload is not an issue.
final issuesProvider = StreamProvider<List<Rec>>((ref) {
  final owner = ref.watch(ownerProvider);
  return owner == null ? Stream.value(const []) : ref.watch(syncProvider).watchIssues(owner);
});

final pendingCountProvider = StreamProvider<int>((ref) {
  final owner = ref.watch(ownerProvider);
  return owner == null ? Stream.value(0) : ref.watch(syncProvider).watchPendingCount(owner);
});

/// Display preferences. Appearance (accent and mode) is a device setting: see core/appearance.dart.
final loadUnitProvider = Provider<LoadUnit>((ref) => LoadUnit.parse(ref.watch(profileProvider).value?.loadUnit));

/// Whether the last attempt to reach the account succeeded. Null = not tried yet.
class Connection extends Notifier<bool?> {
  @override
  bool? build() => null;
  void report(bool reachable) => state = reachable;
}

final connectionProvider = NotifierProvider<Connection, bool?>(Connection.new);

/// What Today and Me both say while that attempt has failed. The app knows only that the account did not answer
/// properly: it cannot tell a phone without a connection from a server in trouble, so it never says "Offline".
const cantSyncLabel = 'Can\'t sync right now';
const cantSyncDetail = 'The last attempt to reach your account did not get through. That can be this phone\'s connection or the server.';

/// "1 change waiting to sync": the real number of saved changes the account has not confirmed yet.
String waitingToSync(int pending) => '$pending ${pending == 1 ? 'change' : 'changes'} waiting to sync';

/// Pulls account state and pushes pending work. Safe to call often; never throws.
Future<void> refreshFromAccount(WidgetRef ref) async {
  final sync = ref.read(syncProvider);
  await sync.flush();
  final ok = await sync.pull();
  if (ref.context.mounted) ref.read(connectionProvider.notifier).report(ok);
}

// ---------------------------------------------------------------------------- repositories

T _owned<T>(Ref ref, T Function(SyncEngine sync, String owner) create) {
  final owner = ref.watch(ownerProvider);
  if (owner == null) throw StateError('No signed-in owner');
  return create(ref.watch(syncProvider), owner);
}

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiProvider), ref.watch(sessionsProvider), ref.watch(syncProvider)));
final planRepositoryProvider = Provider((ref) => _owned(ref, PlanRepository.new));
final foodRepositoryProvider = Provider((ref) => _owned(ref, FoodRepository.new));
final waterRepositoryProvider = Provider((ref) => _owned(ref, WaterRepository.new));
final savedFoodRepositoryProvider = Provider((ref) => _owned(ref, SavedFoodRepository.new));
final foodDiscoveryProvider = Provider((ref) => _owned(ref, (s, o) => FoodDiscovery(ref.watch(apiProvider), s, o, ref.watch(clockProvider))));
final profileRepositoryProvider = Provider((ref) => _owned(ref, ProfileRepository.new));
final workoutRepositoryProvider = Provider((ref) => _owned(ref, (s, o) => WorkoutRepository(s, o, ref.watch(clockProvider))));
final activityRepositoryProvider = Provider((ref) => _owned(ref, (s, o) => ActivityRepository(s, o, ref.watch(clockProvider))));

// ---------------------------------------------------------------------------- shared projections

List<T> _values<T>(AsyncValue<List<Stored<T>>> rows) => [for (final r in rows.value ?? const []) r.value];

final restDaysProvider = StreamProvider<List<Stored<Json>>>((ref) => _rows(ref, Kinds.restDay, (j) => j));

/// The owner's plans, each with the rest days chosen for it on this phone, so every reader of the projection
/// (Today, Train, the occurrence sheet) dates a rotation the same way.
final planListProvider = Provider<List<Plan>>((ref) {
  final rest = <String, List<String>>{};
  for (final r in ref.watch(restDaysProvider).value ?? const <Stored<Json>>[]) {
    (rest[r.value['planId'] as String] ??= []).add(r.value['dayKey'] as String);
  }
  return [for (final p in _values(ref.watch(plansProvider))) Plan({...p.j, 'localRestDays': rest[p.id] ?? const <String>[]})];
});
final workoutListProvider = Provider<List<Workout>>((ref) => _values(ref.watch(workoutsProvider)));
final trainingCtxProvider = Provider<TrainingCtx?>((ref) => ref.watch(contextRowProvider).value?.value);
final primaryPlanProvider = Provider<Plan?>((ref) {
  final id = ref.watch(trainingCtxProvider)?.primaryPlanId;
  return ref.watch(planListProvider).where((p) => p.id == id).firstOrNull;
});

/// Open workouts the user saved for later.
final parkedIdsProvider = Provider<Set<String>>((ref) => {
      for (final r in ref.watch(runtimesProvider).value ?? const <Stored<Json>>[])
        if (WorkoutRuntime(r.value).isParked) r.rec.id
    });

/// Sets that may feed progress and previous performance: not deleted and not awaiting conflict review.
final trustedSetsProvider = Provider<List<WorkoutSet>>((ref) => [
      for (final r in ref.watch(allSetsProvider).value ?? const <Stored<WorkoutSet>>[])
        if (!r.needsReview && !r.value.isDeleted) r.value
    ]);

/// One immutable projection of the day for Today, from the same records Train and Eat use.
/// Null while the owner's local records are still loading.
final dailySnapshotProvider = Provider<DailySnapshot?>((ref) {
  final owner = ref.watch(ownerProvider);
  final day = ref.watch(todayKeyProvider);
  final plans = ref.watch(plansProvider), workouts = ref.watch(workoutsProvider), food = ref.watch(foodProvider(day)), ctx = ref.watch(contextRowProvider);
  // Food is deliberately not required: a journal that is loading or unreadable must never hide the training action.
  if (owner == null || !plans.hasValue || !workouts.hasValue || !ctx.hasValue) return null;
  final all = ref.watch(workoutListProvider);
  final entries = [for (final r in food.value ?? const <Stored<FoodEntry>>[]) if (!r.value.isDeleted) r.value];
  final training = resolveTraining(today: day, ctx: ref.watch(trainingCtxProvider), plans: ref.watch(planListProvider), workouts: all);
  final open = openWorkouts(all, ref.watch(parkedIdsProvider), training);
  return DailySnapshot(
    ownerId: owner,
    dayKey: day,
    training: training,
    inProgress: open.inProgress,
    parked: open.parked,
    finishedToday: [for (final w in all) if (!w.isOpen && !w.isDeleted && w.dayKey == day) w],
    food: entries,
    coverage: NutrientCoverage.calculate(entries),
    runs: [for (final r in ref.watch(runsProvider).value ?? const <Stored<Run>>[]) if (!r.value.isDeleted && r.value.dayKey == day) r.value],
  );
});

final progressProvider = Provider<TrainingProgress>((ref) => TrainingProgressProjection.build(
    today: ref.watch(todayKeyProvider), primary: ref.watch(primaryPlanProvider), workouts: ref.watch(workoutListProvider), sets: ref.watch(trustedSetsProvider)));

/// The everyday foods bundled with the app, read once. It is the same for every account and needs no connection.
/// Read as bytes: `loadString` would decode a file this size on another isolate, for nothing.
final commonFoodsProvider = FutureProvider<CommonFoodCatalog>(
    (ref) async => CommonFoodCatalog.parse(utf8.decode(Uint8List.sublistView(await rootBundle.load('assets/data/common-foods.json')))));
