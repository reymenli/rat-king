extends Area3D
# The final zone cutscene. Walking up to the scientist: he gloats, then the last rat runs out
# from behind him and joins the crew, which makes 100 and unlocks Ratazord.
# Also restores the room on a return visit (rat already joined, scientist already gone).

@export var last_rat: Rat


func _ready() -> void:
	var manager := _manager()
	if manager and manager.last_rat_joined and is_instance_valid(last_rat):
		last_rat.queue_free()
	if manager and manager.scientist_gone:
		for scientist in get_tree().get_nodes_in_group("scientist"):
			scientist.queue_free()
	body_entered.connect(_on_body_entered)


func _manager() -> Level_Manager:
	return get_tree().get_first_node_in_group("level_manager") as Level_Manager


func _on_body_entered(body: Node3D) -> void:
	var manager := _manager()
	if not body.is_in_group("player") or manager == null or manager.last_rat_joined or manager.scientist_gone:
		return
	manager.last_rat_joined = true
	manager.hud.say("Scientist", [
		"STOP right there, K-1! nobody gets past ME. nobody touches the cheese!"])
	if not is_instance_valid(last_rat):
		return
	last_rat.process_mode = Node.PROCESS_MODE_INHERIT
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(last_rat):
		return
	last_rat.move_to(body.global_position)  # scurries out from behind his legs
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(last_rat):
		manager.rat_manager.recruit(last_rat)
	manager.hud.say("Rat King", [
		"huh? one of my guys was hidin back there the whole time. c'mere, kid.",
		"that makes a hundred. ok four-eyes, time for somethin BIG. [Q, Ratazord]"])
