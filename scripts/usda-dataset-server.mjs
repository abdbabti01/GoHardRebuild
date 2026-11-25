// A local stand-in for USDA FoodData Central's search endpoint, answered from the official downloadable datasets
// (https://fdc.nal.usda.gov/download-datasets/), so the common-food catalog can be built through the GoHard API's own
// normalization (UsdaProvider.Parse) without asking the live API (no DEMO_KEY, no rate limit). Not a provider: it only
// answers `query=fdc <id>` with that one record, converted to the search answer's shape, and nothing for anything else.
//
//   node scripts/usda-dataset-server.mjs <dir with the unpacked JSON datasets> [port, default 5139]
//   API: GOHARD_FoodData__UsdaApiKey=dataset GOHARD_FoodData__UsdaBaseUrl=http://127.0.0.1:5139/
//
// The datasets stay outside git (about 300 MB). The conversion keeps the record's own values: every nutrient with its
// ID, unit and amount; FNDDS portions as `foodMeasures` (disseminationText = portionDescription, gramWeight) in the
// dataset's order, and its "Additional Description" attributes, as the search answer gives them; Foundation and SR Legacy without measures, as the search answer has
// none for them. Checked against records the catalog took from the live API (scripts/build-common-foods.mjs --verify).
import { createServer } from 'node:http';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const dir = process.argv[2];
const port = Number(process.argv[3] ?? 5139);
if (!dir) throw new Error('Give the directory holding the unpacked FoodData Central JSON datasets.');
const byId = new Map();
const releases = [];
for (const file of readdirSync(dir).filter((f) => f.endsWith('.json'))) {
  const json = JSON.parse(readFileSync(join(dir, file), 'utf8'));
  for (const [key, foods] of Object.entries(json)) {
    if (!Array.isArray(foods)) continue;
    releases.push(`${key} (${file})`);
    for (const f of foods) byId.set(String(f.fdcId), f);
  }
}
console.log(`USDA datasets: ${byId.size} records from ${releases.join(', ')}`);

/** "10/31/2024" → "2024-10-31" (the search answer's publishedDate). */
const isoDate = (d) => {
  const m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(d ?? '');
  return m ? `${m[3]}-${m[1].padStart(2, '0')}-${m[2].padStart(2, '0')}` : d ?? null;
};

/** One dataset record in the shape of a FoodData Central search result. */
export function asSearchResult(f) {
  const survey = f.dataType === 'Survey (FNDDS)';
  return {
    fdcId: f.fdcId,
    description: f.description,
    dataType: f.dataType,
    publishedDate: isoDate(f.publicationDate),
    additionalDescriptions: survey ? (f.foodAttributes ?? []).filter((a) => a.foodAttributeType?.name === 'Additional Description').sort((a, b) => (a.rank ?? 0) - (b.rank ?? 0)).map((a) => a.value).join(';') || undefined : undefined,
    foodCategory: survey ? f.wweiaFoodCategory?.wweiaFoodCategoryDescription : f.foodCategory?.description,
    foodNutrients: (f.foodNutrients ?? [])
      .filter((n) => n.nutrient && typeof n.amount === 'number')
      .map((n) => ({ nutrientId: n.nutrient.id, nutrientName: n.nutrient.name, unitName: n.nutrient.unitName, value: n.amount })),
    foodMeasures: survey
      ? (f.foodPortions ?? []).filter((p) => p.portionDescription && p.gramWeight > 0)
          .map((p) => ({ disseminationText: p.portionDescription, gramWeight: p.gramWeight }))
      : [],
  };
}

createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  const query = (url.searchParams.get('query') ?? '').trim();
  const id = /^fdc[: ](\d+)$/i.exec(query)?.[1];
  const branded = /Branded/.test(url.searchParams.get('dataType') ?? '');
  const food = id && !branded ? byId.get(id) : null;
  const body = JSON.stringify({ totalHits: food ? 1 : 0, foods: food ? [asSearchResult(food)] : [] });
  console.log(new Date().toISOString(), query, branded ? 'branded' : 'generic', food ? 'found' : 'none');
  res.writeHead(200, { 'content-type': 'application/json' }).end(body);
}).listen(port, '127.0.0.1', () => console.log(`USDA dataset server on http://127.0.0.1:${port}`));
