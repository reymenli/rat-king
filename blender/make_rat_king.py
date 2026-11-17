# Builds the Rat King (the player character): low-poly mesh, rig and animation clips.
#
#   blender -b -P blender/make_rat_king.py
#
# Writes blender/rat-king-character.blend and assets/models/characters/rat_king/SK_RatKing.glb.
# The whole character is defined in this file, so to change a shape, colour or clip,
# edit the tables below and run it again.
#
# Conventions match the rest of the kit: 1 unit is 1 m, feet at the origin, facing -Y in
# Blender (+Z in Godot), vertex colours instead of textures, one NLA track per clip.

import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_BLEND = os.path.join(HERE, "rat-king-character.blend")
OUT_GLB = os.path.join(HERE, "..", "assets", "models", "characters", "rat_king", "SK_RatKing.glb")
FPS = 30

# ------------------------------------------------------------------ colours (sRGB hex)

def colour(hex_code):
    def linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(linear(int(hex_code[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)

FUR = colour("8c8f99")
SUIT = colour("1d2744")
SUIT_DARK = colour("151c33")
SHIRT = colour("f2f2f2")
TIE = colour("c2202b")
PINK = colour("f0a3ad")
SHOE = colour("101012")
GLASS = colour("08080a")
GOLD = colour("f2bf2e")
GEM = colour("d9263a")

# ------------------------------------------------------------------ skeleton
# name: (head, tail, parent). The character's left side is +X.

BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "hips": ((0, 0, 0.62), (0, 0, 0.75), "root"),
    "spine": ((0, 0, 0.75), (0, 0, 1.22), "hips"),
    "head": ((0, 0, 1.22), (0, 0, 1.6), "spine"),
    "tail1": ((0, 0.13, 0.66), (0, 0.36, 0.58), "hips"),
    "tail2": ((0, 0.36, 0.58), (0, 0.6, 0.6), "tail1"),
    "tail3": ((0, 0.6, 0.6), (0, 0.8, 0.72), "tail2"),
}
for side, x in ((".L", 1), (".R", -1)):
    BONES["upper_arm" + side] = ((0.3 * x, 0, 1.14), (0.3 * x, 0, 0.84), "spine")
    BONES["forearm" + side] = ((0.3 * x, 0, 0.84), (0.3 * x, 0, 0.5), "upper_arm" + side)
    BONES["thigh" + side] = ((0.12 * x, 0, 0.62), (0.12 * x, 0, 0.34), "hips")
    BONES["shin" + side] = ((0.12 * x, 0, 0.34), (0.12 * x, 0, 0.04), "thigh" + side)

# ------------------------------------------------------------------ body parts
# (bone, shape, centre, colour, options). Every part moves rigidly with one bone.
#   box:    size=(x, y, z)
#   cone:   r1, r2, depth, optional rot=(x, y, z) degrees. The axis is +Z before rotating.
#   ball:   r, optional scale=(x, y, z)

PARTS = [
    # torso and hips
    ("spine", "box", (0, 0, 0.97), SUIT, dict(size=(0.46, 0.28, 0.5))),
    ("spine", "box", (0, -0.142, 1.0), SHIRT, dict(size=(0.15, 0.02, 0.42))),
    ("spine", "box", (0, -0.155, 0.98), TIE, dict(size=(0.06, 0.02, 0.32))),
    ("spine", "cone", (0, 0, 1.23), FUR, dict(r1=0.1, r2=0.09, depth=0.08)),
    ("hips", "box", (0, 0, 0.66), SUIT_DARK, dict(size=(0.42, 0.27, 0.18))),
    # head
    ("head", "ball", (0, 0, 1.43), FUR, dict(r=0.2, scale=(1.0, 1.05, 0.95))),
    ("head", "cone", (0, -0.27, 1.39), FUR, dict(r1=0.13, r2=0.045, depth=0.27, rot=(90, 0, 0))),
    ("head", "ball", (0, -0.415, 1.39), PINK, dict(r=0.045)),
    ("head", "box", (0.09, -0.18, 1.47), GLASS, dict(size=(0.15, 0.05, 0.09))),
    ("head", "box", (-0.09, -0.18, 1.47), GLASS, dict(size=(0.15, 0.05, 0.09))),
    ("head", "box", (0, -0.185, 1.48), GLASS, dict(size=(0.06, 0.03, 0.025))),
    ("head", "cone", (0.17, 0.03, 1.6), FUR, dict(r1=0.11, r2=0.11, depth=0.03, rot=(90, 0, 0))),
    ("head", "cone", (-0.17, 0.03, 1.6), FUR, dict(r1=0.11, r2=0.11, depth=0.03, rot=(90, 0, 0))),
    ("head", "cone", (0.17, 0.01, 1.6), PINK, dict(r1=0.07, r2=0.07, depth=0.02, rot=(90, 0, 0))),
    ("head", "cone", (-0.17, 0.01, 1.6), PINK, dict(r1=0.07, r2=0.07, depth=0.02, rot=(90, 0, 0))),
    # crown
    ("head", "cone", (0, 0.01, 1.64), GOLD, dict(r1=0.125, r2=0.15, depth=0.09)),
    ("head", "ball", (0, -0.14, 1.64), GEM, dict(r=0.028)),
]
for i in range(5):  # crown points
    angle = math.radians(90 + i * 72)
    PARTS.append(("head", "cone", (0.13 * math.cos(angle), 0.01 - 0.13 * math.sin(angle), 1.725), GOLD,
                  dict(r1=0.035, r2=0.004, depth=0.09)))
for side, x in ((".L", 1), (".R", -1)):
    PARTS += [
        ("upper_arm" + side, "box", (0.3 * x, 0, 0.99), SUIT, dict(size=(0.12, 0.14, 0.32))),
        ("forearm" + side, "box", (0.3 * x, 0, 0.69), SUIT, dict(size=(0.11, 0.12, 0.3))),
        ("forearm" + side, "ball", (0.3 * x, 0, 0.5), PINK, dict(r=0.065)),
        ("thigh" + side, "box", (0.12 * x, 0, 0.48), SUIT_DARK, dict(size=(0.16, 0.17, 0.3))),
        ("shin" + side, "box", (0.12 * x, 0, 0.2), SUIT_DARK, dict(size=(0.14, 0.15, 0.3))),
        ("shin" + side, "box", (0.12 * x, -0.06, 0.045), SHOE, dict(size=(0.15, 0.3, 0.09))),
    ]
TAIL_RADII = {"tail1": (0.045, 0.035), "tail2": (0.035, 0.024), "tail3": (0.024, 0.008)}

# ------------------------------------------------------------------ animation clips
# Each clip is a list of (frame, pose). A pose maps a bone to (x, y, z) degrees, turning the
# bone about the character's own axes: X is left, Y is back, Z is up. Bones not listed are
# at rest. "hips_move" shifts the hips in metres. For limbs that hang down, a negative X
# angle swings them forward. For the spine and head, a positive X angle leans forward.

def mirrored(pose):
    out = {}
    for bone, value in pose.items():
        if bone.endswith(".L"):
            bone = bone[:-2] + ".R"
        elif bone.endswith(".R"):
            bone = bone[:-2] + ".L"
        out[bone] = (value[0], -value[1], -value[2]) if bone != "hips_move" else (-value[0], value[1], value[2])
    return out

REST = {}
IDLE_OUT = {"spine": (2, 0, 0), "head": (-2, 0, 0), "upper_arm.L": (0, -4, 0), "upper_arm.R": (0, 4, 0),
            "tail1": (0, 0, 10), "tail2": (0, 0, 8), "hips_move": (0, 0, 0.008)}
IDLE_IN = {"tail1": (0, 0, -10), "tail2": (0, 0, -8), "upper_arm.L": (0, -2, 0), "upper_arm.R": (0, 2, 0)}

WALK_CONTACT = {"thigh.L": (-28, 0, 0), "shin.L": (6, 0, 0), "thigh.R": (22, 0, 0), "shin.R": (22, 0, 0),
                "upper_arm.L": (22, 0, 0), "forearm.L": (-10, 0, 0), "upper_arm.R": (-22, 0, 0), "forearm.R": (-22, 0, 0),
                "spine": (3, 0, 5), "head": (0, 0, -4), "tail1": (0, 0, 8), "hips_move": (0, 0, -0.025)}
WALK_PASS = {"thigh.L": (0, 0, 0), "thigh.R": (-8, 0, 0), "shin.R": (48, 0, 0),
             "forearm.L": (-12, 0, 0), "forearm.R": (-12, 0, 0), "spine": (3, 0, 0), "hips_move": (0, 0, 0.02)}

RUN_CONTACT = {"thigh.L": (-48, 0, 0), "shin.L": (12, 0, 0), "thigh.R": (34, 0, 0), "shin.R": (58, 0, 0),
               "upper_arm.L": (42, 0, 0), "forearm.L": (-75, 0, 0), "upper_arm.R": (-42, 0, 0), "forearm.R": (-85, 0, 0),
               "spine": (14, 0, 8), "head": (-8, 0, -6), "tail1": (-10, 0, 10), "hips_move": (0, 0, -0.04)}
RUN_PASS = {"thigh.L": (-5, 0, 0), "shin.L": (8, 0, 0), "thigh.R": (-18, 0, 0), "shin.R": (85, 0, 0),
            "upper_arm.L": (5, 0, 0), "forearm.L": (-80, 0, 0), "upper_arm.R": (-5, 0, 0), "forearm.R": (-80, 0, 0),
            "spine": (14, 0, 0), "head": (-8, 0, 0), "tail1": (-10, 0, 0), "hips_move": (0, 0, 0.05)}

JUMP_AIR = {"thigh.L": (-40, 0, 0), "shin.L": (65, 0, 0), "thigh.R": (-15, 0, 0), "shin.R": (40, 0, 0),
            "upper_arm.L": (-20, -55, 0), "upper_arm.R": (-20, 55, 0), "forearm.L": (-25, 0, 0), "forearm.R": (-25, 0, 0),
            "spine": (6, 0, 0), "tail1": (-25, 0, 0), "tail2": (-15, 0, 0)}

REACH = {"upper_arm.R": (-82, 0, 0), "forearm.R": (-18, 0, 0), "spine": (7, 0, 8), "head": (4, 0, 0)}

OW = {"spine": (-18, 0, 0), "head": (-16, 0, 0), "upper_arm.L": (-35, -65, 0), "upper_arm.R": (-35, 65, 0),
      "forearm.L": (-40, 0, 0), "forearm.R": (-40, 0, 0), "thigh.L": (-18, 0, 0), "shin.L": (25, 0, 0),
      "tail1": (-30, 0, 0), "tail2": (-20, 0, 0), "hips_move": (0, 0.06, 0.03)}

POINT = {"upper_arm.R": (-96, 0, 0), "forearm.R": (-4, 0, 0), "spine": (0, 0, 12), "head": (-4, 0, -8),
         "upper_arm.L": (0, -12, 0)}

CLIPS = {
    "Idle": [(1, REST), (31, IDLE_OUT), (61, IDLE_IN), (91, REST)],
    "Walk": [(1, WALK_CONTACT), (7, WALK_PASS), (13, mirrored(WALK_CONTACT)), (19, mirrored(WALK_PASS)), (25, WALK_CONTACT)],
    "Run": [(1, RUN_CONTACT), (5, RUN_PASS), (9, mirrored(RUN_CONTACT)), (13, mirrored(RUN_PASS)), (17, RUN_CONTACT)],
    "Jump": [(1, REST), (7, JUMP_AIR)],
    "Interact": [(1, REST), (7, REACH), (12, REACH), (19, REST)],
    "Ow": [(1, REST), (5, OW), (11, OW), (21, REST)],
    "Command": [(1, REST), (7, POINT), (18, POINT), (25, REST)],
}

# ------------------------------------------------------------------ build

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS

# armature
arm_data = bpy.data.armatures.new("RIG_RatKing")
arm = bpy.data.objects.new("RIG_RatKing", arm_data)
scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for name, (head, tail, parent) in BONES.items():
    bone = arm_data.edit_bones.new(name)
    bone.head, bone.tail = head, tail
    if parent:
        bone.parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")

# mesh
bm = bmesh.new()
colours = bm.loops.layers.float_color.new("Col")
weights = bm.verts.layers.deform.verify()
bone_names = list(BONES)


def finish_part(verts, bone, rgba):
    for vert in verts:
        vert[weights][bone_names.index(bone)] = 1.0
        for loop in vert.link_loops:
            loop[colours] = rgba


def add_part(bone, shape, centre, rgba, options):
    rotation = Euler([math.radians(a) for a in options.get("rot", (0, 0, 0))]).to_matrix().to_4x4()
    matrix = Matrix.Translation(centre) @ rotation
    if shape == "box":
        size = options["size"]
        scale = Matrix.Diagonal((size[0], size[1], size[2], 1.0))
        verts = bmesh.ops.create_cube(bm, size=1.0, matrix=matrix @ scale)["verts"]
    elif shape == "cone":
        verts = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=options["r1"], radius2=options["r2"],
                                      depth=options["depth"], matrix=matrix)["verts"]
    else:
        scale = options.get("scale", (1, 1, 1))
        verts = bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=options["r"],
                                          matrix=matrix @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0)))["verts"]
    finish_part(verts, bone, rgba)


