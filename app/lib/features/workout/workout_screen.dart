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
import '../plans/plan_progress.dart';
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

/// The foreground workout: current exercise, editable entry, recorded sets, rest and deliberate transitions.
/// Targets and previous performance are shown as guidance, separate from the sets actually recorded.
class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key, required this.workoutId});
  final String workoutId;
  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> with WidgetsBindingObserver {
  final _load = TextEditingController(), _reps = TextEditingController(), _duration = TextEditingController();
  Timer? _ticker, _draftDebounce;
  WorkoutRuntime? _runtime;
  String? _boundExerciseId, _error;
  LoadUnit? _entryUnit; // pinned while the entry is dirty
  bool _busy = false, _loaded = false;

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
      if (mounted) setState(() {});
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

  void _onTyped() {
    _entryUnit ??= _unitNow;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 400), _flushDraft);
  }

  void _flushDraft() {
    _draftDebounce?.cancel();
    final r = _runtime, id = _boundExerciseId;
    if (r == null || id == null || _closed) return;
    final LoadUnit unit = _entryUnit ?? _unitNow;
    final draft = EntryDraft.of(load: _load.text, reps: _reps.text, duration: _duration.text, unit: unit.name);
    _runtime = r.withDraft(id, draft);
    unawaited(_repo.saveRuntime(widget.workoutId, _runtime!));
  }

  /// Binds the entry fields to an exercise: its saved draft first, otherwise a suggestion from actual history.
  void _bind(WorkoutExercise exercise, List<WorkoutSet> mine, PreviousPerformance? previous, LoadUnit unit) {
    if (_boundExerciseId == exercise.id) return;
    _boundExerciseId = exercise.id;
    final draft = _runtime!.draftFor(exercise.id);
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
      await _repo.finish(workout);
      if (mounted) await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workoutId: workout.id, justFinished: true)));
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
        _flushDraft();
        _boundExerciseId = null;
        await _save(_runtime!.selecting(added.id));
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
        if (mounted) Navigator.pop(context);
      case 'discard':
        if (await confirm(context, title: 'Remove this workout?', body: 'This removes "${workout.title}" and every set recorded in it. This is the only way a workout is ever removed; it is never cleaned up automatically.', action: 'Remove workout')) {
          _closed = true;
          await _repo.delete(workout);
          if (mounted) Navigator.pop(context);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = (ref.watch(workoutsProvider).value ?? const <Stored<Workout>>[]).where((r) => r.value.id == widget.workoutId).firstOrNull;
    final setRows = ref.watch(setsProvider(widget.workoutId)).value ?? const <Stored<WorkoutSet>>[];
    final unit = _unitNow = ref.watch(loadUnitProvider);
    if (row == null || !_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final workout = row.value;
    if (!workout.isOpen) return WorkoutDetailScreen(workoutId: workout.id);

    final runtime = _runtime!;
    final exercises = workout.exercises;
    final selected = exercises.where((e) => e.id == runtime.selectedExerciseId).firstOrNull ?? exercises.firstOrNull;
    final live = [for (final r in setRows) if (!r.value.isDeleted) r]..sort((a, b) => a.value.performedAtUtc.compareTo(b.value.performedAtUtc));
    List<Stored<WorkoutSet>> setsOf(String id) => [for (final r in live) if (r.value.exerciseId == id) r];
    final mine = selected == null ? const <Stored<WorkoutSet>>[] : setsOf(selected.id);
    final previous = selected == null ? null : previousPerformance(workout, selected, ref.watch(workoutListProvider), ref.watch(trustedSetsProvider));
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

    return PopScope(
      onPopInvokedWithResult: (_, _) => _flushDraft(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(workout.title, overflow: TextOverflow.ellipsis),
          actions: [
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
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(context.inset, 4, context.inset, 28),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Row(children: [
                Expanded(
                  child: Semantics(
                    label: 'Workout time ${durationText(runtime.elapsedSeconds(_now))}${runtime.isPaused ? ', paused' : ''}',
                    child: ExcludeSemantics(child: Text(clockText(runtime.elapsedSeconds(_now)), style: context.titleStyle(30))),
                  ),
                ),
                SecondaryButton(runtime.isPaused ? 'Resume' : 'Pause', key: const Key('workout-pause'), expand: false, icon: runtime.isPaused ? Icons.play_arrow : Icons.pause,
                    onPressed: () => _save(runtime.isPaused ? runtime.resumed(_now) : runtime.paused(_now))),
              ]),
              if (runtime.isPaused) const Padding(padding: EdgeInsets.only(top: 8), child: StatusLine(Icons.pause_circle_outline, 'Workout paused. Time and rest are frozen until you resume.')),
              if (row.needsReview)
                const Padding(padding: EdgeInsets.only(top: 8), child: StatusLine(Icons.rule, 'Saved on this phone; this workout needs review before it can sync. See the review notice below the screen.', tone: Tone.warning)),
              // Recorded work against the plan, for the whole workout. Targets alone never move it.
              Builder(builder: (context) {
                final p = SetProgress.of(workout, [for (final r in live) r.value]);
                return Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: p.planned == null
                      ? Text('${p.recorded} ${p.recorded == 1 ? 'set' : 'sets'} recorded', style: context.numStyle(13.5, color: context.c.secondary, weight: FontWeight.w400))
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${p.counted} of ${p.planned} planned sets recorded', style: context.numStyle(13.5, color: context.c.secondary, weight: FontWeight.w400)),
                          const SizedBox(height: 6),
                          ProgressRail(p.fraction, label: 'Planned sets recorded', height: 6),
                        ]),
                );
              }),
              const SizedBox(height: 22),
              if (selected == null)
                EmptyState('No movements yet', 'Add a movement to start recording sets.',
                    action: SecondaryButton('Add a movement', icon: Icons.add, onPressed: () => _menu('add', workout, null)))
              else ...[
                Overline('Movement ${exercises.indexOf(selected) + 1} of ${exercises.length}${selected.isPrescribed ? '' : ' · extra'}'),
                const SizedBox(height: 6),
                Heading(selected.name, size: 28),
                if (selected.substitutedForKey != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Recorded as ${selected.name}, in place of the planned movement.', style: context.caption)),
                const SizedBox(height: 8),
                Text('Target · ${selected.target}', style: context.numStyle(15, color: context.c.secondary, weight: FontWeight.w400)),
                Text(
                  previous == null ? 'No previous record for this movement.' : 'Last time (${shortDate(previous.dayKey)}) · ${previous.sets.map((s) => setText(s, unit)).join(', ')}',
                  style: context.numStyle(15, color: context.c.secondary, weight: FontWeight.w400),
                ),
                const SizedBox(height: 16),
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
                Overline('Set ${mine.length + 1}'),
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
                if (targetReached) const Padding(padding: EdgeInsets.only(bottom: 10), child: StatusLine(Icons.check_circle_outline, 'Target set count recorded. Add another set, or move on when you are ready.')),
                // Reaching the target never changes exercise. The same action stays available for extra sets.
                PrimaryButton(targetReached ? 'Add another set' : 'Complete set', key: const Key('complete-set'), busy: _busy, onPressed: () => _complete(workout, selected)),
                if (nextExercise != null) ...[
                  const SizedBox(height: 8),
                  SecondaryButton('Next exercise · ${nextExercise.name}', key: const Key('next-exercise'), onPressed: () {
                    _flushDraft();
                    _save(_runtime!.selecting(nextExercise.id));
                  }),
                ],
                const SizedBox(height: 22),
                const Overline('Recorded sets'),
                const SizedBox(height: 8),
                if (mine.isEmpty)
                  Text('None yet. Targets and suggestions are not recorded sets.', style: context.caption)
                else
                  GroupCard(children: [
                    for (final (i, r) in mine.indexed)
                      GroupRow(
                        key: Key('set-row-$i'),
                        title: '${i + 1}.  ${setText(r.value, unit)}',
                        subtitle: r.needsReview ? 'Needs review' : r.isPending ? 'Saved on this phone · sync pending' : null,
                        trailing: Icon(Icons.edit_outlined, size: 20, color: context.c.secondary),
                        onTap: () => _editSet(r.value, selected),
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
                      onTap: e.id == selected?.id ? null : () {
                        _flushDraft();
                        _save(_runtime!.selecting(e.id));
                      },
                    ),
                ]),
              const SizedBox(height: 22),
              SecondaryButton('Finish workout', key: const Key('finish-workout'), icon: Icons.flag_outlined, onPressed: () => _finish(workout)),
              Center(child: TextButton(onPressed: () => _menu('park', workout, selected), child: const Text('Save for later'))),
            ],
          ),
        ),
      ),
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
