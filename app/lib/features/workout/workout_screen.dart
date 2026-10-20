import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../coach/coach_avatar.dart' show CoachHelpButton;
import '../coach/coach_bubble.dart';
import '../coach/coach_contract.dart';
import '../coach/coach_prefs.dart' show workoutSavedProvider;
import '../coach/guide_sheets.dart' show showExerciseInfo;
import '../plans/plan_progress.dart';
import '../shell/home_shell.dart';
import 'progress.dart';
import 'result_rules.dart';
import 'workout_detail_screen.dart';
import 'workout_flow.dart';
import 'workout_repository.dart';
import 'workout_runtime.dart';

String setText(WorkoutSet s, LoadUnit unit) {
  if (s.reps == null && s.durationSeconds != null) return '${s.durationSeconds} s';
  final load = (s.loadKg ?? 0) == 0 ? 'Bodyweight' : formatLoad(s.loadKg, unit);
  return '$load × ${s.reps ?? 0}${s.durationSeconds != null ? ' · ${s.durationSeconds} s' : ''}';
}

/// "‹ All workouts": back to the Workouts overview. It only changes what Train shows; nothing is paused, saved,
/// finished or removed.
class AllWorkoutsLink extends StatelessWidget {
  const AllWorkoutsLink({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => TextButton.icon(
        key: const Key('workout-all'), onPressed: onPressed, icon: const Icon(Icons.chevron_left, size: 22), label: const Text('All workouts', maxLines: 1, overflow: TextOverflow.ellipsis),
        style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 4, right: 10)),
      );
}

/// The recording state of Train › Workouts' workout panel, for one actual workout ID: current exercise, editable
/// entry, last time beside today, recorded sets, rest and deliberate transitions. Targets and previous performance
/// are guidance, separate from the sets actually recorded. Saved for later, it only shows the workout, with Resume;
/// finished, it shows the saved result. Built inside Train's scrolling page, so it is a column, not a page.
class WorkoutRecorder extends ConsumerStatefulWidget {
  const WorkoutRecorder({super.key, required this.workoutId, required this.onLeave});
  final String workoutId;

  /// Back to the overview: All workouts, Save for later, Remove and Done all end here.
  final VoidCallback onLeave;
  @override
  ConsumerState<WorkoutRecorder> createState() => _WorkoutRecorderState();
}

class _WorkoutRecorderState extends ConsumerState<WorkoutRecorder> with WidgetsBindingObserver {
  final _load = TextEditingController(), _reps = TextEditingController(), _duration = TextEditingController();
  Timer? _ticker, _draftDebounce;
  WorkoutRuntime? _runtime;
  String? _boundExerciseId, _error;
  LoadUnit? _entryUnit; // pinned while the entry is dirty
  bool _busy = false, _loaded = false;
  final _panelKey = GlobalKey();

  /// The fields hold something the user typed (or a draft they typed earlier), not a suggestion: Use last values
  /// asks before replacing it.
  bool _typed = false;

