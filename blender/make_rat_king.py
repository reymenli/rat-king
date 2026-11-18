# Builds the Rat King (the player character): one fused low-poly mesh, rig and animation clips.
#
#   blender -b -P blender/make_rat_king.py
#
# Writes blender/rat-king-character.blend and assets/models/characters/rat_king/SK_RatKing.glb.
#
# Design (docs/PROGRESS.md, "Character direction"): a mutated street rat with human traits,
# scrappy, not fancy. Hunched, pot-bellied, long arms and big hands, a big head with a long
# snout, buck teeth, mismatched eyes under an angry brow, a stained tank top and a crown cut
# out of a tin can.
#
# How the mesh is made: the body is laid out as overlapping ellipsoids and tapered limbs
# (SHAPES), fused into one watertight surface with a voxel remesh, smoothed where the shapes
# meet, skinned with automatic weights, then reduced to a faceted low-poly mesh. Each vertex
# takes the colour of the shape it is closest to, then PAINT spots and a top-to-bottom
# gradient are applied. Small hard pieces (eyes, teeth, whiskers, crown) are added after and
# move with the head bone.
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
VOXEL = 0.014  # remesh detail before reduction
TARGET_FACES = 1500  # faces left after reduction, the low-poly look
HEAD_DROP = Vector((0, -0.07, -0.08))  # pushes the head forward and down into the shoulders: the hunch


# ------------------------------------------------------------------ colours (sRGB hex)

def colour(hex_code):
    def linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(linear(int(hex_code[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)

FUR = colour("7a6d63")
FUR_DARK = colour("4f453f")
SKIN = colour("e39aa2")
SHIRT = colour("e6dfc8")
STAIN = colour("d2a93a")
BRASS = colour("c9a03a")
BRASS_DARK = colour("7d6122")
EYE_WHITE = colour("f4efe2")
PUPIL = colour("121014")
TOOTH = colour("f0dc9c")
WHISKER = colour("2a2422")

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
    BONES["upper_arm" + side] = ((0.19 * x, -0.04, 0.98), (0.28 * x, -0.1, 0.74), "spine")
    BONES["forearm" + side] = ((0.28 * x, -0.1, 0.74), (0.31 * x, -0.16, 0.47), "upper_arm" + side)
    BONES["thigh" + side] = ((0.12 * x, 0, 0.52), (0.17 * x, -0.09, 0.3), "hips")
    BONES["shin" + side] = ((0.17 * x, -0.09, 0.3), (0.14 * x, 0.01, 0.06), "thigh" + side)

# ------------------------------------------------------------------ body shapes
# ("ball", centre, radii, colour, rotation degrees) an ellipsoid
# ("limb", start, start radius, end, end radius, colour) a tapered capsule

SHAPES = [
    # head: round skull, long pointed snout, chubby cheeks, a heavy angry brow
    ("ball", (0, -0.12, 1.31), (0.21, 0.23, 0.19), FUR, (0, 0, 0)),
    ("limb", (0, -0.24, 1.29), 0.135, (0, -0.52, 1.23), 0.045, FUR),
    ("ball", (0.115, -0.26, 1.23), (0.1, 0.11, 0.08), FUR, (0, 0, 0)),
    ("ball", (-0.115, -0.26, 1.23), (0.1, 0.11, 0.08), FUR, (0, 0, 0)),
    ("ball", (0, -0.27, 1.4), (0.17, 0.07, 0.045), FUR_DARK, (12, 0, 0)),
    ("ball", (0, -0.545, 1.235), (0.042, 0.04, 0.036), SKIN, (0, 0, 0)),
    # neck, chest and a big belly in a tank top, rat hips
    ("limb", (0, -0.03, 0.98), 0.1, (0, -0.09, 1.14), 0.11, FUR),
    ("ball", (0, -0.08, 0.93), (0.21, 0.15, 0.13), SHIRT, (0, 0, 0)),
    ("ball", (0, -0.08, 0.72), (0.25, 0.24, 0.23), SHIRT, (0, 0, 0)),
    ("ball", (0, 0.0, 0.55), (0.2, 0.17, 0.12), FUR, (0, 0, 0)),
]
for x in (1, -1):
    SHAPES += [
        # big round ears, set wide
        ("ball", (0.2 * x, -0.03, 1.49), (0.12, 0.035, 0.13), FUR, (10, 0, -28 * x)),
        ("ball", (0.2 * x, -0.06, 1.49), (0.085, 0.02, 0.095), SKIN, (10, 0, -28 * x)),
        # long skinny arms, big hands
        ("limb", (0.19 * x, -0.04, 0.98), 0.062, (0.28 * x, -0.1, 0.74), 0.048, FUR),
        ("limb", (0.28 * x, -0.1, 0.74), 0.048, (0.31 * x, -0.16, 0.5), 0.042, FUR),
        ("ball", (0.315 * x, -0.17, 0.43), (0.065, 0.06, 0.085), SKIN, (0, 0, 0)),
        ("limb", (0.31 * x, -0.2, 0.42), 0.022, (0.31 * x, -0.23, 0.35), 0.016, SKIN),
        # short bowed legs, long flat rat feet
        ("limb", (0.12 * x, 0, 0.52), 0.1, (0.17 * x, -0.09, 0.3), 0.07, FUR),
        ("limb", (0.17 * x, -0.09, 0.3), 0.07, (0.14 * x, 0.01, 0.08), 0.05, FUR),
        ("ball", (0.15 * x, -0.08, 0.04), (0.075, 0.16, 0.04), SKIN, (0, 0, 0)),
    ]
SHAPES += [
    ("limb", (0, 0.14, 0.53), 0.05, (0, 0.4, 0.4), 0.035, SKIN),
    ("limb", (0, 0.4, 0.4), 0.035, (0, 0.66, 0.38), 0.022, SKIN),
    ("limb", (0, 0.66, 0.38), 0.022, (0, 0.9, 0.52), 0.01, SKIN),
]
def _dropped(p):
    return tuple(Vector(p) + HEAD_DROP) if p[2] > 1.12 else p
SHAPES = [(s[0], _dropped(s[1]), *s[2:]) if s[0] == "ball" else (s[0], _dropped(s[1]), s[2], _dropped(s[3]), *s[4:]) for s in SHAPES]

# Spots painted over the shape colours: (centre, radius, colour).
PAINT = [
    ((0.07, -0.29, 0.66), 0.085, STAIN),  # cheese stain on the tank top
    ((-0.05, -0.3, 0.78), 0.045, STAIN),
    ((0, -0.2, 0.52), 0.12, FUR_DARK),  # shorts-shadow under the belly
]

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


def shape_matrix(shape):
    """Matrix taking a unit sphere (ball) or the unit segment frame (limb) to the shape."""
    if shape[0] == "ball":
        _, centre, radii, _, rot = shape
        r = Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
        return Matrix.Translation(centre) @ r @ Matrix.Diagonal((*radii, 1.0))
    return None


def shape_distance(shape, p):
    """Rough signed distance from point p to the shape surface, used to pick vertex colours."""
    if shape[0] == "ball":
        local = shape_matrix(shape).inverted() @ p
        return (local.length - 1.0) * min(shape[2])
    _, a, ra, b, rb, _ = shape
    a, b = Vector(a), Vector(b)
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length - (ra + (rb - ra) * t)


# 1. lay out the shapes as one rough mesh
bm = bmesh.new()
for shape in SHAPES:
    if shape[0] == "ball":
        bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=1.0, matrix=shape_matrix(shape))
    else:
        _, a, ra, b, rb, _ = shape
        a, b = Vector(a), Vector(b)
        frame = Matrix.Translation((a + b) / 2) @ (b - a).to_track_quat("Z", "Y").to_matrix().to_4x4()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=ra, radius2=rb, depth=(b - a).length, matrix=frame)
        for centre, radius in ((a, ra), (b, rb)):  # round the ends
            bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=radius, matrix=Matrix.Translation(centre))
