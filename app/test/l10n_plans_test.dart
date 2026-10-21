import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/catalog_names.dart';
import 'package:gohard_rebuild/features/plans/plan_draft.dart';
import 'package:gohard_rebuild/features/plans/plan_l10n.dart';

/// Wording that is genuinely the same in a translation (proper names, letters).
const _same = {'Custom', 'Structure'};

final _idLike = RegExp(r'^[a-z0-9-]+$');
const _idKeys = {'id', 'key', 'catalogKey', 'kind', 'type'};

/// Exercise names stay the catalog's English: they are shown through the exercise-name catalog by key.
bool _catalogName(String path) => path.endsWith('.exercises[].name') || path.contains('.swapNames.');

void _walk(Object? en, Object? other, String path, String lang, List<String> translated) {
  if (en is Map) {
    expect(other, isA<Map>(), reason: '$lang $path');
    expect((other as Map).keys.toList(), en.keys.toList(), reason: '$lang $path keys');
    for (final k in en.keys) {
      _walk(en[k], other[k], '$path.$k', lang, translated);
    }
  } else if (en is List) {
    expect(other, isA<List>(), reason: '$lang $path');
    expect((other as List).length, en.length, reason: '$lang $path length');
    for (var i = 0; i < en.length; i++) {
      _walk(en[i], other[i], '$path[]', lang, translated);
    }
  } else if (en is String) {
    expect(other, isA<String>(), reason: '$lang $path');
    final key = path.split('.').last.replaceAll('[]', '');
    if (_idKeys.contains(key) || _idLike.hasMatch(en) || _catalogName(path)) {
      expect(other, en, reason: '$lang $path must stay identical');
    } else if (!_same.contains(en)) {
      expect(other, isNot(en), reason: '$lang $path is not translated');
      translated.add(path);
    }
  } else {
    expect(other, en, reason: '$lang $path');
  }
}

void main() {
  test('translated plan templates keep every id, key, number and structure of the English file', () {
    final en = jsonDecode(File('assets/data/plan-templates.json').readAsStringSync());
    for (final lang in ['fr', 'ar']) {
      final text = File('assets/data/plan-templates.$lang.json').readAsStringSync();
      final translated = <String>[];
      _walk(en, jsonDecode(text), r'$', lang, translated);
      expect(translated, isNotEmpty);
      // The parsed templates line up one for one with the English ones.
      final a = PlanTemplates.parse(File('assets/data/plan-templates.json').readAsStringSync()), b = PlanTemplates.parse(text);
      expect([for (final t in b.templates) t.id], [for (final t in a.templates) t.id]);
      expect([for (final t in b.templates) t.sequences], [for (final t in a.templates) t.sequences]);
    }
  });

  test('a French and an Arabic search term find the same catalog exercise; a custom one matches its own name', () {
    final names = ExerciseNames.parse(jsonEncode({
      'exercises': {
        'bench-press': {'en': 'Bench press', 'fr': 'Développé couché', 'ar': 'ضغط الصدر بالبار', 'aliases': {'fr': ['Développé couché à la barre']}},
        'back-squat': {'en': 'Back squat', 'fr': 'Squat arrière', 'ar': 'القرفصاء الخلفية'},
      },
    }));
    final catalog = [('bench-press', 'Bench press'), ('back-squat', 'Back squat'), (null, 'Mon développé maison')];
    List<String?> find(String q) => [for (final (key, name) in catalog) if (exerciseMatches(names, q, name: name, catalogKey: key)) key ?? name];
    expect(find('developpe couche'), ['bench-press']);
    expect(find('ضغط الصدر'), ['bench-press']);
    expect(find('ضَغْط الصَّدر'), ['bench-press'], reason: 'diacritics are folded');
    expect(find('bench'), ['bench-press']);
    expect(find('maison'), ['Mon développé maison']);
    expect(find('développé'), ['bench-press', 'Mon développé maison'], reason: 'order is the list order');
  });
}
