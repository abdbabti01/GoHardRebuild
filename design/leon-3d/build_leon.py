"""Leon squat prototype: builds the model, materials, rig, squat animation, cameras and lights from scratch.

    blender -b --factory-startup --python build_leon.py -- --out leon_squat_prototype.blend [--report checks.json]

Everything is procedural (metaballs converted to meshes, bmesh tubes for the mane and tail) so the file can be rebuilt
and edited. Proportions follow design/coach/assets/leon-full.png; the face follows leon-avatar.png.
Leon squat prototype -- technique review pending. The squat timing and angles start from the pilot storyboard
(docs/avatar-pilot/squat-blocking.mjs) and are placeholders until a qualified reviewer sets them.

Axes: Z up, Leon faces -Y, his left is +X. Units are metres; Leon is about 1.9 m to the top of the mane.
"""
import bpy, bmesh, math, sys, json, random
from mathutils import Vector, Matrix, Quaternion
import numpy as np

ARGV = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
def opt(name, default=None):
    return ARGV[ARGV.index(name) + 1] if name in ARGV else default

V = Vector
FPS = 30
TIMING = dict(startHold=0.8, down=1.8, bottomHold=0.3, up=1.4, topHold=0.3, reps=3)
DURATION = TIMING['startHold'] + TIMING['reps'] * (TIMING['down'] + TIMING['bottomHold'] + TIMING['up'] + TIMING['topHold'])
FRAMES = round(DURATION * FPS)  # 366; frame FRAMES + 1 would equal frame 1
# Placeholder bottom of the squat (degrees): shin lean, thigh from vertical, trunk lean, arm raise. Reviewer sets these.
BOTTOM = dict(s=30.0, t=76.0, T=38.0, A=78.0)
MB = 0.575  # visible radius of a metaball element of radius 1 (measured)

# --------------------------------------------------------------------------------------------- palette (sRGB hex)
PALETTE = dict(fur='#C48D57', cream='#EFE2C8', mane='#6E3B20', mane_dark='#4A2715', mane_light='#8C522E',
               nose='#6B3E36', brow='#4A2D20', iris='#9A5A2A', inner_ear='#B97E57', shirt='#3B3D41',
               shorts='#2B2D31', shoe='#F2F1EE', sole='#C9CCD0', accent='#8DB7E6', floor='#8F969C')

