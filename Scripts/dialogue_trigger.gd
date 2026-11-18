extends Area3D
# Plays its lines in the dialogue box the first time the player walks through it.
# Played triggers are remembered on the Level_Manager, so coming back to an area doesn't replay them.

@export var speaker := "Rat King"
@export var lines: PackedStringArray


func _ready() -> void:
	if _key() in _seen():
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func _key() -> String:
	return "%s/%s" % [owner.name if owner else "", name]


func _seen() -> Dictionary:
	var manager := get_tree().get_first_node_in_group("level_manager")
	return manager.dialogue_seen if manager else {}


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_seen()[_key()] = true
		(get_tree().get_first_node_in_group("hud") as HUD).say(speaker, lines)
		queue_free()
