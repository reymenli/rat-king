extends Node3D

@onready var camera: Camera3D = $"../player/CameraPivot/SpringArm3D/Camera3D"
@onready var rat: CharacterBody3D = $"../Rats"
@onready var player: CharacterBody3D = $"../player"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			rat.stay()
			#_click_to_move(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			rat.follow(player)
			print("CLICLEDKOASHIOD")


func _click_to_move(screen_pos: Vector2) -> void:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 1000.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [rat.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return
	rat.move_to(hit["position"])
