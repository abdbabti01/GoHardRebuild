// Builds app/assets/data/common-foods.json: the small catalog of everyday foods the app can find offline.
//
// Every food is one real USDA FoodData Central record, taken exactly as the GoHard rebuild API normalizes it in
// GET /api/v1/foods/search (values, basis and portions untouched). This script only chooses WHICH record stands
// for "Eggs" or "White rice" (the fdcId in SPEC, picked by a person from the candidates) and adds what the
// record cannot know: a short name, a preparation line, a category and search aliases. It never writes a
// nutrient, a portion or a source ID of its own.
//
//   node scripts/build-common-foods.mjs --cache <dir outside the repo> [--api <origin>] [--candidates [id,id]] [--offline]
//
//   --candidates   print what the API returned for each (or the named) entry, to choose an fdcId from
//   --offline      never touch the network: fail if an answer is not in the cache
//
// Answers are cached per query in --cache, so a re-run asks the API nothing it already asked. When something
// must be fetched, ONE disposable account is registered on the testing API, used at no more than 20 lookups a
// minute, and deleted at the end, also when the run fails. Never point this at anything but the rebuild's
// testing API.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';

const VERSION = 1;
const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const value = (name) => (args.includes(`--${name}`) ? args[args.indexOf(`--${name}`) + 1] : undefined);
const api = (value('api') ?? 'https://gohardrebuild-production.up.railway.app').replace(/\/$/, '');
const cacheDir = value('cache');
if (!cacheDir) throw new Error('Give --cache <directory outside the repository>.');
mkdirSync(cacheDir, { recursive: true });
const out = join(dirname(fileURLToPath(import.meta.url)), '..', 'app', 'assets', 'data', 'common-foods.json');
const MAX_SEARCHES = 200, SPACING_MS = 3200;

// scripts/common-foods.spec.json, one row per everyday food:
//   [id, name shown in rows, preparation shown under it, category, query sent to the API, chosen fdcId, aliases, portion]
// Aliases only help a search find the entry (English and French); they never change which food it is.
// `portion` is the label of one of the record's OWN portions ("1 egg") that a new entry starts from; null starts
// at 100 g. It selects among what the source states and is refused if the record has no such portion.
// An entry with no query or no fdcId is left out of the catalog and listed at the end of the run.
const SPEC = JSON.parse(readFileSync(join(dirname(fileURLToPath(import.meta.url)), 'common-foods.spec.json'), 'utf8'));

