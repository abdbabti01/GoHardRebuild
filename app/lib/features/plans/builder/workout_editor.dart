import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/catalog_names.dart';
import '../../../core/format.dart';
import '../../../core/language.dart';
import '../../../core/theme.dart';
import '../../../core/units.dart';
import '../../../core/widgets.dart';
import '../../../data/models.dart';
import '../../../data/sync.dart';
import '../../coach/coach_bubble.dart';
import '../../coach/coach_contract.dart';
import '../../coach/guide_sheets.dart';
import '../../workout/workout_flow.dart';
import '../plan_draft.dart';
import '../plan_progress.dart' show prescriptionLine;
import '../plan_l10n.dart';
import '../plan_repository.dart';

/// Applies one edit to the draft being built, then saves it on the phone. [edits] marks a change to the workouts'
/// contents, after which choosing another template asks before replacing them.
typedef DraftChange = void Function(void Function(PlanDraft d) edit, {bool edits});

/// Opens Ask GoHard about part of the plan being built; the builder supplies the draft and how to apply to it.
typedef AskAbout = void Function(String label, CoachFocus focus, {String? templateId, String? workoutId, String? occurrenceKey, String? catalogKey});

/// "3 × 8–12 · 90 s rest", "3 × 40 s · 60 s rest", or "No target", in the app's language.
String rxText(Prescription e) => prescriptionLine(
    sets: e.targetSets, repsMin: e.isTimed ? null : e.targetRepsMin, repsMax: e.isTimed ? null : e.targetRepsMax,
    seconds: e.isTimed ? e.targetDurationSeconds : null, rest: e.restSeconds, timed: e.isTimed, restAsMinutes: false, zeroRest: true);

/// Where the schedule uses a workout: "Mon, Thu", "Steps 1 and 3", or null when it is not scheduled.
String? usageOf(PlanDraft d, String workoutId) {
  final s = d.schedule;
  if (s.isRotating) {
    final steps = [for (final (i, id) in s.cycle.indexed) if (id == workoutId) '${i + 1}'];
    return steps.isEmpty ? null : currentL10n.builderUsageSteps(steps.length, steps.join(currentL10n.planListComma));
  }
  final days = [for (final p in s.pattern) if (p.workoutId == workoutId) weekdayShort(p.weekday)];
  return days.isEmpty ? null : days.join(currentL10n.planListComma);
}

/// A name in a sheet. Pops the trimmed name, or nothing.
Future<String?> askName(BuildContext context, {required String title, String initial = '', String? action}) =>
    showGoSheet<String>(context, title: title, builder: (_) => _NameForm(initial: initial, action: action ?? context.l10n.actionSave));

class _NameForm extends StatefulWidget {
  const _NameForm({required this.initial, required this.action});
  final String initial, action;
  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  late final _c = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done() => Navigator.pop(context, _c.text.trim());

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        TextField(
            key: const Key('workout-name-field'), controller: _c, autofocus: true, maxLength: 60, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: context.l10n.builderName), onChanged: (_) => setState(() {}), onSubmitted: (_) => _c.text.trim().isEmpty ? null : _done()),
        const SizedBox(height: 8),
        PrimaryButton(widget.action, key: const Key('workout-name-save'), onPressed: _c.text.trim().isEmpty ? null : _done),
      ]);
}

// ------------------------------------------------------------------ the prescription editor

typedef _Rx = ({int? sets, int? repsMin, int? repsMax, int? seconds, int? rest, double? loadKg, String? notes});

Future<_Rx?> _editPrescription(BuildContext context, Prescription e, LoadUnit unit, {required String title, CoachSay? help}) =>
    showGoSheet<_Rx>(context, title: title, builder: (_) => _RxForm(e: e, unit: unit, help: help));

class _RxForm extends StatefulWidget {
  const _RxForm({required this.e, required this.unit, this.help});
  final Prescription e;
  final LoadUnit unit;

  /// What the coach says here when asked: its help entry sits above the fields, and nothing appears by itself in a form.
  final CoachSay? help;
  @override
  State<_RxForm> createState() => _RxFormState();
}

class _RxFormState extends State<_RxForm> {
  late final Prescription e = widget.e;
  late final _sets = TextEditingController(text: e.targetSets?.toString() ?? '');
  late final _lo = TextEditingController(text: e.targetRepsMin?.toString() ?? '');
  late final _hi = TextEditingController(text: e.targetRepsMax?.toString() ?? '');
  late final _secs = TextEditingController(text: e.targetDurationSeconds?.toString() ?? '');
  late final _rest = TextEditingController(text: e.restSeconds?.toString() ?? '');
  late final _load = TextEditingController(text: e.targetLoadKg == null ? '' : formatLoadValue(e.targetLoadKg!, widget.unit));
  late final _notes = TextEditingController(text: e.notes ?? '');
  final _errors = <String, String>{};

