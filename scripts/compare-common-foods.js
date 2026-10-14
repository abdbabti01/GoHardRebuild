// Writes docs/COMMON_FOODS_COMPARISON.md: each legacy name beside the catalog record that replaced it.
// Run: node scripts/compare-common-foods.js (expects the brief's legacy-food-catalog-reference.json at the path below).
const fs = require('fs');
const legacy = require('C:/dev/GoHard_UI_Food_Search/legacy-food-catalog-reference.json').foods;
const cat = require('C:/dev/GoHardRebuild/app/assets/data/common-foods.json');
const norm = (s) => s.toLowerCase().replace(/\(.*?\)/g, '').replace(/[^a-z ]/g, ' ').replace(/\s+/g, ' ').trim();
const fmt = (n) => (n == null ? '—' : String(Math.round(n * 10) / 10));
// Legacy name → catalog id where the everyday name was reworded.
const map = {
  'Ground Beef (90% lean)': 'ground-beef-90', 'Tuna (canned in water)': 'tuna-canned-water', 'Cottage Cheese (Low-fat)': 'cottage-cheese-low-fat',
  'Whey Protein Powder': 'whey-protein-powder', 'Milk (2%)': 'milk-2', 'Almond Milk (Unsweetened)': 'almond-milk-unsweetened', 'Dark Chocolate (70%)': 'dark-chocolate-70',
  'Popcorn (Air-popped)': 'popcorn-air-popped', 'Coffee (Black)': 'coffee-black', 'Oatmeal': 'oatmeal', 'Skim Milk': 'skim-milk',
};
const byId = Object.fromEntries(cat.foods.map((f) => [f.id, f]));
const find = (name) => byId[map[name]] ?? cat.foods.find((f) => norm(f.name) === norm(name)) ?? cat.foods.find((f) => f.aliases.some((a) => norm(a) === norm(name)));
const rows = [];
const missing = [];
for (const l of legacy) {
  const f = find(l.Name);
  if (!f) { missing.push(l.Name); continue; }
  const i = f.item, kcal = i.nutrients.calories, prot = i.nutrients.protein;
  // The same amount the old row described, from the record, when the units agree (both grams).
  const sameAmount = l.ServingUnit === 'g' && i.basis === '100g' && kcal != null ? kcal * l.ServingSize / 100 : null;
  const protSame = l.ServingUnit === 'g' && i.basis === '100g' && prot != null ? prot * l.ServingSize / 100 : null;
  const p = f.portion ? i.servings.find((s) => s.label === f.portion || s.label.startsWith(f.portion)) : null;
  rows.push(`| ${l.Name} | ${f.name} · ${f.qualifier} | ${f.category}${f.category === l.Category ? '' : ` (was ${l.Category})`} | [${i.sourceId}](https://fdc.nal.usda.gov/food-details/${i.sourceId}/nutrients) ${i.description?.split(' · ')[0] ?? ''} | ${p ? `${p.label}${p.grams ? ` = ${fmt(p.grams)} g` : ''}` : '100 g'} | ${l.ServingSize} ${l.ServingUnit}: ${fmt(l.Calories)} kcal, ${fmt(l.Protein)} g | ${sameAmount == null ? 'not comparable (units differ)' : `${fmt(sameAmount)} kcal, ${fmt(protSame)} g`} |`);
}
const used = new Set(rows.length ? cat.foods.filter((f) => legacy.some((l) => find(l.Name) === f)).map((f) => f.id) : []);
const extra = cat.foods.filter((f) => !used.has(f.id)).map((f) => f.name);
const out = `# Common foods compared with the original GoHard catalog

Generated from \`app/assets/data/common-foods.json\` (version ${cat.version}) and the original app's \`FoodSeedData.cs\`
(GoHardAPI revision 27ac638, 76 definitions, supplied as \`legacy-food-catalog-reference.json\`). The original values
had no source IDs or citations; they are shown only for comparison and are not used anywhere in the app.

**Summary.** ${legacy.length} original names; ${rows.length} are covered by a traceable USDA FoodData Central record and
${missing.length} ${missing.length === 1 ? "is" : "are"} not: ${missing.join(', ')}.${extra.length ? ` Not in the original list: ${extra.join(', ')}.` : ''} The catalog has ${cat.foods.length} foods.
Every item is the record exactly as the rebuild API returns it from USDA (source \`usda\`, the FDC ID, the record's
own values, basis and portions); the everyday name, preparation label, category, aliases and starting portion are
GoHard's labels around it. Where the original row and the record differ, the record is what the app uses.

Why some rows differ noticeably:
- **Ground beef 90%**: the record is the cooked (broiled) patty; the original 176 kcal matches raw.
- **Tofu**: the record is firm tofu; the original 76 kcal matches regular.
- **Whey protein**: the closest generic record is "Protein powder, whey based"; the original was a branded-style estimate.
- **Almonds, walnuts**: Foundation/SR Legacy records were chosen over FNDDS ones, whose energy ran 8–12% above the others.
- **Drinks** (milk, juice, coconut water): values stay per 100 g with the record's gram portions ("1 cup = 244 g");
  no gram-to-millilitre density was assumed, so "1 cup" is offered only where the record states its weight.
- **Starting portion**: a count portion only where the record states one ("1 egg = 50 g"); otherwise 100 g.

| Original name | Catalog food · preparation | Category | USDA record (FDC ID, data type) | Starts at | Original row | Record, same amount |
|---|---|---|---|---|---|---|
${rows.join('\n')}

Rebuild: \`node scripts/build-common-foods.mjs --cache <dir> [--offline]\`; spec: \`scripts/common-foods.spec.json\`.
`;
fs.writeFileSync('C:/dev/GoHardRebuild/docs/COMMON_FOODS_COMPARISON.md', out);
console.log('rows', rows.length, 'missing', missing, 'extra', extra);
