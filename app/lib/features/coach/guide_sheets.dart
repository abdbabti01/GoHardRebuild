import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../plans/builder/workout_editor.dart' show rxText;
import '../plans/plan_draft.dart';
import 'coach_avatar.dart';
import 'guide.dart';

/// The Quick guide sheets: reviewed bundled text, shown at once and offline. "Ask GoHard" is a separate, explicit
/// step (the callers pass it in); nothing here sends anything.

const quickGuideLabel = 'Quick guide · built in';

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
          const SectionLabel('Sources'),
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
  return showGoSheet<void>(context, title: 'Why $name?', builder: (sheet) => Column(key: const Key('guide-why-sheet'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Overline(quickGuideLabel),
        const SizedBox(height: 8),
        Text(reason, style: context.body),
        if (split != null) ...[
          _section(context, 'How it works', [split.summary, split.organisation]),
          _section(context, 'Good to know', split.benefits, bullets: true),
          _section(context, 'Trade-offs', split.limitations, bullets: true),
        ],
        _section(context, 'Choosing a split', [splitEvidenceNote]),
        if (split != null) _sources(context, guide.sourcesFor(split.sources)),
        const SizedBox(height: 16),
        SecondaryButton('Ask GoHard', key: const Key('guide-why-ask'), leading: const CoachAvatar(size: 24), onPressed: () {
          Navigator.pop(sheet);
          onAsk();
        }),
      ]));
}

/// "Compare splits": schedule, organisation and practical trade-offs of each candidate, stacked (no table), so it
/// wraps at any width and text size.
Future<void> showCompareSplits(BuildContext context, {required CoachGuideContent guide, required PlanTemplates templates, required PlanDraft draft, required List<String> templateIds, required String suggestedId}) =>
    showGoSheet<void>(context, title: 'Compare splits', builder: (sheet) => Column(key: const Key('guide-compare-sheet'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Overline(quickGuideLabel),
          const SizedBox(height: 8),
          Text(splitEvidenceNote, style: context.caption),
          for (final id in templateIds) ...[
            const SizedBox(height: 18),
            Panel(
              key: Key('guide-compare-$id'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Heading(id == suggestedId ? '${templates.byId(id).name} · Suggested' : templates.byId(id).name, size: 19),
                _section(context, 'Your week', [weekLine(previewOf(draft, templates, id))]),
                if (guide.split(id) case final s?) ...[
                  _section(context, 'Organisation', [s.organisation]),
                  _section(context, 'Days', [s.days]),
                  _section(context, 'Good to know', s.benefits, bullets: true),
                  _section(context, 'Trade-offs', s.limitations, bullets: true),
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
    showGoSheet<void>(context, title: exercise.name, builder: (sheet) => _ExerciseInfo(exercise: exercise, workoutName: workoutName, onAsk: onAsk, onReplace: onReplace));

/// "3 sets of 8 to 12 reps, with 90 seconds' rest between sets."
String rxSentence(Prescription e) {
  final sets = e.targetSets, lo = e.targetRepsMin, hi = e.targetRepsMax;
  final amount = e.isTimed
      ? (e.targetDurationSeconds == null ? null : '${e.targetDurationSeconds} seconds')
      : lo != null && hi != null && lo != hi
          ? '$lo to $hi reps'
          : (lo ?? hi) == null ? null : '${lo ?? hi} reps';
  final what = [if (sets != null) '$sets ${sets == 1 ? 'set' : 'sets'}', ?amount].join(' of ');
  if (what.isEmpty) return 'No target set yet.';
  return '${what[0].toUpperCase()}${what.substring(1)}${e.restSeconds == null ? '' : ", with ${e.restSeconds} seconds' rest between sets"}.';
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
    final guide = ref.watch(coachGuideProvider).value;
    final choices = {for (final c in ref.watch(exerciseChoicesProvider)) c.key: c};
    final info = custom ? null : guide?.exercise(key);
    final known = choices[key];
    final term = guide?.term(e.isTimed ? 'timed-sets' : 'sets-reps');
    final where = workoutName == null ? '' : ' in $workoutName';
    return Column(key: const Key('exercise-info-sheet'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (custom) ...[
        StatusLine(Icons.person_outline, 'Added by you. GoHard has no checked technique notes for your own exercises.'),
        if (known != null) _section(context, 'Category and equipment', ['${known.category} · ${known.equipment}']),
      ] else if (info == null) ...[
        if (known != null) _section(context, 'Category and equipment', ['${known.category} · ${known.equipment}']),
        _section(context, 'Quick guide', ['There are no built-in notes for this exercise yet.']),
      ] else ...[
        const Overline(quickGuideLabel),
        _section(context, 'Muscles', [info.muscles.join(', ')]),
        _section(context, 'Equipment', [info.equipment]),
        _section(context, 'In this routine', [
          info.role == 'main'
              ? 'A main exercise$where: a compound lift that works several large muscles, usually done early with longer rest.'
              : 'An accessory$where: extra work for specific muscles, usually after the main lifts.',
        ]),
        _section(context, 'Technique', info.cues, bullets: true),
        _section(context, 'Good to know', info.benefits, bullets: true),
        _section(context, 'Limitations', info.limitations, bullets: true),
        if (info.alternatives.isNotEmpty) _section(context, 'Alternatives', [info.alternatives.map((k) => choices[k]?.name ?? k).join(', ')]),
      ],
      _section(context, 'Prescription', [rxText(e), rxSentence(e), ?term?.text]),
      if (info != null) _sources(context, guide!.sourcesFor({...info.sources, ...?term?.sources}.toList())),
      const SizedBox(height: 16),
      if (onAsk != null)
        SecondaryButton('Ask about this exercise', key: const Key('exercise-info-ask'), leading: const CoachAvatar(size: 24), onPressed: () {
          Navigator.pop(context);
          onAsk!();
        }),
      if (onReplace != null) ...[
        const SizedBox(height: 8),
        SecondaryButton('Replace…', key: const Key('exercise-info-replace'), onPressed: () {
          Navigator.pop(context);
          onReplace!();
        }),
      ],
    ]);
  }
}
