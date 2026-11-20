"""Renders the Leon squat prototype from leon_squat_prototype.blend.

    blender -b leon_squat_prototype.blend --python render_leon.py -- --stills OUTDIR [--res 720] [--samples 32]
    blender -b leon_squat_prototype.blend --python render_leon.py -- --anim OUTDIR --cam "Cam 3q" [--res 720] [--samples 24]

Stills: front, side and three-quarter at the start pose, plus three-quarter and side at the middle of the first
descent and at the first bottom. Animation: a PNG sequence of frames 1..366 (the 12.2 s loop) for ffmpeg.
"""
import bpy, sys, os

ARGV = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
def opt(name, default=None):
    return ARGV[ARGV.index(name) + 1] if name in ARGV else default

sc = bpy.context.scene
res = int(opt('--res', 720))
sc.render.resolution_x = sc.render.resolution_y = res
sc.render.resolution_percentage = 100
sc.eevee.taa_render_samples = int(opt('--samples', 32))
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGB'

if opt('--stills'):
    out = opt('--stills'); os.makedirs(out, exist_ok=True)
    shots = [('front', 'Cam front', 1), ('side', 'Cam side', 1), ('3q', 'Cam 3q', 1), ('face', 'Cam face', 1),
             ('3q-mid', 'Cam 3q', 52), ('side-mid', 'Cam side', 52), ('3q-bottom', 'Cam 3q', 79), ('side-bottom', 'Cam side', 79), ('front-bottom', 'Cam front', 79)]
    only = opt('--only')
    for name, cam, frame in shots:
        if only and name not in only.split(','): continue
        sc.camera = bpy.data.objects[cam]
        sc.frame_set(frame)
        sc.render.filepath = os.path.join(out, name + '.png')
        bpy.ops.render.render(write_still=True)
        print('STILL', name)
elif opt('--anim'):
    out = opt('--anim'); os.makedirs(out, exist_ok=True)
    sc.camera = bpy.data.objects[opt('--cam', 'Cam 3q')]
    sc.frame_start, sc.frame_end = int(opt('--start', 1)), int(opt('--end', sc.frame_end))
    sc.frame_step = int(opt('--step', 1))
    sc.render.filepath = os.path.join(out, 'f_')
    bpy.ops.render.render(animation=True)
    print('ANIM done')
