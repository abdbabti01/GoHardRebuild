import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/widgets.dart';
import '../../data/sync.dart' show LocalSaveFailure;
import '../body/body_metrics.dart';
import '../body/body_prefs.dart';
import '../body/body_screens.dart' show BodyProgressScreen;
import '../coach/coach_bubble.dart';
import '../coach/coach_prefs.dart';
import '../me/account_repository.dart';
import 'macro_composition.dart';
import 'nutrient_coverage.dart' show Nutrient;
import 'nutrition_history.dart' show NutritionHistoryScreen;
import 'nutrition_surface.dart' show formatKcal;
import 'nutrition_tools.dart' show GoalsEditor;
import 'target_estimate.dart';

/// The answers an estimate was made from, shown under Details used. Kept apart from the fields so the details always
/// describe the numbers on screen, even while a field is being retyped.
typedef _Used = ({int age, double cm, double kg, LatestValue? latest, EnergySex sex, ActivityLevel activity, BodyUnits units});

/// Help me set my targets (docs/NUTRITION_TARGETS.md), opened from Eat's goals sheet: the goal, a few details, and
/// starting calories and protein the person can edit before Use these targets. Back, Change and Cancel change nothing.
/// Only calories and protein are saved, through [ProfileRepository.setGoals] like the goals form; the answers on step 2
/// stay on this page and are never stored or sent. A typed weight is not a weigh-in. Pops `true` for "Set targets
/// manually".
class TargetHelperScreen extends ConsumerStatefulWidget {
  const TargetHelperScreen({super.key});
  @override
  ConsumerState<TargetHelperScreen> createState() => _TargetHelperScreenState();
}

class _TargetHelperScreenState extends ConsumerState<TargetHelperScreen> {
  int _step = 0;
  TargetGoal? _goal;
  RecompPriority? _priority;

  // Step 2. Units start from Body progress's and can be changed here without changing them there.
  late LoadUnit _mass = ref.read(bodyUnitsProvider).mass;
  late LengthUnit _length = ref.read(bodyUnitsProvider).length;
  final _age = TextEditingController(), _cm = TextEditingController(), _ft = TextEditingController(), _in = TextEditingController(), _weight = TextEditingController();
  bool _otherWeight = false, _tried = false;
  EnergySex? _sex;
  ActivityLevel? _activity;
  Map<String, String> _errors = const {};
  EstimateProblem? _problem;

