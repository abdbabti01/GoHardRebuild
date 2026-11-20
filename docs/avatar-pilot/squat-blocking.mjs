// Blocking mannequin for the Leon squat pilot: storyboard poses and animatic timing, NOT Leon and NOT reviewed technique.
// `node docs/avatar-pilot/squat-blocking.mjs` checks the poses and writes docs/avatar-pilot/storyboard.svg.
// The same file runs in a browser (the review page imports `pose`, `at`, `drawFigure`).
//
// Units: standing body height = 1. World: y up, z = the way the figure faces, x = lateral.
// Feet never move: ankles and toes are fixed points; each knee is solved by two-bone IK towards its own foot
// direction (knee over the second toe), so segment lengths are constant and nothing slides or floats.
// The angles below are ILLUSTRATIVE placeholders for one plausible bodyweight squat; the qualified reviewer sets
// the pilot's depth, stance and arm position (see docs/LEON_SQUAT_PILOT.md, "Technique references").

export const BODY = { ankleH: 0.04, shank: 0.245, thigh: 0.245, torso: 0.29, neck: 0.1, head: 0.062, upperArm: 0.165,
  forearm: 0.15, hipHalf: 0.085, ankleHalf: 0.1, shoulderHalf: 0.11, heel: 0.04, toe: 0.11, toeOut: 12 };
// Bottom of the placeholder squat: shank lean, thigh angle from vertical, torso lean, arm raise (degrees).
export const BOTTOM = { s: 32, t: 82, T: 42, A: 85 };
// Pilot timing (seconds), a production choice for "controlled", not an instruction.
export const TIMING = { startHold: 0.8, down: 1.8, bottomHold: 0.3, up: 1.4, topHold: 0.3, reps: 3 };
export const DURATION = TIMING.startHold + TIMING.reps * (TIMING.down + TIMING.bottomHold + TIMING.up + TIMING.topHold);

const rad = (d) => (d * Math.PI) / 180;
const add = (a, b) => a.map((v, i) => v + b[i]);
const sub = (a, b) => a.map((v, i) => v - b[i]);
const mul = (a, k) => a.map((v) => v * k);
const dot = (a, b) => a.reduce((s, v, i) => s + v * b[i], 0);
const len = (a) => Math.hypot(...a);
const norm = (a) => mul(a, 1 / len(a));
const ease = (x) => x * x * (3 - 2 * x);

// u = 0 standing, 1 bottom. The hips hinge back first (torso and thigh lead, shin follows), per ACE step 3.
export function pose(u) {
  const B = BODY;
  const s = rad(BOTTOM.s * u ** 1.3), t = rad(BOTTOM.t * u ** 0.95), T = rad(BOTTOM.T * u ** 0.75), A = rad(BOTTOM.A * u);
  // Mean leg in the sagittal plane gives the pelvis; 0.995 keeps the straight-leg stance just reachable.
  const k2 = [B.shank * Math.sin(s), B.ankleH + B.shank * Math.cos(s)];
  const h2 = [k2[0] - B.thigh * Math.sin(t), k2[1] + B.thigh * Math.cos(t) * 0.995];
  const pelvis = [0, h2[1], h2[0]];
  const j = { pelvis };
  for (const side of [-1, 1]) {
    const a = rad(B.toeOut) * side, dir = [Math.sin(a), 0, Math.cos(a)];
    const ankle = [side * B.ankleHalf, B.ankleH, 0];
    const hip = [side * B.hipHalf, pelvis[1], pelvis[2]];
    const ah = sub(hip, ankle), D = Math.min(len(ah), (B.shank + B.thigh) * 0.9999), axis = norm(ah);
    const x = (B.shank ** 2 - B.thigh ** 2 + D ** 2) / (2 * D), h = Math.sqrt(Math.max(0, B.shank ** 2 - x ** 2));
    const pole = norm(sub(dir, mul(axis, dot(dir, axis))));
    const n = side < 0 ? 'L' : 'R';
    j['hip' + n] = hip; j['ankle' + n] = ankle;
    j['knee' + n] = add(add(ankle, mul(axis, x)), mul(pole, h));
    j['heel' + n] = add([ankle[0], 0, 0], mul(dir, -B.heel));
    j['toe' + n] = add([ankle[0], 0, 0], mul(dir, B.toe));
  }
  const up = [0, Math.cos(T), Math.sin(T)];
  const chest = add(pelvis, mul(up, B.torso));
  j.chest = chest;
  j.head = add(chest, mul([0, Math.cos(T * 0.45), Math.sin(T * 0.45)], B.neck)); // chest up, head slightly up
  j.nose = add(j.head, [0, -0.005, B.head * 1.05]); // shows which way the figure faces
  const arm = [0, -Math.cos(A), Math.sin(A)];
  for (const side of [-1, 1]) {
    const n = side < 0 ? 'L' : 'R', sh = add(chest, [side * B.shoulderHalf, -0.02, 0]);
    j['shoulder' + n] = sh;
    j['elbow' + n] = add(sh, mul(arm, B.upperArm));
    j['hand' + n] = add(j['elbow' + n], mul(arm, B.forearm));
  }
  return j;
}