def lin(hexstr):
    c = [int(hexstr[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)

# --------------------------------------------------------------------------------------------- skeleton (rest pose)
J = {}
for s, x in (('L', 1), ('R', -1)):
    toe = V((math.sin(math.radians(12)) * x, -math.cos(math.radians(12)), 0))
    J['hip' + s] = V((0.10 * x, 0.0, 0.88))
    J['knee' + s] = V((0.14 * x, -0.02, 0.48))
    J['ankle' + s] = V((0.165 * x, 0.0, 0.10))
    J['ball' + s] = J['ankle' + s] + toe * 0.13 + V((0, 0, -0.06))
    J['toe' + s] = toe
    J['clav' + s] = V((0.03 * x, 0.0, 1.40))
    J['shoulder' + s] = V((0.22 * x, 0.01, 1.37))
    J['elbow' + s] = V((0.30 * x, 0.03, 1.08))
    J['wrist' + s] = V((0.34 * x, 0.0, 0.83))
    J['fingers' + s] = V((0.35 * x, -0.01, 0.68))
J.update(pelvis=V((0, 0, 0.93)), spine=V((0, 0, 1.06)), chest=V((0, 0, 1.22)), neck=V((0, 0, 1.43)),
         headBase=V((0, -0.01, 1.52)), headTop=V((0, -0.01, 1.80)))
HC = V((0, -0.015, 1.665))  # head centre (before scaling)
HEAD_SCALE, HEAD_LIFT = 1.2, 0.035

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start, sc.frame_end = 1, FRAMES
    return sc

# --------------------------------------------------------------------------------------------- materials
def material(name, color, rough=0.6, sheen=0.0, emission=None, streaks=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = lin(color)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Sheen Weight'].default_value = sheen
    b.inputs['Sheen Tint'].default_value = lin(color)
    if streaks:
        nt = m.node_tree; tc = nt.nodes.new('ShaderNodeTexCoord'); mp = nt.nodes.new('ShaderNodeMapping')
        mp.inputs['Scale'].default_value = (70, 70, 7)
        nz = nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Detail'].default_value = 4
        bump = nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.35; bump.inputs['Distance'].default_value = 0.003
        nt.links.new(tc.outputs['Object'], mp.inputs['Vector']); nt.links.new(mp.outputs['Vector'], nz.inputs['Vector'])
        nt.links.new(nz.outputs['Fac'], bump.inputs['Height']); nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
    if emission:
        b.inputs['Emission Color'].default_value = lin(emission)
        b.inputs['Emission Strength'].default_value = 2.0
    return m

def rgba_in(n): return [i for i in n.inputs if i.type == 'RGBA']
def rgba_out(n): return [o for o in n.outputs if o.type == 'RGBA'][0]

def body_material():
    """Fur with the shirt and shorts drawn from two per-vertex fields (positive inside the garment), so hems stay
    clean and the clothing can never intersect the body."""
    m = material('Leon body', PALETTE['fur'], rough=0.7, sheen=0.15)
    nt = m.node_tree; N = nt.nodes; L = nt.links
    bsdf = N['Principled BSDF']
    def attr(name):
        a = N.new('ShaderNodeAttribute'); a.attribute_name = name; return a
    def gt(sock, val):
        n = N.new('ShaderNodeMath'); n.operation = 'GREATER_THAN'; L.new(sock, n.inputs[0]); n.inputs[1].default_value = val; return n
    def mix(fac, a, b):
        n = N.new('ShaderNodeMix'); n.data_type = 'RGBA'; L.new(fac, n.inputs['Factor'])
        for sock, c in zip(rgba_in(n), (a, b)):
            if isinstance(c, tuple): sock.default_value = c
            else: L.new(c, sock)
        return n
    shirt, shorts = attr('shirt'), attr('shorts')
    in_shirt, in_shorts = gt(shirt.outputs['Fac'], 0.0), gt(shorts.outputs['Fac'], 0.0)
    c1 = mix(in_shorts.outputs[0], lin(PALETTE['fur']), lin(PALETTE['shorts']))
    c2 = mix(in_shirt.outputs[0], rgba_out(c1), lin(PALETTE['shirt']))
    # a slightly darker band just inside each hem
    hem = N.new('ShaderNodeMath'); hem.operation = 'MINIMUM'
    near_s = N.new('ShaderNodeMath'); near_s.operation = 'LESS_THAN'; L.new(shirt.outputs['Fac'], near_s.inputs[0]); near_s.inputs[1].default_value = 0.012
    band_s = N.new('ShaderNodeMath'); band_s.operation = 'MULTIPLY'; L.new(near_s.outputs[0], band_s.inputs[0]); L.new(in_shirt.outputs[0], band_s.inputs[1])
    near_h = N.new('ShaderNodeMath'); near_h.operation = 'LESS_THAN'; L.new(shorts.outputs['Fac'], near_h.inputs[0]); near_h.inputs[1].default_value = 0.012
    band_h = N.new('ShaderNodeMath'); band_h.operation = 'MULTIPLY'; L.new(near_h.outputs[0], band_h.inputs[0]); L.new(in_shorts.outputs[0], band_h.inputs[1])
    band = N.new('ShaderNodeMath'); band.operation = 'MAXIMUM'; L.new(band_s.outputs[0], band.inputs[0]); L.new(band_h.outputs[0], band.inputs[1])
    dark = N.new('ShaderNodeMix'); dark.data_type = 'RGBA'; dark.blend_type = 'MULTIPLY'
    L.new(band.outputs[0], dark.inputs['Factor']); L.new(rgba_out(c2), rgba_in(dark)[0]); rgba_in(dark)[1].default_value = (0.55, 0.55, 0.58, 1)
    L.new(rgba_out(dark), bsdf.inputs['Base Color'])
    cloth = N.new('ShaderNodeMath'); cloth.operation = 'MAXIMUM'; L.new(in_shirt.outputs[0], cloth.inputs[0]); L.new(in_shorts.outputs[0], cloth.inputs[1])
    rough = N.new('ShaderNodeMapRange'); L.new(cloth.outputs[0], rough.inputs['Value']); rough.inputs['To Min'].default_value = 0.62; rough.inputs['To Max'].default_value = 0.85
    L.new(rough.outputs['Result'], bsdf.inputs['Roughness'])
    sheen = N.new('ShaderNodeMapRange'); L.new(cloth.outputs[0], sheen.inputs['Value']); sheen.inputs['To Min'].default_value = 0.15; sheen.inputs['To Max'].default_value = 0.1
    L.new(sheen.outputs['Result'], bsdf.inputs['Sheen Weight'])
    return m

# --------------------------------------------------------------------------------------------- geometry helpers
def collection(name):
    c = bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c); return c

_MB_N = 0

def metaball(name, elems, res=0.012):
    """elems: ('ell', centre, (a, b, c), rotation-quaternion or None) | ('cap', p0, p1, r). Visible sizes in metres."""
    global _MB_N
    _MB_N += 1
    mb = bpy.data.metaballs.new(f'mb{_MB_N}x')
    mb.resolution = mb.render_resolution = res
    mb.threshold = 0.6
    ob = bpy.data.objects.new(f'mb{_MB_N}x', mb)
    ob['want'] = name
    bpy.context.scene.collection.objects.link(ob)
    for e in elems:
        if e[0] == 'ell':
            _, c, abc, q = e
            m = max(abc)
            el = mb.elements.new(type='ELLIPSOID'); el.co = c; el.radius = m / MB
            el.size_x, el.size_y, el.size_z = (abc[0] / m, abc[1] / m, abc[2] / m)
            if q is not None: el.rotation = q
        else:
            _, p0, p1, r = e
            d = p1 - p0
            el = mb.elements.new(type='CAPSULE'); el.co = (p0 + p1) / 2; el.radius = r / MB
            el.size_x = d.length / 2
            el.rotation = V((1, 0, 0)).rotation_difference(d.normalized())
    return ob

def to_mesh(ob, coll, mat):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    name = ob['want']
    bpy.data.objects.remove(ob)
    new = bpy.data.objects.new(name, me)
    coll.objects.link(new)
    me.materials.append(mat)
    for p in me.polygons: p.use_smooth = True
    return new

def ell(c, abc, q=None): return ('ell', V(c), abc, q)
def cap(p0, p1, r): return ('cap', V(p0), V(p1), r)
def along(a, b, f): return a.lerp(b, f)
def aligned(a, b, abc):
    """Ellipsoid between a and b whose first axis follows a->b."""
    d = (b - a)
    return ('ell', (a + b) / 2, abc, V((1, 0, 0)).rotation_difference(d.normalized()))

def tube(name, coll, mat, pts, radii, flat=1.0, ring=10, up=V((0, 0, 1)), cap_end=True):
    """A tube through pts (Catmull-Rom resampled) with per-point radius; flat < 1 squashes it into a lock of hair."""
    bm = bmesh.new()
    P = [V(p) for p in pts]
    samples, rs = [], []
    n = 24
    for i in range(n + 1):
        u = i / n * (len(P) - 1); k = min(int(u), len(P) - 2); f = u - k
        p0, p1, p2, p3 = P[max(k - 1, 0)], P[k], P[k + 1], P[min(k + 2, len(P) - 1)]
        f2, f3 = f * f, f * f * f
        samples.append(0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f2 + (-p0 + 3 * p1 - 3 * p2 + p3) * f3))
        rs.append(radii[k] + (radii[k + 1] - radii[k]) * f)
    rings = []
    for i, p in enumerate(samples):
        t = (samples[min(i + 1, n)] - samples[max(i - 1, 0)]).normalized()
        a = t.cross(up); a = a.normalized() if a.length > 1e-6 else t.orthogonal().normalized()
        b = t.cross(a).normalized()
        rings.append([bm.verts.new(p + (a * math.cos(2 * math.pi * j / ring) + b * flat * math.sin(2 * math.pi * j / ring)) * rs[i]) for j in range(ring)])
    for r0, r1 in zip(rings, rings[1:]):
        for j in range(ring):
            bm.faces.new((r0[j], r0[(j + 1) % ring], r1[(j + 1) % ring], r1[j]))
    bm.faces.new(list(reversed(rings[0])))
    if cap_end:
        tip = bm.verts.new(samples[-1] + (samples[-1] - samples[-2]).normalized() * rs[-1])
        for j in range(ring): bm.faces.new((rings[-1][j], rings[-1][(j + 1) % ring], tip))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me); coll.objects.link(ob)
    return ob

def on_surface(ob, pts, offset):
    """Moves each point to the nearest point of ob's surface, pushed out along its normal by offset."""
    from mathutils.bvhtree import BVHTree
    me = ob.data
    t = BVHTree.FromPolygons([v.co for v in me.vertices], [p.vertices for p in me.polygons])
    out = []
    for p in pts:
        loc, nor, _, _ = t.find_nearest(p)
        out.append(loc + nor * offset)
    return out

def join(objs, name):
    vl = bpy.context.view_layer
    for o in vl.objects: o.select_set(False)
    for o in objs: o.select_set(True)
    vl.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].select_set(False)
    objs[0].name = name
    return objs[0]

