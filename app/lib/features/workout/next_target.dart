import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/compatibility.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../coach/coach_bubble.dart';
import '../plans/plan_projection.dart';
import '../plans/plan_repository.dart';
import 'progression.dart';
import 'progression_repository.dart';
import 'workout_screen.dart' show setText, shownName, typedLoad;

/// Next targets in the workout workspace, the result and the preview (docs/PROGRESSION.md). Reading a suggestion,
/// opening the review or keeping the current target changes no plan; only the review's confirmation saves, through
/// the plan's own revision-checked command. Nothing here records a set.

/// One exercise occurrence of one plan workout: where a next target lives.
typedef TargetKey = ({String planId, String workoutId, String occurrenceKey});

class TargetSlot {
  const TargetSlot(this.plan, this.definition, this.exercise);
  final Plan plan;
  final WorkoutDefinition definition;

  /// The exercise as the plan holds it now: its next target.
  final Prescription exercise;
  TargetKey get key => (planId: plan.id, workoutId: definition.id, occurrenceKey: exercise.occurrenceKey);
  String get noteId => ProgressionRepository.noteId(plan.id, definition.id, exercise.occurrenceKey);
}

/// Which plan workout each occurrence of a plan belongs to, from the same projection as Today and Train.
final _definitionsProvider = Provider.family<Map<String, String>, String>((ref, planId) {
  final plan = ref.watch(planListProvider).where((p) => p.id == planId).firstOrNull;
  if (plan == null || !plan.isBuilt) return const {};
  return {for (final o in planOccasions(plan, ref.watch(todayKeyProvider), ref.watch(workoutListProvider))) if (o.workoutId != null) o.id: o.workoutId!};
});

/// The plan workout a recorded workout was started from, or null (manual, a plan from before the builder, gone).
String? definitionOf(WidgetRef ref, Workout w) => w.planId == null || w.occasionId == null ? null : ref.watch(_definitionsProvider(w.planId!))[w.occasionId];

/// Null when the plan, the workout or the exercise is gone, or the plan is not in use: nothing is then associated.
final targetSlotProvider = Provider.family<TargetSlot?, TargetKey>((ref, k) {
  final plan = ref.watch(planListProvider).where((p) => p.id == k.planId).firstOrNull;
  if (plan == null || !plan.isBuilt || !(plan.isActive || plan.isPaused)) return null;
  final def = plan.workouts.where((w) => w.id == k.workoutId).firstOrNull;
  final e = def?.exercises.where((x) => x.occurrenceKey == k.occurrenceKey).firstOrNull;
  return e == null ? null : TargetSlot(plan, def!, e);
});

String? _equipment(Ref ref, String? key) {
  if (key == null) return null;
  for (final c in ref.watch(customExercisesProvider).value ?? const <CustomExercise>[]) {
    if (c.key == key) return c.equipment;
  }
  return (ref.watch(catalogProvider).value ?? const <CatalogExercise>[]).where((c) => c.key == key).firstOrNull?.equipment;
}

/// The deterministic result for one exercise of one plan workout, recomputed from the records whenever they change.
final progressionProvider = Provider.family<ProgressionResult?, TargetKey>((ref, k) {
  final slot = ref.watch(targetSlotProvider(k));
  if (slot == null) return null;
  final defs = ref.watch(_definitionsProvider(k.planId));
  return ProgressionRules.evaluate(
    planId: k.planId, definitionId: k.workoutId, rx: slot.exercise, equipment: _equipment(ref, slot.exercise.catalogKey),
    workouts: ref.watch(workoutListProvider), sets: ref.watch(trustedSetsProvider), definitionOf: (id) => defs[id],
    incrementKg: slot.exercise.catalogKey == null ? null : ref.watch(incrementsProvider).value?[slot.exercise.catalogKey]?.value.incrementKg,
  );
});

/// What the Next time section offers: actionable, and not kept as it is from these same facts.
final suggestionProvider = Provider.family<ProgressionResult?, TargetKey>((ref, k) {
  final r = ref.watch(progressionProvider(k));
  if (r == null || !r.actionable) return null;
  final note = ref.watch(progressionNotesProvider).value?[ProgressionRepository.noteId(k.planId, k.workoutId, k.occurrenceKey)];
  return note?['dismissed'] == r.fingerprint ? null : r;
});

