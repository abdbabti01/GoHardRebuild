/// Folding for matching only (exercise and food search): never shown, stored or sent. Lower case; French accents
/// and ligatures to plain letters ("Développé" → "developpe", "œuf" → "oeuf"); Arabic without diacritics or tatweel,
/// with alef, yeh, teh marbuta and hamza-carrier variants merged ("الضغط" = "الضَّغْط", "أرز" = "ارز") and
/// Arabic-Indic digits as ASCII. Distinct words stay distinct: nothing is stemmed or translated.
String foldForSearch(String s) {
  final out = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final mapped = _fold[r];
    if (mapped != null) {
      out.write(mapped);
    } else if ((r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640 || (r >= 0x0300 && r <= 0x036F)) {
      // Arabic harakat, superscript alef, tatweel; combining Latin accents.
    } else if (r >= 0x0660 && r <= 0x0669) {
      out.writeCharCode(r - 0x0660 + 0x30);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      out.writeCharCode(r - 0x06F0 + 0x30);
    } else {
      out.writeCharCode(r);
    }
  }
  return out.toString();
}

final Map<int, String> _fold = {
  for (final e in {
    'àâäáãå': 'a', 'çć': 'c', 'éèêëę': 'e', 'îïíì': 'i', 'ôöóòõ': 'o', 'ùûüú': 'u', 'ÿý': 'y', 'ñ': 'n',
    'œ': 'oe', 'æ': 'ae', '’‘ʼ': "'", '‐‑–—': '-',
    'أإآٱ': 'ا', 'ى': 'ي', 'ئ': 'ي', 'ؤ': 'و', 'ة': 'ه',
  }.entries)
    for (final r in e.key.runes) r: e.value,
};
