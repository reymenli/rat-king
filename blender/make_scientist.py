# Builds the Scientist: a static low-poly character (no rig yet). He stands guard in the
# final zone and is rendered for the dialogue headshot.
#
#   blender -b -P blender/make_scientist.py
#
# Writes blender/scientist-character.blend and assets/models/characters/scientist/SK_Scientist.glb.
#
# Design (docs/PROGRESS.md, "Character direction"): a regular, human-looking scientist.
# White lab coat, blue shirt and red tie, glasses, white hair round the sides and back with a
# receding hairline and a bald top. Normal head size. Each body part is fused on its own
# (blender/fused_mesh.py), so arms and legs never melt into the coat.

import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from fused_mesh import box, colour, disc, fused_part, hard_piece, join, stick  # noqa: E402

OUT_BLEND = os.path.join(HERE, "scientist-character.blend")
OUT_GLB = os.path.join(HERE, "..", "assets", "models", "characters", "scientist", "SK_Scientist.glb")

SKIN = colour("e8c4a8")
SKIN_DARK = colour("cfa688")
HAIR = colour("ececea")
COAT = colour("f2f4f6")
SHIRT = colour("a8c0dc")
TIE = colour("c0202c")
PANTS = colour("3a3d48")
SHOE = colour("1c1c20")
FRAME = colour("26262c")
LENS = colour("dff0ff")
EYE = colour("f8f8f4")
PUPIL = colour("1a1a20")
MOUTH = colour("6e3a36")

HEAD_Z = 1.66

PARTS = {
    # head and neck: a normal head, long nose, a bit of a jaw
    "Head": [
        ("ball", (0, -0.01, HEAD_Z), (0.115, 0.125, 0.14), SKIN, (0, 0, 0)),
        ("ball", (0, -0.05, HEAD_Z - 0.08), (0.095, 0.095, 0.075), SKIN, (0, 0, 0)),
        ("limb", (0, -0.12, HEAD_Z + 0.01), 0.024, (0, -0.16, HEAD_Z - 0.035), 0.018, SKIN_DARK),
        ("ball", (0.118, 0.0, HEAD_Z - 0.01), (0.02, 0.035, 0.045), SKIN_DARK, (0, 0, 0)),
        ("ball", (-0.118, 0.0, HEAD_Z - 0.01), (0.02, 0.035, 0.045), SKIN_DARK, (0, 0, 0)),
        ("limb", (0, 0.0, 1.46), 0.05, (0, -0.02, HEAD_Z - 0.09), 0.05, SKIN),
    ],
    # hair: round the sides and the back only, the top and forehead are bald
    "Hair": [
        ("ball", (0, 0.07, HEAD_Z + 0.0), (0.11, 0.07, 0.085), HAIR, (0, 0, 0)),
        ("ball", (0.105, -0.01, HEAD_Z + 0.03), (0.035, 0.08, 0.06), HAIR, (0, 0, 0)),
        ("ball", (-0.105, -0.01, HEAD_Z + 0.03), (0.035, 0.08, 0.06), HAIR, (0, 0, 0)),
        ("limb", (0.11, 0.0, HEAD_Z + 0.06), 0.03, (0.17, 0.03, HEAD_Z + 0.1), 0.008, HAIR),
        ("limb", (-0.11, 0.0, HEAD_Z + 0.06), 0.03, (-0.17, 0.02, HEAD_Z + 0.11), 0.008, HAIR),
        ("limb", (0.08, 0.08, HEAD_Z + 0.04), 0.03, (0.13, 0.15, HEAD_Z + 0.09), 0.008, HAIR),
        ("limb", (-0.07, 0.09, HEAD_Z + 0.03), 0.03, (-0.12, 0.16, HEAD_Z + 0.07), 0.008, HAIR),
    ],
    # lab coat over a shirt and tie, down to the knees, flat hem
    "Torso": [
        ("ball", (0, 0.0, 1.38), (0.25, 0.14, 0.1), COAT, (0, 0, 0)),  # shoulders
        ("ball", (0, -0.01, 1.2), (0.2, 0.15, 0.2), COAT, (0, 0, 0)),  # chest
        ("cone", (0, 0.0, 1.25), 0.19, (0, 0.01, 0.62), 0.25, COAT),
        ("ball", (0, -0.13, 1.3), (0.075, 0.04, 0.12), SHIRT, (0, 0, 0)),  # shirt in the open collar
        ("limb", (0, -0.17, 1.37), 0.02, (0, -0.175, 1.12), 0.032, TIE),
    ],
}
for side, x in (("L", 1), ("R", -1)):
    PARTS["Arm" + side] = [
        ("limb", (0.21 * x, 0.0, 1.38), 0.055, (0.26 * x, -0.01, 1.1), 0.05, COAT),
        ("limb", (0.26 * x, -0.01, 1.1), 0.05, (0.27 * x, -0.06, 0.86), 0.045, COAT),
        ("ball", (0.272 * x, -0.07, 0.8), (0.04, 0.035, 0.06), SKIN, (0, 0, 0)),
    ]
    PARTS["Leg" + side] = [
        ("limb", (0.095 * x, 0.0, 0.85), 0.07, (0.1 * x, -0.01, 0.46), 0.055, PANTS),
        ("limb", (0.1 * x, -0.01, 0.46), 0.055, (0.1 * x, 0.01, 0.09), 0.045, PANTS),
        ("ball", (0.1 * x, -0.05, 0.045), (0.055, 0.13, 0.045), SHOE, (0, 0, 0)),
    ]
