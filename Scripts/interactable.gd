class_name Interactable
extends Node3D

signal hover_started
signal hover_ended

@export_group("Interaction")
@export var interact_distance := 3.0  # how close the player has to be

var hovered := false


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
