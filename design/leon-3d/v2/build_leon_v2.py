"""Leon v2 — still character model for appearance review (no animation yet).

    blender -b --factory-startup --python build_leon_v2.py -- --base <human_base_meshes_bundle.blend>
        [--out leon_v2.blend] [--stills DIR [--res 1080] [--only "Cam front,Cam side,Cam 3q,Cam face"]]

Body: Blender Studio's CC0 "Human Base Meshes" v1.4.1 realistic male (sculpted multires level 2), with the muscle forms
strengthened and a V-taper added in code. Head, mane, fur, shorts, trainers and tail are built here. The rig is a reusable
skeleton (spine, neck, head, arms with fingers, legs with feet, tail) weighted with Blender's bone-heat weights.
"""
import bpy, bmesh, math, random, sys
import numpy as np
from mathutils import Vector, Matrix, Quaternion
from mathutils.bvhtree import BVHTree

ARGV = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
def opt(name, default=None):
    return ARGV[ARGV.index(name) + 1] if name in ARGV else default
V = Vector

PALETTE = dict(fur='#B58440', fur_light='#D6A962', cream='#F1E4CB', mane='#5E3119', mane_dark='#2E170B',
               mane_light='#80492A', nose='#5E3530', brow='#4A2D20', iris='#93531C', inner_ear='#B5805C',
               shorts='#24272C', waistband='#1A1C20', accent='#0062CC', shoe='#F3F2EF', sole='#D3D6DA',
               bg='#C9CED3', floor='#A9B0B6', claw='#E8DCC8', pad='#5A3B33')

def lin(hexstr, a=1.0):
    c = [int(hexstr[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (a,)

# --------------------------------------------------------------------------------- joints of the base mesh (rest, A-pose)
# measured by slicing the subdivided base mesh; left side (x > 0), mirrored for the right
J = dict(hips=V((0, 0.0, 0.93)), spine=V((0, 0.0, 1.06)), chest=V((0, 0.0, 1.20)), neck=V((0, -0.005, 1.41)),
         head=V((0, -0.02, 1.50)), headTop=V((0, -0.02, 1.72)))
JS = dict(clav=V((0.03, -0.01, 1.40)), shoulder=V((0.18, 0.0, 1.37)), elbow=V((0.30, -0.01, 1.07)),
          wrist=V((0.375, -0.065, 0.865)), hand=V((0.425, -0.11, 0.745)),
          hip=V((0.09, -0.01, 0.89)), knee=V((0.13, 0.0, 0.47)), ankle=V((0.172, 0.04, 0.08)),
          ball=V((0.205, -0.085, 0.02)), toe=V((0.215, -0.13, 0.02)))
def js(name, side):
    p = JS[name].copy()
    if side == 'R': p.x = -p.x
    return p

def collection(name):
    c = bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c); return c

def link_only(ob, coll):
    for c in list(ob.users_collection): c.objects.unlink(ob)
    coll.objects.link(ob)

def verts_np(me):
    a = np.empty(len(me.vertices) * 3); me.vertices.foreach_get('co', a); return a.reshape(-1, 3)

def set_verts(me, P):
    me.vertices.foreach_set('co', P.ravel()); me.update()

def normals_np(me):
    a = np.empty(len(me.vertices) * 3); me.vertices.foreach_get('normal', a); return a.reshape(-1, 3)

def edges_np(me):
    a = np.empty(len(me.edges) * 2, dtype=np.int64); me.edges.foreach_get('vertices', a); return a.reshape(-1, 2)

def smooth_field(X, E, n, iters, lam=0.5, pin=None):
    """Laplacian smoothing of a per-vertex field over the mesh edges (umbrella operator)."""
    deg = np.bincount(E.ravel(), minlength=n).astype(float); deg[deg == 0] = 1
    X = X.copy()
    for _ in range(iters):
        S = np.zeros_like(X)
        for k in range(X.shape[1]):
            S[:, k] = np.bincount(E[:, 0], weights=X[E[:, 1], k], minlength=n) + np.bincount(E[:, 1], weights=X[E[:, 0], k], minlength=n)
        Xn = X + lam * (S / deg[:, None] - X)
        if pin is not None: Xn[pin] = X[pin]
        X = Xn
    return X

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)

# --------------------------------------------------------------------------------- body
def load_body(path):
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = ['GEO-body_male_realistic']
    ob = dst.objects[0]
    bpy.context.scene.collection.objects.link(ob)
    ob.location = (0, 0, 0); ob.parent = None
    for c in list(ob.children): bpy.data.objects.remove(c)
    low = ob.copy(); low.data = ob.data.copy(); low.name = 'Body low (weights)'
    low.modifiers.clear(); bpy.context.scene.collection.objects.link(low)
    mr = ob.modifiers[0]; mr.levels = 2
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear(); ob.data = me; bpy.data.meshes.remove(old)
    ob.name = 'Leon body'; me.name = 'Leon body'
    return ob, low

def region_weights(P):
    """1 on the trunk and limbs, fading to 0 on the head, hands and feet (where detail must not be exaggerated)."""
    ax = np.abs(P[:, 0])
    w = 1 - smoothstep(1.40, 1.46, P[:, 2])                                   # head
    w *= smoothstep(0.10, 0.16, P[:, 2])                                      # feet
    # hands: beyond the wrist along the forearm
    for s in (1, -1):
        e, wr = JS['elbow'].copy(), JS['wrist'].copy(); e.x *= s; wr.x *= s
        d = np.array((wr - e).normalized()); t = (P - np.array(wr)) @ d
        w *= 1 - smoothstep(-0.03, 0.0, t) * (np.sign(P[:, 0]) == s)
    return w

def sculpt_body(ob):
    """Strengthens the muscle forms of the base sculpt and builds an athletic V-taper.
    1) band-pass the surface (forms between ~1.5 and ~6 cm) and push it along the normal: deeper separations, fuller
       muscle bellies; 2) add volume where an athlete carries it (traps, delts, lats, pecs, arms, glutes, quads, calves)."""
    me = ob.data
    P = verts_np(me); n = len(P); E = edges_np(me); N = normals_np(me)
    w = region_weights(P)
    s1 = smooth_field(P, E, n, 8)
    s2 = smooth_field(s1, E, n, 160)
    band = np.einsum('ij,ij->i', s1 - s2, N)
    P = P + N * (band * 1.4 * w)[:, None]
    # volume: (centre, radii xyz, amount m) for the left side; mirrored
    G = [((0.195, 0.0, 1.32), (0.08, 0.085, 0.11), 0.021),   # deltoid
         ((0.11, 0.03, 1.42), (0.08, 0.06, 0.06), 0.022),     # trapezius
         ((0.09, -0.08, 1.27), (0.08, 0.05, 0.07), 0.015),    # pectoral
         ((0.14, 0.06, 1.18), (0.06, 0.06, 0.12), 0.020),     # latissimus
         ((0.25, -0.01, 1.21), (0.055, 0.065, 0.10), 0.019),  # biceps / triceps
         ((0.33, -0.03, 0.99), (0.05, 0.05, 0.08), 0.012),    # forearm
         ((0.11, -0.06, 0.68), (0.09, 0.075, 0.16), 0.028),   # quadriceps
         ((0.07, -0.04, 0.55), (0.05, 0.05, 0.06), 0.013),    # vastus medialis
         ((0.11, 0.06, 0.66), (0.075, 0.065, 0.14), 0.018),  # hamstrings
         ((0.08, 0.10, 0.83), (0.08, 0.06, 0.08), 0.007),     # glute
         ((0.16, 0.07, 0.34), (0.06, 0.06, 0.10), 0.022),     # calf
         ((0.13, -0.02, 0.36), (0.04, 0.04, 0.09), 0.008)]    # tibialis / shin
    disp = np.zeros(n)
    for (c, r, a) in G:
        for s in (1, -1):
            cc = np.array((c[0] * s, c[1], c[2])); q = (P - cc) / np.array(r)
            disp += a * np.exp(-np.einsum('ij,ij->i', q, q) * 1.6)
    # a slightly narrower waist for the taper
    waist = np.exp(-((P[:, 2] - 1.03) / 0.07) ** 2) * (np.abs(P[:, 0]) > 0.08)
    disp -= 0.008 * waist
    P = P + N * (disp * w)[:, None]
    # a thicker, lion-like neck (the head mask above does not apply here)
    neck = smoothstep(1.34, 1.40, P[:, 2]) * (1 - smoothstep(1.46, 1.50, P[:, 2])) * (np.abs(P[:, 0]) < 0.12)
    P = P + N * (0.012 * neck)[:, None]
    set_verts(me, P)
    # paler fur on the chest and belly
    belly = np.exp(-((P[:, 0] / 0.11) ** 2) - ((P[:, 2] - 1.16) / 0.2) ** 2) * smoothstep(0.0, -0.06, P[:, 1])
    me.attributes.new('belly', 'FLOAT', 'POINT').data.foreach_set('value', belly)
    # per-vertex cavity for shading: negative in muscle separations, positive on bellies
    N = normals_np(me)
    cav = np.einsum('ij,ij->i', P - smooth_field(P, E, n, 30), N)
    attr = me.attributes.new('cavity', 'FLOAT', 'POINT'); attr.data.foreach_set('value', np.clip(cav / 0.004, -1, 1))

def delete_verts(ob, mask):
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(mask)[0]], context='VERTS')
    bm.to_mesh(ob.data); bm.free(); ob.data.update()

