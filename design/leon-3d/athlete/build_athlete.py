"""GoHard charcoal athlete: still model built on BlendKit's free "Muscular Male Base Mesh with PBR Skin" (Dr toxic, royalty free).

    blender -b --factory-startup --disable-autoexec <muscular_male_base_mesh.blend> --python build_athlete.py --
        --out DIR [--res 1080] [--samples 160] [--views 3q[,front,side]] [--save athlete.blend]

Keeps the asset's Auto-Rig Pro rig (posed with plain Blender, no add-on). Changes: belly flattened and abdominals added,
the face replaced by a smooth faceless head with a blue visor, charcoal-black finish, black shorts, athletic shoes.
Helpers come from ../v2/build_leon_v2.py. Renders with Cycles on the CPU (low memory).
"""
import bpy, math, sys, os, importlib.util
import numpy as np
from mathutils import Vector as V, Matrix
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('v2', os.path.join(HERE, '..', 'v2', 'build_leon_v2.py'))
v2 = importlib.util.module_from_spec(spec); spec.loader.exec_module(v2)
from_v2 = ('lin verts_np set_verts normals_np edges_np smooth_field smoothstep delete_verts metaball to_mesh ell cap '
           'parent_to_bone shell nodes_mat attr_mix fabric_bump rgba_in rgba_out').split()
globals().update({k: getattr(v2, k) for k in from_v2})

ARGV = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
def opt(k, d=None): return ARGV[ARGV.index(k) + 1] if k in ARGV else d

SKIN, SHORTS, BAND, UPPER, ACCENT = '#141518', '#0B0C0E', '#060607', '#1A1C20', '#0062CC'
v2.PALETTE.update(shorts=SHORTS, waistband=BAND, shoe=UPPER, accent=ACCENT)
sc = bpy.context.scene; vl = bpy.context.view_layer
rig = bpy.data.objects['rig.002']; body = bpy.data.objects['body_low.002']

def op_on(ob, fn, **kw):
    with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]): fn(**kw)

# ------------------------------------------------------------------ clean up: old face parts, widgets, horror textures
for o in list(bpy.data.objects):
    if o.name.startswith(('cs_', 'Eyes_', 'Gum_', 'teeth', 'Tongue')): bpy.data.objects.remove(o)
for img in list(bpy.data.images): bpy.data.images.remove(img)
mw = body.matrix_world.copy(); body.parent = None; body.data.transform(mw); body.matrix_world = Matrix()

# ------------------------------------------------------------------ body: subdivide once, flatten the belly, add abdominals
sub = body.modifiers.new('sub', 'SUBSURF'); sub.levels = 1
op_on(body, bpy.ops.object.modifier_move_to_index, modifier='sub', index=0)
op_on(body, bpy.ops.object.modifier_apply, modifier='sub')
me = body.data; P = verts_np(me); N = normals_np(me); E = edges_np(me); n = len(P)
def group(name):
    gi = body.vertex_groups[name].index; w = np.zeros(n)
    for v in me.vertices:
        for g in v.groups:
            if g.group == gi: w[v.index] = g.weight
    return w
arms = sum(group(f'{g}.{s}') for g in ('arm_stretch', 'forearm_stretch', 'forearm_twist', 'hand', 'c_arm_twist_offset') for s in 'lr')
torso = (arms < 0.05)
zs = np.arange(0.93, 1.40, 0.02)
mid = (np.abs(P[:, 0]) < 0.04) & torso & (P[:, 1] < 0)
cur = np.array([P[mid & (np.abs(P[:, 2] - z) < 0.012), 1].min() for z in zs])
want = np.interp(zs, [0.93, 0.97, 1.01, 1.05, 1.09, 1.13, 1.17, 1.21, 1.25, 1.29, 1.33, 1.37],
                 [cur[0], -0.078, -0.085, -0.093, -0.103, -0.114, -0.123, -0.130, -0.135, -0.140, -0.150, cur[-1]])
