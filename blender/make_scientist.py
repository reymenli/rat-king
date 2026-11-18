# Builds the Scientist: one fused low-poly mesh, posed, no rig yet (he is only seen in the
# dialogue headshot and, later, behind the glass in the final zone).
#
#   blender -b -P blender/make_scientist.py
#
# Writes blender/scientist-character.blend and assets/models/characters/scientist/SK_Scientist.glb.
#
# Design (docs/PROGRESS.md, "Character direction"): the mad scientist trope, in the spirit of
# Dr. Neo Cortex or the PvZ scientist. An enormous bald dome on a tiny hunched body, white
# hair spiking out at the temples, a long nose and pointed chin, thick round glasses, a manic
# grin, a lab coat that flares out like a triangle and rubber gloves rubbed together.
# Same build as the Rat King (blender/make_rat_king.py): SHAPES are fused with a voxel remesh,
# smoothed, reduced, and coloured from the nearest shape. Hard pieces are added after.

import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_BLEND = os.path.join(HERE, "scientist-character.blend")
OUT_GLB = os.path.join(HERE, "..", "assets", "models", "characters", "scientist", "SK_Scientist.glb")
VOXEL = 0.014
TARGET_FACES = 1600


def colour(hex_code):
    def linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(linear(int(hex_code[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)

SKIN = colour("e3d6a4")  # sickly, never sees the sun
SKIN_DARK = colour("b8a877")
HAIR = colour("f2f2f0")
COAT = colour("eef0f2")
COAT_STAIN = colour("9fc45a")  # something green spilled on him
SHIRT = colour("6b7f99")
TIE = colour("b5212e")
GLOVE = colour("3fa58c")
PANTS = colour("2c2c34")
SHOE = colour("151518")
LENS = colour("d9f2ff")
FRAME = colour("1a1a1f")
MOUTH = colour("3a1418")
TEETH = colour("f5f0d8")
PUPIL = colour("101014")

SHAPES = [
    # the dome: huge, bald, leaning forward over the body
    ("ball", (0, -0.16, 1.6), (0.31, 0.3, 0.34), SKIN, (18, 0, 0)),
    ("ball", (0, -0.28, 1.36), (0.15, 0.12, 0.13), SKIN, (0, 0, 0)),  # jaw
    ("limb", (0, -0.29, 1.3), 0.07, (0, -0.34, 1.2), 0.025, SKIN),  # pointed chin
    ("limb", (0, -0.39, 1.5), 0.05, (0, -0.53, 1.42), 0.018, SKIN_DARK),  # long nose
    ("ball", (0, -0.4, 1.64), (0.2, 0.06, 0.035), SKIN_DARK, (8, 0, 0)),  # brow ridge
    # neck, tiny chest and a coat flaring out like a triangle
    ("limb", (0, -0.07, 1.18), 0.05, (0, -0.2, 1.34), 0.06, SKIN),
    ("ball", (0, -0.06, 1.1), (0.17, 0.12, 0.13), SHIRT, (10, 0, 0)),
    ("cone", (0, -0.04, 1.15), 0.17, (0, 0.02, 0.52), 0.29, COAT),
]
for x in (1, -1):
    SHAPES += [
        ("ball", (0.28 * x, -0.12, 1.6), (0.035, 0.05, 0.06), SKIN_DARK, (0, 0, 0)),  # small ears
        # skinny arms in coat sleeves, gloved hands rubbed together in front of the chest
        ("limb", (0.17 * x, -0.04, 1.12), 0.055, (0.22 * x, -0.1, 0.86), 0.05, COAT),
        ("limb", (0.22 * x, -0.1, 0.86), 0.05, (0.06 * x, -0.24, 0.92), 0.045, COAT),
        ("ball", (0.04 * x, -0.28, 0.94), (0.06, 0.07, 0.075), GLOVE, (0, 0, 0)),
        ("limb", (0.02 * x, -0.32, 0.98), 0.02, (0.0, -0.36, 1.03), 0.015, GLOVE),
        # thin legs, big shoes
        ("limb", (0.08 * x, 0, 0.6), 0.055, (0.09 * x, -0.02, 0.08), 0.04, PANTS),
        ("ball", (0.09 * x, -0.07, 0.04), (0.065, 0.15, 0.045), SHOE, (0, 0, 0)),
    ]
SHAPES.append(("limb", (0, -0.21, 1.13), 0.025, (0, -0.22, 0.95), 0.035, TIE))
# hair: a white mass round the back and sides of the dome, with long messy tufts sticking out
HEAD_CENTRE = Vector((0, -0.16, 1.6))
SHAPES += [
    ("ball", (0, 0.06, 1.58), (0.25, 0.11, 0.13), HAIR, (0, 0, 0)),
    ("ball", (0.25, -0.1, 1.62), (0.09, 0.15, 0.12), HAIR, (0, 0, 0)),
    ("ball", (-0.25, -0.1, 1.62), (0.09, 0.15, 0.12), HAIR, (0, 0, 0)),
]
for i in range(11):
    turn = math.radians(60 + i * 24)  # 0 is straight ahead: from his left temple, round the back, to the right
    out = Vector((math.sin(turn), -math.cos(turn), 0.25 + 0.2 * (i % 3)))
    base = HEAD_CENTRE + Vector((out.x * 0.3, out.y * 0.3, 0.03 * (i % 3)))
    tip = base + out.normalized() * (0.17 + 0.06 * ((i * 7) % 3))
    SHAPES.append(("limb", tuple(base), 0.05, tuple(tip), 0.008, HAIR))
PAINT = [((-0.14, -0.3, 0.6), 0.07, COAT_STAIN), ((0.1, -0.28, 0.5), 0.045, COAT_STAIN)]


def shape_matrix(shape):
    _, centre, radii, _, rot = shape
    r = Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
    return Matrix.Translation(centre) @ r @ Matrix.Diagonal((*radii, 1.0))


def shape_distance(shape, p):
    if shape[0] == "ball":
        return ((shape_matrix(shape).inverted() @ p).length - 1.0) * min(shape[2])
    # limbs and cones measure the same way
    _, a, ra, b, rb, _ = shape
    a, b = Vector(a), Vector(b)
    ab = b - a
    raw = (p - a).dot(ab) / ab.length_squared
    t = max(0.0, min(1.0, raw))
    past_hem = 1.0 if shape[0] == "cone" and not 0.0 <= raw <= 1.0 else 0.0  # cones end flat
    return (p - (a + ab * t)).length - (ra + (rb - ra) * t) + past_hem


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

bm = bmesh.new()
for shape in SHAPES:
    if shape[0] == "ball":
        bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=1.0, matrix=shape_matrix(shape))
    else:
        _, a, ra, b, rb, _ = shape
        a, b = Vector(a), Vector(b)
        frame = Matrix.Translation((a + b) / 2) @ (b - a).to_track_quat("Z", "Y").to_matrix().to_4x4()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=ra, radius2=rb, depth=(b - a).length, matrix=frame)
        if shape[0] == "limb":  # limbs get round ends, cones keep a flat hem
            for centre, radius in ((a, ra), (b, rb)):
                bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=radius, matrix=Matrix.Translation(centre))
