class_name Interactable
extends Node3D

signal hover_started
signal hover_ended

@export_group("Interaction")
@export var interact_distance := 3.0  # how close the player has to be
@export var prompt_text := "Use"  # shown in the HUD as "E  <prompt_text>"

@export_group("Highlight")
@export var highlight_enabled := true
@export var highlight_material: Material  # leave empty for a default glow

var hovered := false
var can_interact := true  # set false once there is nothing left to do (e.g. an opened cage)

var _meshes: Array[MeshInstance3D] = []
var _highlight: Material


func _init() -> void:
	add_to_group("interactables") # lets the player find the nearest one without aiming


# Scripts that extend this and have their own _ready must call super().
func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	_highlight = highlight_material if highlight_material else _make_default_highlight()
	hover_started.connect(_apply_hover.bind(true))
	hover_ended.connect(_apply_hover.bind(false))


func interact(_player: CharacterBody3D) -> void:
	pass


# The player calls this when its ray starts / stops pointing at this object.
func set_hovered(value: bool) -> void:
	if value == hovered:
		return
	hovered = value
	if hovered:
		hover_started.emit()
	else:
		hover_ended.emit()


func _apply_hover(value: bool) -> void:
	if highlight_enabled:
		for mesh in _meshes:
			mesh.material_overlay = _highlight if value else null


func _make_default_highlight() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.85, 0.4, 0.35)
	return material
