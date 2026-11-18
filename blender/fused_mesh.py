# Shared building blocks for the character scripts (make_rat_king.py, make_scientist.py).
#
# A character is a list of PARTS. Each part is a list of shapes that get fused into one closed
# low-poly surface on their own (voxel remesh, smooth, decimate). Parts are never fused to each
# other, so an arm can't melt into the belly. Each face takes the colour of the shape it is
# closest to, then painted spots and a light-to-dark gradient go on top.
#
# Shapes:
#   ("ball", centre, radii, colour, rotation_degrees)   an ellipsoid
#   ("limb", start, start_radius, end, end_radius, colour)   a tapered capsule (round ends)
#   ("cone", start, start_radius, end, end_radius, colour)   the same with flat ends (a coat hem)

import math

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector


def colour(hex_code):
    def linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(linear(int(hex_code[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)


def _ball_matrix(shape):
    _, centre, radii, _, rot = shape
    r = Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
    return Matrix.Translation(centre) @ r @ Matrix.Diagonal((*radii, 1.0))


def shape_colour(shape):
    return shape[3] if shape[0] == "ball" else shape[5]


def shape_distance(shape, p):
    """Rough signed distance from p to the shape's surface."""
    if shape[0] == "ball":
        return ((_ball_matrix(shape).inverted() @ p).length - 1.0) * min(shape[2])
    _, a, ra, b, rb, _ = shape
    a, b = Vector(a), Vector(b)
    ab = b - a
    raw = (p - a).dot(ab) / ab.length_squared
    t = max(0.0, min(1.0, raw))
    past_end = 1.0 if shape[0] == "cone" and not 0.0 <= raw <= 1.0 else 0.0
    return (p - (a + ab * t)).length - (ra + (rb - ra) * t) + past_end


def _lay_out(bm, shapes):
    for shape in shapes:
        if shape[0] == "ball":
            bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=1.0, matrix=_ball_matrix(shape))
            continue
        _, a, ra, b, rb, _ = shape
        a, b = Vector(a), Vector(b)
        frame = Matrix.Translation((a + b) / 2) @ (b - a).to_track_quat("Z", "Y").to_matrix().to_4x4()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=ra, radius2=rb, depth=(b - a).length, matrix=frame)
        if shape[0] == "limb":
            for centre, radius in ((a, ra), (b, rb)):
                bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=radius, matrix=Matrix.Translation(centre))


def _apply(ob, kind, **settings):
    mod = ob.modifiers.new(kind, kind)
    for key, value in settings.items():
        setattr(mod, key, value)
    with bpy.context.temp_override(object=ob, active_object=ob):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def fused_part(name, shapes, faces, voxel=0.012, paint=(), height=1.6):
    """One closed low-poly surface from `shapes`, vertex coloured, flat shaded."""
    bm = bmesh.new()
    _lay_out(bm, shapes)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    _apply(ob, "REMESH", mode="VOXEL", voxel_size=voxel)
    _apply(ob, "SMOOTH", factor=0.6, iterations=5)
    if len(mesh.polygons) > faces:
        _apply(ob, "DECIMATE", ratio=faces / len(mesh.polygons))
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for poly in mesh.polygons:
        poly.use_smooth = False
        p = Vector(poly.center)
        rgba = shape_colour(min(shapes, key=lambda s: shape_distance(s, p)))
        for centre, radius, spot in paint:
            if (p - Vector(centre)).length < radius:
                rgba = spot
        shade = (0.74 + 0.26 * min(1.0, p.z / height)) * (0.86 + 0.14 * max(0.0, poly.normal.z))
        for li in poly.loop_indices:
            col.data[li].color = (rgba[0] * shade, rgba[1] * shade, rgba[2] * shade, 1.0)
    return ob


def hard_piece(name, build, rgba):
    """A small solid piece (glasses, crown, teeth). `build(bm)` adds its geometry."""
    bm = bmesh.new()
    build(bm)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for item in col.data:
        item.color = rgba
    for poly in mesh.polygons:
        poly.use_smooth = False
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def disc(bm, centre, radius, thickness, segments=16):
    """A flat round disc facing -Y (a lens or a frame)."""
    frame = Matrix.Translation(centre) @ Euler((math.radians(90), 0, 0)).to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=thickness, matrix=frame)


def box(bm, centre, size, rot=(0, 0, 0)):
    r = Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(centre) @ r @ Matrix.Diagonal((*size, 1)))


def stick(bm, a, b, radius, segments=6):
    a, b = Vector(a), Vector(b)
    frame = Matrix.Translation((a + b) / 2) @ (b - a).to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius * 0.7, depth=(b - a).length, matrix=frame)


def join(objects, name):
    """Joins objects into one (vertex groups and colours carry over) and gives it a vertex colour material."""
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    body = objects[0]
    body.name = body.data.name = name
    mesh = body.data
    mesh.color_attributes.active_color = mesh.color_attributes["Col"]
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")
    material = bpy.data.materials.new("M_" + name)
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
    return body