// ---------------------------------------------------------------------------------------------- words

String _rx(AppLocalizations l, int? sets, int? lo, int? hi) => targetText(sets: sets, repsMin: lo, repsMax: hi, l: l);
String _days(AppLocalizations l, ProgressionResult r) {
  final days = [for (final s in r.sessions.reversed) shortDate(s.workout.dayKey)];
  return days.toSet().length == 1 ? l.workoutProgressionDaysBoth(days.first) : l.workoutProgressionDaysPair(days.first, days.last);
}

/// A short, factual sentence from the result: what was recorded and what follows from it. No claims about readiness.
/// [exercise] is the name as shown; [workout] the plan workout's own name.
String explainProgression(ProgressionResult r, {required String exercise, required String workout, required LoadUnit unit, AppLocalizations? l}) {
  l ??= currentL10n;
  final target = formatLoad(r.targetKg, unit);
  final top = r.repsMax ?? 0, sets = r.sets ?? 0;
  return switch (r.decision) {
    ProgressionDecision.increase || ProgressionDecision.configureIncrement || ProgressionDecision.incrementTooLarge when r.sessions.length == 2 =>
      [
        l.workoutProgressionQualified(workout, _days(l, r), sets, exercise, target, top, ltr('${r.repsMin}–$top')),
        if (r.decision == ProgressionDecision.configureIncrement) l.workoutProgressionConfigureIncrement,
        if (r.decision == ProgressionDecision.incrementTooLarge) l.workoutProgressionIncrementTooLarge(formatLoad(r.incrementKg, unit)),
      ].join(' '),
    ProgressionDecision.keepCurrent => '${switch (r.sessions.firstWhere((s) => !s.qualifies).reason) {
        ProgressionReason.belowTop => l.workoutProgressionBelowTop(workout, top, target),
        ProgressionReason.setsMissing => l.workoutProgressionSetsMissing(workout, sets, exercise),
        ProgressionReason.extraSets => l.workoutProgressionExtraSets(workout, sets, exercise),
        ProgressionReason.loadUnknown => l.workoutProgressionLoadUnknown(workout),
        ProgressionReason.loadDiffers => l.workoutProgressionLoadDiffers(workout, target),
        ProgressionReason.partialWorkout => l.workoutProgressionPartial(workout),
        _ => l.workoutProgressionNotAsPlanned(workout, exercise),
      }} ${l.workoutProgressionStays(target)}',
    ProgressionDecision.moreSessions => r.reason == ProgressionReason.targetChanged
        ? l.workoutProgressionTargetChanged(workout, target)
        : l.workoutProgressionNeedTwo(workout, target, r.sessions.where((s) => s.reason != ProgressionReason.targetChanged).length),
    ProgressionDecision.setBaseline => r.reason == ProgressionReason.noLoadTarget ? l.workoutProgressionNoLoadTarget(workout) : l.workoutProgressionNoRange(workout),
    ProgressionDecision.unsupported => switch (r.reason) {
        ProgressionReason.timed => l.workoutProgressionTimed,
        ProgressionReason.bodyweight || ProgressionReason.assisted => l.workoutProgressionBodyweight,
        _ => l.workoutProgressionNoIdentity,
      },
    _ => '',
  };
}

// ---------------------------------------------------------------------------------------------- Next time