# --------------------------------------------------------------------------------------------- the model
def build_model():
    M = dict(body=body_material(), fur=material('Fur', PALETTE['fur'], 0.7, 0.15), cream=material('Cream fur', PALETTE['cream'], 0.75, 0.2),
             mane=material('Mane', PALETTE['mane'], 0.6, 0.2, streaks=True), mane_dark=material('Mane dark', PALETTE['mane_dark'], 0.6, 0.2, streaks=True),
             mane_light=material('Mane light', PALETTE['mane_light'], 0.55, 0.2, streaks=True), nose=material('Nose', PALETTE['nose'], 0.35),
             brow=material('Brow', PALETTE['brow'], 0.6, 0.3), iris=material('Iris', PALETTE['iris'], 0.2),
             pupil=material('Pupil', '#120c0a', 0.15), sclera=material('Eye white', '#F6F2EA', 0.25),
             glint=material('Eye glint', '#FFFFFF', 0.1, emission='#FFFFFF'), inner_ear=material('Inner ear', PALETTE['inner_ear'], 0.6),
             shoe=material('Shoe', PALETTE['shoe'], 0.5), sole=material('Sole', PALETTE['sole'], 0.7), accent=material('Shoe accent', PALETTE['accent'], 0.5),
             mouth=material('Mouth line', '#3A221B', 0.5))
    C = collection('Leon')
    parts = {}

    # torso: pelvis, belly, chest, pecs, lats, traps, neck
    parts['Torso'] = to_mesh(metaball('Torso', [
        ell((0, 0.01, 0.93), (0.165, 0.12, 0.12)), ell((0.075, 0.065, 0.885), (0.09, 0.08, 0.09)), ell((-0.075, 0.065, 0.885), (0.09, 0.08, 0.09)),
        ell((0, 0.0, 1.07), (0.155, 0.11, 0.13)), ell((0, -0.005, 1.20), (0.18, 0.12, 0.11)), ell((0, -0.01, 1.30), (0.215, 0.13, 0.12)),
        ell((0.085, -0.075, 1.29), (0.1, 0.065, 0.08)), ell((-0.085, -0.075, 1.29), (0.1, 0.065, 0.08)),
        ell((0.10, 0.05, 1.26), (0.10, 0.08, 0.13)), ell((-0.10, 0.05, 1.26), (0.10, 0.08, 0.13)),
        ell((0.12, 0.02, 1.385), (0.11, 0.08, 0.06)), ell((-0.12, 0.02, 1.385), (0.11, 0.08, 0.06)),
        cap((0, 0.0, 1.38), (0, -0.005, 1.57), 0.075)]), C, M['body'])
    for s in 'LR':
        h, k, a = J['hip' + s], J['knee' + s], J['ankle' + s]
        parts['Leg.' + s] = to_mesh(metaball('Leg.' + s, [
            cap(h, k, 0.076), aligned(h + V((0, -0.01, 0)), along(h, k, 0.75), (0.17, 0.09, 0.092)),
            ell(k + V((0, -0.01, 0.0)), (0.056, 0.058, 0.06)), cap(k, along(k, a, 0.55), 0.05),
            aligned(along(k, a, 0.08) + V((0, 0.025, 0)), along(k, a, 0.55) + V((0, 0.018, 0)), (0.11, 0.054, 0.056)),
            cap(along(k, a, 0.5), a, 0.043), ell(a, (0.045, 0.045, 0.045))]), C, M['body'])
        sh, el, wr = J['shoulder' + s], J['elbow' + s], J['wrist' + s]
        parts['Arm.' + s] = to_mesh(metaball('Arm.' + s, [
            ell(sh + V((0.012 * (1 if s == 'L' else -1), 0, -0.01)), (0.096, 0.09, 0.096)), cap(sh, el, 0.066),
            aligned(along(sh, el, 0.25) + V((0, -0.025, 0)), along(sh, el, 0.85) + V((0, -0.02, 0)), (0.13, 0.066, 0.064)),
            aligned(along(sh, el, 0.2) + V((0, 0.03, 0)), along(sh, el, 0.85) + V((0, 0.03, 0)), (0.14, 0.06, 0.06)),
            cap(el, wr, 0.05), aligned(el + V((0, -0.01, -0.02)), along(el, wr, 0.6), (0.11, 0.064, 0.06)),
            ell(wr, (0.038, 0.034, 0.036))]), C, M['body'])
        # hand: palm faces the thigh, fingers together and slightly curled, thumb forward
        x = 1 if s == 'L' else -1
        d = (J['fingers' + s] - wr).normalized()
        side = V((x, 0, 0)); fwd = (V((0, -1, 0)) - d * d.dot(V((0, -1, 0)))).normalized()
        palm_c = wr + d * 0.05
        el_h = [aligned(wr + d * 0.01, wr + d * 0.09, (0.05, 0.05, 0.022))]
        for i, off in enumerate((-0.027, -0.009, 0.009, 0.027)):
            base = palm_c + d * 0.04 + fwd * off
            ln = 0.07 - abs(off) * 0.6
            el_h.append(cap(base, base + d * ln * 0.6 + side * -0.008, 0.0105))
            el_h.append(cap(base + d * ln * 0.6 + side * -0.008, base + d * ln + side * -0.024, 0.0095))
        tb = wr + d * 0.03 + fwd * 0.035 + side * -0.008
        el_h.append(cap(tb, tb + d * 0.045 + fwd * 0.02 + side * -0.012, 0.0125))
        parts['Hand.' + s] = to_mesh(metaball('Hand.' + s, el_h, res=0.006), C, M['fur'])
        # shoe: upper (white), sole (grey), a light-blue heel patch as in the artwork
        an, toe = J['ankle' + s], J['toe' + s]
        up = V((0, 0, 1))
        parts['Shoe.' + s] = to_mesh(metaball('Shoe.' + s, [
            aligned(an - toe * 0.07 + up * -0.04, an + toe * 0.19 + up * -0.05, (0.15, 0.058, 0.05)),
            ell(an - toe * 0.035 + up * -0.03, (0.06, 0.06, 0.06)), ell(an + toe * 0.17 + up * -0.06, (0.05, 0.055, 0.035))], res=0.008), C, M['shoe'])
        sole = metaball('Sole.' + s, [aligned(an - toe * 0.10 + up * -0.085, an + toe * 0.215 + up * -0.085, (0.17, 0.062, 0.02))], res=0.008)
        parts['Sole.' + s] = to_mesh(sole, C, M['sole'])
        parts['Accent.' + s] = to_mesh(metaball('Accent.' + s, [ell(an - toe * 0.045 + up * -0.035 + V((0.045 * x, 0, 0)), (0.03, 0.022, 0.025))], res=0.006), C, M['accent'])
    build_head(C, M, parts)
    build_tail(C, M, parts)
    # nothing may sit below the floor: lift the soles so their lowest point is z = 0
    low = min((parts['Sole.' + s].matrix_world @ v.co).z for s in 'LR' for v in parts['Sole.' + s].data.vertices)
    for s in 'LR':
        for k in ('Shoe.', 'Sole.', 'Accent.'):
            for v in parts[k + s].data.vertices: v.co.z -= low
    return C, M, parts

