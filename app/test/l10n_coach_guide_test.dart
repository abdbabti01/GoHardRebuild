import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keys whose string values are identifiers, never display text.
const _idKeys = {'id', 'templateId', 'catalogKey', 'url', 'sources', 'alternatives', 'role', 'kind', 'type'};

/// Source citations stay in their original language.
const _citationKeys = {'title', 'publisher'};

/// Display strings intentionally identical to English, per language.
const _same = {
  'fr': {'3 × 8–12', '3 × 40 s', 'Triceps', 'Biceps', 'Progression'},
  'ar': {'3 × 8–12'},
};

final _identifier = RegExp(r'^[a-z0-9][a-z0-9-]*$');

dynamic _load(String name) => jsonDecode(File('assets/data/$name').readAsStringSync());

void _compare(dynamic en, dynamic tr, String lang, String path, String? key, bool id) {
  switch (en) {
    case Map():
      expect(tr, isA<Map>(), reason: path);
      expect((tr as Map).keys.toList(), en.keys.toList(), reason: path);
      for (final k in en.keys) {
        _compare(en[k], tr[k], lang, '$path.$k', k as String, id || _idKeys.contains(k) || _citationKeys.contains(k));
      }
    case List():
      expect(tr, isA<List>(), reason: path);
      expect((tr as List).length, en.length, reason: path);
      for (var i = 0; i < en.length; i++) {
        _compare(en[i], tr[i], lang, '$path[$i]', key, id);
      }
    case String():
      expect(tr, isA<String>(), reason: path);
      if (id || _identifier.hasMatch(en) || en.startsWith('http')) {
        expect(tr, en, reason: '$path is an identifier or citation');
      } else if (en.trim().isNotEmpty && !_same[lang]!.contains(en)) {
        expect(tr, isNot(en), reason: '$path is untranslated in $lang');
        expect((tr as String).trim(), isNotEmpty, reason: path);
      }
    default:
      expect(tr, en, reason: path);
  }
}

void main() {
  final en = _load('coach-guide.json');
  for (final lang in ['fr', 'ar']) {
    test('coach guide $lang mirrors English structure, ids and data', () {
      _compare(en, _load('coach-guide.$lang.json'), lang, r'$', null, false);
    });
  }
}
