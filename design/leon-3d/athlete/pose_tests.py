"""Pose tests on the BlendKit 'Muscular Male Base Mesh' ARP rig, without the Auto-Rig Pro add-on.
blender -b --factory-startup --disable-autoexec <asset.blend> --python pose_tests.py -- --out DIR [--res 900] [--tests rest,squat,overhead,grip]
"""
import bpy, sys, math, os
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
def opt(k, d=None): return argv[argv.index(k) + 1] if k in argv else d
OUT = opt('--out'); RES = int(opt('--res', 900)); TESTS = opt('--tests', 'rest,squat,overhead,grip').split(',')
os.makedirs(OUT, exist_ok=True)

sc = bpy.context.scene
rig = bpy.data.objects['rig.002']
vl = bpy.context.view_layer
for o in bpy.data.objects:
    if o.name.startswith('cs_') or o.name.startswith(('teeth', 'Tongue', 'Gum')): o.hide_render = True

# ---- clay material only (the 4K textures are never loaded) ----
clay = bpy.data.materials.new('clay'); clay.use_nodes = True
bsdf = clay.node_tree.nodes['Principled BSDF']
bsdf.inputs['Base Color'].default_value = (0.42, 0.42, 0.43, 1); bsdf.inputs['Roughness'].default_value = 0.55
for o in bpy.data.objects:
    if o.type == 'MESH' and not o.name.startswith('cs_'):
        for i in range(len(o.data.materials)): o.data.materials[i] = clay
for img in list(bpy.data.images): bpy.data.images.remove(img)

# ---- studio ----
sc.render.engine = opt('--engine', 'BLENDER_EEVEE_NEXT')
if sc.render.engine == 'CYCLES':
    sc.cycles.device = 'CPU'; sc.cycles.samples = int(opt('--samples', 48)); sc.cycles.use_denoising = opt('--denoise', '0') == '1'
    sc.render.threads_mode = 'FIXED'; sc.render.threads = 4
sc.render.resolution_x = sc.render.resolution_y = RES
sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Base Contrast'
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs[0].default_value = (0.58, 0.60, 0.63, 1); w.node_tree.nodes['Background'].inputs[1].default_value = 0.35
bpy.ops.mesh.primitive_plane_add(size=20); floor = bpy.context.object
fm = bpy.data.materials.new('floor'); fm.use_nodes = True; fm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.5, 0.52, 0.55, 1)
floor.data.materials.append(fm)
def light(name, loc, power, size):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = power; d.size = size
    o = bpy.data.objects.new(name, d); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (Vector((0, 0, 1.0)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
light('key', (-2.5, -3.0, 3.5), 350, 2.5); light('fill', (3.0, -2.5, 2.0), 110, 3); light('rim', (1.5, 3.5, 3.0), 250, 2)
w.node_tree.nodes['Background'].inputs[1].default_value = 0.15
cam_d = bpy.data.cameras.new('cam'); cam = bpy.data.objects.new('cam', cam_d); sc.collection.objects.link(cam); sc.camera = cam

def shoot(name, target, yaw_deg, dist, lens=50, elev=0.0):
    t = Vector(target); a = math.radians(yaw_deg)
    cam.location = t + Vector((math.sin(a) * dist, -math.cos(a) * dist, elev))
    cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler(); cam_d.lens = lens
    sc.render.filepath = os.path.join(OUT, name + '.png'); bpy.ops.render.render(write_still=True)
    print('RENDERED', sc.render.filepath)

# ---- posing helpers (world-space, pivot at bone head) ----
defaults = {(pb.name, k): pb[k] for pb in rig.pose.bones for k in pb.keys() if isinstance(pb[k], float)}
def reset():
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)
    for (n, k), v in defaults.items(): rig.pose.bones[n][k] = v
    vl.update()
def W(n): vl.update(); return rig.matrix_world @ rig.pose.bones[n].matrix
def setW(n, M): rig.pose.bones[n].matrix = rig.matrix_world.inverted() @ M; vl.update()
def rot(n, axis, deg):
    M = W(n); h = M.translation.copy()
    setW(n, Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg), 4, Vector(axis)) @ Matrix.Translation(-h) @ M)
def move(n, d):
    M = W(n); M.translation += Vector(d); setW(n, M)
def aim(n, direction):
    M = W(n); cur = M.col[1].xyz.normalized(); q = cur.rotation_difference(Vector(direction).normalized())
    h = M.translation.copy(); setW(n, Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h) @ M)
def head(n): return W(n).translation.copy()
def fk_arms():
    for s in 'lr': rig.pose.bones[f'c_hand_ik.{s}']['ik_fk_switch'] = 1.0
    vl.update()
def arms(dir_l, fore_l=None, hand_l=None):
    fk_arms()
    for s, sx in (('l', 1), ('r', -1)):
        f = lambda v: (v[0] * sx, v[1], v[2])
        aim(f'c_arm_fk.{s}', f(dir_l)); aim(f'c_forearm_fk.{s}', f(fore_l or dir_l)); aim(f'c_hand_fk.{s}', f(hand_l or fore_l or dir_l))