  // Captured once: dispose() must not touch ref, and a late save must stay with the owner this screen opened for.
  late final WorkoutRepository _repo = ref.read(workoutRepositoryProvider);
  late LoadUnit _unitNow = ref.read(loadUnitProvider);
  bool _closed = false;
  DateTime get _now => ref.read(clockProvider).utcNow();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The ticker only redraws. Elapsed and rest are always recomputed from the saved anchors.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(shellProvider).tab == 1) setState(() {});
    });
    _loadRuntime();
  }

  Future<void> _loadRuntime() async {
    final r = await _repo.runtime(widget.workoutId) ?? WorkoutRuntime.started(_now);
    if (!mounted) return;
    setState(() {
      _runtime = r;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _flushDraft();
    _load.dispose();
    _reps.dispose();
    _duration.dispose();
    super.dispose();
  }

  /// Backgrounding does not pause the workout or its rest; it only makes sure typed input is on disk.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _flushDraft();
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  Future<void> _save(WorkoutRuntime next) async {
    setState(() => _runtime = next);
    await _repo.saveRuntime(widget.workoutId, next);
  }

  /// A park, resume or finish made elsewhere (Today's Resume, another start's "save it for later") is the stored
  /// truth: it replaces this panel's copy, keeping only the entry being typed here.
  /// The selection is this panel's too: only it changes exercise, so a late echo of an older write never switches back.
  void _adopt(WorkoutRuntime stored) {
    final mine = _runtime;
    if (mine == null || !_loaded || _closed) return;
    setState(() => _runtime = WorkoutRuntime(copyJson(stored.j)
      ..['drafts'] = copyJson(mine.j)['drafts'] ?? <String, dynamic>{}
      ..['selectedExerciseId'] = mine.selectedExerciseId));
  }

  void _onTyped() {
    _typed = true;
    _entryUnit ??= _unitNow;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 400), _flushDraft);
  }

  void _flushDraft() {
    final draft = _foldDraft();
    if (draft != null) unawaited(_repo.saveDraft(widget.workoutId, _boundExerciseId!, draft));
  }

  /// Puts the entry into this panel's runtime as the bound exercise's draft. Only what the user typed is a draft; a
  /// suggestion left untouched is not, and is suggested again when the exercise is opened.
  EntryDraft? _foldDraft() {
    _draftDebounce?.cancel();
    final r = _runtime, id = _boundExerciseId;
    if (r == null || id == null || _closed) return null;
    final LoadUnit unit = _entryUnit ?? _unitNow;
    final draft = _typed ? EntryDraft.of(load: _load.text, reps: _reps.text, duration: _duration.text, unit: unit.name) : EntryDraft.of(unit: unit.name);
    _runtime = r.withDraft(id, draft);
    return draft;
  }

  /// The one way to change exercise (Next, a movement row, an added movement). The entry's draft goes in the same
  /// write as the selection, so nothing can land on top of it. Nothing is recorded; time and rest are untouched.
  Future<void> _select(String exerciseId) async {
    _foldDraft();
    // Brought into view only when its top is off screen, below the status bar; no animation with reduced motion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _panelKey.currentContext?.findRenderObject();
      if (!mounted || box is! RenderBox) return;
      final top = MediaQuery.paddingOf(context).top + 12;
      box.showOnScreen(rect: Rect.fromLTWH(0, -top, box.size.width, top + 1), duration: context.motion(Motion.quick), curve: Motion.curve);
    });
    try {
      await _save(_runtime!.selecting(exerciseId));
    } on LocalSaveFailure {
      if (mounted) toast(context, 'The change of movement could not be saved on this phone. Your sets and entry are unchanged; try again.');
    }
  }

  /// Binds the entry fields to an exercise: its saved draft first, otherwise a suggestion from actual history.
  void _bind(WorkoutExercise exercise, List<WorkoutSet> mine, PreviousPerformance? previous, LoadUnit unit) {
    if (_boundExerciseId == exercise.id) return;
    _boundExerciseId = exercise.id;
    final draft = _runtime!.draftFor(exercise.id);
    _typed = !draft.isEmpty;
    if (!draft.isEmpty) {
      _entryUnit = LoadUnit.parse(draft.unit);
      _load.text = draft.rawLoad;
      _reps.text = draft.rawReps;
      _duration.text = draft.rawDuration;
      return;
    }
    _entryUnit = null;
    // Suggestion order: this workout's last set, then the matching earlier set. Plan targets are hints only.
    final source = mine.isNotEmpty ? mine.last : previous == null ? null : previous.sets[mine.length.clamp(0, previous.sets.length - 1)];
    _load.text = source?.loadKg == null || source!.loadKg == 0 ? '' : formatLoadValue(source.loadKg!, unit);
    _reps.text = source?.reps?.toString() ?? '';
    _duration.text = source?.durationSeconds?.toString() ?? '';
  }

  /// Copies the matching set from last time into the entry for the next set. It never records, starts rest or touches
  /// a recorded set; typed values that differ are replaced only after asking. The load is written in today's unit.
  Future<void> _useLast(WorkoutSet last, LoadUnit unit) async {
    final load = last.loadKg == null || last.loadKg == 0 ? '' : formatLoadValue(last.loadKg!, unit);
    final reps = last.reps?.toString() ?? '', duration = last.durationSeconds?.toString() ?? '';
    final shown = _load.text == load && _reps.text == reps && _duration.text == duration && (_entryUnit ?? unit) == unit;
    if (shown) return;
    final typed = _typed && [_load, _reps, _duration].any((c) => c.text.trim().isNotEmpty);
    if (typed &&
        !await confirm(context, title: 'Replace what you typed?', body: "The entry for this set will show last time's values instead. Nothing is recorded until you tap Record set.",
            action: 'Use last values', cancel: 'Keep mine')) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _load.text = load;
      _reps.text = reps;
      _duration.text = duration;
      _entryUnit = unit;
      _typed = false;
    });
    _flushDraft();
  }

  Future<void> _complete(Workout workout, WorkoutExercise exercise) async {
    final LoadUnit unit = _entryUnit ?? ref.read(loadUnitProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rawLoad = parseNonNegative(_load.text);
      if (_load.text.trim().isNotEmpty && rawLoad == null) throw const InvalidSet('Enter the load as a number of zero or more, or leave it blank for bodyweight.');
      final set = exercise.isTimed
          ? await _repo.recordSet(workout, exercise.id, durationSeconds: parsePositiveInt(_duration.text), loadKg: rawLoad == null ? null : loadInputToKg(rawLoad, unit))
          // Converted to canonical kilograms exactly once, from the unit the entry was typed in.
          : await _repo.recordSet(workout, exercise.id, reps: parsePositiveInt(_reps.text), loadKg: rawLoad == null ? null : loadInputToKg(rawLoad, unit));
      // Success is shown only now, after the set is durably on the phone. The entry stays as the next suggestion.
      _entryUnit = null;
      _typed = false;
      var next = _runtime!.withDraft(exercise.id, EntryDraft.of(unit: unit.name));
      if ((exercise.restSeconds ?? 0) > 0 && !next.isPaused) next = next.withRest(_now, exercise.restSeconds!, exercise.id);
      await _save(next);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 4), persist: false, // with an action it would otherwise stay and cover Finish and Save for later
          content: Text('Saved on this phone: ${setText(set, ref.read(loadUnitProvider))}'),
          action: SnackBarAction(label: 'Undo', onPressed: () => _repo.deleteSet(set)),
        ));
    } on InvalidSet catch (e) {
      setState(() => _error = e.message);
    } on LocalSaveFailure {
      // The typed values stay in the fields. No checkmark, no count change.
      setState(() => _error = 'Not saved. Your entry is still here. Tap again to retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editSet(WorkoutSet set, WorkoutExercise exercise) async {
    final unit = ref.read(loadUnitProvider);
    final load = TextEditingController(text: set.loadKg == null || set.loadKg == 0 ? '' : formatLoadValue(set.loadKg!, unit));
    final value = TextEditingController(text: (exercise.isTimed ? set.durationSeconds : set.reps)?.toString() ?? '');
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.up, actionsOverflowButtonSpacing: 4,
        title: const Text('Edit set'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: load, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Load', suffixText: unit.name, hintText: 'Bodyweight')),
          const SizedBox(height: 12),
          TextField(controller: value, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: exercise.isTimed ? 'Seconds' : 'Reps')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'delete'), child: const Text('Delete set')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Save')),
        ],
      ),
    );
    try {
      if (action == 'delete') {
        await _repo.deleteSet(set);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Set removed.')));
        }
      } else if (action == 'save') {
        final rawLoad = parseNonNegative(load.text);
        final n = parsePositiveInt(value.text);
        await _repo.updateSet(set, loadKg: rawLoad == null ? null : loadInputToKg(rawLoad, unit), reps: exercise.isTimed ? null : n, durationSeconds: exercise.isTimed ? n : null);
      }
    } on InvalidSet catch (e) {
      if (mounted) toast(context, e.message);
    } on LocalSaveFailure {
      if (mounted) toast(context, 'That change could not be saved on this phone. The set is unchanged.');
    }
  }

  Future<void> _finish(Workout workout) async {
    _flushDraft();
    final preview = await _repo.preview(workout);
    if (!mounted) return;
    final sets = await _repo.sets(workout.id);
    if (!mounted) return;
    final missing = [
      for (final e in workout.exercises)
        if (e.isPrescribed && sets.where((s) => s.exerciseId == e.id && !s.isDeleted).length < (e.targetSets ?? 1)) e.name
    ];
    final noData = preview.outcome == WorkoutResultRules.noData;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.up, actionsOverflowButtonSpacing: 4,
        title: Text(noData ? 'No training logged' : 'Finish workout?'),
        content: SingleChildScrollView(
          child: Text(noData
              ? 'No set has been recorded. You can save this as a record without training: it gives no training credit${workout.isManual ? '' : ' and leaves the planned workout available'}. Time on the clock alone is not training.'
              : '${preview.performedSets} set${preview.performedSets == 1 ? '' : 's'} across ${preview.performedExercises} movement${preview.performedExercises == 1 ? '' : 's'} recorded.'
                  '${missing.isEmpty ? '' : '\n\nNot fully recorded: ${missing.join(', ')}. You can still finish; it will be saved as partial.'}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep training')),
          FilledButton(key: const Key('finish-confirm'), onPressed: () => Navigator.pop(context, true), child: Text(noData ? 'Save without training' : 'Finish workout')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    try {
      _closed = true; // the runtime is removed with the finish; nothing may write it back
      ScaffoldMessenger.of(context).clearSnackBars(); // a lingering Undo must not cover the result's Done action
      // Read before the await: the screen may be gone when the finish returns.
      final cue = ref.read(workoutSavedProvider.notifier), today = ref.read(todayKeyProvider);
      await _repo.finish(workout);
      // Saved with training in it: Today's companion acknowledges this one finish, once (docs/COACH.md › Companion).
      if (!noData) cue.saved(workout.id, today);
      // The panel now shows the saved result: the workout is no longer open.
    } on LocalSaveFailure {
      _closed = false;
      if (mounted) toast(context, 'The workout could not be finished on this phone. Nothing changed. Try again.');
    }
  }

  Future<void> _menu(String action, Workout workout, WorkoutExercise? selected) async {
    switch (action) {
      case 'add' || 'substitute':
        final e = await push<CatalogExercise>(context, ExercisePicker(title: action == 'add' ? 'Add a movement' : 'Replace ${selected!.name}'));
        if (e == null) return;
        final added = await _repo.addExercise(workout, name: e.name, catalogKey: e.key, isTimed: e.isTimed, substitutedForKey: action == 'substitute' ? selected!.catalogKey ?? selected.name : null);
        await _select(added.id);
      case 'remove':
        try {
          await _repo.removeExercise(workout, selected!.id);
          _boundExerciseId = null;
        } on InvalidSet catch (e) {
          if (mounted) toast(context, e.message);
        }
      case 'park':
        // Typed input is folded in, then the parked state is the LAST write: leaving the screen must not overwrite it.
        _flushDraft();
        _closed = true;
        ScaffoldMessenger.of(context).clearSnackBars();
        await _repo.saveRuntime(workout.id, _runtime!.paused(_now, park: true));
        if (mounted) widget.onLeave();
      case 'discard':
        if (await confirm(context, title: 'Remove this workout?', body: 'This removes "${workout.title}" and every set recorded in it. This is the only way a workout is ever removed; it is never cleaned up automatically.', action: 'Remove workout')) {
          _closed = true;
          await _repo.delete(workout);
          if (mounted) widget.onLeave();
        }
    }
  }

  Future<void> _resumeParked(Workout workout) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (await ensureForeground(context, ref, workout.id) && mounted) await _save(_runtime!.resumed(_now));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(runtimesProvider, (_, next) {
      final stored = (next.value ?? const <Stored<Json>>[]).where((r) => r.rec.id == widget.workoutId).firstOrNull;
      if (stored != null) _adopt(WorkoutRuntime(stored.value));
    });
    final all = ref.watch(workoutsProvider);
    final row = (all.value ?? const <Stored<Workout>>[]).where((r) => r.value.id == widget.workoutId).firstOrNull;
    final setRows = ref.watch(setsProvider(widget.workoutId)).value ?? const <Stored<WorkoutSet>>[];
    final unit = _unitNow = ref.watch(loadUnitProvider);
    if (row == null && all.hasValue) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AllWorkoutsLink(onPressed: widget.onLeave),
        const EmptyState('This workout is not on this phone', 'It may have been removed. Nothing else changed.'),
      ]);
    }
    if (row == null || !_loaded) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    final workout = row.value;
    if (!workout.isOpen) return WorkoutResultView(workoutId: workout.id, onDone: widget.onLeave);

    final runtime = _runtime!;
    final parked = runtime.isParked;
    final exercises = workout.exercises;
    final selected = exercises.where((e) => e.id == runtime.selectedExerciseId).firstOrNull ?? exercises.firstOrNull;
    final live = [for (final r in setRows) if (!r.value.isDeleted) r]..sort((a, b) => a.value.performedAtUtc.compareTo(b.value.performedAtUtc));
    List<Stored<WorkoutSet>> setsOf(String id) => [for (final r in live) if (r.value.exerciseId == id) r];
    final mine = selected == null ? const <Stored<WorkoutSet>>[] : setsOf(selected.id);
    final history = selected == null
        ? const <PreviousPerformance>[]
        : exerciseHistory(
            catalogKey: selected.catalogKey, ordinal: occurrenceOf([for (final e in exercises) e.catalogKey], exercises.indexOf(selected)),
            beforeUtc: DateTime.parse(workout.startedAtUtc), excludeId: workout.id, workouts: ref.watch(workoutListProvider), sets: ref.watch(trustedSetsProvider));
    final previous = history.firstOrNull;
    if (selected != null && _boundExerciseId != selected.id) {
      // Controllers are filled after this frame; changing them during build is not allowed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _bind(selected, [for (final r in mine) r.value], previous, unit));
      });
    }
    final entryUnit = _entryUnit ?? unit;
    final rest = runtime.restRemainingSeconds(_now);
    final targetReached = selected != null && selected.targetSets != null && mine.length >= selected.targetSets!;
    final nextExercise = selected == null ? null : exercises.where((e) => e.ordinal > selected.ordinal).firstOrNull;
    final lastForNext = previous?.sets.elementAtOrNull(mine.length);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // A compact header: back to the overview, help with recording and the workout's options.
      Row(children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AllWorkoutsLink(onPressed: () {
              _flushDraft();
              widget.onLeave();
            }),
          ),
        ),
        CoachHelpButton(
          key: const Key('coach-help-workout'), semanticLabel: 'Help with recording this workout',
          onPressed: () => showCoachHelpSheet(context, title: 'Recording sets', say: CoachSay(
              'Record each set as you finish it; the rest timer then starts on its own. Last time is what you actually did before, and Use last values only fills the entry. Save for later keeps everything.',
              ask: selected == null ? null : CoachContext(label: selected.name, focus: CoachFocus.exercise, catalogKey: selected.catalogKey))),
        ),
        if (!parked)
          PopupMenuButton<String>(
            key: const Key('workout-menu'),
            tooltip: 'Workout options',
            onSelected: (a) => _menu(a, workout, selected),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'add', child: Text('Add a movement')),
              if (selected != null) const PopupMenuItem(value: 'substitute', child: Text('Replace this movement')),
              if (selected != null && mine.isEmpty) const PopupMenuItem(value: 'remove', child: Text('Remove this movement')),
              const PopupMenuItem(value: 'park', child: Text('Save for later')),
              const PopupMenuItem(value: 'discard', child: Text('Remove workout')),
            ],
          ),
      ]),
      Heading(workout.title, size: 28, serif: true),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: Semantics(
            label: 'Workout time ${durationText(runtime.elapsedSeconds(_now))}${runtime.isPaused ? ', paused' : ''}',
            child: ExcludeSemantics(child: Text(clockText(runtime.elapsedSeconds(_now)), style: context.titleStyle(30))),
          ),
        ),
        if (!parked)
          SecondaryButton(runtime.isPaused ? 'Resume' : 'Pause', key: const Key('workout-pause'), expand: false, icon: runtime.isPaused ? Icons.play_arrow : Icons.pause,
              onPressed: () => _save(runtime.isPaused ? runtime.resumed(_now) : runtime.paused(_now))),
      ]),
      if (parked) ...[
        const Padding(padding: EdgeInsets.only(top: 8), child: StatusLine(Icons.bookmark_outline, 'Saved for later. Everything recorded is kept; resume it to record more.')),
        const SizedBox(height: 10),
        PrimaryButton('Resume workout', key: const Key('panel-resume'), icon: Icons.play_arrow_rounded, busy: _busy, onPressed: () => _resumeParked(workout)),
      ] else if (runtime.isPaused)
        const Padding(padding: EdgeInsets.only(top: 8), child: StatusLine(Icons.pause_circle_outline, 'Workout paused. Time and rest are frozen until you resume.')),
      if (row.needsReview)
        const Padding(padding: EdgeInsets.only(top: 8), child: StatusLine(Icons.rule, 'Saved on this phone; this workout needs review before it can sync. See the review notice below the screen.', tone: Tone.warning)),
      // Recorded work against the plan, for the whole workout. Targets alone never move it.
      Builder(builder: (context) {
        final p = SetProgress.of(workout, [for (final r in live) r.value]);
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: p.planned == null
              ? Text('${p.recorded} ${p.recorded == 1 ? 'set' : 'sets'} recorded', style: context.numStyle(13.5, color: context.c.secondary, weight: FontWeight.w400))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p.counted} of ${p.planned} planned sets recorded', style: context.numStyle(13.5, color: context.c.secondary, weight: FontWeight.w400)),
                  const SizedBox(height: 6),
                  ProgressRail(p.fraction, label: 'Planned sets recorded', height: 6),
                ]),
        );
      }),
      const SizedBox(height: 18),
      if (selected == null)
        EmptyState('No movements yet', 'Add a movement to start recording sets.',
            action: parked ? null : SecondaryButton('Add a movement', icon: Icons.add, onPressed: () => _menu('add', workout, null)))
      else ...[
        // The exercise heading: its place in the workout, the name in the serif and the planned prescription.
        KeyedSubtree(key: _panelKey, child: PhotoPanel(
          key: const Key('workout-exercise-panel'),
          photo: 'assets/images/workout-hero.webp',
          photoAlignment: const Alignment(1, 0.6),
          content: (context) => [
            Overline('Movement ${exercises.indexOf(selected) + 1} of ${exercises.length}${selected.isPrescribed ? '' : ' · extra'}'),
            const SizedBox(height: 4),
            Semantics(header: true, child: Text(selected.name, style: context.pageTitleStyle(26))),
            const SizedBox(height: 2),
            Text(selected.target, key: const Key('workout-prescription'), style: context.numStyle(16, color: context.c.secondary, weight: FontWeight.w500)),
            if (selected.substitutedForKey != null)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('Recorded as ${selected.name}, in place of the planned movement.', style: context.caption)),
          ],
          actions: (context) => [
            QuietLink('About', key: const Key('workout-demo'), said: 'About ${selected.name}',
                onPressed: () => showExerciseInfo(appContext(context), exercise: Prescription(selected.j), workoutName: workout.title)),
          ],
        )),
        // The plan's target is the user's aim: never put in the fields or counted as a set, and apart from last time.
        if (selected.targetLoadKg != null) ...[
          const SizedBox(height: 10),
          _Tile(icon: Icons.flag_outlined, label: 'Target', value: formatLoad(selected.targetLoadKg, unit), valueKey: const Key('workout-target-load')),
        ],
        if ((selected.notes ?? '').trim().isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 10), child: StatusLine(Icons.sticky_note_2_outlined, selected.notes!.trim())),
        const SizedBox(height: 16),
        // Last time beside today, set by set.
        LastTime(
          history: history, status: historyStatus(ref, selected.catalogKey), unit: unit,
          today: [for (final r in mine) r.value], nextIndex: parked ? null : mine.length, rows: selected.targetSets,
          onAll: () => showExerciseHistory(context, name: selected.name, history: history, unit: unit),
        ),
        const SizedBox(height: 16),
        if (!parked) ...[
          if (rest != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Overline(rest == 0 ? 'Rest ended' : 'Rest${runtime.restExerciseId != selected.id ? ' · from the previous movement' : ''}'),
                  Semantics(
                    label: rest == 0 ? 'Rest ended' : 'Rest, ${durationText(rest)} left',
                    child: ExcludeSemantics(child: Text(clockText(rest), key: const Key('rest-clock'), style: context.sansStyle(context.display(70), weight: FontWeight.w300).copyWith(height: 1.05, fontFeatures: const [FontFeature.tabularFigures()]))),
                  ),
                  Wrap(spacing: 8, children: [
                    if (rest > 0) TextButton(onPressed: () => _save(runtime.restExtended(_now, 30)), child: const Text('+30 s')),
                    TextButton(key: const Key('rest-skip'), onPressed: () => _save(runtime.withoutRest()), child: Text(rest == 0 ? 'Dismiss' : 'Skip rest')),
                  ]),
                ]),
              ),
            ),
          // The next set's entry: what will be recorded, not yet a set.
          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
            Overline('Set ${mine.length + 1} · not recorded yet'),
            if (lastForNext != null)
              TextButton.icon(key: const Key('use-last-values'), onPressed: () => _useLast(lastForNext, unit), icon: const Icon(Icons.history, size: 18),
                  label: Text('Use last values', semanticsLabel: 'Use last values: ${setText(lastForNext, unit)}')),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: _BigField(key: const Key('set-load'), controller: _load, label: 'Load', suffix: entryUnit.name, hint: 'Bodyweight', decimal: true, onChanged: _onTyped),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: selected.isTimed
                  ? _BigField(key: const Key('set-duration'), controller: _duration, label: 'Time', suffix: 's', hint: selected.targetDurationSeconds?.toString() ?? '', onChanged: _onTyped)
                  : _BigField(key: const Key('set-reps'), controller: _reps, label: 'Reps', suffix: '',
                      hint: selected.targetRepsMin == null ? '' : selected.targetRepsMin == selected.targetRepsMax ? '${selected.targetRepsMin}' : '${selected.targetRepsMin}–${selected.targetRepsMax}', onChanged: _onTyped),
            ),
          ]),
          const SizedBox(height: 12),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
          if (targetReached)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.check_circle_outline,
                nextExercise == null ? 'Target set count recorded. This is the last movement: add another set, or finish the workout when you are ready.' : 'Target set count recorded. Add another set, or move on when you are ready.')),
          // Reaching the target never changes exercise. The same action stays available for extra sets.
          PrimaryButton(targetReached ? 'Record another set' : 'Record set', key: const Key('complete-set'), icon: Icons.check_rounded, busy: _busy, onPressed: () => _complete(workout, selected)),
          if (nextExercise != null) ...[
            const SizedBox(height: 8),
            SecondaryButton('Next exercise · ${nextExercise.name}', key: const Key('next-exercise'), onPressed: () => _select(nextExercise.id)),
          ],
        ],
        const SizedBox(height: 22),
        const Overline('Recorded sets'),
        const SizedBox(height: 8),
        if (mine.isEmpty)
          Text('None yet. Targets, last time and suggestions are not recorded sets.', style: context.caption)
        else
          GroupCard(children: [
            for (final (i, r) in mine.indexed)
              GroupRow(
                key: Key('set-row-$i'),
                title: '${i + 1}.  ${setText(r.value, unit)}',
                subtitle: r.needsReview ? 'Needs review' : r.isPending ? 'Recorded · saved on this phone, sync pending' : 'Recorded',
                trailing: parked ? null : Icon(Icons.edit_outlined, size: 20, color: context.c.secondary),
                onTap: parked ? null : () => _editSet(r.value, selected),
              ),
          ]),
      ],
      const SizedBox(height: 26),
      const Overline('All movements'),
      const SizedBox(height: 8),
      if (exercises.isNotEmpty)
        GroupCard(children: [
          for (final e in exercises)
            GroupRow(
              key: Key('exercise-row-${e.ordinal}'),
              title: e.name,
              subtitle: '${setsOf(e.id).length}${e.targetSets == null ? '' : ' of ${e.targetSets}'} sets recorded${e.id == selected?.id ? ' · current' : ''}',
              trailing: e.id == selected?.id ? Icon(Icons.radio_button_checked, size: 20, color: context.c.accent) : null,
              onTap: e.id == selected?.id ? null : () => _select(e.id),
            ),
        ]),
      if (!parked) ...[
        const SizedBox(height: 22),
        SecondaryButton('Finish workout', key: const Key('finish-workout'), icon: Icons.flag_outlined, onPressed: () => _finish(workout)),
        Center(child: TextButton(onPressed: () => _menu('park', workout, selected), child: const Text('Save for later'))),
      ],
    ]);
  }
}