# --------------------------------------------------------------------------------- rig
def build_rig(coll):
    arm = bpy.data.armatures.new('Leon rig'); rig = bpy.data.objects.new('Leon rig', arm); coll.objects.link(rig)
    vl = bpy.context.view_layer; vl.objects.active = rig; rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.edit_bones
    def bone(name, h, t, parent=None, connect=False, roll_up=None):
        b = eb.new(name); b.head, b.tail = h, t
        if parent: b.parent = eb[parent]; b.use_connect = connect
        if roll_up is not None: b.align_roll(roll_up)
        return b
    bone('root', V((0, 0, 0)), V((0, 0.25, 0)))
    bone('hips', J['hips'], J['spine'], 'root')
    bone('spine', J['spine'], J['chest'], 'hips', True)
    bone('chest', J['chest'], J['neck'], 'spine', True)
    bone('neck', J['neck'], J['head'], 'chest', True)
    bone('head', J['head'], J['headTop'], 'neck', True)
    bone('tail', V((0, 0.10, 0.90)), V((0, 0.22, 0.80)), 'hips')
    for s in ('L', 'R'):
        bone(f'clavicle.{s}', js('clav', s), js('shoulder', s), 'chest', roll_up=V((0, 0, 1)))
        bone(f'upper_arm.{s}', js('shoulder', s), js('elbow', s), f'clavicle.{s}', True, roll_up=V((0, 1, 0)))
        bone(f'forearm.{s}', js('elbow', s), js('wrist', s), f'upper_arm.{s}', True, roll_up=V((0, 1, 0)))
        bone(f'hand.{s}', js('wrist', s), js('hand', s), f'forearm.{s}', True, roll_up=V((0, 1, 0)))
        bone(f'thigh.{s}', js('hip', s), js('knee', s), 'hips', roll_up=V((0, -1, 0)))
        bone(f'shin.{s}', js('knee', s), js('ankle', s), f'thigh.{s}', True, roll_up=V((0, -1, 0)))
        bone(f'foot.{s}', js('ankle', s), js('ball', s), f'shin.{s}', True, roll_up=V((0, 0, 1)))
        bone(f'toe.{s}', js('ball', s), js('toe', s), f'foot.{s}', True, roll_up=V((0, 0, 1)))
    bpy.ops.object.mode_set(mode='OBJECT')
    return rig

def skin_from_low(rig, low, body):
    """Bone-heat weights on the low-resolution base mesh, transferred to the subdivided body."""
    vl = bpy.context.view_layer
    for o in vl.objects: o.select_set(False)
    low.select_set(True); rig.select_set(True); vl.objects.active = rig
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    for b in rig.data.bones:
        body.vertex_groups.new(name=b.name)
    dt = body.modifiers.new('weights', 'DATA_TRANSFER'); dt.object = low
    dt.use_vert_data = True; dt.data_types_verts = {'VGROUP_WEIGHTS'}; dt.vert_mapping = 'POLYINTERP_NEAREST'
    dt.layers_vgroup_select_src = 'ALL'; dt.layers_vgroup_select_dst = 'NAME'
    for o in vl.objects: o.select_set(False)
    vl.objects.active = body; body.select_set(True)
    bpy.ops.object.modifier_apply(modifier=dt.name)
    m = body.modifiers.new('Armature', 'ARMATURE'); m.object = rig
    body.parent = rig

def rotate_world(rig, name, axis, deg):
    """Rotates a pose bone about a world axis through its head (applied on top of its current pose)."""
    bpy.context.view_layer.update()
    pb = rig.pose.bones[name]
    M = pb.matrix.copy(); h = M.translation.copy()
    R = Matrix.Rotation(math.radians(deg), 4, V(axis))
    pb.matrix = Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ M
    bpy.context.view_layer.update()

def pose_stand(rig):
    """Relaxed standing pose for the still renders: arms down by the sides with a soft elbow."""
    for s, k in (('L', 1), ('R', -1)):
        # (rotating a downward limb about -X swings it forward)
        rotate_world(rig, f'upper_arm.{s}', (0, 1, 0), 16 * k)
        rotate_world(rig, f'upper_arm.{s}', (1, 0, 0), -4)
        rotate_world(rig, f'forearm.{s}', (0, 1, 0), 6 * k)
        rotate_world(rig, f'forearm.{s}', (1, 0, 0), -8)
        rotate_world(rig, f'hand.{s}', (0, 1, 0), 8 * k)

# --------------------------------------------------------------------------------- generic geometry
MB = 0.575  # visible radius of a metaball element of radius 1 (stiffness 2, threshold 0.6)
_MB_N = 0

def metaball(name, elems, res=0.005):
    """elems: ('ell', centre, (a, b, c), quaternion or None) | ('cap', p0, p1, r); visible sizes in metres."""
    global _MB_N
    _MB_N += 1
    mb = bpy.data.metaballs.new(f'mb{_MB_N}x'); mb.resolution = mb.render_resolution = res; mb.threshold = 0.6
    ob = bpy.data.objects.new(f'mb{_MB_N}x', mb); ob['want'] = name
    bpy.context.scene.collection.objects.link(ob)
    for e in elems:
        if e[0] == 'ell':
            _, c, abc, q = e; m = max(abc)
            el = mb.elements.new(type='ELLIPSOID'); el.co = c; el.radius = m / MB
            el.size_x, el.size_y, el.size_z = (abc[0] / m, abc[1] / m, abc[2] / m)
            if q is not None: el.rotation = q
        else:
            _, p0, p1, r = e; d = p1 - p0
            el = mb.elements.new(type='CAPSULE'); el.co = (p0 + p1) / 2; el.radius = r / MB; el.size_x = d.length / 2
            el.rotation = V((1, 0, 0)).rotation_difference(d.normalized())
    return ob

