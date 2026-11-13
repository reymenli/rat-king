extends Node3D

@export_group("Nodes")
@export var animation_player: AnimationPlayer

@export_group("Wiring")
@export var plate: PressurePlate

@export_group("Animations")
@export var open_animation: StringName = &"Open"
@export var close_animation: StringName = &"Close"


func _ready() -> void:
	if plate == null:
		push_warning("Door '%s' has no plate assigned." % name)
		return
	plate.pressed.connect(open)
	plate.released.connect(close)


func open() -> void:
	animation_player.play(open_animation)


func close() -> void:
	animation_player.play(close_animation)
