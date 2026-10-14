import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/models.dart';
import '../../workout/workout_flow.dart' show PickChip;
import '../plan_actions.dart' show pickDay;
import '../plan_draft.dart';
import 'workout_editor.dart';

Widget _label(String text) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 4), child: SectionLabel(text));
Widget _chips(List<Widget> chips) => Wrap(spacing: 6, children: chips);

/// The first names a "Build my own" plan starts with, one per chosen day (up to four): the user renames them.
List<String> defaultWorkoutNames(int days) => [for (var i = 0; i < (days.clamp(1, 4)); i++) 'Workout ${String.fromCharCode(65 + i)}'];

/// Template choice from the "Start from a template" path: whether to copy its starting exercises. Kept in the draft.
bool withExercises(PlanDraft d) => d.j['withExercises'] != false;

// ------------------------------------------------------------------ step 1: availability and preferences

class PreferencesStep extends StatefulWidget {
  const PreferencesStep({super.key, required this.draft, required this.change});
  final PlanDraft draft;
  final DraftChange change;
  @override
  State<PreferencesStep> createState() => _PreferencesStepState();
}

class _PreferencesStepState extends State<PreferencesStep> {
  late bool _experience = widget.draft.experience != null;

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final days = d.days;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('A few answers to suggest a starting point. You can change everything later.', style: context.caption),
      _label('Days a week'),
      _chips([
        for (final n in defaultDays.keys)
          PickChip(key: Key('days-$n'), label: '$n', semanticLabel: '$n days a week', selected: days.length == n, onTap: () => widget.change((d) => d.setPreferences(days: defaultDays[n]))),
      ]),
      _label('Which days'),
      _chips([
        for (var wd = 1; wd <= 7; wd++)
          PickChip(
            key: Key('weekday-$wd'), label: weekdayShort(wd), semanticLabel: weekdayName(wd), selected: days.contains(wd),
            onTap: () => widget.change((d) => d.setPreferences(days: days.contains(wd) ? [for (final x in days) if (x != wd) x] : [...days, wd])),
          ),
      ]),
      if (days.isEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: StatusLine(Icons.info_outline, 'Choose at least one day.', tone: Tone.warning)),
      _label('Equipment'),
      _chips([
        for (final e in equipmentChoices.entries)
          PickChip(key: Key('equipment-${e.key}'), label: e.value, selected: d.equipment == e.key, onTap: () => widget.change((d) => d.setPreferences(equipment: e.key))),
      ]),
      _label('Planned time per workout (optional)'),
      _chips([
        PickChip(key: const Key('budget-none'), label: 'No limit', selected: d.timeBudgetMinutes == null, onTap: () => widget.change((d) => d.timeBudgetMinutes = null)),
        for (final m in const [30, 45, 60, 75, 90])
          PickChip(key: Key('budget-$m'), label: '$m min', selected: d.timeBudgetMinutes == m, onTap: () => widget.change((d) => d.timeBudgetMinutes = m)),
      ]),
      Text('The time you plan to spend. It is your choice, not a calculated length of the workout.', style: context.caption),
      const SizedBox(height: 8),
      if (!_experience)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(key: const Key('experience-show'), onPressed: () => setState(() => _experience = true), icon: const Icon(Icons.add, size: 18), label: const Text('Add your training experience (optional)')),
        )
      else ...[
        _label('Training experience (optional)'),
        _chips([
          for (final e in experienceChoices.entries)
            PickChip(
              key: Key('experience-${e.key}'), label: e.value, selected: d.experience == e.key,
              onTap: () => widget.change((d) => d.experience == e.key ? d.setPreferences(clearExperience: true) : d.setPreferences(experience: e.key)),
            ),
        ]),
      ],
    ]);
  }
}

// ------------------------------------------------------------------ step 2: structure and schedule

