// Builds app/assets/data/exercise-media.json (the app's exercise demonstration manifest) and
// docs/EXERCISE_DEMOS_COVERAGE.md from the reviewed choices in scripts/exercise-demos.spec.json.
//
// A person chose WHICH wger clip or still stands for each catalogue key (after watching it). This script takes the
// provider's own metadata for exactly those IDs (licence, author, size, codec, dimensions), measures the clips itself
// (bytes, SHA-256) and refuses anything that breaks the first-release rules: HTTPS on an allowed host, a named author,
// a Creative Commons licence, not AI-generated, H.264, at most 20 MiB. It never searches, guesses or picks a first hit.
//
//   node scripts/build-exercise-demos.mjs --cache <dir outside the repo> [--offline]
//
// Clips are kept in --cache, so a re-run downloads nothing it already has (the reviewed set is five
// clips, 35.1 MiB). --offline never touches the network and uses only cached API answers and clips.
// Posters (app/assets/demos/<key>.jpg) are made on Windows by scripts/exercise-demo-posters.ps1 and only checked here.
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const args = process.argv.slice(2);
const cacheDir = args.includes('--cache') ? args[args.indexOf('--cache') + 1] : undefined;
const offline = args.includes('--offline');
if (!cacheDir) throw new Error('Give --cache <directory outside the repository>.');
mkdirSync(cacheDir, { recursive: true });

const MAX_CLIP_BYTES = 20 * 1024 * 1024;
const HOSTS = ['wger.de'];
const API = 'https://wger.de/api/v2';
const spec = JSON.parse(readFileSync(join(here, 'exercise-demos.spec.json'), 'utf8'));
const catalog = JSON.parse(readFileSync(join(root, 'api', 'src', 'GoHard.Api', 'Data', 'exercise-catalog.json'), 'utf8'));
const entries = Array.isArray(catalog) ? catalog : Object.values(catalog).find(Array.isArray);
const names = Object.fromEntries(entries.map((e) => [e.key, e.name]));

const problems = [];
const fail = (key, why) => problems.push(`${key}: ${why}`);

async function api(path) {
  const file = join(cacheDir, `api_${path.replace(/[^a-z0-9]+/gi, '_')}.json`);
  if (existsSync(file)) return JSON.parse(readFileSync(file, 'utf8'));
  if (offline) throw new Error(`Not cached: ${path}`);
  const r = await fetch(`${API}/${path}`, { headers: { Accept: 'application/json' } });
  if (!r.ok) throw new Error(`${path}: HTTP ${r.status}`);
  const j = await r.json();
  writeFileSync(file, JSON.stringify(j));
  return j;
}