mesh = bpy.data.meshes.new("SK_Scientist")
bm.to_mesh(mesh)
bm.free()
body = bpy.data.objects.new("SK_Scientist", mesh)
scene.collection.objects.link(body)
bpy.context.view_layer.objects.active = body
body.select_set(True)
for kind, settings in (("REMESH", dict(mode="VOXEL", voxel_size=VOXEL)), ("SMOOTH", dict(factor=0.6, iterations=6))):
    mod = body.modifiers.new(kind, kind)
    for key, value in settings.items():
        setattr(mod, key, value)
    bpy.ops.object.modifier_apply(modifier=mod.name)
mod = body.modifiers.new("Decimate", "DECIMATE")
mod.ratio = TARGET_FACES / len(mesh.polygons)
bpy.ops.object.modifier_apply(modifier="Decimate")
for poly in mesh.polygons:
    poly.use_smooth = False

col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
for poly in mesh.polygons:
    p = Vector(poly.center)
    best = min(SHAPES, key=lambda s: shape_distance(s, p))
    rgba = best[3] if best[0] == "ball" else best[5]
    for centre, radius, paint in PAINT:
        if (p - Vector(centre)).length < radius:
            rgba = paint
    shade = (0.72 + 0.28 * min(1.0, p.z / 1.6)) * (0.85 + 0.15 * max(0.0, poly.normal.z))
    for li in poly.loop_indices:
        col.data[li].color = (rgba[0] * shade, rgba[1] * shade, rgba[2] * shade, 1.0)


