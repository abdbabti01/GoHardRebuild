import '../../core/language.dart';
import '../../data/models.dart';
import '../nutrition/nutrient_coverage.dart';
import '../plans/plan_projection.dart';

export '../plans/plan_projection.dart' show occasionOutcome, openWorkoutFor, planOccasions;

/// How one planned occasion reads today. Always shown as text, never by colour alone.
enum OccasionStatus {
  inProgress, finished, partial, skipped, missed, due, upcoming, paused;

  /// The state in words, in the current language ("In progress", "Planned").
  String get label => currentL10n.todayOccasionStatus(name);
}

OccasionStatus statusOf(Occasion o, Plan plan, String today, Iterable<Workout> workouts) {
  if (openWorkoutFor(o, workouts) != null) return OccasionStatus.inProgress;
  final outcome = occasionOutcome(o, workouts);
  if (outcome != null) return outcome == 'full' ? OccasionStatus.finished : OccasionStatus.partial;
  if (o.isSkipped) return OccasionStatus.skipped;
  // While paused, expectations stop at the pause date: nothing after it becomes "missed".
  if (plan.isPaused && (plan.pausedOn == null || o.scheduledDate.compareTo(plan.pausedOn!) >= 0)) return OccasionStatus.paused;
  final c = o.scheduledDate.compareTo(today);
  // A rotation waits for you: a workout not done yet is never missed, it is still the one due.
  if (plan.isRotating) return c <= 0 ? OccasionStatus.due : OccasionStatus.upcoming;
  return c < 0 ? OccasionStatus.missed : c == 0 ? OccasionStatus.due : OccasionStatus.upcoming;
}

/// Plan week "n of N", derived from the accepted start in seven-day intervals. Not a completion measure.
/// An ongoing plan just counts its weeks.
int planWeek(Plan plan, String today) {
  final days = DateTime.parse('${today}T00:00:00Z').difference(DateTime.parse('${plan.startDate}T00:00:00Z')).inDays;
  if (days < 0) return 0;
  return plan.isOngoing ? days ~/ 7 + 1 : (days ~/ 7 + 1).clamp(1, plan.blockWeeks);
}

/// What the primary plan says about today (docs/TRAINING_PLANS.md › Today). It is only the plan's side: open and
/// recorded workouts are listed beside it by [DailySnapshot] and never change it.
sealed class TrainingAction {
  const TrainingAction();
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

/// The plan has training on today's date.
class PlannedToday extends TrainingAction {
  const PlannedToday(this.plan, this.occasions, {this.next, this.missed = const [], this.blockDone = false});
  final Plan plan;

  /// Every occurrence of the plan on today's date, whatever its state (due, in progress, skipped, done), each with
  /// its own identity; for a rotation also its next workout still waiting from an earlier day.
  final List<Occasion> occasions;

  /// The first workout still to do after today's: a fixed plan's on its real date, a rotation's next in sequence.
  final Occasion? next;

  /// Fixed plans: earlier workouts nobody did or skipped. They stay on their dates.
  final List<Occasion> missed;

