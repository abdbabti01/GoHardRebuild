import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../plans/plan_draft.dart';

/// The reviewed, bundled "Quick guide" (docs/COACH.md › coach-guide.json): splits, exercises and terms. Read
/// offline; nothing here calls a model or the network.
extension type GuideSource(Json j) {
  String get id => j['id'] as String;
  String get title => j['title'] as String;
  String get publisher => j['publisher'] as String;
  String get url => j['url'] as String;
}

extension type SplitGuide(Json j) {
  String get templateId => j['templateId'] as String;
  String get name => j['name'] as String;
  String get summary => j['summary'] as String;
  String get organisation => j['organisation'] as String;
  String get days => j['days'] as String;
  List<String> get benefits => (j['benefits'] as List).cast<String>();
  List<String> get limitations => (j['limitations'] as List).cast<String>();
  List<String> get sources => (j['sources'] as List).cast<String>();
}

extension type ExerciseGuide(Json j) {
  String get catalogKey => j['catalogKey'] as String;
  List<String> get muscles => (j['muscles'] as List).cast<String>();
  String get equipment => j['equipment'] as String;

  /// main | accessory
  String get role => j['role'] as String;
  List<String> get cues => (j['cues'] as List).cast<String>();
  List<String> get benefits => (j['benefits'] as List).cast<String>();
  List<String> get limitations => (j['limitations'] as List).cast<String>();
  List<String> get alternatives => (j['alternatives'] as List).cast<String>();
  List<String> get sources => (j['sources'] as List).cast<String>();
}

extension type GuideTerm(Json j) {
  String get id => j['id'] as String;
  String get term => j['term'] as String;
  String get text => j['text'] as String;
  List<String> get sources => (j['sources'] as List? ?? const []).cast<String>();
}

class CoachGuideContent {
  CoachGuideContent.parse(String text) : this._(jsonDecode(text) as Json);
  CoachGuideContent._(Json j)
      : version = j['version'] as int,
        reviewNote = j['reviewNote'] as String,
        sources = {for (final s in j['sources'] as List) (s as Json)['id'] as String: GuideSource(s)},
        splits = {for (final s in j['splits'] as List) (s as Json)['templateId'] as String: SplitGuide(s)},
        exercises = {for (final e in j['exercises'] as List) (e as Json)['catalogKey'] as String: ExerciseGuide(e)},
        terms = {for (final t in j['terms'] as List) (t as Json)['id'] as String: GuideTerm(t)};
  final int version;
  final String reviewNote;
  final Map<String, GuideSource> sources;
  final Map<String, SplitGuide> splits;
  final Map<String, ExerciseGuide> exercises;
  final Map<String, GuideTerm> terms;

  SplitGuide? split(String? templateId) => splits[templateId];
  ExerciseGuide? exercise(String? catalogKey) => exercises[catalogKey];
  GuideTerm? term(String id) => terms[id];

  /// Only IDs present in [sources]; an unknown one is dropped rather than shown.
  List<GuideSource> sourcesFor(List<String> ids) => [for (final id in ids) ?sources[id]];
}

final coachGuideProvider = FutureProvider<CoachGuideContent>((ref) async => CoachGuideContent.parse(await rootBundle.loadString('assets/data/coach-guide.json')));

// ------------------------------------------------------------------ Guide me: reproducible suggestions, no AI

/// Alternatives that genuinely fit each day count (a matching weekly sequence, or a sensible rotation), in order.
const _alternatives = {
  2: ['upper-lower', 'push-pull'],
  3: ['push-pull-legs', 'upper-lower'],
  4: ['push-pull', 'full-body'],
  5: ['body-part', 'upper-lower'],
  6: ['upper-lower', 'push-pull'],
  7: ['upper-lower', 'push-pull'],
};
const _counts = ['no', 'one', 'two', 'three', 'four', 'five', 'six', 'seven'];
const _equipmentWords = {'full_gym': 'gym equipment', 'dumbbells': 'dumbbells only', 'bodyweight': 'bodyweight only'};

typedef GuidedSuggestion = ({String templateId, String reason, List<String> alternatives});

/// One suggested starting routine and up to two alternatives from the answers, by the existing rule
/// ([suggestTemplate]). The same answers always give the same result.
GuidedSuggestion guidedSuggestion(int days, String equipment, {String? experience}) {
  final base = suggestTemplate(days, experience: experience);
  final n = days.clamp(0, 7);
  final swaps = equipment == 'full_gym' ? '' : ' Exercises use the ${equipment == 'dumbbells' ? 'dumbbell' : 'bodyweight'} versions.';
  return (
    templateId: base.templateId,
    reason: 'Suggested because you selected ${_counts[n]} training ${n == 1 ? 'day' : 'days'} and ${_equipmentWords[equipment] ?? equipment}. ${base.reason}$swaps',
    alternatives: [for (final id in _alternatives[days] ?? const <String>[]) if (id != base.templateId) id].take(2).toList(),
  );
}

/// How a template sits on the chosen days, in a few words.
String fitLine(PlanTemplate t, int days) => t.fitsWeekly(days)
    ? 'One workout on each of your $days days.'
    : 'Its ${t.sequenceFor(days).length} workouts rotate across your $days ${days == 1 ? 'day' : 'days'}.';

/// The draft as it would be with this template: what the previews read. The real draft is untouched.
PlanDraft previewOf(PlanDraft d, PlanTemplates templates, String templateId) => d.copy()..applyTemplate(templates, templateId);

/// A readable week: "Mon Upper A · Tue Lower A · Thu Upper B · Fri Lower B", or the cycle and its days.
String weekLine(PlanDraft d) {
  final names = {for (final w in d.workouts) w.id: w.name};
  final s = d.schedule;
  if (!s.isRotating) return [for (final p in s.pattern) '${weekdayShort(p.weekday)} ${names[p.workoutId] ?? ''}'].join(' · ');
  final days = s.trainingDays.isEmpty ? 'any day' : s.trainingDays.map(weekdayShort).join(', ');
  return '${[for (final id in s.cycle) names[id] ?? ''].join(' → ')}, on $days. The order carries on across weeks.';
}
