extends Area3D
# Plays its lines in the dialogue box the first time the player walks through it.

@export var speaker := "Rat King"
@export var lines: PackedStringArray


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		(get_tree().get_first_node_in_group("hud") as HUD).say(speaker, lines)
		queue_free()