class StructureStep extends ConsumerStatefulWidget {
  const StructureStep({super.key, required this.draft, required this.change, required this.startLocked, required this.today});
  final PlanDraft draft;
  final DraftChange change;

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
    if (d.j['edited'] == true &&
        !await confirm(context, title: 'Replace your workouts?', action: 'Replace them',
            body: 'This starts the workouts again from ${id == 'custom' ? 'your own names' : templates.byId(id).name}. Changes you made to the exercises are not kept.')) {
      return;
    }
    change((d) {
      if (exercises != null) d.j['withExercises'] = exercises;
      d.j['edited'] = false;
      if (id == 'custom') {
        d.setCustomStructure(defaultWorkoutNames(d.days.length));
        if (d.title.trim().isEmpty || templates.templates.any((t) => t.name == d.title)) d.title = 'My plan';
      } else {
        d.applyTemplate(templates, id, withExercises: withExercises(d));
      }
    });
    _title.text = d.title;
  }

  Future<void> _assignDay(int wd, String? current) async {
    final workouts = d.workouts;
    final chosen = await showGoSheet<String>(context, title: weekdayName(wd), builder: (sheet) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, w) in workouts.indexed)
            ChoiceTile<String>(key: Key('day-assign-$wd-$i'), value: w.id, groupValue: current ?? '', title: w.name, onChanged: (v) => Navigator.pop(sheet, v)),
          ChoiceTile<String>(key: Key('day-assign-$wd-rest'), value: '', groupValue: current ?? '', title: 'Rest', subtitle: 'No workout on this day', onChanged: (v) => Navigator.pop(sheet, v)),
        ]));
    if (chosen != null) change((d) => d.assignDay(wd, chosen.isEmpty ? null : chosen));
  }

  Future<void> _addStep() async {
    final workouts = d.workouts;
    final id = await showGoSheet<String>(context, title: 'Add a step', builder: (sheet) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, w) in workouts.indexed) ListRow(key: Key('cycle-add-$i'), title: w.name, onTap: () => Navigator.pop(sheet, w.id)),
        ]));
    if (id != null) change((d) => d.setCycle([...d.schedule.cycle, id]));
  }

  Future<void> _customWeeks() async {
    final c = TextEditingController(text: d.durationWeeks?.toString() ?? '');
    final weeks = await showGoSheet<int>(context, title: 'Plan length', builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
          final v = int.tryParse(c.text.trim());
          final ok = v != null && v >= 1 && v <= 52;
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
                key: const Key('duration-custom-field'), controller: c, autofocus: true, keyboardType: TextInputType.number, onChanged: (_) => setSheet(() {}),
                decoration: InputDecoration(labelText: 'Weeks', helperText: '1 to 52 weeks', errorText: c.text.trim().isEmpty || ok ? null : 'Choose 1 to 52 weeks.')),
            const SizedBox(height: 10),
            PrimaryButton('Use this length', key: const Key('duration-custom-save'), onPressed: ok ? () => Navigator.pop(sheet, v) : null),
          ]);
        }));
    c.dispose();
    if (weeks != null) change((d) => d.durationWeeks = weeks);
  }

  TextEditingController _nameFor(WorkoutDefinition w) => _names.putIfAbsent(w.id, () => TextEditingController(text: w.name));

  Widget _templates(PlanTemplates templates) {
    final n = d.days.length;
    final suggestion = suggestTemplate(n, experience: d.experience);
    String preview(PlanTemplate t) {
      if (t.isCustom) return 'Name your own workouts and choose their days.';
      final names = [for (final k in t.sequenceFor(n)) t.workout(k).name];
      return t.fitsWeekly(n) ? 'Your $n days: ${names.join(', ')}' : 'Rotates ${names.join(' → ')} over your $n days';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        key: const Key('template-suggestion'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusLine(Icons.lightbulb_outline, 'Suggested: ${templates.byId(suggestion.templateId).name}. ${suggestion.reason}', tone: Tone.accent),
          const SizedBox(height: 6),
          Text(splitEvidenceNote, style: context.caption),
        ]),
      ),
      const SizedBox(height: 12),
      for (final t in templates.templates)
        ChoiceTile<String>(
          key: Key('template-${t.id}'), value: t.id, groupValue: d.templateId ?? '',
          title: t.id == suggestion.templateId ? '${t.name} · Suggested' : t.name,
          subtitle: '${t.summary}\n${preview(t)}',
          onChanged: (id) => id == d.templateId ? null : _pick(templates, id),
        ),
      if (d.templateId != null && d.templateId != 'custom') ...[
        Text(templates.byId(d.templateId!).detail, style: context.caption),
        SwitchListTile(
          key: const Key('template-with-exercises'), contentPadding: EdgeInsets.zero, value: withExercises(d),
          onChanged: (v) => _pick(templates, d.templateId!, exercises: v),
          title: const Text('Include starting exercises'),
          subtitle: Text(withExercises(d)
              ? 'A starting routine with sets, reps and rest and no weights. Change anything in the next step.'
              : 'Workouts start empty. The plan stays a draft until every scheduled workout has an exercise.'),
        ),
      ],
    ]);
  }

  Widget _workoutNames() {
    final workouts = d.workouts;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label('Your workouts'),
      Text('Name each different workout once. A workout can repeat on several days.', style: context.caption),
      for (final (i, w) in workouts.indexed)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Expanded(
              child: TextField(
                key: Key('custom-workout-name-$i'), controller: _nameFor(w), maxLength: 60, textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Workout ${i + 1}', counterText: '', errorText: _nameFor(w).text.trim().isEmpty ? 'Give it a name.' : null),
                onChanged: (v) => change((d) => d.renameWorkout(w.id, v)),
              ),
            ),
            IconButton(
              key: Key('custom-workout-remove-$i'), tooltip: 'Remove ${w.name.isEmpty ? 'workout ${i + 1}' : w.name}', icon: const Icon(Icons.close),
              onPressed: workouts.length == 1
                  ? null
                  : () async {
                      if (w.exercises.isNotEmpty &&
                          !await confirm(context, title: 'Remove ${w.name}?', action: 'Remove', destructive: true, body: 'Its exercises are removed with it, and every day or step that used it.')) {
                        return;
                      }
                      change((d) => d.deleteWorkout(w.id), edits: true);
                    },
            ),
          ]),
        ),
      const SizedBox(height: 10),
      SecondaryButton('Add a workout', key: const Key('custom-add-workout'), icon: Icons.add, onPressed: () {
        final name = 'Workout ${String.fromCharCode(65 + (workouts.length % 26))}';
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label('Your week'),
      Text('One workout per weekday. A workout can be used on several days. A missed workout stays on its day until you move or skip it.', style: context.caption),
      const SizedBox(height: 8),
      GroupCard(children: [
        for (var wd = 1; wd <= 7; wd++)
          GroupRow(key: Key('day-assign-$wd'), title: weekdayName(wd), value: byDay[wd] == null ? 'Rest' : names[byDay[wd]] ?? 'Rest', onTap: () => _assignDay(wd, byDay[wd])),
      ]),
    ]);
  }

  Widget _cycle() {
    final cycle = d.schedule.cycle;
    final names = {for (final w in d.workouts) w.id: w.name};
    final days = d.schedule.trainingDays;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label('The cycle'),
      Text('Workouts follow this order and start again from the top when it ends. The order carries on across weeks; it does not restart on Monday.', style: context.caption),
      const SizedBox(height: 8),
      if (cycle.isNotEmpty)
        GroupCard(children: [
          for (final (i, id) in cycle.indexed)
            GroupRow(
              title: '${i + 1}. ${names[id] ?? ''}',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(key: Key('cycle-up-$i'), tooltip: 'Move step ${i + 1} up', icon: const Icon(Icons.arrow_upward, size: 20),
                    onPressed: i == 0 ? null : () => change((d) => d.setCycle([...cycle]..insert(i - 1, cycle[i])..removeAt(i + 1)))),
                IconButton(key: Key('cycle-down-$i'), tooltip: 'Move step ${i + 1} down', icon: const Icon(Icons.arrow_downward, size: 20),
                    onPressed: i == cycle.length - 1 ? null : () => change((d) => d.setCycle([...cycle]..insert(i + 2, cycle[i])..removeAt(i)))),
                IconButton(key: Key('cycle-remove-$i'), tooltip: 'Remove step ${i + 1}', icon: const Icon(Icons.close, size: 20),
                    onPressed: cycle.length == 1 ? null : () => change((d) => d.setCycle([...cycle]..removeAt(i)))),
              ]),
            ),
        ]),
      const SizedBox(height: 8),
      SecondaryButton('Add a step', key: const Key('cycle-add'), icon: Icons.add, onPressed: _addStep),
      _label('Training days'),
      Text('The next workout goes on the next of these days. With none chosen, any day can be a training day.', style: context.caption),
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
    final rotating = d.schedule.isRotating;
    final weeks = d.durationWeeks;
    const lengths = [4, 6, 8, 12, 16];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_chooseTemplate) templates == null ? const Center(child: CircularProgressIndicator()) : _templates(templates),
      if (_nameWorkouts) _workoutNames(),
      _label('Plan name'),
      TextField(
          key: const Key('plan-title'), controller: _title, maxLength: 60, textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'My plan'), onChanged: (v) => change((d) => d.title = v)),
      _label('Schedule'),
      Segmented<String>(
        keyPrefix: 'mode', values: const ['fixed', 'rotating'], selected: d.schedule.mode, label: (v) => v == 'fixed' ? 'Fixed weekdays' : 'Rotating sequence',
        onChanged: widget.startLocked ? (_) => toast(context, 'An active plan keeps its schedule type. Duplicate it to switch.') : (v) => change((d) => d.setMode(v)),
      ),
      const SizedBox(height: 8),
      Text('Fixed weekdays: each workout has its own weekday, and a missed one stays on its day.', style: context.caption.copyWith(fontWeight: rotating ? null : FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Rotating sequence: an ordered cycle that continues across weeks and moves on only when you finish or skip a workout.',
          style: context.caption.copyWith(fontWeight: rotating ? FontWeight.w600 : null)),
      if (rotating) _cycle() else _fixedDays(),
      _label('Start and length'),
      GroupCard(children: [
        GroupRow(
          key: const Key('plan-start-date'), title: 'Starts', value: longDate(d.startDate),
          subtitle: widget.startLocked ? 'An active plan keeps its start date.' : null,
          onTap: widget.startLocked
              ? null
              : () async {
                  final day = await pickDay(context, initial: d.startDate.compareTo(widget.today) < 0 ? widget.today : d.startDate, first: widget.today, help: 'Plan starts');
                  if (day != null) change((d) => d.startDate = day);
                },
        ),
      ]),
      const SizedBox(height: 8),
      _chips([
        for (final n in lengths) PickChip(key: Key('duration-$n'), label: '$n weeks', selected: weeks == n, onTap: () => change((d) => d.durationWeeks = n)),
        PickChip(key: const Key('duration-custom'), label: weeks != null && !lengths.contains(weeks) ? '$weeks ${weeks == 1 ? 'week' : 'weeks'}' : 'Other length', selected: weeks != null && !lengths.contains(weeks), onTap: _customWeeks),
        if (rotating) PickChip(key: const Key('duration-ongoing'), label: 'Ongoing', selected: weeks == null, onTap: () => change((d) => d.durationWeeks = null)),
      ]),
      Text(rotating ? 'A rotation can run for 1 to 52 weeks, or keep going with no end.' : 'A fixed-weekday plan has an end: 1 to 52 weeks.', style: context.caption),
    ]);
  }
}