  @override
  void dispose() {
    for (final c in [_sets, _lo, _hi, _secs, _rest, _load, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Blank is "no target"; anything else must be a whole number in the range the plan rules accept.
  int? _int(String field, TextEditingController c, int min, int max, String message) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(asciiDigits(t));
    if (v == null || v < min || v > max) _errors[field] = message;
    return v;
  }

  void _save() {
    setState(_errors.clear);
    final l = context.l10n;
    final sets = _int('sets', _sets, 1, 20, l.builderRxSetsError);
    final lo = e.isTimed ? null : _int('lo', _lo, 1, 100, l.builderRxRepsError);
    final hi = e.isTimed ? null : _int('hi', _hi, 1, 100, l.builderRxRepsError);
    if (lo != null && hi != null && lo > hi) _errors['hi'] = l.builderRxRepsOrder;
    final secs = e.isTimed ? _int('secs', _secs, 1, 3600, l.builderRxTimeError) : null;
    final rest = _int('rest', _rest, 0, 900, l.builderRxRestError);
    double? kg;
    if (_load.text.trim().isNotEmpty) {
      final v = parseNonNegative(_load.text);
      kg = v == null ? null : loadInputToKg(v, widget.unit);
      if (kg == null || kg > 2000) _errors['load'] = l.builderRxLoadError(formatLoad(2000, widget.unit));
    }
    if (_notes.text.trim().length > 500) _errors['notes'] = l.builderRxNotesError;
    if (_errors.isNotEmpty) return setState(() {});
    Navigator.pop<_Rx>(context, (sets: sets, repsMin: lo, repsMax: hi, seconds: secs, rest: rest, loadKg: kg, notes: _notes.text));
  }

  Widget _field(String key, String label, TextEditingController c, {String? helper, String? error, bool decimal = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: Key(key), controller: c, keyboardType: TextInputType.numberWithOptions(decimal: decimal), textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 3, errorText: error, errorMaxLines: 3),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (widget.help case final help?) ...[
          Align(alignment: AlignmentDirectional.centerEnd, child: CoachHelpEntry(id: 'exercise.prescription', label: l.builderRxHelp)),
          CoachSpot(id: 'exercise.prescription', say: help, padding: const EdgeInsets.only(top: 4, bottom: 12)),
        ],
        _field('rx-sets', l.builderRxSets, _sets, error: _errors['sets']),
        if (e.isTimed)
          _field('rx-seconds', l.builderRxSeconds, _secs, error: _errors['secs'])
        else ...[
          _field('rx-reps-min', l.builderRxRepsMin, _lo, error: _errors['lo']),
          _field('rx-reps-max', l.builderRxRepsMax, _hi, helper: l.builderRxRepsHelper, error: _errors['hi']),
        ],
        _field('rx-rest', l.builderRxRest, _rest, error: _errors['rest']),
        _field('rx-load', l.builderRxLoad(widget.unit.label), _load, decimal: true, error: _errors['load'], helper: l.builderRxLoadHelper),
        TextField(
            key: const Key('rx-notes'), controller: _notes, maxLines: 3, minLines: 1, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.builderRxNotes, errorText: _errors['notes'])),
        const SizedBox(height: 14),
        PrimaryButton(l.actionSave, key: const Key('rx-save'), onPressed: _save),
      ]);
  }
}

// ------------------------------------------------------------------ exercise list of one workout

/// One workout's exercises with their prescriptions: tap to edit sets, reps, rest and an optional target; move up or
/// down with buttons (no dragging needed); replace or remove from the menu; add from the exercise picker.
class ExerciseListEditor extends ConsumerWidget {
  const ExerciseListEditor({super.key, required this.draft, required this.workoutId, required this.index, required this.change, this.ask});
  final PlanDraft draft;
  final String workoutId;
  final int index;
  final DraftChange change;

  /// Ask GoHard from an exercise's information; without it Ask GoHard opens with no draft to change.
  final AskAbout? ask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(loadUnitProvider);
    final w = draft.workout(workoutId)!;
    final list = w.exercises;
    final wi = index;
    final l = context.l10n;
    final names = ref.watch(exerciseNamesProvider), locale = Localizations.localeOf(context);
    String nameOf(Prescription e) => names.name(e.catalogKey, e.name, locale);
    late final void Function(Prescription) about;
    void askAbout(Prescription e) {
      final label = '${nameOf(e)} · ${w.name}';
      if (ask != null) return ask!(label, CoachFocus.exercise, workoutId: workoutId, occurrenceKey: e.occurrenceKey, catalogKey: e.catalogKey);
      openAskGoHard(context, CoachContext(label: label, focus: CoachFocus.exercise, workoutId: workoutId, occurrenceKey: e.occurrenceKey, catalogKey: e.catalogKey));
    }