mesh = bpy.data.meshes.new("SK_RatKing")
bm.to_mesh(mesh)
bm.free()
body = bpy.data.objects.new("SK_RatKing", mesh)
scene.collection.objects.link(body)
bpy.context.view_layer.objects.active = body
body.select_set(True)

# 2. fuse into one surface and soften the creases where shapes meet
remesh = body.modifiers.new("Remesh", "REMESH")
remesh.mode = "VOXEL"
remesh.voxel_size = VOXEL
bpy.ops.object.modifier_apply(modifier="Remesh")
smooth = body.modifiers.new("Smooth", "SMOOTH")
smooth.factor = 0.6
smooth.iterations = 6
bpy.ops.object.modifier_apply(modifier="Smooth")

# 3. skin with automatic weights while the mesh is dense, then reduce it (weights carry over)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
bpy.context.view_layer.objects.active = body
decimate = body.modifiers.new("Decimate", "DECIMATE")
decimate.ratio = TARGET_FACES / len(mesh.polygons)
body.modifiers.move(body.modifiers.find("Decimate"), 0)
bpy.ops.object.modifier_apply(modifier="Decimate")
for poly in mesh.polygons:
    poly.use_smooth = False  # flat facets


# 4. vertex colours: nearest shape, painted spots, darker towards the feet and underneath
def body_colour(p, normal):
    best = min(SHAPES, key=lambda s: shape_distance(s, p))
    rgba = best[3] if best[0] == "ball" else best[5]
    for centre, radius, paint in PAINT:
        if (p - Vector(centre)).length < radius:
            rgba = paint
    shade = 0.72 + 0.28 * min(1.0, p.z / 1.4)  # feet darker than the head
    shade *= 0.85 + 0.15 * max(0.0, normal.z)  # faces that point up catch more light
    return (rgba[0] * shade, rgba[1] * shade, rgba[2] * shade, 1.0)


col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
for poly in mesh.polygons:
    centre = poly.center
    rgba = body_colour(Vector(centre), poly.normal)
    for li in poly.loop_indices:
        col.data[li].color = rgba