push = np.interp(P[:, 2], zs, np.maximum(want - cur, 0), left=0, right=0)
D = np.zeros_like(P)
D[:, 1] = push * np.exp(-P[:, 0] ** 2 / (2 * 0.12 ** 2)) * smoothstep(0.03, -0.06, P[:, 1]) * torso
D = smooth_field(D, E, n, 12, 0.5)
P = P + D; set_verts(me, P); N = normals_np(me)
front = smoothstep(-0.35, -0.75, N[:, 1]) * torso * (P[:, 1] < 0)
g = lambda x, s: np.exp(-x ** 2 / (2 * s * s))
inside = smoothstep(0.10, 0.075, np.abs(P[:, 0])) * smoothstep(0.985, 1.02, P[:, 2]) * smoothstep(1.36, 1.31, P[:, 2])
groove = 0.0055 * g(P[:, 0], 0.0065) * inside                                             # linea alba
for z0 in (1.105, 1.185, 1.262): groove += 0.0035 * g(P[:, 2] - z0, 0.0065) * inside       # tendinous lines
groove += 0.004 * g(np.abs(P[:, 0]) - 0.098, 0.009) * smoothstep(0.98, 1.04, P[:, 2]) * smoothstep(1.34, 1.28, P[:, 2])  # outer edge
P = P - N * (groove * front)[:, None]; set_verts(me, P)
N = normals_np(me)
cav = np.einsum('ij,ij->i', P - smooth_field(P, E, n, 30, 0.5), N)
a = me.attributes.new('cavity', 'FLOAT', 'POINT'); a.data.foreach_set('value', np.clip(cav / 0.004, -1, 1))

# ------------------------------------------------------------------ clothing shells (rest pose; they carry the skin weights)
C = sc.collection
def skinned(ob, smooth=True):
    m = ob.modifiers.new('Armature', 'ARMATURE'); m.object = rig
    if smooth:      # (not on the soles: Cycles 4.5 crashes subdividing their large n-gon caps)
        m2 = ob.modifiers.new('Smooth', 'SUBSURF'); m2.levels = 0; m2.render_levels = 1
    return ob
shorts = shell(body, C, 'Shorts', lambda P: (P[:, 2] > 0.68) & (P[:, 2] < 1.045) & (np.abs(P[:, 0]) < 0.27),
               lambda P: 0.008 + 0.007 * smoothstep(0.86, 0.70, P[:, 2]), 25, v2.shorts_material())
sm = shorts.data; S = verts_np(sm); SE = edges_np(sm)
crotch = (np.abs(S[:, 0]) < 0.10) & (S[:, 2] < 0.97)
set_verts(sm, smooth_field(S, SE, len(S), 60, 0.5, pin=~crotch)); S = verts_np(sm)
ang = np.arctan2(S[:, 1] - 0.024, np.abs(S[:, 0]) - 0.143)
stripe = smooth_field(((np.abs(ang) < 0.12) & (S[:, 2] < 1.005)).astype(float)[:, None], SE, len(S), 5)[:, 0]
for nm, val in (('stripe', stripe), ('band', (S[:, 2] > 1.005).astype(float))):
    sm.attributes.new(nm, 'FLOAT', 'POINT').data.foreach_set('value', val)
sol = shorts.modifiers.new('Thickness', 'SOLIDIFY'); sol.thickness = 0.003; sol.offset = -1
skinned(shorts)

shoes = shell(body, C, 'Shoes', lambda P: P[:, 2] < 0.16,
              lambda P: 0.011 + 0.012 * smoothstep(-0.03, -0.12, P[:, 1]), 40, v2.shoe_material())
hm = shoes.data; H = verts_np(hm); HE = edges_np(hm)
# smooth envelope: bridge the toe gaps by smoothing, but never come closer to the foot than the wanted clearance
fb = BVHTree.FromPolygons([V(p) for p in P], [p.vertices for p in me.polygons if all(P[i, 2] < 0.2 for i in p.vertices)])
clear = 0.009 + 0.010 * smoothstep(-0.03, -0.12, H[:, 1])
for _ in range(25):
    H = smooth_field(H, HE, len(H), 6, 0.5)
    for i in range(len(H)):
        loc, nor, _, dist = fb.find_nearest(V(H[i]))
        if loc is None: continue
        d = V(H[i]) - loc; s = d.dot(nor)
        if s < clear[i]: H[i] = np.array(loc + nor * clear[i])
H[H[:, 2] < 0.007, 2] = 0.007; set_verts(hm, H)
cx = 0.20 * np.sign(H[:, 0])
for nm, val in dict(trim=H[:, 2] < 0.016, heel=(H[:, 1] > 0.125) & (H[:, 2] > 0.03) & (H[:, 2] < 0.11),
                    lace=(H[:, 1] < 0.03) & (H[:, 1] > -0.10) & (H[:, 2] > 0.065) & (np.abs(H[:, 0] - cx) < 0.026)).items():
    hm.attributes.new(nm, 'FLOAT', 'POINT').data.foreach_set('value', val.astype(float))
