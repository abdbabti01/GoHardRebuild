"""Rig check on the built mannequin: squat (IK feet planted), arms overhead, closed fists.
    blender -b <mannequin.blend> --python rig_test.py -- --out DIR [--res 480]
Prints foot sliding, knee bend and fingertip travel; renders a small sheet of the three poses."""
import bpy, sys, os, math, importlib.util
import numpy as np
from mathutils import Vector as V
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('mq', os.path.join(HERE, 'build_mannequin.py'))
mq = importlib.util.module_from_spec(spec); spec.loader.exec_module(mq)
ARGV = sys.argv[sys.argv.index('--') + 1:]; OUT = ARGV[ARGV.index('--out') + 1]
RES = int(ARGV[ARGV.index('--res') + 1]) if '--res' in ARGV else 480
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene; rig = bpy.data.objects['Mannequin rig']; vl = bpy.context.view_layer
W_, rot, move, aim, local_x = mq.pose_api(rig)
sc.cycles.samples = 32; sc.cycles.use_denoising = False; sc.render.resolution_x = sc.render.resolution_y = RES
cam = sc.camera; cd = cam.data

def reset():
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)
    vl.update()
def shot(name, target, az, dist, lens=55, elev=0.1):
    t = V(target); a = math.radians(az); cd.lens = lens
    cam.location = t + V((math.sin(a) * dist, -math.cos(a) * dist, elev))
    cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(OUT, name + '.png'); bpy.ops.render.render(write_still=True)
def wpos(n): return W_(n).translation.copy()

# ---- squat: torso down and back, chest forward; feet stay on their IK controls
reset()
feet0 = {s: W_(f'DEF-foot.{s}').copy() for s in 'LR'}
move('torso', (0, 0.16, -0.36)); rot('torso', (1, 0, 0), 22); rot('chest', (1, 0, 0), 8)
for s, k in (('L', 1), ('R', -1)):
    move(f'foot_ik.{s}', (0.05 * k, 0, 0)); rot(f'foot_ik.{s}', (0, 0, 1), 12 * k)
    move(f'thigh_ik_target.{s}', (0.12 * k, 0, 0))
    rig.pose.bones[f'upper_arm_parent.{s}']['IK_FK'] = 1.0
    aim(f'upper_arm_fk.{s}', (0.12 * k, -1, 0.05)); aim(f'forearm_fk.{s}', (0.10 * k, -1, 0.05)); aim(f'hand_fk.{s}', (0.10 * k, -1, 0.0))
vl.update()
for s in 'LR':
    f1 = W_(f'DEF-foot.{s}')
    print(f'squat foot {s}: ball moved {(f1.translation - feet0[s].translation).length * 1000:.1f} mm (expected: only the 5 cm stance widening)')
hip = wpos('DEF-thigh.L'); knee = wpos('DEF-shin.L'); ank = wpos('DEF-foot.L')
a = math.degrees((hip - knee).angle(ank - knee)); print(f'squat knee angle {a:.0f} deg, hip height {hip.z:.2f} m, knee height {knee.z:.2f} m')
shot('squat_3q', (0, 0.05, 0.62), -35, 3.6); shot('squat_side', (0, 0.05, 0.62), -90, 3.6)
# ---- overhead
reset()
for s, k in (('L', 1), ('R', -1)):
    rig.pose.bones[f'upper_arm_parent.{s}']['IK_FK'] = 1.0
    aim(f'upper_arm_fk.{s}', (0.22 * k, 0.03, 1)); aim(f'forearm_fk.{s}', (0.12 * k, 0.03, 1)); aim(f'hand_fk.{s}', (0.1 * k, 0.0, 1))
vl.update()
shot('overhead_front', (0, 0, 1.05), 0, 4.2); shot('overhead_shoulders', (0, 0, 1.40), -30, 1.6)
# ---- fists
reset()
for s, k in (('L', 1), ('R', -1)):
    rig.pose.bones[f'upper_arm_parent.{s}']['IK_FK'] = 1.0
    aim(f'upper_arm_fk.{s}', (0.2 * k, -0.2, -1)); aim(f'forearm_fk.{s}', (0.15 * k, -1, -0.3)); aim(f'hand_fk.{s}', (0.12 * k, -1, -0.3))
dorsal = W_('DEF-hand.L').col[2].xyz.normalized()
tip0 = wpos('DEF-f_index.03.L') + W_('DEF-f_index.03.L').col[1].xyz * rig.pose.bones['DEF-f_index.03.L'].length
local_x('f_index.01.L', 20)
tip1 = wpos('DEF-f_index.03.L') + W_('DEF-f_index.03.L').col[1].xyz * rig.pose.bones['DEF-f_index.03.L'].length
sign = 1 if (tip1 - tip0).dot(dorsal) < 0 else -1          # curl toward the palm
local_x('f_index.01.L', -20)
for s in 'LR':
    for f in ('index', 'middle', 'ring', 'pinky'):
        for j, d in ((1, 80), (2, 95), (3, 60)): local_x(f'f_{f}.0{j}.{s}', sign * d)
    for j, d in ((2, 45), (3, 55)): local_x(f'thumb.0{j}.{s}', sign * d)
    local_x(f'thumb.01.{s}', sign * 20)
vl.update()
tip2 = wpos('DEF-f_index.03.L') + W_('DEF-f_index.03.L').col[1].xyz * rig.pose.bones['DEF-f_index.03.L'].length
print(f'fist: index tip moved {(tip2 - tip0).length * 1000:.0f} mm toward the palm side ({(tip2 - tip0).dot(-dorsal) * 1000:.0f} mm palmar)')
print('finger controls:', sorted(n for n in rig.pose.bones.keys() if n.startswith(('f_', 'thumb')) and n.endswith('.L')))
hl = (wpos('DEF-hand.L') + wpos('DEF-f_middle.01.L')) / 2
shot('fist_front', hl, -20, 0.6, 55, 0.05); shot('fist_side', hl, -100, 0.6, 55, 0.1)
print('DONE')
