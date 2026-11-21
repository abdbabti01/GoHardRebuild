"""Bodyweight-squat pilot on the approved mannequin (appearance unchanged). Technique review: PENDING.

    blender -b --disable-autoexec mannequin_face.blend --python animate_squat.py -- --out DIR
        [--check 1] [--render 3q|side] [--res 720] [--samples 48] [--frames A-B] [--save squat.blend]

Three controlled repetitions at 30 fps (11 s, 330 frames; frame 331 = frame 1, so the clip loops):
0.5 s stand, then per rep 1.5 s down, 0.3 s hold, 1.2 s up, 0.5 s stand. Feet are IK controls that never move, so they
cannot slide; the torso control lowers and hinges, the knees follow through IK, the arms reach forward for balance.
"""
import bpy, sys, os, math, importlib.util
import numpy as np
from mathutils import Vector as V, Matrix
from mathutils.bvhtree import BVHTree
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('mq', os.path.join(HERE, 'build_mannequin.py'))
mq = importlib.util.module_from_spec(spec); spec.loader.exec_module(mq)
ARGV = sys.argv[sys.argv.index('--') + 1:]
def opt(k, d=None): return ARGV[ARGV.index(k) + 1] if k in ARGV else d

sc = bpy.context.scene; vl = bpy.context.view_layer; rig = bpy.data.objects['Mannequin rig']
W_, rot, move, aim, local_x = mq.pose_api(rig)
FPS, N = 30, 330
sc.render.fps = FPS; sc.frame_start, sc.frame_end = 1, N

# ---------------------------------------------------------------- poses (computed in world space, keyed in local space)
STAND_ARMS = {'L': ((0.24, 0.03, -1), (0.17, -0.07, -1), (0.13, -0.07, -1))}
BOTTOM_ARMS = {'L': ((0.12, -1, 0.02), (0.10, -1, 0.03), (0.10, -1, 0.0))}
KEYED = ['torso', 'chest', 'neck'] + [f'{b}_fk.{s}' for b in ('upper_arm', 'forearm', 'hand') for s in 'LR']

def set_stance():   # fixed for the whole clip: feet a little wider, toes out, knees tracking over the toes
    for s, k in (('L', 1), ('R', -1)):
        move(f'foot_ik.{s}', (0.035 * k, 0, 0)); rot(f'foot_ik.{s}', (0, 0, 1), 12 * k)
        move(f'thigh_ik_target.{s}', (0.12 * k, 0, 0))
        rig.pose.bones[f'upper_arm_parent.{s}']['IK_FK'] = 1.0

def arms(spec):
    a, f, h = spec['L']
    for s, k in (('L', 1), ('R', -1)):
        m = lambda v: (v[0] * k, v[1], v[2])
        aim(f'upper_arm_fk.{s}', m(a)); aim(f'forearm_fk.{s}', m(f)); aim(f'hand_fk.{s}', m(h))

def snapshot():
    vl.update(); return {n: rig.pose.bones[n].matrix_basis.copy() for n in KEYED}

def clear_keyed():
    for n in KEYED:
        pb = rig.pose.bones[n]; pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0)
    vl.update()

set_stance()
for n in KEYED: rig.pose.bones[n].rotation_mode = 'QUATERNION'
clear_keyed(); arms(STAND_ARMS); STAND = snapshot()
clear_keyed()
move('torso', (0, 0.22, -0.36)); rot('torso', (1, 0, 0), 24); rot('chest', (1, 0, 0), 4); rot('neck', (1, 0, 0), -12)
arms(BOTTOM_ARMS); BOTTOM = snapshot()

def key(frame, pose):
    for n, M in pose.items():
        pb = rig.pose.bones[n]; loc, q, _ = M.decompose()
        pb.location = loc; pb.rotation_quaternion = q
        pb.keyframe_insert('location', frame=frame); pb.keyframe_insert('rotation_quaternion', frame=frame)
rig.animation_data_clear()
key(1, STAND); key(15, STAND)
for r in range(3):
    s = 16 + 105 * r
    key(s, STAND); key(s + 45, BOTTOM); key(s + 54, BOTTOM); key(s + 90, STAND); key(s + 104, STAND)
key(N, STAND)
for fc in rig.animation_data.action.fcurves:
    for kp in fc.keyframe_points: kp.interpolation = 'BEZIER'; kp.easing = 'AUTO'; kp.handle_left_type = kp.handle_right_type = 'AUTO_CLAMPED'
print('keyframes: 3 reps, frames 1-%d at %d fps (%.1f s)' % (N, FPS, N / FPS))

# ---------------------------------------------------------------- checks
def evaluated_world(ob):
    dg = bpy.context.evaluated_depsgraph_get(); e = ob.evaluated_get(dg); me = e.to_mesh()
    P = np.array([ob.matrix_world @ v.co for v in me.vertices]); F = [p.vertices[:] for p in me.polygons]; e.to_mesh_clear()
    return P, F

