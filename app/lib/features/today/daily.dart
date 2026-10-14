import '../../data/models.dart';
import '../nutrition/nutrient_coverage.dart';

/// How one planned occasion reads today. Always shown as text, never by colour alone.
enum OccasionStatus {
  inProgress('In progress'),
  finished('Completed'),
  partial('Partial'),
  skipped('Skipped'),
  missed('Missed'),
  due('Due'),
  upcoming('Planned'),
  paused('Paused');

  const OccasionStatus(this.label);
  final String label;
}

/// The outcome credited to an occasion: the account's value, or a locally finished workout not yet acknowledged.
String? occasionOutcome(Occasion o, Iterable<Workout> workouts) =>
    o.resultOutcome ?? workouts.where((w) => !w.isDeleted && w.occasionId == o.id && w.qualifiedOccasion).firstOrNull?.outcome;

Workout? openWorkoutFor(Occasion o, Iterable<Workout> workouts) => workouts.where((w) => w.isOpen && w.occasionId == o.id).firstOrNull;

OccasionStatus statusOf(Occasion o, Plan plan, String today, Iterable<Workout> workouts) {
  if (openWorkoutFor(o, workouts) != null) return OccasionStatus.inProgress;
  final outcome = occasionOutcome(o, workouts);
  if (outcome != null) return outcome == 'full' ? OccasionStatus.finished : OccasionStatus.partial;
  if (o.isSkipped) return OccasionStatus.skipped;
  // While paused, expectations stop at the pause date: nothing after it becomes "missed".
  if (plan.isPaused && (plan.pausedOn == null || o.scheduledDate.compareTo(plan.pausedOn!) >= 0)) return OccasionStatus.paused;
  final c = o.scheduledDate.compareTo(today);
  return c < 0 ? OccasionStatus.missed : c == 0 ? OccasionStatus.due : OccasionStatus.upcoming;
}

/// Plan week "n of N", derived from the accepted start in seven-day intervals. Not a completion measure.
int planWeek(Plan plan, String today) {
  final days = DateTime.parse('${today}T00:00:00Z').difference(DateTime.parse('${plan.startDate}T00:00:00Z')).inDays;
  return days < 0 ? 0 : (days ~/ 7 + 1).clamp(1, plan.blockWeeks);
}

/// The one dominant training message for Today, in the product's priority order.
sealed class TrainingAction {
  const TrainingAction();
}

class ResumeWorkout extends TrainingAction {
  const ResumeWorkout(this.workout);
  final Workout workout;
}

class PlanPausedAction extends TrainingAction {
  const PlanPausedAction(this.plan);
  final Plan plan;
}

class StartsLater extends TrainingAction {
  const StartsLater(this.plan, this.first);
  final Plan plan;
  final Occasion first;
}

class BlockReviewDue extends TrainingAction {
  const BlockReviewDue(this.plan);
  final Plan plan;
}

class WorkoutDue extends TrainingAction {
  const WorkoutDue(this.plan, this.occasion);
  final Plan plan;
  final Occasion occasion;
}

class DoneToday extends TrainingAction {
  const DoneToday(this.plan, this.occasion, this.outcome, this.next);
  final Plan plan;
  final Occasion occasion;
  final String outcome;
  final Occasion? next;
}

class RecoveryDay extends TrainingAction {
  const RecoveryDay(this.plan, this.next, this.missed);
  final Plan plan;
  final Occasion? next;
  final List<Occasion> missed;
}

class ReviewDraft extends TrainingAction {
  const ReviewDraft(this.draft);
  final Plan draft;
}

class CreatePlan extends TrainingAction {
  const CreatePlan();
}

/// Resolves what Today should ask of the user. Pure: the same inputs always give the same answer.
///
/// `parkedIds` are open workouts the user saved for later; they stay recoverable but do not take over Today.
TrainingAction resolveTraining({required String today, required TrainingCtx? ctx, required List<Plan> plans, required List<Workout> workouts, Set<String> parkedIds = const {}}) {
  // 1. An open foreground workout always comes first, whatever happened to its plan since.
  final open = workouts.where((w) => w.isOpen).toList()..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
  final foreground = open.where((w) => !parkedIds.contains(w.id)).firstOrNull;
  if (foreground != null) return ResumeWorkout(foreground);

  final primary = plans.where((p) => p.id == ctx?.primaryPlanId).firstOrNull;
  if (primary != null) {
    if (primary.isPaused) return PlanPausedAction(primary);
    final occasions = primary.occasions;
    final pending = occasions.where((o) => !o.isSkipped && occasionOutcome(o, workouts) == null).toList();
    final end = primary.endDate;
    // Reaching the end, or resolving everything, is a review-due condition. It is never an automatic achievement.
    if (pending.isEmpty || (end != null && today.compareTo(end) > 0)) return BlockReviewDue(primary);
    if (today.compareTo(primary.startDate) < 0) return StartsLater(primary, occasions.first);

    final dueToday = pending.where((o) => o.scheduledDate == today).firstOrNull;
    if (dueToday != null) return WorkoutDue(primary, dueToday);
    final upcoming = pending.where((o) => o.scheduledDate.compareTo(today) > 0).toList();
    final doneToday = occasions.where((o) => o.scheduledDate == today && occasionOutcome(o, workouts) != null).firstOrNull;
    if (doneToday != null) return DoneToday(primary, doneToday, occasionOutcome(doneToday, workouts)!, upcoming.firstOrNull);
    // Missed training stays on its date until the user resolves it. It never takes over Today or moves by itself.
    return RecoveryDay(primary, upcoming.firstOrNull, pending.where((o) => o.scheduledDate.compareTo(today) < 0).toList());
  }

  // Only without a primary plan may a saved draft or setup drive Today.
  final drafts = plans.where((p) => p.isDraft && !p.isArchived).toList();
  if (drafts.isNotEmpty) return ReviewDraft(drafts.last);
  return const CreatePlan();
}

/// Everything relevant today, built only from the signed-in owner's real records.
class DailySnapshot {
  const DailySnapshot({required this.ownerId, required this.dayKey, required this.training, required this.parked,
      required this.finishedToday, required this.food, required this.coverage, required this.runs});
  final String ownerId, dayKey;
  final TrainingAction training;

  /// Open workouts saved for later.
  final List<Workout> parked;

  /// Workouts finished on this calendar day, planned or manual, with their honest outcomes.
  final List<Workout> finishedToday;
  final List<FoodEntry> food;
  final Map<Nutrient, NutrientTotal> coverage;
  final List<Run> runs;

  /// Finished workouts not already shown by the training module. Only the workout that IS the "done for today"
  /// result is left out, by its identity: the account's result workout, or the local workout credited to that
  /// occasion. A manual workout, or another attempt at the same occasion that earned nothing, is still listed.
  List<Workout> get recordedToday {
    final a = training;
    if (a is! DoneToday) return finishedToday;
    final o = a.occasion;
    return [for (final w in finishedToday) if (w.id != o.resultWorkoutId && !(w.occasionId == o.id && w.qualifiedOccasion)) w];
  }
}