skinned(shoes)
soles = v2.build_soles(shoes, C, v2.sole_material())
for so in soles:
    so.vertex_groups[0].name = 'foot.' + so.name[-1].lower(); skinned(so, smooth=False)

# ------------------------------------------------------------------ head: remove the face, add a smooth faceless head + visor
wh = np.zeros(n); gi = body.vertex_groups['head.x'].index
for v in me.vertices:
    for gg in v.groups:
        if gg.group == gi: wh[v.index] = gg.weight
P = verts_np(me)
# faceless hood: skull, face, jaw and a neck that sinks into the traps; body skin inside it is removed, so where the
# traps meet the hood they intersect in a clean seam line
head_ob = metaball('Head', [ell((0, 0.006, 1.886), (0.100, 0.126, 0.132)),
                            ell((0, -0.040, 1.818), (0.084, 0.094, 0.090)),
                            ell((0, -0.066, 1.772), (0.060, 0.064, 0.048)),
                            ell((0, -0.030, 1.715), (0.056, 0.050, 0.055)),
                            cap((0, 0.04, 1.58), (0, 0.015, 1.80), 0.072)], res=0.004)
bpy.context.view_layer.update()
head = to_mesh(head_ob, C, bpy.data.materials.new('tmp'), smooth_iters=6)
hb = BVHTree.FromPolygons([v.co for v in head.data.vertices], [p.vertices for p in head.data.polygons])
def inside(p, margin=0.012):     # well inside: kept skin dips into the hood, so the seam is a clean intersection
    loc, nor, _, _ = hb.find_nearest(V(p)); return loc is not None and (V(p) - loc).dot(nor) < -margin
# pull the old head (ears, nose, chin) into the hood first, so trimming leaves only a clean intersection with the traps
hc = np.array([0, 0.0, 1.86]); pull = smoothstep(0.15, 0.6, wh) * (P[:, 2] > 1.6)
P = hc + (P - hc) * (1 - 0.65 * pull)[:, None]; set_verts(me, P)
hood = np.array([P[i, 2] > 1.5 and inside(P[i]) for i in range(n)])
cut = hood | (P[:, 2] < 0.115) | ((P[:, 2] > 0.80) & (P[:, 2] < 0.99) & (np.abs(P[:, 0]) < 0.27) & torso)
delete_verts(body, cut)
# visor: a parametric band ray-cast onto the head, so its edges are clean curves
cols, rows, tmax = 81, 9, math.radians(84)
c0 = V((0, 0.0, 1.852)); pts = []
for j in range(rows):
    t = j / (rows - 1) * 2 - 1
    for i in range(cols):
        th = (i / (cols - 1) * 2 - 1) * tmax; s = th / tmax
        zt = 1.862 - 0.010 * s * s + t * (0.019 - 0.010 * s * s)
        d = V((math.sin(th), -math.cos(th), (zt - c0.z) / 0.105)).normalized()
        hit, nor, _, _ = hb.ray_cast(c0, d)
        pts.append(hit + nor * 0.0012)
vm = bpy.data.meshes.new('Visor')
vm.from_pydata(pts, [], [(j * cols + i, j * cols + i + 1, (j + 1) * cols + i + 1, (j + 1) * cols + i)
                         for j in range(rows - 1) for i in range(cols - 1)])
visor = bpy.data.objects.new('Visor', vm); C.objects.link(visor)
for p in vm.polygons: p.use_smooth = True
s1 = visor.modifiers.new('Thick', 'SOLIDIFY'); s1.thickness = 0.005; s1.offset = 1; s1.use_even_offset = True
s2 = visor.modifiers.new('Round', 'SUBSURF'); s2.levels = s2.render_levels = 2
for ob in (head, visor): parent_to_bone(ob, rig, 'head.x')

