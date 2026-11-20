"""GoHard exercise demonstrator: faceless athletic mannequin (concept Option A).

    blender -b --factory-startup --python build_mannequin.py -- --base <human_base_meshes_bundle.blend>
        --out DIR [--res 1080] [--samples 256] [--views front,side,3q] [--save mannequin.blend]

Body: Blender Studio's CC0 "Human Base Meshes" v1.4.1 realistic male (multires level 2), muscle forms strengthened
in code. Head: the face is cut off at mid-neck and a smooth faceless head is lofted from the neck's own edge loop, so
the surface is continuous. Rig: Rigify (ships with Blender) fitted to the mesh; finger joints are found from the
hand geometry (geodesic fingertips + anatomical phalanx ratios). Clothes: shells of the body surface.
Helpers come from ../v2/build_leon_v2.py.
"""
import bpy, bmesh, math, sys, os, heapq, importlib.util
import numpy as np
from mathutils import Vector as V, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('v2', os.path.join(HERE, '..', 'v2', 'build_leon_v2.py'))
v2 = importlib.util.module_from_spec(spec); spec.loader.exec_module(v2)
for k in ('lin verts_np set_verts normals_np edges_np smooth_field smoothstep delete_verts metaball to_mesh ell cap '
          'shell nodes_mat attr_mix fabric_bump rgba_in rgba_out region_weights hull2d').split():
    globals()[k] = getattr(v2, k)

ARGV = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
def opt(k, d=None): return ARGV[ARGV.index(k) + 1] if k in ARGV else d

COL = dict(skin='#33363B', shorts='#25282C', band='#1C1E21', accent='#0062CC', upper='#1B1D20', lace='#7A7F87',
           sole='#ECEBE8', bg='#DFE3E8', floor='#C9CED4')

# ------------------------------------------------------------------ body
def sculpt(ob):
    """Athletic definition without bodybuilder bulk: band-pass muscle separations, modest volume, narrow waist."""
    me = ob.data; P = verts_np(me); n = len(P); E = edges_np(me); N = normals_np(me)
    w = region_weights(P)
    glute = np.exp(-((P[:, 2] - 0.86) / 0.11) ** 2) * smoothstep(0.0, 0.06, P[:, 1])   # big convex forms: don't inflate
    crotch = np.exp(-(P[:, 0] / 0.06) ** 2 - ((P[:, 1] + 0.11) / 0.06) ** 2 - ((P[:, 2] - 0.80) / 0.07) ** 2)
    s1 = smooth_field(P, E, n, 8); s2 = smooth_field(s1, E, n, 160)
    P = P + N * (np.einsum('ij,ij->i', s1 - s2, N) * 1.25 * w * (1 - 0.9 * glute) * (1 - crotch))[:, None]
    G = [((0.195, 0.0, 1.32), (0.08, 0.085, 0.11), 0.014),   # deltoid
         ((0.11, 0.03, 1.42), (0.08, 0.06, 0.06), 0.004),     # trapezius (kept low)
         ((0.09, -0.08, 1.27), (0.08, 0.05, 0.07), 0.010),    # pectoral
         ((0.14, 0.06, 1.18), (0.06, 0.06, 0.12), 0.010),     # latissimus
         ((0.25, -0.01, 1.21), (0.055, 0.065, 0.10), 0.013),  # biceps / triceps
         ((0.33, -0.03, 0.99), (0.05, 0.05, 0.08), 0.008),    # forearm
         ((0.11, -0.06, 0.66), (0.10, 0.08, 0.18), 0.036),    # quadriceps
         ((0.07, -0.04, 0.55), (0.05, 0.05, 0.06), 0.016),    # vastus medialis
         ((0.12, -0.04, 0.56), (0.07, 0.06, 0.07), 0.012),    # lower quadriceps, visible below the hem
         ((0.16, -0.01, 0.62), (0.05, 0.06, 0.12), 0.012),    # vastus lateralis
         ((0.11, 0.06, 0.66), (0.08, 0.07, 0.15), 0.022),     # hamstrings
         ((0.06, 0.0, 0.70), (0.05, 0.06, 0.10), 0.010),      # adductors
         ((0.16, 0.07, 0.34), (0.065, 0.065, 0.11), 0.027),   # calf
         ((0.10, 0.06, 0.36), (0.045, 0.05, 0.09), 0.016),    # calf, medial head
         ((0.14, 0.03, 0.30), (0.06, 0.06, 0.12), 0.008),     # lower leg
         ((0.13, -0.02, 0.36), (0.04, 0.04, 0.09), 0.008)]    # tibialis
    disp = np.zeros(n)
    for c, r, a in G:
        for s in (1, -1):
            q = (P - np.array((c[0] * s, c[1], c[2]))) / np.array(r)
            disp += a * np.exp(-np.einsum('ij,ij->i', q, q) * 1.6)
    disp -= 0.010 * np.exp(-((P[:, 2] - 1.03) / 0.07) ** 2) * (np.abs(P[:, 0]) > 0.08)   # waist
    disp -= 0.008 * np.exp(-((P[:, 2] - 1.02) / 0.08) ** 2 - (P[:, 0] / 0.09) ** 2) * (P[:, 1] < -0.06)  # flat belly
    set_verts(me, P + N * (disp * w)[:, None])

