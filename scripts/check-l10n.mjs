// Checks the translation catalogs (docs/LOCALIZATION.md › Checks): every English key exists in French and Arabic and
// nowhere else, every key has a description, placeholders match, ICU braces and plural/select forms are well formed,
// Arabic plurals give all six forms, and nothing is left as the English text unless it is the same in every language.
// Usage: node scripts/check-l10n.mjs   (exit code 1 on any problem)
import fs from 'node:fs';
import path from 'node:path';

const dir = path.join(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '..', 'app', 'lib', 'l10n');
const read = (l) => JSON.parse(fs.readFileSync(path.join(dir, `app_${l}.arb`), 'utf8'));
const en = read('en'), fr = read('fr'), ar = read('ar');
const keys = (o) => Object.keys(o).filter((k) => !k.startsWith('@'));
const problems = [];
const bad = (m) => problems.push(m);

/** The declared placeholders an ICU message uses: {name}, {name, plural, …}, {name, select, …}. Words inside a
 * select or plural branch ("other{Weather}") are text, not arguments. */
function args(msg, declared) {
  const out = new Set();
  for (const m of msg.matchAll(/\{\s*([A-Za-z][A-Za-z0-9_]*)\s*(?:,|\})/g)) if (declared.has(m[1])) out.add(m[1]);
  return out;
}

/** Balanced braces, and each plural/select block's forms. Returns [{kind, forms}] or throws. */
function blocks(msg) {
  let depth = 0;
  for (const ch of msg) {
    if (ch === '{') depth++;
    if (ch === '}' && --depth < 0) throw new Error('unbalanced }');
  }
  if (depth !== 0) throw new Error('unbalanced {');
  const found = [];
  const re = /\{\s*[A-Za-z][A-Za-z0-9_]*\s*,\s*(plural|select)\s*,/g;
  for (const m of msg.matchAll(re)) {
    // Walk the block's top level and collect the selector before each "{".
    let i = m.index + m[0].length, d = 0, sel = '', forms = [];
    for (; i < msg.length; i++) {
      const ch = msg[i];
      if (ch === '{') {
        if (d === 0) forms.push(sel.trim());
        d++;
        sel = '';
      } else if (ch === '}') {
        if (d === 0) break;
        d--;
      } else if (d === 0) sel += ch;
    }
    found.push({ kind: m[1], forms });
  }
  return found;
}

const sameEverywhere = (k, v) =>
  !/[A-Za-z]{2,}/.test(v.replace(/\{[^{}]*\}/g, '')) || /same in every language|may match English|never translated/i.test(en['@' + k]?.description ?? '');

for (const k of keys(en)) {
  const meta = en['@' + k];
  if (!meta?.description) bad(`${k}: no description`);
  const declared = new Set(Object.keys(meta?.placeholders ?? {}));
  const want = args(en[k], declared);
  // A translation uses every placeholder English uses; it may use another declared one its grammar needs (an Arabic
  // verb agreeing with the guide's name), but a placeholder no language uses is a mistake.
  const used = new Set(want);
  for (const [l, cat] of [['fr', fr], ['ar', ar]]) {
    const v = cat[k];
    if (typeof v !== 'string') { bad(`${k}: missing in ${l}`); continue; }
    const got = args(v, declared);
    got.forEach((p) => used.add(p));
    const lost = [...want].filter((p) => !got.has(p));
    if (lost.length) bad(`${k} (${l}): drops placeholder(s) {${lost}}`);
    if (v === en[k] && !sameEverywhere(k, v)) bad(`${k} (${l}): untranslated ("${v}")`);
  }
  for (const p of declared) if (!used.has(p)) bad(`${k}: placeholder ${p} declared but used in no language`);
  for (const [l, v] of [['en', en[k]], ['fr', fr[k]], ['ar', ar[k]]]) {
    if (typeof v !== 'string') continue;
    let bs;
    try { bs = blocks(v); } catch (e) { bad(`${k} (${l}): ${e.message}`); continue; }
    for (const b of bs) {
      if (!b.forms.includes('other')) bad(`${k} (${l}): ${b.kind} without "other"`);
      if (b.kind === 'plural' && l === 'ar') {
        for (const [a, c] of [['zero', '=0'], ['one', '=1'], ['two', '=2']]) if (!b.forms.includes(a) && !b.forms.includes(c)) bad(`${k} (ar): plural lacks ${c}/${a}`);
        for (const f of ['few', 'many']) if (!b.forms.includes(f)) bad(`${k} (ar): plural lacks ${f}`);
      }
    }
  }
}
for (const [l, cat] of [['fr', fr], ['ar', ar]]) for (const k of keys(cat)) if (!(k in en)) bad(`${k}: in ${l} but not in English`);

const total = keys(en).length;
if (problems.length) {
  console.error(problems.join('\n'));
  console.error(`\n${problems.length} problem(s) in ${total} messages.`);
  process.exit(1);
}
console.log(`Localization catalogs OK: ${total} messages in en, fr, ar.`);
