import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/format.dart';
import '../../../core/language.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/models.dart';
import '../../../data/sync.dart';
import '../../coach/coach_bubble.dart';
import '../../coach/guide.dart';
import '../../coach/guide_sheets.dart';
import '../../coach/coach_contract.dart';
import '../../plus/entitlement.dart';
import '../../plus/plus_screen.dart';
import '../../shell/home_shell.dart';
import '../plan_actions.dart' show runPlanDecision;
import '../plan_draft.dart';
import '../plan_l10n.dart';
import '../plan_repository.dart';
import 'builder_steps.dart';
import 'review_step.dart';
import 'workout_editor.dart';

String _stepName(AppLocalizations l, int step) => switch (step) {
      0 => l.builderStepAvailability,
      1 => l.builderStepStructure,
      2 => l.builderStepWorkouts,
      _ => l.builderStepReview,
    };

/// Train › Plan › Create plan: "Guide me" (answers, then a suggested starting plan) or "I know what I want" (a
/// template or my own), both into the same four-step builder. A plan in progress (saved on the phone after every
/// change) can be continued or discarded.
class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key});
  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  bool _loaded = false, _direct = false;
  PlanDraft? _saved, _open;

  @override
  void initState() {
    super.initState();
    ref.read(planRepositoryProvider).builderDraft('new').then((d) {
      if (mounted) setState(() { _loaded = true; _saved = d; });
    });
  }

  Future<void> _begin(String path, {bool guided = false}) async {
    final d = PlanDraft.fresh(today: ref.read(todayKeyProvider), path: path, guided: guided, customTitle: context.l10n.planDefaultTitle);
    await ref.read(planRepositoryProvider).saveBuilderDraft(d);
    if (mounted) setState(() => _open = d);
  }

  Future<void> _discard() async {
    final l = context.l10n;
    final ok = await confirm(context, title: l.builderStartOverTitle, action: l.builderDiscardAction, destructive: true, body: l.builderDiscardBody);
    if (!ok || !mounted) return;
    await ref.read(planRepositoryProvider).discardBuilderDraft('new');
    if (mounted) setState(() => _saved = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_open != null) return PlanBuilder(initial: _open!);
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final saved = _saved;
    final l = context.l10n;
    return AppPage(title: l.builderCreatePlan, children: [
      if (saved != null) ...[
        // The plan in progress as a pale panel: its name in the serif, where it stopped, Continue and Start over.
        // Start over asks from the page's own context ([_discard]), never the panel's.
        PhotoPanel(
          content: (context) => [
            Overline(l.planStartInProgressTitle),
            const SizedBox(height: 4),
            Text(saved.title.trim().isEmpty ? l.builderUntitled : saved.title.trim(), style: context.pageTitleStyle(28)),
            const SizedBox(height: 4),
            Text(l.builderStepSaved(saved.step.clamp(0, 3) + 1, _stepName(l, saved.step.clamp(0, 3))), style: context.caption),
          ],
          actions: (_) => [
            PrimaryButton(l.builderContinuePlan, key: const Key('plan-draft-resume'), expand: false, onPressed: () => setState(() => _open = saved)),
            QuietLink(l.builderStartOver, key: const Key('plan-draft-discard'), said: l.builderStartOverSaid, onPressed: _discard),
          ],
        ),
      ] else ...[
        Text(l.builderBothWays, style: context.sansStyle(16, color: context.c.secondary)),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (i, (key, label, about, icon, selected, onTap)) in [
            ('plan-path-guided', l.builderGuideMe, l.builderGuideMeAbout, Icons.explore_outlined, false, () => _begin('template', guided: true)),
            ('plan-path-direct', l.builderKnowWhat, l.builderKnowWhatAbout, Icons.tune, _direct, () => setState(() => _direct = true)),
          ].indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ChoiceCard(key: Key(key), label: label, semanticLabel: l.builderChoiceSemantics(label, about), leading: Icon(icon), selected: selected, onTap: onTap),
                const SizedBox(height: 6),
                ExcludeSemantics(child: Text(about, textAlign: TextAlign.center, style: context.caption)),
              ]),
            ),
          ],
        ]),
      ],
      if (saved == null && _direct) ...[
        const SizedBox(height: 18),
        GroupCard(children: [
          GroupRow(
            key: const Key('plan-path-template'), icon: Icons.view_week_outlined, title: l.builderFromTemplate,
            subtitle: l.builderFromTemplateSubtitle, onTap: () => _begin('template'),
          ),
          GroupRow(
            key: const Key('plan-path-custom'), icon: Icons.edit_note, title: l.builderBuildOwn,
            subtitle: l.builderBuildOwnSubtitle, onTap: () => _begin('custom'),
          ),
        ]),
      ],
    ]);
  }
}