  // Step 3.
  TargetEstimate? _estimate;
  _Used? _used;
  final _calories = TextEditingController(), _protein = TextEditingController();
  String? _saveError;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_age, _cm, _ft, _in, _weight, _calories, _protein]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The latest weight in Body progress (trusted check-ins only, as Body progress shows it), or null.
  LatestValue? _latest() {
    final rows = ref.watch(metricsProvider).value ?? const [];
    return latestOf([for (final r in rows) if (!r.value.isDeleted && !r.needsReview && hasMeasurement(r.value)) r.value], BodyField.weight);
  }

  void _manual() => Navigator.pop(context, true);

  String _num(double v) => formatNumber(double.parse(v.toStringAsFixed(1)));

  /// A field the person changed from the suggestion it was given.
  static bool _edited(TextEditingController c, int suggested) => parsePositiveInt(c.text, grouping: true) != suggested;

  // ---------------------------------------------------------------------------- reading step 2

  ({double? cm, String? error}) _height(AppLocalizations l) {
    if (_length == LengthUnit.cm) {
      if (_cm.text.trim().isEmpty) return (cm: null, error: l.tgtNeeded);
      final v = parseNonNegative(_cm.text);
      return v == null ? (cm: null, error: l.tgtNotANumber) : (cm: v, error: null);
    }
    if (_ft.text.trim().isEmpty) return (cm: null, error: l.tgtNeeded);
    final ft = parseNonNegative(_ft.text), inches = _in.text.trim().isEmpty ? 0.0 : parseNonNegative(_in.text);
    return ft == null || inches == null ? (cm: null, error: l.tgtNotANumber) : (cm: feetInchesToCm(ft, inches), error: null);
  }

  ({double? kg, String? error}) _weightKg(AppLocalizations l, LatestValue? latest) {
    if (latest != null && !_otherWeight) return (kg: latest.value, error: null);
    if (_weight.text.trim().isEmpty) return (kg: null, error: l.tgtNeeded);
    final v = parseNonNegative(_weight.text);
    return v == null ? (kg: null, error: l.tgtNotANumber) : (kg: loadInputToKg(v, _mass), error: null);
  }

  /// Switching a unit converts what was typed; text that is not a number stays as it is.
  void _setLength(LengthUnit next) {
    if (next == _length) return;
    final cm = _height(context.l10n).cm;
    setState(() {
      _length = next;
      if (cm == null) return;
      if (next == LengthUnit.cm) {
        _cm.text = _num(cm);
      } else {
        final total = double.parse((cm / cmPerInch).toStringAsFixed(1));
        _ft.text = '${total ~/ 12}';
        _in.text = _num(total - 12 * (total ~/ 12));
      }
    });
  }

  void _setMass(LoadUnit next) {
    if (next == _mass) return;
    final v = parseNonNegative(_weight.text);
    setState(() {
      if (v != null) _weight.text = _num(loadKgToDisplay(loadInputToKg(v, _mass), next));
      _mass = next;
    });
  }

  void _estimateNow() {
    final l = context.l10n;
    final errors = <String, String>{};
    final age = parsePositiveInt(_age.text);
    if (_age.text.trim().isEmpty) {
      errors['age'] = l.tgtNeeded;
    } else if (age == null) {
      errors['age'] = l.tgtNotANumber;
    }
    final latest = _latest();
    final h = _height(l), w = _weightKg(l, latest);
    if (h.error != null) errors['height'] = h.error!;
    if (w.error != null) errors['weight'] = w.error!;
    _tried = true;
    _problem = null;
    if (errors.isEmpty && _sex != null && _activity != null) {
      final r = estimateTargets(goal: _goal!, priority: _priority, sex: _sex!, activity: _activity!, age: age!, heightCm: h.cm!, weightKg: w.kg!);
      switch (r.problem) {
        case EstimateProblem.ageRange:
          errors['age'] = l.tgtOutOfRange;
        case EstimateProblem.heightRange:
          errors['height'] = l.tgtOutOfRange;
        case EstimateProblem.weightRange:
          errors['weight'] = l.tgtOutOfRange;
        case EstimateProblem.under19 || EstimateProblem.underweightForLoss:
          _problem = r.problem;
        case null:
          // Computed once, here: a later weigh-in never changes what is on step 3. A number the person edited stays
          // as they typed it (and is shown as theirs); an untouched one follows the new suggestion.
          final e = r.estimate!, before = _estimate;
          if (before == null || !_edited(_calories, before.calories)) _calories.text = '${e.calories}';
          if (before == null || !_edited(_protein, before.protein)) _protein.text = '${e.protein}';
          _estimate = e;
          _used = (age: age, cm: h.cm!, kg: w.kg!, latest: latest != null && !_otherWeight ? latest : null, sex: _sex!, activity: _activity!, units: BodyUnits(_mass, _length));
          _saveError = null;
          _step = 2;
      }
    }
    setState(() => _errors = errors);
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _saveError = null;
    });
    final current = ref.read(profileProvider).value;
    if (current == null) {
      return setState(() {
        _busy = false;
        _saveError = l.eatGoalsSaveFailed;
      });
    }
    try {
      // The goals form's own rules and save: calories and protein only; water and everything else untouched.
      await ref.read(profileRepositoryProvider).setGoals(current,
          calorieGoal: GoalsEditor.whole(_calories.text, l.eatGoalCaloriesWhole), proteinGoal: GoalsEditor.whole(_protein.text, l.eatGoalProteinWhole));
      if (!mounted) return;
      toast(context, l.tgtSaved);
      Navigator.pop(context);
    } on AuthFailure catch (e) {
      setState(() => _saveError = e.message);
    } on LocalSaveFailure {
      setState(() => _saveError = l.eatGoalsSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------- pages

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final back = SecondaryButton(l.tgtBack, key: const Key('tgt-back'), onPressed: () => setState(() => _step--));
    final ready = _goal != null && (_goal != TargetGoal.recomp || _priority != null);
    final (title, children, primary) = switch (_step) {
      0 => (l.tgtGoalTitle, _goalStep(), PrimaryButton(l.actionContinue, key: const Key('tgt-continue'), onPressed: ready ? () => setState(() => _step = 1) : null)),
      1 => (l.tgtAboutTitle, _aboutStep(), PrimaryButton(l.actionContinue, key: const Key('tgt-continue'), onPressed: _estimateNow)),
      _ => (l.tgtResultTitle, _resultStep(), PrimaryButton(l.tgtUse, key: const Key('tgt-use'), busy: _busy, onPressed: _save)),
    };
    return AppPage(
      // One page per step: each opens at its top, with its title clear of the app bar, rather than keeping the
      // previous step's scroll position.
      key: ValueKey(_step),
      title: title,
      subtitle: l.tgtStep(_step + 1),
      actions: [TextButton(key: const Key('tgt-cancel'), onPressed: () => Navigator.pop(context), child: Text(l.actionCancel))],
      bottom: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        primary,
        if (_step > 0) ...[const SizedBox(height: 8), back],
      ]),
      children: children,
    );
  }

  Widget _manualLink([String? text]) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: QuietLink(text ?? context.l10n.tgtManual, key: Key(text == null ? 'tgt-manual-$_step' : 'tgt-sex-skip'), onPressed: _manual));

  Widget _label(String text) =>
      Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Semantics(header: true, child: Text(text, style: context.sansStyle(16, weight: FontWeight.w600))));

  Widget _choose() => Padding(padding: const EdgeInsets.only(bottom: 8), child: StatusLine(Icons.error_outline, context.l10n.tgtChooseOne, tone: Tone.error));

  String _goalName(AppLocalizations l, TargetGoal g) => switch (g) {
        TargetGoal.maintain => l.tgtGoalMaintain,
        TargetGoal.lose => l.tgtGoalLose,
        TargetGoal.gain => l.tgtGoalGain,
        TargetGoal.recomp => l.tgtGoalRecomp,
      };

  String _priorityName(AppLocalizations l, RecompPriority p) => p == RecompPriority.steady ? l.tgtPrioritySteady : l.tgtPriorityFatLoss;

  String _activityName(AppLocalizations l, ActivityLevel a) => switch (a) {
        ActivityLevel.inactive => l.tgtActInactive,
        ActivityLevel.lowActive => l.tgtActLow,
        ActivityLevel.active => l.tgtActActive,
        ActivityLevel.veryActive => l.tgtActVery,
      };

  List<Widget> _goalStep() {
    final l = context.l10n;
    return [
      for (final (g, line) in [
        (TargetGoal.maintain, l.tgtGoalMaintainLine),
        (TargetGoal.lose, l.tgtGoalLoseLine),
        (TargetGoal.gain, l.tgtGoalGainLine),
        (TargetGoal.recomp, l.tgtGoalRecompLine),
      ])
        ChoiceTile<TargetGoal?>(key: Key('tgt-goal-${g.name}'), value: g, groupValue: _goal, title: _goalName(l, g), subtitle: line, onChanged: (v) => setState(() {
              _goal = v;
              _problem = null;
            })),
      // Recomposition has a real trade-off, so the person chooses it; nothing is picked for them.
      if (_goal == TargetGoal.recomp) ...[
        _label(l.tgtPriorityTitle),
        for (final (p, line) in [(RecompPriority.steady, l.tgtPrioritySteadyLine), (RecompPriority.fatLoss, l.tgtPriorityFatLossLine)])
          ChoiceTile<RecompPriority?>(key: Key('tgt-priority-${p.name}'), value: p, groupValue: _priority, title: _priorityName(l, p), subtitle: line, onChanged: (v) => setState(() {
                _priority = v;
                _problem = null;
              })),
      ],
      const SizedBox(height: 8),
      _manualLink(),
    ];
  }

  List<Widget> _aboutStep() {
    final l = context.l10n;
    final latest = _latest();
    final units = BodyUnits(_mass, _length);
    TextField field(String key, String error, TextEditingController c, String label, {String? suffix, String? helper, TextInputType type = const TextInputType.numberWithOptions(decimal: true)}) => TextField(
        key: Key(key), controller: c, keyboardType: type, textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label, suffixText: suffix, helperText: helper, helperMaxLines: 3, errorMaxLines: 3, errorText: _errors[error]));
    return [
      Text(l.tgtAboutIntro, style: context.sansStyle(15, color: context.c.secondary)),
      const SizedBox(height: 16),
      field('tgt-age', 'age', _age, l.tgtAge, suffix: l.tgtYears, type: TextInputType.number),

      _label(l.tgtHeight),
      Segmented<LengthUnit>(values: LengthUnit.values, selected: _length, keyPrefix: 'tgt-height-unit', label: (u) => u == LengthUnit.cm ? l.bodyUnitCm : l.tgtUnitFeetInches, onChanged: _setLength),
      const SizedBox(height: 10),
      if (_length == LengthUnit.cm)
        field('tgt-height-cm', 'height', _cm, l.tgtHeight, suffix: l.bodyUnitCm)
      else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: field('tgt-height-ft', 'height', _ft, l.tgtHeight, suffix: l.tgtFeet, type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: TextField(key: const Key('tgt-height-in'), controller: _in, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(suffixText: l.bodyUnitIn))),
        ]),

      _label(l.tgtWeight),
      Segmented<LoadUnit>(values: LoadUnit.values, selected: _mass, keyPrefix: 'tgt-weight-unit', label: (u) => u.label, onChanged: _setMass),
      const SizedBox(height: 10),
      if (latest != null && !_otherWeight)
        Panel(
          key: const Key('tgt-latest'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.tgtLatestWeighIn, style: context.sansStyle(15, color: context.c.secondary)),
            Text(units.value(BodyField.weight, latest.value), key: const Key('tgt-latest-weight'), style: context.pageTitleStyle(28)),
            Text(latest.averaged ? l.bodyAverageOfEntries(latest.count, dayMonth(latest.dayKey)) : l.bodyRecordedOn(dayMonth(latest.dayKey)),
                key: const Key('tgt-latest-date'), style: context.sansStyle(15, color: context.c.secondary)),
            TextButton(key: const Key('tgt-other-weight'), onPressed: () => setState(() => _otherWeight = true), child: Text(l.tgtUseOtherWeight)),
          ]),
        )
      else ...[
        field('tgt-weight', 'weight', _weight, l.tgtWeight, suffix: _mass.label, helper: l.tgtWeightOnlyHere),
        if (latest != null)
          Align(alignment: AlignmentDirectional.centerStart,
              child: TextButton(key: const Key('tgt-latest-weight-use'), onPressed: () => setState(() => _otherWeight = false), child: Text(l.tgtUseLatestWeight))),
      ],

      _label(l.tgtSex),
      if (_tried && _sex == null) _choose(),
      for (final (s, name) in [(EnergySex.female, l.tgtFemale), (EnergySex.male, l.tgtMale)])
        ChoiceTile<EnergySex?>(key: Key('tgt-sex-${s.name}'), value: s, groupValue: _sex, title: name, onChanged: (v) => setState(() => _sex = v)),
      Text(l.tgtSexWhy, style: context.caption),
      _manualLink(l.tgtSexSkip),

      // One question for the whole usual week (work, getting around and workouts), so exercise is never added twice.
      _label(l.tgtActivity),
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.tgtActivityHelp, key: const Key('tgt-activity-help'), style: context.caption)),
      if (_tried && _activity == null) _choose(),
      for (final (a, line) in [
        (ActivityLevel.inactive, l.tgtActInactiveLine),
        (ActivityLevel.lowActive, l.tgtActLowLine),
        (ActivityLevel.active, l.tgtActActiveLine),
        (ActivityLevel.veryActive, l.tgtActVeryLine),
      ])
        ChoiceTile<ActivityLevel?>(key: Key('tgt-activity-${a.name}'), value: a, groupValue: _activity, title: _activityName(l, a), subtitle: line, onChanged: (v) => setState(() => _activity = v)),

      const SizedBox(height: 8),
      Text(l.tgtScope, style: context.caption),
      if (_problem != null) ...[
        const SizedBox(height: 14),
        Panel(
          key: const Key('tgt-problem'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatusLine(Icons.info_outline, _problem == EstimateProblem.under19 ? l.tgtUnder19 : l.tgtUnderweight),
            const SizedBox(height: 8),
            PrimaryButton(l.tgtManual, key: const Key('tgt-problem-manual'), onPressed: _manual),
          ]),
        ),
      ] else
        _manualLink(),
    ];
  }

  /// A label and its value on one line, wrapping under each other when there is no room; read as one item.
  Widget _row(String key, String label, String value, {bool strong = false, String? note}) => MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
              Text(label, style: context.sansStyle(15, weight: strong ? FontWeight.w600 : FontWeight.w400)),
              Text(value, key: Key(key), style: context.numStyle(15).copyWith(fontWeight: strong ? FontWeight.w700 : null)),
            ]),
            if (note != null) Text(note, key: Key('$key-note'), style: context.caption),
          ]),
        ),
      );

  Widget _section(String key, String title, List<Widget> children) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: Key(key),
          tilePadding: EdgeInsets.zero, childrenPadding: const EdgeInsets.only(bottom: 8), expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          title: Text(title, style: context.sansStyle(16, weight: FontWeight.w600)),
          children: children,
        ),
      );

  List<Widget> _resultStep() {
    final l = context.l10n;
    final e = _estimate!, u = _used!, goal = _goal!;
    final profile = ref.watch(profileProvider).value;
    final coach = ref.watch(coachPrefsProvider.select((p) => p.onTabs));
    String kcal(int v) => l.eatKcalValue(formatKcal(v));
    String grams(int v) => withUnit(formatGrouped(v), l.eatUnitGram);
    final floor = kcal(lossFloorKcal[u.sex]!);
    final approach = switch (goal) {
      TargetGoal.maintain => l.tgtApproachMaintain,
      TargetGoal.gain => l.tgtApproachGain,
      TargetGoal.lose => l.tgtApproachLose,
      TargetGoal.recomp => _priority == RecompPriority.steady ? l.tgtApproachRecompSteady : l.tgtApproachRecompFatLoss,
    };
    final adjustment = switch (e.adjustment) { 0 => l.tgtAdjustNone, < 0 => l.tgtAdjustLess(kcal(-e.adjustment)), _ => l.tgtAdjustMore(kcal(e.adjustment)) };
    final calorieNote = e.notes.contains(EstimateNote.lossNoRoom)
        ? l.tgtNoteNoRoom(floor)
        : e.notes.contains(EstimateNote.lossAtFloor)
            ? l.tgtNoteFloor(floor)
            : null;

    Widget target(String key, String label, TextEditingController c, String suffix, int suggested, int? saved, String Function(int) show) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(key: Key(key), controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label, suffixText: suffix)),
            // Whose number this is: the suggestion, or the person's own edit (with the way back to the suggestion).
            ListenableBuilder(
              listenable: c,
              builder: (context, _) {
                final edited = _edited(c, suggested);
                final status = [edited ? l.tgtEdited(show(suggested)) : l.tgtSuggestedEstimate, if (saved != null) l.tgtCurrently(show(saved))].join(' · ');
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                    Text(status, key: Key('$key-status'), style: context.caption),
                    if (edited) TextButton(key: Key('$key-reset'), onPressed: () => c.text = '$suggested', child: Text(l.tgtUseSuggestion)),
                  ]),
                );
              },
            ),
          ]),
        );

    final height = u.units.length == LengthUnit.cm
        ? withUnit(formatGrouped(u.cm), l.bodyUnitCm)
        : () {
            final inches = double.parse((u.cm / cmPerInch).toStringAsFixed(1));
            return '${withUnit(formatGrouped(inches ~/ 12), l.tgtFeet)} ${withUnit(formatGrouped(inches - 12 * (inches ~/ 12)), l.bodyUnitIn)}';
          }();
    final latest = u.latest;
    final weightSource = latest == null ? l.tgtWeightEntered : latest.averaged ? l.bodyAverageOfEntries(latest.count, dayMonth(latest.dayKey)) : l.tgtWeightLatest(dayMonth(latest.dayKey));

    // In running text a number keeps its unit on the same line.
    String keep(String v) => v.replaceAll(' ', '\u00A0');
    final (sayM, sayC, sayP) = (keep(kcal(e.maintenance)), keep(kcal(e.calories)), keep(grams(e.protein)));

    return [
      // The guide explains this calculation; its numbers come from the calculator, never from the guide.
      if (coach)
        CoachSpeaker(key: const Key('tgt-coach'), say: CoachSay(l.tgtCoachSay(sayM, sayC, sayP)))
      else
        Text(l.tgtPlainSay(sayM, sayC, sayP), key: const Key('tgt-plain'), style: context.sansStyle(16)),
      const SizedBox(height: 14),

      // 1–2. The goal, with the way to change it, and the approach in one sentence.
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: MergeSemantics(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Overline(l.tgtYourGoal),
              Text(_goalName(l, goal), key: const Key('tgt-goal-name'), style: context.sansStyle(18, weight: FontWeight.w600)),
              if (goal == TargetGoal.recomp) Text(_priorityName(l, _priority!), key: const Key('tgt-goal-priority'), style: context.sansStyle(15, color: context.c.secondary)),
            ]),
          ),
        ),
        TextButton(key: const Key('tgt-change-goal'), onPressed: () => setState(() => _step = 0), child: Text(l.tgtChange, semanticsLabel: l.tgtChangeGoalSaid)),
      ]),
      const SizedBox(height: 6),
      Text(approach, key: const Key('tgt-approach'), style: context.sansStyle(15)),

      // 3. What is saved, editable.
      target('tgt-calories', l.eatGoalCaloriesLabel, _calories, l.eatUnitKcal, e.calories, profile?.calorieGoal, kcal),
      target('tgt-protein', l.eatGoalProteinLabel, _protein, l.eatUnitGram, e.protein, profile?.proteinGoal, grams),
      Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.tgtSavesOnly, key: const Key('tgt-saves'), style: context.caption)),
      const SizedBox(height: 14),

      // 4. Maintenance → adjustment → target, exactly as calculated.
      Panel(
        key: const Key('tgt-math'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _row('tgt-maintenance', l.tgtMaintenanceRow, kcal(e.maintenance)),
          _row('tgt-adjustment', l.tgtAdjustmentRow, adjustment, note: calorieNote),
          _row('tgt-target', l.tgtTargetRow, kcal(e.calories), strong: true),
          const Divider(height: 16),
          _row('tgt-protein-math', l.tgtProteinRow(formatGrouped(e.proteinPerKg), u.units.value(BodyField.weight, u.kg)), grams(e.protein),
              strong: true, note: e.notes.contains(EstimateNote.proteinAtCap) ? l.tgtProteinCapped : null),
          const SizedBox(height: 4),
          Text(l.tgtRounding, key: const Key('tgt-rounding'), style: context.caption),
        ]),
      ),
      const SizedBox(height: 6),

      // 5. Details used.
      _section('tgt-details', l.tgtDetailsTitle, [
        _row('tgt-used-age', l.tgtAge, withUnit(formatGrouped(u.age), l.tgtYears)),
        _row('tgt-used-height', l.tgtHeight, height),
        _row('tgt-used-weight', l.tgtWeight, u.units.value(BodyField.weight, u.kg), note: weightSource),
        _row('tgt-used-sex', l.tgtSexUsed, u.sex == EnergySex.female ? l.tgtFemale : l.tgtMale),
        _row('tgt-used-activity', l.tgtActivityUsed, _activityName(l, u.activity)),
        Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(key: const Key('tgt-change-details'), onPressed: () => setState(() => _step = 1), child: Text(l.tgtChangeDetails))),
      ]),

      // The estimated split, display only, following the edited fields: a hypothetical day at these targets, never
      // anything logged (Eat's recorded composition is a separate chart). Protein is the field as typed; carbs and fat
      // are rounded estimates.
      _section('tgt-macros', l.tgtMacros, [
        ListenableBuilder(
          listenable: Listenable.merge([_calories, _protein]),
          builder: (context, _) {
            final cal = parsePositiveInt(_calories.text, grouping: true), pro = parsePositiveInt(_protein.text, grouping: true);
            final m = cal == null || pro == null ? null : macrosFor(cal, pro);
            final split = MacroComposition({Nutrient.protein: pro?.toDouble(), Nutrient.carbs: m?.carbs.toDouble(), Nutrient.fat: m?.fat.toDouble()});
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              MacroDonut(split, title: l.nrMacroTargetTitle, keyPrefix: 'tgt', amount: (n, g) => n == Nutrient.protein ? grams(g.round()) : l.tgtAbout(grams(g.round())),
                  notes: [if (split.percents != null) l.nrMacroBasis(formatKcal(split.kcal))]),
              if (m != null && m.over) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.tgtMacroOver, key: const Key('tgt-macro-over'), style: context.caption)),
            ]);
          },
        ),
        const SizedBox(height: 6),
        Text(l.tgtMacroNote, key: const Key('tgt-macro-note'), style: context.caption),
      ]),

      // 6. Method, sources and limits.
      _section('tgt-how', l.tgtHowTitle, [
        for (final (i, t) in [l.tgtHowMethod, l.tgtHowGoal, l.tgtHowLimits].indexed)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, key: Key('tgt-how-$i'), style: context.sansStyle(15))),
      ]),

      // Checking the start: where to look, what logs can and can't show. Nothing here changes a target.
      _section('tgt-check', l.tgtCheckTitle, [
        for (final (i, t) in [l.tgtCheckTrend, l.tgtCheckLogs, l.tgtCheckScale, l.tgtCheckManual].indexed)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('•  $t', key: Key('tgt-check-$i'), style: context.sansStyle(15))),
        Wrap(spacing: 8, children: [
          QuietLink(l.bodyTitle, key: const Key('tgt-open-body'), onPressed: () => push<void>(context, const BodyProgressScreen())),
          QuietLink(l.eatHistoryTrends, key: const Key('tgt-open-history'), onPressed: () => push<String>(context, NutritionHistoryScreen(selected: ref.read(todayKeyProvider)))),
        ]),
      ]),

      if (_saveError != null) Padding(padding: const EdgeInsets.only(top: 12), child: StatusLine(Icons.error_outline, _saveError!, tone: Tone.error)),
      const SizedBox(height: 8),
      _manualLink(),
    ];
  }
}
