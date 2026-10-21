import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/catalog_names.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../plans/builder/workout_editor.dart' show rxText;
import '../plans/plan_draft.dart';
import 'coach_avatar.dart';
import 'guide.dart';

/// The Quick guide sheets: reviewed bundled text, shown at once and offline. "Ask GoHard" is a separate, explicit
/// step (the callers pass it in); nothing here sends anything.

/// "Quick guide · built in", in the app's language.
String quickGuideLabel(AppLocalizations l) => l.coachQuickGuideBuiltIn;

Widget _section(BuildContext context, String title, List<String> lines, {bool bullets = false}) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionLabel(title),
        const SizedBox(height: 4),
        for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(bullets ? '•  $l' : l, style: context.body)),
      ]),
    );

Widget _sources(BuildContext context, List<GuideSource> sources) => sources.isEmpty
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionLabel(context.l10n.coachGuideSources),
          for (final s in sources)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.title, style: context.sansStyle(14.5, weight: FontWeight.w500)),
                Text(s.publisher, style: context.caption),
                SelectableText(s.url, style: context.caption),
              ]),
            ),
        ]),
      );

/// "Why this suggestion?": the reason from the answers and the reviewed split text, then an explicit Ask GoHard.
Future<void> showWhySuggestion(BuildContext context, {required CoachGuideContent guide, required String templateId, required String name, required String reason, required VoidCallback onAsk}) {
  final split = guide.split(templateId);
  final l = context.l10n;
  return showGoSheet<void>(context, title: l.coachWhyTitle(name), builder: (sheet) => Column(key: const Key('guide-why-sheet'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Overline(quickGuideLabel(l)),
        const SizedBox(height: 8),
        Text(reason, style: context.body),
        if (split != null) ...[
          _section(context, l.coachSheetHowItWorks, [split.summary, split.organisation]),
          _section(context, l.coachSheetGoodToKnow, split.benefits, bullets: true),
          _section(context, l.coachSheetTradeOffs, split.limitations, bullets: true),
        ],
        _section(context, l.coachSheetChoosingSplit, [l.coachSplitEvidenceNote]),
        if (split != null) _sources(context, guide.sourcesFor(split.sources)),
        const SizedBox(height: 16),
        SecondaryButton(l.coachAskTitle, key: const Key('guide-why-ask'), leading: const CoachAvatar(size: 24), onPressed: () {
          Navigator.pop(sheet);
          onAsk();
        }),
      ]));
}

/// "Compare splits": schedule, organisation and practical trade-offs of each candidate, stacked (no table), so it
/// wraps at any width and text size.
Future<void> showCompareSplits(BuildContext context, {required CoachGuideContent guide, required PlanTemplates templates, required PlanDraft draft, required List<String> templateIds, required String suggestedId}) =>
    showGoSheet<void>(context, title: context.l10n.coachCompareTitle, builder: (sheet) => Column(key: const Key('guide-compare-sheet'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Overline(quickGuideLabel(context.l10n)),
          const SizedBox(height: 8),
          Text(context.l10n.coachSplitEvidenceNote, style: context.caption),
          for (final id in templateIds) ...[
            const SizedBox(height: 18),
            Panel(
              key: Key('guide-compare-$id'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Heading(id == suggestedId ? context.l10n.coachCompareSuggested(templates.byId(id).name) : templates.byId(id).name, size: 19),
                _section(context, context.l10n.coachSheetYourWeek, [weekLine(previewOf(draft, templates, id))]),
                if (guide.split(id) case final s?) ...[
                  _section(context, context.l10n.coachSheetOrganisation, [s.organisation]),
                  _section(context, context.l10n.coachSheetDays, [s.days]),
                  _section(context, context.l10n.coachSheetGoodToKnow, s.benefits, bullets: true),
                  _section(context, context.l10n.coachSheetTradeOffs, s.limitations, bullets: true),
                ],
              ]),
            ),
          ],
        ]));

// ------------------------------------------------------------------ exercise information

/// "About (exercise name)": muscles, equipment, its role in this workout, technique cues, benefits, limitations,
/// alternatives and the prescription in plain words, from the reviewed content. A custom exercise is "Added by you"
/// with no technique claims. [onAsk] opens Ask GoHard; [onReplace] runs the editor's own replace control.
Future<void> showExerciseInfo(BuildContext context, {required Prescription exercise, String? workoutName, VoidCallback? onAsk, VoidCallback? onReplace}) =>
    showGoSheet<void>(context,
        title: ProviderScope.containerOf(context, listen: false).read(exerciseNamesProvider).name(exercise.catalogKey, exercise.name, Localizations.localeOf(context)),
        builder: (sheet) => _ExerciseInfo(exercise: exercise, workoutName: workoutName, onAsk: onAsk, onReplace: onReplace));