# 5. hard pieces that move with the head bone
def head_piece(name, bm_piece, rgba):
    piece_mesh = bpy.data.meshes.new(name)
    bmesh.ops.translate(bm_piece, vec=HEAD_DROP, verts=bm_piece.verts[:])
    bm_piece.to_mesh(piece_mesh)
    bm_piece.free()
    c = piece_mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for item in c.data:
        item.color = rgba
    for poly in piece_mesh.polygons:
        poly.use_smooth = False
    ob = bpy.data.objects.new(name, piece_mesh)
    scene.collection.objects.link(ob)
    group = ob.vertex_groups.new(name="head")
    group.add(range(len(piece_mesh.vertices)), 1.0, "REPLACE")
    return ob


pieces = []
# mismatched eyes: the left one bulges (the mutation), the right one squints under the brow
for x, radius, squint in ((0.095, 0.058, 0.0), (-0.09, 0.04, 0.35)):
    bm_eye = bmesh.new()
    centre = Vector((x, -0.305, 1.355))
    bmesh.ops.create_uvsphere(bm_eye, u_segments=10, v_segments=7, radius=radius,
                              matrix=Matrix.Translation(centre) @ Matrix.Diagonal((1, 1, 1 - squint, 1)))
    pieces.append(head_piece("Eye", bm_eye, EYE_WHITE))
    bm_pupil = bmesh.new()
    bmesh.ops.create_uvsphere(bm_pupil, u_segments=8, v_segments=6, radius=radius * 0.45,
                              matrix=Matrix.Translation(centre + Vector((-0.008 * (x > 0), -radius * 0.78, 0.004))))
    pieces.append(head_piece("Pupil", bm_pupil, PUPIL))
# buck teeth
for x in (0.013, -0.013):
    bm_tooth = bmesh.new()
    bmesh.ops.create_cube(bm_tooth, size=1.0, matrix=Matrix.Translation((x, -0.505, 1.17)) @ Matrix.Diagonal((0.022, 0.012, 0.05, 1)))
    pieces.append(head_piece("Tooth", bm_tooth, TOOTH))
# whiskers
for x in (1, -1):
    for i, (dz, dy) in enumerate(((0.02, 0.0), (0.0, 0.01), (-0.02, 0.02))):
        bm_w = bmesh.new()
        a = Vector((0.04 * x, -0.48, 1.23 + dz))
        b = a + Vector((0.2 * x, 0.06 + dy, dz * 3))
        frame = Matrix.Translation((a + b) / 2) @ (b - a).to_track_quat("Z", "Y").to_matrix().to_4x4()
        bmesh.ops.create_cone(bm_w, cap_ends=True, segments=3, radius1=0.004, radius2=0.002, depth=(b - a).length, matrix=frame)
        pieces.append(head_piece("Whisker", bm_w, WHISKER))
# crown cut from a tin can: uneven points, tilted, one point bent back
bm_crown = bmesh.new()
points = 10
heights = [0.16, 0.06, 0.13, 0.05, 0.15, 0.06, 0.1, 0.045, 0.15, 0.06]
bottom, top = [], []
for i in range(points):
    a = i * math.tau / points
    d = Vector((math.cos(a), math.sin(a), 0))
    bottom.append(bm_crown.verts.new(d * 0.13))
    lean = 0.035 if i == 6 else 0.012  # point 6 is bent outwards
    top.append(bm_crown.verts.new(d * (0.135 + lean) + Vector((0, 0, heights[i]))))
for i in range(points):
    j = (i + 1) % points
    bm_crown.faces.new((bottom[i], bottom[j], top[j], top[i]))
bmesh.ops.solidify(bm_crown, geom=bm_crown.faces[:], thickness=0.012)
crown_matrix = Matrix.Translation((0.03, -0.1, 1.44)) @ Euler((math.radians(-8), math.radians(14), 0)).to_matrix().to_4x4()
bmesh.ops.transform(bm_crown, matrix=crown_matrix, verts=bm_crown.verts[:])
crown = head_piece("Crown", bm_crown, BRASS)
for poly in crown.data.polygons:  # inside of the can darker
    inside = (Vector(poly.center) - crown_matrix.translation - HEAD_DROP).normalized().dot(poly.normal) < 0
    for li in poly.loop_indices:
        crown.data.color_attributes["Col"].data[li].color = BRASS_DARK if inside else BRASS
pieces.append(crown)

# join the pieces into the body (vertex groups and colours carry over)
bpy.ops.object.select_all(action="DESELECT")
for ob in pieces:
    ob.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
mesh = body.data
mesh.color_attributes.active_color = mesh.color_attributes["Col"]
mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")

material = bpy.data.materials.new("M_RatKing")  # shows the vertex colours in Blender
material.use_nodes = True
material.use_backface_culling = False
nodes = material.node_tree.nodes
shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
attribute = nodes.new("ShaderNodeVertexColor")
attribute.layer_name = "Col"
material.node_tree.links.new(attribute.outputs["Color"], shader.inputs["Base Color"])
shader.inputs["Roughness"].default_value = 0.85
mesh.materials.clear()
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
