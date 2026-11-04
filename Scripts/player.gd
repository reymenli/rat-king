extends CharacterBody3D
# Script for character

signal command_issued(point: Vector3, collider: Object)

@export_group("Movement")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var acceleration := 30.0

@export_group("Camera")
@export var mouse_sensitivity := 0.003
@export_range(-89.0, 0.0) var min_pitch_deg := -70.0
@export_range(0.0, 89.0) var max_pitch_deg := 60

@export_group("Aiming")
@export var aim_range := 100.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var aim_ray: RayCast3D = $RayCast3D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

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
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target := direction * speed
	
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	move_and_slide()
	_update_aim()
	
func _update_aim() -> void:
	aim_ray.global_transform = camera.global_transform
	aim_ray.force_raycast_update()
	
	has_aim = aim_ray.is_colliding()
	if has_aim:
		aim_point = aim_ray.get_collision_point()
		aim_collider = aim_ray.get_collider()
	else: 
		aim_point = camera.global_position - camera.global_basis.z * aim_range
		aim_collider = null
