import '../../core/language.dart';
import '../../data/models.dart';
import 'daily.dart';

/// Today's greeting, worked out on the phone from what Today already shows (docs/COACH.md › Companion › Greeting).
/// Nothing here asks the AI, needs a connection or guesses: no readiness, recovery, calories or mood, and a line
/// only when the projection says something definite.

/// The part of the day from the phone's local hour: 'morning', 'afternoon' or 'evening' (the greeting's select).
String partOfDay(int hour) => hour >= 5 && hour < 12 ? 'morning' : hour >= 12 && hour < 18 ? 'afternoon' : 'evening';

/// "Good morning, Alex!" or "Good morning!": one whole message per part of the day, the name a placeholder.
String greetingTitle(AppLocalizations l, int hour, String? name) =>
    name == null ? l.todayGreetingPlain(partOfDay(hour)) : l.todayGreetingNamed(partOfDay(hour), name);

/// The first word of the profile's display name, or null without one.
String? firstName(String? displayName) {
  final first = (displayName ?? '').trim().split(RegExp(r'\s+')).first;
  return first.isEmpty ? null : first;
}

/// One short factual line about today's training, or null when there is nothing definite to say.
///
/// [justSaved]: a workout was finished with training in it during this session (its own success path, never a
/// sync or a restart). A planned rest day is a rest day, never a skipped workout; a manual workout never stands in
/// for the plan's; a skipped day never turns into the next workout.
String? todayLine(AppLocalizations l, DailySnapshot s, Iterable<Workout> all, {bool justSaved = false}) {
  if (justSaved) return l.todayLineSaved;
  if (s.inProgress.isNotEmpty) return l.todayLineResume;
  return switch (s.training) {
    PlannedToday(:final plan, :final occasions) => () {
        final status = {for (final o in occasions) o.id: statusOf(o, plan, s.dayKey, all)};
        // The same lead as Today's workout module: in progress, else the first due, else the first of the day.
        final lead = occasions.where((o) => status[o.id] == OccasionStatus.inProgress).firstOrNull ??
            occasions.where((o) => status[o.id] == OccasionStatus.due).firstOrNull ??
            occasions.firstOrNull;
        if (lead == null) return null;
        return switch (status[lead.id]!) {
          OccasionStatus.inProgress => l.todayLineResume,
          OccasionStatus.due => l.todayLineDue(lead.title),
          OccasionStatus.finished => l.todayLineFinished,
          OccasionStatus.partial => l.todayLinePartial,
          OccasionStatus.skipped => l.todayLineSkipped,
          _ => null,
        };
      }(),
    PlannedRest() => l.todayLineRest,
    PlanPausedAction() => l.todayLinePaused,
    _ => null,
  };
}
