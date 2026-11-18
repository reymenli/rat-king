extends CharacterBody3D
# Script for character

signal command_issued(point: Vector3, collider: Object)
signal keys_changed(count: int)
signal hover_changed(target: Interactable)
signal got_hurt

# node references added in inspector
@export_group("Nodes")
@export var camera_pivot: Node3D
@export var spring_arm: SpringArm3D
@export var camera: Camera3D
@export var aim_ray: RayCast3D
@export var mesh: Node3D
@export var anim: AnimationPlayer
@export var aim_marker: Node3D
@export var command_wheel : Control

@export_group("Movement")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var acceleration := 30.0
@export var turn_speed := 12.0

@export_group("Camera")
@export var mouse_sensitivity := 0.005
@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_vertical_angle := deg_to_rad(-70.0)
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_vertical_angle := deg_to_rad(60.0)
@export var min_zoom := 1.5
@export var max_zoom := 6.0
## Spring arm length change per scroll notch.
@export var zoom_step := 0.5
## How far the camera sits to the right of the character (over the shoulder).
@export var shoulder_offset := 0.75
@export var default_fov := 70.0

@export_group("Aiming")
@export var aim_range := 100.0
## Camera distance, field of view and mouse speed while right click is held.
@export var aim_zoom := 2.0
@export var aim_fov := 48.0
@export var aim_sensitivity_scale := 0.6
## Interactables this close can be used without aiming at them.
@export var reach := 1.8

# updated every physics frame
var has_aim := false
var aim_point := Vector3.ZERO
var aim_collider: Object = null
var aiming := false
var first_person := false
var hovered: Interactable = null
var keys := 0:
	set(value):
		keys = value
		keys_changed.emit(keys)

var _zoom := 3.2
# Two samples of "standing on solid ground", so a hazard sends the player back to
# a spot that is a moment old and safely outside the hazard.
var _safe_now := Vector3.ZERO
var _safe_before := Vector3.ZERO
var _safe_timer := 0.0

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.add_excluded_object(get_rid())
	spring_arm.position.x = shoulder_offset
	spring_arm.spring_length = _zoom
	camera.fov = default_fov
	aim_ray.add_exception(self)
	aim_ray.target_position = Vector3(0, 0, -aim_range)
	aim_ray.collision_mask = 0b101 # world and rats
	aim_ray.collide_with_areas = true # interactables are areas
	aim_ray.enabled = true
	reset_safe_spot()

# Call after moving the player somewhere new, so a hazard cannot send them back to the old place.
func reset_safe_spot() -> void:
	_safe_now = global_position
	_safe_before = global_position

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

	var sprinting := Input.is_action_pressed("sprint") and not aiming
	var speed := sprint_speed if sprinting else walk_speed
	var target := direction * speed

	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	# While aiming the character faces where the camera looks, like GTA.
	var facing := -camera.global_basis.z if (aiming or first_person) else direction
	_face_direction(Vector3(facing.x, 0.0, facing.z), delta)
	move_and_slide()
	_update_camera(delta)
	_update_aim()
	_update_hover()
	_update_safe_spot(delta)
	_animate(direction, sprinting)

func _update_camera(delta: float) -> void:
	aiming = Input.is_action_pressed("rmb") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var length := 0.0 if first_person else (aim_zoom if aiming else _zoom)
	var blend := 1.0 - exp(-12.0 * delta)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, length, blend)
	spring_arm.position.x = lerpf(spring_arm.position.x, 0.0 if first_person else shoulder_offset, blend)
	camera.fov = lerpf(camera.fov, aim_fov if aiming else default_fov, blend)
	if mesh:
		mesh.visible = not first_person

# Casts a ray along a line through the crosshair
func _update_aim() -> void:
	# Start level with the character so things between the camera and the player are skipped.
	var cam := camera.global_transform
	aim_ray.global_transform = Transform3D(cam.basis, cam.origin - cam.basis.z * spring_arm.get_hit_length())
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

# The rat under the crosshair, if any.
func aimed_rat() -> Rat:
	return aim_collider as Rat if is_instance_valid(aim_collider) else null

# The interactable under the crosshair, or failing that the closest one in reach.
func _update_hover() -> void:
	var target := _interactable_of(aim_collider as Node) if is_instance_valid(aim_collider) else null
	if target and global_position.distance_to(aim_point) > target.interact_distance:
		target = null
	if target == null:
		var best := reach
		for node in get_tree().get_nodes_in_group("interactables"):
			var other := node as Interactable
			var distance := global_position.distance_to(other.global_position)
			if other.can_interact and distance < best:
				best = distance
				target = other
	if target == hovered:
		return
	if is_instance_valid(hovered):
		hovered.set_hovered(false)
	hovered = target
	if hovered:
		hovered.set_hovered(true)
	hover_changed.emit(hovered)

func _interactable_of(node: Node) -> Interactable:
	while node:
		if node is Interactable:
			return node if (node as Interactable).can_interact else null
		node = node.get_parent()
	return null

func _update_safe_spot(delta: float) -> void:
	_safe_timer += delta
	if _safe_timer < 0.3 or not is_on_floor():
		return
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is Rat_Structure:
			return # a bridge can vanish, so it is not a safe place to return to
	_safe_timer = 0.0
	_safe_before = _safe_now
	_safe_now = global_position

# Called by hazards. The Rat King cannot faint, so they are put back on safe ground.
# shortcut: a teleport instead of a physics knockback, so pits and flat hazards share one path.
func hurt() -> void:
	global_position = _safe_before
	_safe_now = _safe_before
	velocity = Vector3(0, 3.0, 0)
	_play("Ow")
	got_hurt.emit()

# Handles mouse input
func _unhandled_input(event: InputEvent) -> void:
	# Click to grab the mouse again (after alt-tab). Esc is the pause menu (main_menu.gd).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and aimed_rat():
			get_tree().get_first_node_in_group("rat_manager").toggle_selected(aimed_rat())
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event.is_action_pressed("interact") and is_instance_valid(hovered):
		_play("Interact")
		hovered.interact(self)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		first_person = not first_person
	elif event is InputEventMouseMotion:
		var sensitivity := mouse_sensitivity * (aim_sensitivity_scale if aiming else 1.0)
		camera_pivot.rotation.y = wrapf(camera_pivot.rotation.y - event.relative.x * sensitivity, 0.0, TAU)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * sensitivity, min_vertical_angle, max_vertical_angle)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + zoom_step, min_zoom, max_zoom)

func _face_direction(direction: Vector3, delta: float) -> void:
	if mesh == null or direction.is_zero_approx():
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	mesh.rotation.y = lerp_angle(mesh.rotation.y, target_yaw, turn_speed * delta)

func _animate(direction: Vector3, sprinting: bool) -> void:
	if anim == null or anim.current_animation in ["Ow", "Interact", "Command"]:
		return # one-shot clips finish on their own
	if not is_on_floor():
		_play("Jump")
	elif direction.is_zero_approx():
		_play("Idle")
	else:
		_play("Run" if sprinting else "Walk")

# The pointing animation, played when a command is given.
func gesture() -> void:
	_play("Command")

func _play(clip: StringName) -> void:
	if anim and anim.has_animation(clip) and anim.current_animation != clip:
		anim.play(clip, 0.15)