# ------------------------------------------------------------------ faceless head lofted from the neck
ZCUT, HC = 1.445, V((0, -0.040, 1.565))
def faceless_head(ob):
    shape_ob = metaball('head shape', [ell((0, -0.038, 1.592), (0.076, 0.097, 0.092)),     # cranium
                                       ell((0, -0.060, 1.528), (0.058, 0.074, 0.074)),     # lower face: egg, soft jaw
                                       cap((0, -0.026, 1.38), (0, -0.034, 1.53), 0.064)], res=0.003)
    bpy.context.view_layer.update()
    shape = to_mesh(shape_ob, bpy.context.scene.collection, bpy.data.materials.new('tmp'), smooth_iters=4)
    sb = BVHTree.FromPolygons([v.co for v in shape.data.vertices], [p.vertices for p in shape.data.polygons])
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, ZCUT), plane_no=(0, 0, 1),
                           clear_outer=True)
    ring = [v for v in bm.verts if abs(v.co.z - ZCUT) < 1e-5 and any(e.is_boundary for e in v.link_edges)]
    ring.sort(key=lambda v: math.atan2(v.co.y - HC.y, v.co.x - HC.x))
    n, K = len(ring), 64
    th = [math.atan2(v.co.y - HC.y, v.co.x - HC.x) for v in ring]
    ph0 = [math.atan2(v.co.z - HC.z, math.hypot(v.co.x - HC.x, v.co.y - HC.y)) for v in ring]
    r0 = [(v.co - HC).length for v in ring]
    rings = [ring]
    for k in range(1, K):
        u = k / K; b = float(smoothstep(0.0, 0.16, np.array(u)))
        row = []
        for i in range(n):
            ph = ph0[i] + (math.pi / 2 - ph0[i]) * u
            d = V((math.cos(ph) * math.cos(th[i]), math.cos(ph) * math.sin(th[i]), math.sin(ph)))
            hit = sb.ray_cast(HC, d)[0]
            rh = (hit - HC).length if hit is not None else r0[i]
            row.append(bm.verts.new(HC + d * (r0[i] * (1 - b) + rh * b)))
        rings.append(row)
    top = bm.verts.new(sb.ray_cast(HC, V((0, 0, 1)))[0])
    new = []
    for a, c in zip(rings, rings[1:]):
        for i in range(n): new.append(bm.faces.new((a[i], a[(i + 1) % n], c[(i + 1) % n], c[i])))
    for i in range(n): new.append(bm.faces.new((rings[-1][i], rings[-1][(i + 1) % n], top)))
    f = new[len(new) // 2]; f.normal_update()
    if f.normal.dot(f.calc_center_median() - V((HC.x, HC.y, f.calc_center_median().z))) < 0:
        for f in new: f.normal_flip()
    for f in new: f.smooth = True
    bm.to_mesh(ob.data); bm.free(); ob.data.update()
    bpy.data.objects.remove(shape); bpy.data.materials.remove(bpy.data.materials['tmp'])
    # relax the lofted verts (pin the body), so the neck flows into the head
    me = ob.data; P = verts_np(me); E = edges_np(me)
    pin = P[:, 2] < ZCUT + 1e-4
    P = smooth_field(P, E, len(P), 20, 0.5, pin=pin)
    junction = (P[:, 2] < ZCUT + 1e-4) | (P[:, 2] > 1.53)          # soften the jaw-to-neck corner only
    set_verts(me, smooth_field(P, E, len(P), 90, 0.5, pin=junction))

# ------------------------------------------------------------------ hand analysis for finger joints
def graph(P, E, mask):
    idx = np.nonzero(mask)[0]; loc = -np.ones(len(P), int); loc[idx] = np.arange(len(idx))
    e = E[mask[E[:, 0]] & mask[E[:, 1]]]
    nbr = [[] for _ in idx]
    for a, b in loc[e]:
        w = float(np.linalg.norm(P[idx[a]] - P[idx[b]])); nbr[a].append((b, w)); nbr[b].append((a, w))
    return idx, nbr

def dijkstra(nbr, srcs):
    d = np.full(len(nbr), np.inf); h = [(0.0, int(s)) for s in srcs]
    for s in srcs: d[s] = 0
    heapq.heapify(h)
    while h:
        dd, u = heapq.heappop(h)
        if dd > d[u]: continue
        for v, w in nbr[u]:
            if dd + w < d[v]: d[v] = dd + w; heapq.heappush(h, (dd + w, v))
    return d

def hand_joints(P, E):
    """Left-hand joint positions: CMC/MCP/PIP/DIP/tip per finger, from the mesh."""
    W = np.array(v2.JS['wrist']); a = np.array(v2.JS['hand']) - W; a /= np.linalg.norm(a)
    t = (P - W) @ a
    idx, nbr = graph(P, E, (P[:, 0] > 0.28) & (P[:, 2] < 0.95) & (t > -0.012) & (np.linalg.norm(P - W, axis=1) < 0.25))
    Q = P[idx]; tq = t[idx]
    dw = dijkstra(nbr, np.nonzero(tq < -0.006)[0])
    tips = []
    for v in np.argsort(-dw):
        if dw[v] < 0.06: break
        seen, front = {v}, [v]
        for _ in range(7):
            front = [j for i in front for j, _ in nbr[i] if j not in seen]; seen.update(front)
        if dw[v] >= max(dw[j] for j in seen) and all(np.linalg.norm(Q[v] - Q[o]) > 0.018 for o in tips):
            tips.append(v)
    print('fingertips found:', len(tips), [round(float(dw[v]), 3) for v in tips])
    assert len(tips) == 5, 'expected five fingertips'
    thumb = min(tips, key=lambda v: dw[v])
    lat = Q[thumb] - W; lat -= a * (lat @ a); lat /= np.linalg.norm(lat)
    fingers = sorted([v for v in tips if v != thumb], key=lambda v: -((Q[v] - W) @ lat))
    names = ['thumb', 'index', 'middle', 'ring', 'pinky']; order = [thumb] + fingers
    D = np.array([dijkstra(nbr, [v]) for v in order]); label = D.argmin(0)
    HL = float(np.linalg.norm(Q[order[2]] - W))
    ratio = dict(thumb=0.56, index=0.49, middle=0.55, ring=0.52, pinky=0.41)
    split = dict(thumb=(1.0, 0.57, 0.27), index=(1.0, 0.55, 0.27), middle=(1.0, 0.55, 0.27), ring=(1.0, 0.55, 0.27),
                 pinky=(1.0, 0.55, 0.28))
    J = {}
    for f, nm in enumerate(names):
        L = ratio[nm] * HL
        def at(s):
            for half in (0.003, 0.006, 0.010):
                band = (label == f) & (np.abs(D[f] - s) < half)
                if band.sum() >= 4: return Q[band].mean(0)
            return Q[order[f]]
        J[nm] = [at(L * k) for k in split[nm]] + [at(0.006)]
    mcps = np.array([J[n][0] for n in names[1:]])
    dorsal = np.cross(mcps[0] - mcps[3], a); dorsal /= np.linalg.norm(dorsal)
    if dorsal[0] < 0: dorsal = -dorsal                      # A-pose: palms face the thighs, backs face out
    print('hand length', round(HL, 3), 'thumb CMC', J['thumb'][0].round(3), 'index MCP', J['index'][0].round(3))
    return J, W, dorsal

# ------------------------------------------------------------------ Rigify rig fitted to the mesh
def build_rig(P, J, W, dorsal):
    bpy.ops.preferences.addon_enable(module='rigify')
    bpy.ops.object.armature_human_metarig_add()
    meta = bpy.context.object
    bpy.ops.object.mode_set(mode='EDIT'); eb = meta.data.edit_bones
    keep = ('spine', 'pelvis', 'shoulder', 'upper_arm', 'forearm', 'hand', 'palm', 'f_', 'thumb', 'thigh', 'shin', 'foot',
            'toe', 'heel')
    for b in list(eb):
        if not b.name.startswith(keep): eb.remove(b)
    zax = {b.name: b.z_axis.copy() for b in eb}
    def put(name, h, t, roll=None):
        for side, sx in (('L', 1), ('R', -1)):
            nm = name.replace('.L', '.' + side) if name.endswith('.L') else name
            if nm not in eb: continue
            b = eb[nm]; mir = lambda p: V((p[0] * sx, p[1], p[2]))
            b.head = mir(h); b.tail = mir(t)
            r = V(roll) if roll is not None else zax[nm]
            b.align_roll(V((r[0] * sx, r[1], r[2])) if roll is not None else r)
            if not name.endswith('.L'): break
    S = [(0, 0.010, 0.93), (0, 0.010, 1.02), (0, 0.005, 1.11), (0, 0.0, 1.21), (0, 0.0, 1.36), (0, -0.015, 1.425),
         (0, -0.025, 1.50), (0, -0.035, 1.72)]
    for i, nm in enumerate(['spine', 'spine.001', 'spine.002', 'spine.003', 'spine.004', 'spine.005', 'spine.006']):
        put(nm, S[i], S[i + 1])
    put('pelvis.L', (0, 0.01, 0.93), (0.11, -0.04, 1.03))
    js = v2.JS
    put('shoulder.L', (0.025, -0.02, 1.395), (0.165, 0.005, 1.385))
    put('upper_arm.L', js['shoulder'], js['elbow'], (0, 1, 0))
    put('forearm.L', js['elbow'], js['wrist'], (0, 1, 0))
    mcp = {k: J[k][0] for k in ('index', 'middle', 'ring', 'pinky')}
    put('hand.L', js['wrist'], (mcp['index'] + mcp['middle']) / 2, tuple(dorsal))
    for k, nm in zip(('index', 'middle', 'ring', 'pinky'), ('palm.01', 'palm.02', 'palm.03', 'palm.04')):
        put(nm + '.L', W + (mcp[k] - W) * 0.22, mcp[k], tuple(dorsal))
        for s in range(3): put(f'f_{k}.0{s + 1}.L', J[k][s], J[k][s + 1], tuple(dorsal))
    for s in range(3): put(f'thumb.0{s + 1}.L', J['thumb'][s], J['thumb'][s + 1], tuple(dorsal))
    # legs and feet from the measured joints and the foot geometry
    F = P[(P[:, 0] > 0) & (P[:, 2] < 0.05)]
    toe = F[F[:, 1].argmin()]; heel_y = F[:, 1].max(); ank = np.array(js['ankle'])
    ball = np.array((ank[0] + (toe[0] - ank[0]) * 0.8, toe[1] + 0.055, 0.025))
    put('thigh.L', js['hip'], js['knee'], (0, -1, 0)); put('shin.L', js['knee'], js['ankle'], (0, -1, 0))
    put('foot.L', js['ankle'], ball, (0, 0, 1)); put('toe.L', ball, (toe[0], toe[1], 0.025), (0, 0, 1))
    put('heel.02.L', (ank[0] - 0.035, heel_y - 0.01, 0.0), (ank[0] + 0.035, heel_y - 0.01, 0.0))
    bpy.ops.object.mode_set(mode='OBJECT')
    vl = bpy.context.view_layer
    for o in vl.objects: o.select_set(False)
    vl.objects.active = meta; meta.select_set(True)
    bpy.ops.pose.rigify_generate()
    rig = meta.data.rigify_target_rig; rig.name = 'Mannequin rig'
    meta.hide_render = meta.hide_viewport = True
    return rig

def smooth_weights(ob, iters=12):
    """Nearest-face transfer can jump between arm and torso in the armpit: smooth all weights over the mesh, normalise."""
    me = ob.data; n = len(me.vertices); G = ob.vertex_groups
    Wt = np.zeros((n, len(G)))
    for v in me.vertices:
        for g in v.groups: Wt[v.index, g.group] = g.weight
    Wt = smooth_field(Wt, edges_np(me), n, iters, 0.5)
    Wt[Wt < 0.01] = 0; Wt /= np.maximum(Wt.sum(1, keepdims=True), 1e-9)
    for gi, g in enumerate(G):
        g.remove(list(range(n)))
        nz = np.nonzero(Wt[:, gi])[0]; q = np.round(Wt[nz, gi] * 256) / 256
        for val in np.unique(q):
            if val > 0: g.add(nz[q == val].tolist(), float(val), 'REPLACE')

def skin(rig, low, body):
    vl = bpy.context.view_layer
    for o in vl.objects: o.select_set(False)
    low.select_set(True); rig.select_set(True); vl.objects.active = rig
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    for g in low.vertex_groups: body.vertex_groups.new(name=g.name)
    dt = body.modifiers.new('weights', 'DATA_TRANSFER'); dt.object = low
    dt.use_vert_data = True; dt.data_types_verts = {'VGROUP_WEIGHTS'}; dt.vert_mapping = 'POLYINTERP_NEAREST'
    dt.layers_vgroup_select_src = 'ALL'; dt.layers_vgroup_select_dst = 'NAME'
    with bpy.context.temp_override(object=body, active_object=body, selected_objects=[body]):
        bpy.ops.object.modifier_apply(modifier=dt.name)
    smooth_weights(body)
    body.parent = rig; body.modifiers.new('Armature', 'ARMATURE').object = rig
    low.hide_render = low.hide_viewport = True
    print('deform groups:', len(low.vertex_groups))

# ------------------------------------------------------------------ clothing
def skinned(ob, rig, smooth=True):
    ob.parent = rig; ob.modifiers.new('Armature', 'ARMATURE').object = rig
    if smooth: m = ob.modifiers.new('Smooth', 'SUBSURF'); m.levels = 0; m.render_levels = 1
    return ob

def envelope(ob, P_body, polys, clear_fn, iters=25):
    """Smooth a shell but keep it at least the clearance outside the body: bridges folds and toe gaps like fabric.
    Open rims (waist, hem, collar) stay where they are."""
    bb = BVHTree.FromPolygons([V(p) for p in P_body], polys)
    me = ob.data; H = verts_np(me); HE = edges_np(me); clear = clear_fn(H)
    FE = np.array([k for p in me.polygons for k in p.edge_keys]); FE.sort(1)
    ek, cnt = np.unique(FE, axis=0, return_counts=True)
    rim = np.zeros(len(H), bool); rim[ek[cnt == 1].ravel()] = True
    for _ in range(iters):
        H = smooth_field(H, HE, len(H), 6, 0.5, pin=rim)
        for i in range(len(H)):
            loc, nor, _, _ = bb.find_nearest(V(H[i]))
            if loc is not None and (V(H[i]) - loc).dot(nor) < clear[i]: H[i] = np.array(loc + nor * clear[i])
    set_verts(me, H)

def mat_skin():
    m, N, L, b = nodes_mat('Mannequin satin')
    cv = N.new('ShaderNodeAttribute'); cv.attribute_name = 'cavity'
    dk = N.new('ShaderNodeMapRange'); dk.inputs['From Min'].default_value = -1; dk.inputs['To Min'].default_value = 0.55
    dk.inputs['To Max'].default_value = 1.1; L.new(cv.outputs['Fac'], dk.inputs['Value'])
    mul = N.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.inputs['Factor'].default_value = 1
    rgba_in(mul)[0].default_value = lin(COL['skin']); comb = N.new('ShaderNodeCombineColor')
    for k in ('Red', 'Green', 'Blue'): L.new(dk.outputs['Result'], comb.inputs[k])
    L.new(comb.outputs['Color'], rgba_in(mul)[1]); L.new(rgba_out(mul), b.inputs['Base Color'])
    rg = N.new('ShaderNodeMapRange'); rg.inputs['From Min'].default_value = -1; rg.inputs['To Min'].default_value = 0.66
    rg.inputs['To Max'].default_value = 0.5; L.new(cv.outputs['Fac'], rg.inputs['Value']); L.new(rg.outputs['Result'], b.inputs['Roughness'])
    b.inputs['Specular IOR Level'].default_value = 0.4; b.inputs['Coat Weight'].default_value = 0.03
    b.inputs['Sheen Weight'].default_value = 0.12; b.inputs['Sheen Tint'].default_value = lin('#AEB4BC')
    return m

def mat_shorts():
    m, N, L, b = nodes_mat('Shorts')
    c = attr_mix(N, L, 'band', lin(COL['shorts']), lin(COL['band']))
    c = attr_mix(N, L, 'stripe', c, lin(COL['accent']), sharp=True)
    L.new(c, b.inputs['Base Color']); b.inputs['Roughness'].default_value = 0.7
    b.inputs['Sheen Weight'].default_value = 0.3; b.inputs['Sheen Tint'].default_value = lin('#8C949E')
    fabric_bump(N, L, b, 2600, 0.12)
    return m

def mat_shoe():
    m, N, L, b = nodes_mat('Shoes')
    tc = N.new('ShaderNodeTexCoord'); sep = N.new('ShaderNodeSeparateXYZ'); L.new(tc.outputs['Object'], sep.inputs[0])
    mul = N.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = 420
    sw = N.new('ShaderNodeMath'); sw.operation = 'SINE'; gt = N.new('ShaderNodeMath'); gt.operation = 'GREATER_THAN'
    gt.inputs[1].default_value = 0.35; la = N.new('ShaderNodeAttribute'); la.attribute_name = 'lace'
    lf = N.new('ShaderNodeMath'); lf.operation = 'MULTIPLY'
    L.new(sep.outputs['Y'], mul.inputs[0]); L.new(mul.outputs[0], sw.inputs[0]); L.new(sw.outputs[0], gt.inputs[0])
    L.new(la.outputs['Fac'], lf.inputs[0]); L.new(gt.outputs[0], lf.inputs[1])
    mx = N.new('ShaderNodeMix'); mx.data_type = 'RGBA'; L.new(lf.outputs[0], mx.inputs['Factor'])
    rgba_in(mx)[0].default_value = lin(COL['upper']); rgba_in(mx)[1].default_value = lin(COL['lace']); c = rgba_out(mx)
    c = attr_mix(N, L, 'trim', c, lin('#2E3034'))
    L.new(c, b.inputs['Base Color']); b.inputs['Roughness'].default_value = 0.65; b.inputs['Sheen Weight'].default_value = 0.25
    fabric_bump(N, L, b, 1800, 0.15)
    return m

def mat_sole():
    m, N, L, b = nodes_mat('Sole')
    L.new(attr_mix(N, L, 'outsole', lin(COL['sole']), lin('#55595F')), b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.6
    return m

# ------------------------------------------------------------------ pose helpers (world space, pivot at the bone head)
def pose_api(rig):
    vl = bpy.context.view_layer
    def W_(n): vl.update(); return rig.matrix_world @ rig.pose.bones[n].matrix
    def setW(n, M): rig.pose.bones[n].matrix = rig.matrix_world.inverted() @ M; vl.update()
    def rot(n, axis, deg):
        M = W_(n); h = M.translation.copy()
        setW(n, Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg), 4, V(axis)) @ Matrix.Translation(-h) @ M)
    def move(n, d): M = W_(n); M.translation += V(d); setW(n, M)
    def aim(n, d):
        M = W_(n); q = M.col[1].xyz.normalized().rotation_difference(V(d).normalized()); h = M.translation.copy()
        setW(n, Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h) @ M)
    def local_x(n, deg):  # bend about the bone's own X axis (finger curl)
        M = W_(n); rot(n, M.col[0].xyz, deg)
    return W_, rot, move, aim, local_x