# ------------------------------------------------------------------ materials
def skin_material():
    m, Nn, L, b = nodes_mat('Charcoal skin')
    cv = Nn.new('ShaderNodeAttribute'); cv.attribute_name = 'cavity'
    dark = Nn.new('ShaderNodeMapRange'); dark.inputs['From Min'].default_value = -1; dark.inputs['To Min'].default_value = 0.45
    dark.inputs['To Max'].default_value = 1.35; L.new(cv.outputs['Fac'], dark.inputs['Value'])
    mul = Nn.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.inputs['Factor'].default_value = 1
    rgba_in(mul)[0].default_value = lin(SKIN); comb = Nn.new('ShaderNodeCombineColor')
    for k in ('Red', 'Green', 'Blue'): L.new(dark.outputs['Result'], comb.inputs[k])
    L.new(comb.outputs['Color'], rgba_in(mul)[1]); L.new(rgba_out(mul), b.inputs['Base Color'])
    rough = Nn.new('ShaderNodeMapRange'); rough.inputs['From Min'].default_value = -1; rough.inputs['To Min'].default_value = 0.62
    rough.inputs['To Max'].default_value = 0.42; L.new(cv.outputs['Fac'], rough.inputs['Value']); L.new(rough.outputs['Result'], b.inputs['Roughness'])
    b.inputs['Coat Weight'].default_value = 0.12; b.inputs['Coat Roughness'].default_value = 0.3
    b.inputs['Sheen Weight'].default_value = 0.1; b.inputs['Sheen Roughness'].default_value = 0.45
    b.inputs['Specular IOR Level'].default_value = 0.4
    b.inputs['Sheen Tint'].default_value = lin('#9AA2AD')
    tc = Nn.new('ShaderNodeTexCoord'); nz = Nn.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 260
    bump = Nn.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.06
    L.new(tc.outputs['Object'], nz.inputs['Vector']); L.new(nz.outputs['Fac'], bump.inputs['Height']); L.new(bump.outputs['Normal'], b.inputs['Normal'])
    return m
skin = skin_material()
head_skin = skin.copy(); head_skin.name = 'Charcoal head'
head_skin.node_tree.nodes['Attribute'].attribute_name = 'none'   # no cavity data on the head: neutral 0 -> mid value
body.data.materials.clear(); body.data.materials.append(skin)
head.data.materials.clear(); head.data.materials.append(head_skin)
vmat, Nn, L, b = nodes_mat('Visor')
b.inputs['Base Color'].default_value = lin('#06183A'); b.inputs['Roughness'].default_value = 0.35
b.inputs['Coat Weight'].default_value = 0.5; b.inputs['Coat Roughness'].default_value = 0.28
b.inputs['Emission Color'].default_value = lin('#0062CC'); b.inputs['Emission Strength'].default_value = 2.2
visor.data.materials.append(vmat)
bpy.data.materials.remove(bpy.data.materials['tmp'])

# ------------------------------------------------------------------ pose: relaxed athletic ready stance
def W(nm): vl.update(); return rig.matrix_world @ rig.pose.bones[nm].matrix
def setW(nm, M): rig.pose.bones[nm].matrix = rig.matrix_world.inverted() @ M; vl.update()
def rot(nm, axis, deg):
    M = W(nm); h = M.translation.copy()
    setW(nm, Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg), 4, V(axis)) @ Matrix.Translation(-h) @ M)
def move(nm, d): M = W(nm); M.translation += V(d); setW(nm, M)
def aim(nm, d):
    M = W(nm); q = M.col[1].xyz.normalized().rotation_difference(V(d).normalized()); h = M.translation.copy()
    setW(nm, Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h) @ M)
rig.parent.location.z = 0.019                       # soles sit on the floor
rot('c_spine_03.x', (1, 0, 0), -5); rot('c_neck.x', (1, 0, 0), -2); rot('c_head.x', (1, 0, 0), 11)
for s, k in (('l', 1), ('r', -1)):
    rig.pose.bones[f'c_hand_ik.{s}']['ik_fk_switch'] = 1.0
    move(f'c_foot_ik.{s}', (0.03 * k, 0, 0)); rot(f'c_foot_ik.{s}', (0, 0, 1), 8 * k)
    aim(f'c_arm_fk.{s}', (0.30 * k, 0.04, -1)); aim(f'c_forearm_fk.{s}', (0.20 * k, -0.22, -1)); aim(f'c_hand_fk.{s}', (0.14 * k, -0.16, -1))
    rig.pose.bones[f'c_hand_fk.{s}']['fingers_grasp'] = 0.6
vl.update()