/// The four steps as numbered marks joined by a line: done steps carry a check, the current one is the deep accent,
/// later ones are outlined. Drawing only (the builder announces the step in words); the names show under the marks
/// while they fit and are left to the line above with large text.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator(this.step);
  final int step;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final l = context.l10n;
    Widget mark(int i) {
      final done = i < step, now = i == step;
      return Container(
        width: 28, height: 28, alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: now ? c.accentDeep : done ? c.tint : c.surface,
          border: Border.all(color: now || done ? c.accentDeep : c.outline, width: 1.5),
        ),
        child: done
            ? Icon(Icons.check_rounded, size: 16, color: GoColors.panelOf(c).text)
            // Decoration inside a fixed mark (the step is said in words above), so the digit keeps its size.
            : Text('${i + 1}', textScaler: TextScaler.noScaling, style: context.numStyle(13.5, weight: FontWeight.w700, color: now ? c.onAccentDeep : c.secondary)),
      );
    }

    Widget line(int i) => Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 4), color: i < step ? c.accentDeep : c.divider));
    TextStyle style(int i) => context.sansStyle(12.5, weight: i == step ? FontWeight.w700 : FontWeight.w400, color: i == step ? c.text : c.secondary);
    // The names show only when all four fit at the reader's text size; otherwise the line above names the step.
    double width(int i) {
      final p = TextPainter(text: TextSpan(text: _stepName(l, i), style: style(i)), textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context))..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    return LayoutBuilder(builder: (context, box) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (var i = 0; i < 4; i++) ...[if (i > 0) line(i), mark(i)],
      ]),
      if ([for (var i = 0; i < 4; i++) width(i)].fold(0.0, (a, b) => a + b) + 3 * 12 <= box.maxWidth) ...[
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (var i = 0; i < 4; i++) Text(_stepName(l, i), style: style(i))]),
      ],
    ]));
  }
}