// Pose parameter u at time `sec` of the looping clip; the loop starts and ends standing still, so it joins invisibly.
export function at(sec) {
  const { startHold, down, bottomHold, up, topHold } = TIMING, rep = down + bottomHold + up + topHold;
  let x = ((sec % DURATION) + DURATION) % DURATION - startHold;
  if (x < 0) return 0;
  x %= rep;
  if (x < down) return ease(x / down);
  if (x < down + bottomHold) return 1;
  if (x < down + bottomHold + up) return 1 - ease((x - down - bottomHold) / up);
  return 0;
}

// Rough centre of mass (segment-mass fractions of a typical adult) and the feet's support area along z.
export function balance(j) {
  const mid = (a, b) => mul(add(a, b), 0.5);
  const parts = [[mid(j.pelvis, j.chest), 0.5], [j.head, 0.08], [mid(j.hipL, j.kneeL), 0.1], [mid(j.hipR, j.kneeR), 0.1],
    [mid(j.kneeL, j.ankleL), 0.06], [mid(j.kneeR, j.ankleR), 0.06], [mid(j.shoulderL, j.handL), 0.05], [mid(j.shoulderR, j.handR), 0.05]];
  const m = parts.reduce((s, [, w]) => s + w, 0);
  const z = parts.reduce((s, [p, w]) => s + p[2] * w, 0) / m;
  return { z, min: j.heelL[2], max: j.toeL[2] };
}

// Three-quarter view: camera yawed `yaw` degrees off the front, a little above hip height, orthographic.
export function project(p, yaw = -35, pitch = 6) {
  const y = rad(yaw), q = rad(pitch);
  const x1 = p[0] * Math.cos(y) - p[2] * Math.sin(y), z1 = p[0] * Math.sin(y) + p[2] * Math.cos(y);
  return { x: x1, y: p[1] * Math.cos(q) - z1 * Math.sin(q), depth: z1 * Math.cos(q) + p[1] * Math.sin(q) };
}

// SVG group for one pose. Far limbs are lighter; hips, knees and ankles are ringed so they stay readable.
export function drawFigure(j, { cx, base, scale, yaw = -35, ink = '#2b2f2e', far = '#9aa29d', joint = '#1d5c9e', floor = '#d9ddd8' }) {
  const P = (k) => { const p = project(j[k], yaw); return { x: cx + p.x * scale, y: base - p.y * scale, d: p.depth }; };
  const seg = (a, b, w, c) => { const A = P(a), B = P(b); return { d: (A.d + B.d) / 2, s: `<line x1="${A.x.toFixed(1)}" y1="${A.y.toFixed(1)}" x2="${B.x.toFixed(1)}" y2="${B.y.toFixed(1)}" stroke="${c}" stroke-width="${w}" stroke-linecap="round"/>` }; };
  const nearL = P('hipL').d > P('hipR').d;
  const sideInk = (n) => ((n === 'L') === nearL ? ink : far);
  const parts = [];
  for (const n of ['L', 'R']) {
    const c = sideInk(n);
    parts.push(seg('hip' + n, 'knee' + n, 0.045 * scale, c), seg('knee' + n, 'ankle' + n, 0.04 * scale, c),
      seg('heel' + n, 'toe' + n, 0.03 * scale, c), seg('ankle' + n, 'heel' + n, 0.03 * scale, c),
      seg('shoulder' + n, 'elbow' + n, 0.032 * scale, c), seg('elbow' + n, 'hand' + n, 0.028 * scale, c));
  }
  parts.push(seg('hipL', 'hipR', 0.05 * scale, ink), seg('pelvis', 'chest', 0.075 * scale, ink), seg('shoulderL', 'shoulderR', 0.05 * scale, ink));
  parts.sort((a, b) => a.d - b.d);
  const H = P('head'), N = P('nose'), rings = ['hipL', 'hipR', 'kneeL', 'kneeR', 'ankleL', 'ankleR'].map((k) => { const p = P(k); return `<circle cx="${p.x.toFixed(1)}" cy="${p.y.toFixed(1)}" r="${(0.013 * scale).toFixed(1)}" fill="#fff" stroke="${joint}" stroke-width="${(0.006 * scale).toFixed(1)}"/>`; });
  return `<g><ellipse cx="${cx}" cy="${base + 2}" rx="${0.22 * scale}" ry="${0.05 * scale}" fill="${floor}"/>${parts.map((p) => p.s).join('')}<circle cx="${H.x.toFixed(1)}" cy="${H.y.toFixed(1)}" r="${(BODY.head * scale).toFixed(1)}" fill="${ink}"/><circle cx="${N.x.toFixed(1)}" cy="${N.y.toFixed(1)}" r="${(0.018 * scale).toFixed(1)}" fill="${ink}"/>${rings.join('')}</g>`;
}

