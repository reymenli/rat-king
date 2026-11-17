class_name Cage
extends Interactable
# Holds rats until the player opens it with a key. Rat children of this node are the prisoners.

@export_group("Nodes")
@export var animation_player: AnimationPlayer


func _ready() -> void:
	super()
	prompt_text = "Open cage (needs a key)"


func interact(player: CharacterBody3D) -> void:
	if player.keys < 1:
		return
	player.keys -= 1
	can_interact = false
	animation_player.play("Unlock")
	animation_player.queue("Open")
	await animation_player.animation_finished  # the lock drops first, then the rats are let out
	var manager := get_tree().get_first_node_in_group("rat_manager") as Rat_Manager
	for child in get_children():
		if child is Rat:
			child.global_position = global_position + global_basis.z * 1.3  # just outside the door
			manager.recruit(child)