/// Opens the builder on an existing plan: edit it from an effective date, or duplicate it into a new draft.
Future<void> openPlanEditor(BuildContext context, WidgetRef ref, Plan plan, {bool duplicate = false}) async {
  final repo = ref.read(planRepositoryProvider);
  final today = ref.read(todayKeyProvider);
  final l = context.l10n;
  final existing = await repo.builderDraft(duplicate ? 'new' : plan.id);
  if (!context.mounted) return;
  PlanDraft? draft;
  if (existing != null && !duplicate && existing.baseRevision != null && existing.baseRevision != plan.revision) {
    // The plan changed since these unsaved edits began (another device, an accepted swap): they are not offered again.
    toast(context, l.builderPlanChanged);
  } else if (existing != null && !duplicate) {
    final resume = await confirm(context, title: l.builderContinueChangesTitle, action: l.builderContinueChanges, cancel: l.builderStartFromSaved,
        body: l.builderContinueChangesBody(plan.title));
    if (resume) draft = existing;
  } else if (existing != null) {
    final replace = await confirm(context, title: l.builderReplaceInProgressTitle, action: l.builderReplaceIt,
        body: l.builderReplaceInProgressBody(existing.title.trim().isEmpty ? l.builderUntitled : existing.title.trim(), plan.title));
    if (!replace) return;
  }
  draft ??= PlanDraft.fromPlan(plan, duplicate: duplicate, today: today, copyName: l.planCopyName);
  if (draft.effectiveDate != null && draft.effectiveDate!.compareTo(today) < 0) draft.effectiveDate = today;
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

  /// Bumped when Ask GoHard replaces the draft, so the step's fields rebuild from it.
  int _applied = 0;

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
      toast(context, context.l10n.builderSaveFailed);
    });
  }

  /// Leaving Availability lays out the structure for the days chosen ([layOutStructure]).
  Future<void> _next() async {
    if (_step == 0) {
      final templates = await ref.read(planTemplatesProvider.future);
      if (!mounted) return;
      _change((d) => layOutStructure(d, templates));
    }
    _change((d) => d.step = _step + 1);
  }

  /// An accepted Ask GoHard suggestion: an ordinary saved edit of this draft, never activated.
  Future<void> _applyFromCoach(PlanDraft next) async {
    final j = copyJson(next.j); // [next] may be this very draft
    _change((d) => d.j
      ..clear()
      ..addAll(j), edits: true);
    setState(() => _applied++);
  }

  void _ask(String label, CoachFocus focus, {String? templateId, String? workoutId, String? occurrenceKey, String? catalogKey}) => openAskGoHard(
      context,
      CoachContext(
          label: label, focus: focus, templateId: templateId ?? draft.templateId, workoutId: workoutId, occurrenceKey: occurrenceKey, catalogKey: catalogKey,
          draft: () => draft, applyToDraft: _applyFromCoach));

  /// The split being chosen or used, by name, for Ask GoHard.
  String get _splitLabel {
    final t = ref.read(planTemplatesProvider).value;
    final id = draft.templateId;
    if (t != null && id != null && id != 'custom') return t.byId(id).name;
    if (t != null && draft.guided && draft.workouts.isEmpty) return t.byId(suggestTemplate(draft.days.length).templateId).name;
    return draft.title.trim().isEmpty ? context.l10n.planDefaultTitle : draft.title.trim();
  }

  /// What the coach says on each step (docs/COACH.md › Companion › Where it speaks), with Ask me about the draft and,
  /// on the split step, the built-in Compare splits. Nothing on the review step: it is a summary to check, not a task.
  ({String id, String label, CoachSay say})? _help(int step) {
    CoachContext ask(String label, CoachFocus focus) =>
        CoachContext(label: label, focus: focus, templateId: draft.templateId, draft: () => draft, applyToDraft: _applyFromCoach);
    final l = context.l10n;
    switch (step) {
      case 0:
        return (
          id: 'builder.preferences', label: l.builderHelpWeek,
          say: CoachSay(l.builderCoachWeek, ask: ask(l.builderAskWeek, CoachFocus.plan)),
        );
      case 1:
        final templates = ref.watch(planTemplatesProvider).value, guide = ref.watch(coachGuideProvider).value;
        final s = guidedSuggestion(draft.days.length, draft.equipment, experience: draft.experience);
        return (
          id: 'builder.structure', label: l.builderHelpSplit,
          say: CoachSay(l.builderCoachSplit,
              ask: ask(l.builderAskSplit, CoachFocus.split),
              guide: templates == null || guide == null || draft.path != 'template'
                  ? null
                  : (label: l.builderCompareSplits, key: const Key('coach-compare'), onPressed: () => showCompareSplits(context,
                      guide: guide, templates: templates, draft: draft, templateIds: [s.templateId, ...s.alternatives], suggestedId: s.templateId))),
        );
      case 2:
        return (
          id: 'builder.workouts', label: l.builderHelpWorkouts,
          say: CoachSay(l.builderCoachWorkouts,
              ask: ask(draft.title.trim().isEmpty ? _splitLabel : draft.title.trim(), CoachFocus.workout)),
        );
      default:
        return null;
    }
  }

  void _back() => _step <= _first ? Navigator.maybePop(context) : _change((d) => d.step = _step - 1);

  /// What stops the user leaving this step, in words.
  List<String> get _blocking {
    final l = context.l10n;
    if (_step == 0) return draft.days.isEmpty ? [l.builderChooseDay] : const [];
    if (_step == 1 && draft.guided && draft.workouts.isEmpty) return [l.builderChooseStarting];
    return [for (final code in draft.errors) planErrorText(l, code)];
  }

  /// A new or duplicated plan is a new saved definition (docs/PLUS_PREVIEW.md): over the limit the limit is explained
  /// here and the draft stays as it is. False when it may not be saved now.
  Future<bool> _mayCreate() async {
    final plans = ref.read(planListProvider);
    if (widget.editing != null || plans.any((p) => p.id == draft.planId)) return true;
    final gate = planGate(ref.read(plusProvider), plans);
    if (gate == CreateGate.ok) return true;
    await showPlusLimit(context, PlusLimit.plans, gate: gate, existing: plans.where((p) => !p.isArchived).length);
    return false;
  }

  /// Save plan: saved and ready, not active. Nothing about the current plan or Today changes.
  Future<void> _savePlan() async {
    if (_busy || !await _mayCreate() || !mounted) return;
    setState(() => _busy = true);
    await _saving;
    if (!mounted) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final shell = ref.read(shellProvider.notifier);
    final message = l.builderPlanSaved(draft.title.trim());
    try {
      await ref.read(planRepositoryProvider).createPlan(draft);
    } on ScheduleRefused catch (e) {
      if (mounted) setState(() { _busy = false; _error = planErrorText(l, e.codes.first); });
      return;
    } on LocalSaveFailure {
      if (mounted) setState(() { _busy = false; _error = l.planLocalSaveFailed; });
      return;
    }
    shell.switchTab(1, trainView: TrainView.plan);
    nav.popUntil((r) => r.isFirst);
    messenger.showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 2200)));
  }

  Future<void> _activate() async {
    if (_busy || !await _mayCreate() || !mounted) return;
    final primary = ref.read(primaryPlanProvider);
    final replaces = primary != null && primary.id != draft.planId ? primary : null;
    final l = context.l10n;
    if (replaces != null) {
      final open = ref.read(workoutListProvider).where((w) => w.isOpen && w.planId == replaces.id).firstOrNull;
      final ok = await confirm(context, title: l.builderPauseActivateTitle(replaces.title), action: l.builderPauseActivate,
          body: [l.builderPauseActivateBody(replaces.title, draft.title.trim(), longDate(draft.startDate)), if (open != null) l.builderOpenWorkoutStays(open.title)].join('\n\n'));
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    await _saving;
    if (!mounted) return;
    final today = ref.read(todayKeyProvider);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final shell = ref.read(shellProvider.notifier);
    final message = draft.startDate.compareTo(today) > 0 ? l.builderActiveStarts(draft.title.trim(), shortDate(draft.startDate)) : l.builderActive(draft.title.trim());
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
    final text = context.l10n.builderDraftSaved;
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(text), duration: const Duration(milliseconds: 2200)));
  }

  Future<void> _saveChanges() async {
    setState(() { _busy = true; _error = null; });
    await _saving;
    if (!mounted) return;
    final plan = ref.read(planListProvider).where((p) => p.id == widget.editing!.id).firstOrNull ?? widget.editing!;
    final today = ref.read(todayKeyProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      await ref.read(planRepositoryProvider).revise(plan, draft, workouts: ref.read(workoutListProvider), today: today);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text(plan.isDraft ? l.builderChangesSaved : l.builderChangesSavedFrom(shortDate(draft.effectiveDate ?? today))), duration: const Duration(milliseconds: 2200)));
    } on ScheduleRefused catch (e) {
      if (mounted) setState(() { _busy = false; _error = planErrorText(l, e.codes.first); });
    } on LocalSaveFailure {
      if (mounted) setState(() { _busy = false; _error = l.planLocalSaveFailed; });
    }
  }

  Widget _bottom() {
    final blocking = _blocking;
    final l = context.l10n;
    final notes = [
      for (final m in {...blocking, ?_error}) Padding(padding: const EdgeInsets.only(bottom: 8), child: StatusLine(Icons.error_outline, m, tone: Tone.error)),
    ];
    final back = SecondaryButton(l.builderBack, key: const Key('builder-back'), onPressed: _busy ? null : _back);
    Widget pair(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
    if (_step < 3) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        ...notes,
        pair(back, PrimaryButton(l.builderNext, key: const Key('builder-next'), onPressed: blocking.isEmpty ? _next : null)),
      ]);
    }
    if (widget.editing != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        ...notes,
        pair(back, PrimaryButton(l.builderSaveChanges, key: const Key('plan-save-changes'), busy: _busy, onPressed: blocking.isEmpty ? _saveChanges : null)),
      ]);
    }
    // Save and activate, Save plan (complete, not active) and Save draft (unfinished, on this phone) are three
    // different things (docs/PLAN_LIBRARY_OVERLOAD.md); an unusable plan can only be kept as a draft.
    final saveDraft = SecondaryButton(l.builderSaveDraft, key: const Key('plan-save-draft'), onPressed: _busy ? null : _saveDraft);
    if (!draft.isUsable) return Column(mainAxisSize: MainAxisSize.min, children: [...notes, pair(back, saveDraft)]);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ...notes,
      PrimaryButton(l.builderSaveActivate, key: const Key('plan-activate'), busy: _busy, onPressed: _activate),
      const SizedBox(height: 8),
      pair(back, SecondaryButton(l.builderSavePlan, key: const Key('plan-save'), onPressed: _busy ? null : _savePlan)),
      Center(child: TextButton(key: const Key('plan-save-draft'), onPressed: _busy ? null : _saveDraft, child: Text(l.builderSaveDraft))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final today = ref.watch(todayKeyProvider);
    // Read when activating or saving changes: kept loaded from the start.
    ref.watch(primaryPlanProvider);
    ref.watch(workoutListProvider);
    final l = context.l10n;
    final title = switch (draft.mode) { 'edit' => l.planEdit, 'duplicate' => l.planDuplicate, _ => l.builderCreatePlan };
    final help = _help(step);
    final progress = l.builderProgressSemantics(step + 1, _stepName(l, step));
    return PopScope(
      canPop: step <= _first,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _change((d) => d.step = _step - 1);
      },
      child: AppPage(
        key: ValueKey('builder-step-$step-$_applied'),
        title: title,
        bottom: _bottom(),
        children: [
          Row(children: [
            Expanded(
              child: Semantics(
                key: const Key('builder-progress'), label: progress, container: true,
                child: ExcludeSemantics(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Overline(l.builderProgressOverline(step + 1, _stepName(l, step))),
                    const SizedBox(height: 10),
                    _StepIndicator(step),
                  ]),
                ),
              ),
            ),
            // The coach's help entry, in a reserved slot beside the progress: never over fields, actions or the keyboard.
            if (help != null) ...[
              const SizedBox(width: 8),
              CoachHelpEntry(id: help.id, label: help.label),
            ],
          ]),
          // In the page's flow under the progress: it moves the step down and covers nothing. The split step
          // introduces itself once, the first time it is in view; the others speak when asked.
          if (help != null) CoachSpot(id: help.id, say: help.say, introduce: help.id == 'builder.structure'),
          const SizedBox(height: 18),
          switch (step) {
            0 => PreferencesStep(draft: draft, change: _change),
            1 => StructureStep(draft: draft, change: _change, today: today, startLocked: widget.editing != null && !widget.editing!.isDraft, ask: _ask),
            2 => WorkoutsStep(draft: draft, change: _change, ask: _ask),
            _ => ReviewStep(draft: draft, change: _change, editing: widget.editing),
          },
        ],
      ),
    );
  }
}