export const BOARD = [
  { u: 0, time: 0, title: '1  Start', lines: ['Standing tall, feet a little wider', 'than hips, toes slightly out.'] },
  { u: 0.25, time: 0.8 + 0.6, title: '2  Hips back first', lines: ['Hips move back, then down;', 'hips and knees bend together.'] },
  { u: 0.6, time: 0.8 + 1.05, title: '3  Controlled descent', lines: ['Knees follow the second toe;', 'heels stay down.'] },
  { u: 1, time: 0.8 + 1.8, title: '4  Bottom (placeholder)', lines: ['Depth set by the reviewer: ACE', 'stops at about parallel or earlier.'] },
  { u: 0.6, time: 0.8 + 2.1 + 0.55, title: '5  Return', lines: ['Push the floor away; hips and', 'torso rise together.'] },
  { u: 0, time: 0.8 + 3.8, title: '6  Standing again', lines: ['Same pose as frame 1: the loop', 'joins without a jump. Rep 2 of 3.'] },
];

function storyboard() {
  const W = 230, Hh = 520, pad = 20, scale = 250, top = 70;
  const panels = BOARD.map((f, i) => {
    const x = pad + i * W;
    const text = f.lines.map((l, k) => `<text x="${x + 12}" y="${top + 306 + k * 17}" font-size="12.5" fill="#4b524e">${l}</text>`).join('');
    return `<rect x="${x}" y="${top}" width="${W - 12}" height="${Hh}" rx="10" fill="#fff" stroke="#dde1dc"/>`
      + `<text x="${x + 12}" y="${top + 24}" font-size="14" font-weight="600" fill="#1b1e1c">${f.title}</text>`
      + `<text x="${x + W - 24}" y="${top + 24}" font-size="12" fill="#6b726e" text-anchor="end">${f.time.toFixed(2)} s</text>`
      + drawFigure(pose(f.u), { cx: x + (W - 12) / 2, base: top + 282, scale }) + text
      + `<line x1="${x + 12}" y1="${top + 352}" x2="${x + W - 24}" y2="${top + 352}" stroke="#eceeea"/>`
      + `<text x="${x + 12}" y="${top + 372}" font-size="11.5" fill="#6b726e">Side view (reference only)</text>`
      + drawFigure(pose(f.u), { cx: x + (W - 12) / 2 - 10, base: top + 500, scale: 120, yaw: -90 });
  }).join('');
  const width = pad * 2 + BOARD.length * W - 12;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${top + Hh + 40}" viewBox="0 0 ${width} ${top + Hh + 40}" font-family="Inter, Segoe UI, sans-serif">`
    + `<rect width="100%" height="100%" fill="#f3f4f1"/>`
    + `<text x="${pad}" y="30" font-size="18" font-weight="600" fill="#1b1e1c">Leon bodyweight squat pilot: storyboard (blocking mannequin, three-quarter view, camera 35° off the front)</text>`
    + `<text x="${pad}" y="52" font-size="13" fill="#8a3b12">Not Leon and not an animation. Depth, stance, arm position and timing are placeholders awaiting qualified technique review.</text>`
    + panels + `<text x="${pad}" y="${top + Hh + 26}" font-size="12" fill="#6b726e">Timing: ${TIMING.startHold} s hold, then ${TIMING.reps} reps of ${TIMING.down} s down, ${TIMING.bottomHold} s pause, ${TIMING.up} s up, ${TIMING.topHold} s pause = ${DURATION.toFixed(1)} s loop. Ringed: hips, knees, ankles. Generated by squat-blocking.mjs.</text></svg>`;
}

if (typeof process !== 'undefined' && process.argv[1] && import.meta.url.endsWith(process.argv[1].replace(/\\/g, '/').split('/').pop())) {
  const { writeFileSync } = await import('node:fs');
  const B = BODY, eps = 1e-9;
  const ref = pose(0);
  for (let i = 0; i <= 100; i++) {
    const j = pose(i / 100);
    for (const n of ['L', 'R']) {
      for (const k of ['ankle', 'heel', 'toe']) if (len(sub(j[k + n], ref[k + n])) > eps) throw new Error(`${k}${n} moved at u=${i / 100}`);
      if (Math.abs(len(sub(j['knee' + n], j['ankle' + n])) - B.shank) > 1e-6) throw new Error(`shank length at u=${i / 100}`);
      if (Math.abs(len(sub(j['hip' + n], j['knee' + n])) - B.thigh) > 1e-6) throw new Error(`thigh length at u=${i / 100}`);
      if (j['knee' + n][1] < B.ankleH || j['hand' + n][1] < 0.02) throw new Error(`below the floor at u=${i / 100}`);
    }
    const b = balance(j);
    if (b.z < b.min || b.z > b.max) throw new Error(`centre of mass ${b.z.toFixed(3)} outside the feet at u=${i / 100}`);
  }
  if (at(0) !== 0 || at(DURATION - 0.01) !== 0 || Math.abs(at(TIMING.startHold + TIMING.down + 0.1) - 1) > eps) throw new Error('loop timing');
  const out = new URL('./storyboard.svg', import.meta.url);
  writeFileSync(out, storyboard());
  const b = balance(pose(1));
  console.log(`ok: feet fixed, lengths constant, balance inside the feet (bottom COM z=${b.z.toFixed(3)} in ${b.min.toFixed(3)}..${b.max.toFixed(3)}), loop ${DURATION.toFixed(1)} s`);
}
