import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../plans/builder/workout_editor.dart' show rxText;
import '../plans/plan_draft.dart';
import 'coach_avatar.dart';
import 'coach_bubble.dart';
import 'exercise_demo.dart';
import 'exercise_media.dart';
import 'media_manager.dart' show ManageExerciseVideoScreen, mediaAccessProvider;
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

Widget _techniqueSources(BuildContext context, List<TechniqueSource> sources) => Padding(
      key: const Key('exercise-technique-sources'),
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionLabel('Technique text sources'),
        for (final s in sources)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: context.sansStyle(14.5, weight: FontWeight.w500)),
              Text('${s.publisher} · checked ${s.checked}', style: context.caption),
              Text(s.url, style: context.caption),
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

/// Which exercise a sheet is about: its stable catalogue key (null or `custom:<id>` for the user's own) and name.
/// Nothing else is needed to show its guide and demonstration; a prescription is extra context when there is one.
typedef ExerciseIdentity = ({String? catalogKey, String name, bool isTimed});

/// The one exercise sheet (docs/EXERCISE_DEMOS.md): name, muscles and equipment, the demonstration, "How to do it",
/// its role, benefits, limitations, alternatives, the [prescription] when there is one, sources and credits, then the
/// caller's own Ask and Replace. Opening it, or pressing Play, changes nothing and calls no AI.
Future<void> showExerciseDetails(BuildContext context,
        {required ExerciseIdentity exercise, Prescription? prescription, String? workoutName, VoidCallback? onAsk, VoidCallback? onReplace}) =>
    showGoSheet<void>(context, title: exercise.name,
        builder: (sheet) => _ExerciseInfo(exercise: exercise, prescription: prescription, workoutName: workoutName, onAsk: onAsk, onReplace: onReplace));

/// "About (exercise name)" for a prescribed exercise: [showExerciseDetails] with its prescription. A custom exercise is
/// "Added by you" with no technique claims and no demonstration. [onAsk] opens Ask GoHard; [onReplace] runs the
/// editor's own replace control.
Future<void> showExerciseInfo(BuildContext context, {required Prescription exercise, String? workoutName, VoidCallback? onAsk, VoidCallback? onReplace}) =>
    showExerciseDetails(context, exercise: (catalogKey: exercise.catalogKey, name: exercise.name, isTimed: exercise.isTimed), prescription: exercise,
        workoutName: workoutName, onAsk: onAsk, onReplace: onReplace);

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

/// "How to do it": Setup, Movement and Common mistakes when they were written from an exercise-specific source,
/// otherwise the general cues, said to be unchecked.
Widget _howTo(BuildContext context, TechniqueGuide? sourced, List<String>? cues, String reviewNote) {
  if (sourced == null && (cues == null || cues.isEmpty)) return const SizedBox.shrink();
  return Padding(
    key: const Key('exercise-how-to'),
    padding: const EdgeInsets.only(top: 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text('How to do it', style: context.titleStyle(19))),
      if (sourced != null) ...[
        _section(context, 'Setup', sourced.setup, bullets: true),
        _section(context, 'Movement', sourced.movement, bullets: true),
        if (sourced.mistakes.isNotEmpty) _section(context, 'Common mistakes', sourced.mistakes, bullets: true),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Written from ${sourced.sources.map((s) => '${s.publisher}: ${s.title}').join('; ')}, checked ${sourced.sources.first.checked}. $reviewNote', style: context.caption),
        ),
      ] else ...[
        _section(context, 'Technique', cues!, bullets: true),
        Padding(padding: const EdgeInsets.only(top: 2), child: Text('General cues, not yet checked against a technique source.', style: context.caption)),
      ],
    ]),
  );
}

