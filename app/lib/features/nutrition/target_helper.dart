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
import '../coach/coach_bubble.dart';
import '../coach/coach_prefs.dart';
import '../me/account_repository.dart';
import 'nutrition_surface.dart' show formatKcal;
import 'nutrition_tools.dart' show GoalsEditor;
import 'target_estimate.dart';

/// Help me set my targets (docs/NUTRITION_TARGETS.md), opened from Eat's goals sheet: the goal, a few details, and
/// starting calories and protein the person can edit before Use these targets. Back and Cancel change nothing. Only
/// calories and protein are saved, through [ProfileRepository.setGoals] like the goals form; the answers on step 2 stay
/// on this page and are never stored or sent. A typed weight is not a weigh-in. Pops `true` for "Set targets manually".
class TargetHelperScreen extends ConsumerStatefulWidget {
  const TargetHelperScreen({super.key});
  @override
  ConsumerState<TargetHelperScreen> createState() => _TargetHelperScreenState();
}

class _TargetHelperScreenState extends ConsumerState<TargetHelperScreen> {
  int _step = 0;
  TargetGoal? _goal;

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
    final h = _height(l), w = _weightKg(l, _latest());
    if (h.error != null) errors['height'] = h.error!;
    if (w.error != null) errors['weight'] = w.error!;
    _tried = true;
    _problem = null;
    if (errors.isEmpty && _sex != null && _activity != null) {
      final r = estimateTargets(goal: _goal!, sex: _sex!, activity: _activity!, age: age!, heightCm: h.cm!, weightKg: w.kg!);
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
          // Computed once, here: a later weigh-in never changes what is on step 3.
          _estimate = r.estimate;
          _calories.text = '${r.estimate!.calories}';
          _protein.text = '${r.estimate!.protein}';
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
    final (title, children, primary) = switch (_step) {
      0 => (l.tgtGoalTitle, _goalStep(), PrimaryButton(l.actionContinue, key: const Key('tgt-continue'), onPressed: _goal == null ? null : () => setState(() => _step = 1))),
      1 => (l.tgtAboutTitle, _aboutStep(), PrimaryButton(l.actionContinue, key: const Key('tgt-continue'), onPressed: _estimateNow)),
      _ => (l.tgtResultTitle, _resultStep(), PrimaryButton(l.tgtUse, key: const Key('tgt-use'), busy: _busy, onPressed: _save)),
    };
    return AppPage(
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

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(text, style: context.sansStyle(16, weight: FontWeight.w600)));

  Widget _choose() => Padding(padding: const EdgeInsets.only(bottom: 8), child: StatusLine(Icons.error_outline, context.l10n.tgtChooseOne, tone: Tone.error));

  List<Widget> _goalStep() {
    final l = context.l10n;
    return [
      for (final (g, title, line) in [
        (TargetGoal.maintain, l.tgtGoalMaintain, l.tgtGoalMaintainLine),
        (TargetGoal.lose, l.tgtGoalLose, l.tgtGoalLoseLine),
        (TargetGoal.gain, l.tgtGoalGain, l.tgtGoalGainLine),
        (TargetGoal.recomp, l.tgtGoalRecomp, l.tgtGoalRecompLine),
      ])
        ChoiceTile<TargetGoal?>(key: Key('tgt-goal-${g.name}'), value: g, groupValue: _goal, title: title, subtitle: line, onChanged: (v) => setState(() {
              _goal = v;
              _problem = null;
            })),
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

      _label(l.tgtActivity),
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.tgtActivityHelp, style: context.caption)),
      if (_tried && _activity == null) _choose(),
      for (final (a, title, line) in [
        (ActivityLevel.inactive, l.tgtActInactive, l.tgtActInactiveLine),
        (ActivityLevel.lowActive, l.tgtActLow, l.tgtActLowLine),
        (ActivityLevel.active, l.tgtActActive, l.tgtActActiveLine),
        (ActivityLevel.veryActive, l.tgtActVery, l.tgtActVeryLine),
      ])
        ChoiceTile<ActivityLevel?>(key: Key('tgt-activity-${a.name}'), value: a, groupValue: _activity, title: title, subtitle: line, onChanged: (v) => setState(() => _activity = v)),

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

  List<Widget> _resultStep() {
    final l = context.l10n;
    final e = _estimate!;
    final profile = ref.watch(profileProvider).value;
    final coach = ref.watch(coachPrefsProvider.select((p) => p.onTabs));
    String kcal(int v) => l.eatKcalValue(formatKcal(v));
    String grams(int v) => withUnit(formatGrouped(v), l.eatUnitGram);
    final maintenance = kcal(e.maintenance);
    final floor = kcal(lossFloorKcal[_sex]!);
    final why = switch (_goal!) {
      TargetGoal.maintain => l.tgtWhyMaintain,
      TargetGoal.gain => l.tgtWhyGain(maintenance),
      TargetGoal.recomp => l.tgtWhyRecomp,
      TargetGoal.lose when e.notes.contains(EstimateNote.lossNoRoom) => l.tgtWhyLoseNoRoom(floor),
      TargetGoal.lose when e.notes.contains(EstimateNote.lossAtFloor) => l.tgtWhyLoseFloor(maintenance, floor),
      TargetGoal.lose => l.tgtWhyLose(maintenance),
    };

    Widget target(String key, String label, TextEditingController c, String suffix, String? current, String suggested) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(current == null ? l.tgtSuggested(suggested) : l.tgtCurrentToSuggested(current, suggested), key: Key('$key-compare'), style: context.sansStyle(15, color: context.c.secondary)),
            const SizedBox(height: 6),
            TextField(key: Key(key), controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label, suffixText: suffix)),
          ]),
        );

    return [
      // The guide explains how the numbers were made; the numbers come from the calculator, never from the guide.
      if (coach) CoachSpeaker(key: const Key('tgt-coach'), say: CoachSay(l.tgtCoachSay)) else Text(l.tgtPlainSay, key: const Key('tgt-plain'), style: context.sansStyle(16)),
      target('tgt-calories', l.eatGoalCaloriesLabel, _calories, l.eatUnitKcal, profile?.calorieGoal == null ? null : kcal(profile!.calorieGoal!), kcal(e.calories)),
      target('tgt-protein', l.eatGoalProteinLabel, _protein, l.eatUnitGram, profile?.proteinGoal == null ? null : grams(profile!.proteinGoal!), grams(e.protein)),
      const SizedBox(height: 14),
      Text(why, key: const Key('tgt-why'), style: context.sansStyle(15)),
      if (e.notes.contains(EstimateNote.proteinAtCap)) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.tgtProteinCapped, style: context.caption)),
      const SizedBox(height: 8),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('tgt-macros'),
          tilePadding: EdgeInsets.zero, childrenPadding: const EdgeInsets.only(bottom: 8), expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(l.tgtMacros, style: context.sansStyle(16, weight: FontWeight.w600)),
          children: [
            // Follows the fields: an edited calorie or protein number gives its own carbs and fat.
            ListenableBuilder(
              listenable: Listenable.merge([_calories, _protein]),
              builder: (context, _) {
                final cal = parsePositiveInt(_calories.text, grouping: true), pro = parsePositiveInt(_protein.text, grouping: true);
                final m = cal == null || pro == null ? null : macrosFor(cal, pro);
                String show(int? v) => v == null ? '—' : l.tgtAbout(grams(v));
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (key, name, v) in [('tgt-carbs', l.eatCarbs, m?.$1), ('tgt-fat', l.eatFat, m?.$2)])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
                        Text(name, style: context.sansStyle(15, weight: FontWeight.w600)),
                        Text(show(v), key: Key(key), style: context.numStyle(15)),
                      ]),
                    ),
                ]);
              },
            ),
            const SizedBox(height: 6),
            Text(l.tgtMacroNote, key: const Key('tgt-macro-note'), style: context.caption),
          ],
        ),
      ),
      Text(l.tgtHow, style: context.caption),
      if (_saveError != null) Padding(padding: const EdgeInsets.only(top: 12), child: StatusLine(Icons.error_outline, _saveError!, tone: Tone.error)),
      const SizedBox(height: 8),
      _manualLink(),
    ];
  }
}
