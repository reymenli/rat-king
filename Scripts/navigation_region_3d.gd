extends Node3D

@export var camera: Camera3D
@export var rat: SquadRat
@export var target_marker: MeshInstance3D

var click_pending: bool = false
var click_position: Vector2


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if target_marker:
		target_marker.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			click_position = event.position
			click_pending = true


func _physics_process(_delta: float) -> void:
	if not click_pending:
		return

	click_pending = false
	_move_rat_to_click()


func _move_rat_to_click() -> void:
	var ray_start := camera.project_ray_origin(click_position)
	var ray_direction := camera.project_ray_normal(click_position)
	var ray_end := ray_start + ray_direction * 1000.0

	var query := PhysicsRayQueryParameters3D.create(
		ray_start,
		ray_end
	)

	# Detect environment objects on physics layer 1.
	query.collision_mask = 1

	# Prevent the ray from selecting the rat itself.
	query.exclude = [rat.get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return

	var destination: Vector3 = hit["position"]

	rat.command_move_to(destination)

	if target_marker:
		target_marker.global_position = destination + Vector3.UP * 0.05
		target_marker.show()
