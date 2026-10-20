import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/compatibility.dart';
import '../../core/format.dart';
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
import 'workout_screen.dart' show setText;

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

String _rx(int? sets, int? lo, int? hi) => targetText(sets: sets, repsMin: lo, repsMax: hi);
String _days(ProgressionResult r) {
  final days = [for (final s in r.sessions.reversed) shortDate(s.workout.dayKey)];
  return days.toSet().length == 1 ? 'both on ${days.first}' : days.join(' and ');
}

/// A short, factual sentence from the result: what was recorded and what follows from it. No claims about readiness.
String explainProgression(ProgressionResult r, {required String exercise, required String workout, required LoadUnit unit}) {
  final target = formatLoad(r.targetKg, unit);
  final top = r.repsMax;
  return switch (r.decision) {
    ProgressionDecision.increase || ProgressionDecision.configureIncrement || ProgressionDecision.incrementTooLarge when r.sessions.length == 2 =>
      'In your last two $workout sessions (${_days(r)}) you recorded all ${r.sets} sets of $exercise at $target with $top or more reps, the top of your ${r.repsMin}–$top range.'
          '${switch (r.decision) {
            ProgressionDecision.configureIncrement => ' Choose the weight increment your equipment allows to see a next target.',
            ProgressionDecision.incrementTooLarge => ' Your increment of ${formatLoad(r.incrementKg, unit)} is more than 5% of that target, so GoHard does not suggest it automatically. You can still review the target yourself.',
            _ => '',
          }}',
    ProgressionDecision.keepCurrent => '${switch (r.sessions.firstWhere((s) => !s.qualifies).reason) {
        ProgressionReason.belowTop => 'A set in one of your last two $workout sessions was below $top reps at $target.',
        ProgressionReason.setsMissing => 'One of your last two $workout sessions has fewer than ${r.sets} sets of $exercise recorded.',
        ProgressionReason.extraSets => 'One of your last two $workout sessions has more than ${r.sets} sets of $exercise, and warm-ups are not marked, so they cannot be compared.',
        ProgressionReason.loadUnknown => 'A set in one of your last two $workout sessions has no load recorded.',
        ProgressionReason.loadDiffers => 'One of your last two $workout sessions used a load other than $target.',
        ProgressionReason.partialWorkout => 'One of your last two $workout sessions was saved as partly completed.',
        _ => 'One of your last two $workout sessions did not include $exercise as planned.',
      }} The target stays at $target.',
    ProgressionDecision.moreSessions => r.reason == ProgressionReason.targetChanged
        ? 'Your target changed since your last $workout session. Two sessions at $target are needed before a step up is considered.'
        : 'Two $workout sessions at $target are needed before a step up is considered; ${r.sessions.where((s) => s.reason != ProgressionReason.targetChanged).length} recorded so far.',
    ProgressionDecision.setBaseline => r.reason == ProgressionReason.noLoadTarget
        ? 'This exercise has no weight target in $workout. Set one if you want sessions compared against it.'
        : 'This exercise has no set count and rep range in $workout to compare against.',
    ProgressionDecision.unsupported => switch (r.reason) {
        ProgressionReason.timed => 'This exercise is timed, so GoHard does not calculate a weight for it. You can set targets yourself.',
        ProgressionReason.bodyweight || ProgressionReason.assisted => 'GoHard does not calculate weights for bodyweight or assisted exercises. You can set targets yourself.',
        _ => 'This exercise is not linked to a saved exercise, so its sessions are not compared.',
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
    final (first, firstResult) = shown.first;
    TargetKey key(Prescription e) => (planId: planId, workoutId: workoutId, occurrenceKey: e.occurrenceKey);
    return Column(key: const Key('next-time'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 22),
      SectionHeader('Next time', trailing: CoachHelpEntry(id: 'progression.next', label: 'About next targets')),
      CoachSpot(
        id: 'progression.next', introduce: true,
        say: CoachSay(
          firstResult.decision == ProgressionDecision.increase
              ? 'You reached the top of your rep range in your last two comparable sessions of ${first.name}. You can review an optional next target.'
              : 'You reached the top of your rep range in your last two comparable sessions of ${first.name}. Tell me your weight increment and I can size a next target.',
          guide: (label: 'How progression works', key: const Key('progression-how'), onPressed: () => showProgressionHelp(context)),
        ),
      ),
      const SizedBox(height: 10),
      _SuggestionCard(slotKey: key(first), result: firstResult, exercise: first, workout: def.name, unit: unit),
      if (shown.length > 1) ...[
        const SizedBox(height: 10),
        GroupCard(children: [
          for (final (e, r) in shown.skip(1))
            GroupRow(
              key: Key('next-time-row-${e.occurrenceKey}'), title: e.name,
              subtitle: r.decision == ProgressionDecision.increase ? '${formatLoad(r.targetKg, unit)} → ${formatLoad(r.proposedKg, unit)} · Review' : 'Choose your weight increment',
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
    final r = result;
    final increase = r.decision == ProgressionDecision.increase;
    return PanelTheme(
      child: Builder(builder: (context) => PanelSurface(
        child: Column(key: Key('next-time-card-${exercise.occurrenceKey}'), crossAxisAlignment: CrossAxisAlignment.start, children: [
          Overline(workout),
          const SizedBox(height: 2),
          Semantics(header: true, child: Text(exercise.name, style: context.pageTitleStyle(24))),
          const SizedBox(height: 8),
          Wrap(spacing: 22, runSpacing: 8, children: [
            _Figure('Current target', formatLoad(r.targetKg, unit)),
            if (increase) _Figure('Proposed', formatLoad(r.proposedKg, unit), valueKey: const Key('next-time-proposed')),
          ]),
          const SizedBox(height: 4),
          Text(_rx(r.sets, r.repsMin, r.repsMax), style: context.numStyle(15, color: context.c.secondary, weight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(explainProgression(r, exercise: exercise.name, workout: workout, unit: unit), style: context.sansStyle(14.5)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            increase
                ? PrimaryButton('Review next target', key: const Key('next-time-review'), expand: false, onPressed: () => showTargetReview(appContext(context), slotKey))
                : PrimaryButton('Choose your weight increment', key: const Key('next-time-increment'), expand: false, onPressed: () => showIncrementSheet(appContext(context), exercise)),
            TextButton(
              key: const Key('next-time-keep'),
              onPressed: () => keepCurrentTarget(appContext(context), ref, slotKey, r),
              child: const Text('Keep current target'),
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
    if (context.mounted) toast(context, 'Kept ${formatLoad(r.targetKg, ref.read(loadUnitProvider))}. Nothing in your plan changed.');
  } on LocalSaveFailure {
    if (context.mounted) toast(context, 'That could not be saved on this phone. Nothing changed; try again.');
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
        Icon(Icons.update, size: 18, color: context.c.secondary),
        Text(load == null ? 'No next weight target' : 'Next target · ${formatLoad(load, unit)}', key: const Key('workout-next-target'),
            style: context.sansStyle(14.5, color: context.c.secondary, weight: FontWeight.w500)),
        QuietLink(load == null ? 'Set a target' : suggested ? 'Review suggestion' : 'Review', key: const Key('workout-next-target-review'),
            said: load == null ? 'Set a next target for ${slot.exercise.name}' : 'Review the next target for ${slot.exercise.name}',
            onPressed: () => showTargetReview(appContext(context), slotKey)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------- review

/// Review next target: the exercise and its workout, the current target, the suggestion (if any) in the person's
/// unit, editable sets and rep range, the sessions behind it and why. Saves only on the explicit confirmation.
Future<void> showTargetReview(BuildContext context, TargetKey key) =>
    showGoSheet<void>(context, title: 'Next target', builder: (_) => _TargetReview(slotKey: key));

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
    final load = raw.isEmpty ? null : parseNonNegative(raw);
    if (raw.isNotEmpty && (load == null || load <= 0 || loadInputToKg(load, _unit) > 2000)) {
      _error = 'Enter a weight above zero, or leave it empty for no weight target.';
      return null;
    }
    int? n(TextEditingController c) => c.text.trim().isEmpty ? null : parsePositiveInt(c.text);
    final sets = n(_sets), lo = n(_lo), hi = n(_hi);
    if ((_sets.text.trim().isNotEmpty && (sets == null || sets > 20)) || (_lo.text.trim().isNotEmpty && (lo == null || lo > 100)) ||
        (_hi.text.trim().isNotEmpty && (hi == null || hi > 100)) || (lo != null && hi != null && lo > hi) || ((lo == null) != (hi == null))) {
      _error = 'Use 1 to 20 sets and a rep range from 1 to 100, the lower number first.';
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
      if (mounted) setState(() => _error = 'It could not be saved on this phone. Nothing changed; try again.');
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
      if (mounted) toast(context, 'Previous target restored.');
    } on ScheduleRefused catch (x) {
      if (mounted) setState(() => _error = x.message);
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = 'It could not be saved on this phone. Nothing changed; try again.');
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
      return const StatusLine(Icons.info_outline, 'This exercise is no longer in that plan workout, so there is no next target to review. Nothing was changed.');
    }
    final r = ref.watch(progressionProvider(widget.slotKey));
    final unit = ref.watch(loadUnitProvider);
    final from = '$unit|${r?.decision}|${r?.proposedKg}|${slot.exercise.j}';
    if (!_touched && from != _filledFrom) {
      _unit = unit;
      _fill(slot, r);
      _filledFrom = from;
    }
    final e = slot.exercise, c = context.c;
    final note = ref.watch(progressionNotesProvider).value?[slot.noteId];
    final accepted = note?['accepted'] is Map && note?['previous'] is Map && _holds(e, note!['accepted'] as Json);
    final pending = (ref.watch(plansProvider).value ?? const <Stored<Plan>>[]).where((p) => p.value.id == slot.plan.id).firstOrNull?.isPending ?? false;
    final increment = e.catalogKey == null ? null : ref.watch(incrementsProvider).value?[e.catalogKey]?.value.incrementKg;
    final supported = ProgressionRules.support(e, null) == ProgressionReason.none && r?.decision != ProgressionDecision.unsupported;
    final scope = 'Applies from the next time you start ${slot.definition.name}, until you change it. Today\'s workout and earlier ones keep what they recorded.';

    final head = <Widget>[
      Text('${slot.definition.name} · ${slot.plan.title}', style: context.caption),
      Semantics(header: true, child: Text(e.name, style: context.pageTitleStyle(26))),
      const SizedBox(height: 6),
      Text('Current target: ${e.targetLoadKg == null ? 'no weight target' : formatLoad(e.targetLoadKg, _unit)} · ${_rx(e.targetSets, e.targetRepsMin, e.targetRepsMax)}',
          key: const Key('review-current'), style: context.numStyle(15, weight: FontWeight.w500)),
    ];

    if (accepted && !_editing) {
      final prev = note['previous'] as Json;
      return Column(key: const Key('review-accepted'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        ...head,
        const SizedBox(height: 12),
        StatusLine(Icons.check_circle_outline, 'Next target saved. $scope', tone: Tone.success),
        if (pending) const Padding(padding: EdgeInsets.only(top: 6), child: StatusLine(Icons.phone_iphone, 'Saved on this phone · sync pending')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
        const SizedBox(height: 14),
        SecondaryButton('Edit next target', key: const Key('review-edit'), onPressed: () => setState(() {
          _editing = true;
          _touched = false;
          _filledFrom = null;
        })),
        TextButton(
          key: const Key('review-restore'), onPressed: _busy ? null : () => _restore(slot, note),
          child: Text('Restore previous target (${prev['loadKg'] == null ? 'no weight target' : formatLoad(prev['loadKg'] as num, _unit)})'),
        ),
        PrimaryButton('Done', key: const Key('review-done'), onPressed: () => Navigator.pop(context)),
      ]);
    }

    final v = _parse();
    final changed = v != null && !_holds(e, {'loadKg': v.loadKg, 'sets': v.sets, 'repsMin': v.lo, 'repsMax': v.hi});
    final label = v?.loadKg == null ? 'Save next target' : 'Use ${formatLoad(v!.loadKg, _unit)} from next session';
    return Column(key: const Key('target-review'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      ...head,
      if (r != null && r.decision != ProgressionDecision.setBaseline) ...[
        const SizedBox(height: 10),
        Text(explainProgression(r, exercise: e.name, workout: slot.definition.name, unit: _unit), key: const Key('review-reason'), style: context.sansStyle(14.5)),
      ],
      if (r != null && r.sessions.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Overline('Your last sessions'),
        for (final s in r.sessions)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${longDate(s.workout.dayKey)}: ${s.sets.isEmpty ? 'not recorded' : [for (final x in s.sets) setText(x, _unit)].join(', ')}',
                style: context.numStyle(14, color: c.secondary, weight: FontWeight.w400)),
          ),
      ],
      const SizedBox(height: 16),
      if (r?.decision == ProgressionDecision.increase) Text('Suggested: ${formatLoad(r!.proposedKg, _unit)}, one increment of ${formatLoad(r.incrementKg, _unit)}. Only the weight is suggested; sets and reps change only if you edit them.', style: context.caption),
      const SizedBox(height: 8),
      _field(_load, 'Weight', const Key('review-load'), decimal: true, suffix: _unit.name),
      if (_load.text.trim().isEmpty && r?.lastLoadKg != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(key: const Key('review-use-last'), icon: const Icon(Icons.history, size: 18), label: Text('Use last recorded load (${formatLoad(r!.lastLoadKg, _unit)})'),
              onPressed: () => setState(() {
                _load.text = formatLoadValue(r.lastLoadKg!, _unit);
                _touched = true;
              })),
        ),
      const SizedBox(height: 8),
      // Side by side; stacked with large text, so no label is cut short.
      if (MediaQuery.textScalerOf(context).scale(10) > 13) ...[
        _field(_sets, 'Sets', const Key('review-sets')),
        const SizedBox(height: 8),
        _field(_lo, 'Reps from', const Key('review-reps-min')),
        const SizedBox(height: 8),
        _field(_hi, 'Reps to', const Key('review-reps-max')),
      ] else
        Row(children: [
          Expanded(child: _field(_sets, 'Sets', const Key('review-sets'))),
          const SizedBox(width: 8),
          Expanded(child: _field(_lo, 'Reps from', const Key('review-reps-min'))),
          const SizedBox(width: 8),
          Expanded(child: _field(_hi, 'to', const Key('review-reps-max'))),
        ]),
      if (supported) ...[
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(key: const Key('review-increment'), onPressed: () => showIncrementSheet(context, e),
              child: Text(increment == null ? 'Choose your weight increment' : 'Weight increment ${formatLoad(increment, _unit)} · Change')),
        ),
      ],
      const SizedBox(height: 10),
      Text(scope, style: context.caption),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
      const SizedBox(height: 14),
      PrimaryButton(changed ? label : 'No change to save', key: const Key('review-confirm'), busy: _busy, onPressed: changed ? () => _save(slot) : null),
      TextButton(
        key: const Key('review-keep'),
        onPressed: () async {
          if (r != null && r.actionable && !_editing) await keepCurrentTarget(context, ref, widget.slotKey, r);
          if (context.mounted) Navigator.pop(context);
        },
        child: const Text('Keep current target'),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------------------------- increments

/// Choose the weight increment for one exercise: the step its plates, dumbbells or stack allow. Nothing is chosen
/// until the person picks one; it is saved in kilograms and shown in their unit.
Future<void> showIncrementSheet(BuildContext context, Prescription exercise) => showGoSheet<void>(
      context, title: 'Weight increment',
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
      return setState(() => _error = 'Enter a step above zero and up to ${formatLoad(ProgressionRepository.maxIncrementKg, _unit)}.');
    }
    setState(() => _busy = true);
    try {
      await ref.read(progressionRepositoryProvider).setIncrement(key, kg);
      if (mounted) Navigator.pop(context);
    } on LocalSaveFailure {
      if (mounted) setState(() => _error = 'It could not be saved on this phone. Try again.');
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
    final custom = parseNonNegative(_custom.text);
    final value = _custom.text.trim().isNotEmpty ? custom : _picked;
    return Column(key: const Key('increment-form'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(e.name, style: context.sansStyle(16, weight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('The step GoHard adds when it suggests a heavier target for ${e.name}, and only then. Pick the smallest increase your plates, '
          'dumbbells or machine allow. Gyms differ, so nothing is chosen for you.', style: context.caption),
      const SizedBox(height: 6),
      Text('GoHard keeps a load exactly as you record it. Use the same convention as your sets: if you record dumbbells per hand, '
          'enter the step per hand; for a barbell, the total change on the bar.', style: context.caption),
      if (stored?.value.incrementKg != null) ...[
        const SizedBox(height: 10),
        Text('Saved: ${formatLoad(stored!.value.incrementKg, _unit)}${stored.isPending ? ' · sync pending' : ''}', key: const Key('increment-saved'), style: context.numStyle(15)),
      ],
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final v in _choices[_unit]!)
          ChoiceChip(
            key: Key('increment-${formatNumber(v)}'), label: Text('${formatNumber(v)} ${_unit.name}'), selected: _picked == v && _custom.text.trim().isEmpty,
            onSelected: (_) => setState(() {
              _picked = v;
              _custom.clear();
              _error = null;
            }),
          ),
      ]),
      const SizedBox(height: 8),
      TextField(key: const Key('increment-custom'), controller: _custom, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Another step', suffixText: _unit.name), onChanged: (_) => setState(() => _error = null)),
      if (caps != null && !caps.contains(ProgressionRepository.capability))
        const Padding(padding: EdgeInsets.only(top: 8), child: StatusLine(Icons.phone_iphone, 'Saved on this phone. Your account\'s server does not keep increments yet; it will sync once the server is updated.')),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
      const SizedBox(height: 12),
      PrimaryButton(value == null || value <= 0 ? 'Choose a step' : 'Save ${formatNumber(value)} ${_unit.name}', key: const Key('increment-save'), busy: _busy,
          onPressed: value == null || value <= 0 ? null : () => _save(value)),
      if (stored?.value.incrementKg != null)
        TextButton(key: const Key('increment-clear'), onPressed: _busy ? null : () => _save(null), child: const Text('Remove this increment')),
    ]);
  }
}

// ---------------------------------------------------------------------------------------------- help

/// How progression works: the actual rules and their limits, and what comes from published guidance and what is
/// GoHard's own choice (docs/PROGRESSION.md › Sources).
Future<void> showProgressionHelp(BuildContext context) => showGoSheet<void>(
      context, title: 'How progression works',
      builder: (sheet) {
        Widget p(String t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: sheet.sansStyle(15)));
        return Column(key: const Key('progression-help'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          p('A target is what you plan to lift. Last time is what you recorded before. Today shows only the sets you actually record. Suggestions never record a set.'),
          p('GoHard looks at your two most recent sessions of the same plan workout. If both have every planned set of an exercise at its target weight, with reps at the top of its range, it suggests the target plus one weight increment that you chose.'),
          p('It never goes further back than those two sessions, never adds sets, changes reps or swaps exercises, and never lowers a weight on its own. Timed, bodyweight and assisted exercises keep manual targets.'),
          p('An increment larger than 5% of the current target is not suggested automatically; you can still set the target yourself. That limit is a GoHard product choice, not a safety threshold.'),
          p('Reps say nothing about effort, form, pain or recovery. A suggestion is optional: review it, edit it or keep your current target. Nothing changes until you confirm.'),
          Text('Published guidance: the 2009 ACSM position stand describes raising the load by about 2–10% once you can do one or two reps more than your target in two consecutive sessions. '
              'The 2026 ACSM position stand advises progressive resistance training, and notes that continued overload matters mainly for longer-term progress. '
              'GoHard\'s rule (the top of your range in your last two sessions, one increment you chose, at most 5%) is its own product choice; neither paper tests or validates it.',
              style: sheet.caption),
        ]);
      },
    );
