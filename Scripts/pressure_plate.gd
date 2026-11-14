class_name PressurePlate
extends Node3D

signal pressed
signal released

@export_group("Nodes")
@export var pressed_sound: AudioStreamPlayer3D
@export var unpressed_sound: AudioStreamPlayer3D
@export var animation_player: AnimationPlayer
@export var area: Area3D

@export_group("Plate Settings")
@export var rats_needed: int = 10

var bodies_on_plate := 0

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	animation_player.play("Release")

func is_pressed() -> bool:
	return bodies_on_plate >= rats_needed

func _is_valid(body: Node3D) -> bool:
	return body.is_in_group("rats")

func _on_body_entered(body: Node3D) -> void:
	if not _is_valid(body):
		return

	bodies_on_plate += 1
	if bodies_on_plate == rats_needed:
		animation_player.play("Press")
		pressed_sound.play()
		pressed.emit()


func _on_body_exited(body: Node3D) -> void:
	if not _is_valid(body):
		return

	bodies_on_plate -= 1
	if bodies_on_plate == rats_needed - 1:
		animation_player.play("Release")
		unpressed_sound.play()
		released.emit()
