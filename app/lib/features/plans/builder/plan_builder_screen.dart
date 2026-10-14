import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/models.dart';
import '../../../data/sync.dart';
import '../../shell/home_shell.dart';
import '../plan_actions.dart' show runPlanDecision;
import '../plan_draft.dart';
import '../plan_repository.dart';
import '../plan_rules.dart';
import 'builder_steps.dart';
import 'review_step.dart';
import 'workout_editor.dart';

const _stepNames = ['Availability', 'Structure', 'Workouts', 'Review'];

/// Train › Plan › Create plan: choose "Start from a template" or "Build my own", then the four-step builder. A plan
/// in progress (saved on the phone after every change) can be continued or discarded.
class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key});
  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  bool _loaded = false;
  PlanDraft? _saved, _open;

  @override
  void initState() {
    super.initState();
    ref.read(planRepositoryProvider).builderDraft('new').then((d) {
      if (mounted) setState(() { _loaded = true; _saved = d; });
    });
  }

  Future<void> _begin(String path) async {
    final d = PlanDraft.fresh(today: ref.read(todayKeyProvider), path: path);
    await ref.read(planRepositoryProvider).saveBuilderDraft(d);
    if (mounted) setState(() => _open = d);
  }

  Future<void> _discard() async {
    final ok = await confirm(context, title: 'Start over?', action: 'Discard it', destructive: true,
        body: 'The plan in progress is deleted from this phone. Nothing else changes: no plan was created from it.');
    if (!ok || !mounted) return;
    await ref.read(planRepositoryProvider).discardBuilderDraft('new');
    if (mounted) setState(() => _saved = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_open != null) return PlanBuilder(initial: _open!);
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final saved = _saved;
    return AppPage(title: 'Create plan', children: [
      if (saved != null) ...[
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Overline('Plan in progress'),
            const SizedBox(height: 4),
            Text(saved.title.trim().isEmpty ? 'Untitled plan' : saved.title.trim(), style: context.titleStyle(22)),
            const SizedBox(height: 4),
            Text('Step ${saved.step.clamp(0, 3) + 1} of 4 · ${_stepNames[saved.step.clamp(0, 3)]}. Saved on this phone; nothing is active yet.', style: context.caption),
            const SizedBox(height: 14),
            PrimaryButton('Continue this plan', key: const Key('plan-draft-resume'), onPressed: () => setState(() => _open = saved)),
            const SizedBox(height: 8),
            SecondaryButton('Start over', key: const Key('plan-draft-discard'), onPressed: _discard),
          ]),
        ),
      ] else ...[
        Text('Both ways make a plan of your own that you can change at any time.', style: context.sansStyle(16, color: context.c.secondary)),
        const SizedBox(height: 16),
        GroupCard(children: [
          GroupRow(
            key: const Key('plan-path-template'), icon: Icons.view_week_outlined, title: 'Start from a template',
            subtitle: 'Preview a familiar split such as Upper / Lower or Push / Pull / Legs, then make it yours.', onTap: () => _begin('template'),
          ),
          GroupRow(
            key: const Key('plan-path-custom'), icon: Icons.edit_note, title: 'Build my own',
            subtitle: 'Name your workouts, add exercises and arrange your week.', onTap: () => _begin('custom'),
          ),
        ]),
      ],
    ]);
  }
}

/// Opens the builder on an existing plan: edit it from an effective date, or duplicate it into a new draft.
Future<void> openPlanEditor(BuildContext context, WidgetRef ref, Plan plan, {bool duplicate = false}) async {
  final repo = ref.read(planRepositoryProvider);
  final today = ref.read(todayKeyProvider);
  final existing = await repo.builderDraft(duplicate ? 'new' : plan.id);
  if (!context.mounted) return;
  PlanDraft? draft;
  if (existing != null && !duplicate) {
    final resume = await confirm(context, title: 'Continue your changes?', action: 'Continue changes', cancel: 'Start from the saved plan',
        body: 'You were changing "${plan.title}" and did not save. Continue where you left off, or start again from the plan as it is now.');
    if (resume) draft = existing;
  } else if (existing != null) {
    final replace = await confirm(context, title: 'Replace your plan in progress?', action: 'Replace it',
        body: '"${existing.title.trim().isEmpty ? 'Untitled plan' : existing.title.trim()}" is not finished. Duplicating "${plan.title}" replaces it on this phone.');
    if (!replace) return;
  }
  draft ??= PlanDraft.fromPlan(plan, duplicate: duplicate, today: today);
  await repo.saveBuilderDraft(draft);
  if (context.mounted) await push<void>(context, PlanBuilder(initial: draft, editing: duplicate ? null : plan));
}

