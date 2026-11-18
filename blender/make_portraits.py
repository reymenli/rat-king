# Renders the dialogue box headshots to assets/ui/portraits/ (rat_king.png, scientist.png).
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P blender/make_portraits.py
# The Rat King comes from rat-king-character.blend. The Scientist is a placeholder bust built
# here from primitives until the real scientist model exists (schedule week 5).
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "assets", "ui", "portraits")
SIZE = 256


def hexcol(h, a=1.0):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return (*[x ** 2.2 for x in c], a)  # sRGB to linear


def setup_render(color_type):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = color_type
    sc.display.shading.show_cavity = True
    sc.display.shading.show_object_outline = True
    sc.display.shading.object_outline_color = (0.02, 0.02, 0.03)
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = SIZE
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"


def shoot(name, look_at, from_dir, ortho):
    sc = bpy.context.scene
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


# ------------------------------------------------------------------ Rat King
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "rat-king-character.blend"))
setup_render("VERTEX")
bpy.context.scene.frame_set(1)
# Front is -Y. A three quarter view from his right, a little above the eyes.
shoot("rat_king.png", (0.0, -0.1, 1.47), (-0.55, -1.0, 0.18), 0.95)

# ------------------------------------------------------------------ Scientist
bpy.ops.wm.read_factory_settings(use_empty=True)
setup_render("OBJECT")

SKIN, HAIR, COAT = hexcol("f1c7a5"), hexcol("e8e8ec"), hexcol("f4f6f8")
SHIRT, TIE, DARK, LENS = hexcol("8fb4d9"), hexcol("c0283a"), hexcol("1b1b22"), hexcol("cfe8ff")


def part(kind, loc, color, scale=(1, 1, 1), rot=(0, 0, 0), **kw):
    ops = {"ball": bpy.ops.mesh.primitive_uv_sphere_add, "box": bpy.ops.mesh.primitive_cube_add,
           "cone": bpy.ops.mesh.primitive_cone_add, "ring": bpy.ops.mesh.primitive_torus_add,
           "cyl": bpy.ops.mesh.primitive_cylinder_add}
    if kind == "ball":
        kw.setdefault("segments", 14)
        kw.setdefault("ring_count", 8)
    ops[kind](location=loc, rotation=[math.radians(a) for a in rot], **kw)
    ob = bpy.context.active_object
    ob.scale = scale
    ob.color = color
    for poly in ob.data.polygons:
        poly.use_smooth = False  # flat shaded like the rest of the game
    return ob


# coat, shirt and tie
part("box", (0, 0, 1.0), COAT, scale=(0.46, 0.24, 0.3), size=2)
part("cone", (0, -0.23, 1.2), SHIRT, rot=(90, 0, 180), radius1=0.13, radius2=0.0, depth=0.02, vertices=3)
part("box", (0, -0.25, 1.1), TIE, scale=(0.035, 0.01, 0.11), size=2)
part("box", (-0.12, -0.25, 1.12), COAT, scale=(0.08, 0.02, 0.18), rot=(0, -18, 0), size=2)  # lapels
part("box", (0.12, -0.25, 1.12), COAT, scale=(0.08, 0.02, 0.18), rot=(0, 18, 0), size=2)
# neck and head
part("cyl", (0, 0, 1.33), SKIN, radius=0.08, depth=0.16, vertices=10)
part("ball", (0, 0, 1.55), SKIN, scale=(0.9, 0.95, 1.1), radius=0.2)
part("cone", (0, -0.2, 1.52), SKIN, rot=(90, 0, 0), radius1=0.035, radius2=0.01, depth=0.08, vertices=6)  # nose
part("ball", (0.2 * 0.9, 0, 1.53), SKIN, radius=0.04)  # ears
part("ball", (-0.2 * 0.9, 0, 1.53), SKIN, radius=0.04)
# wild white hair around the sides and back, bald on top
for i in range(11):
    a = math.radians(-20 + i * 22)
    x, y = 0.19 * math.cos(a), 0.17 * math.sin(a) + 0.03
    part("cone", (x, y, 1.64 + 0.03 * (i % 2)), HAIR, rot=(70 * math.sin(a), -70 * math.cos(a), 0),
         radius1=0.07, radius2=0.0, depth=0.2, vertices=5)
# round glasses with a manic stare
for x in (-0.075, 0.075):
    part("ring", (x, -0.175, 1.58), DARK, rot=(90, 0, 0), major_radius=0.055, minor_radius=0.01,
         major_segments=14, minor_segments=4)
    part("cyl", (x, -0.17, 1.58), LENS, rot=(90, 0, 0), radius=0.05, depth=0.005, vertices=14)
    part("ball", (x * 0.9, -0.175, 1.58), DARK, radius=0.018)
part("box", (0, -0.18, 1.585), DARK, scale=(0.025, 0.005, 0.006), size=2)
for x, tilt in ((-0.08, 12), (0.08, -12)):  # eyebrows, raised high
    part("box", (x, -0.17, 1.66), HAIR, scale=(0.05, 0.01, 0.012), rot=(0, tilt, 0), size=2)
part("box", (0, -0.17, 1.45), DARK, scale=(0.07, 0.01, 0.01), rot=(0, 0, 0), size=2)  # thin grin

shoot("scientist.png", (0.0, -0.05, 1.5), (0.55, -1.0, 0.15), 0.95)
print("PORTRAITS DONE")