/// Where an exercise's history stands: still loading, unreadable, or ready (possibly empty). A movement with no
/// identity has none to look for.
enum HistoryStatus { loading, unavailable, ready, noIdentity }

HistoryStatus historyStatus(WidgetRef ref, String? catalogKey) {
  if (catalogKey == null) return HistoryStatus.noIdentity;
  final w = ref.watch(workoutsProvider), s = ref.watch(allSetsProvider);
  if (w.hasError || s.hasError) return HistoryStatus.unavailable;
  return w.hasValue && s.hasValue ? HistoryStatus.ready : HistoryStatus.loading;
}

/// "Last time · date" for one exercise: a compact Set / Last time / Today table from the most recent earlier session
/// ([history] first). Today shows what is recorded, marked so, and the next set as not recorded yet; every previous
/// set is shown, and a side with nothing for a row says so instead of implying a comparison. [nextIndex] is null when
/// nothing can be recorded here (the preview, or a workout saved for later); before Start there is no Today column.
class LastTime extends StatelessWidget {
  const LastTime({super.key, required this.history, required this.status, required this.unit, this.today = const [], this.nextIndex, this.rows, this.compare = true, required this.onAll});
  final List<PreviousPerformance> history;
  final HistoryStatus status;
  final LoadUnit unit;
  final List<WorkoutSet> today;
  final int? nextIndex, rows;