    Future<void> edit(Prescription e) async {
      final rx = await _editPrescription(context, e, unit, title: nameOf(e),
          help: CoachSay(l.builderCoachExercise,
              onAsk: () => askAbout(e), guide: (label: l.builderAboutExercise, key: const Key('coach-exercise-info'), onPressed: () => about(e))));
      if (rx == null) return;
      change((d) => d.setPrescription(workoutId, e.occurrenceKey,
          sets: rx.sets, repsMin: rx.repsMin, repsMax: rx.repsMax, seconds: rx.seconds, restSeconds: rx.rest, targetLoadKg: rx.loadKg, notes: rx.notes), edits: true);
    }

    Future<void> replace(Prescription e) async {
      final picked = await push<CatalogExercise>(context, ExercisePicker(title: l.builderReplaceExercise(nameOf(e))));
      if (picked != null) change((d) => d.replaceExercise(workoutId, e.occurrenceKey, picked), edits: true);
    }

    about = (e) => showExerciseInfo(context, exercise: e, workoutName: w.name, onReplace: () => replace(e), onAsk: () => askAbout(e));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (list.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: StatusLine(Icons.info_outline, l.builderNoExercisesWarn, tone: Tone.warning)),
      for (final (ei, e) in list.indexed)
        DecoratedBox(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.c.divider))),
          child: Row(children: [
            Expanded(
              child: Semantics(
                button: true, hint: l.builderEditRx,
                child: InkWell(
                  key: Key('exercise-$wi-$ei'),
                  onTap: () => edit(e),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Targets.minimum),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('${ei + 1}. ${nameOf(e)}', style: context.sansStyle(15.5, weight: FontWeight.w600)),
                        Text(rxText(e), style: context.numStyle(14, color: context.c.secondary, weight: FontWeight.w500)),
                        if (e.targetLoadKg != null)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.flag_outlined, size: 15, color: context.c.secondary),
                            const SizedBox(width: 4),
                            Flexible(child: Text(l.planTargetLoad(formatLoad(e.targetLoadKg, unit)), style: context.caption)),
                          ]),
                        if (e.notes != null) Text(e.notes!, style: context.caption),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(key: Key('exercise-info-$wi-$ei'), tooltip: l.builderAbout(nameOf(e)), icon: const Icon(Icons.info_outline, size: 20), onPressed: () => about(e)),
            IconButton(key: Key('exercise-up-$wi-$ei'), tooltip: l.builderMoveUp(nameOf(e)), icon: const Icon(Icons.arrow_upward, size: 20),
                onPressed: ei == 0 ? null : () => change((d) => d.moveExercise(workoutId, e.occurrenceKey, -1), edits: true)),
            IconButton(key: Key('exercise-down-$wi-$ei'), tooltip: l.builderMoveDown(nameOf(e)), icon: const Icon(Icons.arrow_downward, size: 20),
                onPressed: ei == list.length - 1 ? null : () => change((d) => d.moveExercise(workoutId, e.occurrenceKey, 1), edits: true)),
            PopupMenuButton<String>(
              key: Key('exercise-menu-$wi-$ei'), tooltip: l.builderMoreFor(nameOf(e)),
              onSelected: (v) async {
                if (v == 'edit') return edit(e);
                if (v == 'remove') return change((d) => d.removeExercise(workoutId, e.occurrenceKey), edits: true);
                return replace(e);
              },
              itemBuilder: (_) => [
                PopupMenuItem(key: Key('exercise-edit-$wi-$ei'), value: 'edit', child: Text(l.builderEditRx)),
                PopupMenuItem(key: Key('exercise-replace-$wi-$ei'), value: 'replace', child: Text(l.builderReplaceWithAnother)),
                PopupMenuItem(key: Key('exercise-remove-$wi-$ei'), value: 'remove', child: Text(l.actionRemove)),
              ],
            ),
          ]),
        ),
      const SizedBox(height: 8),
      SecondaryButton(l.builderAddExercise, key: Key('exercise-add-$wi'), icon: Icons.add, onPressed: () async {
        final picked = await push<CatalogExercise>(context, ExercisePicker(title: l.builderAddTo(w.name)));
        if (picked != null) change((d) => d.addExercise(workoutId, picked), edits: true);
      }),
    ]);
  }
}

