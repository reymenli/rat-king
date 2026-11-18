# Renders the dialogue box headshots to assets/ui/portraits/ (rat_king.png, scientist.png).
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P blender/make_portraits.py
# Run make_rat_king.py and make_scientist.py first: this renders their saved .blend files.
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "assets", "ui", "portraits")
SIZE = 256

# (blend file, output, point to frame, direction the camera looks from, frame size in metres)
SHOTS = [
    ("rat-king-character.blend", "rat_king.png", (0.0, -0.18, 1.33), (-0.5, -1.0, 0.4), 0.85),
    ("scientist-character.blend", "scientist.png", (0.0, -0.22, 1.55), (0.5, -1.0, 0.1), 0.95),
]

for blend, name, look_at, from_dir, ortho in SHOTS:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, blend))
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "VERTEX"
    sc.display.shading.show_object_outline = True
    sc.display.shading.object_outline_color = (0.02, 0.02, 0.03)
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = SIZE
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.frame_set(1)
    cam = bpy.data.objects.new("PortraitCam", bpy.data.cameras.new("PortraitCam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    target = Vector(look_at)
    cam.location = target + Vector(from_dir).normalized() * 5.0
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    os.makedirs(OUT, exist_ok=True)
    sc.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
print("PORTRAITS DONE")