def stand(rig):
    W_, rot, move, aim, local_x = pose_api(rig)
    print('switch props:', [(pb.name, k, round(pb[k], 2)) for pb in rig.pose.bones for k in pb.keys() if 'IK' in k or 'FK' in k])
    for s, k in (('L', 1), ('R', -1)):
        rig.pose.bones[f'upper_arm_parent.{s}']['IK_FK'] = 1.0
        aim(f'upper_arm_fk.{s}', (0.24 * k, 0.03, -1)); aim(f'forearm_fk.{s}', (0.17 * k, -0.07, -1))
        aim(f'hand_fk.{s}', (0.13 * k, -0.07, -1))
        for f in ('index', 'middle', 'ring', 'pinky'):
            for j in (1, 2, 3): local_x(f'f_{f}.0{j}.{s}', 10)
        move(f'foot_ik.{s}', (0.015 * k, 0, 0))

# ------------------------------------------------------------------ studio (Cycles on the CPU)
def studio(sc, C):
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = int(opt('--samples', 256))
    sc.cycles.use_denoising = opt('--denoise', '1') == '1'
    sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Punchy'; sc.view_settings.exposure = -0.1
    w = bpy.data.worlds.new('Studio'); sc.world = w; w.use_nodes = True; wn, wl = w.node_tree.nodes, w.node_tree.links
    wn['Background'].inputs['Color'].default_value = lin('#E6E9ED'); wn['Background'].inputs['Strength'].default_value = 0.2
    cb = wn.new('ShaderNodeBackground'); cb.inputs['Color'].default_value = lin(COL['bg'])
    lp = wn.new('ShaderNodeLightPath'); mx = wn.new('ShaderNodeMixShader')
    wl.new(lp.outputs['Is Camera Ray'], mx.inputs[0]); wl.new(wn['Background'].outputs[0], mx.inputs[1]); wl.new(cb.outputs[0], mx.inputs[2])
    wl.new(mx.outputs[0], wn['World Output'].inputs['Surface'])
    fm, N, L, b = nodes_mat('Floor'); b.inputs['Base Color'].default_value = lin(COL['floor']); b.inputs['Roughness'].default_value = 0.9
    geo = N.new('ShaderNodeNewGeometry'); ln = N.new('ShaderNodeVectorMath'); ln.operation = 'LENGTH'
    mr = N.new('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = 1.2; mr.inputs['From Max'].default_value = 4.0
    em = N.new('ShaderNodeEmission'); em.inputs['Color'].default_value = lin(COL['bg']); ms = N.new('ShaderNodeMixShader')
    L.new(geo.outputs['Position'], ln.inputs[0]); L.new(ln.outputs['Value'], mr.inputs['Value']); L.new(mr.outputs['Result'], ms.inputs[0])
    L.new(b.outputs[0], ms.inputs[1]); L.new(em.outputs[0], ms.inputs[2]); L.new(ms.outputs[0], N['Material Output'].inputs['Surface'])
    me = bpy.data.meshes.new('Floor'); bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
    bm.to_mesh(me); bm.free(); me.materials.append(fm); C.objects.link(bpy.data.objects.new('Floor', me))
    def light(name, loc, e, size, col, tgt=V((0, 0, 0.95))):
        d = bpy.data.lights.new(name, 'AREA'); d.energy = e; d.size = size; d.shape = 'DISK'; d.color = lin(col)[:3]
        o = bpy.data.objects.new(name, d); C.objects.link(o); o.location = loc
        o.rotation_euler = (tgt - V(loc)).to_track_quat('-Z', 'Y').to_euler()
    light('Key', (-2.0, -2.6, 2.9), 230, 2.6, '#FFF6EC'); light('Fill', (2.6, -2.2, 1.5), 80, 3.2, '#EEF3FA')
    light('Rim L', (-2.2, 2.2, 2.3), 210, 1.6, '#FFFFFF'); light('Rim R', (2.2, 2.2, 2.0), 190, 1.6, '#FFFFFF')
    light('Top', (0, 0.2, 3.8), 50, 2.5, '#FFFFFF', V((0, 0, 0)))
    cd = bpy.data.cameras.new('cam'); cam = bpy.data.objects.new('cam', cd); C.objects.link(cam); sc.camera = cam
    return cam, cd

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene; C = sc.collection
    body, low = v2.load_body(opt('--base')); body.name = body.data.name = 'Mannequin body'
    sculpt(body)
    me = body.data; P = verts_np(me); E = edges_np(me)
    J, Wr, dorsal = hand_joints(P, E)
    faceless_head(body)
    me = body.data; P = verts_np(me); E = edges_np(me); N = normals_np(me)
    cav = np.einsum('ij,ij->i', P - smooth_field(P, E, len(P), 30), N)
    me.attributes.new('cavity', 'FLOAT', 'POINT').data.foreach_set('value', np.clip(cav / 0.004, -1, 1))
    for p in me.polygons: p.use_smooth = True
    rig = build_rig(P, J, Wr, dorsal)
    skin(rig, low, body)
    # shorts: above the knee, loose leg, blue piping low on the outer seam
    shorts = shell(body, C, 'Shorts', lambda P: (P[:, 2] > 0.585) & (P[:, 2] < 1.0) & (np.abs(P[:, 0]) < 0.26),
                   lambda P: 0.008 + 0.016 * smoothstep(0.80, 0.60, P[:, 2]), 25, mat_shorts())
    sm = shorts.data; S = verts_np(sm); SE = edges_np(sm)
    crotch = (np.abs(S[:, 0]) < 0.08) & (S[:, 2] < 0.90)
    set_verts(sm, smooth_field(S, SE, len(S), 60, 0.5, pin=~crotch))
    hips = [p.vertices[:] for p in me.polygons if all(0.45 < P[i, 2] < 1.15 for i in p.vertices)]
    envelope(shorts, P, hips, lambda H: 0.007 + 0.014 * smoothstep(0.80, 0.60, H[:, 2]))
    S = verts_np(sm)                                   # level, clean hem and waistband edges
    FE = np.array([k for p in sm.polygons for k in p.edge_keys]); FE.sort(1)
    ek, cnt = np.unique(FE, axis=0, return_counts=True); rim = np.unique(ek[cnt == 1].ravel())
    S[rim, 2] = np.where(S[rim, 2] < 0.8, 0.598, 0.997); set_verts(sm, S)
    S = verts_np(sm)
    ang = np.arctan2(S[:, 1] + 0.01, np.abs(S[:, 0]) - 0.115)
    stripe = smooth_field(((np.abs(ang) < 0.07) & (S[:, 2] < 0.76)).astype(float)[:, None], SE, len(S), 3)[:, 0]
    for nm, val in (('stripe', stripe), ('band', (S[:, 2] > 0.955).astype(float))):
        sm.attributes.new(nm, 'FLOAT', 'POINT').data.foreach_set('value', val)
    sol = shorts.modifiers.new('Thickness', 'SOLIDIFY'); sol.thickness = 0.003; sol.offset = -1
    skinned(shorts, rig)
    # shoes: smooth envelope around the foot, separate soles
    polys = [p.vertices[:] for p in me.polygons if all(P[i, 2] < 0.16 for i in p.vertices)]
    shoes = shell(body, C, 'Shoes', lambda P: P[:, 2] < 0.115, lambda P: 0.008 + 0.006 * smoothstep(-0.03, -0.10, P[:, 1]),
                  30, mat_shoe())
    # drape over a toe-merged foot (the real toes are removed below), so no toe grooves show through
    foot = P[:, 2] < 0.16
    proxy = smooth_field(P, E, len(P), 120, 0.5, pin=~foot)
    envelope(shoes, proxy, polys, lambda H: 0.012 + 0.012 * smoothstep(-0.03, -0.11, H[:, 1]), iters=45)
    hm = shoes.data; H = verts_np(hm); H[H[:, 2] < 0.006, 2] = 0.006; set_verts(hm, H)
    cx = 0.17 * np.sign(H[:, 0])
    for nm, val in dict(trim=H[:, 2] < 0.014,
                        lace=(H[:, 1] < 0.02) & (H[:, 1] > -0.07) & (H[:, 2] > 0.05) & (np.abs(H[:, 0] - cx) < 0.02)).items():
        hm.attributes.new(nm, 'FLOAT', 'POINT').data.foreach_set('value', val.astype(float))
    skinned(shoes, rig)
    for so in v2.build_soles(shoes, C, mat_sole()):
        so.vertex_groups[0].name = 'DEF-foot.' + so.name[-1]; skinned(so, rig, smooth=False)
    torso = ~((np.abs(P[:, 0]) > 0.28) & (P[:, 2] < 1.0))
    delete_verts(body, (P[:, 2] < 0.085) | ((P[:, 2] > 0.64) & (P[:, 2] < 0.95) & (np.abs(P[:, 0]) < 0.25) & torso))
    body.data.materials.clear(); body.data.materials.append(mat_skin())
    rig.location.z = 0.018
    stand(rig)
    cam, cd = studio(sc, C)
    OUT = opt('--out'); os.makedirs(OUT, exist_ok=True)
    if opt('--save'):
        os.makedirs(os.path.dirname(opt('--save')), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=opt('--save'), compress=True)
    res = int(opt('--res', 1080)); sc.render.resolution_x = res; sc.render.resolution_y = int(res * 1.25)
    for view in [v for v in opt('--views', 'front,side,3q').split(',') if v]:
        az = dict(front=0, side=-90, q=-35, back=180, face=-25)['q' if view == '3q' else view]
        t, dist, cd.lens = (V((0, -0.04, 1.50)), 1.5, 85) if view == 'face' else (V((0, -0.02, 0.88)), 3.9, 55)
        a = math.radians(az)
        cam.location = t + V((math.sin(a) * dist, -math.cos(a) * dist, 0.10 if view != 'face' else 0.02))
        cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(OUT, f'mannequin_{view}.png'); bpy.ops.render.render(write_still=True)
        print('RENDERED', sc.render.filepath)
    print('DONE')

if __name__ == '__main__':
    main()