def to_mesh(ob, coll, mat, smooth_iters=4):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    name = ob['want']; bpy.data.objects.remove(ob)
    if smooth_iters and len(me.vertices):
        P = verts_np(me); set_verts(me, smooth_field(P, edges_np(me), len(P), smooth_iters, 0.4))
    new = bpy.data.objects.new(name, me); coll.objects.link(new)
    me.materials.append(mat)
    for p in me.polygons: p.use_smooth = True
    return new

def ell(c, abc, q=None): return ('ell', V(c), abc, q)
def cap(p0, p1, r): return ('cap', V(p0), V(p1), r)

def tube(name, coll, mat, pts, radii, flat=1.0, ring=10, up=V((0, 0, 1)), cap_end=True):
    """A tube through pts (Catmull-Rom resampled) with per-point radius; flat < 1 squashes it."""
    bm = bmesh.new(); P = [V(p) for p in pts]; samples, rs = [], []; n = 24
    for i in range(n + 1):
        u = i / n * (len(P) - 1); k = min(int(u), len(P) - 2); f = u - k
        p0, p1, p2, p3 = P[max(k - 1, 0)], P[k], P[k + 1], P[min(k + 2, len(P) - 1)]
        samples.append(0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f ** 3))
        rs.append(radii[k] + (radii[k + 1] - radii[k]) * f)
    rings = []
    for i, p in enumerate(samples):
        t = (samples[min(i + 1, n)] - samples[max(i - 1, 0)]).normalized()
        a = t.cross(up); a = a.normalized() if a.length > 1e-6 else t.orthogonal().normalized()
        b = t.cross(a).normalized()
        rings.append([bm.verts.new(p + (a * math.cos(2 * math.pi * j / ring) + b * flat * math.sin(2 * math.pi * j / ring)) * rs[i]) for j in range(ring)])
    for r0, r1 in zip(rings, rings[1:]):
        for j in range(ring): bm.faces.new((r0[j], r0[(j + 1) % ring], r1[(j + 1) % ring], r1[j]))
    bm.faces.new(list(reversed(rings[0])))
    if cap_end:
        tip = bm.verts.new(samples[-1] + (samples[-1] - samples[-2]).normalized() * rs[-1])
        for j in range(ring): bm.faces.new((rings[-1][j], rings[-1][(j + 1) % ring], tip))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me); coll.objects.link(ob)
    return ob

def bvh_of(ob):
    me = ob.data
    return BVHTree.FromPolygons([v.co for v in me.vertices], [p.vertices for p in me.polygons])

def on_surface(ob, pts, offset):
    t = bvh_of(ob); out = []
    for p in pts:
        loc, nor, _, _ = t.find_nearest(V(p)); out.append(loc + nor * offset)
    return out

def join(objs, name):
    vl = bpy.context.view_layer
    for o in vl.objects: o.select_set(False)
    for o in objs: o.select_set(True)
    vl.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].select_set(False); objs[0].name = name
    return objs[0]

def parent_to_bone(ob, rig, bone):
    bpy.context.view_layer.update()
    pb = rig.pose.bones[bone]
    ob.parent = rig; ob.parent_type = 'BONE'; ob.parent_bone = bone
    ob.matrix_parent_inverse = (rig.matrix_world @ pb.matrix @ Matrix.Translation((0, pb.bone.length, 0))).inverted()

