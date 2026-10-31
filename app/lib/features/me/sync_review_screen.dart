import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import '../../core/compatibility.dart';
import '../body/body_metrics.dart';
import '../body/body_repository.dart';
import '../nutrition/water.dart';
import '../plans/train_screen.dart' show builderDraftProvider;
import '../workout/workout_screen.dart';

/// A plain description of one stored version, for comparing "on this phone" with "in your account". Names, titles and
/// amounts the person typed or chose stay as stored.
String describeRecord(AppLocalizations l, String kind, Json j, LoadUnit unit) => switch (kind) {
      Kinds.set => (j['isDeleted'] as bool? ?? false) ? l.syncRemoved : setText(WorkoutSet(j), unit),
      Kinds.food => (j['isDeleted'] as bool? ?? false)
          ? l.syncRemoved
          : FoodEntry(j).calories == null
              ? l.syncFoodLine('${j['name']}', '${j['amountDescription']}', '${j['meal']}', shortDate(j['dayKey'] as String))
              : l.syncFoodLineCalories('${j['name']}', '${j['amountDescription']}', '${j['meal']}', shortDate(j['dayKey'] as String), formatNumber(FoodEntry(j).calories!)),
      Kinds.workout => j['finishedAtUtc'] == null
          ? l.syncWorkoutInProgress('${j['title']}', shortDate(j['dayKey'] as String))
          : l.syncWorkoutFinished('${j['title']}', shortDate(j['dayKey'] as String), '${j['outcome']}'),
      Kinds.context => j['primaryPlanId'] == null ? l.syncNoPrimaryPlan : l.syncPrimaryPlanSet,
      Kinds.plan => l.syncPlanLine('${j['title']}', '${j['lifecycle']}'),
      Kinds.profile => [
          l.syncProfileLine('${j['displayName']}', '${j['appearance']}', '${j['loadUnit']}'),
          if (j['calorieGoal'] != null) l.syncGoalCalories('${j['calorieGoal']}'),
          if (j['proteinGoal'] != null) l.syncGoalProtein('${j['proteinGoal']}'),
          if (j['waterGoalMl'] != null) l.syncGoalWater('${j['waterGoalMl']}'),
        ].join(' · '),
      Kinds.savedFood => (j['isDeleted'] as bool? ?? false)
          ? l.syncRemoved
          : [(j['item'] as Json?)?['name'] as String? ?? l.syncFoodFallback, if (j['isFavourite'] == true) l.syncFavourite].join(' · '),
      Kinds.run => l.syncRunLine(shortDate(j['dayKey'] as String)),
      // Water is described in millilitres, the stored amount, whatever display unit is chosen.
      Kinds.water => (j['isDeleted'] as bool? ?? false) ? l.syncRemoved : l.syncWaterLine(VolumeUnit.ml.format((j['volumeMl'] as num).toDouble()), shortDate(j['dayKey'] as String)),
      Kinds.weeklyGoal => l.syncWeeklyGoalsLine(
          shortDate(j['weekStart'] as String),
          j['workoutsTarget'] == null ? l.syncNoWorkoutTarget : l.syncWorkoutsTarget(j['workoutsTarget'] as int),
          j['runWalkTarget'] == null ? l.syncNoRunWalkTarget : l.syncRunWalkTarget(j['runWalkTarget'] as int)),
      Kinds.exerciseIncrement => ExerciseIncrement(j).incrementKg == null ? l.syncNoIncrement : l.syncIncrement(formatLoad(ExerciseIncrement(j).incrementKg, unit)),
      // Circumferences in centimetres, the stored unit; weight in the lifting unit.
      Kinds.metric => (j['isDeleted'] as bool? ?? false)
          ? l.syncRemoved
          : [for (final f in BodyField.values) if (BodyMetric(j).value(f.key) != null) l.bodyFieldValue(bodyFieldLabel(l, f), BodyUnits(unit, LengthUnit.cm).value(f, BodyMetric(j).value(f.key))), shortDate(j['dayKey'] as String)].join(' · '),
      _ => kind,
    };