# ------------------------------------------------------------------ studio (Cycles CPU)
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
sc.cycles.samples = int(opt('--samples', 160)); sc.cycles.use_denoising = opt('--denoise', '1') == '1'
sc.cycles.denoiser = 'OPENIMAGEDENOISE'
sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Punchy'; sc.view_settings.exposure = -0.2
w = bpy.data.worlds.new('Studio'); sc.world = w; w.use_nodes = True
wn, wl = w.node_tree.nodes, w.node_tree.links
wn['Background'].inputs['Color'].default_value = lin('#D4DADF'); wn['Background'].inputs['Strength'].default_value = 0.12
cam_bg = wn.new('ShaderNodeBackground'); cam_bg.inputs['Color'].default_value = lin('#C9CED3')
lp = wn.new('ShaderNodeLightPath'); mx = wn.new('ShaderNodeMixShader')
wl.new(lp.outputs['Is Camera Ray'], mx.inputs[0]); wl.new(wn['Background'].outputs[0], mx.inputs[1]); wl.new(cam_bg.outputs[0], mx.inputs[2])
wl.new(mx.outputs[0], wn['World Output'].inputs['Surface'])
fm, Nn, L, b = nodes_mat('Floor'); b.inputs['Base Color'].default_value = lin('#8E959C'); b.inputs['Roughness'].default_value = 0.85
geo = Nn.new('ShaderNodeNewGeometry'); ln = Nn.new('ShaderNodeVectorMath'); ln.operation = 'LENGTH'
mr = Nn.new('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = 1.6; mr.inputs['From Max'].default_value = 5.0
em = Nn.new('ShaderNodeEmission'); em.inputs['Color'].default_value = lin('#C9CED3'); mxs = Nn.new('ShaderNodeMixShader')
L.new(geo.outputs['Position'], ln.inputs[0]); L.new(ln.outputs['Value'], mr.inputs['Value']); L.new(mr.outputs['Result'], mxs.inputs[0])
L.new(b.outputs[0], mxs.inputs[1]); L.new(em.outputs[0], mxs.inputs[2]); L.new(mxs.outputs[0], Nn['Material Output'].inputs['Surface'])
bpy.ops.mesh.primitive_plane_add(size=40); floor = bpy.context.object; floor.data.materials.append(fm)
def light(name, loc, energy, size, color, target=V((0, 0, 1.1))):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.color = lin(color)[:3]; d.shape = 'DISK'; d.size = size
    o = bpy.data.objects.new(name, d); C.objects.link(o); o.location = loc
    o.rotation_euler = (target - V(loc)).to_track_quat('-Z', 'Y').to_euler()
light('Key', (-2.4, -2.9, 3.3), 600, 2.4, '#FFF4E8')
light('Fill', (3.0, -2.2, 1.6), 160, 3.0, '#E6EEFA')
light('Rim L', (-2.3, 2.5, 2.6), 900, 1.4, '#FFF2E2')
light('Rim R', (2.5, 2.3, 2.2), 800, 1.4, '#E8F0FF')
light('Top', (0, 0.3, 4.2), 90, 2.5, '#FFFFFF', target=V((0, 0, 0)))
cd = bpy.data.cameras.new('cam'); cam = bpy.data.objects.new('cam', cd); C.objects.link(cam); sc.camera = cam; cd.lens = 55
OUT = opt('--out'); os.makedirs(OUT, exist_ok=True)
res = int(opt('--res', 1080)); sc.render.resolution_x = sc.render.resolution_y = res
if opt('--save'): bpy.ops.wm.save_as_mainfile(filepath=opt('--save'), compress=True)
for view in [v for v in opt('--views', '3q').split(',') if v]:
    az, tgt, dist, lens, elev = dict(front=(0, (0, 0, 1.04), 4.25, 55, 0.12), side=(-90, (0, 0, 1.04), 4.25, 55, 0.12),
                                     q=(-35, (0, 0, 1.04), 4.25, 55, 0.12), face=(-30, (0, -0.02, 1.86), 1.4, 85, 0.02),
                                     back=(160, (0, 0, 1.04), 4.25, 55, 0.12))['q' if view == '3q' else view]
    a = math.radians(az); t = V(tgt); cd.lens = lens
    cam.location = t + V((math.sin(a) * dist, -math.cos(a) * dist, elev))
    cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(OUT, f'athlete_{view}.png'); bpy.ops.render.render(write_still=True)
    print('RENDERED', sc.render.filepath)
print('DONE')
