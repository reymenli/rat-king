# Builds the Rat King (the player character): low-poly body parts, rig and animation clips.
#
#   blender -b -P blender/make_rat_king.py
#
# Writes blender/rat-king-character.blend and assets/models/characters/rat_king/SK_RatKing.glb.
#
# Design (docs/PROGRESS.md, "Character direction"): a mutated rat with human traits. Rat-like
# head and build (long snout, big ears, pink hands and tail, hunched forward), dressed like a
# boss: navy suit, white shirt, red tie, black sunglasses and a gold crown.
#
# How the mesh is made (blender/fused_mesh.py): each PART is fused into its own closed
# low-poly surface and only follows its own bones, so an arm can never melt into the belly.
# Small hard pieces (sunglasses, crown, teeth, whiskers) follow the head bone.
#
# Conventions match the rest of the kit: 1 unit is 1 m, feet at the origin, facing -Y in
# Blender (+Z in Godot), vertex colours instead of textures, one NLA track per clip.

import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from fused_mesh import box, colour, disc, fused_part, hard_piece, join, stick  # noqa: E402

OUT_BLEND = os.path.join(HERE, "rat-king-character.blend")
OUT_GLB = os.path.join(HERE, "..", "assets", "models", "characters", "rat_king", "SK_RatKing.glb")
FPS = 30

# ------------------------------------------------------------------ colours (sRGB hex)

FUR = colour("858891")
SKIN = colour("eaa0a9")
SUIT = colour("1f2a48")
PANTS = colour("18203a")
SHIRT = colour("f1f1ee")
TIE = colour("c2202b")
SHOE = colour("121214")
SHADES = colour("0b0b0e")
GOLD = colour("f0bd2c")
GEM = colour("d9263a")
TOOTH = colour("f4ead0")
WHISKER = colour("2a2626")

# ------------------------------------------------------------------ skeleton
# name: (head, tail, parent). The character's left side is +X, the front is -Y.
# The spine leans forward and the head pokes out in front of it: he is hunched.

BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "hips": ((0, 0, 0.52), (0, -0.02, 0.64), "root"),
    "spine": ((0, -0.02, 0.64), (0, -0.07, 1.02), "hips"),
    "head": ((0, -0.09, 1.0), (0, -0.25, 1.36), "spine"),
    "tail1": ((0, 0.16, 0.52), (0, 0.4, 0.4), "hips"),
    "tail2": ((0, 0.4, 0.4), (0, 0.66, 0.38), "tail1"),
    "tail3": ((0, 0.66, 0.38), (0, 0.88, 0.5), "tail2"),
}
for side, x in ((".L", 1), (".R", -1)):
    BONES["upper_arm" + side] = ((0.21 * x, -0.05, 0.98), (0.28 * x, -0.1, 0.74), "spine")
    BONES["forearm" + side] = ((0.28 * x, -0.1, 0.74), (0.31 * x, -0.16, 0.47), "upper_arm" + side)
    BONES["thigh" + side] = ((0.12 * x, 0, 0.52), (0.16 * x, -0.08, 0.3), "hips")
    BONES["shin" + side] = ((0.16 * x, -0.08, 0.3), (0.14 * x, 0.01, 0.06), "thigh" + side)

# ------------------------------------------------------------------ body parts
# name: (bones it follows, faces after reduction, shapes). See fused_mesh.py for the shapes.