String _title(AppLocalizations l, String kind) => switch (kind) {
      Kinds.set => l.syncKindSet,
      Kinds.food => l.syncKindFood,
      Kinds.workout => l.syncKindWorkout,
      Kinds.context => l.syncKindContext,
      Kinds.plan => l.syncKindPlan,
      Kinds.profile => l.syncKindProfile,
      Kinds.run => l.syncKindRun,
      Kinds.metric => l.syncKindMetric,
      Kinds.proposal => l.syncKindProposal,
      Kinds.savedFood => l.syncKindSavedFood,
      Kinds.water => l.syncKindWater,
      Kinds.weeklyGoal => l.syncKindWeeklyGoal,
      Kinds.exerciseIncrement => l.syncKindIncrement,
      _ => kind,
    };

/// The account's error code (stored as it came) in words.
String _reason(AppLocalizations l, String? code) => switch (code) {
      'REVISION_CONFLICT' => l.syncReasonRevisionConflict,
      'SET_DELETED' || 'ENTRY_DELETED' => l.syncReasonDeleted,
      'OCCASION_NOT_ELIGIBLE' => l.syncReasonOccasionNotEligible,
      'ALREADY_FINISHED' => l.syncReasonAlreadyFinished,
      'SET_DEPENDENCY_MISMATCH' => l.syncReasonSetMismatch,
      'PRIMARY_EXISTS' || 'PLAN_NOT_DRAFT' || 'PLAN_NOT_ACTIVE' || 'PLAN_NOT_PAUSED' || 'STALE_REVIEW' => l.syncReasonPlansChanged,
      'NOT_FOUND' => l.syncReasonNotFound,
      'PLAN_LIMIT' => l.syncReasonPlanLimit,
      _ => l.syncReasonOther(code == null ? l.syncReasonUnknownCode : ltr(code)),
    };

/// Changes that could not converge on their own. Both versions are kept until you choose; choosing never
/// adds a record, finishes a workout or silently discards the other version.
class SyncReviewScreen extends ConsumerWidget {
  const SyncReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(issuesProvider).value ?? const <Rec>[];
    final l = context.l10n;
    return AppPage(title: l.syncReviewTitle, children: [
      Text(l.syncReviewIntro, style: context.caption),
      if (issues.isEmpty) EmptyState(l.syncReviewEmptyTitle, l.syncReviewEmptyBody),
      for (final rec in issues) _Issue(rec),
    ]);
  }
}

class _Issue extends ConsumerWidget {
  const _Issue(this.rec);
  final Rec rec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.read(syncProvider);
    final unit = ref.watch(loadUnitProvider);
    final local = jsonDecode(rec.body) as Json;
    final server = rec.serverBody == null ? null : jsonDecode(rec.serverBody!) as Json;
    final l = context.l10n;

    Future<void> act(Future<void> Function(Cmd cmd) action, String Function(AppLocalizations l) done) async {
      final cmd = await sync.issueFor(rec.ownerId, rec.kind, rec.id);
      if (cmd == null) return;
      await action(cmd);
      if (context.mounted) toast(context, done(context.l10n));
    }

