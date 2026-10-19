# Train › Progress: weekly goals, exercise trends, weekly recap

Added 19 Oct 2026 from `GoHard_Progress_Claude_Handoff` (branch `feature/training-progress`, built on
`feature/workout-workspace`). Three connected views, all computed on the phone from the account's own records:

1. **Weekly progress** (Train › Progress): this week's date range, Set weekly goals / Edit goals, Workouts and
   Run / Walk with real counts, strength-trend previews, plan adherence, last week's recap, then the quieter history
   (consistency, recent workouts, workout history, Run / Walk personal bests).
2. **Exercise trends** (a preview, or See all → a searchable list of recorded exercises): one exercise's comparable
   results with 4 weeks / 12 weeks / All, the chart, the change, and the sessions behind every point.
3. **Weekly recap** (last week's card): one completed Monday–Sunday week, with previous/next among completed weeks.

Code: `app/lib/features/progress/` (`weekly.dart`, `trends.dart` – pure projections; `goal_repository.dart`;
`progress_view.dart`, `trend_screens.dart`, `recap_screen.dart`). API: `WeeklyGoalService`, `PUT /weekly-goals/{monday}`,
snapshot `weeklyGoals`, migration `AddWeeklyGoals`, capability `goals.weekly`.

## Weekly goals

- Two optional whole numbers: workouts per week and runs or walks per week, each **1–21** (an input bound, not a
  recommendation). Blank = no target. Zero, negatives, decimals and out-of-range values are refused by the app
  (`GoalRepository.parse`) and the API (`VALIDATION_FAILED`; a decimal is not a whole number, 400) alike. Nothing is
  ever suggested or preselected, and a fresh install uploads nothing.
- **Goal history.** A save writes the record of **this week's Monday** (`weekStart`). A week's goals are the latest
  record with `weekStart` on or before its Monday. So a change in week B never rewrites week A, a week before any record
  has no goals ("No goals were set for this week."), and clearing is a record with both targets null – never a deletion
  that would bring an older target back. Past weeks are not editable in this version.
- **Sync.** One row per owner and Monday (primary key `(UserId, WeekStart)`), revision-checked like every other
  record: `expectedRevision` 0 creates the week, otherwise it must match. A second phone's choice for the same week is
  a conflict kept for review (Me › Review saved changes: keep this phone's or use the account's); a retry replays the
  recorded answer. A field left out by an older client keeps the stored value; an explicit null clears it. The queued
  command carries its week in its path, so a late sync can never move it into another week. Erased with the account.
- **Older servers.** The app sends `weeklygoal.*` only when the server declares `goals.weekly` (unknown waits, like
  Run / Walk routes). A server that answered without it shows "Weekly goals are not available on your account's server
  yet" instead of Set/Edit; counts still show. A saved but unsent goal says "Goals saved on this phone · sync pending".
- Goals are independent of plans: saving one never schedules, moves, skips or completes a planned workout. Plan
  adherence keeps its own rules.

## Counting (one projection: overview, bars, recap, coach)

- Weeks run Monday–Sunday by calendar arithmetic on date-only `dayKey`s (`mondayOf`), never 7 × 24 h, so daylight
  saving and the year end change nothing. An activity belongs to its stored `dayKey`. The current week follows the
  app's day (`todayKeyProvider`) and rolls over with it.
- **Workouts:** distinct, finished, not deleted, with outcome full, partial or manual_recorded (`countsAsTraining`).
  Open, paused, saved-for-later, no-data and deleted workouts do not count. A partial workout counts as training and
  keeps its "Finished partially" label.
- **Run / Walk:** distinct finished, not deleted activities with positive `activeDurationSeconds`; an interval session
  is one activity. No minimum distance; no route required. Distance and active time are summed where recorded; an
  activity without a distance is not counted as zero and the recap says how many are missing. "Walking distance"
  only when every activity is a walk, "Running" likewise, otherwise "Run / Walk".
- Without a target a row shows "n recorded" and no bar; with one, "n of target" and a bar capped at full (the count is
  never capped). Steps, food and water are not part of this.

## Exercise trends

- Grouped by exact identity (catalog key or private `custom:<id>`), across every appearance in a workout. Free text
  has no trend. Only performed workouts and trusted sets (not deleted, not awaiting review, `isPerformed`).
- **Metric.** Loaded rep sets → **Top set load · N reps**: per workout, the heaviest load among sets of exactly N reps
  (ties: performed first, then ID). N starts at the reps of the most recent loaded set and can be changed among the
  recorded rep counts. No loaded set: the most reps in a set with no added load; a timed exercise: the longest recorded
  time. Sets that the metric cannot use are counted in a note, never plotted as 0 kg.
- One point per workout at its real start time; two sessions on one day stay two points (rows show the time). A
  workout without a set at N reps gives no point; nothing is interpolated or forecast.
- Ranges: the last 28 or 84 calendar days including today, or all. The hero, chart, change and rows use the same
  filtered points. The change (latest − first) appears only with two or more points and is shown neutrally ("No
  change", "−2.5 kg"). Units are converted once at display (`formatLoad`).
- A point or a row opens that workout's own record (`WorkoutDetailScreen`); "All N sessions and sets" lists every set.
- The chart is a small `CustomPainter` (no chart dependency): announced as one summary, with the session list as the
  full non-visual alternative.
- Last time in the recorder keeps its own occurrence rule (`exerciseHistory`).

## Weekly recap

Last week by default, earlier completed weeks back to the first recorded one; the current week is never a recap.
Counts (workouts; runs and walks named), distance and active time, the goals that applied to that week (reached is a
check and the word "reached"), at most one strength highlight – the biggest increase at one rep count with two or more
sessions in the week, by the chart's rule; omitted when flat or missing – and the week's sessions, each opening its
own record. A zero week says "No activity was recorded this week." Recalculated every time from the records.

## Coach

Train's coach on Progress states one fact from the projection ("1 of 3 workouts recorded this week.") or how to set a
goal; the recap shows the guide with the recorded counts (only while Show coach on Train and Eat is on). Neither asks
the AI; Ask me opens the existing conversation with the context "Your progress".

## Deviations from the board

- Subpages are ordinary pushed pages (back arrow, no section control or floating bar), as every other Train page.
- The old "Exercise history" list (first vs latest best set) is replaced by Strength trends and See all, which cover
  every recorded exercise.
- The recap lists the week's sessions directly instead of behind "View week's sessions".