def build_head(C, M, parts):
    h = lambda x, y, z: HC + V((x, y, z))
    parts['Head'] = to_mesh(metaball('Head', [
        ell(h(0, 0.015, 0.02), (0.135, 0.13, 0.14)), ell(h(0, -0.05, 0.065), (0.10, 0.075, 0.07)),
        ell(h(0.065, -0.06, -0.03), (0.07, 0.07, 0.062)), ell(h(-0.065, -0.06, -0.03), (0.07, 0.07, 0.062)),
        cap(h(0, -0.07, 0.03), h(0, -0.155, -0.002), 0.04),
        ell(h(0.1, -0.035, -0.045), (0.065, 0.06, 0.07)), ell(h(-0.1, -0.035, -0.045), (0.065, 0.06, 0.07)),
        # relaxed upper lids
        ell(h(0.055, -0.098, 0.072), (0.04, 0.03, 0.014)), ell(h(-0.055, -0.098, 0.072), (0.04, 0.03, 0.014))], res=0.006), C, M['fur'])
    parts['Muzzle'] = to_mesh(metaball('Muzzle', [
        ell(h(0.037, -0.14, -0.048), (0.052, 0.046, 0.038)), ell(h(-0.037, -0.14, -0.048), (0.052, 0.046, 0.038)),
        ell(h(0, -0.155, -0.035), (0.03, 0.03, 0.026)), ell(h(0, -0.115, -0.09), (0.058, 0.048, 0.042)),
        ell(h(0, -0.095, -0.125), (0.05, 0.04, 0.045)), ell(h(0.065, -0.1, -0.07), (0.048, 0.042, 0.04)),
        ell(h(-0.065, -0.1, -0.07), (0.048, 0.042, 0.04))], res=0.006), C, M['cream'])
    nose = metaball('Nose', [ell(h(0, -0.19, 0.0), (0.04, 0.024, 0.025)), ell(h(0, -0.188, -0.017), (0.019, 0.02, 0.016))], res=0.004)
    parts['Nose'] = to_mesh(nose, C, M['nose'])
    eyes = []
    for x in (1, -1):
        c = h(0.055 * x, -0.104, 0.034)
        look = V((0.12 * x, -1, 0.03)).normalized()
        eyes += [to_mesh(metaball('EyeW', [ell(c, (0.034, 0.034, 0.034))], res=0.004), C, M['sclera']),
                 to_mesh(metaball('Iris', [ell(c + look * 0.0235, (0.0245, 0.0245, 0.0245))], res=0.003), C, M['iris']),
                 to_mesh(metaball('Pupil', [ell(c + look * 0.031, (0.0125, 0.0125, 0.0125))], res=0.002), C, M['pupil']),
                 to_mesh(metaball('Glint', [ell(c + look * 0.034 + V((0.007 * x, 0, 0.009)), (0.0048, 0.0048, 0.0048))], res=0.0015), C, M['glint'])]
        eyes.append(tube('Brow', C, M['brow'], on_surface(parts['Head'], [h(0.014 * x, -0.13, 0.085), h(0.055 * x, -0.125, 0.1), h(0.1 * x, -0.098, 0.086)], 0.006), [0.013, 0.016, 0.01], flat=0.7, ring=8))
        ear = to_mesh(metaball('Ear', [ell(h(0.128 * x, -0.012, 0.13), (0.05, 0.022, 0.056), Quaternion((0, 1, 0), math.radians(-28 * x)))], res=0.005), C, M['fur'])
        inner = to_mesh(metaball('InnerEar', [ell(h(0.124 * x, -0.031, 0.128), (0.032, 0.008, 0.037), Quaternion((0, 1, 0), math.radians(-28 * x)))], res=0.004), C, M['inner_ear'])
        eyes += [ear, inner]
    parts['Face details'] = join(eyes, 'Face details')
    mouth = [tube('Mouth', C, M['mouth'], on_surface(parts['Muzzle'], [h(0, -0.19, -0.03), h(0, -0.181, -0.05)], 0.0015), [0.004, 0.004], ring=6)]
    for x in (1, -1):
        mouth.append(tube('Mouth', C, M['mouth'], on_surface(parts['Muzzle'], [h(0, -0.181, -0.05), h(0.03 * x, -0.17, -0.066), h(0.062 * x, -0.15, -0.052)], 0.0015), [0.004, 0.004, 0.003], ring=6))
    parts['Mouth'] = join(mouth, 'Mouth')
    # mane: a dark base volume, then three layers of locks: a ruff framing the face, a crest swept up and back
    # from the hairline, and a drape falling behind the neck. Everything stays inside the shoulder line.
    parts['Mane base'] = to_mesh(metaball('Mane base', [
        ell(h(0, 0.1, 0.0), (0.18, 0.14, 0.2)), ell(h(0.12, 0.07, -0.03), (0.08, 0.09, 0.16)), ell(h(-0.12, 0.07, -0.03), (0.08, 0.09, 0.16)),
        ell(h(0, 0.05, 0.11), (0.12, 0.11, 0.09)), ell(h(0, 0.12, -0.15), (0.15, 0.1, 0.14)),
        ell(h(0.09, 0.04, -0.13), (0.07, 0.065, 0.09)), ell(h(-0.09, 0.04, -0.13), (0.07, 0.065, 0.09))], res=0.01), C, M['mane_dark'])
    rnd = random.Random(7)
    locks = []
    mats = [M['mane'], M['mane_light'], M['mane'], M['mane_dark']]
    back, down = V((0, 1, 0)), V((0, 0, -1))
    for i in range(18):
        th = math.radians(-122 + i * 14.4) + rnd.uniform(-0.04, 0.04)
        if abs(math.degrees(th)) < 38: continue
        sx, sz = math.sin(th), math.cos(th)
        radial = V((sx, 0, sz))
        root = h(0.13 * sx, -0.03 + 0.03 * abs(sx), 0.135 * sz - 0.01)
        g = 0.3 + 0.6 * max(0.0, -sz)
        p1 = root + radial * 0.05 + back * 0.012
        p2 = p1 + radial * 0.03 + back * 0.06 + down * 0.04 * g
        p3 = p2 + back * 0.05 + down * 0.08 * g
        locks.append(tube('Ruff', C, rnd.choice(mats[:3]), [root, p1, p2, p3], [0.04, 0.043, 0.03, 0.01], flat=0.45, ring=10, up=radial))
    for i in range(24):
        th = math.radians(-128 + i * 11.1) + rnd.uniform(-0.04, 0.04)
        sx, sz = math.sin(th), math.cos(th)
        radial = V((sx, 0, sz))
        root = h(0.165 * sx, 0.055 + 0.02 * abs(sx), 0.145 * sz + 0.005)
        g = 0.35 + 0.65 * max(0.0, -sz) + 0.25 * abs(sx)       # more gravity at the sides and below
        ln = rnd.uniform(0.85, 1.15)
        p1 = root + radial * 0.055 * ln + back * 0.03
        p2 = p1 + radial * 0.035 * ln + back * 0.09 * ln + down * 0.06 * g * ln
        p3 = p2 + radial * 0.01 + back * 0.06 * ln + down * 0.12 * g * ln
        p3.x = max(-0.2, min(0.2, p3.x))
        locks.append(tube('Lock', C, rnd.choice(mats), [root, p1, p2, p3], [0.05, 0.05, 0.036, 0.012], flat=0.45, ring=10, up=radial))
    for i, x in enumerate((-0.06, -0.03, 0.0, 0.03, 0.06)):
        lift = rnd.uniform(-0.015, 0.02)
        root = h(x, -0.07, 0.115)
        p1 = h(x * 1.05 + 0.015, -0.035, 0.19 + lift)
        p2 = h(x * 1.15 + 0.03, 0.06, 0.205 - abs(x) * 0.3 + lift)
        p3 = h(x * 1.6, 0.16, 0.12 - abs(x) * 0.3)
        p4 = h(x * 1.9, 0.2, 0.0)
        locks.append(tube('Crest', C, rnd.choice(mats), [root, p1, p2, p3, p4], [0.035, 0.045, 0.045, 0.03, 0.01], flat=0.45, ring=10, up=V((0, 0, 1))))
    for i, x in enumerate((-0.14, -0.1, -0.05, 0.0, 0.05, 0.1, 0.14)):
        root = h(x, 0.12, 0.0)
        locks.append(tube('Drape', C, rnd.choice(mats), [root, h(x * 1.05, 0.19, -0.1), h(x * 1.05, 0.2, -0.2), h(x * 1.0, 0.17, -0.29)],
                          [0.05, 0.05, 0.04, 0.012], flat=0.5, ring=10, up=V((0, 1, 0))))
    parts['Mane locks'] = join(locks, 'Mane locks')
    for k in ('Head', 'Muzzle', 'Nose', 'Face details', 'Mouth', 'Mane base', 'Mane locks'):
        for v in parts[k].data.vertices: v.co = HC + V((0, 0, HEAD_LIFT)) + (v.co - HC) * HEAD_SCALE

