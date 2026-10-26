// Builds the Eating out restaurant catalog (docs/EATING_OUT.md › Catalog) from committed source extracts.
//
//   node scripts/build-restaurant-catalog.mjs          write the catalog (API + app copies) and docs/RESTAURANT_SOURCES.md
//   node scripts/build-restaurant-catalog.mjs --check  fail if the committed outputs differ from a fresh build
//
// Nothing here fetches a restaurant site. Inputs: scripts/restaurant-catalog.spec.json (which items, their portion words
// and the source's build statements) and scripts/restaurant-sources/* (the source's own rows: a PDF text extract made
// with scripts/pdf-text.mjs, or a rows file). Every number comes from those rows; a footlong is derived only by the
// source's own instruction to double the 6-inch values. The build refuses rows that fail the checks below.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const spec = JSON.parse(fs.readFileSync(path.join(root, 'scripts/restaurant-catalog.spec.json'), 'utf8'));
const sourcesDir = path.join(root, 'scripts/restaurant-sources');
const outputs = ['api/src/GoHard.Api/Data/restaurant-catalog.json', 'app/assets/data/restaurant-catalog.json'];
const manifest = 'docs/RESTAURANT_SOURCES.md';
const problems = [];
const fail = (m) => problems.push(m);

// ---------------------------------------------------------------- adapters: source file → rows {section, name, values{}}

/** Subway's table as extracted text: "Name | g | cal | …" or the name on its own line and the numbers on the next. */
function subwayRows(chain) {
  const lines = fs.readFileSync(path.join(sourcesDir, chain.file), 'utf8').split(/\r?\n/).map((l) => l.trim());
  // Every heading of the table, so a row is found only under its own (the same name appears in several sections).
  const sections = chain.sections;
  const rows = [];
  let section = null, pendingName = null;
  for (const line of lines) {
    const cells = line.split('|').map((c) => c.trim()).filter((c) => c !== '' && c !== '**');
    const numeric = cells.filter((c) => /^\d+(\.\d+)?$/.test(c));
    const head = sections.find((s) => line === s || line.startsWith(s + ' |') || line.startsWith(s));
    if (head && numeric.length < chain.columns.length) { section = head; pendingName = null; continue; }
    if (numeric.length === chain.columns.length && cells.length - numeric.length <= 1) {
      const name = cells.length > numeric.length ? cells[0] : pendingName;
      pendingName = null;
      if (name && section) rows.push({ section, name: name.replace(/\s+/g, ' ').trim(), values: Object.fromEntries(chain.columns.map((c, i) => [c, +numeric[i]])) });
      continue;
    }
    pendingName = numeric.length === 0 && cells.length === 1 ? cells[0] : null;
  }
  return rows;
}

/** A rows file: {columns, rows:[{section, name, values[], updated?, serving?}]}. */
function fileRows(chain) {
  const f = JSON.parse(fs.readFileSync(path.join(sourcesDir, chain.file), 'utf8'));
  return f.rows.map((r) => {
    if (r.values.length !== f.columns.length) fail(`${chain.id}: row "${r.section} / ${r.name}" has ${r.values.length} values for ${f.columns.length} columns`);
    return { section: r.section, name: r.name, updated: r.updated ?? null, values: Object.fromEntries(f.columns.map((c, i) => [c, r.values[i]])) };
  });
}

const adapters = { 'subway-pdf-text': subwayRows, rows: fileRows };

// ---------------------------------------------------------------- checks

const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : null);

function check(id, n, extra, grams) {
  for (const k of ['calories', 'protein', 'carbs', 'fat']) if (n[k] !== null && (n[k] < 0 || n[k] > 3000)) fail(`${id}: ${k} ${n[k]} out of range`);
  if (n.calories === null || n.protein === null) fail(`${id}: calories and protein are required for an offered item`);
  if (grams !== null && !(grams > 0 && grams < 3000)) fail(`${id}: serving ${grams} g out of range`);
  if (n.calories !== null && n.protein !== null && n.carbs !== null && n.fat !== null) {
    // Energy from the stated macros (Atwater 4/4/9). Labels round each value, so a margin is allowed; a shifted
    // column or a lost decimal point lands far outside it.
    const atwater = 4 * n.protein + 4 * n.carbs + 9 * n.fat;
    if (Math.abs(atwater - n.calories) > Math.max(25, 0.12 * n.calories)) fail(`${id}: ${n.calories} kcal does not fit P${n.protein} C${n.carbs} F${n.fat} (${atwater})`);
  }
  if (extra.satFatG !== null && n.fat !== null && extra.satFatG > n.fat) fail(`${id}: saturated fat above total fat`);
  if (extra.fibreG !== null && n.carbs !== null && extra.fibreG > n.carbs) fail(`${id}: fibre above carbohydrate`);
  if (extra.sodiumMg !== null && (extra.sodiumMg < 0 || extra.sodiumMg > 6000)) fail(`${id}: sodium out of range`);
}

// ---------------------------------------------------------------- build

