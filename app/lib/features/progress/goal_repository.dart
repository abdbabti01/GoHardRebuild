import '../../core/units.dart' show parsePositiveInt;
import '../../data/db.dart' show Cmd;
import '../../data/models.dart';
import '../../data/sync.dart';
import 'weekly.dart';

/// Why a weekly target was refused: not a whole number from 1 to 21.
enum GoalInputError { outOfRange }

/// Weekly activity targets through the outbox (docs/PROGRESS.md › Weekly goals). A save writes the record of the
/// week it was made in; queued, it keeps that week however late it reaches the account.
class GoalRepository {
  GoalRepository(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;

  static const capability = 'goals.weekly';

  /// A goal command waits until the account's server declares weekly goals (unknown waits too); nothing else is held.
  static bool serverTakes(Cmd cmd, Set<String>? capabilities) => !cmd.kind.startsWith('weeklygoal.') || (capabilities?.contains(capability) ?? false);

  /// A field's text as a target: blank is no target. Whole numbers 1 to 21 only; anything else is refused with the
  /// same rule the account applies. Digits may be typed in any of the app's languages ("٣"); the form words the error.
  static (int?, GoalInputError?) parse(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return (null, null);
    final v = parsePositiveInt(t);
    if (v == null || v < goalRange.$1 || v > goalRange.$2) return (null, GoalInputError.outOfRange);
    return (v, null);
  }

  /// Sets the targets effective from [weekStart] (this week's Monday). Null clears one; both null is an explicit
  /// "no goals from this week", never a deletion that would bring an older target back.
  Future<Receipt> set(String weekStart, {required int? workouts, required int? runWalk}) {
    for (final v in [workouts, runWalk]) {
      if (v != null && (v < goalRange.$1 || v > goalRange.$2)) throw ArgumentError.value(v, 'target');
    }
    final fields = {'workoutsTarget': workouts, 'runWalkTarget': runWalk};
    return _sync.submit(_owner, kind: 'weeklygoal.put', method: 'PUT', path: '/weekly-goals/$weekStart', targetKind: Kinds.weeklyGoal, targetId: weekStart,
        writes: [LocalWrite(Kinds.weeklyGoal, weekStart, {'weekStart': weekStart, ...fields})],
        payload: {'expectedRevision': {r'$rev': [Kinds.weeklyGoal, weekStart]}, ...fields});
  }

  /// "Keep the version on this phone" after another phone chose this week's goal: one new command against the
  /// account's revision; the account's choice is kept as the alternative.
  Future<Receipt?> keepLocal(String operationId, WeeklyGoal local) => _sync.resolveKeepLocal(_owner, operationId,
      kind: 'weeklygoal.put', method: 'PUT', path: '/weekly-goals/${local.weekStart}',
      payload: {'expectedRevision': {r'$rev': [Kinds.weeklyGoal, local.weekStart]}, 'workoutsTarget': local.workoutsTarget, 'runWalkTarget': local.runWalkTarget});
}