/// Who made the demonstration and under which licence: separate from the sources of the written technique.
Widget _demoCredit(BuildContext context, ExerciseMedia m) => Padding(
      key: const Key('exercise-demo-credit'),
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionLabel(m.isVideo ? 'Demonstration video credit' : 'Illustration credit'),
        const SizedBox(height: 4),
        Text(m.credit.attribution, style: context.sansStyle(14.5, weight: FontWeight.w500)),
        Text('Shows: ${m.variant}', style: context.caption),
        // Original footage carries its rights notice; someone else's keeps its licence and source.
        if (m.credit.original) Text(m.credit.notice ?? 'Original footage.', style: context.caption)
        else ...[
          if (m.changes.isNotEmpty) Text('Changes: ${m.changes}', style: context.caption),
          if (m.credit.licenceUrl != null) Text('Licence: ${m.credit.licenceUrl}', style: context.caption),
        ],
        if (m.sourcePage != null) Text('Source: ${m.sourcePage}', style: context.caption),
      ]),
    );

class _ExerciseInfo extends ConsumerWidget {
  const _ExerciseInfo({required this.exercise, this.prescription, this.workoutName, this.onAsk, this.onReplace});
  final ExerciseIdentity exercise;
  final Prescription? prescription;
  final String? workoutName;
  final VoidCallback? onAsk, onReplace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = exercise;
    final rx = prescription;
    final key = e.catalogKey;
    final custom = key == null || key.startsWith('custom:');
    final guide = ref.watch(coachGuideProvider).value;
    final demos = ref.watch(exerciseMediaProvider).value;
    final choices = {for (final c in ref.watch(exerciseChoicesProvider)) c.key: c};
    final info = custom ? null : guide?.exercise(key);
    final media = demos?.forKey(key);
    final sourced = demos?.techniqueFor(key);
    final known = choices[key];
    final term = rx == null ? null : guide?.term(e.isTimed ? 'timed-sets' : 'sets-reps');
    final where = workoutName == null ? '' : ' in $workoutName';
    // Shown once the bundled manifest has been read (at once, offline), so a clip is never announced then withdrawn.
    final demo = custom || demos == null ? null : ExerciseDemoMedia(media: media);
    return Column(key: const Key('exercise-info-sheet'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (custom) ...[
        StatusLine(Icons.person_outline, 'Added by you. GoHard has no checked technique notes or demonstration for your own exercises.'),
        if (known != null) _section(context, 'Category and equipment', ['${known.category} · ${known.equipment}']),
      ] else if (info == null) ...[
        if (known != null) _section(context, 'Category and equipment', ['${known.category} · ${known.equipment}']),
        ?demo,
        _howTo(context, sourced, null, demos?.techniqueReviewNote ?? ''),
        if (sourced == null) _section(context, 'Quick guide', ['There are no built-in notes for this exercise yet.']),
      ] else ...[
        const Overline(quickGuideLabel),
        _section(context, 'Muscles', [info.muscles.join(', ')]),
        _section(context, 'Equipment', [info.equipment]),
        if (demo != null) ...[const SizedBox(height: 14), demo],
        if (media?.isVideo ?? false)
          const CoachSpot(id: 'exercise.demo', introduce: true, say: CoachSay('Want to see this movement? Press Play on the demonstration.')),
        _howTo(context, sourced, info.cues, demos?.techniqueReviewNote ?? ''),
        _section(context, 'In this routine', [
          info.role == 'main'
              ? 'A main exercise$where: a compound lift that works several large muscles, usually done early with longer rest.'
              : 'An accessory$where: extra work for specific muscles, usually after the main lifts.',
        ]),
        _section(context, 'Good to know', info.benefits, bullets: true),
        _section(context, 'Limitations', info.limitations, bullets: true),
        if (info.alternatives.isNotEmpty) _section(context, 'Alternatives', [info.alternatives.map((k) => choices[k]?.name ?? k).join(', ')]),
      ],
      if (rx != null) _section(context, 'Prescription', [rxText(rx), rxSentence(rx), ?term?.text]),
      if (info != null) _sources(context, guide!.sourcesFor({...info.sources, ...?term?.sources}.toList())),
      if (sourced != null) _techniqueSources(context, sourced.sources),
      if (media != null) _demoCredit(context, media),
      // The owner's quiet way in; nobody else sees it.
      if (!custom && (ref.watch(mediaAccessProvider).value?.canManage ?? false))
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(key: const Key('exercise-manage-demo'), icon: const Icon(Icons.video_settings_outlined, size: 18),
              label: const Text('Manage demonstration'), onPressed: () => push(context, ManageExerciseVideoScreen(catalogKey: key))),
        ),
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
