extends Area3D
# The cheese in the final zone. Touching it takes it (Level_Manager.has_cheese) and it
# shows up on the hideout table (trophy_cheese.gd).

@export var cheese: Node3D


func _ready() -> void:
	if _manager() and _manager().has_cheese and cheese:
		cheese.hide()
	body_entered.connect(_on_body_entered)


func _manager() -> Level_Manager:
	return get_tree().get_first_node_in_group("level_manager") as Level_Manager


func _on_body_entered(body: Node3D) -> void:
	var manager := _manager()
	if not body.is_in_group("player") or manager == null or manager.has_cheese:
		return
	manager.has_cheese = true
	if cheese:
		cheese.hide()
	manager.hud.say("Rat King", ["got it. GOT IT. back to the hideout, boys."])