/// "3 sets of 8 to 12 reps, with 90 seconds' rest between sets."
String rxSentence(Prescription e, [AppLocalizations? l10n]) {
  final l = l10n ?? currentL10n;
  final sets = e.targetSets, lo = e.targetRepsMin, hi = e.targetRepsMax;
  final amount = e.isTimed
      ? (e.targetDurationSeconds == null ? null : l.coachRxSeconds(e.targetDurationSeconds!))
      : lo != null && hi != null && lo != hi
          ? l.coachRxRepRange(lo, hi)
          : (lo ?? hi) == null ? null : l.coachRxReps((lo ?? hi)!);
  final setsText = sets == null ? null : l.coachRxSets(sets);
  // Each part starts with a number, so nothing needs a capital letter.
  final what = setsText != null && amount != null ? l.coachRxSetsOf(setsText, amount) : setsText ?? amount;
  if (what == null) return l.coachRxNone;
  return e.restSeconds == null ? l.coachRxSentence(what) : l.coachRxSentenceRest(what, e.restSeconds!);
}

class _ExerciseInfo extends ConsumerWidget {
  const _ExerciseInfo({required this.exercise, this.workoutName, this.onAsk, this.onReplace});
  final Prescription exercise;
  final String? workoutName;
  final VoidCallback? onAsk, onReplace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = exercise;
    final key = e.catalogKey;
    final custom = key == null || key.startsWith('custom:');
    final l = context.l10n;
    final locale = Localizations.localeOf(context);
    final names = ref.watch(exerciseNamesProvider);
    final guide = ref.watch(coachGuideProvider).value;
    final choices = {for (final c in ref.watch(exerciseChoicesProvider)) c.key: c};
    final info = custom ? null : guide?.exercise(key);
    final known = choices[key];
    final term = guide?.term(e.isTimed ? 'timed-sets' : 'sets-reps');
    final w = workoutName;
    final kind = known == null ? null : '${names.category(known.category, locale)} · ${names.equipment(known.equipment, locale)}';
    return Column(key: const Key('exercise-info-sheet'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (custom) ...[
        StatusLine(Icons.person_outline, l.coachInfoCustom),
        if (kind != null) _section(context, l.coachInfoCategoryEquipment, [kind]),
      ] else if (info == null) ...[
        if (kind != null) _section(context, l.coachInfoCategoryEquipment, [kind]),
        _section(context, l.coachQuickGuide, [l.coachInfoNoNotes]),
      ] else ...[
        Overline(quickGuideLabel(l)),
        _section(context, l.coachInfoMuscles, [info.muscles.join(l.coachListSeparator)]),
        _section(context, l.coachInfoEquipment, [info.equipment]),
        _section(context, l.coachInfoInRoutine, [
          info.role == 'main'
              ? (w == null ? l.coachInfoRoleMain : l.coachInfoRoleMainIn(w))
              : (w == null ? l.coachInfoRoleAccessory : l.coachInfoRoleAccessoryIn(w)),
        ]),
        _section(context, l.coachInfoTechnique, info.cues, bullets: true),
        _section(context, l.coachSheetGoodToKnow, info.benefits, bullets: true),
        _section(context, l.coachGuideLimitations, info.limitations, bullets: true),
        if (info.alternatives.isNotEmpty)
          _section(context, l.coachGuideAlternatives, [info.alternatives.map((k) => choices[k] == null ? k : names.nameOf(k, choices[k]!.name, locale)).join(l.coachListSeparator)]),
      ],
      _section(context, l.coachInfoPrescription, [rxText(e), rxSentence(e, l), ?term?.text]),
      if (info != null) _sources(context, guide!.sourcesFor({...info.sources, ...?term?.sources}.toList())),
      const SizedBox(height: 16),
      if (onAsk != null)
        SecondaryButton(l.coachInfoAsk, key: const Key('exercise-info-ask'), leading: const CoachAvatar(size: 24), onPressed: () {
          Navigator.pop(context);
          onAsk!();
        }),
      if (onReplace != null) ...[
        const SizedBox(height: 8),
        SecondaryButton(l.coachInfoReplace, key: const Key('exercise-info-replace'), onPressed: () {
          Navigator.pop(context);
          onReplace!();
        }),
      ],
    ]);
  }
}
