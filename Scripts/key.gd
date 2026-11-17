extends Area3D
# Pickup. Walking into it adds one key to the player.

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	rotate_y(delta * 2.0)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.keys += 1
		queue_free()