/// "Edit this workout only": the exercise editor for one pending occurrence of a fixed-weekday plan, saved with
/// `PlanRepository.editOccasion`. Returns when the user saves or leaves.
Future<void> openOccurrenceEditor(BuildContext context, WidgetRef ref, Plan plan, Occasion occasion) async {
  await push<void>(context, OccurrenceEditorScreen(plan: plan, occasion: occasion));
}

/// The four steps over one [PlanDraft]. Every change is saved on the phone at once; nothing is created, activated or
/// started until Activate plan (or Save changes when editing).
class PlanBuilder extends ConsumerStatefulWidget {
  const PlanBuilder({super.key, required this.initial, this.editing});
  final PlanDraft initial;

  /// The plan being edited; null for a new plan or a duplicate.
  final Plan? editing;
  @override
  ConsumerState<PlanBuilder> createState() => _PlanBuilderState();
}

class _PlanBuilderState extends ConsumerState<PlanBuilder> {
  late final PlanDraft draft = widget.initial;
  Future<void> _saving = Future.value();
  bool _busy = false, _saveFailed = false;
  String? _error;

  /// Edit and duplicate start at Structure: the plan already says when and how you train.
  int get _first => draft.mode == 'new' ? 0 : 1;
  int get _step => draft.step.clamp(_first, 3);

  void _change(void Function(PlanDraft d) edit, {bool edits = false}) {
    setState(() {
      edit(draft);
      if (edits) draft.j['edited'] = true;
      _error = null;
    });
    final snapshot = draft.copy();
    final repo = ref.read(planRepositoryProvider);
    _saving = _saving.then((_) => repo.saveBuilderDraft(snapshot)).then((_) => _saveFailed = false, onError: (Object _) {
      if (!mounted || _saveFailed) return;
      _saveFailed = true;
      toast(context, 'The latest change could not be saved on this phone. Keep this screen open and try again.');
    });
  }

  /// Leaving Availability lays out the structure for the days chosen: the template (suggested, or the one picked),
  /// or the user's first workout names. A template whose workouts were already edited is never re-copied.
  Future<void> _next() async {
    if (_step == 0) {
      final templates = await ref.read(planTemplatesProvider.future);
      if (!mounted) return;
      _change((d) {
        if (d.path == 'template' && d.templateId != 'custom' && d.j['edited'] != true) {
          d.applyTemplate(templates, d.templateId ?? suggestTemplate(d.days.length, experience: d.experience).templateId, withExercises: withExercises(d));
        } else if (d.workouts.isEmpty) {
          d.setCustomStructure(defaultWorkoutNames(d.days.length));
          if (d.title.trim().isEmpty) d.title = 'My plan';
        }
      });
    }
    _change((d) => d.step = _step + 1);
  }

  void _back() => _step <= _first ? Navigator.maybePop(context) : _change((d) => d.step = _step - 1);

  /// What stops the user leaving this step, in words.
  List<String> get _blocking {
    if (_step == 0) return draft.days.isEmpty ? const ['Choose at least one day.'] : const [];
    return [for (final code in draft.errors) PlanRules.describe(code)];
  }

