# Adds the structure clips (Brace, Form, HopOut) to the three squad rats in rat-king-lab.blend,
# saves the .blend and re-exports assets/models/characters/rats/SK_Rat_{E,F,G}.glb.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b blender/rat-king-lab.blend -P blender/make_rat_clips.py
# Safe to rerun: existing Brace/Form/HopOut tracks and actions are replaced.
import math
import os

import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(bpy.data.filepath)))
OUT = os.path.join(ROOT, "assets", "models", "characters", "rats")
RATS = ["E", "F", "G"]

# Poses: bone -> (rotation in degrees about the WORLD x, y, z axes, offset in metres in world space).
# The rat faces -Y with Z up. +X rotation swings legs back and dips the spine/head down,
# and lifts the tail. Bones not listed stay at rest.
REST = {}
CROUCH = {  # flat, wide, braced to carry weight
    "hips": ((0, 0, 0), (0, 0, -0.035)),
    "spine": ((4, 0, 0), (0, 0, 0)),
    "head": ((-12, 0, 0), (0, 0, 0)),
    "leg_f.L": ((-20, -28, 0), (0, 0, 0)), "leg_f.R": ((-20, 28, 0), (0, 0, 0)),
    "leg_r.L": ((25, -28, 0), (0, 0, 0)), "leg_r.R": ((25, 28, 0), (0, 0, 0)),
    "foot_f.L": ((10, 0, 0), (0, 0, 0)), "foot_f.R": ((10, 0, 0), (0, 0, 0)),
    "foot_r.L": ((-15, 0, 0), (0, 0, 0)), "foot_r.R": ((-15, 0, 0), (0, 0, 0)),
    "ear.L": ((-35, 0, 0), (0, 0, 0)), "ear.R": ((-35, 0, 0), (0, 0, 0)),
    "tail1": ((-8, 0, 0), (0, 0, 0)), "tail2": ((4, 0, 0), (0, 0, 0)), "tail3": ((4, 0, 0), (0, 0, 0)),
}
def shifted(pose, bone, rot=(0, 0, 0), loc=(0, 0, 0)):
    """Copy of pose with an extra rotation/offset added to one bone."""
    p = dict(pose)
    r, l = p.get(bone, ((0, 0, 0), (0, 0, 0)))
    p[bone] = (tuple(a + b for a, b in zip(r, rot)), tuple(a + b for a, b in zip(l, loc)))
    return p
BREATHE = shifted(shifted(shifted(CROUCH, "hips", loc=(0, 0, -0.006)), "head", rot=(4, 0, 0)), "tail3", rot=(0, 0, 10))
BREATHE = shifted(BREATHE, "tail2", rot=(0, 0, 6))
TUCK = {  # mid-air: legs pulled in, tail streaming back
    "spine": ((-10, 0, 0), (0, 0, 0)), "head": ((-8, 0, 0), (0, 0, 0)),
    "leg_f.L": ((-50, 0, 0), (0, 0, 0)), "leg_f.R": ((-50, 0, 0), (0, 0, 0)),
    "leg_r.L": ((55, 0, 0), (0, 0, 0)), "leg_r.R": ((55, 0, 0), (0, 0, 0)),
    "ear.L": ((-45, 0, 0), (0, 0, 0)), "ear.R": ((-45, 0, 0), (0, 0, 0)),
    "tail1": ((10, 0, 0), (0, 0, 0)), "tail2": ((-5, 0, 0), (0, 0, 0)), "tail3": ((-5, 0, 0), (0, 0, 0)),
}
def at(pose, loc):
    """pose with the hips moved to loc (world offset from rest), keeping its other bones."""
    p = dict(pose)
    r, _ = p.get("hips", ((0, 0, 0), (0, 0, 0)))
    p["hips"] = (r, loc)
    return p
SQUASH = shifted(CROUCH, "hips", loc=(0, 0, -0.015))
SQUASH = shifted(shifted(SQUASH, "head", rot=(10, 0, 0)), "tail1", rot=(-6, 0, 0))

# Clips at 24 fps: (frame, pose). Brace loops (first == last). Form lands in Brace's first pose,
# HopOut starts from it and lands at rest, so the clips chain without pops.
CLIPS = {
    "Brace": [(1, CROUCH), (25, BREATHE), (49, CROUCH)],
    # Hops in from 0.3 m behind and below, arcs up and lands braced.
    "Form": [(1, at(TUCK, (0, 0.3, -0.05))), (6, at(TUCK, (0, 0.15, 0.12))),
             (11, at(TUCK, (0, 0.02, 0.06))), (14, SQUASH), (18, CROUCH)],
    "HopOut": [(1, CROUCH), (4, SQUASH), (9, at(TUCK, (0, -0.08, 0.16))),
               (14, at(TUCK, (0, -0.16, 0.05))), (17, at(REST, (0, -0.2, -0.015))), (20, at(REST, (0, -0.2, 0)))],
}


def apply_pose(rig, pose):
    for pb in rig.pose.bones:
        rot, loc = pose.get(pb.name, ((0, 0, 0), (0, 0, 0)))
        rest = pb.bone.matrix_local.to_3x3()
        world = Euler([math.radians(a) for a in rot], "XYZ").to_matrix()
        pb.rotation_mode = "XYZ"
        # A world-axis rotation expressed in the bone's own rest frame.
        pb.rotation_euler = (rest.inverted() @ world @ rest).to_euler("XYZ")
        pb.location = rest.inverted() @ Vector(loc)
        pb.scale = (1, 1, 1)


def make_clip(rig, name, keys):
    act_name = name if rig.name == "RIG_Rat_E" else f"{rig.name}_{name}"
    old = bpy.data.actions.get(act_name)
    if old:
        bpy.data.actions.remove(old)
    ad = rig.animation_data or rig.animation_data_create()
    act = bpy.data.actions.new(act_name)
    act.use_fake_user = True
    ad.action = act
    for frame, pose in keys:
        apply_pose(rig, pose)
        for pb in rig.pose.bones:
            for path in ("location", "rotation_euler", "scale"):
                pb.keyframe_insert(path, frame=frame, group=pb.name)
    ad.action = None
    track = ad.nla_tracks.get(name) or ad.nla_tracks.new()
    track.name = name
    for s in list(track.strips):
        track.strips.remove(s)
    strip = track.strips.new(name, keys[0][0], act)
    strip.name = name
    return act


def export(letter):
    rig = bpy.data.objects[f"RIG_Rat_{letter}"]
    mesh = bpy.data.objects[f"SK_Rat_{letter}_Rigged"]
    old_loc = rig.location.copy()
    rig.location = (0, 0, 0)  # README: move the piece to the origin before exporting
    bpy.context.scene.frame_set(0)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in (rig, mesh):
        ob.hide_set(False)
        ob.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, f"SK_Rat_{letter}.glb"), export_format="GLB",
        use_selection=True, export_yup=True, export_animations=True,
        export_animation_mode="NLA_TRACKS", export_vertex_color="MATERIAL", export_force_sampling=True)
    rig.location = old_loc


bpy.context.scene.render.fps = 24
for letter in RATS:
    rig = bpy.data.objects[f"RIG_Rat_{letter}"]
    for name, keys in CLIPS.items():
        make_clip(rig, name, keys)
    # Rest pose so the first track (Idle) still decides the exported rest.
    apply_pose(rig, REST)
    export(letter)
bpy.ops.wm.save_mainfile()
print("RAT CLIPS DONE")