/// "Next time": the suggestions of one plan workout, compact. The first is a small card; any others are one row each
/// with a way to review them. [source] limits it to the suggestions a finished workout produced (the result).
class NextTimeSection extends ConsumerWidget {
  const NextTimeSection({super.key, required this.planId, required this.workoutId, this.source});
  final String planId, workoutId;
  final String? source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planListProvider).where((p) => p.id == planId).firstOrNull;
    final def = plan?.workouts.where((w) => w.id == workoutId).firstOrNull;
    if (def == null) return const SizedBox.shrink();
    final shown = [
      for (final e in def.exercises)
        if (ref.watch(suggestionProvider((planId: planId, workoutId: workoutId, occurrenceKey: e.occurrenceKey))) case final r?)
          if (source == null || r.sourceWorkoutId == source) (e, r),
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    final unit = ref.watch(loadUnitProvider);
    final l = context.l10n;
    final (first, firstResult) = shown.first;
    TargetKey key(Prescription e) => (planId: planId, workoutId: workoutId, occurrenceKey: e.occurrenceKey);
    return Column(key: const Key('next-time'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 22),
      SectionHeader(l.workoutNextTimeHeader, trailing: CoachHelpEntry(id: 'progression.next', label: l.workoutNextTimeHelpLabel)),
      CoachSpot(
        id: 'progression.next', introduce: true,
        say: CoachSay(
          firstResult.decision == ProgressionDecision.increase
              ? l.workoutNextTimeCoachIncrease(shownName(ref, context, first.catalogKey, first.name))
              : l.workoutNextTimeCoachIncrement(shownName(ref, context, first.catalogKey, first.name)),
          guide: (label: l.workoutProgressionHowTitle, key: const Key('progression-how'), onPressed: () => showProgressionHelp(context)),
        ),
      ),
      const SizedBox(height: 10),
      _SuggestionCard(slotKey: key(first), result: firstResult, exercise: first, workout: def.name, unit: unit),
      if (shown.length > 1) ...[
        const SizedBox(height: 10),
        GroupCard(children: [
          for (final (e, r) in shown.skip(1))
            GroupRow(
              key: Key('next-time-row-${e.occurrenceKey}'), title: shownName(ref, context, e.catalogKey, e.name),
              subtitle: r.decision == ProgressionDecision.increase ? l.workoutNextTimeRowReview(ltr('${formatLoad(r.targetKg, unit)} → ${formatLoad(r.proposedKg, unit)}')) : l.workoutChooseIncrement,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => r.decision == ProgressionDecision.increase ? showTargetReview(context, key(e)) : showIncrementSheet(context, e),
            ),
        ]),
      ],
    ]);
  }
}

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({required this.slotKey, required this.result, required this.exercise, required this.workout, required this.unit});
  final TargetKey slotKey;
  final ProgressionResult result;
  final Prescription exercise;
  final String workout;
  final LoadUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = result, l = context.l10n;
    final increase = r.decision == ProgressionDecision.increase;
    final name = shownName(ref, context, exercise.catalogKey, exercise.name);
    return PanelTheme(
      child: Builder(builder: (context) => PanelSurface(
        child: Column(key: Key('next-time-card-${exercise.occurrenceKey}'), crossAxisAlignment: CrossAxisAlignment.start, children: [
          Overline(workout),
          const SizedBox(height: 2),
          Semantics(header: true, child: Text(name, style: context.pageTitleStyle(24))),
          const SizedBox(height: 8),
          Wrap(spacing: 22, runSpacing: 8, children: [
            _Figure(l.workoutCurrentTarget, formatLoad(r.targetKg, unit)),
            if (increase) _Figure(l.workoutProposed, formatLoad(r.proposedKg, unit), valueKey: const Key('next-time-proposed')),
          ]),
          const SizedBox(height: 4),
          Text(_rx(l, r.sets, r.repsMin, r.repsMax), style: context.numStyle(15, color: context.c.secondary, weight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(explainProgression(r, exercise: name, workout: workout, unit: unit, l: l), style: context.sansStyle(14.5)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            increase
                ? PrimaryButton(l.workoutReviewNextTarget, key: const Key('next-time-review'), expand: false, onPressed: () => showTargetReview(appContext(context), slotKey))
                : PrimaryButton(l.workoutChooseIncrement, key: const Key('next-time-increment'), expand: false, onPressed: () => showIncrementSheet(appContext(context), exercise)),
            TextButton(
              key: const Key('next-time-keep'),
              onPressed: () => keepCurrentTarget(appContext(context), ref, slotKey, r),
              child: Text(l.workoutKeepCurrentTarget),
            ),
          ]),
        ]),
      )),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {this.valueKey});
  final String label, value;
  final Key? valueKey;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Overline(label),
        Text(value, key: valueKey, style: context.pageTitleStyle(26)),
      ]);
}

