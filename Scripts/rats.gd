class_name Rat
extends CharacterBody3D

signal state_changed(new_state: int)

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var visuals: Node3D = $Visuals
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var animation_player: AnimationPlayer = $Visuals/SK_Rat_E/AnimationPlayer

var _follow_player: Node3D

var speed = 3.0
var turn_speed = 10.0
const FOLLOW_DISTANCE := 1.0

enum State {
	FOLLOW,
	STAY,
	MOVE_TO
}

var state: State = State.STAY


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if state == State.MOVE_TO:
		animation_player.play("Run")
		_process_move_to()
	
	if state == State.FOLLOW and velocity.x != 0.0:
		animation_player.play("Run")
		_process_follow()
	elif state == State.FOLLOW and velocity.x == 0.0:
		animation_player.play("Idle")
		_process_follow()
	
	if state == State.STAY:
		animation_player.play("Idle")
		velocity.x = 0.0
		velocity.z = 0.0
		
	move_and_slide()
	_face_velocity(delta)

func move_to(position: Vector3) -> void:
	navigation_agent_3d.target_position = position
	_set_state(State.MOVE_TO)
	
func stay() -> void:
	_set_state(State.STAY)
	
func follow(target: Node3D) -> void:
	_follow_player = target # We get the player node and store it as a variable. 
	_set_state(State.FOLLOW)

func _process_move_to() -> void:
	if navigation_agent_3d.is_navigation_finished(): 
		velocity.x = 0.0
		velocity.z = 0.0
		_set_state(State.STAY)
		return
		
	var next_path = navigation_agent_3d.get_next_path_position()
	var direction: Vector3 = next_path - global_position # Where we want to go Minus where we are right now in a 3d vector.
	direction.y = 0.0
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
func _process_follow() -> void:
	if not is_instance_valid(_follow_player):
		_set_state(State.STAY)
		return
	
	navigation_agent_3d.target_position = _follow_player.global_position
	 
	var to_target := _follow_player.global_position - global_position
	to_target.y = 0.0
	if to_target.length() < FOLLOW_DISTANCE: # So rats keep a distance away when following player
		velocity.x = 0.0
		velocity.z = 0.0
		return
	
	if navigation_agent_3d.is_navigation_finished(): # Stay where you are, but you're still in follow mode
		velocity.x = 0.0
		velocity.z = 0.0
		
	var next_path = navigation_agent_3d.get_next_path_position()
	var direction: Vector3 = next_path - global_position # Where we want to go Minus where we are right now in a 3d vector.
	direction.y = 0.0
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
func _face_velocity(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 0.1: # Not moving a lot
		return
	var target_angle = atan2(flat.x, flat.z)
	visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, turn_speed * delta)
	collision_shape_3d.rotation.y = lerp_angle(collision_shape_3d.rotation.y, target_angle, turn_speed * delta)

func _set_state(new_state: State) -> void:
	if state == new_state:
		return

	state = new_state
	state_changed.emit(state)