for test in TESTS:
    reset()
    if test == 'rest':
        shoot('rest_3q', (0, 0, 1.0), -35, 4.6); shoot('rest_face', head('c_head.x') + Vector((0, 0, 0.1)), -25, 0.9, 85)
    elif test == 'squat':
        move('c_root_master.x', (0, 0.22, -0.40)); rot('c_root_master.x', (1, 0, 0), 30)
        rot('c_spine_01.x', (1, 0, 0), 6); rot('c_spine_03.x', (1, 0, 0), -6); rot('c_neck.x', (1, 0, 0), -18); rot('c_head.x', (1, 0, 0), -12)
        for s, sx in (('l', 1), ('r', -1)):
            move(f'c_foot_ik.{s}', (0.06 * sx, 0, 0)); rot(f'c_foot_ik.{s}', (0, 0, 1), 14 * sx)
            move(f'c_leg_pole.{s}', (0.16 * sx, 0, 0))
        arms((0.12, -1, 0.0))
        shoot('squat_3q', (0, 0, 0.75), -35, 4.4); shoot('squat_side', (0, 0, 0.75), -90, 4.4); shoot('squat_front', (0, 0, 0.75), 0, 4.4)
        shoot('squat_knees_hips_close', ((head('c_leg_fk.l') + head('c_thigh_fk.l')) / 2), -55, 1.6, 50, 0.25)
    elif test == 'overhead':
        arms((0.22, 0.02, 1), (0.12, 0.02, 1), (0.1, 0.0, 1))
        shoot('overhead_front', (0, 0, 1.15), 0, 5.0); shoot('overhead_side', (0, 0, 1.15), -90, 5.0); shoot('overhead_3q', (0, 0, 1.15), -35, 5.0)
        shoot('overhead_shoulder_close', head('c_arm_fk.l') + Vector((0.05, 0, 0.05)), -40, 1.3, 50, 0.1)
    elif test == 'grip':
        arms((0.25, -0.35, -1), (0.15, -1, -0.15), (0.12, -1, -0.15))
        for s in 'lr': rig.pose.bones[f'c_hand_fk.{s}']['fingers_grasp'] = 1.0
        vl.update()
        hl = head('c_hand_fk.l')
        shoot('grip_3q', (0, 0, 1.0), -35, 4.6)
        shoot('grip_hand_back', hl + Vector((0.0, -0.06, -0.02)), 60, 0.55, 85, 0.25)
        shoot('grip_hand_palm', hl + Vector((0.0, -0.06, -0.02)), -60, 0.55, 85, -0.1)
        shoot('grip_hand_front', hl + Vector((0.0, -0.06, -0.02)), 0, 0.55, 85, 0.1)
        print('thumb1.l rot vs rest (deg):', round(math.degrees(rig.pose.bones['c_thumb1.l'].matrix_basis.to_quaternion().angle), 1),
              'index1.l:', round(math.degrees(rig.pose.bones['index1.l'].matrix.to_quaternion().rotation_difference(rig.data.bones['index1.l'].matrix_local.to_quaternion()).angle), 1),
              'thumb1.l(def):', round(math.degrees(rig.pose.bones['thumb1.l'].matrix.to_quaternion().rotation_difference(rig.data.bones['thumb1.l'].matrix_local.to_quaternion()).angle), 1))
    elif test == 'rest2':
        shoot('rest_side', (0, 0, 1.0), -90, 4.6); shoot('rest_back', (0, 0, 1.0), 160, 4.6)
    elif test == 'squat2':
        move('c_root_master.x', (0, 0.22, -0.40)); rot('c_root_master.x', (1, 0, 0), 30)
        rot('c_spine_01.x', (1, 0, 0), 6); rot('c_spine_03.x', (1, 0, 0), -6); rot('c_neck.x', (1, 0, 0), -18); rot('c_head.x', (1, 0, 0), -12)
        for s, sx in (('l', 1), ('r', -1)):
            move(f'c_foot_ik.{s}', (0.06 * sx, 0, 0)); rot(f'c_foot_ik.{s}', (0, 0, 1), 14 * sx); move(f'c_leg_pole.{s}', (0.16 * sx, 0, 0))
        arms((0.12, -1, 0.0))
        k = head('c_leg_fk.l')
        shoot('squat_knee_outer', k + Vector((0.05, 0.08, -0.05)), -100, 1.1, 50, 0.1)
        shoot('squat_knee_back', k + Vector((0.0, 0.12, -0.05)), 150, 1.1, 50, 0.2)
        shoot('squat_hips_front', head('c_root_master.x') + Vector((0, -0.05, -0.05)), 0, 1.4, 50, 0.1)
    elif test == 'overhead2':
        arms((0.22, 0.02, 1), (0.12, 0.02, 1), (0.1, 0.0, 1))
        sh = head('c_arm_fk.l')
        shoot('overhead_shoulders_front', Vector((0, sh.y, sh.z)), 0, 1.6, 50, 0.05)
        shoot('overhead_shoulders_back', Vector((0, sh.y, sh.z)), 180, 1.6, 50, 0.05)
        shoot('overhead_armpit', sh + Vector((0.0, 0, -0.08)), -70, 0.9, 50, -0.15)
    elif test == 'grip2':
        arms((0.25, -0.35, -1), (0.15, -1, -0.15), (0.12, -1, -0.15))
        for s in 'lr': rig.pose.bones[f'c_hand_fk.{s}']['fingers_grasp'] = 1.0
        vl.update()
        hc = (head('c_hand_fk.l') + head('c_middle2.l')) / 2
        shoot('grip_front', hc, 0, 0.55, 50, 0.05); shoot('grip_outer', hc, -90, 0.55, 50, 0.05)
        shoot('grip_inner', hc, 90, 0.55, 50, -0.1); shoot('grip_top', hc, -20, 0.35, 50, 0.4)
        print('thumb drivers:', [d.data_path for d in rig.animation_data.drivers if 'thumb' in d.data_path and '.l' in d.data_path])
        for n in ('c_thumb1.l', 'c_thumb2.l', 'c_thumb3.l', 'c_index2.l', 'c_index3.l'):
            print(n, 'basis rot deg', round(math.degrees(rig.pose.bones[n].matrix_basis.to_quaternion().angle), 1))
print('DONE')