    return FutureBuilder<Cmd?>(
      future: sync.issueFor(rec.ownerId, rec.kind, rec.id),
      builder: (context, snap) {
        final cmd = snap.data;
        final refusedStart = cmd?.kind == 'workout.start';
        // A refused new plan (docs/PLAN_LIBRARY_OVERLOAD.md): its content can go back to the builder, nothing lost.
        final refusedPlan = cmd?.kind == 'plan.create' && rec.syncState == 'rejected' && rec.revision == 0;
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionLabel(_title(l, rec.kind)),
              const SizedBox(height: 6),
              Text(_reason(l, cmd?.lastError), style: context.body),
              const SizedBox(height: 12),
              Text(l.syncOnThisPhone, style: context.caption),
              Text(describeRecord(l, rec.kind, local, unit), style: context.sansStyle(15, weight: FontWeight.w600)),
              if (server != null) ...[
                const SizedBox(height: 8),
                Text(l.syncInYourAccount, style: context.caption),
                Text(describeRecord(l, rec.kind, server, unit), style: context.sansStyle(15, weight: FontWeight.w600)),
              ],
              const SizedBox(height: 14),
              if (rec.syncState == 'conflict' && server != null && (rec.kind == Kinds.set || rec.kind == Kinds.food || rec.kind == Kinds.weeklyGoal || rec.kind == Kinds.exerciseIncrement ||
                  (rec.kind == Kinds.metric && !BodyMetric(local).isDeleted && ref.watch(compatibilityProvider).supports(BodyRepository.capability)))) ...[
                PrimaryButton(l.syncKeepLocal, key: Key('issue-keep-${rec.id}'), onPressed: () => act(
                    (cmd) => switch (rec.kind) {
                          Kinds.set => ref.read(workoutRepositoryProvider).keepLocalSet(cmd.operationId, WorkoutSet(local)),
                          Kinds.weeklyGoal => ref.read(goalRepositoryProvider).keepLocal(cmd.operationId, WeeklyGoal(local)),
                          Kinds.metric => ref.read(bodyRepositoryProvider).keepLocal(cmd.operationId, BodyMetric(local)),
                          Kinds.exerciseIncrement => ref.read(progressionRepositoryProvider).keepLocal(cmd.operationId, ExerciseIncrement(local)),
                          _ => ref.read(foodRepositoryProvider).keepLocal(cmd.operationId, FoodEntry(local)),
                        },
                    (l) => l.syncKeptLocal)),
                const SizedBox(height: 8),
              ],
              if (refusedPlan) ...[
                PrimaryButton(l.syncKeepAsUnfinished, key: Key('issue-unfinished-${rec.id}'), onPressed: () async {
                  final kept = await ref.read(planRepositoryProvider).keepRefusedAsDraft(cmd!.operationId, today: ref.read(todayKeyProvider));
                  ref.invalidate(builderDraftProvider);
                  if (context.mounted) toast(context, kept ? l.syncKeptAsUnfinished : l.syncUnfinishedExists);
                }),
                const SizedBox(height: 8),
              ],
              if (refusedStart) ...[
                PrimaryButton(l.syncKeepManual, key: Key('issue-manual-${rec.id}'), onPressed: () => act(
                    (cmd) => ref.read(workoutRepositoryProvider).keepAsManual(cmd.operationId, Workout(local)),
                    (l) => l.syncKeptManual)),
                const SizedBox(height: 8),
              ],
              if (server != null && !refusedStart)
                SecondaryButton(l.syncUseServer, key: Key('issue-server-${rec.id}'), onPressed: () => act(
                    (cmd) => sync.resolveUseServer(rec.ownerId, cmd.operationId), (l) => l.syncUsingServer))
              else if (!refusedStart || rec.revision == 0)
                SecondaryButton(rec.revision == 0 ? l.syncRemoveFromPhone : l.syncDropChange, key: Key('issue-discard-${rec.id}'), onPressed: () async {
                  if (!await confirm(context,
                      title: rec.revision == 0 ? l.syncRemoveConfirmTitle : l.syncDropConfirmTitle,
                      body: rec.revision == 0
                          ? (rec.kind == Kinds.workout ? l.syncRemoveConfirmBodyWorkout : l.syncRemoveConfirmBody)
                          : l.syncDropConfirmBody,
                      action: rec.revision == 0 ? l.actionRemove : l.syncDropChange)) {
                    return;
                  }
                  await act((cmd) => sync.discard(rec.ownerId, cmd.operationId), (l) => l.syncDiscardDone);
                }),
            ]),
          ),
        );
      },
    );
  }
}