  Future<void> _activate() async {
    final primary = ref.read(primaryPlanProvider);
    final replaces = primary != null && primary.id != draft.planId ? primary : null;
    if (replaces != null) {
      final open = ref.read(workoutListProvider).where((w) => w.isOpen && w.planId == replaces.id).firstOrNull;
      final ok = await confirm(context, title: 'Pause ${replaces.title} and activate this plan?', action: 'Pause and activate',
          body: '"${replaces.title}" will be paused, not deleted. Its history and recorded workouts are kept, and you can resume it later. '
              '"${draft.title.trim()}" becomes your plan from ${longDate(draft.startDate)}.'
              '${open == null ? '' : '\n\nYour open workout "${open.title}" stays open with its recorded sets.'}');
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    await _saving;
    if (!mounted) return;
    final today = ref.read(todayKeyProvider);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final shell = ref.read(shellProvider.notifier);
    final message = draft.startDate.compareTo(today) > 0 ? '"${draft.title.trim()}" is active. It starts ${shortDate(draft.startDate)}.' : '"${draft.title.trim()}" is active.';
    final done = await runPlanDecision(context, () => ref.read(planRepositoryProvider).createAndActivate(draft, today: today, replacePrimaryId: replaces?.id), saved: '');
    if (!mounted) return;
    setState(() => _busy = false);
    if (!done) return;
    shell.switchTab(1, trainView: TrainView.plan);
    nav.popUntil((r) => r.isFirst);
    // Shown once back on the shell, so it sits above the navigation bar instead of covering it.
    messenger.showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 2200)));
  }

  Future<void> _saveDraft() async {
    setState(() => _busy = true);
    await _saving;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(const SnackBar(content: Text('Draft saved on this phone. Nothing is active yet.'), duration: Duration(milliseconds: 2200)));
  }

  Future<void> _saveChanges() async {
    setState(() { _busy = true; _error = null; });
    await _saving;
    if (!mounted) return;
    final plan = ref.read(planListProvider).where((p) => p.id == widget.editing!.id).firstOrNull ?? widget.editing!;
    final today = ref.read(todayKeyProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(planRepositoryProvider).revise(plan, draft, workouts: ref.read(workoutListProvider), today: today);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text(plan.isDraft ? 'Changes saved.' : 'Changes saved from ${shortDate(draft.effectiveDate ?? today)}.'), duration: const Duration(milliseconds: 2200)));
    } on ScheduleRefused catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.message; });
    } on LocalSaveFailure {
      if (mounted) setState(() { _busy = false; _error = 'That could not be saved on this phone. Nothing changed.'; });
    }
  }

  Widget _bottom() {
    final blocking = _blocking;
    final notes = [
      for (final m in {...blocking, ?_error}) Padding(padding: const EdgeInsets.only(bottom: 8), child: StatusLine(Icons.error_outline, m, tone: Tone.error)),
    ];
    final back = SecondaryButton('Back', key: const Key('builder-back'), onPressed: _busy ? null : _back);
    Widget pair(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
    if (_step < 3) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        ...notes,
        pair(back, PrimaryButton('Next', key: const Key('builder-next'), onPressed: blocking.isEmpty ? _next : null)),
      ]);
    }
    if (widget.editing != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        ...notes,
        pair(back, PrimaryButton('Save changes', key: const Key('plan-save-changes'), busy: _busy, onPressed: blocking.isEmpty ? _saveChanges : null)),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ...notes,
      if (draft.isUsable) ...[
        PrimaryButton('Activate plan', key: const Key('plan-activate'), busy: _busy, onPressed: _activate),
        const SizedBox(height: 8),
      ],
      pair(back, SecondaryButton('Save draft', key: const Key('plan-save-draft'), onPressed: _busy ? null : _saveDraft)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final today = ref.watch(todayKeyProvider);
    // Read when activating or saving changes: kept loaded from the start.
    ref.watch(primaryPlanProvider);
    ref.watch(workoutListProvider);
    final title = switch (draft.mode) { 'edit' => 'Edit plan', 'duplicate' => 'Duplicate plan', _ => 'Create plan' };
    final progress = 'Step ${step + 1} of 4: ${_stepNames[step]}';
    return PopScope(
      canPop: step <= _first,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _change((d) => d.step = _step - 1);
      },
      child: AppPage(
        key: ValueKey('builder-step-$step'),
        title: title,
        bottom: _bottom(),
        children: [
          Semantics(
            key: const Key('builder-progress'), label: progress, container: true,
            child: ExcludeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Overline('Step ${step + 1} of 4 · ${_stepNames[step]}'),
                const SizedBox(height: 8),
                ProgressRail((step + 1) / 4, label: progress, height: 6),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          switch (step) {
            0 => PreferencesStep(draft: draft, change: _change),
            1 => StructureStep(draft: draft, change: _change, today: today, startLocked: widget.editing != null && !widget.editing!.isDraft),
            2 => WorkoutsStep(draft: draft, change: _change),
            _ => ReviewStep(draft: draft, change: _change, editing: widget.editing),
          },
        ],
      ),
    );
  }
}