# --------------------------------------------------------------------------------- strands (fur, mane, whiskers)
def sample_surface(ob, count, rng):
    me = ob.data; me.calc_loop_triangles()
    T = np.empty(len(me.loop_triangles) * 3, dtype=np.int64); me.loop_triangles.foreach_get('vertices', T); T = T.reshape(-1, 3)
    P = verts_np(me); VN = normals_np(me)
    a, b, c = P[T[:, 0]], P[T[:, 1]], P[T[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    idx = rng.choice(len(T), count, p=area / area.sum())
    u, v = rng.random(count), rng.random(count); f = u + v > 1; u[f] = 1 - u[f]; v[f] = 1 - v[f]; w = 1 - u - v
    pts = a[idx] * w[:, None] + b[idx] * u[:, None] + c[idx] * v[:, None]
    nrm = VN[T[idx, 0]] * w[:, None] + VN[T[idx, 1]] * u[:, None] + VN[T[idx, 2]] * v[:, None]
    nrm /= np.linalg.norm(nrm, axis=1)[:, None]
    return pts, nrm

def unit(a): return a / np.maximum(np.linalg.norm(a, axis=-1, keepdims=True), 1e-9)

def fur(pts, nrm, flow, length, lift=0.35, segs=3, curl=0.35):
    """Short strands leaning along `flow` (projected onto the surface) and bending towards it."""
    f = unit(flow - nrm * np.einsum('ij,ij->i', flow, nrm)[:, None])
    d0 = unit(nrm * lift + f * (1 - lift))
    t = np.linspace(0, 1, segs + 1)[None, :, None]
    L = length[:, None, None]
    return pts[:, None, :] + (d0[:, None, :] * t + f[:, None, :] * curl * t * t) * L

def curves_object(name, coll, S, r_root, r_tip, mat):
    """S: (n, k, 3) strand points."""
    n, k, _ = S.shape
    cv = bpy.data.hair_curves.new(name)
    cv.add_curves([k] * n)
    cv.position_data.foreach_set('vector', S.astype(np.float32).ravel())
    rad = cv.attributes.get('radius') or cv.attributes.new('radius', 'FLOAT', 'POINT')
    rad.data.foreach_set('value', np.tile(np.linspace(r_root, r_tip, k), n).astype(np.float32))
    cv.materials.append(mat)
    ob = bpy.data.objects.new(name, cv); coll.objects.link(ob)
    return ob

def mane_strands(head, base, HC, S, rng, guides=1100, children=34):
    """Guide strands grown from the mane base: out from the surface, swept back, the crest lifting first; kept off the
    face and above the shoulders. Children clump around each guide."""
    th = bvh_of(head)
    pts, nrm = sample_surface(base, guides * 4, rng)
    ears = [HC + V((0.122 * x, -0.03, 0.135)) * S for x in (1, -1)]
    keep = []
    for i, p in enumerate(pts):
        p = V(p); loc, nor, _, _ = th.find_nearest(p)
        rel = (p - HC) / S
        front = rel.y < -0.06 and abs(rel.x) < 0.1 and rel.z > -0.13
        near_ear = min((p - e).length for e in ears) < 0.06 * S
        if (p - loc).dot(nor) > 0.002 and not front and not near_ear: keep.append(i)
        if len(keep) == guides: break
    pts, nrm = pts[keep], nrm[keep]
    kind = [0] * len(pts)
    # a ruff framing the face and a crest from the forehead, both rooted on the head itself
    hp, hn = sample_surface(head, 40000, rng)
    rel = (hp - np.array(HC)) / S
    rxz = np.hypot(rel[:, 0], rel[:, 2] + 0.01)
    far_ears = np.min([np.linalg.norm(hp - np.array(e), axis=1) for e in ears], axis=0) > 0.065 * S
    ring = (rel[:, 1] > -0.07) & (rel[:, 1] < 0.05) & (rxz > 0.105) & (rel[:, 2] > -0.2) & far_ears
    crest = (rel[:, 2] > 0.105) & (rel[:, 1] > -0.07) & (rel[:, 1] < 0.05) & (np.abs(rel[:, 0]) < 0.075)
    ri = np.nonzero(ring)[0][:560]; ci = np.nonzero(crest & ~ring)[0][:170]
    pts = np.concatenate([pts, hp[ri], hp[ci]]); nrm = np.concatenate([nrm, hn[ri], hn[ci]])
    kind += [1] * len(ri) + [2] * len(ci)
    segs = 11; G = np.zeros((len(pts), segs + 1, 3))
    for gi, (p, n) in enumerate(zip(pts, nrm)):
        p = V(p); n = V(n); rel = (p - HC) / S
        crest = float(smoothstep(0.03, 0.13, rel.z))
        low = float(smoothstep(0.0, -0.16, rel.z))
        if kind[gi] == 0:     # swept back: the top lifting before it falls, lower locks falling sooner
            d = (n * 0.45 + V((0, 1.1, 0)) + V((0, 0, 0.8 * crest - 0.4 * low))).normalized()
            L = S * (0.10 + 0.06 * rng.random()) * (1 + 0.4 * crest)
        elif kind[gi] == 1:   # ruff: out from the face edge, then back
            d = (n * 1.0 + V((0, 0.55, 0))).normalized()
            L = S * (0.07 + 0.04 * rng.random())
        else:                 # crest: up off the forehead and back over the top
            d = (V((0, 0.0, 1.0)) + V((0, 0.35, 0)) + n * 0.3).normalized()
            L = S * (0.13 + 0.05 * rng.random())
        G[gi, 0] = p
        for i in range(1, segs + 1):
            jitter = V(rng.normal(0, 0.04, 3))
            g = (0.07 + 0.16 * low + 0.07 * (i / segs)) * (0.5 if kind[gi] == 2 and i < 5 else 1.0)
            d = (d + V((0, 0.12 + 0.08 * (kind[gi] == 2), 0)) + V((0, 0, -1)) * g + jitter).normalized()
            q = p + d * (L / segs)
            loc, nor, _, _ = th.find_nearest(q)
            if (q - loc).dot(nor) < 0.005: q = loc + nor * 0.005
            if q.z < 1.48:                       # never onto the shoulders
                q.x = max(-0.14, min(0.14, q.x)); q.z = max(q.z, 1.44)
            G[gi, i] = q; p = q
    # children
    nG = len(G); C = np.repeat(G, children, axis=0)
    n_rep = np.repeat(nrm, children, axis=0)
    o = rng.normal(0, 1, (len(C), 3)); o -= n_rep * np.einsum('ij,ij->i', o, n_rep)[:, None]
    o = unit(o) * (rng.random(len(C)) ** 0.5 * 0.016)[:, None]
    t = np.linspace(0, 1, segs + 1)[None, :, None]
    C = C + o[:, None, :] * (1 - 0.85 * t) + rng.normal(0, 0.0015, C.shape) * t
    # vary length: shrink towards the root
    f = rng.uniform(0.7, 1.0, len(C))[:, None, None]
    C = C[:, :1, :] + (C - C[:, :1, :]) * f
    return np.concatenate([G, C])

# --------------------------------------------------------------------------------- head
def build_head(C, M, HC, S, rng):
    h = lambda x, y, z: HC + V((x, y, z)) * S
    r = lambda *abc: tuple(a * S for a in abc)
    parts = {}
    parts['Head'] = to_mesh(metaball('Head', [
        ell(h(0, 0.015, 0.02), r(0.13, 0.13, 0.135)),                                          # cranium
        ell(h(0, -0.06, 0.068), r(0.105, 0.07, 0.058)),                                        # forehead / brow ridge
        ell(h(0.062, -0.07, -0.03), r(0.068, 0.07, 0.063)), ell(h(-0.062, -0.07, -0.03), r(0.068, 0.07, 0.063)),
        cap(h(0, -0.07, 0.035), h(0, -0.165, 0.0), 0.042 * S),                                  # nasal bridge
        ell(h(0.104, -0.03, -0.05), r(0.068, 0.065, 0.075)), ell(h(-0.104, -0.03, -0.05), r(0.068, 0.065, 0.075)),
        ell(h(0, 0.0, -0.085), r(0.09, 0.09, 0.07)),                                            # jaw / throat
        # relaxed upper lids covering the top of each eye
        ell(h(0.056, -0.112, 0.058), r(0.042, 0.032, 0.015)), ell(h(-0.056, -0.112, 0.058), r(0.042, 0.032, 0.015))]), C, M['fur_head'])
    parts['Muzzle'] = to_mesh(metaball('Muzzle', [
        ell(h(0.036, -0.142, -0.048), r(0.05, 0.045, 0.037)), ell(h(-0.036, -0.142, -0.048), r(0.05, 0.045, 0.037)),
        ell(h(0, -0.157, -0.035), r(0.03, 0.03, 0.026)), ell(h(0, -0.115, -0.09), r(0.056, 0.048, 0.042)),
        ell(h(0, -0.095, -0.125), r(0.048, 0.04, 0.045)), ell(h(0.064, -0.1, -0.07), r(0.046, 0.042, 0.04)),
        ell(h(-0.064, -0.1, -0.07), r(0.046, 0.042, 0.04))]), C, M['cream'])
    parts['Nose'] = to_mesh(metaball('Nose', [
        ell(h(0, -0.192, 0.0), r(0.04, 0.025, 0.024)),
        ell(h(0.021, -0.188, -0.011), r(0.019, 0.02, 0.016)), ell(h(-0.021, -0.188, -0.011), r(0.019, 0.02, 0.016)),
        ell(h(0, -0.186, -0.021), r(0.011, 0.016, 0.014))], res=0.003), C, M['nose'], 2)
    det, ear_fur, brow_fur = [], [], []
    for x in (1, -1):
        nos = on_surface(parts['Nose'], [h(0.017 * x, -0.215, -0.013)], -0.002)[0]
        det.append(to_mesh(metaball('Nostril', [ell(nos, r(0.0085, 0.006, 0.005), Quaternion((0, 0, 1), math.radians(25 * x)))], res=0.002), C, M['nostril'], 0))
        c = h(0.056 * x, -0.118, 0.032); er = 0.03 * S
        look = V((-0.28, -1, 0.04)).normalized()        # both eyes toward the three-quarter camera
        det += [to_mesh(metaball('Eye', [ell(c, (er, er, er))], res=0.003), C, M['sclera'], 0),
                # iris and pupil only just break the eyeball surface, like a painted iris under the cornea
                to_mesh(metaball('Iris', [ell(c + look * er * 0.1, (er * 0.91,) * 3)], res=0.0015), C, M['iris'], 0),
                to_mesh(metaball('Pupil', [ell(c + look * er * 0.6, (er * 0.43,) * 3)], res=0.001), C, M['pupil'], 0),
                to_mesh(metaball('Glint', [ell(c + (look + V((0.25 * x, 0, 0.3))).normalized() * er * 1.0, (0.0032 * S,) * 3)], res=0.0008), C, M['glint'], 0)]
        side = V((x, 0, 0)); up = V((0, 0.12, 1)).normalized()
        lash = [c + (side * math.cos(a) + up * math.sin(a)) * er * 1.04 + look * er * 0.18 for a in np.radians(np.linspace(185, -10, 9))]
        det.append(tube('Lash', C, M['lash'], lash, [0.002, 0.0035, 0.0045, 0.0045, 0.0045, 0.0045, 0.004, 0.003, 0.002], ring=6))
        brow = tube('Brow', C, M['brow'], on_surface(parts['Head'], [h(0.016 * x, -0.13, 0.082), h(0.055 * x, -0.124, 0.098), h(0.098 * x, -0.098, 0.084)], 0.003),
                    [0.011 * S, 0.014 * S, 0.008 * S], flat=0.55, ring=8)
        bp, bn = sample_surface(brow, 2200, rng)
        brow_fur.append(fur(bp, bn, np.tile(np.array((x * 1.0, 0.2, 0.25)), (len(bp), 1)), rng.uniform(0.004, 0.007, len(bp)) * S, lift=0.3))
        det.append(brow)
        ear = to_mesh(metaball('Ear', [ell(h(0.122 * x, -0.03, 0.135), r(0.048, 0.022, 0.054), Quaternion((0, 1, 0), math.radians(-30 * x)))], res=0.004), C, M['fur_head'])
        ep, en = sample_surface(ear, 2500, rng)
        ear_fur.append(fur(ep, en, unit(ep - np.array(h(0.122 * x, -0.03, 0.135))) + np.array((0, 0, 0.3)), rng.uniform(0.003, 0.006, len(ep)) * S, lift=0.3))
        det.append(ear)
        det.append(to_mesh(metaball('InnerEar', [ell(h(0.118 * x, -0.05, 0.133), r(0.03, 0.007, 0.035), Quaternion((0, 1, 0), math.radians(-30 * x)))], res=0.003), C, M['inner_ear']))
    parts['Face details'] = join(det, 'Face details')
    mouth = [tube('Mouth', C, M['mouth'], on_surface(parts['Muzzle'], [h(0, -0.19, -0.03), h(0, -0.182, -0.05)], 0.0012), [0.0032, 0.0032], ring=6)]
    for x in (1, -1):
        mouth.append(tube('Mouth', C, M['mouth'], on_surface(parts['Muzzle'], [h(0, -0.182, -0.05), h(0.03 * x, -0.171, -0.066), h(0.062 * x, -0.15, -0.052)], 0.0012), [0.0032, 0.0032, 0.0025], ring=6))
    parts['Mouth'] = join(mouth, 'Mouth')
    parts['Mane base'] = to_mesh(metaball('Mane base', [
        ell(h(0, 0.08, 0.0), r(0.155, 0.125, 0.175)),
        ell(h(0.108, 0.05, -0.04), r(0.07, 0.08, 0.15)), ell(h(-0.108, 0.05, -0.04), r(0.07, 0.08, 0.15)),
        ell(h(0, 0.03, 0.105), r(0.115, 0.1, 0.08)), ell(h(0, 0.07, -0.15), r(0.13, 0.095, 0.1)),
        ell(h(0.08, -0.005, -0.12), r(0.062, 0.058, 0.075)), ell(h(-0.08, -0.005, -0.12), r(0.062, 0.058, 0.075))], res=0.008), C, M['mane_base'])
    # --- strands
    H = C
    head_pts, head_n = sample_surface(parts['Head'], 26000, rng)
    rel = (head_pts - np.array(HC)) / S
    eye_c = [np.array(h(0.056 * x, -0.118, 0.032)) for x in (1, -1)]
    ok = np.ones(len(head_pts), bool)
    for e in eye_c: ok &= np.linalg.norm(head_pts - e, axis=1) > 0.046 * S
    head_pts, head_n, rel = head_pts[ok], head_n[ok], rel[ok]
    flow = np.c_[rel[:, 0] * 1.4, np.full(len(rel), 0.9), rel[:, 2] * 0.6 - 0.15]
    curves_object('Head fur', H, fur(head_pts, head_n, flow, rng.uniform(0.004, 0.008, len(head_pts)) * S, lift=0.25), 0.00045, 0.0001, M['hair_fur'])
    mp, mn = sample_surface(parts['Muzzle'], 16000, rng)
    nose_tip = np.array(h(0, -0.2, -0.01))
    rel_m = (mp - np.array(HC)) / S
    chin = smoothstep(-0.09, -0.15, rel_m[:, 2])
    flow_m = unit(mp - nose_tip) + np.array((0, 0, -0.6)) * chin[:, None]
    curves_object('Muzzle fur', H, fur(mp, mn, flow_m, (rng.uniform(0.003, 0.006, len(mp)) + chin * rng.uniform(0.006, 0.018, len(mp))) * S, lift=0.25),
                  0.0004, 0.0001, M['hair_cream'])
    # whiskers from the muzzle pads
    wk = []
    for x in (1, -1):
        for i in range(6):
            root = on_surface(parts['Muzzle'], [h((0.035 + 0.006 * (i % 3)) * x, -0.162 + 0.006 * (i // 3), -0.04 - 0.009 * (i % 3))], 0.0)[0]
            d = V((x * 1.0, -0.35 + 0.05 * i, -0.08 - 0.04 * (i % 3))).normalized()
            L = (0.09 + 0.012 * i) * S
            wk.append([root + d * L * t + V((0, 0, -0.025 * t * t)) * L for t in np.linspace(0, 1, 6)])
    curves_object('Whiskers', H, np.array([[list(p) for p in s] for s in wk]), 0.0006, 0.00012, M['whisker'])
    curves_object('Ear fur', H, np.concatenate(ear_fur), 0.0004, 0.0001, M['hair_fur'])
    curves_object('Brow fur', H, np.concatenate(brow_fur), 0.0005, 0.0001, M['hair_brow'])
    curves_object('Mane', H, mane_strands(parts['Head'], parts['Mane base'], HC, S, rng), 0.0011, 0.00025, M['hair_mane'])
    return parts

def build_tail(C, M, rng):
    # out of the shorts, back and towards Leon's left, away from the legs and the three-quarter camera
    pts = [V((0, 0.105, 0.93)), V((0.02, 0.2, 0.89)), V((0.07, 0.32, 0.79)), V((0.12, 0.40, 0.68))]
    t = tube('Tail', C, M['fur_head'], pts, [0.024, 0.021, 0.018, 0.016], ring=12, cap_end=False)
    tuft = to_mesh(metaball('Tuft', [ell(V((0.135, 0.42, 0.645)), (0.035, 0.035, 0.045))], res=0.005), C, M['mane_base'])
    tp, tn = sample_surface(tuft, 3000, rng)
    flow = np.tile(np.array((0.3, 0.0, -1.0)), (len(tp), 1))
    curves_object('Tail tuft', C, fur(tp, tn, flow, rng.uniform(0.03, 0.06, len(tp)), lift=0.5, segs=5, curl=0.5), 0.001, 0.0002, M['hair_mane'])
    return join([t, tuft], 'Tail')

def body_fur_static(body, rig, coll, M, rng, count=170000):
    """Short fur over the body, grown on the posed surface (for stills; animation needs surface-deformed curves)."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(body.evaluated_get(dg), depsgraph=dg)
    tmp = bpy.data.objects.new('tmp', me)
    pts, nrm = sample_surface(tmp, count, rng)
    bpy.data.objects.remove(tmp); bpy.data.meshes.remove(me)
    flow = np.tile(np.array((0.0, 0.15, -1.0)), (len(pts), 1))
    ob = curves_object('Body fur', coll, fur(pts, nrm, flow, rng.uniform(0.0025, 0.0045, len(pts)), lift=0.2, segs=2, curl=0.2),
                       0.00028, 0.00006, M['hair_body'])
    ob.parent = rig                                  # same parent space as the body
    return ob

# --------------------------------------------------------------------------------- clothing shells
def shell(body, coll, name, keep_fn, offset_fn, iters, mat):
    """A garment made from the body's own surface: copy the region, push it out, smooth away anatomy."""
    ob = body.copy(); ob.data = body.data.copy(); ob.name = name; ob.data.name = name
    ob.modifiers.clear(); ob.parent = None; coll.objects.link(ob)
    P = verts_np(ob.data)
    delete_verts(ob, ~keep_fn(P))
    me = ob.data; P = verts_np(me); N = normals_np(me); E = edges_np(me)
    P = P + N * offset_fn(P)[:, None]
    P = smooth_field(P, E, len(P), iters, 0.5)
    set_verts(me, P)
    me.materials.clear(); me.materials.append(mat)
    return ob

def build_shorts(body, coll, mat):
    keep = lambda P: (P[:, 2] > 0.60) & (P[:, 2] < 0.99) & (np.abs(P[:, 0]) < 0.26)
    off = lambda P: 0.007 + 0.011 * smoothstep(0.80, 0.62, P[:, 2])
    ob = shell(body, coll, 'Shorts', keep, off, 25, mat)
    me = ob.data; P = verts_np(me); E = edges_np(me)
    crotch = (np.abs(P[:, 0]) < 0.08) & (P[:, 2] < 0.90) & (P[:, 1] < 0.0)
    set_verts(me, smooth_field(P, E, len(P), 60, 0.5, pin=~crotch))
    P = verts_np(me)
    cx = 0.115 * np.sign(P[:, 0]); ang = np.arctan2(P[:, 1] + 0.01, np.abs(P[:, 0]) - np.abs(cx))
    stripe = ((np.abs(ang) < 0.15) & (P[:, 2] < 0.955)).astype(float)
    stripe = smooth_field(stripe[:, None], E, len(P), 5)[:, 0]          # the shader sharpens it again at 0.5
    band = (P[:, 2] > 0.955).astype(float)
    for nm, val in (('stripe', stripe), ('band', band)):
        a = me.attributes.new(nm, 'FLOAT', 'POINT'); a.data.foreach_set('value', val)
    sol = ob.modifiers.new('Thickness', 'SOLIDIFY'); sol.thickness = 0.003; sol.offset = -1
    return ob

def build_shoes(body, coll, mat):
    keep = lambda P: P[:, 2] < 0.115
    # roomier toe box than heel, so the toes disappear into a shoe shape
    off = lambda P: 0.009 + 0.006 * smoothstep(-0.02, -0.09, P[:, 1])
    ob = shell(body, coll, 'Trainers', keep, off, 40, mat)
    me = ob.data; P = verts_np(me)
    P[P[:, 2] < 0.006, 2] = 0.006                  # the upper sits on the sole
    set_verts(me, P)
    P = verts_np(me)
    cx = 0.19 * np.sign(P[:, 0])
    attrs = dict(
        trim=(P[:, 2] < 0.013),
        heel=(P[:, 1] > 0.065) & (P[:, 2] > 0.025) & (P[:, 2] < 0.085),
        lace=(P[:, 1] < -0.005) & (P[:, 1] > -0.085) & (P[:, 2] > 0.055) & (np.abs(P[:, 0] - cx) < 0.022))
    for nm, val in attrs.items():
        a = me.attributes.new(nm, 'FLOAT', 'POINT'); a.data.foreach_set('value', val.astype(float))
    return ob

def hull2d(pts):
    pts = sorted(map(tuple, pts))
    def half(seq):
        out = []
        for p in seq:
            while len(out) >= 2 and (out[-1][0] - out[-2][0]) * (p[1] - out[-2][1]) - (out[-1][1] - out[-2][1]) * (p[0] - out[-2][0]) <= 0: out.pop()
            out.append(p)
        return out
    lo, hi = half(pts), half(reversed(pts))
    return np.array(lo[:-1] + hi[:-1])

def build_soles(shoes, coll, mat):
    """A rounded sole slab under each trainer, from the footprint of the upper (white midsole, grey outsole)."""
    P = verts_np(shoes.data); out = []
    for s, x in (('L', 1), ('R', -1)):
        foot = P[(np.sign(P[:, 0]) == x) & (P[:, 2] < 0.03)][:, :2]
        ring = hull2d(foot)
        for _ in range(3):                                   # Chaikin rounding
            nxt = np.roll(ring, -1, axis=0); ring = np.concatenate([0.75 * ring + 0.25 * nxt, 0.25 * ring + 0.75 * nxt])
            ring = ring.reshape(2, -1, 2).transpose(1, 0, 2).reshape(-1, 2)
        c = ring.mean(0)
        def level(inset, z):
            d = ring - c; r = np.linalg.norm(d, axis=1, keepdims=True)
            return np.c_[c + d * (r + 0.004 - inset) / r, np.full(len(ring), z)]
        rings = [level(0.005, -0.018), level(0.0, -0.014), level(0.0, 0.004), level(0.003, 0.009)]
        bm = bmesh.new()
        vs = [[bm.verts.new(p) for p in rg] for rg in rings]
        n = len(ring)
        for a, b in zip(vs, vs[1:]):
            for j in range(n): bm.faces.new((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
        bm.faces.new(list(reversed(vs[0]))); bm.faces.new(vs[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(f'Sole.{s}'); bm.to_mesh(me); bm.free()
        Z = verts_np(me)[:, 2]
        a = me.attributes.new('outsole', 'FLOAT', 'POINT'); a.data.foreach_set('value', (Z < -0.012).astype(float))
        me.materials.append(mat)
        ob = bpy.data.objects.new(f'Sole.{s}', me); coll.objects.link(ob)
        vg = ob.vertex_groups.new(name=f'foot.{s}'); vg.add(list(range(len(me.vertices))), 1.0, 'REPLACE')
        out.append(ob)
    return out

def sole_material():
    m, N, L, b = nodes_mat('Sole')
    L.new(attr_mix(N, L, 'outsole', lin('#F1F0EC'), lin('#8E959C')), b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.7
    return m

# --------------------------------------------------------------------------------- materials
def nodes_mat(name):
    m = bpy.data.materials.new(name); m.use_nodes = True
    return m, m.node_tree.nodes, m.node_tree.links, m.node_tree.nodes['Principled BSDF']

def rgba_in(n): return [i for i in n.inputs if i.type == 'RGBA']
def rgba_out(n): return [o for o in n.outputs if o.type == 'RGBA'][0]

def simple(name, color, rough=0.5, sheen=0.0, spec=0.5, coat=0.0):
    m, N, L, b = nodes_mat(name)
    b.inputs['Base Color'].default_value = lin(color); b.inputs['Roughness'].default_value = rough
    b.inputs['Sheen Weight'].default_value = sheen; b.inputs['Specular IOR Level'].default_value = spec
    b.inputs['Coat Weight'].default_value = coat
    return m

def fur_material(name, base, light, cavity_attr=True, scale=1.0):
    """Short golden fur as a surface shader: colour variation, a fine fur-grain bump, soft sheen at grazing angles,
    and the cavity field darkening the muscle separations so the forms read from every side."""
    m, N, L, b = nodes_mat(name)
    tc = N.new('ShaderNodeTexCoord')
    gm = N.new('ShaderNodeMapping'); gm.inputs['Scale'].default_value = (900 * scale, 900 * scale, 160 * scale)
    grain = N.new('ShaderNodeTexNoise'); grain.inputs['Detail'].default_value = 3; grain.inputs['Roughness'].default_value = 0.6
    L.new(tc.outputs['Object'], gm.inputs['Vector']); L.new(gm.outputs['Vector'], grain.inputs['Vector'])
    bump = N.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.25; bump.inputs['Distance'].default_value = 0.0006
    L.new(grain.outputs['Fac'], bump.inputs['Height']); L.new(bump.outputs['Normal'], b.inputs['Normal'])
    patch = N.new('ShaderNodeTexNoise'); patch.inputs['Scale'].default_value = 6 / scale; patch.inputs['Detail'].default_value = 2
    L.new(tc.outputs['Object'], patch.inputs['Vector'])
    ramp = N.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.3; ramp.color_ramp.elements[0].color = lin(base)
    ramp.color_ramp.elements[1].position = 0.75; ramp.color_ramp.elements[1].color = lin(light)
    L.new(patch.outputs['Fac'], ramp.inputs['Fac'])
    col = ramp.outputs['Color']
    if cavity_attr:
        col = attr_mix(N, L, 'belly', col, lin('#DDB98A'))
        cav = N.new('ShaderNodeAttribute'); cav.attribute_name = 'cavity'
        mr = N.new('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = -1; mr.inputs['From Max'].default_value = 1
        mr.inputs['To Min'].default_value = 0.62; mr.inputs['To Max'].default_value = 1.12
        L.new(cav.outputs['Fac'], mr.inputs['Value'])
        mul = N.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.inputs['Factor'].default_value = 1.0
        comb = N.new('ShaderNodeCombineColor')
        for k in ('Red', 'Green', 'Blue'): L.new(mr.outputs['Result'], comb.inputs[k])
        L.new(col, rgba_in(mul)[0]); L.new(comb.outputs['Color'], rgba_in(mul)[1])
        col = rgba_out(mul)
    L.new(col, b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.58
    b.inputs['Specular IOR Level'].default_value = 0.35
    b.inputs['Sheen Weight'].default_value = 0.4; b.inputs['Sheen Roughness'].default_value = 0.35
    b.inputs['Sheen Tint'].default_value = lin('#EBBE7E')
    return m

def hair_material(name, root, tip, rough=0.5, spec=0.4, var=0.25):
    """Strand colour from root to tip with per-strand variation (EEVEE renders the curves as strips)."""
    m, N, L, b = nodes_mat(name)
    hi = N.new('ShaderNodeHairInfo')
    ramp = N.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = lin(root); ramp.color_ramp.elements[1].color = lin(tip)
    L.new(hi.outputs['Intercept'], ramp.inputs['Fac'])
    vr = N.new('ShaderNodeMapRange'); vr.inputs['To Min'].default_value = 1 - var; vr.inputs['To Max'].default_value = 1 + var * 0.6
    L.new(hi.outputs['Random'], vr.inputs['Value'])
    comb = N.new('ShaderNodeCombineColor')
    for k in ('Red', 'Green', 'Blue'): L.new(vr.outputs['Result'], comb.inputs[k])
    mul = N.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.inputs['Factor'].default_value = 1.0
    L.new(ramp.outputs['Color'], rgba_in(mul)[0]); L.new(comb.outputs['Color'], rgba_in(mul)[1])
    L.new(rgba_out(mul), b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = rough; b.inputs['Specular IOR Level'].default_value = spec
    return m

def attr_mix(N, L, attr, a, b, sharp=False):
    """Colour a where the point attribute is 0, b where it is 1 (sharp: a crisp edge where it crosses 0.5)."""
    at = N.new('ShaderNodeAttribute'); at.attribute_name = attr
    fac = at.outputs['Fac']
    if sharp:
        mr = N.new('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = 0.45; mr.inputs['From Max'].default_value = 0.52
        L.new(fac, mr.inputs['Value']); fac = mr.outputs['Result']
    mx = N.new('ShaderNodeMix'); mx.data_type = 'RGBA'; L.new(fac, mx.inputs['Factor'])
    for s, c in zip(rgba_in(mx), (a, b)):
        if isinstance(c, tuple): s.default_value = c
        else: L.new(c, s)
    return rgba_out(mx)

def fabric_bump(N, L, b, scale=2200, strength=0.18):
    tc = N.new('ShaderNodeTexCoord'); wv = N.new('ShaderNodeTexWave'); wv.wave_type = 'BANDS'
    wv.inputs['Scale'].default_value = scale; wv.inputs['Distortion'].default_value = 2
    L.new(tc.outputs['Object'], wv.inputs['Vector'])
    bump = N.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = strength; bump.inputs['Distance'].default_value = 0.0004
    L.new(wv.outputs['Fac'], bump.inputs['Height']); L.new(bump.outputs['Normal'], b.inputs['Normal'])

def shorts_material():
    m, N, L, b = nodes_mat('Shorts')
    c = attr_mix(N, L, 'band', lin(PALETTE['shorts']), lin(PALETTE['waistband']))
    c = attr_mix(N, L, 'stripe', c, lin(PALETTE['accent']), sharp=True)
    L.new(c, b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.55; b.inputs['Sheen Weight'].default_value = 0.35
    b.inputs['Sheen Tint'].default_value = lin('#9AA3AE'); b.inputs['Specular IOR Level'].default_value = 0.4
    fabric_bump(N, L, b)
    return m

def shoe_material():
    m, N, L, b = nodes_mat('Trainers')
    c = attr_mix(N, L, 'heel', lin(PALETTE['shoe']), lin(PALETTE['accent']))
    # laces: light grey bands across the instep
    tc = N.new('ShaderNodeTexCoord'); sep = N.new('ShaderNodeSeparateXYZ'); L.new(tc.outputs['Object'], sep.inputs[0])
    sw = N.new('ShaderNodeMath'); sw.operation = 'SINE'; mul = N.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'
    mul.inputs[1].default_value = 380; L.new(sep.outputs['Y'], mul.inputs[0]); L.new(mul.outputs[0], sw.inputs[0])
    gt = N.new('ShaderNodeMath'); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = 0.2; L.new(sw.outputs[0], gt.inputs[0])
    la = N.new('ShaderNodeAttribute'); la.attribute_name = 'lace'
    lf = N.new('ShaderNodeMath'); lf.operation = 'MULTIPLY'; L.new(la.outputs['Fac'], lf.inputs[0]); L.new(gt.outputs[0], lf.inputs[1])
    mx = N.new('ShaderNodeMix'); mx.data_type = 'RGBA'; L.new(lf.outputs[0], mx.inputs['Factor'])
    L.new(c, rgba_in(mx)[0]); rgba_in(mx)[1].default_value = lin('#BFC4CA'); c = rgba_out(mx)
    c = attr_mix(N, L, 'trim', c, lin('#D9DCE0'))
    L.new(c, b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.6; b.inputs['Sheen Weight'].default_value = 0.2
    fabric_bump(N, L, b, 1500, 0.12)
    return m

def all_materials():
    M = {}
    M['body'] = fur_material('Leon fur', PALETTE['fur'], PALETTE['fur_light'])
    M['fur_head'] = fur_material('Head fur base', PALETTE['fur'], PALETTE['fur_light'], cavity_attr=False, scale=0.5)
    M['cream'] = fur_material('Muzzle base', PALETTE['cream'], '#F7EEDC', cavity_attr=False, scale=0.5)
    M['mane_base'] = simple('Mane base', PALETTE['mane'], 0.8)
    M['nose'] = simple('Nose', PALETTE['nose'], 0.38, spec=0.5)
    M['nostril'] = simple('Nostril', '#1E1210', 0.6)
    M['sclera'] = simple('Sclera', '#F4EFE6', 0.18, spec=0.6, coat=0.6)
    M['iris'] = simple('Iris', PALETTE['iris'], 0.25, coat=0.8)
    M['pupil'] = simple('Pupil', '#0E0907', 0.2, coat=0.8)
    M['glint'] = simple('Glint', '#FFFFFF', 0.1); M['glint'].node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 3.0
    M['glint'].node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value = (1, 1, 1, 1)
    M['lash'] = simple('Lash line', '#24140E', 0.5)
    M['brow'] = fur_material('Brow', PALETTE['brow'], '#5E3A28', cavity_attr=False, scale=0.4)
    M['inner_ear'] = simple('Inner ear', PALETTE['inner_ear'], 0.7, sheen=0.4)
    M['mouth'] = simple('Mouth line', '#2A1712', 0.6)
    M['hair_fur'] = hair_material('Fur strands', '#A56A31', '#D29F5C', var=0.15)
    M['hair_cream'] = hair_material('Cream strands', '#E3D2B2', '#FAF4E8', var=0.08)
    M['hair_body'] = hair_material('Body fur strands', '#AE7C3E', '#DDB271', var=0.12)
    M['hair_brow'] = hair_material('Brow strands', '#3A2116', '#5A3726', var=0.1)
    M['whisker'] = hair_material('Whiskers', '#EDE6DA', '#FFFFFF', rough=0.35, var=0.03)
    M['hair_mane'] = hair_material('Mane strands', PALETTE['mane_dark'], PALETTE['mane_light'], rough=0.45, var=0.3)
    M['shorts'] = shorts_material(); M['shoes'] = shoe_material()
    return M

# --------------------------------------------------------------------------------- studio
def studio(sc, head_c):
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
    sc.eevee.taa_render_samples = 64
    sc.render.resolution_x = sc.render.resolution_y = 720
    sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Punchy'
    sc.view_settings.exposure = -0.2
    for k, v in (('use_shadows', True), ('use_raytracing', True)):
        try: setattr(sc.eevee, k, v)
        except AttributeError: pass
    w = bpy.data.worlds.new('Studio'); sc.world = w; w.use_nodes = True
    wn, wl = w.node_tree.nodes, w.node_tree.links
    wn['Background'].inputs['Color'].default_value = lin('#D4DADF'); wn['Background'].inputs['Strength'].default_value = 0.35
    cam_bg = wn.new('ShaderNodeBackground'); cam_bg.inputs['Color'].default_value = lin(PALETTE['bg']); cam_bg.inputs['Strength'].default_value = 1.0
    lp = wn.new('ShaderNodeLightPath'); mx = wn.new('ShaderNodeMixShader')
    wl.new(lp.outputs['Is Camera Ray'], mx.inputs[0]); wl.new(wn['Background'].outputs[0], mx.inputs[1]); wl.new(cam_bg.outputs[0], mx.inputs[2])
    wl.new(mx.outputs[0], wn['World Output'].inputs['Surface'])
    S = collection('Studio')
    m, N, L, b = nodes_mat('Floor')
    b.inputs['Base Color'].default_value = lin(PALETTE['floor']); b.inputs['Roughness'].default_value = 0.85
    geo = N.new('ShaderNodeNewGeometry'); ln = N.new('ShaderNodeVectorMath'); ln.operation = 'LENGTH'
    rng = N.new('ShaderNodeMapRange'); rng.inputs['From Min'].default_value = 1.4; rng.inputs['From Max'].default_value = 4.5
    em = N.new('ShaderNodeEmission'); em.inputs['Color'].default_value = lin(PALETTE['bg'])
    mx = N.new('ShaderNodeMixShader')
    L.new(geo.outputs['Position'], ln.inputs[0]); L.new(ln.outputs['Value'], rng.inputs['Value']); L.new(rng.outputs['Result'], mx.inputs[0])
    L.new(b.outputs[0], mx.inputs[1]); L.new(em.outputs[0], mx.inputs[2]); L.new(mx.outputs[0], N['Material Output'].inputs['Surface'])
    me = bpy.data.meshes.new('Floor'); bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30); bm.to_mesh(me); bm.free()
    me.materials.append(m); fl = bpy.data.objects.new('Floor', me); S.objects.link(fl)
    def light(name, loc, energy, size, color, target=V((0, 0, 1.0))):
        ld = bpy.data.lights.new(name, 'AREA'); ld.energy = energy; ld.color = lin(color)[:3]; ld.shape = 'DISK'; ld.size = size
        ob = bpy.data.objects.new(name, ld); S.objects.link(ob); ob.location = loc
        ob.rotation_euler = (target - V(loc)).to_track_quat('-Z', 'Y').to_euler()
    light('Key', (-2.2, -2.8, 3.1), 520, 1.6, '#FFF3E4')
    light('Fill', (2.9, -2.0, 1.5), 140, 3.0, '#E6EEFA')
    light('Rim L', (-2.2, 2.4, 2.4), 420, 1.2, '#FFF0DC')
    light('Rim R', (2.4, 2.2, 2.0), 360, 1.2, '#EAF1FF')
    light('Top', (0, 0.2, 4.0), 120, 2.5, '#FFFFFF', target=V((0, 0, 0)))
    cams = {}
    target = V((0, -0.02, 0.92))
    for name, az in (('Cam front', 0), ('Cam 3q', -35), ('Cam side', -90)):
        cd = bpy.data.cameras.new(name); cd.lens = 55
        ob = bpy.data.objects.new(name, cd); S.objects.link(ob)
        a = math.radians(az); dist = 3.55
        ob.location = target + V((math.sin(a) * dist, -math.cos(a) * dist, 0.12))
        ob.rotation_euler = (target - ob.location).to_track_quat('-Z', 'Y').to_euler()
        cams[name] = ob
    cd = bpy.data.cameras.new('Cam face'); cd.lens = 85
    fc = bpy.data.objects.new('Cam face', cd); S.objects.link(fc)
    a = math.radians(-28)
    fc.location = head_c + V((math.sin(a) * 1.35, -math.cos(a) * 1.35, 0.04))
    fc.rotation_euler = (head_c - fc.location).to_track_quat('-Z', 'Y').to_euler()
    cams['Cam face'] = fc
    sc.camera = cams['Cam 3q']
    return cams

def render_stills(sc, cams, out, which, res=720):
    sc.render.resolution_x = sc.render.resolution_y = res
    for name in which:
        sc.camera = cams[name]
        sc.render.filepath = f'{out}/{name.split()[1]}.png'
        bpy.ops.render.render(write_still=True)

# --------------------------------------------------------------------------------- main
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    C = collection('Leon')
    body, low = load_body(opt('--base'))
    link_only(body, C); link_only(low, C)
    sculpt_body(body)
    rig = build_rig(C)
    skin_from_low(rig, low, body)
    low.hide_render = True; low.hide_viewport = True
    M = all_materials()
    rng = np.random.default_rng(11)
    shoes = build_shoes(body, C, M['shoes'])
    garments = [build_shorts(body, C, M['shorts']), shoes, *build_soles(shoes, C, sole_material())]
    for g in garments:
        m = g.modifiers.new('Armature', 'ARMATURE'); m.object = rig; g.parent = rig
    # the body under the garments and the human head are not needed
    P = verts_np(body.data)
    delete_verts(body, (P[:, 2] > 1.475) | (P[:, 2] < 0.07) |
                 ((P[:, 2] > 0.64) & (P[:, 2] < 0.95) & (np.abs(P[:, 0]) < 0.26)))
    body.data.materials.append(M['body'])
    for o in (body, *garments):
        for p in o.data.polygons: p.use_smooth = True
    HC, S = V((0, -0.035, 1.625)), 0.95
    H = collection('Leon head')
    build_head(H, M, HC, S, rng)
    for o in list(H.objects): parent_to_bone(o, rig, 'head')
    tail = build_tail(C, M, rng)
    parent_to_bone(tail, rig, 'tail'); parent_to_bone(bpy.data.objects['Tail tuft'], rig, 'tail')
    rig.location.z = 0.018                         # stand on the trainer soles
    sc.render.hair_type = 'STRIP'; sc.render.hair_subdiv = 1
    pose_stand(rig)
    body_fur_static(body, rig, C, M, rng)
    cams = studio(sc, HC + V((0, -0.06, 0.04)))
    if opt('--stills'):
        render_stills(sc, cams, opt('--stills'), (opt('--only') or 'Cam front,Cam 3q,Cam side').split(','), int(opt('--res', 720)))
    if opt('--out'):
        bpy.ops.wm.save_as_mainfile(filepath=opt('--out'), compress=True)

if __name__ == '__main__':
    main()