// ---------------------------------------------------------------------------------------------- testing API
let account = null, searches = 0, last = 0;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function call(method, path, body, token) {
  const r = await fetch(`${api}/api/v1${path}`, {
    method, signal: AbortSignal.timeout(40000),
    headers: { ...(body ? { 'content-type': 'application/json' } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`${method} ${path}: HTTP ${r.status} ${text.slice(0, 200)}`);
  return text ? JSON.parse(text) : null;
}

async function search(query) {
  const file = join(cacheDir, `${query.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')}.json`);
  if (existsSync(file)) return JSON.parse(readFileSync(file, 'utf8'));
  if (flag('offline')) throw new Error(`Not in the cache and --offline was given: "${query}"`);
  if (searches >= MAX_SEARCHES) throw new Error(`Stopped at ${MAX_SEARCHES} searches in one run.`);
  if (!account) {
    const password = randomUUID().replace(/-/g, ''); // random, used once, never printed
    const r = await call('POST', '/auth/register', { email: `catalog-${Date.now()}@example.test`, password, displayName: 'Catalog build' });
    account = { token: r.accessToken, password };
    console.error('Registered one disposable account.');
  }
  let results;
  for (let attempt = 1; results === undefined; attempt++) {
    if (searches >= MAX_SEARCHES) throw new Error(`Stopped at ${MAX_SEARCHES} searches in one run.`);
    await sleep(Math.max(0, last + SPACING_MS * attempt - Date.now()));
    last = Date.now();
    searches++;
    try {
      results = (await call('GET', `/foods/search?q=${encodeURIComponent(query)}`, null, account.token)).results;
    } catch (e) {
      // The provider not answering is passing trouble; anything else (quota, not configured) stops the run.
      if (attempt >= 4 || !/HTTP 503/.test(e.message)) throw e;
      console.error(`"${query}": provider unavailable, trying again (${attempt}).`);
    }
  }
  const answer = { query, retrievedAtUtc: new Date().toISOString(), results };
  writeFileSync(file, JSON.stringify(answer));
  return answer;
}

async function deleteAccount() {
  if (!account) return;
  await call('DELETE', '/account', { password: account.password }, account.token);
  let gone = false;
  try { await call('GET', '/me', null, account.token); } catch { gone = true; }
  if (!gone) throw new Error('The disposable account still answers after deletion.');
  console.error('Deleted the disposable account; its token no longer works.');
}

// ---------------------------------------------------------------------------------------------- build
const CATEGORIES = ['Proteins', 'Carbohydrates', 'Vegetables', 'Fruits', 'Dairy', 'Fats & Oils', 'Snacks', 'Beverages'];
const line = (i) => `${i.sourceId.padEnd(8)} ${i.name}${i.brand ? ` [${i.brand}]` : ''} | ${i.description ?? ''} | ${i.basis} kcal ${i.nutrients.calories} P ${i.nutrients.protein} C ${i.nutrients.carbs} F ${i.nutrients.fat} | ${i.servings.map((s) => `${s.label}=${s.grams ?? `${s.milliliters}ml`}`).join('; ')}`;

try {
  const only = flag('candidates') && value('candidates') && !value('candidates').startsWith('--') ? value('candidates').split(',') : null;
  const foods = [], left = [];
  for (const [id, name, qualifier, category, query, fdcId, aliases, portion = null] of SPEC) {
    if (only && !only.includes(id)) continue;
    if (!CATEGORIES.includes(category)) throw new Error(`${id}: unknown category ${category}`);
    if (query == null) { left.push(id); continue; }
    const answer = await search(query);
    if (flag('candidates')) {
      console.log(`\n## ${id} — ${name} (${qualifier}) — "${query}"${fdcId ? ` — chosen ${fdcId}` : ''}`);
      for (const i of answer.results) if (!i.brand) console.log(`  ${line(i)}`);
      continue;
    }
    if (fdcId == null) { left.push(id); continue; }
    const item = answer.results.find((i) => i.source === 'usda' && i.sourceId === String(fdcId));
    if (!item) throw new Error(`${id}: the answer to "${query}" has no record ${fdcId}`);
    if (!name || !qualifier) throw new Error(`${id}: name and qualifier are required`);
    if (portion != null && !item.servings.some((s) => s.label === portion && (s.grams > 0 || s.milliliters > 0))) throw new Error(`${id}: the record states no portion "${portion}"`);
    foods.push({ id, name, qualifier, category, aliases, portion, item });
  }
  if (!flag('candidates')) {
    if (new Set(foods.map((f) => f.id)).size !== foods.length || new Set(foods.map((f) => f.item.sourceId)).size !== foods.length) throw new Error('Two entries share an id or a record.');
    const retrieved = foods.map((f) => f.item.retrievedAtUtc.slice(0, 10)).sort();
    mkdirSync(dirname(out), { recursive: true });
    writeFileSync(out, `${JSON.stringify({
      version: VERSION,
      provenance: {
        source: 'USDA FoodData Central (public domain, CC0)',
        retrieved: retrieved[0] === retrieved.at(-1) ? retrieved[0] : `${retrieved[0]} to ${retrieved.at(-1)}`,
        method: 'Each item is one FoodData Central record exactly as the GoHard rebuild API normalized it in GET /api/v1/foods/search: sourceId is the FDC ID, and the values, basis and portions are the record\'s own. The record for each everyday name was chosen by review. Name, qualifier, category and aliases are GoHard\'s labels for finding the food; they are not USDA data. Built by scripts/build-common-foods.mjs from scripts/common-foods.spec.json.',
      },
      categories: CATEGORIES,
      foods,
    }, null, 1)}\n`);
    console.error(`Wrote ${foods.length} foods to ${out}. Left out: ${left.join(', ') || 'none'}.`);
  }
} finally {
  await deleteAccount();
  console.error(`Searches sent in this run: ${searches}.`);
}