def build_tail(C, M, parts):
    # from the tailbone, back and towards Leon's left (away from the three-quarter camera), tuft clear of the floor
    pts = [V((0, 0.12, 0.88)), V((0.04, 0.24, 0.80)), V((0.12, 0.31, 0.68)), V((0.19, 0.31, 0.58))]
    t = tube('Tail', C, M['fur'], pts, [0.026, 0.023, 0.02, 0.018], ring=10, cap_end=False)
    tuft = to_mesh(metaball('Tuft', [aligned(V((0.18, 0.31, 0.60)), V((0.25, 0.28, 0.49)), (0.07, 0.045, 0.045)),
                                     ell(V((0.235, 0.29, 0.51)), (0.04, 0.04, 0.04))], res=0.006), C, M['mane_dark'])
    parts['Tail'] = join([t, tuft], 'Tail')

# --------------------------------------------------------------------------------------------- clothing fields
HEM_Z, WAIST_Z, NECK_Z, SLEEVE_T, SHORTS_T = 0.975, 1.0, 1.47, 0.42, 0.56

def seg_t(p, a, b):
    d = b - a; return (p - a).dot(d) / d.length_squared

def write_fields(ob, kind, side=None):
    me = ob.data
    shirt = me.attributes.new('shirt', 'FLOAT', 'POINT'); shorts = me.attributes.new('shorts', 'FLOAT', 'POINT')
    for i, v in enumerate(me.vertices):
        p = v.co; sv, hv = -1.0, -1.0
        if kind == 'torso':
            sv = min(p.z - HEM_Z, NECK_Z - p.z); hv = WAIST_Z - p.z
        elif kind == 'leg':
            h, k = J['hip' + side], J['knee' + side]
            sv = p.z - HEM_Z
            hv = min(WAIST_Z - p.z + 0.2, (SHORTS_T - seg_t(p, h, k)) * (k - h).length)
        elif kind == 'arm':
            sh, el = J['shoulder' + side], J['elbow' + side]
            sv = (SLEEVE_T - seg_t(p, sh, el)) * (el - sh).length
        shirt.data[i].value = sv; shorts.data[i].value = hv

# --------------------------------------------------------------------------------------------- rig
def build_rig(C):
    arm = bpy.data.armatures.new('Leon rig')
    rig = bpy.data.objects.new('Leon rig', arm); C.objects.link(rig)
    rig.show_in_front = True
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    E = arm.edit_bones
    def bone(name, head, tail, parent=None, connect=False, deform=True, roll=0.0):
        b = E.new(name); b.head, b.tail = head, tail; b.roll = roll
        if parent: b.parent = E[parent]; b.use_connect = connect
        b.use_deform = deform
        return b
    bone('root', V((0, 0, 0)), V((0, 0.35, 0)), deform=False)
    bone('hips', J['pelvis'], J['spine'], 'root')
    bone('spine', J['spine'], J['chest'], 'hips', True)
    bone('chest', J['chest'], J['neck'], 'spine', True)
    bone('neck', J['neck'], J['headBase'], 'chest', True)
    bone('head', J['headBase'], J['headTop'], 'neck', True)
    bone('tail', V((0, 0.12, 0.88)), V((0.19, 0.31, 0.58)), 'hips')
    for s in 'LR':
        bone('shoulder.' + s, J['clav' + s], J['shoulder' + s], 'chest')
        bone('upper_arm.' + s, J['shoulder' + s], J['elbow' + s], 'shoulder.' + s, True)
        bone('forearm.' + s, J['elbow' + s], J['wrist' + s], 'upper_arm.' + s, True)
        bone('hand.' + s, J['wrist' + s], J['fingers' + s], 'forearm.' + s, True)
        bone('thigh.' + s, J['hip' + s], J['knee' + s], 'hips')
        bone('shin.' + s, J['knee' + s], J['ankle' + s], 'thigh.' + s, True)
        bone('foot.' + s, J['ankle' + s], J['ball' + s], 'shin.' + s, True)
        bone('foot_ik.' + s, J['ankle' + s], J['ball' + s], 'root', deform=False)
        bone('knee_pole.' + s, J['knee' + s] + J['toe' + s] * 0.6, J['knee' + s] + J['toe' + s] * 0.6 + V((0, 0, 0.1)), 'root', deform=False)
        bone('elbow_ref.' + s, J['elbow' + s] + V((0, 0.4, 0)), J['elbow' + s] + V((0, 0.4, 0.1)), 'root', deform=False)
    # pole angles that leave the rest pose unchanged
    poles = {}
    for s in 'LR':
        base, ikb, pole = E['thigh.' + s], E['shin.' + s], E['knee_pole.' + s].head
        n = (ikb.tail - base.head).cross(pole - base.head)
        proj = n.cross(base.tail - base.head)
        a = base.x_axis.angle(proj)
        if base.x_axis.cross(proj).angle(base.tail - base.head) < 1: a = -a
        poles[s] = a
    bpy.ops.object.mode_set(mode='POSE')
    for s in 'LR':
        ik = rig.pose.bones['shin.' + s].constraints.new('IK')
        ik.target, ik.subtarget = rig, 'foot_ik.' + s
        ik.pole_target, ik.pole_subtarget, ik.pole_angle = rig, 'knee_pole.' + s, poles[s]
        ik.chain_count = 2
        cr = rig.pose.bones['foot.' + s].constraints.new('COPY_ROTATION')
        cr.target, cr.subtarget = rig, 'foot_ik.' + s
        # knees only bend forward
        for b in ('thigh.', 'shin.'):
            rig.pose.bones[b + s].ik_stretch = 0.0
    for pb in rig.pose.bones: pb.rotation_mode = 'QUATERNION'
    bpy.ops.object.mode_set(mode='OBJECT')
    return rig

def smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a))); return t * t * (3 - 2 * t)

def skin(rig, parts):
    """Weights: torso by height along the spine, legs and arms blended over the knee and elbow, rigid parts on one bone."""
    def add_mod(ob):
        m = ob.modifiers.new('Armature', 'ARMATURE'); m.object = rig
        ob.parent = rig
    def rigid(ob, bone):
        g = ob.vertex_groups.new(name=bone); g.add(range(len(ob.data.vertices)), 1.0, 'REPLACE'); add_mod(ob)
    for name, ob in parts.items():
        if name == 'Torso':
            gs = {b: ob.vertex_groups.new(name=b) for b in ('hips', 'spine', 'chest', 'neck')}
            for v in ob.data.vertices:
                z = v.co.z
                w = {'hips': 1 - smooth(1.0, 1.12, z), 'spine': smooth(1.0, 1.12, z) * (1 - smooth(1.18, 1.30, z)),
                     'chest': smooth(1.18, 1.30, z) * (1 - smooth(1.44, 1.52, z)), 'neck': smooth(1.44, 1.52, z)}
                for b, val in w.items():
                    if val > 1e-4: gs[b].add([v.index], val, 'REPLACE')
            add_mod(ob)
        elif name.startswith('Leg.') or name.startswith('Arm.'):
            s = name[-1]
            a, b, c = (('thigh.', 'shin.', 'knee') if name.startswith('Leg.') else ('upper_arm.', 'forearm.', 'elbow'))
            g1, g2 = ob.vertex_groups.new(name=a + s), ob.vertex_groups.new(name=b + s)
            j = J[c + s]
            axis = ((J['hip' + s] - j).normalized() - (J['ankle' + s] - j).normalized()) if c == 'knee' else \
                   ((J['shoulder' + s] - j).normalized() - (J['wrist' + s] - j).normalized())
            axis.normalize()
            width = 0.05 if c == 'knee' else 0.04
            for v in ob.data.vertices:
                w = smooth(-width, width, (j - v.co).dot(axis))  # 0 above the joint, 1 below
                if w < 1 - 1e-4: g1.add([v.index], 1 - w, 'REPLACE')
                if w > 1e-4: g2.add([v.index], w, 'REPLACE')
            add_mod(ob)
        elif name.startswith(('Hand.',)): rigid(ob, 'hand.' + name[-1])
        elif name.startswith(('Shoe.', 'Sole.', 'Accent.')): rigid(ob, 'foot.' + name[-1])
        elif name == 'Tail': rigid(ob, 'tail')
        else: rigid(ob, 'head')
    write_fields(parts['Torso'], 'torso')
    for s in 'LR':
        write_fields(parts['Leg.' + s], 'leg', s); write_fields(parts['Arm.' + s], 'arm', s)

# --------------------------------------------------------------------------------------------- animation
def ease(x): return x * x * (3 - 2 * x)

def phase_u(sec):
    """0 standing .. 1 bottom; the clip starts and ends standing still, so the loop joins invisibly."""
    T = TIMING; rep = T['down'] + T['bottomHold'] + T['up'] + T['topHold']
    x = (sec % DURATION) - T['startHold']
    if x < 0: return 0.0
    x %= rep
    if x < T['down']: return ease(x / T['down'])
    if x < T['down'] + T['bottomHold']: return 1.0
    if x < T['down'] + T['bottomHold'] + T['up']: return 1 - ease((x - T['down'] - T['bottomHold']) / T['up'])
    return 0.0

def angles(u):
    # hips lead (thigh and trunk ahead of the shin), as in the pilot storyboard
    return dict(s=math.radians(BOTTOM['s'] * u ** 1.3), t=math.radians(BOTTOM['t'] * u ** 0.95),
                T=math.radians(BOTTOM['T'] * u ** 0.75), A=math.radians(BOTTOM['A'] * u))

def hip_offset(a):
    """Movement of the hip joints from the mean sagittal leg chain (y forward is negative)."""
    shank, thigh = (J['ankleL'] - J['kneeL']).length, (J['kneeL'] - J['hipL']).length
    def chain(s, t):
        ky, kz = -shank * math.sin(s), shank * math.cos(s)
        return V((0, ky + thigh * math.sin(t), kz + thigh * math.cos(t)))
    return chain(a['s'], a['t']) - chain(0, 0)

def animate(rig):
    pb = rig.pose.bones
    rest_q = {b.name: b.matrix_local.to_quaternion() for b in rig.data.bones}
    def local_rot(name, angle):  # rotation about world X through the bone head, in the bone's own axes
        q = rest_q[name]; return q.inverted() @ Quaternion((1, 0, 0), angle) @ q
    for f in range(1, FRAMES + 2):
        u = phase_u((f - 1) / FPS); a = angles(u)
        off = hip_offset(a)
        pb['hips'].location = rest_q['hips'].inverted() @ off
        pb['hips'].rotation_quaternion = local_rot('hips', a['T'] * 0.4)
        pb['spine'].rotation_quaternion = local_rot('spine', a['T'] * 0.3)
        pb['chest'].rotation_quaternion = local_rot('chest', a['T'] * 0.3)
        pb['neck'].rotation_quaternion = local_rot('neck', -a['T'] * 0.3)
        pb['head'].rotation_quaternion = local_rot('head', -a['T'] * 0.25)
        pb['tail'].rotation_quaternion = local_rot('tail', math.radians(38) * u)
        for s in 'LR':
            pb['upper_arm.' + s].rotation_quaternion = local_rot('upper_arm.' + s, -(a['A'] + a['T']))
            pb['forearm.' + s].rotation_quaternion = local_rot('forearm.' + s, -math.radians(12) * u)
        for name in ('hips', 'spine', 'chest', 'neck', 'head', 'tail') + tuple(n + s for n in ('upper_arm.', 'forearm.') for s in 'LR'):
            if name == 'hips': pb[name].keyframe_insert('location', frame=f)
            pb[name].keyframe_insert('rotation_quaternion', frame=f)
    for fc in rig.animation_data.action.fcurves:
        for k in fc.keyframe_points: k.interpolation = 'LINEAR'

