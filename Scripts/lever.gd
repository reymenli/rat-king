class_name Lever
extends Interactable

signal turned_on
signal turned_off

@export_group("Nodes")
@export var animation_player: AnimationPlayer
@export var lever_sound: AudioStreamPlayer3D

@export_group("Animations")
@export var on_animation: StringName = &"On"
@export var off_animation: StringName = &"Off"

@export_group("Highlight")
@export var highlight_enabled := true
@export var highlight_material: Material  # leave empty for a default glow
@export var prompt: Node3D  # optional, e.g. a Label3D, only visible while looked at

var _on := false
var _meshes: Array[MeshInstance3D] = []
var _highlight: Material


func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)

	_highlight = highlight_material if highlight_material else _make_default_highlight()
	if prompt:
		prompt.visible = false

	hover_started.connect(_apply_hover.bind(true))
	hover_ended.connect(_apply_hover.bind(false))

	animation_player.play(off_animation)
	
	print("Lever '%s' found %d meshes" % [name, _meshes.size()])


func is_on() -> bool:
	return _on


func interact(player: CharacterBody3D) -> void:
	if player == null or not player.is_in_group("player"):
		return
	_toggle()


func _toggle() -> void:
	_on = not _on
	lever_sound.play()
	if _on:
		animation_player.play(on_animation)
		turned_on.emit()
	else:
		animation_player.play(off_animation)
		turned_off.emit()


func _apply_hover(value: bool) -> void:
	if highlight_enabled:
		for mesh in _meshes:
			mesh.material_overlay = _highlight if value else null
	if prompt:
		prompt.visible = value


func _make_default_highlight() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.85, 0.4, 0.35)
	return material