def checks():
    body, shorts, shoes = (bpy.data.objects[n] for n in ('Mannequin body', 'Shorts', 'Shoes'))
    soles = [bpy.data.objects['Sole.L'], bpy.data.objects['Sole.R']]
    rest = np.array([v.co for v in body.data.vertices])
    under_shorts = (rest[:, 2] > 0.59) & (rest[:, 2] < 1.0) & (np.abs(rest[:, 0]) < 0.26) & ~((np.abs(rest[:, 0]) > 0.28))
    under_shoes = (rest[:, 2] < 0.13)
    shorts.modifiers['Thickness'].show_viewport = False
    sc.frame_set(1); feet0 = {s: (W_(f'DEF-foot.{s}').translation.copy(), W_(f'DEF-toe.{s}').translation.copy()) for s in 'LR'}
    slide, heel_lift, poke_s, poke_f, knee_min, hip_min, com_out, com_track = 0, 0, 0, 0, 180, 9, 0, []
    heel = {so.name: np.array([v.co.y for v in so.data.vertices]) > 0.06 for so in soles}
    for f in range(1, N + 1, 3):
        sc.frame_set(f)
        for s in 'LR':
            a, b = W_(f'DEF-foot.{s}').translation, W_(f'DEF-toe.{s}').translation
            slide = max(slide, (a - feet0[s][0]).length, (b - feet0[s][1]).length)
        for so in soles:
            Z, _ = evaluated_world(so); heel_lift = max(heel_lift, Z[heel[so.name], 2].min())
        hip, knee, ank = (W_(n).translation for n in ('DEF-thigh.L', 'DEF-shin.L', 'DEF-foot.L'))
        knee_min = min(knee_min, math.degrees((hip - knee).angle(ank - knee))); hip_min = min(hip_min, hip.z)
        B, _ = evaluated_world(body)
        dg = bpy.context.evaluated_depsgraph_get(); e = body.evaluated_get(dg); me = e.to_mesh()
        C_ = np.empty(len(me.polygons) * 3); me.polygons.foreach_get('center', C_); A_ = np.empty(len(me.polygons))
        me.polygons.foreach_get('area', A_); e.to_mesh_clear()
        com = (C_.reshape(-1, 3) * A_[:, None]).sum(0) / A_.sum()     # rough centre of mass: area-weighted surface centroid
        toe_y = min(W_('DEF-toe.L').translation.y, W_('DEF-toe.R').translation.y) - 0.04
        heel_y = W_('DEF-foot.L').translation.y + 0.06
        if not (toe_y <= com[1] <= heel_y): com_out += 1
        com_track.append((f, round(float(com[1]), 3), round(float(toe_y), 3), round(float(heel_y), 3)))
        if f in (1, 61, 97, 121):    # standing, bottom of rep 1, rising, standing again
            for ob, mask, name in ((shorts, under_shorts, 's'), (shoes, under_shoes, 'f')):
                S, F = evaluated_world(ob); bvh = BVHTree.FromPolygons([V(p) for p in S], F); out = 0
                for p in B[mask]:
                    loc, nor, _, d = bvh.find_nearest(V(p))
                    if loc is not None and d < 0.05 and (V(p) - loc).dot(nor) > 0.002: out += 1
                if name == 's': poke_s = max(poke_s, out)
                else: poke_f = max(poke_f, out)
    shorts.modifiers['Thickness'].show_viewport = True
    sc.frame_set(1); a1 = {n: rig.pose.bones[n].matrix_basis.copy() for n in KEYED}
    sc.frame_set(N); aN = {n: rig.pose.bones[n].matrix_basis.copy() for n in KEYED}
    loop = max(max(abs(x - y) for ra, rb in zip(a1[n], aN[n]) for x, y in zip(ra, rb)) for n in KEYED)
    print(f'CHECK foot sliding (max over clip): {slide * 1000:.2f} mm')
    print(f'CHECK heel lift (lowest heel-sole point, max over clip): {heel_lift * 1000:.1f} mm above floor')
    print(f'CHECK depth: smallest knee angle {knee_min:.0f} deg, lowest hip joint {hip_min:.2f} m')
    print(f'CHECK balance: frames with rough centre of mass outside the feet: {com_out} of {len(range(1, N + 1, 3))}')
    print('CHECK balance track (frame, COM y, toe y, heel y):', [t for t in com_track if t[0] in (1, 31, 61, 91, 121)])
    print(f'CHECK clothing: body points through the shorts {poke_s}, through the shoes {poke_f} (worst sampled frame)')
    print(f'CHECK loop: frame 1 vs frame {N} pose difference {loop:.2e} (frame {N + 1} = frame 1)')

if opt('--check', '1') == '1': checks()
if opt('--save'): bpy.ops.wm.save_as_mainfile(filepath=opt('--save'), compress=True)

# ---------------------------------------------------------------- render
view = opt('--render')
if view:
    res = int(opt('--res', 720)); sc.render.resolution_x = sc.render.resolution_y = res
    sc.cycles.samples = int(opt('--samples', 48)); sc.cycles.use_denoising = True; sc.render.use_persistent_data = True
    cam = sc.camera; cam.data.lens = 55
    t = V((0, 0.0, 0.86)); a = math.radians(-35 if view == '3q' else -90)
    cam.location = t + V((math.sin(a) * 3.6, -math.cos(a) * 3.6, 0.10))
    cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
    a0, a1 = map(int, opt('--frames', f'1-{N}').split('-')); sc.frame_start, sc.frame_end = a0, a1
    sc.render.image_settings.file_format = 'PNG'
    sc.render.filepath = os.path.join(opt('--out'), view, 'f_')
    bpy.ops.render.render(animation=True)
print('DONE')