for part in PARTS:
    add_part(*part)
for bone, (r1, r2) in TAIL_RADII.items():  # a cone along each tail bone
    head, tail = Vector(BONES[bone][0]), Vector(BONES[bone][1])
    matrix = Matrix.Translation((head + tail) / 2) @ (tail - head).to_track_quat("Z", "Y").to_matrix().to_4x4()
    verts = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=r1, radius2=r2,
                                  depth=(tail - head).length * 1.08, matrix=matrix)["verts"]
    finish_part(verts, bone, PINK)

mesh = bpy.data.meshes.new("SK_RatKing")
bm.to_mesh(mesh)
bm.free()
body = bpy.data.objects.new("SK_RatKing", mesh)
scene.collection.objects.link(body)
for name in bone_names:
    body.vertex_groups.new(name=name)
body.parent = arm
body.modifiers.new("Armature", "ARMATURE").object = arm
mesh.color_attributes.active_color = mesh.color_attributes["Col"]
mesh.color_attributes.render_color_index = 0

material = bpy.data.materials.new("M_RatKing")  # shows the vertex colours in Blender
material.use_nodes = True
nodes = material.node_tree.nodes
shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
attribute = nodes.new("ShaderNodeVertexColor")
attribute.layer_name = "Col"
material.node_tree.links.new(attribute.outputs["Color"], shader.inputs["Base Color"])
shader.inputs["Roughness"].default_value = 0.8
mesh.materials.append(material)

