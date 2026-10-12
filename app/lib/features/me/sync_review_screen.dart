import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import '../workout/workout_screen.dart';

/// A plain description of one stored version, for comparing "on this phone" with "in your account".
String describeRecord(String kind, Json j, LoadUnit unit) => switch (kind) {
      Kinds.set => (j['isDeleted'] as bool? ?? false) ? 'Removed' : setText(WorkoutSet(j), unit),
      Kinds.food => (j['isDeleted'] as bool? ?? false)
          ? 'Removed'
          : '${j['name']} · ${j['amountDescription']} · ${j['meal']} · ${shortDate(j['dayKey'] as String)}'
              '${FoodEntry(j).calories == null ? '' : ' · ${formatNumber(FoodEntry(j).calories!)} kcal'}',
      Kinds.workout => '${j['title']} · ${shortDate(j['dayKey'] as String)} · ${j['finishedAtUtc'] == null ? 'in progress' : 'finished (${j['outcome']})'}',
      Kinds.context => j['primaryPlanId'] == null ? 'No primary plan' : 'A primary plan is set',
      Kinds.plan => '${j['title']} · ${j['lifecycle']}',
      Kinds.profile => '${j['displayName']} · ${j['appearance']} · ${j['loadUnit']}',
      Kinds.run => 'Run · ${shortDate(j['dayKey'] as String)}',
      _ => kind,
    };

const _titles = {
  Kinds.set: 'Recorded set', Kinds.food: 'Food entry', Kinds.workout: 'Workout', Kinds.context: 'Primary plan change', Kinds.plan: 'Plan schedule change',
  Kinds.profile: 'Profile', Kinds.run: 'Run', Kinds.metric: 'Body measurement', Kinds.proposal: 'Suggested change',
};

String _reason(String? code) => switch (code) {
      'REVISION_CONFLICT' => 'It was also changed somewhere else, so the two versions differ.',
      'SET_DELETED' || 'ENTRY_DELETED' => 'It was removed somewhere else after you changed it here.',
      'OCCASION_NOT_ELIGIBLE' => 'That planned workout was already started, recorded or skipped somewhere else.',
      'ALREADY_FINISHED' => 'This workout was already finished somewhere else.',
      'SET_DEPENDENCY_MISMATCH' => 'The sets in your account differ from the sets on this phone.',
      'PRIMARY_EXISTS' || 'PLAN_NOT_DRAFT' || 'PLAN_NOT_ACTIVE' || 'PLAN_NOT_PAUSED' || 'STALE_REVIEW' => 'Your plans changed somewhere else before this reached your account.',
      'NOT_FOUND' => 'It no longer exists in your account.',
      _ => 'Your account did not accept it (${code ?? 'unknown reason'}).',
    };

/// Changes that could not converge on their own. Both versions are kept until you choose; choosing never
/// adds a record, finishes a workout or silently discards the other version.
class SyncReviewScreen extends ConsumerWidget {
  const SyncReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(issuesProvider).value ?? const <Rec>[];
    return AppPage(title: 'Review saved changes', children: [
      Text('Everything below is saved on this phone. Each item differs from your account or was not accepted, so it needs your decision.', style: context.caption),
      if (issues.isEmpty) const EmptyState('Nothing to review', 'All your changes are either synced or waiting to sync normally.'),
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

    Future<void> act(Future<void> Function(Cmd cmd) action, String done) async {
      final cmd = await sync.issueFor(rec.ownerId, rec.kind, rec.id);
      if (cmd == null) return;
      await action(cmd);
      if (context.mounted) toast(context, done);
    }

    return FutureBuilder<Cmd?>(
      future: sync.issueFor(rec.ownerId, rec.kind, rec.id),
      builder: (context, snap) {
        final cmd = snap.data;
        final refusedStart = cmd?.kind == 'workout.start';
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionLabel(_titles[rec.kind] ?? rec.kind),
              const SizedBox(height: 6),
              Text(_reason(cmd?.lastError), style: context.body),
              const SizedBox(height: 12),
              Text('On this phone', style: context.caption),
              Text(describeRecord(rec.kind, local, unit), style: context.sansStyle(15, weight: FontWeight.w600)),
              if (server != null) ...[
                const SizedBox(height: 8),
                Text('In your account', style: context.caption),
                Text(describeRecord(rec.kind, server, unit), style: context.sansStyle(15, weight: FontWeight.w600)),
              ],
              const SizedBox(height: 14),
              if (rec.syncState == 'conflict' && server != null && (rec.kind == Kinds.set || rec.kind == Kinds.food)) ...[
                PrimaryButton('Keep the version on this phone', key: Key('issue-keep-${rec.id}'), onPressed: () => act(
                    (cmd) => rec.kind == Kinds.set
                        ? ref.read(workoutRepositoryProvider).keepLocalSet(cmd.operationId, WorkoutSet(local))
                        : ref.read(foodRepositoryProvider).keepLocal(cmd.operationId, FoodEntry(local)),
                    'Kept your version. The account\'s version is retained as the alternative.')),
                const SizedBox(height: 8),
              ],
              if (refusedStart) ...[
                PrimaryButton('Keep it as a manual workout', key: Key('issue-manual-${rec.id}'), onPressed: () => act(
                    (cmd) => ref.read(workoutRepositoryProvider).keepAsManual(cmd.operationId, Workout(local)),
                    'Kept as manual training. Every recorded set is preserved.')),
                const SizedBox(height: 8),
              ],
              if (server != null && !refusedStart)
                SecondaryButton('Use the account\'s version', key: Key('issue-server-${rec.id}'), onPressed: () => act(
                    (cmd) => sync.resolveUseServer(rec.ownerId, cmd.operationId), 'Using the account\'s version. Your version is retained as the alternative.'))
              else if (!refusedStart || rec.revision == 0)
                SecondaryButton(rec.revision == 0 ? 'Remove it from this phone' : 'Drop my change', key: Key('issue-discard-${rec.id}'), onPressed: () async {
                  if (!await confirm(context,
                      title: rec.revision == 0 ? 'Remove it from this phone?' : 'Drop this change?',
                      body: rec.revision == 0
                          ? 'Your account never accepted this, so removing it here removes it completely${rec.kind == Kinds.workout ? ', including its recorded sets' : ''}.'
                          : 'Your account\'s version will be shown again.',
                      action: rec.revision == 0 ? 'Remove' : 'Drop my change')) {
                    return;
                  }
                  await act((cmd) => sync.discard(rec.ownerId, cmd.operationId), 'Done.');
                }),
            ]),
          ),
        );
      },
    );
  }
}