const ids = new Set();
const chains = spec.chains.map((chain) => {
  const out = { id: chain.id, name: chain.name, country: 'CA', status: chain.status, unavailable: chain.unavailable ?? null, sources: chain.sources, builds: chain.builds ?? {}, items: [] };
  if (chain.status !== 'available') return out;
  const rows = adapters[chain.adapter](chain);
  const sourceIds = new Set(chain.sources.map((s) => s.id));
  for (const s of chain.sources) if (!s.checked || !/^https:\/\//.test(s.url)) fail(`${chain.id}: source ${s.id} needs an https URL and a check date`);
  for (const it of chain.items) {
    const matches = rows.filter((r) => r.section === it.section && r.name === it.row);
    if (matches.length !== 1) { fail(`${chain.id}: "${it.section} / ${it.row}" found ${matches.length} times in ${chain.file}`); continue; }
    const v = matches[0].values;
    const unreliable = new Set(chain.unreliable?.[it.section] ?? []);
    const pick = (k) => (unreliable.has(k) ? null : num(v[k]));
    const id = `${chain.id}:${it.id}`;
    if (!/^1 [A-Za-z]/.test(it.portion)) fail(`${id}: portion must read "1 <noun>…" (${it.portion})`);
    if (!chain.builds?.[it.build] && chain.builds?.[it.build] !== null) fail(`${id}: unknown build "${it.build}"`);
    const source = it.source ?? chain.sources[0].id;
    if (!sourceIds.has(source)) fail(`${id}: unknown source ${source}`);
    const base = {
      id, name: it.name ?? it.row, sourceName: it.row, section: it.section, role: it.role, kind: it.kind, group: it.group,
      size: it.footlong ? '6-inch' : null, variantOf: null, portion: it.portion, grams: num(v.grams ?? null),
      nutrients: { calories: pick('calories'), protein: pick('protein'), carbs: pick('carbs'), fat: pick('fat') },
      extra: { sodiumMg: pick('sodium'), fibreG: pick('fibre'), satFatG: pick('satFat') },
      build: it.build, source, updated: matches[0].updated ?? null, derived: null, maxQuantity: it.maxQuantity ?? 1,
    };
    check(id, base.nutrients, base.extra, base.grams);
    for (const item of [base, ...(it.footlong ? [footlong(base)] : [])]) {
      if (ids.has(item.id)) fail(`duplicate id ${item.id}`);
      ids.add(item.id);
      out.items.push(item);
    }
  }
  if (out.items.length === 0) fail(`${chain.id}: available but no items`);
  return out;
});

/** The source's own rule: one footlong = two 6-inch servings. Every value doubled, nothing else changed. */
function footlong(b) {
  const twice = (o) => Object.fromEntries(Object.entries(o).map(([k, x]) => [k, x === null ? null : x * 2]));
  return { ...b, id: b.id.replace(/-6in$/, '') + '-footlong', size: 'Footlong', variantOf: b.id, portion: '1 sub (footlong)', grams: b.grams === null ? null : b.grams * 2,
    nutrients: twice(b.nutrients), extra: twice(b.extra), derived: 'footlong-double', build: 'footlong' };
}

const catalog = { version: spec.version, country: 'CA', checked: spec.checked, chains };
const json = JSON.stringify(catalog, null, 1) + '\n';

// ---------------------------------------------------------------- manifest

function manifestText() {
  const l = [];
  l.push('# Restaurant sources and coverage', '', `Generated by \`node scripts/build-restaurant-catalog.mjs\` from \`scripts/restaurant-catalog.spec.json\`. Do not edit by hand.`, '');
  l.push(`Catalog version **${spec.version}**, checked **${spec.checked}**. Country: Canada. Not every location sells every item; this is a selection, not the full menu.`, '');
  for (const c of chains) {
    l.push(`## ${c.name} Canada (\`${c.id}\`)`, '');
    for (const s of c.sources) l.push(`- Source: ${s.title}. <${s.url}>. Published: ${s.published ?? 'not stated'}${s.publishedNote ? ` (${s.publishedNote})` : ''}. Checked: ${s.checked}.${s.sha256 ? ` SHA-256 of the document read: \`${s.sha256}\`.` : ''}`);
    if (c.status !== 'available') { l.push('', `**Not available.** ${c.unavailable}`, ''); continue; }
    l.push('', `${c.items.length} options (${c.items.filter((i) => i.derived).length} derived by the source's own doubling rule).`, '');
    l.push('| Item | Portion | g | kcal | Protein g | Carbs g | Fat g | Sodium mg | Build |', '|---|---|---|---|---|---|---|---|---|');
    for (const i of c.items) {
      const n = i.nutrients, d = (x) => (x === null ? '—' : x);
      l.push(`| ${i.name} | ${i.portion} | ${d(i.grams)} | ${d(n.calories)} | ${d(n.protein)} | ${d(n.carbs)} | ${d(n.fat)} | ${d(i.extra.sodiumMg)} | ${i.build}${i.updated ? `, row updated ${i.updated}` : ''} |`);
    }
    l.push('');
    for (const [k, v] of Object.entries(c.builds)) if (v) l.push(`- \`${k}\`: ${v}`);
    l.push('');
  }
  return l.join('\n');
}

if (problems.length) {
  console.error(problems.map((p) => `✗ ${p}`).join('\n'));
  process.exit(1);
}
const md = manifestText();
if (process.argv.includes('--check')) {
  const stale = [...outputs.map((o) => [o, json]), [manifest, md]].filter(([o, text]) => !fs.existsSync(path.join(root, o)) || fs.readFileSync(path.join(root, o), 'utf8') !== text);
  if (stale.length) { console.error(`Out of date: ${stale.map(([o]) => o).join(', ')}. Run node scripts/build-restaurant-catalog.mjs`); process.exit(1); }
  console.log('Restaurant catalog up to date.');
} else {
  for (const o of outputs) fs.writeFileSync(path.join(root, o), json);
  fs.writeFileSync(path.join(root, manifest), md);
  const counts = chains.map((c) => `${c.id} ${c.items.length}`).join(', ');
  console.log(`Wrote catalog ${spec.version}: ${counts}`);
}
