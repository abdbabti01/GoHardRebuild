// One real owner-video round trip against a running API and object store (docs/OWNER_EXERCISE_VIDEOS.md › Local
// verification): draft → signed direct upload → complete → worker (FFmpeg) → preview → details → publish → public
// catalogue → download the published clip and check its SHA-256. It does what the app does, over HTTP.
//
//   node scripts/media-roundtrip.mjs --api http://localhost:5131 --email <owner> --password <pw> --clip <file> --key <catalogKey>
//        [--licensed "Creator|Licence|https://licence|https://source"] [--store-host localhost:8333] [--unpublish]
//
// --store-host: where this computer reaches the store when the links are signed for another host (the emulator's 10.0.2.2);
// the request keeps the signed Host header. Prints statuses only, never a signed URL or token.
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync, statSync } from 'node:fs';
import http from 'node:http';
import https from 'node:https';

const args = process.argv.slice(2);
const arg = (n) => (args.includes(`--${n}`) ? args[args.indexOf(`--${n}`) + 1] : undefined);
const api = arg('api') ?? 'http://localhost:5131';
const clip = arg('clip'), key = arg('key');
if (!clip || !key || !arg('email')) throw new Error('Give --email, --password, --clip and --key.');

async function call(method, path, body, token) {
  const r = await fetch(`${api}/api/v1${path}`, {
    method, headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await r.text();
  return { status: r.status, data: text ? JSON.parse(text) : null };
}

/** PUT/GET to a signed URL, optionally through another address while keeping the signed Host header. */
function store(method, url, { body, headers = {} } = {}) {
  const u = new URL(url);
  const via = arg('store-host');
  const [host, port] = via ? via.split(':') : [u.hostname, u.port];
  const lib = u.protocol === 'https:' ? https : http;
  return new Promise((resolve, reject) => {
    const req = lib.request({ method, host, port, path: u.pathname + u.search, headers: { host: u.host, ...headers } }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

const login = await call('POST', '/auth/login', { email: arg('email'), password: arg('password') });
if (login.status !== 200) throw new Error(`login ${login.status}`);
const token = login.data.accessToken;
const access = await call('GET', '/exercise-media/access', undefined, token);
console.log('access', JSON.stringify(access.data));
if (!access.data.canManage || !access.data.ready) throw new Error('This account cannot manage, or the server is not set up.');

const bytes = readFileSync(clip);
const type = clip.toLowerCase().endsWith('.mov') ? 'video/quicktime' : 'video/mp4';
const draftId = randomUUID();
const created = await call('POST', '/exercise-media/manage/drafts', { operationId: randomUUID(), draftId, catalogKey: key, contentType: type, bytes: statSync(clip).size }, token);
console.log('draft', created.status, created.data.status, created.data.data?.status);
const link = await call('POST', `/exercise-media/manage/drafts/${draftId}/upload-url`, undefined, token);
console.log('upload link', link.status, `expires ${link.data.expiresAtUtc}`);
const put = await store('PUT', link.data.url, { body: bytes, headers: { 'content-type': type, 'content-length': bytes.length } });
console.log('direct upload', put.status, `${(bytes.length / 1048576).toFixed(1)} MiB`);
const done = await call('POST', `/exercise-media/manage/drafts/${draftId}/complete`, { operationId: randomUUID() }, token);
console.log('complete', done.status, done.data.data?.status ?? done.data.code);

let draft;
const started = Date.now();
for (;;) {
  const list = await call('GET', '/exercise-media/manage', undefined, token);
  draft = list.data.drafts.find((d) => d.id === draftId);
  if (!['queued', 'processing'].includes(draft.status)) break;
  if (Date.now() - started > 15 * 60_000) throw new Error('processing took too long');
  await new Promise((r) => setTimeout(r, 2000));
}
console.log('processed', draft.status, draft.error ?? '', `${((Date.now() - started) / 1000).toFixed(0)} s`,
  draft.status === 'ready' ? `${draft.width}x${draft.height} ${draft.durationSeconds}s ${(draft.bytes / 1048576).toFixed(2)} MiB` : '');
if (draft.status !== 'ready') process.exit(2);

const preview = await call('GET', `/exercise-media/manage/drafts/${draftId}/preview`, undefined, token);
const previewClip = await store('GET', preview.data.clipUrl, { headers: { range: 'bytes=0-99' } });
console.log('preview', previewClip.status, previewClip.headers['content-type'], previewClip.headers['content-range'] ?? '');

const [creator, licence, licenceUrl, source] = (arg('licensed') ?? '').split('|');
const details = await call('PUT', `/exercise-media/manage/drafts/${draftId}/details`, {
  operationId: randomUUID(), revision: draft.revision, variant: arg('variant') ?? `${key} (round-trip check)`, title: arg('title') ?? key,
  creator: creator || 'GoHard', rightsKind: licence ? 'licensed' : 'original', licenceName: licence || null, licenceUrl: licenceUrl || null,
  sourceUrl: source || null, rightsNotice: licence ? 'Transcoded to H.264, muted, by GoHard.' : 'Original footage, published by GoHard.', rightsConfirmed: true,
}, token);
console.log('details', details.status, details.data.status, details.data.code ?? '');
const published = await call('POST', `/exercise-media/manage/drafts/${draftId}/publish`, { operationId: randomUUID(), revision: details.data.revision }, token);
console.log('publish', published.status, published.data.status, published.data.code ?? '');

const catalog = await call('GET', '/exercise-media/catalog', undefined, token);
const entry = catalog.data.entries.find((e) => e.catalogKey === key);
console.log('catalogue', `revision ${catalog.data.revision}`, `origin ${catalog.data.mediaOrigin}`, entry ? 'entry present' : 'NO ENTRY');
const pub = await store('GET', entry.clipUrl);
const sha = createHash('sha256').update(pub.body).digest('hex');
console.log('public clip', pub.status, pub.headers['content-type'], `${pub.body.length} bytes`, sha === entry.sha256 ? 'sha256 matches' : 'SHA MISMATCH',
  pub.headers['cache-control'] ?? '(no cache-control)');
const range = await store('GET', entry.clipUrl, { headers: { range: 'bytes=0-1023' } });
console.log('public range', range.status, range.headers['content-range'] ?? '');
const anonStaging = await store('GET', preview.data.clipUrl.split('?')[0]);
console.log('staging without a signature', anonStaging.status, anonStaging.status >= 400 ? '(private, as it must be)' : 'EXPOSED');
if (args.includes('--unpublish')) {
  const un = await call('POST', `/exercise-media/manage/keys/${key}/unpublish`, { operationId: randomUUID(), versionId: entry.id }, token);
  console.log('unpublish', un.status, un.data.status);
}
console.log(`RESULT ${sha === entry.sha256 ? 'OK' : 'FAIL'} ${entry.clipUrl.replace(/^https?:\/\/[^/]+/, '')}`);
