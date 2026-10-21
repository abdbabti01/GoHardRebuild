import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/format.dart';
import '../../../core/language.dart';
import '../../../core/units.dart' show asciiDigits;
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/models.dart';
import '../../coach/coach_contract.dart' show CoachFocus;
import '../../coach/guide.dart';
import '../../coach/guide_sheets.dart';
import '../../workout/workout_flow.dart' show PickChip;
import '../plan_actions.dart' show pickDay;
import '../plan_draft.dart';
import '../plan_l10n.dart';
import 'workout_editor.dart';

Widget _label(String text) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 4), child: SectionLabel(text));
Widget _chips(List<Widget> chips) => Wrap(spacing: 6, children: chips);

/// The first names a "Build my own" plan starts with, one per chosen day (up to four): the user renames them.
/// In the app's language (they become the user's own names).
List<String> defaultWorkoutNames(int days) => [for (var i = 0; i < (days.clamp(1, 4)); i++) currentL10n.builderDefaultWorkoutName(String.fromCharCode(65 + i))];

/// Template choice from the "Start from a template" path: whether to copy its starting exercises. Kept in the draft.
bool withExercises(PlanDraft d) => d.j['withExercises'] != false;

/// Leaving Availability lays out the structure for the days chosen: the template (suggested, or the one picked),
/// or the user's first workout names. Workouts already edited are never re-copied, and Guide me waits for the
/// person to choose a starting plan on Structure.
void layOutStructure(PlanDraft d, PlanTemplates templates) {
  if (d.guided && d.templateId == null) return;
  if (d.path == 'template' && d.templateId != 'custom' && d.j['edited'] != true) {
    d.applyTemplate(templates, d.templateId ?? suggestTemplate(d.days.length, experience: d.experience).templateId, withExercises: withExercises(d));
  } else if (d.workouts.isEmpty) {
    d.setCustomStructure(defaultWorkoutNames(d.days.length));
    if (d.title.trim().isEmpty) d.title = currentL10n.planDefaultTitle;
  }
}

/// "Use this starting plan" / choosing a template: a fresh, editable copy in the draft (or the user's own names).
/// Still a draft: nothing is created or activated.
void useTemplate(PlanDraft d, PlanTemplates templates, String id) {
  d.j['edited'] = false;
  if (id == 'custom') {
    d.setCustomStructure(defaultWorkoutNames(d.days.length));
    if (d.title.trim().isEmpty || templates.templates.any((t) => t.name == d.title)) d.title = currentL10n.planDefaultTitle;
  } else {
    d.applyTemplate(templates, id, withExercises: withExercises(d));
  }
}

// ------------------------------------------------------------------ step 1: availability and preferences

class PreferencesStep extends StatefulWidget {
  const PreferencesStep({super.key, required this.draft, required this.change});
  final PlanDraft draft;
  final DraftChange change;
  @override
  State<PreferencesStep> createState() => _PreferencesStepState();
}

class _PreferencesStepState extends State<PreferencesStep> {
  late bool _experience = widget.draft.experience != null || widget.draft.guided;

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final days = d.days;
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(d.guided ? l.builderPrefsGuided : l.builderPrefsIntro, style: context.caption),
      _label(l.builderDaysAWeek),
      _chips([
        for (final n in defaultDays.keys)
          PickChip(key: Key('days-$n'), label: '$n', semanticLabel: l.builderDaysAWeekCount(n), selected: days.length == n, onTap: () => widget.change((d) => d.setPreferences(days: defaultDays[n]))),
      ]),
      _label(l.builderWhichDays),
      _chips([
        for (var wd = 1; wd <= 7; wd++)
          PickChip(
            key: Key('weekday-$wd'), label: weekdayShort(wd), semanticLabel: weekdayName(wd), selected: days.contains(wd),
            onTap: () => widget.change((d) => d.setPreferences(days: days.contains(wd) ? [for (final x in days) if (x != wd) x] : [...days, wd])),
          ),
      ]),
      if (days.isEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: StatusLine(Icons.info_outline, l.builderChooseDay, tone: Tone.warning)),
      _label(l.builderEquipment),
      _chips([
        for (final e in equipmentChoices.entries)
          PickChip(key: Key('equipment-${e.key}'), label: equipmentLabel(l, e.key), selected: d.equipment == e.key, onTap: () => widget.change((d) => d.setPreferences(equipment: e.key))),
      ]),
      _label(l.builderPlannedTime),
      _chips([
        PickChip(key: const Key('budget-none'), label: l.builderNoLimit, selected: d.timeBudgetMinutes == null, onTap: () => widget.change((d) => d.timeBudgetMinutes = null)),
        for (final m in const [30, 45, 60, 75, 90])
          PickChip(key: Key('budget-$m'), label: l.durationMinutes(m), selected: d.timeBudgetMinutes == m, onTap: () => widget.change((d) => d.timeBudgetMinutes = m)),
      ]),
      Text(l.builderPlannedTimeNote, style: context.caption),
      const SizedBox(height: 8),
      if (!_experience)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(key: const Key('experience-show'), onPressed: () => setState(() => _experience = true), icon: const Icon(Icons.add, size: 18), label: Text(l.builderAddExperience)),
        )
      else ...[
        _label(l.builderExperience),
        _chips([
          for (final e in experienceChoices.entries)
            PickChip(
              key: Key('experience-${e.key}'), label: experienceLabel(l, e.key), selected: d.experience == e.key,
              onTap: () => widget.change((d) => d.experience == e.key ? d.setPreferences(clearExperience: true) : d.setPreferences(experience: e.key)),
            ),
        ]),
      ],
    ]);
  }
}