PARTS = {
    "Head": (["head"], 900, [
        ("ball", (0, -0.19, 1.23), (0.2, 0.22, 0.18), FUR, (0, 0, 0)),
        ("limb", (0, -0.31, 1.21), 0.13, (0, -0.59, 1.15), 0.045, FUR),  # long rat snout
        ("ball", (0.11, -0.33, 1.15), (0.095, 0.1, 0.075), FUR, (0, 0, 0)),
        ("ball", (-0.11, -0.33, 1.15), (0.095, 0.1, 0.075), FUR, (0, 0, 0)),
        ("ball", (0, -0.612, 1.155), (0.04, 0.038, 0.034), SKIN, (0, 0, 0)),
        ("ball", (0.2, -0.1, 1.4), (0.12, 0.035, 0.13), FUR, (10, 0, -28)),  # big round ears
        ("ball", (0.2, -0.13, 1.4), (0.085, 0.02, 0.095), SKIN, (10, 0, -28)),
        ("ball", (-0.2, -0.1, 1.4), (0.12, 0.035, 0.13), FUR, (10, 0, 28)),
        ("ball", (-0.2, -0.13, 1.4), (0.085, 0.02, 0.095), SKIN, (10, 0, 28)),
    ]),
    "Torso": (["hips", "spine"], 900, [
        ("limb", (0, -0.04, 0.98), 0.085, (0, -0.13, 1.09), 0.09, FUR),  # neck
        ("ball", (0, -0.08, 0.81), (0.2, 0.16, 0.25), SUIT, (0, 0, 0)),  # one smooth jacket, no crease
        ("ball", (0, 0.0, 0.57), (0.19, 0.16, 0.11), PANTS, (0, 0, 0)),
        ("ball", (0, -0.2, 0.95), (0.06, 0.03, 0.1), SHIRT, (0, 0, 0)),  # shirt in the open jacket
        ("limb", (0, -0.226, 1.0), 0.022, (0, -0.245, 0.8), 0.035, TIE),
    ]),
    "Tail": (["tail1", "tail2", "tail3"], 200, [
        ("limb", (0, 0.14, 0.53), 0.045, (0, 0.4, 0.4), 0.032, SKIN),
        ("limb", (0, 0.4, 0.4), 0.032, (0, 0.66, 0.38), 0.02, SKIN),
        ("limb", (0, 0.66, 0.38), 0.02, (0, 0.9, 0.52), 0.009, SKIN),
    ]),
}
for side, x in ((".L", 1), (".R", -1)):
    PARTS["Arm" + side] = (["upper_arm" + side, "forearm" + side], 300, [
        ("limb", (0.21 * x, -0.05, 0.98), 0.062, (0.28 * x, -0.1, 0.74), 0.052, SUIT),
        ("limb", (0.28 * x, -0.1, 0.74), 0.052, (0.31 * x, -0.16, 0.51), 0.048, SUIT),
        ("ball", (0.31 * x, -0.162, 0.5), (0.05, 0.05, 0.025), SHIRT, (0, 0, 0)),  # cuff
        ("ball", (0.315 * x, -0.17, 0.43), (0.06, 0.055, 0.075), SKIN, (0, 0, 0)),
        ("limb", (0.31 * x, -0.2, 0.42), 0.02, (0.31 * x, -0.23, 0.36), 0.015, SKIN),
    ])
    PARTS["Leg" + side] = (["thigh" + side, "shin" + side], 300, [
        ("limb", (0.12 * x, 0, 0.52), 0.09, (0.16 * x, -0.08, 0.3), 0.068, PANTS),
        ("limb", (0.16 * x, -0.08, 0.3), 0.068, (0.14 * x, 0.01, 0.1), 0.055, PANTS),
        ("ball", (0.15 * x, -0.08, 0.05), (0.075, 0.16, 0.05), SHOE, (0, 0, 0)),
    ])

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
IDLE_OUT = {"spine": (3, 0, 0), "head": (-4, 0, 3), "upper_arm.L": (0, -4, 0), "upper_arm.R": (0, 4, 0),
            "tail1": (0, 0, 14), "tail2": (0, 0, 12), "tail3": (0, 0, 10), "hips_move": (0, 0, 0.01)}
IDLE_IN = {"head": (2, 0, -3), "tail1": (0, 0, -14), "tail2": (0, 0, -12), "tail3": (0, 0, -10),
           "upper_arm.L": (0, -2, 0), "upper_arm.R": (0, 2, 0)}

WALK_CONTACT = {"thigh.L": (-28, 0, 0), "shin.L": (6, 0, 0), "thigh.R": (22, 0, 0), "shin.R": (22, 0, 0),
                "upper_arm.L": (22, 0, 0), "forearm.L": (-10, 0, 0), "upper_arm.R": (-22, 0, 0), "forearm.R": (-22, 0, 0),
                "spine": (3, 0, 8), "head": (0, 0, -6), "tail1": (0, 0, 12), "hips_move": (0, 0, -0.025)}
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


def bone_distance(name, p):
    a, b = Vector(BONES[name][0]), Vector(BONES[name][1])
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def weigh(ob, bones):
    """Each vertex follows only this part's bones, blended by distance so joints bend smoothly."""
    groups = {name: ob.vertex_groups.new(name=name) for name in bones}
    for v in ob.data.vertices:
        raw = {name: 1.0 / max(bone_distance(name, v.co), 0.01) ** 4 for name in bones}
        total = sum(raw.values())
        for name, value in raw.items():
            if value / total > 0.01:
                groups[name].add([v.index], value / total, "REPLACE")


objects = []
for name, (bones, faces, shapes) in PARTS.items():
    ob = fused_part(name, shapes, faces, voxel=0.012, height=1.45)
    weigh(ob, bones)
    objects.append(ob)