async function clip(url, id) {
  const file = join(cacheDir, `clip_${id}`);
  if (!existsSync(file)) {
    if (offline) throw new Error(`Clip ${id} not cached.`);
    const r = await fetch(url);
    if (!r.ok) throw new Error(`clip ${id}: HTTP ${r.status}`);
    writeFileSync(file, Buffer.from(await r.arrayBuffer()));
  }
  const bytes = readFileSync(file);
  return { bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex'), moovFirst: moovBeforeMdat(bytes) };
}

/** Whether the MP4/MOV index comes before the media data, so playback can start before the whole file arrives. */
function moovBeforeMdat(b) {
  for (let o = 0; o + 8 <= b.length;) {
    let size = b.readUInt32BE(o);
    const type = b.toString('latin1', o + 4, o + 8);
    if (type === 'moov') return true;
    if (type === 'mdat') return false;
    if (size === 1) size = Number(b.readBigUInt64BE(o + 8));
    if (size < 8) return false;
    o += size;
  }
  return false;
}

const licences = Object.fromEntries((await api('license/?limit=50')).results.map((l) => [l.id, l]));
const ccName = (l) => ({ 'CC-BY-SA 3': 'CC BY-SA 3.0', 'CC-BY-SA 4': 'CC BY-SA 4.0', 'CC-BY 4': 'CC BY 4.0', CC0: 'CC0 1.0' })[l.short_name];
const licenceOf = (key, id) => {
  const l = licences[id];
  if (!l || !ccName(l)) fail(key, `licence ${id} is not a Creative Commons licence this app accepts`);
  return l ? { licence: ccName(l) ?? l.short_name, licenceUrl: l.url.replace('http://', 'https://').replace(/deed\.en$/, '') } : {};
};
const page = (exerciseId) => `https://wger.de/en/exercise/${exerciseId}/view-base`;
const exists = (p) => existsSync(join(root, 'app', p));

const media = [];
for (const v of spec.videos) {
  const r = await api(`video/${v.wgerVideo}/`);
  const url = new URL(r.video);
  if (r.exercise !== v.wgerExercise) fail(v.catalogKey, `video ${v.wgerVideo} belongs to exercise ${r.exercise}, not ${v.wgerExercise}`);
  if (url.protocol !== 'https:' || !HOSTS.includes(url.hostname)) fail(v.catalogKey, `${r.video} is not HTTPS on an allowed host`);
  if (!r.license_author?.trim()) fail(v.catalogKey, 'no author');
  if (r.codec !== 'h264') fail(v.catalogKey, `codec ${r.codec}, not H.264`);
  const m = await clip(r.video, v.wgerVideo);
  if (m.bytes !== r.size) fail(v.catalogKey, `measured ${m.bytes} bytes, provider says ${r.size}`);
  if (m.bytes > MAX_CLIP_BYTES) fail(v.catalogKey, `${m.bytes} bytes is over the 20 MiB limit`);
  if (!m.moovFirst) fail(v.catalogKey, 'the index (moov) is after the media data');
  const poster = `assets/demos/${v.catalogKey}.jpg`;
  if (!exists(poster)) fail(v.catalogKey, `${poster} is missing (run scripts/exercise-demo-posters.ps1)`);
  const lic = licenceOf(v.catalogKey, r.license);
  media.push({
    catalogKey: v.catalogKey, kind: 'video', status: 'approved', poster, variant: v.variant, rationale: v.rationale,
    video: {
      url: r.video, bytes: m.bytes, sha256: m.sha256, codec: 'H.264', container: url.pathname.toLowerCase().endsWith('.mov') ? 'QuickTime (.mov)' : 'MP4',
      durationSeconds: Number(r.duration), width: r.width, height: r.height,
    },
    provider: { name: 'wger', exerciseId: v.wgerExercise, mediaId: v.wgerVideo, page: page(v.wgerExercise), retrieved: spec.reviewed },
    credit: { creator: r.license_author.trim(), ...lic, attribution: `Video by ${r.license_author.trim()}, via wger.de, ${lic.licence}` },
    changes: `Played and saved exactly as published (no transcoding or cropping). Poster: one frame at ${Math.round(v.posterAt * 100)} % of the clip, scaled to 640 px wide, JPEG.`,
    download: true,
  });
}

for (const s of spec.stills) {
  const imgs = [];
  for (const id of s.wgerImages) {
    const r = await api(`exerciseimage/${id}/`);
    if (r.exercise !== s.wgerExercise) fail(s.catalogKey, `image ${id} belongs to exercise ${r.exercise}`);
    if (r.is_ai_generated) fail(s.catalogKey, `image ${id} is marked AI-generated`);
    if (!r.license_author?.trim()) fail(s.catalogKey, `image ${id} has no author`);
    imgs.push(r);
  }
  const poster = `assets/demos/${s.catalogKey}.jpg`;
  if (!exists(poster)) fail(s.catalogKey, `${poster} is missing (run scripts/exercise-demo-posters.ps1)`);
  const authors = [...new Set(imgs.map((i) => i.license_author.trim()))];
  const lic = licenceOf(s.catalogKey, imgs[0].license);
  if (imgs.some((i) => i.license !== imgs[0].license)) fail(s.catalogKey, 'the two images have different licences');
  media.push({
    catalogKey: s.catalogKey, kind: 'still', status: 'approved', poster, variant: s.variant, rationale: s.rationale,
    provider: { name: 'wger', exerciseId: s.wgerExercise, mediaId: s.wgerImages.join('+'), page: page(s.wgerExercise), retrieved: spec.reviewed,
      originals: imgs.map((i) => i.image) },
    credit: { creator: authors.join(', '), ...lic, attribution: `Illustrations by ${authors.join(', ')}, via wger.de, ${lic.licence}` },
    changes: "The provider's 400 px thumbnails of the start and finish positions, placed side by side on white (640 x 320), JPEG.",
    download: false,
  });
}

const mapped = new Set(media.map((m) => m.catalogKey));
for (const key of Object.keys(names)) if (!mapped.has(key) && !spec.gaps[key]) fail(key, 'neither mapped nor given a gap reason');
for (const key of [...mapped, ...Object.keys(spec.gaps), ...Object.keys(spec.technique)]) if (!names[key]) fail(key, 'not a catalogue key');
const sourceIds = new Set(spec.techniqueSources.map((s) => s.id));
for (const [key, t] of Object.entries(spec.technique)) for (const id of t.sources) if (!sourceIds.has(id)) fail(key, `unknown technique source ${id}`);

if (problems.length) {
  console.error(problems.join('\n'));
  process.exit(1);
}

const manifest = {
  version: 1,
  reviewed: spec.reviewed,
  reviewNote: spec.reviewNote,
  allowedHosts: HOSTS,
  maxClipBytes: MAX_CLIP_BYTES,
  media: media.sort((a, b) => a.catalogKey.localeCompare(b.catalogKey)),
  techniqueReviewNote: 'Written by the developer from the exercise-specific source named with it, checked on the date shown. Not reviewed by a qualified coach.',
  techniqueSources: spec.techniqueSources,
  technique: Object.entries(spec.technique).map(([catalogKey, t]) => ({ catalogKey, ...t })),
};
writeFileSync(join(root, 'app', 'assets', 'data', 'exercise-media.json'), `${JSON.stringify(manifest, null, 2)}\n`);

const mib = (b) => `${(b / 1048576).toFixed(2)} MiB`;
const rows = Object.keys(names).map((key) => {
  const m = media.find((x) => x.catalogKey === key);
  const status = m?.kind === 'video' ? 'Video' : m?.kind === 'still' ? 'Still only' : 'Written guide only';
  const src = m ? `wger exercise ${m.provider.exerciseId}, ${m.kind === 'video' ? 'video' : 'images'} ${m.provider.mediaId}` : '—';
  const props = m?.video ? `${m.video.codec} ${m.video.container}, ${m.video.width}x${m.video.height}, ${m.video.durationSeconds} s, ${mib(m.video.bytes)}` : '';
  const credit = m ? `${m.credit.creator}, ${m.credit.licence}` : '';
  const text = spec.technique[key] ? `Setup/Movement from ${spec.technique[key].sources.join(', ')}` : 'Existing cues (not source-checked)';
  const note = m ? m.variant : '';
  const gap = spec.gaps[key] ?? '';
  return `| \`${key}\` | ${names[key]} | ${status} | ${src} | ${props} | ${credit} | ${text} | ${[note, gap].filter(Boolean).join(' ')} |`;
});
const count = (k) => media.filter((m) => m.kind === k).length;
writeFileSync(join(root, 'docs', 'EXERCISE_DEMOS_COVERAGE.md'), [
  '# Exercise demonstrations: coverage',
  '',
  `Generated by \`scripts/build-exercise-demos.mjs\` from \`scripts/exercise-demos.spec.json\` (reviewed ${spec.reviewed}). One row per built-in catalogue key.`,
  `Video ${count('video')} · still only ${count('still')} · written guide only ${Object.keys(names).length - media.length} (of ${Object.keys(names).length}).`,
  '',
  'Clips: SHA-256 and exact bytes are in `app/assets/data/exercise-media.json`. Every clip is streamed from, or saved from, its wger URL unchanged.',
  '',
  '| Key | Name | Status | Source | Media | Creator, licence | Technique text | Variant shown / gap reason |',
  '|---|---|---|---|---|---|---|---|',
  ...rows,
  '',
].join('\n'));
console.log(`OK: ${count('video')} videos, ${count('still')} stills, ${Object.keys(names).length - media.length} without media; clips total ${mib(media.reduce((s, m) => s + (m.video?.bytes ?? 0), 0))}.`);