  /// Nothing is left to do in this block after today.
  final bool blockDone;
}

/// The active plan has nothing on today's date: a fixed plan's day without a workout, a rotation's day off its
/// training days, or a day the person chose to rest ([chosen]). Never inferred from nothing being recorded.
class PlannedRest extends TrainingAction {
  const PlannedRest(this.plan, this.next, this.missed, {this.chosen = false});
  final Plan plan;
  final Occasion? next;
  final List<Occasion> missed;
  final bool chosen;
}

class ReviewDraft extends TrainingAction {
  const ReviewDraft(this.draft);
  final Plan draft;
}

class CreatePlan extends TrainingAction {
  const CreatePlan();
}

/// Resolves what the primary plan says about today. Pure: the same inputs always give the same answer.
///
/// Open and recorded workouts do not change the answer: a manual workout never hides, completes or replaces a
/// planned one, and only a workout linked to an occurrence changes that occurrence's state.
TrainingAction resolveTraining({required String today, required TrainingCtx? ctx, required List<Plan> plans, required List<Workout> workouts}) {
  final primary = plans.where((p) => p.id == ctx?.primaryPlanId).firstOrNull;
  if (primary != null) {
    if (primary.isPaused) return PlanPausedAction(primary);
    // The same projection Train shows: a rotation's next workout is part of it.
    final occasions = planOccasions(primary, today, workouts);
    bool pending(Occasion o) => !o.isSkipped && occasionOutcome(o, workouts) == null;
    if (occasions.isEmpty) return BlockReviewDue(primary);
    if (today.compareTo(primary.startDate) < 0) return StartsLater(primary, occasions.first);

    // A rotation's next workout waits for you: still today's when it came up on an earlier day.
    final waiting = primary.isRotating ? occasions.where(pending).firstOrNull : null;
    final todays = [for (final o in occasions) if (o.scheduledDate == today || (o == waiting && o.scheduledDate.compareTo(today) < 0)) o];
    final later = [for (final o in occasions) if (pending(o) && o.scheduledDate.compareTo(today) > 0) o]..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    // Missed training stays on its date until the user resolves it. It never takes over Today or moves by itself.
    final missed = primary.isRotating ? const <Occasion>[] : [for (final o in occasions) if (pending(o) && o.scheduledDate.compareTo(today) < 0) o];
    final end = primary.endDate;
    if (todays.isNotEmpty) return PlannedToday(primary, todays, next: later.firstOrNull, missed: missed, blockDone: !occasions.any((o) => pending(o) && !todays.contains(o)));
    // Reaching the end, or resolving everything, is a review-due condition. It is never an automatic achievement.
    if (!occasions.any(pending) || (end != null && today.compareTo(end) > 0)) return BlockReviewDue(primary);
    return PlannedRest(primary, later.firstOrNull, missed, chosen: primary.restDays.contains(today));
  }

  // Only without a primary plan may a saved draft or setup drive Today.
  final drafts = plans.where((p) => p.isDraft && !p.isArchived).toList();
  if (drafts.isNotEmpty) return ReviewDraft(drafts.last);
  return const CreatePlan();
}

/// Everything relevant today, built only from the signed-in owner's real records.
class DailySnapshot {
  const DailySnapshot({required this.ownerId, required this.dayKey, required this.training, this.inProgress = const [], required this.parked,
      required this.finishedToday, required this.food, required this.coverage, required this.runs});
  final String ownerId, dayKey;
  final TrainingAction training;

  /// The open workout in front, newest first, unless it belongs to one of today's planned occurrences (then the
  /// plan's own entry shows it): a manual workout, or a planned one from another day.
  final List<Workout> inProgress;

  /// Open workouts saved for later, except those today's planned entry already shows.
  final List<Workout> parked;

  /// Workouts finished on this calendar day, planned or manual, with their honest outcomes.
  final List<Workout> finishedToday;
  final List<FoodEntry> food;
  final Map<Nutrient, NutrientTotal> coverage;
  final List<Run> runs;

  /// Finished workouts not already shown by the training module. Only a workout that IS the result of one of
  /// today's planned occurrences is left out, by its identity: the account's result workout, or the local workout
  /// credited to that occasion. A manual workout, or another attempt that earned nothing, is still listed.
  List<Workout> get recordedToday {
    final shown = todaysOccasions;
    return [
      for (final w in finishedToday)
        if (!shown.any((o) => w.id == o.resultWorkoutId || (w.occasionId == o.id && w.qualifiedOccasion))) w,
    ];
  }

  List<Occasion> get todaysOccasions => switch (training) { PlannedToday(:final occasions) => occasions, _ => const [] };
}

/// Splits open workouts for Today: the one in front and those saved for later, leaving out any that today's planned
/// entry shows as its own state.
({List<Workout> inProgress, List<Workout> parked}) openWorkouts(List<Workout> workouts, Set<String> parkedIds, TrainingAction training) {
  final shown = {for (final o in switch (training) { PlannedToday(:final occasions) => occasions, _ => const <Occasion>[] }) o.id};
  final open = [for (final w in workouts) if (w.isOpen && !shown.contains(w.occasionId)) w]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
  return (inProgress: [for (final w in open) if (!parkedIds.contains(w.id)) w], parked: [for (final w in open) if (parkedIds.contains(w.id)) w]);
}