# animation: one action per clip, pushed down to its own NLA track
arm.animation_data_create()
for pose_bone in arm.pose.bones:
    pose_bone.rotation_mode = "QUATERNION"


def apply_pose(pose, frame):
    for pose_bone in arm.pose.bones:
        rest = pose_bone.bone.matrix_local.to_quaternion()
        angles = pose.get(pose_bone.name, (0, 0, 0))
        turn = Euler([math.radians(a) for a in angles]).to_quaternion()
        pose_bone.rotation_quaternion = rest.inverted() @ turn @ rest  # character axes -> bone axes
        pose_bone.keyframe_insert("rotation_quaternion", frame=frame)
    hips = arm.pose.bones["hips"]
    hips.location = hips.bone.matrix_local.to_quaternion().inverted() @ Vector(pose.get("hips_move", (0, 0, 0)))
    hips.keyframe_insert("location", frame=frame)


for clip, keys in CLIPS.items():
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    arm.animation_data.action = action
    for frame, pose in keys:
        apply_pose(pose, frame)
    track = arm.animation_data.nla_tracks.new()
    track.name = clip
    strip = track.strips.new(clip, 1, action)
    strip.name = clip
    arm.animation_data.action = None
apply_pose(REST, 1)
arm.animation_data.action = None  # the rest pose keys above made a stray action, drop it
for action in list(bpy.data.actions):
    if action.name not in CLIPS:
        bpy.data.actions.remove(action)
for pose_bone in arm.pose.bones:
    pose_bone.rotation_quaternion = (1, 0, 0, 0)
    pose_bone.location = (0, 0, 0)
scene.frame_set(1)

# save and export
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format="GLB",
    export_yup=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_force_sampling=True,
    export_vertex_color="ACTIVE",
    export_materials="EXPORT",
)
print("rat king: %d verts, %d clips -> %s" % (len(mesh.vertices), len(CLIPS), os.path.normpath(OUT_GLB)))