FACES = {"Head": 700, "Hair": 400, "Torso": 900}
HEAD_SCALE = 1.3  # a slightly big head reads better at game distance, still human
HEAD_PIVOT = Vector((0, 0, 1.47))  # the base of the neck


bpy.ops.wm.read_factory_settings(use_empty=True)
objects = [fused_part(name, shapes, FACES.get(name, 300), voxel=0.01, height=1.8) for name, shapes in PARTS.items()]
first_face_piece = len(objects)

# face: glasses with eyes behind them, white eyebrows, a thin smirk
eye_y = -0.125
for x in (0.048, -0.048):
    objects.append(hard_piece("Eye", lambda bm, x=x: disc(bm, (x, eye_y + 0.004, HEAD_Z + 0.025), 0.019, 0.01), EYE))
    objects.append(hard_piece("Pupil", lambda bm, x=x: disc(bm, (x - 0.003, eye_y - 0.004, HEAD_Z + 0.023), 0.009, 0.006), PUPIL))
    objects.append(hard_piece("Frame", lambda bm, x=x: disc(bm, (x, eye_y - 0.012, HEAD_Z + 0.025), 0.036, 0.008), FRAME))
    objects.append(hard_piece("Lens", lambda bm, x=x: disc(bm, (x, eye_y - 0.018, HEAD_Z + 0.025), 0.03, 0.006), LENS))
    objects.append(hard_piece("Brow", lambda bm, x=x: box(bm, (x, eye_y - 0.005, HEAD_Z + 0.072), (0.045, 0.012, 0.012), (0, 10 if x > 0 else -10, 0)), HAIR))
objects.append(hard_piece("Bridge", lambda bm: box(bm, (0, eye_y - 0.02, HEAD_Z + 0.03), (0.025, 0.008, 0.007)), FRAME))
for x in (0.084, -0.084):  # temple arms of the glasses, back to the ears
    objects.append(hard_piece("Temple", lambda bm, x=x: stick(bm, (x, eye_y - 0.01, HEAD_Z + 0.03), (x * 1.38, -0.005, HEAD_Z + 0.02), 0.004), FRAME))
objects.append(hard_piece("Mouth", lambda bm: box(bm, (0.008, -0.135, HEAD_Z - 0.085), (0.06, 0.01, 0.009), (0, -7, 0)), MOUTH))

grow = Matrix.Translation(HEAD_PIVOT) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-HEAD_PIVOT)
for ob in objects[:2] + objects[first_face_piece:]:  # head, hair and the face pieces
    ob.data.transform(grow)
body = join(objects, "SK_Scientist")
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_yup=True,
                          export_vertex_color="ACTIVE", export_materials="EXPORT")
print("scientist: %d verts, %d faces -> %s" % (len(body.data.vertices), len(body.data.polygons), os.path.normpath(OUT_GLB)))
