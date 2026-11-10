extends CharacterBody3D
# Script for character

signal command_issued(point: Vector3, collider: Object)

# node references added in inspector
@export_group("Nodes")
@export var camera_pivot: Node3D
@export var spring_arm: SpringArm3D
@export var camera: Camera3D
@export var aim_ray: RayCast3D
@export var mesh: Node3D
@export var anim: AnimationPlayer
@export var aim_marker: Node3D
# add later

@export_group("Movement")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var acceleration := 30.0
@export var turn_speed := 12.0

@export_group("Camera")
@export var mouse_sensitivity := 0.005
@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_vertical_angle := deg_to_rad(-80.0)
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_vertical_angle := PI / 4.0
@export var min_zoom := 1.5
@export var max_zoom := 8.0
## Spring arm length change per scroll notch.
@export var zoom_step := 0.5

@export_group("Aiming")
@export var aim_range := 100.0

# updated every physics frame
var has_aim := false
var aim_point := Vector3.ZERO
var aim_collider: Object = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.add_excluded_object(get_rid())
	aim_ray.add_exception(self)
	aim_ray.target_position = Vector3(0, 0, -aim_range)
	aim_ray.enabled = true

func _physics_process(delta: float) -> void:
	# jumping and falling
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	
	#walking relative to camera
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y).normalized()
	direction = direction.rotated(Vector3.UP, camera.global_rotation.y)
	
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target := direction * speed
	
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	
	_face_direction(direction, delta)
	move_and_slide()
	_update_aim()

# Casts a ray along a line through the crosshair
func _update_aim() -> void:
	aim_ray.global_transform = Transform3D(camera.global_basis, spring_arm.global_position)
	aim_ray.force_raycast_update()

	has_aim = aim_ray.is_colliding()
	if has_aim:
		aim_point = aim_ray.get_collision_point()
		aim_collider = aim_ray.get_collider()
	else:
		aim_point = aim_ray.to_global(aim_ray.target_position)
		aim_collider = null
	if aim_marker:
		aim_marker.global_position = aim_point
		aim_marker.visible = has_aim


# Handles mouse input
func _unhandled_input(event: InputEvent) -> void:
	#Esc to unlock mouse and click to enter game again
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
		
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
		
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
		
	if event.is_action_pressed("command_wheel"):
		issue_command()
		return
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotation.y = wrapf(camera_pivot.rotation.y - event.relative.x * mouse_sensitivity, 0.0, TAU)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * mouse_sensitivity, min_vertical_angle, max_vertical_angle)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clampf(spring_arm.spring_length - zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clampf(spring_arm.spring_length + zoom_step, min_zoom, max_zoom)
	
func _face_direction(direction: Vector3, delta: float) -> void:
	if mesh == null or direction.is_zero_approx():
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	mesh.rotation.y = lerp_angle(mesh.rotation.y, target_yaw, turn_speed * delta)	

func issue_command() -> void:
	# Nothing under the crosshair (sky, out of range): don't send a point
	if not has_aim:
		return
	command_issued.emit(aim_point, aim_collider)
	print(aim_point, aim_collider)