// ------------------------------------------------------------------ step 3: workouts

class WorkoutsStep extends ConsumerWidget {
  const WorkoutsStep({super.key, required this.draft, required this.change, this.ask});
  final PlanDraft draft;
  final DraftChange change;
  final AskAbout? ask;

  Future<void> _copyFrom(BuildContext context, WidgetRef ref) async {
    final others = [for (final p in ref.read(planListProvider)) if (p.id != draft.planId && p.workouts.isNotEmpty) p];
    final recorded = [
      for (final w in [...ref.read(workoutListProvider)]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc)))
        if (!w.isDeleted && w.exercises.any((e) => e.isPrescribed && !e.isDeleted)) w,
    ].take(10).toList();
    final l = context.l10n;
    Widget source(String key, String title, String subtitle, String name, List<Prescription> exercises) => ListRow(
        key: Key(key), title: title, subtitle: subtitle, onTap: () => Navigator.pop(context, (name: name, exercises: exercises)));
    final picked = await showGoSheet<({String name, List<Prescription> exercises})>(context, title: l.builderCopyWorkout,
        builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text(l.builderCopyNote, style: context.caption),
              const SizedBox(height: 10),
              SectionLabel(l.builderThisPlan),
              for (final (i, w) in draft.workouts.indexed) source('copy-this-$i', w.name, l.planExercisesPlain(w.exercises.length), w.name, w.exercises),
              for (final p in others) ...[
                const SizedBox(height: 12),
                SectionLabel(p.title),
                for (final (i, w) in p.workouts.indexed) source('copy-plan-${p.id}-$i', w.name, l.planExercisesPlain(w.exercises.length), w.name, w.exercises),
              ],
              if (recorded.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionLabel(l.builderRecordedSection),
                for (final w in recorded)
                  source('copy-recorded-${w.id}', w.title, shortDate(w.dayKey), w.title, [
                    for (final e in w.exercises)
                      if (e.isPrescribed && !e.isDeleted)
                        Prescription({
                          'catalogKey': e.catalogKey, 'name': e.name, 'isTimed': e.isTimed, 'targetSets': e.targetSets, 'targetRepsMin': e.targetRepsMin,
                          'targetRepsMax': e.targetRepsMax, 'targetDurationSeconds': e.targetDurationSeconds, 'restSeconds': e.restSeconds,
                          if (e.targetLoadKg != null) 'targetLoadKg': e.targetLoadKg, if (e.notes != null) 'notes': e.notes,
                        }),
                  ]),
              ],
            ]));
    if (picked == null) return;
    final taken = {for (final w in draft.workouts) w.name};
    change((d) => d.copyWorkout(taken.contains(picked.name) ? l.planCopyName(picked.name) : picked.name, picked.exercises), edits: true);
    if (context.mounted) toast(context, l.builderCopied);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kept loaded for "Copy from…".
    ref.watch(planListProvider);
    ref.watch(workoutListProvider);
    final workouts = draft.workouts;
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.builderWorkoutsIntro, style: context.caption),
      for (final (wi, w) in workouts.indexed) ...[
        const SizedBox(height: 18),
        Panel(
          // Panel takes plain insets: the wider side stays on the leading edge.
          padding: context.isRtl ? const EdgeInsets.fromLTRB(6, 10, 16, 14) : const EdgeInsets.fromLTRB(16, 10, 6, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // The workout's name in the serif, as the plan's own names are elsewhere.
                  Semantics(header: true, child: Text(w.name, style: context.pageTitleStyle(24))),
                  Text(l.planExerciseCount(w.exercises.length), style: context.numStyle(14, color: context.c.secondary, weight: FontWeight.w500)),
                  Text(usageOf(draft, w.id) ?? l.builderNotScheduled, style: context.caption),
                ]),
              ),
              IconButton(key: Key('workout-up-$wi'), tooltip: l.builderMoveUp(w.name), icon: const Icon(Icons.arrow_upward, size: 20),
                  onPressed: wi == 0 ? null : () => change((d) => d.moveWorkout(w.id, -1))),
              IconButton(key: Key('workout-down-$wi'), tooltip: l.builderMoveDown(w.name), icon: const Icon(Icons.arrow_downward, size: 20),
                  onPressed: wi == workouts.length - 1 ? null : () => change((d) => d.moveWorkout(w.id, 1))),
              PopupMenuButton<String>(
                key: Key('workout-menu-$wi'), tooltip: l.builderMoreFor(w.name),
                onSelected: (v) async {
                  switch (v) {
                    case 'rename':
                      final name = await askName(context, title: l.builderRenameWorkout, initial: w.name);
                      if (name != null && name.isNotEmpty) change((d) => d.renameWorkout(w.id, name), edits: true);
                    case 'duplicate':
                      change((d) => d.duplicateWorkout(w.id, name: l.planCopyName(w.name)), edits: true);
                    case 'delete':
                      final ok = await confirm(context,
                          title: l.builderDeleteTitle(w.name), destructive: true, action: l.builderDeleteWorkout,
                          body: l.builderDeleteBody);
                      if (ok) change((d) => d.deleteWorkout(w.id), edits: true);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(key: Key('workout-rename-$wi'), value: 'rename', child: Text(l.builderRename)),
                  PopupMenuItem(key: Key('workout-duplicate-$wi'), value: 'duplicate', child: Text(l.builderDuplicate)),
                  PopupMenuItem(key: Key('workout-delete-$wi'), value: 'delete', child: Text(l.actionDelete)),
                ],
              ),
            ]),
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsetsDirectional.only(end: 10), child: ExerciseListEditor(draft: draft, workoutId: w.id, index: wi, change: change, ask: ask)),
          ]),
        ),
      ],
      const SizedBox(height: 18),
      SecondaryButton(l.builderAddWorkout, key: const Key('workout-add'), icon: Icons.add, onPressed: () async {
        final name = await askName(context, title: l.builderNewWorkout, action: l.builderAddWorkout);
        if (name != null && name.isNotEmpty) change((d) => d.addWorkout(name), edits: true);
      }),
      const SizedBox(height: 10),
      SecondaryButton(l.builderCopyFrom, key: const Key('workout-copy'), icon: Icons.copy_outlined, onPressed: () => _copyFrom(context, ref)),
    ]);
  }
}

