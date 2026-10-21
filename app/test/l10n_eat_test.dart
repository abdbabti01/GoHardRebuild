import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/features/nutrition/food_discovery.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_search.dart';
import 'package:gohard_rebuild/features/nutrition/water.dart';
import 'package:gohard_rebuild/l10n/app_localizations.dart';

/// Eat in French and Arabic: catalog names and aliases find the same food, typed digits mean the same numbers,
/// Arabic plural forms. Display and search only; no value changes with the language.
void main() {
  final main = File('assets/data/common-foods.json').readAsStringSync();
  final overlay = File('assets/data/common-foods.l10n.json').readAsStringSync();
  final catalog = CommonFoodCatalog.parse(main, overlay: overlay);

  CommonFood first(String q) => searchLocal(q, catalog: catalog, saved: const [], journal: const [], seen: const []).common.first.common!;

  test('the overlay names every catalog food in French and Arabic, and nothing else', () {
    final words = (jsonDecode(overlay) as Map)['foods'] as Map;
    expect(words.keys.toSet(), {for (final f in catalog.foods) f.id});
    for (final f in catalog.foods) {
      for (final lang in ['fr', 'ar']) {
        expect(f.words[lang]?.name, isNotEmpty, reason: '${f.id} $lang');
        expect(f.portionIn(lang) == null, f.portion == null, reason: 'a start portion is translated exactly when there is one: ${f.id}');
      }
    }
  });

  test('French and Arabic names find the same food, with the same values and portions', () {
    final english = first('chicken breast');
    expect(english.id, 'chicken-breast');
    for (final q in ['poulet', 'Poitrine de poulet', 'دجاج', 'صدر الدجاج', 'صَدْر دجاج']) {
      final f = first(q);
      expect(f.id, english.id, reason: q);
      expect(f.item.key, english.item.key);
      expect(f.item.nutrients, english.item.nutrients);
      expect([for (final s in f.item.servings) s.grams], [for (final s in english.item.servings) s.grams]);
    }
    expect(first('ارز').id, anyOf('brown-rice', 'white-rice'), reason: 'hamza folded');
    expect(first('أرز أبيض').id, 'white-rice', reason: 'a variant is not merged with another');
    expect(first('أرز بني').id, 'brown-rice');
  });

  test('a catalog food is shown in the app language; logged words stay as stored', () {
    final s = Suggestion(catalog.foods.firstWhere((f) => f.id == 'eggs').item, Origin.common, common: catalog.foods.firstWhere((f) => f.id == 'eggs'));
    expect(rowFacts(s, lookupAppLocalizations(const Locale('en'))).title, 'Eggs');
    expect(rowFacts(s, lookupAppLocalizations(const Locale('fr', 'CA'))).title, 'Œufs');
    expect(rowFacts(s, lookupAppLocalizations(const Locale('ar'))).title, 'بيض');
    expect(rowFacts(s, lookupAppLocalizations(const Locale('fr', 'CA'))).basis, startsWith('1 œuf'));
    expect(rowFacts(s, lookupAppLocalizations(const Locale('en'))).basis, startsWith('1 egg'));
  });

  test('a barcode typed in Arabic-Indic digits is the same code, leading zeros kept', () {
    expect(asciiDigits('٠١٢٣٤٥٦٧٨٩٠٥'), '012345678905');
    expect(asciiDigits('۰۱۲۳۴۵۶۷۸۹۰۵'), '012345678905');
    expect(normalizeBarcode('٠١٢٣٤٥٦٧٨٩٠٥'), normalizeBarcode('012345678905'));
  });

  test('water typed with grouping or Arabic digits is the same amount', () {
    for (final raw in ['1500', '1 500', '1 500', '1,500', '١٥٠٠', '١٬٥٠٠']) {
      expect(VolumeUnit.ml.parseAmount(raw), 1500, reason: raw);
    }
    expect(VolumeUnit.flOz.parseAmount('8,5'), 8.5);
    expect(VolumeUnit.ml.parseAmount('1,2,3'), isNull);
  });

  test('Arabic entry counts use all six plural forms', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect([for (final n in [0, 1, 2, 3, 11, 100]) ar.trendsFoodCount(n)], ['0 طعام', 'طعام واحد', 'طعامان', '3 أطعمة', '11 طعامًا', '100 طعام']);
    final en = lookupAppLocalizations(const Locale('en'));
    expect([en.trendsFoodCount(0), en.trendsFoodCount(1), en.trendsFoodCount(2)], ['0 foods', '1 food', '2 foods']);
    final fr = lookupAppLocalizations(const Locale('fr', 'CA'));
    expect([fr.trendsFoodCount(0), fr.trendsFoodCount(1), fr.trendsFoodCount(2)], ['0 aliment', '1 aliment', '2 aliments']);
  });
}