def head_piece(name, build, rgba):
    ob = hard_piece(name, build, rgba)
    ob.vertex_groups.new(name="head").add(range(len(ob.data.vertices)), 1.0, "REPLACE")
    objects.append(ob)


# sunglasses: found by casting rays at the head, so they sit just in front of the face
# instead of sinking into it. Rounded lenses angled to the face, a top bar, arms back to the
# ears, and a white glint on each lens so they read as glass, not as empty eyes.
head_tree = BVHTree.FromObject(objects[0], bpy.context.evaluated_depsgraph_get())
SHADES_Z = 1.275


def face_point(x, z):
    hit, normal, _, _ = head_tree.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)))
    return hit, normal


def lens(bm, centre, normal):
    facing = normal.to_track_quat("Z", "Y").to_matrix().to_4x4()
    shape = Matrix.Translation(centre) @ facing @ Matrix.Diagonal((1.3, 0.85, 1.0, 1.0))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=14, radius1=0.05, radius2=0.05, depth=0.016, matrix=shape)


rims = []
for x in (0.08, -0.08):
    hit, normal = face_point(x, SHADES_Z)
    normal = (normal + Vector((0, -1, 0))).normalized()  # face mostly forward, a little to the side
    centre = hit + normal * 0.03
    rims.append(centre)
    head_piece("Lens", lambda bm, c=centre, n=normal: lens(bm, c, n), SHADES)
    glint = centre + normal * 0.01 + Vector((0.02 * (1 if x > 0 else -1), 0, 0.018))
    head_piece("Glint", lambda bm, g=glint, n=normal: box(bm, g, (0.022, 0.004, 0.006), (0, 0, 0)), colour("ffffff"))
    ear = Vector((0.17 * (1 if x > 0 else -1), -0.12, SHADES_Z + 0.03))
    head_piece("Temple", lambda bm, a=centre + Vector((0.06 * (1 if x > 0 else -1), 0.01, 0.01)), b=ear: stick(bm, a, b, 0.008), SHADES)
top = (rims[0] + rims[1]) / 2 + Vector((0, -0.005, 0.04))
head_piece("TopBar", lambda bm: stick(bm, rims[1] + Vector((0, 0, 0.04)), rims[0] + Vector((0, 0, 0.04)), 0.011), SHADES)
head_piece("Bridge", lambda bm: box(bm, (rims[0] + rims[1]) / 2 + Vector((0, -0.01, 0.01)), (0.05, 0.015, 0.016)), SHADES)
# buck teeth
for x in (0.013, -0.013):
    head_piece("Tooth", lambda bm, x=x: box(bm, (x, -0.575, 1.09), (0.022, 0.012, 0.05)), TOOTH)
# whiskers
for x in (1, -1):
    for dz, dy in ((0.02, 0.0), (0.0, 0.01), (-0.02, 0.02)):
        a = Vector((0.04 * x, -0.55, 1.15 + dz))
        head_piece("Whisker", lambda bm, a=a, x=x, dz=dz, dy=dy: stick(bm, a, a + Vector((0.2 * x, 0.06 + dy, dz * 3)), 0.004, 3), WHISKER)


# gold crown: a band with five points and a red gem, sitting a little crooked
CROWN_TILT = Matrix.Translation((0.01, -0.18, 1.355)) @ Euler((math.radians(-6), math.radians(8), math.radians(18))).to_matrix().to_4x4()
def crown(bm):
    points = 10
    bottom, top = [], []
    for i in range(points):
        a = i * math.tau / points
        d = Vector((math.cos(a), math.sin(a), 0))
        bottom.append(bm.verts.new(d * 0.15))
        top.append(bm.verts.new(d * 0.165 + Vector((0, 0, 0.17 if i % 2 == 0 else 0.07))))
    for i in range(points):
        j = (i + 1) % points
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.014)
    bmesh.ops.transform(bm, matrix=CROWN_TILT, verts=bm.verts[:])


head_piece("Crown", crown, GOLD)
gem_at = CROWN_TILT @ Vector((0.0, -0.17, 0.05))  # on the front of the band, wherever the crown tilts
head_piece("Gem", lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=0.026, matrix=Matrix.Translation(gem_at)), GEM)

body = join(objects, "SK_RatKing")
mesh = body.data
body.parent = arm
body.modifiers.new("Armature", "ARMATURE").object = arm

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
bpy.ops.object.select_all(action="DESELECT")
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
print("rat king: %d verts, %d faces, %d clips -> %s" % (len(mesh.vertices), len(mesh.polygons), len(CLIPS), os.path.normpath(OUT_GLB)))
