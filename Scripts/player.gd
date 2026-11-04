extends CharacterBody3D
# Script for character

signal command_issued(point: Vector3, collider: Object)

@export_group("Movement")
@export var speed := 5.0
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
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	#if Input.is_action_just_pressed("jump") and is_on_floor():
		#velocity.y = JUMP_VELOCITY

	move_and_slide()
	