def piece(bm_piece, rgba):
    m = bpy.data.meshes.new("Piece")
    bm_piece.to_mesh(m)
    bm_piece.free()
    c = m.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for item in c.data:
        item.color = rgba
    ob = bpy.data.objects.new("Piece", m)
    scene.collection.objects.link(ob)
    return ob


pieces = []
# thick round glasses, the right lens a bit bigger: one eye always wider than the other
for x, r in ((0.11, 0.085), (-0.11, 0.075)):
    centre = Vector((x, -0.43, 1.56))
    face = Matrix.Translation(centre) @ Euler((math.radians(90 + 8), 0, 0)).to_matrix().to_4x4()
    b = bmesh.new()
    bmesh.ops.create_cone(b, cap_ends=True, segments=16, radius1=r, radius2=r, depth=0.03, matrix=face)
    pieces.append(piece(b, FRAME))
    b = bmesh.new()
    bmesh.ops.create_cone(b, cap_ends=True, segments=16, radius1=r * 0.8, radius2=r * 0.8, depth=0.035, matrix=face)
    pieces.append(piece(b, LENS))
    b = bmesh.new()  # tiny pupils staring at you
    bmesh.ops.create_uvsphere(b, u_segments=8, v_segments=6, radius=0.018, matrix=Matrix.Translation(centre + Vector((-0.012 * (x > 0), -0.025, 0.0))))
    pieces.append(piece(b, PUPIL))
b = bmesh.new()
bmesh.ops.create_cube(b, size=1.0, matrix=Matrix.Translation((0, -0.45, 1.58)) @ Matrix.Diagonal((0.06, 0.02, 0.015, 1)))
pieces.append(piece(b, FRAME))
# manic grin: a crescent of teeth on a dark mouth, curling higher on his left
for i in range(7):
    t = (i - 3) / 3.0  # -1 .. 1 across the mouth
    x = 0.11 * t
    z = 1.37 + 0.035 * t * t + 0.012 * t
    y = -0.395 + 0.06 * t * t
    turn = Euler((0, 0, math.radians(-35 * t))).to_matrix().to_4x4()
    b = bmesh.new()
    bmesh.ops.create_cube(b, size=1.0, matrix=Matrix.Translation((x, y, z)) @ turn @ Matrix.Diagonal((0.036, 0.03, 0.05, 1)))
    pieces.append(piece(b, MOUTH))
    b = bmesh.new()
    bmesh.ops.create_cube(b, size=1.0, matrix=Matrix.Translation((x, y - 0.012, z + 0.008)) @ turn @ Matrix.Diagonal((0.03, 0.02, 0.022, 1)))
    pieces.append(piece(b, TEETH))

bpy.ops.object.select_all(action="DESELECT")
for ob in pieces:
    ob.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
mesh = body.data
for poly in mesh.polygons:
    poly.use_smooth = False
mesh.color_attributes.active_color = mesh.color_attributes["Col"]
mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")

material = bpy.data.materials.new("M_Scientist")
material.use_nodes = True
nodes = material.node_tree.nodes
shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
attribute = nodes.new("ShaderNodeVertexColor")
attribute.layer_name = "Col"
material.node_tree.links.new(attribute.outputs["Color"], shader.inputs["Base Color"])
shader.inputs["Roughness"].default_value = 0.85
mesh.materials.append(material)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_yup=True,
                          export_vertex_color="ACTIVE", export_materials="EXPORT")
print("scientist: %d verts, %d faces -> %s" % (len(mesh.vertices), len(mesh.polygons), os.path.normpath(OUT_GLB)))