  /// With the Today column (recording); false in the preview.
  final bool compare;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final last = history.firstOrNull;
    final empty = switch (status) {
      HistoryStatus.loading => 'Reading your previous sessions…',
      HistoryStatus.unavailable => 'Your previous sessions could not be read on this phone right now.',
      HistoryStatus.noIdentity => 'No history: this movement is not linked to a saved exercise, so nothing is matched by name.',
      HistoryStatus.ready when last == null => 'No previous session recorded.',
      _ => null,
    };
    final count = [last?.sets.length ?? 0, if (compare) today.length + (nextIndex == null ? 0 : 1), if (compare) rows ?? 0].fold(0, (a, b) => a > b ? a : b);
    Widget cell(String text, {Key? key, Color? color, FontWeight weight = FontWeight.w500, IconData? icon, String? below}) => Padding(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (icon != null) ...[Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: c.accent)), const SizedBox(width: 4)],
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(text, style: context.numStyle(15, color: color, weight: weight)),
                if (below != null) Text(below, style: context.sansStyle(12.5, color: c.secondary)),
              ]),
            ),
          ]),
        );
    Widget lastCell(int i, {String label = ''}) {
      final s = last?.sets.elementAtOrNull(i);
      return s != null ? cell('$label${setText(s, unit)}', key: Key('compare-$i-last')) : cell('$label—', key: Key('compare-$i-last'), color: c.secondary);
    }

    Widget todayCell(int i, {String label = ''}) {
      final s = today.elementAtOrNull(i);
      return s != null
        ? Semantics(label: 'Recorded: ${setText(s, unit)}', child: ExcludeSemantics(child: cell('$label${setText(s, unit)}', key: Key('compare-$i-today'), weight: FontWeight.w700, icon: Icons.check_circle, below: 'Recorded')))
        : cell('$label${i == nextIndex ? 'Next · not recorded yet' : 'Not recorded yet'}', key: Key('compare-$i-today'), color: c.secondary, weight: i == nextIndex ? FontWeight.w600 : FontWeight.w400);
    }

    Widget head(String text) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(text, style: context.sansStyle(13, color: c.secondary, weight: FontWeight.w600)));
    return Panel(
      key: const Key('last-time'),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(last == null ? 'Last time' : 'Last time · ${shortDate(last.dayKey)}', key: const Key('last-time-title'), style: context.sansStyle(16, weight: FontWeight.w600)),
          ),
          if (history.isNotEmpty) QuietLink('All sessions', key: const Key('all-sessions'), said: 'All previous sessions', onPressed: onAll),
        ]),
        if (last != null && last.workout.outcome != WorkoutResultRules.full) Text('${last.workout.title} · ${WorkoutResultRules.label(last.workout.outcome)}', style: context.caption),
        if (empty != null) Padding(padding: const EdgeInsets.only(top: 2, bottom: 4), child: Text(empty, key: const Key('last-time-empty'), style: context.caption)),
        // With large text each set is a short block (Set, then Last time and Today under it) instead of squeezed columns.
        if (count > 0 && MediaQuery.textScalerOf(context).scale(10) > 13)
          Column(key: const Key('compare-table'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < count; i++)
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    head('Set ${i + 1}'),
                    lastCell(i, label: 'Last time: '),
                    if (compare) todayCell(i, label: 'Today: '),
                  ]),
                ),
              ),
          ])
        else if (count > 0)
          Table(
            key: const Key('compare-table'),
            columnWidths: compare ? const {0: FlexColumnWidth(0.55), 1: FlexColumnWidth(1.3), 2: FlexColumnWidth(1.6)} : const {0: FlexColumnWidth(0.55), 1: FlexColumnWidth(2.9)},
            children: [
              TableRow(children: [head('Set'), head('Last time'), if (compare) head('Today')]),
              for (var i = 0; i < count; i++)
                TableRow(
                  decoration: i == nextIndex ? BoxDecoration(border: Border(top: BorderSide(color: c.divider), bottom: BorderSide(color: c.divider))) : null,
                  children: [
                    cell('${i + 1}', color: c.secondary),
                    lastCell(i),
                    if (compare) todayCell(i),
                  ],
                ),
            ],
          ),
      ]),
    );
  }
}