/// Keep current target: the plan keeps what it has, and this suggestion (from these facts) is not offered again.
Future<void> keepCurrentTarget(BuildContext context, WidgetRef ref, TargetKey k, ProgressionResult r) async {
  try {
    await ref.read(progressionRepositoryProvider).dismiss(ProgressionRepository.noteId(k.planId, k.workoutId, k.occurrenceKey), r.fingerprint);
    if (context.mounted) toast(context, context.l10n.workoutKeptTarget(formatLoad(r.targetKg, ref.read(loadUnitProvider))));
  } on LocalSaveFailure {
    if (context.mounted) toast(context, context.l10n.workoutSaveFailedNothingChanged);
  }
}

// ---------------------------------------------------------------------------------------------- the entry in the recorder

/// The selected exercise's next target, apart from today's: "Next target · 195 lb" with Review, or Set a target when
/// the plan has no weight target. Shown only while the exercise is still in the plan workout it was started from.
class NextTargetLine extends ConsumerWidget {
  const NextTargetLine({super.key, required this.slotKey});
  final TargetKey slotKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = ref.watch(targetSlotProvider(slotKey));
    if (slot == null) return const SizedBox.shrink();
    final unit = ref.watch(loadUnitProvider);
    final load = slot.exercise.targetLoadKg;
    final suggested = ref.watch(suggestionProvider(slotKey))?.decision == ProgressionDecision.increase;
    final l = context.l10n, name = shownName(ref, context, slot.exercise.catalogKey, slot.exercise.name);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
        Icon(Icons.update, size: 18, color: context.c.secondary),
        Text(load == null ? l.workoutNoNextTarget : l.workoutNextTargetValue(formatLoad(load, unit)), key: const Key('workout-next-target'),
            style: context.sansStyle(14.5, color: context.c.secondary, weight: FontWeight.w500)),
        QuietLink(load == null ? l.workoutSetATarget : suggested ? l.workoutReviewSuggestion : l.workoutReview, key: const Key('workout-next-target-review'),
            said: load == null ? l.workoutSetNextTargetSemantic(name) : l.workoutReviewNextTargetSemantic(name),
            onPressed: () => showTargetReview(appContext(context), slotKey)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------- review

/// Review next target: the exercise and its workout, the current target, the suggestion (if any) in the person's
/// unit, editable sets and rep range, the sessions behind it and why. Saves only on the explicit confirmation.
Future<void> showTargetReview(BuildContext context, TargetKey key) =>
    showGoSheet<void>(context, title: context.l10n.workoutNextTargetTitle, builder: (_) => _TargetReview(slotKey: key));

class _TargetReview extends ConsumerStatefulWidget {
  const _TargetReview({required this.slotKey});
  final TargetKey slotKey;
  @override
  ConsumerState<_TargetReview> createState() => _TargetReviewState();
}

class _TargetReviewState extends ConsumerState<_TargetReview> {
  final _load = TextEditingController(), _sets = TextEditingController(), _lo = TextEditingController(), _hi = TextEditingController();
  LoadUnit _unit = LoadUnit.kg;
  bool _busy = false, _editing = false, _touched = false;

  /// What the form was last filled from. Until the person types, it follows the records as they load (the unit, the
  /// suggestion); after that it keeps what they typed, in the unit they typed it in.
  String? _filledFrom;
  String? _error;

  @override
  void dispose() {
    for (final c in [_load, _sets, _lo, _hi]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(TargetSlot slot, ProgressionResult? r) {
    final e = slot.exercise;
    // The suggestion, or the current target; with neither the load stays empty: opening never chooses a weight.
    final load = r?.decision == ProgressionDecision.increase ? r!.proposedKg : e.targetLoadKg;
    _load.text = load == null ? '' : formatLoadValue(load, _unit);
    _sets.text = e.targetSets?.toString() ?? '';
    _lo.text = e.targetRepsMin?.toString() ?? '';
    _hi.text = e.targetRepsMax?.toString() ?? '';
  }

  /// The form as a target, or an error in the plan's own rules.
  ({double? loadKg, int? sets, int? lo, int? hi})? _parse() {
    final raw = _load.text.trim();
    final load = raw.isEmpty ? null : typedLoad(raw);
    if (raw.isNotEmpty && (load == null || load <= 0 || loadInputToKg(load, _unit) > 2000)) {
      _error = context.l10n.workoutTargetLoadError;
      return null;
    }
    int? n(TextEditingController c) => c.text.trim().isEmpty ? null : parsePositiveInt(c.text);
    final sets = n(_sets), lo = n(_lo), hi = n(_hi);
    if ((_sets.text.trim().isNotEmpty && (sets == null || sets > 20)) || (_lo.text.trim().isNotEmpty && (lo == null || lo > 100)) ||
        (_hi.text.trim().isNotEmpty && (hi == null || hi > 100)) || (lo != null && hi != null && lo > hi) || ((lo == null) != (hi == null))) {
      _error = context.l10n.workoutTargetRangeError;
      return null;
    }
    _error = null;
    return (loadKg: load == null ? null : ProgressionRules.round3(loadInputToKg(load, _unit)), sets: sets, lo: lo, hi: hi);
  }

  Future<void> _save(TargetSlot slot) async {
    if (_busy) return; // a second tap while saving does nothing
    final v = _parse();
    if (v == null) return setState(() {});
    setState(() => _busy = true);
    final e = slot.exercise;
    try {
      final receipt = await ref.read(planRepositoryProvider).setNextTarget(slot.plan,
          workoutId: slot.definition.id, occurrenceKey: e.occurrenceKey, loadKg: v.loadKg, sets: v.sets, repsMin: v.lo, repsMax: v.hi,
          workouts: ref.read(workoutListProvider), today: ref.read(todayKeyProvider));
      if (receipt != null) {
        await ref.read(progressionRepositoryProvider).rememberAccepted(slot.noteId,
            previous: {'loadKg': e.targetLoadKg, 'sets': e.targetSets, 'repsMin': e.targetRepsMin, 'repsMax': e.targetRepsMax},
            accepted: {'loadKg': v.loadKg, 'sets': v.sets, 'repsMin': v.lo, 'repsMax': v.hi});
      }
      if (mounted) setState(() => _editing = false);
    } on ScheduleRefused catch (x) {
      if (mounted) setState(() => _error = x.message);
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = context.l10n.workoutTargetSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Back to the target the accepted one replaced, only while the plan still holds the accepted one. The plan's
  /// revision check keeps an edit made on another phone from being overwritten (it goes to the sync review).
  Future<void> _restore(TargetSlot slot, Json note) async {
    if (_busy) return;
    final prev = note['previous'] as Json, acc = note['accepted'] as Json;
    setState(() => _busy = true);
    try {
      if (!_holds(slot.exercise, acc)) throw const ScheduleRefused(['TARGET_CHANGED_SINCE']);
      await ref.read(planRepositoryProvider).setNextTarget(slot.plan,
          workoutId: slot.definition.id, occurrenceKey: slot.exercise.occurrenceKey, loadKg: (prev['loadKg'] as num?)?.toDouble(),
          sets: prev['sets'] as int?, repsMin: prev['repsMin'] as int?, repsMax: prev['repsMax'] as int?,
          workouts: ref.read(workoutListProvider), today: ref.read(todayKeyProvider));
      await ref.read(progressionRepositoryProvider).forgetAccepted(slot.noteId);
      if (mounted) Navigator.pop(context);
      if (mounted) toast(context, context.l10n.workoutTargetRestored);
    } on ScheduleRefused catch (x) {
      if (mounted) setState(() => _error = x.message);
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = context.l10n.workoutTargetSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static bool _holds(Prescription e, Json v) =>
      (v['loadKg'] == null ? e.targetLoadKg == null : ProgressionRules.sameLoad(e.targetLoadKg, (v['loadKg'] as num).toDouble())) &&
      e.targetSets == v['sets'] && e.targetRepsMin == v['repsMin'] && e.targetRepsMax == v['repsMax'];

  Widget _field(TextEditingController c, String label, Key key, {bool decimal = false, String? suffix}) => TextField(
        key: key, controller: c, keyboardType: TextInputType.numberWithOptions(decimal: decimal), onChanged: (_) => setState(() {
          _error = null;
          _touched = true;
        }),
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      );

  @override
  Widget build(BuildContext context) {
    final slot = ref.watch(targetSlotProvider(widget.slotKey));
    if (slot == null) {
      return StatusLine(Icons.info_outline, context.l10n.workoutTargetGone);
    }
    final r = ref.watch(progressionProvider(widget.slotKey));
    final unit = ref.watch(loadUnitProvider);
    final from = '$unit|${r?.decision}|${r?.proposedKg}|${slot.exercise.j}';
    if (!_touched && from != _filledFrom) {
      _unit = unit;
      _fill(slot, r);
      _filledFrom = from;
    }
    final e = slot.exercise, c = context.c, l = context.l10n;
    final name = shownName(ref, context, e.catalogKey, e.name);
    final note = ref.watch(progressionNotesProvider).value?[slot.noteId];
    final accepted = note?['accepted'] is Map && note?['previous'] is Map && _holds(e, note!['accepted'] as Json);
    final pending = (ref.watch(plansProvider).value ?? const <Stored<Plan>>[]).where((p) => p.value.id == slot.plan.id).firstOrNull?.isPending ?? false;
    final increment = e.catalogKey == null ? null : ref.watch(incrementsProvider).value?[e.catalogKey]?.value.incrementKg;
    final supported = ProgressionRules.support(e, null) == ProgressionReason.none && r?.decision != ProgressionDecision.unsupported;
    final scope = l.workoutTargetScope(slot.definition.name);

    final head = <Widget>[
      Text('${slot.definition.name} · ${slot.plan.title}', style: context.caption),
      Semantics(header: true, child: Text(name, style: context.pageTitleStyle(26))),
      const SizedBox(height: 6),
      Text(l.workoutReviewCurrent(e.targetLoadKg == null ? l.workoutNoWeightTarget : formatLoad(e.targetLoadKg, _unit), _rx(l, e.targetSets, e.targetRepsMin, e.targetRepsMax)),
          key: const Key('review-current'), style: context.numStyle(15, weight: FontWeight.w500)),
    ];

    if (accepted && !_editing) {
      final prev = note['previous'] as Json;
      return Column(key: const Key('review-accepted'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        ...head,
        const SizedBox(height: 12),
        StatusLine(Icons.check_circle_outline, l.workoutTargetSaved(scope), tone: Tone.success),
        if (pending) Padding(padding: const EdgeInsets.only(top: 6), child: StatusLine(Icons.phone_iphone, l.workoutSyncPending)),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        const SizedBox(height: 14),
        SecondaryButton(l.workoutEditNextTarget, key: const Key('review-edit'), onPressed: () => setState(() {
          _editing = true;
          _touched = false;
          _filledFrom = null;
        })),
        TextButton(
          key: const Key('review-restore'), onPressed: _busy ? null : () => _restore(slot, note),
          child: Text(l.workoutRestorePrevious(prev['loadKg'] == null ? l.workoutNoWeightTarget : formatLoad(prev['loadKg'] as num, _unit))),
        ),
        PrimaryButton(l.actionDone, key: const Key('review-done'), onPressed: () => Navigator.pop(context)),
      ]);
    }

    final v = _parse();
    final changed = v != null && !_holds(e, {'loadKg': v.loadKg, 'sets': v.sets, 'repsMin': v.lo, 'repsMax': v.hi});
    final label = v?.loadKg == null ? l.workoutSaveNextTarget : l.workoutUseLoadFromNext(formatLoad(v!.loadKg, _unit));
    return Column(key: const Key('target-review'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      ...head,
      if (r != null && r.decision != ProgressionDecision.setBaseline) ...[
        const SizedBox(height: 10),
        Text(explainProgression(r, exercise: name, workout: slot.definition.name, unit: _unit, l: l), key: const Key('review-reason'), style: context.sansStyle(14.5)),
      ],
      if (r != null && r.sessions.isNotEmpty) ...[
        const SizedBox(height: 12),
        Overline(l.workoutYourLastSessions),
        for (final s in r.sessions)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l.workoutSessionLine(longDate(s.workout.dayKey), s.sets.isEmpty ? l.workoutNotRecordedLower : [for (final x in s.sets) setText(x, _unit, l)].join(l.workoutListSeparator)),
                style: context.numStyle(14, color: c.secondary, weight: FontWeight.w400)),
          ),
      ],
      const SizedBox(height: 16),
      if (r?.decision == ProgressionDecision.increase) Text(l.workoutSuggestedLine(formatLoad(r!.proposedKg, _unit), formatLoad(r.incrementKg, _unit)), style: context.caption),
      const SizedBox(height: 8),
      _field(_load, l.workoutWeightLabel, const Key('review-load'), decimal: true, suffix: _unit.label),
      if (_load.text.trim().isEmpty && r?.lastLoadKg != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(key: const Key('review-use-last'), icon: const Icon(Icons.history, size: 18), label: Text(l.workoutUseLastRecordedLoad(formatLoad(r!.lastLoadKg, _unit))),
              onPressed: () => setState(() {
                _load.text = formatLoadValue(r.lastLoadKg!, _unit);
                _touched = true;
              })),
        ),
      const SizedBox(height: 8),
      // Side by side; stacked with large text, so no label is cut short.
      if (MediaQuery.textScalerOf(context).scale(10) > 13) ...[
        _field(_sets, l.workoutSetsLabel, const Key('review-sets')),
        const SizedBox(height: 8),
        _field(_lo, l.workoutRepsFrom, const Key('review-reps-min')),
        const SizedBox(height: 8),
        _field(_hi, l.workoutRepsTo, const Key('review-reps-max')),
      ] else
        Row(children: [
          Expanded(child: _field(_sets, l.workoutSetsLabel, const Key('review-sets'))),
          const SizedBox(width: 8),
          Expanded(child: _field(_lo, l.workoutRepsFrom, const Key('review-reps-min'))),
          const SizedBox(width: 8),
          Expanded(child: _field(_hi, l.workoutRepsToShort, const Key('review-reps-max'))),
        ]),
      if (supported) ...[
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(key: const Key('review-increment'), onPressed: () => showIncrementSheet(context, e),
              child: Text(increment == null ? l.workoutChooseIncrement : l.workoutIncrementChange(formatLoad(increment, _unit)))),
        ),
      ],
      const SizedBox(height: 10),
      Text(scope, style: context.caption),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
      const SizedBox(height: 14),
      PrimaryButton(changed ? label : l.workoutNoChangeToSave, key: const Key('review-confirm'), busy: _busy, onPressed: changed ? () => _save(slot) : null),
      TextButton(
        key: const Key('review-keep'),
        onPressed: () async {
          if (r != null && r.actionable && !_editing) await keepCurrentTarget(context, ref, widget.slotKey, r);
          if (context.mounted) Navigator.pop(context);
        },
        child: Text(l.workoutKeepCurrentTarget),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------------------------- increments

/// Choose the weight increment for one exercise: the step its plates, dumbbells or stack allow. Nothing is chosen
/// until the person picks one; it is saved in kilograms and shown in their unit.
Future<void> showIncrementSheet(BuildContext context, Prescription exercise) => showGoSheet<void>(
      context, title: context.l10n.workoutIncrementTitle,
      builder: (_) => _IncrementForm(exercise: exercise),
    );

class _IncrementForm extends ConsumerStatefulWidget {
  const _IncrementForm({required this.exercise});
  final Prescription exercise;
  @override
  ConsumerState<_IncrementForm> createState() => _IncrementFormState();
}

class _IncrementFormState extends ConsumerState<_IncrementForm> {
  final _custom = TextEditingController();
  LoadUnit _unit = LoadUnit.kg;
  double? _picked; // in the display unit
  bool _busy = false;
  String? _error;

  static const _choices = {LoadUnit.kg: [0.5, 1.0, 1.25, 2.0, 2.5, 5.0], LoadUnit.lb: [1.0, 2.5, 5.0, 10.0]};

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _save(double? displayValue) async {
    final key = widget.exercise.catalogKey;
    if (key == null || _busy) return;
    final kg = displayValue == null ? null : loadInputToKg(displayValue, _unit);
    if (kg != null && (kg <= 0 || kg > ProgressionRepository.maxIncrementKg)) {
      return setState(() => _error = context.l10n.workoutIncrementRangeError(formatLoad(ProgressionRepository.maxIncrementKg, _unit)));
    }
    setState(() => _busy = true);
    try {
      await ref.read(progressionRepositoryProvider).setIncrement(key, kg);
      if (mounted) Navigator.pop(context);
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = context.l10n.workoutSaveFailedRetry);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    final unit = ref.watch(loadUnitProvider);
    if (unit != _unit) {
      _unit = unit;
      _picked = null; // a step picked in the other unit is not this one
    }
    final stored = e.catalogKey == null ? null : ref.watch(incrementsProvider).value?[e.catalogKey];
    final caps = ref.watch(compatibilityProvider).capabilities;
    final custom = typedLoad(_custom.text);
    final l = context.l10n, name = shownName(ref, context, e.catalogKey, e.name);
    String step(double v) => withUnit(formatNumber(v), _unit.label);
    final value = _custom.text.trim().isNotEmpty ? custom : _picked;
    return Column(key: const Key('increment-form'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(name, style: context.sansStyle(16, weight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(l.workoutIncrementCaption(name), style: context.caption),
      const SizedBox(height: 6),
      Text(l.workoutIncrementConvention, style: context.caption),
      if (stored?.value.incrementKg != null) ...[
        const SizedBox(height: 10),
        Text(stored!.isPending ? l.workoutIncrementSavedPending(formatLoad(stored.value.incrementKg, _unit)) : l.workoutIncrementSaved(formatLoad(stored.value.incrementKg, _unit)), key: const Key('increment-saved'), style: context.numStyle(15)),
      ],
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final v in _choices[_unit]!)
          ChoiceChip(
            // The key is the number in ASCII, whatever the language shows.
            key: Key('increment-${v == v.roundToDouble() ? v.round() : v}'), label: Text(step(v)), selected: _picked == v && _custom.text.trim().isEmpty,
            onSelected: (_) => setState(() {
              _picked = v;
              _custom.clear();
              _error = null;
            }),
          ),
      ]),
      const SizedBox(height: 8),
      TextField(key: const Key('increment-custom'), controller: _custom, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.workoutIncrementAnother, suffixText: _unit.label), onChanged: (_) => setState(() => _error = null)),
      if (caps != null && !caps.contains(ProgressionRepository.capability))
        Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.phone_iphone, l.workoutIncrementLocalOnly)),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
      const SizedBox(height: 12),
      PrimaryButton(value == null || value <= 0 ? l.workoutChooseStep : l.workoutSaveStep(step(value)), key: const Key('increment-save'), busy: _busy,
          onPressed: value == null || value <= 0 ? null : () => _save(value)),
      if (stored?.value.incrementKg != null)
        TextButton(key: const Key('increment-clear'), onPressed: _busy ? null : () => _save(null), child: Text(l.workoutIncrementRemove)),
    ]);
  }
}

// ---------------------------------------------------------------------------------------------- help

/// How progression works: the actual rules and their limits, and what comes from published guidance and what is
/// GoHard's own choice (docs/PROGRESSION.md › Sources).
Future<void> showProgressionHelp(BuildContext context) => showGoSheet<void>(
      context, title: context.l10n.workoutProgressionHowTitle,
      builder: (sheet) {
        final l = sheet.l10n;
        Widget p(String t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: sheet.sansStyle(15)));
        return Column(key: const Key('progression-help'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          p(l.workoutProgressionHelp1),
          p(l.workoutProgressionHelp2),
          p(l.workoutProgressionHelp3),
          p(l.workoutProgressionHelp4),
          p(l.workoutProgressionHelp5),
          Text(l.workoutProgressionHelpSources, style: sheet.caption),
        ]);
      },
    );