// ------------------------------------------------------------------ step 2: structure and schedule

class StructureStep extends ConsumerStatefulWidget {
  const StructureStep({super.key, required this.draft, required this.change, required this.startLocked, required this.today, this.ask});
  final PlanDraft draft;
  final DraftChange change;

  /// Ask GoHard about a split (from "Why this suggestion?").
  final AskAbout? ask;

  /// An active plan keeps its start date (edit only).
  final bool startLocked;
  final String today;
  @override
  ConsumerState<StructureStep> createState() => _StructureStepState();
}

class _StructureStepState extends ConsumerState<StructureStep> {
  late final _title = TextEditingController(text: widget.draft.title);
  final _names = <String, TextEditingController>{};

  PlanDraft get d => widget.draft;
  DraftChange get change => widget.change;

  @override
  void dispose() {
    _title.dispose();
    for (final c in _names.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _chooseTemplate => d.mode == 'new' && d.path == 'template';
  bool get _nameWorkouts => !_chooseTemplate || d.templateId == 'custom';

  /// Replaces the workouts with a fresh copy of a template (or the user's own names), asking first when the
  /// workouts were already edited.
  Future<void> _pick(PlanTemplates templates, String id, {bool? exercises}) async {
    if (d.j['edited'] == true) {
      final l = context.l10n;
      final now = [for (final w in d.workouts) w.name].join(l.planListComma);
      final next = id == 'custom' ? defaultWorkoutNames(d.days.length).join(l.planListComma) : [for (final w in previewOf(d, templates, id).workouts) w.name].join(l.planListComma);
      if (!await confirm(context, title: l.builderReplaceWorkoutsTitle, action: l.builderReplaceThem,
          body: l.builderReplaceWorkoutsBody(id == 'custom' ? l.builderYourOwnNames : templates.byId(id).name, now, next))) {
        return;
      }
    }
    change((d) {
      if (exercises != null) d.j['withExercises'] = exercises;
      useTemplate(d, templates, id);
    });
    _title.text = d.title;
  }

  /// Guide me: one suggested starting plan and up to two alternatives from the answers, each with a readable week.
  Widget _guide(PlanTemplates templates, CoachGuideContent? guide) {
    final s = guidedSuggestion(d.days.length, d.equipment, experience: d.experience);
    final name = templates.byId(s.templateId).name;
    final chosen = d.workouts.isEmpty ? null : d.templateId;
    final l = context.l10n;
    Widget use(String id, {bool primary = false}) => chosen == id
        ? StatusLine(Icons.check_circle_outline, l.builderUsingStarting, tone: Tone.success)
        : primary
            ? PrimaryButton(l.builderUseStarting, key: Key('guide-use-$id'), onPressed: () => _pick(templates, id))
            : SecondaryButton(l.builderUseStarting, key: Key('guide-use-$id'), onPressed: () => _pick(templates, id));
    // Styles come from the context they are drawn in: the pale panel's ink inside it, the page's outside.
    Widget week(BuildContext context, String id) => Text(weekLine(previewOf(d, templates, id)), style: context.sansStyle(15, weight: FontWeight.w500));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (d.j['edited'] == true && chosen != null && chosen != s.templateId) ...[
        StatusLine(Icons.info_outline, key: const Key('guide-answers-changed'), tone: Tone.warning,
            l.builderAnswersChanged(name)),
        const SizedBox(height: 10),
      ],
      // The suggestion is the step's summary, a pale panel in the Today look. Its sheets open from this page's
      // context (the State's), so they keep the app's look.
      PhotoPanel(
        key: const Key('guide-suggestion'),
        content: (pc) => [
          Overline(l.builderSuggestedStarting),
          const SizedBox(height: 4),
          Semantics(header: true, child: Text(name, style: pc.pageTitleStyle(28))),
          const SizedBox(height: 6),
          Text(s.reason, key: const Key('guide-reason'), style: pc.body),
          _label(l.builderYourWeek),
          week(pc, s.templateId),
          if (guide?.split(s.templateId) case final split?) Padding(padding: const EdgeInsets.only(top: 4), child: Text(split.organisation, style: pc.caption)),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: use(s.templateId, primary: true)),
          const SizedBox(height: 8),
          SecondaryButton(l.builderCompareSplits, key: const Key('guide-compare'), onPressed: guide == null
              ? null
              : () => showCompareSplits(context, guide: guide, templates: templates, draft: d, templateIds: [s.templateId, ...s.alternatives], suggestedId: s.templateId)),
          TextButton.icon(
            key: const Key('guide-why'), icon: const Icon(Icons.help_outline, size: 18), label: Text(l.builderWhySuggestion),
            onPressed: guide == null
                ? null
                : () => showWhySuggestion(context, guide: guide, templateId: s.templateId, name: name, reason: s.reason,
                    onAsk: () => widget.ask?.call(name, CoachFocus.split, templateId: s.templateId)),
          ),
        ],
      ),
      if (s.alternatives.isNotEmpty) _label(l.builderAlsoFits),
      for (final id in s.alternatives)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Panel(
            key: Key('guide-alt-$id'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Heading(templates.byId(id).name, size: 20),
              const SizedBox(height: 4),
              Text(fitLine(templates.byId(id), d.days.length), style: context.caption),
              const SizedBox(height: 6),
              week(context, id),
              const SizedBox(height: 12),
              use(id),
            ]),
          ),
        ),
    ]);
  }

  Future<void> _assignDay(int wd, String? current) async {
    final workouts = d.workouts;
    final chosen = await showGoSheet<String>(context, title: weekdayName(wd), builder: (sheet) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, w) in workouts.indexed)
            ChoiceTile<String>(key: Key('day-assign-$wd-$i'), value: w.id, groupValue: current ?? '', title: w.name, onChanged: (v) => Navigator.pop(sheet, v)),
          ChoiceTile<String>(key: Key('day-assign-$wd-rest'), value: '', groupValue: current ?? '', title: context.l10n.builderRest, subtitle: context.l10n.builderRestSubtitle, onChanged: (v) => Navigator.pop(sheet, v)),
        ]));
    if (chosen != null) change((d) => d.assignDay(wd, chosen.isEmpty ? null : chosen));
  }

  Future<void> _addStep() async {
    final workouts = d.workouts;
    final id = await showGoSheet<String>(context, title: context.l10n.builderAddStep, builder: (sheet) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, w) in workouts.indexed) ListRow(key: Key('cycle-add-$i'), title: w.name, onTap: () => Navigator.pop(sheet, w.id)),
        ]));
    if (id != null) change((d) => d.setCycle([...d.schedule.cycle, id]));
  }

  Future<void> _customWeeks() async {
    final c = TextEditingController(text: d.durationWeeks?.toString() ?? '');
    final l = context.l10n;
    final weeks = await showGoSheet<int>(context, title: l.builderPlanLength, builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
          final v = int.tryParse(asciiDigits(c.text.trim()));
          final ok = v != null && v >= 1 && v <= 52;
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
                key: const Key('duration-custom-field'), controller: c, autofocus: true, keyboardType: TextInputType.number, onChanged: (_) => setSheet(() {}),
                decoration: InputDecoration(labelText: l.builderWeeks, helperText: l.builderWeeksHelper, errorText: c.text.trim().isEmpty || ok ? null : l.builderWeeksError)),
            const SizedBox(height: 10),
            PrimaryButton(l.builderUseLength, key: const Key('duration-custom-save'), onPressed: ok ? () => Navigator.pop(sheet, v) : null),
          ]);
        }));
    c.dispose();
    if (weeks != null) change((d) => d.durationWeeks = weeks);
  }

  TextEditingController _nameFor(WorkoutDefinition w) => _names.putIfAbsent(w.id, () => TextEditingController(text: w.name));

  Widget _templates(PlanTemplates templates) {
    final n = d.days.length;
    final suggestion = suggestTemplate(n, experience: d.experience);
    final l = context.l10n;
    String preview(PlanTemplate t) {
      if (t.isCustom) return l.builderTemplateCustomPreview;
      final names = [for (final k in t.sequenceFor(n)) t.workout(k).name];
      return t.fitsWeekly(n) ? l.builderTemplateWeekly(n, names.join(l.planListComma)) : l.builderTemplateRotates(names.join(l.planSequenceArrow), n);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (d.guided)
        _label(l.builderOtherStartingPoints)
      else ...[
        Panel(
          key: const Key('template-suggestion'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatusLine(Icons.lightbulb_outline, l.builderSuggestedLine(templates.byId(suggestion.templateId).name, suggestionReason(l, n)), tone: Tone.accent),
            const SizedBox(height: 6),
            Text(l.planSplitEvidenceNote, style: context.caption),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      for (final t in templates.templates)
        ChoiceTile<String>(
          key: Key('template-${t.id}'), value: t.id, groupValue: d.templateId ?? '',
          title: t.id == suggestion.templateId ? l.builderTemplateSuggested(t.name) : t.name,
          subtitle: '${t.summary}\n${preview(t)}',
          onChanged: (id) => id == d.templateId ? null : _pick(templates, id),
        ),
      if (d.templateId != null && d.templateId != 'custom') ...[
        Text(templates.byId(d.templateId!).detail, style: context.caption),
        SwitchListTile(
          key: const Key('template-with-exercises'), contentPadding: EdgeInsets.zero, value: withExercises(d),
          onChanged: (v) => _pick(templates, d.templateId!, exercises: v),
          title: Text(l.builderIncludeExercises),
          subtitle: Text(withExercises(d) ? l.builderWithExercisesOn : l.builderWithExercisesOff),
        ),
      ],
    ]);
  }

  Widget _workoutNames() {
    final workouts = d.workouts;
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label(l.builderYourWorkouts),
      Text(l.builderNameOnce, style: context.caption),
      for (final (i, w) in workouts.indexed)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Expanded(
              child: TextField(
                key: Key('custom-workout-name-$i'), controller: _nameFor(w), maxLength: 60, textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l.builderWorkoutN(i + 1), counterText: '', errorText: _nameFor(w).text.trim().isEmpty ? l.builderGiveName : null),
                onChanged: (v) => change((d) => d.renameWorkout(w.id, v)),
              ),
            ),
            IconButton(
              key: Key('custom-workout-remove-$i'), tooltip: l.builderRemoveNamed(w.name.isEmpty ? l.builderWorkoutNLower(i + 1) : w.name), icon: const Icon(Icons.close),
              onPressed: workouts.length == 1
                  ? null
                  : () async {
                      if (w.exercises.isNotEmpty &&
                          !await confirm(context, title: l.builderRemoveTitle(w.name), action: l.actionRemove, destructive: true, body: l.builderRemoveBody)) {
                        return;
                      }
                      change((d) => d.deleteWorkout(w.id), edits: true);
                    },
            ),
          ]),
        ),
      const SizedBox(height: 10),
      SecondaryButton(l.builderAddAWorkout, key: const Key('custom-add-workout'), icon: Icons.add, onPressed: () {
        final name = l.builderDefaultWorkoutName(String.fromCharCode(65 + (workouts.length % 26)));
        change((d) {
          final id = d.addWorkout(name);
          if (d.schedule.isRotating) d.setCycle([...d.schedule.cycle, id]);
        });
      }),
    ]);
  }

  Widget _fixedDays() {
    final byDay = {for (final p in d.schedule.pattern) p.weekday: p.workoutId};
    final names = {for (final w in d.workouts) w.id: w.name};
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label(l.builderYourWeek),
      Text(l.builderFixedNote, style: context.caption),
      const SizedBox(height: 8),
      GroupCard(children: [
        for (var wd = 1; wd <= 7; wd++)
          GroupRow(key: Key('day-assign-$wd'), title: weekdayName(wd), value: byDay[wd] == null ? l.builderRest : names[byDay[wd]] ?? l.builderRest, onTap: () => _assignDay(wd, byDay[wd])),
      ]),
    ]);
  }

  Widget _cycle() {
    final cycle = d.schedule.cycle;
    final names = {for (final w in d.workouts) w.id: w.name};
    final days = d.schedule.trainingDays;
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label(l.builderTheCycle),
      Text(l.builderCycleNote, style: context.caption),
      const SizedBox(height: 8),
      if (cycle.isNotEmpty)
        GroupCard(children: [
          for (final (i, id) in cycle.indexed)
            GroupRow(
              title: '${i + 1}. ${names[id] ?? ''}',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(key: Key('cycle-up-$i'), tooltip: l.builderMoveStepUp(i + 1), icon: const Icon(Icons.arrow_upward, size: 20),
                    onPressed: i == 0 ? null : () => change((d) => d.setCycle([...cycle]..insert(i - 1, cycle[i])..removeAt(i + 1)))),
                IconButton(key: Key('cycle-down-$i'), tooltip: l.builderMoveStepDown(i + 1), icon: const Icon(Icons.arrow_downward, size: 20),
                    onPressed: i == cycle.length - 1 ? null : () => change((d) => d.setCycle([...cycle]..insert(i + 2, cycle[i])..removeAt(i)))),
                IconButton(key: Key('cycle-remove-$i'), tooltip: l.builderRemoveStep(i + 1), icon: const Icon(Icons.close, size: 20),
                    onPressed: cycle.length == 1 ? null : () => change((d) => d.setCycle([...cycle]..removeAt(i)))),
              ]),
            ),
        ]),
      const SizedBox(height: 8),
      SecondaryButton(l.builderAddStep, key: const Key('cycle-add'), icon: Icons.add, onPressed: _addStep),
      _label(l.builderTrainingDays),
      Text(l.builderTrainingDaysNote, style: context.caption),
      _chips([
        for (var wd = 1; wd <= 7; wd++)
          PickChip(
            key: Key('training-day-$wd'), label: weekdayShort(wd), semanticLabel: weekdayName(wd), selected: days.contains(wd),
            onTap: () => change((d) => d.setTrainingDays(days.contains(wd) ? [for (final x in days) if (x != wd) x] : [...days, wd])),
          ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(planTemplatesProvider).value;
    final guide = ref.watch(coachGuideProvider).value;
    final guided = _chooseTemplate && d.guided;
    if (guided && templates == null) return const Center(child: CircularProgressIndicator());
    // Guide me, before a starting plan is chosen: only the suggestion and its alternatives.
    if (guided && d.workouts.isEmpty) return _guide(templates!, guide);
    final rotating = d.schedule.isRotating;
    final weeks = d.durationWeeks;
    const lengths = [4, 6, 8, 12, 16];
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (guided) _guide(templates!, guide),
      if (_chooseTemplate) templates == null ? const Center(child: CircularProgressIndicator()) : _templates(templates),
      if (_nameWorkouts) _workoutNames(),
      _label(l.builderPlanName),
      TextField(
          key: const Key('plan-title'), controller: _title, maxLength: 60, textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.builderName, hintText: l.planDefaultTitle), onChanged: (v) => change((d) => d.title = v)),
      _label(l.builderSchedule),
      Segmented<String>(
        keyPrefix: 'mode', values: const ['fixed', 'rotating'], selected: d.schedule.mode, label: (v) => scheduleModeLabel(l, v),
        onChanged: widget.startLocked ? (_) => toast(context, l.builderModeLocked) : (v) => change((d) => d.setMode(v)),
      ),
      const SizedBox(height: 8),
      Text(l.builderFixedExplain, style: context.caption.copyWith(fontWeight: rotating ? null : FontWeight.w600)),
      const SizedBox(height: 4),
      Text(l.builderRotatingExplain,
          style: context.caption.copyWith(fontWeight: rotating ? FontWeight.w600 : null)),
      if (rotating) _cycle() else _fixedDays(),
      _label(l.builderStartAndLength),
      GroupCard(children: [
        GroupRow(
          key: const Key('plan-start-date'), title: l.builderStarts, value: longDate(d.startDate),
          subtitle: widget.startLocked ? l.builderStartLocked : null,
          onTap: widget.startLocked
              ? null
              : () async {
                  final day = await pickDay(context, initial: d.startDate.compareTo(widget.today) < 0 ? widget.today : d.startDate, first: widget.today, help: l.builderPlanStartsHelp);
                  if (day != null) change((d) => d.startDate = day);
                },
        ),
      ]),
      const SizedBox(height: 8),
      _chips([
        for (final n in lengths) PickChip(key: Key('duration-$n'), label: l.planWeeksPlain(n), selected: weeks == n, onTap: () => change((d) => d.durationWeeks = n)),
        PickChip(key: const Key('duration-custom'), label: weeks != null && !lengths.contains(weeks) ? l.planWeeksCount(weeks) : l.builderOtherLength, selected: weeks != null && !lengths.contains(weeks), onTap: _customWeeks),
        if (rotating) PickChip(key: const Key('duration-ongoing'), label: l.planOngoing, selected: weeks == null, onTap: () => change((d) => d.durationWeeks = null)),
      ]),
      Text(rotating ? l.builderRotationLength : l.builderFixedLength, style: context.caption),
    ]);
  }
}
