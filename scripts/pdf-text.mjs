// Minimal PDF text extraction: inflate FlateDecode streams, decode ToUnicode CMaps, print text runs in reading order.
import fs from 'node:fs';
import zlib from 'node:zlib';

const buf = fs.readFileSync(process.argv[2]);
const s = buf.toString('latin1');
const objs = new Map();
const re = /(\d+)\s+0\s+obj([\s\S]*?)endobj/g;
let m;
while ((m = re.exec(s))) objs.set(+m[1], m[2]);

function streamOf(body) {
  const i = body.indexOf('stream');
  if (i < 0) return null;
  let start = i + 6;
  if (body[start] === '\r') start++;
  if (body[start] === '\n') start++;
  const end = body.lastIndexOf('endstream');
  const raw = Buffer.from(body.slice(start, end), 'latin1');
  if (!/FlateDecode/.test(body.slice(0, i))) return raw.toString('latin1');
  try { return zlib.inflateSync(raw, { finishFlush: zlib.constants.Z_SYNC_FLUSH }).toString('latin1'); } catch { return ''; }
}

// Object streams
for (const [, body] of [...objs]) {
  if (!/\/Type\s*\/ObjStm/.test(body)) continue;
  const data = streamOf(body);
  const n = +(/\/N\s+(\d+)/.exec(body)[1]), first = +(/\/First\s+(\d+)/.exec(body)[1]);
  const head = data.slice(0, first).trim().split(/\s+/).map(Number);
  for (let k = 0; k < n; k++) {
    const num = head[2 * k], off = head[2 * k + 1], next = k + 1 < n ? head[2 * k + 3] : data.length - first;
    if (!objs.has(num)) objs.set(num, data.slice(first + off, first + next));
  }
}

function cmap(text) {
  const map = new Map();
  for (const b of text.matchAll(/beginbfchar([\s\S]*?)endbfchar/g))
    for (const p of b[1].matchAll(/<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>/g)) map.set(parseInt(p[1], 16), hex16(p[2]));
  for (const b of text.matchAll(/beginbfrange([\s\S]*?)endbfrange/g))
    for (const p of b[1].matchAll(/<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(<[0-9A-Fa-f]+>|\[[^\]]*\])/g)) {
      const lo = parseInt(p[1], 16), hi = parseInt(p[2], 16);
      if (p[3].startsWith('<')) { const base = parseInt(p[3].slice(1, -1), 16); for (let c = lo; c <= hi; c++) map.set(c, String.fromCharCode(base + c - lo)); }
      else { const arr = [...p[3].matchAll(/<([0-9A-Fa-f]+)>/g)]; arr.forEach((a, j) => map.set(lo + j, hex16(a[1]))); }
    }
  return map;
}
function hex16(h) { let o = ''; for (let i = 0; i < h.length; i += 4) o += String.fromCharCode(parseInt(h.slice(i, i + 4), 16)); return o; }

const ref = (body, key) => { const r = new RegExp('/' + key + '\\s+(\\d+)\\s+0\\s+R').exec(body); return r ? +r[1] : null; };
function dict(body, key) {
  const i = body.indexOf('/' + key); if (i < 0) return null;
  let j = body.indexOf('<<', i); const r = /\/\w+\s+(\d+)\s+0\s+R/.exec(body.slice(i, i + 40));
  if (r && (j < 0 || body.indexOf(r[0], i) < j)) return objs.get(+r[1]) ?? null;
  let depth = 0, k = j;
  for (; k < body.length; k++) { if (body.startsWith('<<', k)) { depth++; k++; } else if (body.startsWith('>>', k)) { depth--; k++; if (!depth) break; } }
  return body.slice(j, k + 1);
}

const pages = [...objs].filter(([, b]) => /\/Type\s*\/Page\b/.test(b)).sort((a, b) => a[0] - b[0]);
for (const [pn, page] of pages) {
  const res = dict(page, 'Resources') ?? '';
  const fontsD = dict(res, 'Font') ?? '';
  const fonts = {};
  for (const f of fontsD.matchAll(/\/(\w+)\s+(\d+)\s+0\s+R/g)) {
    const fb = objs.get(+f[2]) ?? ''; const tu = ref(fb, 'ToUnicode');
    const two = /Type0/.test(fb);
    fonts[f[1]] = { map: tu ? cmap(streamOf(objs.get(tu) ?? '') ?? '') : null, two };
  }
  const contents = [];
  const cr = /\/Contents\s*(\[[^\]]*\]|\d+\s+0\s+R)/.exec(page);
  if (cr) for (const r of cr[1].matchAll(/(\d+)\s+0\s+R/g)) contents.push(streamOf(objs.get(+r[1]) ?? '') ?? '');
  const runs = [];
  let font = null, x = 0, y = 0;
  const tok = /\/(\w+)\s+[\d.]+\s+Tf|([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+Tm|([-\d.]+)\s+([-\d.]+)\s+T[dD]|(\[(?:[^\]\\]|\\.)*\]|\((?:[^)\\]|\\.)*\)|<[0-9A-Fa-f\s]*>)\s*(TJ|Tj|'|")|BT/g;
  for (const c of contents) {
    let t;
    while ((t = tok.exec(c))) {
      if (t[0] === 'BT') { x = 0; y = 0; continue; }
      if (t[1]) { font = fonts[t[1]]; continue; }
      if (t[2] !== undefined) { x = +t[6]; y = +t[7]; continue; }
      if (t[8] !== undefined) { x += +t[8]; y += +t[9]; continue; }
      let out = '';
      for (const part of t[10].matchAll(/\((?:[^)\\]|\\.)*\)|<[0-9A-Fa-f\s]*>/g)) {
        const p = part[0];
        let codes = [];
        if (p.startsWith('(')) {
          const str = p.slice(1, -1).replace(/\\(\d{1,3}|.)/g, (_, e) => /\d/.test(e) ? String.fromCharCode(parseInt(e, 8)) : ({ n: '\n', r: '\r', t: '\t' }[e] ?? e));
          codes = [...str].map((ch) => ch.charCodeAt(0));
          if (font?.two) { const pairs = []; for (let i = 0; i < codes.length; i += 2) pairs.push(codes[i] * 256 + (codes[i + 1] ?? 0)); codes = pairs; }
        } else {
          const h = p.slice(1, -1).replace(/\s/g, ''); const w = font?.two ? 4 : 2;
          for (let i = 0; i < h.length; i += w) codes.push(parseInt(h.slice(i, i + w), 16));
        }
        out += codes.map((cd) => font?.map?.get(cd) ?? String.fromCharCode(cd)).join('');
      }
      runs.push({ x, y, s: out });
    }
  }
  // group by y (rounded), sort by x
  const rows = new Map();
  for (const r of runs) { const k = Math.round(r.y); (rows.get(k) ?? rows.set(k, []).get(k)).push(r); }
  console.log(`===== page obj ${pn}`);
  for (const k of [...rows.keys()].sort((a, b) => b - a)) console.log(rows.get(k).sort((a, b) => a.x - b.x).map((r) => r.s).join(' | '));
}
