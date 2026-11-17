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

var _on := false


func _ready() -> void:
	super()
	prompt_text = "Pull lever"
	animation_player.play(off_animation)


func is_on() -> bool:
	return _on


func interact(player: CharacterBody3D) -> void:
	if player == null or not player.is_in_group("player"):
		return
	_toggle()


func _toggle() -> void:
	_on = not _on
	if lever_sound:
		lever_sound.play()
	if _on:
		animation_player.play(on_animation)
		turned_on.emit()
	else:
		animation_player.play(off_animation)
		turned_off.emit()