# --------------------------------------------------------------------------------------------- scene
def scene_setup(sc):
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
    sc.eevee.taa_render_samples = 32
    try: sc.eevee.use_shadows = True
    except AttributeError: pass
    sc.render.resolution_x = sc.render.resolution_y = 720
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new('Studio'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = lin('#D7DEE3')
    wn, wl = w.node_tree.nodes, w.node_tree.links
    cam_bg = wn.new('ShaderNodeBackground'); cam_bg.inputs['Color'].default_value = lin('#DFE3E6'); cam_bg.inputs['Strength'].default_value = 1.0
    lp = wn.new('ShaderNodeLightPath'); mx = wn.new('ShaderNodeMixShader')
    wl.new(lp.outputs['Is Camera Ray'], mx.inputs[0]); wl.new(wn['Background'].outputs[0], mx.inputs[1]); wl.new(cam_bg.outputs[0], mx.inputs[2])
    wl.new(mx.outputs[0], wn['World Output'].inputs['Surface'])
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.5
    S = collection('Studio')
    floor_m = material('Floor', PALETTE['floor'], 0.9)
    nt = floor_m.node_tree; N, Lk = nt.nodes, nt.links
    geo = N.new('ShaderNodeNewGeometry'); ln = N.new('ShaderNodeVectorMath'); ln.operation = 'LENGTH'
    rng = N.new('ShaderNodeMapRange'); rng.inputs['From Min'].default_value = 1.1; rng.inputs['From Max'].default_value = 4.0
    em = N.new('ShaderNodeEmission'); em.inputs['Color'].default_value = lin('#DFE3E6'); em.inputs['Strength'].default_value = 1.0
    mx = N.new('ShaderNodeMixShader')
    Lk.new(geo.outputs['Position'], ln.inputs[0]); Lk.new(ln.outputs['Value'], rng.inputs['Value']); Lk.new(rng.outputs['Result'], mx.inputs[0])
    Lk.new(N['Principled BSDF'].outputs[0], mx.inputs[1]); Lk.new(em.outputs[0], mx.inputs[2]); Lk.new(mx.outputs[0], N['Material Output'].inputs['Surface'])
    bpy.ops.mesh.primitive_plane_add(size=1)
    fl = bpy.context.active_object; fl.name = 'Floor'; fl.scale = (60, 60, 1); fl.data.materials.append(floor_m)
    for c in fl.users_collection: c.objects.unlink(fl)
    S.objects.link(fl)
    def light(name, kind, loc, energy, size, color='#FFFFFF', target=V((0, 0, 1.0))):
        ld = bpy.data.lights.new(name, kind); ld.energy = energy; ld.color = lin(color)[:3]
        if kind == 'AREA': ld.size = size
        else: ld.angle = math.radians(size)
        ob = bpy.data.objects.new(name, ld); S.objects.link(ob); ob.location = loc
        ob.rotation_euler = (target - V(loc)).to_track_quat('-Z', 'Y').to_euler()
        return ob
    light('Key', 'AREA', (-2.4, -2.6, 3.2), 330, 2.5, '#FFF6EA')
    light('Fill', 'AREA', (2.8, -2.2, 1.6), 110, 3.0, '#EAF2FF')
    light('Rim', 'AREA', (0.6, 2.8, 2.6), 300, 2.0, '#FFF1DE')
    light('Sun', 'SUN', (0, 0, 5), 0.3, 8.0, '#FFFFFF', target=V((0.4, 0.6, 0)))
    target = V((0, -0.08, 0.95))
    cams = {}
    for name, az, dist, z in (('Cam 3q', -35, 3.25, 1.2), ('Cam side', -90, 3.25, 1.15), ('Cam front', 0, 3.25, 1.15)):
        cd = bpy.data.cameras.new(name); cd.lens = 50; cd.sensor_width = 36
        ob = bpy.data.objects.new(name, cd); S.objects.link(ob)
        a = math.radians(az)
        ob.location = target + V((math.sin(a) * dist, -math.cos(a) * dist, z - target.z))
        ob.rotation_euler = (target - ob.location).to_track_quat('-Z', 'Y').to_euler()
        cams[name] = ob
    cd = bpy.data.cameras.new('Cam face'); cd.lens = 50; cd.sensor_width = 36
    fc = bpy.data.objects.new('Cam face', cd); S.objects.link(fc)
    ft = HC + V((0, 0, HEAD_LIFT - 0.02)); a = math.radians(-28)
    fc.location = ft + V((math.sin(a) * 1.15, -math.cos(a) * 1.15, 0.05)); fc.rotation_euler = (ft - fc.location).to_track_quat('-Z', 'Y').to_euler()
    cams['Cam face'] = fc
    sc.camera = cams['Cam 3q']
    return cams

# --------------------------------------------------------------------------------------------- checks
def evaluated(ob, dg):
    e = ob.evaluated_get(dg); me = e.to_mesh()
    co = np.empty(len(me.vertices) * 3); me.vertices.foreach_get('co', co)
    co = co.reshape(-1, 3) @ np.array(e.matrix_world.to_3x3()).T + np.array(e.matrix_world.translation)
    tris = None
    me.calc_loop_triangles()
    if len(me.loop_triangles):
        tris = np.empty(len(me.loop_triangles) * 3, dtype=np.int64); me.loop_triangles.foreach_get('vertices', tris); tris = tris.reshape(-1, 3)
    e.to_mesh_clear()
    return co, tris

def checks(sc, rig, parts):
    from mathutils.bvhtree import BVHTree
    rep = {'label': 'Leon squat prototype -- technique review pending', 'note': 'Geometry checks only; not a technique review.'}
    pb = rig.pose.bones
    feet0, sole_min, knee_bad, elbow_bad, com_out, overlaps = None, [], [], [], [], {}
    pelvis = []
    pairs = [('Hand.L', 'Leg.L'), ('Hand.R', 'Leg.R'), ('Hand.L', 'Torso'), ('Hand.R', 'Torso'), ('Arm.L', 'Leg.L'), ('Arm.R', 'Leg.R'),
             ('Tail', 'Leg.L'), ('Tail', 'Leg.R'), ('Mane locks', 'Arm.L'), ('Mane locks', 'Arm.R'), ('Hand.L', 'Hand.R'), ('Leg.L', 'Leg.R')]
    support = None
    prev = prev_v = None
    for f in range(1, FRAMES + 2):
        sc.frame_set(f)
        mw = rig.matrix_world
        p = (mw @ pb['hips'].matrix).translation.copy()
        if prev is not None:
            v = (p - prev) * FPS
            rep['pelvis_max_speed_m_s'] = round(max(rep.get('pelvis_max_speed_m_s', 0), v.length), 3)
            if prev_v is not None:
                rep['pelvis_max_accel_m_s2'] = round(max(rep.get('pelvis_max_accel_m_s2', 0), (v - prev_v).length * FPS), 3)
            prev_v = v
        prev = p
        for s in 'LR':
            m = mw @ pb['foot.' + s].matrix
            if f == 1: rep.setdefault('_foot0', {})[s] = m.copy()
            d = (m.translation - rep['_foot0'][s].translation).length
            rep['foot_max_shift_mm_all_frames'] = round(max(rep.get('foot_max_shift_mm_all_frames', 0), d * 1000), 3)
            h, k, a = (mw @ pb['thigh.' + s].head), (mw @ pb['shin.' + s].head), (mw @ pb['shin.' + s].tail)
            line = a - h; kp = h + line * ((k - h).dot(line) / line.length_squared)
            if (k - kp).dot(J['toe' + s]) < -0.002: knee_bad.append((f, s))
    rep.pop('_foot0', None)
    for f in sorted(set(list(range(1, FRAMES + 2, 6)) + [79, FRAMES + 1])):
        sc.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        mw = rig.matrix_world
        feet = [mw @ pb['foot.' + s].matrix for s in 'LR']
        if feet0 is None: feet0 = [m.copy() for m in feet]
        for m0, m1 in zip(feet0, feet):
            dpos = (m1.translation - m0.translation).length
            drot = math.degrees(m0.to_quaternion().rotation_difference(m1.to_quaternion()).angle)
            rep['foot_max_shift_mm'] = max(rep.get('foot_max_shift_mm', 0), round(dpos * 1000, 3))
            rep['foot_max_turn_deg'] = max(rep.get('foot_max_turn_deg', 0), round(drot, 3))
            if dpos > 0.001 or drot > 0.5: rep.setdefault('feet_moved', []).append(f)
        pelvis.append((f, np.array((mw @ pb['hips'].matrix).col[3][:3])))
        for s in 'LR':
            h, k, a = (mw @ pb['thigh.' + s].head), (mw @ pb['shin.' + s].head), (mw @ pb['shin.' + s].tail)
            toe = J['toe' + s]
            # knee must sit on the toe side of the hip-ankle line (bending forward), never behind it
            line = (a - h); kproj = h + line * ((k - h).dot(line) / line.length_squared)
            if (k - kproj).dot(toe) < -0.002: knee_bad.append((f, s))
            sh, el, wr = (mw @ pb['upper_arm.' + s].head), (mw @ pb['forearm.' + s].head), (mw @ pb['forearm.' + s].tail)
            bend = math.degrees((el - sh).angle(wr - el))
            if bend > 60 or ((el - sh).cross(wr - el)).x * (1) > 1e-4 and bend > 1: elbow_bad.append((f, s, round(bend, 1)))
        # centre of mass of the closed body parts (uniform density) against the feet's support area
        tot, mom = 0.0, np.zeros(3)
        for name in ('Torso', 'Leg.L', 'Leg.R', 'Arm.L', 'Arm.R', 'Head', 'Muzzle', 'Mane base', 'Hand.L', 'Hand.R'):
            co, tris = evaluated(parts[name], dg)
            p0, p1, p2 = co[tris[:, 0]], co[tris[:, 1]], co[tris[:, 2]]
            vol = np.einsum('ij,ij->i', p0, np.cross(p1, p2)) / 6.0
            tot += vol.sum(); mom += ((p0 + p1 + p2) / 4.0 * vol[:, None]).sum(0)
        com = mom / tot
        if support is None:
            pts = np.vstack([evaluated(parts['Sole.' + s], dg)[0] for s in 'LR'])
            support = (pts[:, 1].min(), pts[:, 1].max(), pts[:, 0].min(), pts[:, 0].max())
        margin_back, margin_front = support[1] - com[1], com[1] - support[0]
        if margin_back < 0 or margin_front < 0: com_out.append((f, round(float(com[1]), 3)))
        rep.setdefault('com_margin_min', [9, 9])
        rep['com_margin_min'] = [round(min(rep['com_margin_min'][0], float(margin_back)), 3), round(min(rep['com_margin_min'][1], float(margin_front)), 3)]
        for s in 'LR':
            co, _ = evaluated(parts['Sole.' + s], dg); sole_min.append(float(co[:, 2].min()))
        rep['tail_lowest_z_m'] = round(min(rep.get('tail_lowest_z_m', 9), float(evaluated(parts['Tail'], dg)[0][:, 2].min())), 3)
        trees = {}
        for a, b in pairs:
            for n in (a, b):
                if n not in trees:
                    co, tris = evaluated(parts[n], dg)
                    trees[n] = BVHTree.FromPolygons([tuple(x) for x in co], [tuple(t) for t in tris])
            hits = len(trees[a].overlap(trees[b]))
            if hits: overlaps.setdefault(f'{a} x {b}', []).append((f, hits))
    sc.frame_set(1)
    co1, _ = evaluated(parts['Torso'], bpy.context.evaluated_depsgraph_get())
    sc.frame_set(FRAMES + 1)
    co2, _ = evaluated(parts['Torso'], bpy.context.evaluated_depsgraph_get())
    rep['loop_max_vertex_gap_m'] = float(np.abs(co1 - co2).max())
    p = np.array([x[1] for x in pelvis])
    rep['feet_fixed'] = 'feet_moved' not in rep
    rep['sole_lowest_z_m'] = [round(min(sole_min), 5), round(max(sole_min), 5)]
    rep['knees_behind_line'] = knee_bad[:10]
    rep['elbows_odd'] = elbow_bad[:10]
    rep['com_outside_feet'] = com_out[:10]
    rep['overlaps'] = {k: v[:6] for k, v in overlaps.items()}
    rep['pelvis_drop_m'] = round(float(p[:, 2].max() - p[:, 2].min()), 3)
    sc.frame_set(1)
    return rep

# --------------------------------------------------------------------------------------------- main
def main():
    sc = reset()
    C, M, parts = build_model()
    rig = build_rig(C)
    skin(rig, parts)
    animate(rig)
    scene_setup(sc)
    sc['label'] = 'Leon squat prototype -- technique review pending'
    note = bpy.data.texts.new('README')
    note.write(__doc__)
    rep = checks(sc, rig, parts) if '--no-checks' not in ARGV else {}
    out = opt('--out')
    if out:
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=out, compress=True)
    if opt('--report'):
        with open(opt('--report'), 'w') as fh: json.dump(rep, fh, indent=1, default=str)
    print('REPORT', json.dumps(rep, default=str))

main()