/// Every earlier session of one exercise, newest first, read-only: its date, workout, real outcome and each set.
/// Closing it leaves the panel exactly as it was.
Future<void> showExerciseHistory(BuildContext context, {required String name, required List<PreviousPerformance> history, required LoadUnit unit}) => showGoSheet<void>(
      appContext(context),
      title: name,
      builder: (sheet) => Column(key: const Key('history-sheet'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('Previous sessions, newest first: workouts that count as training, matched by this exercise and its place in the workout.', style: sheet.caption),
        for (final (i, p) in history.indexed) ...[
          const SizedBox(height: 12),
          if (i > 0) ...[const Rule(), const SizedBox(height: 12)],
          Text(longDate(p.dayKey), key: Key('history-session-$i'), style: sheet.sansStyle(16, weight: FontWeight.w600)),
          Text('${p.workout.title} · ${WorkoutResultRules.label(p.workout.outcome)}', style: sheet.caption),
          for (final (n, s) in p.sets.indexed) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${n + 1}.  ${setText(s, unit)}', style: sheet.numStyle(15, weight: FontWeight.w400))),
        ],
      ]),
    );

/// A small labelled tile: what it is ("Target") and the value.
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value, this.valueKey});
  final IconData icon;
  final String label, value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.tile), border: Border.all(color: c.divider)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ExcludeSemantics(child: Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 20, color: c.secondary))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: context.sansStyle(13.5, color: c.secondary, weight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, key: valueKey, style: context.numStyle(16.5, weight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

/// Large logging field: 37 px value, at least 88 px tall, numeric keyboard.
class _BigField extends StatelessWidget {
  const _BigField({super.key, required this.controller, required this.label, required this.suffix, required this.hint, required this.onChanged, this.decimal = false});
  final TextEditingController controller;
  final String label, suffix, hint;
  final VoidCallback onChanged;
  final bool decimal;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Targets.logging),
        child: TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          textAlign: TextAlign.center,
          style: context.sansStyle(37, weight: FontWeight.w600).copyWith(height: 1.1, fontFeatures: const [FontFeature.tabularFigures()]),
          decoration: InputDecoration(
            labelText: suffix.isEmpty ? label : '$label ($suffix)',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: hint,
            hintStyle: context.sansStyle(20, color: context.c.secondary),
            contentPadding: const EdgeInsets.fromLTRB(8, 26, 8, 14),
          ),
        ),
      );
}
