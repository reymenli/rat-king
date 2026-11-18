extends Area3D
# The cheese on the hideout table. It appears once the player has taken it in the final zone.
# Walking up to it shows the win screen, every time, so the player can keep playing or leave.

@export var cheese: Node3D


func _ready() -> void:
	var manager := get_tree().get_first_node_in_group("level_manager") as Level_Manager
	if cheese:
		cheese.visible = manager != null and manager.has_cheese
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var manager := get_tree().get_first_node_in_group("level_manager") as Level_Manager
	if body.is_in_group("player") and manager and manager.has_cheese:
		manager.won = true
		manager.show_win()