// ------------------------------------------------------------------ this workout only

/// Edits one pending occurrence of a fixed-weekday plan: its name and exercises. The rest of the plan is unchanged.
class OccurrenceEditorScreen extends ConsumerStatefulWidget {
  const OccurrenceEditorScreen({super.key, required this.plan, required this.occasion});
  final Plan plan;
  final Occasion occasion;
  @override
  ConsumerState<OccurrenceEditorScreen> createState() => _OccurrenceEditorScreenState();
}

class _OccurrenceEditorScreenState extends ConsumerState<OccurrenceEditorScreen> {
  static const _id = 'this-workout';
  late final PlanDraft _draft = PlanDraft.fresh(today: widget.occasion.scheduledDate, path: 'custom')
    ..j['workouts'] = [
      {'id': _id, 'name': widget.occasion.title, 'notes': null, 'exercises': [for (final p in widget.occasion.prescription) copyJson(p.j)]},
    ];
  late final _title = TextEditingController(text: widget.occasion.title);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _change(void Function(PlanDraft d) edit, {bool edits = false}) => setState(() {
        edit(_draft);
        _error = null;
      });

  Future<void> _save() async {
    final l = context.l10n;
    if (_title.text.trim().isEmpty) return setState(() => _error = l.builderGiveWorkoutName);
    setState(() => _busy = true);
    final plan = ref.read(planListProvider).where((p) => p.id == widget.plan.id).firstOrNull ?? widget.plan;
    try {
      await ref.read(planRepositoryProvider).editOccasion(plan, scheduleOf(plan, ref.read(workoutListProvider)), widget.occasion,
          title: _title.text, prescription: [for (final e in _draft.workout(_id)!.exercises) copyJson(e.j)]);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(l.builderSavedOnly(shortDate(widget.occasion.scheduledDate))), duration: const Duration(milliseconds: 2200)));
    } on ScheduleRefused catch (e) {
      setState(() { _busy = false; _error = planErrorText(l, e.codes.first); });
    } on LocalSaveFailure {
      setState(() { _busy = false; _error = l.planLocalSaveFailed; });
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: context.l10n.builderThisWorkoutOnly,
        subtitle: longDate(widget.occasion.scheduledDate),
        bottom: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
          PrimaryButton(context.l10n.builderSaveThisWorkout, key: const Key('occurrence-save'), busy: _busy, onPressed: _save),
        ]),
        children: [
          StatusLine(Icons.info_outline, context.l10n.builderOnlyThisChanges(longDate(widget.occasion.scheduledDate), widget.plan.title)),
          const SizedBox(height: 16),
          TextField(key: const Key('occurrence-title'), controller: _title, maxLength: 60, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: context.l10n.builderWorkoutName)),
          const SizedBox(height: 8),
          ExerciseListEditor(draft: _draft, workoutId: _id, index: 0, change: _change),
        ],
      );
}
