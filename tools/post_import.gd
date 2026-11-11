@tool
extends EditorScenePostImport
# Runs on every Blender-exported GLB that points at it in its .import file.
# 1. Kit pieces are painted with vertex colours, so switch that on for every material.
# 2. Looping clips (idle, run) are marked as looping.

const LOOPING_CLIPS := ["Idle", "Run"]

func _post_import(scene: Node) -> Object:
	_fix(scene)
	return scene

func _fix(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh:
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s)
				if mat is BaseMaterial3D:
					(mat as BaseMaterial3D).vertex_color_use_as_albedo = true
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		for clip in player.get_animation_list():
			if clip in LOOPING_CLIPS:
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for child in node.get_children():
		_fix(child)
