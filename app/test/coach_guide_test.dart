import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/coach/guide.dart';
import 'package:gohard_rebuild/features/coach/guide_sheets.dart';
import 'package:gohard_rebuild/features/plans/builder/builder_steps.dart';
import 'package:gohard_rebuild/features/plans/plan_draft.dart';

final _apiFile = File('../api/src/GoHard.Api/Data/coach-guide.json');
final _appFile = File('assets/data/coach-guide.json');
final _guide = CoachGuideContent.parse(_appFile.readAsStringSync());
final _raw = jsonDecode(_appFile.readAsStringSync()) as Json;
final _templates = PlanTemplates.parse(File('assets/data/plan-templates.json').readAsStringSync());
final _catalog = {for (final c in jsonDecode(File('../api/src/GoHard.Api/Data/exercise-catalog.json').readAsStringSync()) as List) (c as Json)['key'] as String};

PlanDraft _guided(List<int> days) => PlanDraft.fresh(today: '2026-10-14', path: 'template', guided: true)..setPreferences(days: days);

void main() {
  group('reviewed content', () {
    test('the app copy is byte-identical to the canonical API file', () {
      expect(_appFile.readAsBytesSync(), _apiFile.readAsBytesSync());
    });

    test('has an honest review note and only the cited sources', () {
      expect(_guide.reviewNote, contains('awaits review'));
      expect(_guide.sources.keys, unorderedEquals(['acsm-2009', 'ramos-campo-2024']));
      for (final s in _guide.sources.values) {
        expect(s.url, startsWith('https://pubmed.ncbi.nlm.nih.gov/'));
      }
    });

    test('every template has a split entry and every templateId exists', () {
      final ids = {for (final t in _templates.templates) t.id};
      expect(_guide.splits.keys.toSet(), ids);
      for (final s in _guide.splits.values) {
        expect(s.name, _templates.byId(s.templateId).name, reason: 'the real split name');
        expect(s.benefits, isNotEmpty);
        expect(s.limitations, isNotEmpty);
      }
    });

    test('every catalogKey and alternative exists in the catalog; every exercise the templates or swaps use is covered', () {
      for (final e in _guide.exercises.values) {
        expect(_catalog, contains(e.catalogKey));
        expect(e.cues.length, inInclusiveRange(2, 4), reason: e.catalogKey);
        expect(e.role, anyOf('main', 'accessory'));
        expect(e.muscles, isNotEmpty);
        for (final a in e.alternatives) {
          expect(_catalog, contains(a), reason: '${e.catalogKey} → $a');
          expect(a, isNot(e.catalogKey));
        }
      }
      final used = <String>{
        for (final t in _templates.templates)
          for (final w in t.workouts)
            for (final eq in equipmentChoices.keys)
              for (final e in _templates.exercisesFor(w, eq)) e['catalogKey'] as String,
      };
      expect(used.difference(_guide.exercises.keys.toSet()), isEmpty);
      expect(_catalog.difference(_guide.exercises.keys.toSet()), isEmpty, reason: 'the whole catalogue is covered');
    });

    test('every source ID resolves, and the terms include the notation and plain explanations', () {
      final ids = [
        for (final s in (_raw['splits'] as List).cast<Json>()) ...(s['sources'] as List),
        for (final e in (_raw['exercises'] as List).cast<Json>()) ...(e['sources'] as List),
        for (final t in (_raw['terms'] as List).cast<Json>()) ...(t['sources'] as List),
      ];
      expect(ids.where((id) => !_guide.sources.containsKey(id)), isEmpty);
      expect(_guide.term('sets-reps')!.term, '3 × 8–12');
      for (final id in ['rep-range', 'rest', 'split', 'rotation', 'fixed-weekdays', 'compound-accessory', 'progression']) {
        expect(_guide.term(id), isNotNull, reason: id);
      }
    });
  });

  group('Guide me suggestions', () {
    test('are reproducible for 2–7 days × equipment × experience, with at most two distinct alternatives tied to the answers', () {
      const words = {2: 'two', 3: 'three', 4: 'four', 5: 'five', 6: 'six', 7: 'seven'};
      for (var days = 2; days <= 7; days++) {
        for (final eq in equipmentChoices.keys) {
          for (final exp in [null, ...experienceChoices.keys]) {
            final a = guidedSuggestion(days, eq, experience: exp), b = guidedSuggestion(days, eq, experience: exp);
            expect((a.templateId, a.reason), (b.templateId, b.reason));
            expect(a.alternatives, b.alternatives);
            expect(a.templateId, suggestTemplate(days).templateId, reason: 'the existing rule');
            expect(a.alternatives.length, lessThanOrEqualTo(2));
            expect(a.alternatives.toSet().length, a.alternatives.length);
            expect(a.alternatives, isNot(contains(a.templateId)));
            expect(a.alternatives, isNot(contains('custom')));
            for (final id in a.alternatives) {
              expect(_templates.byId(id).isCustom, isFalse);
            }
            expect(a.reason, startsWith('Suggested because you selected ${words[days]} training days and '));
            expect(a.reason, contains(switch (eq) { 'full_gym' => 'gym equipment', 'dumbbells' => 'dumbbells only', _ => 'bodyweight only' }));
          }
        }
      }
    });

    test('4 days with a gym: Upper / Lower, with Push / Pull and a Full Body rotation as alternatives', () {
      final s = guidedSuggestion(4, 'full_gym');
      expect(s.templateId, 'upper-lower');
      expect(s.alternatives, ['push-pull', 'full-body']);
      expect(s.reason, startsWith('Suggested because you selected four training days and gym equipment.'));
      final d = _guided([1, 2, 4, 5]);
      expect(fitLine(_templates.byId('full-body'), 4), 'Its 3 workouts rotate across your 4 days.');
      expect(weekLine(previewOf(d, _templates, 'upper-lower')), 'Mon Upper B · Tue Lower B · Thu Upper A · Fri Lower A', reason: 'real days, from the Wednesday start');
      expect(weekLine(previewOf(d, _templates, 'full-body')), startsWith('Full body A → Full body B → Full body C, on Mon, Tue, Thu, Fri.'));
      expect(d.workouts, isEmpty, reason: 'a preview never changes the draft');
    });

    test('Use this starting plan copies the routine into a draft, not an active plan; older drafts still load', () {
      final d = _guided([1, 2, 4, 5]);
      layOutStructure(d, _templates);
      expect(d.workouts, isEmpty, reason: 'Guide me waits for the person to choose');
      useTemplate(d, _templates, 'upper-lower');
      expect([for (final w in d.workouts) w.name], ['Upper A', 'Lower A', 'Upper B', 'Lower B']);
      expect(d.toPlanJson()['lifecycle'], 'draft');
      expect(d.isUsable, isTrue);
      final reloaded = PlanDraft(jsonDecode(jsonEncode(d.j)) as Json);
      expect((reloaded.guided, reloaded.path, reloaded.templateId), (true, 'template', 'upper-lower'));
      final older = PlanDraft.fresh(today: '2026-10-14', path: 'template')..j.remove('guided');
      expect(older.guided, isFalse);
      layOutStructure(older..setPreferences(days: [1, 2, 4, 5]), _templates);
      expect(older.templateId, 'upper-lower', reason: 'the template path is unchanged: the suggestion is copied on Next');
    });

    test('changed answers after customising never replace the workouts without an explicit apply', () {
      final d = _guided([1, 2, 4, 5]);
      useTemplate(d, _templates, 'upper-lower');
      d.renameWorkout(d.workouts.first.id, 'Upper heavy');
      d.j['edited'] = true;
      final before = [for (final w in d.workouts) w.name];
      d.setPreferences(days: [1, 3, 5]);
      layOutStructure(d, _templates);
      expect([for (final w in d.workouts) w.name], before);
      expect(guidedSuggestion(3, d.equipment).templateId, 'full-body', reason: 'the answers now suggest something else');
      useTemplate(d, _templates, 'full-body'); // the explicit apply
      expect([for (final w in d.workouts) w.name], ['Full body A', 'Full body B', 'Full body C']);
      expect(d.j['edited'], isFalse);
    });

    test('prescriptions read in plain words', () {
      expect(rxSentence(Prescription({'name': 'x', 'targetSets': 3, 'targetRepsMin': 8, 'targetRepsMax': 12, 'restSeconds': 90})), "3 sets of 8 to 12 reps, with 90 seconds' rest between sets.");
      expect(rxSentence(Prescription({'name': 'x', 'isTimed': true, 'targetSets': 3, 'targetDurationSeconds': 40})), '3 sets of 40 seconds.');
      expect(rxSentence(Prescription({'name': 'x'})), 'No target set yet.');
    });
  });
}
