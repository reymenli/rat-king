class_name SquadRat
extends CharacterBody3D

signal state_changed(new_state: int)

enum State {
	IDLE,
	FOLLOW,
	STAY,
	MOVE_TO
}

@export var move_speed: float = 3.0
@export var acceleration: float = 12.0
@export var turn_speed: float = 10.0

# Limit how often a moving follow target requests a new path.
@export var repath_interval: float = 0.2
@export var target_move_threshold: float = 0.35

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visuals: Node3D = $Visuals

var state: State = State.IDLE

var _follow_target: Node3D
var _follow_offset: Vector3 = Vector3.ZERO

var _destination: Vector3
var _last_requested_target: Vector3
var _needs_path: bool = false
var _has_requested_path: bool = false
var _repath_time: float = 0.0


func command_follow(
	target: Node3D,
	offset: Vector3 = Vector3.ZERO
) -> void:
	if not is_instance_valid(target):
		return

	_follow_target = target
	_follow_offset = offset

	_needs_path = true
	_has_requested_path = false
	_repath_time = 0.0

	_set_state(State.FOLLOW)


func command_stay() -> void:
	_follow_target = null
	_needs_path = false
	_has_requested_path = false

	# Stop horizontal movement immediately.
	velocity.x = 0.0
	velocity.z = 0.0

	_set_state(State.STAY)


func command_move_to(world_position: Vector3) -> void:
	_follow_target = null
	_destination = world_position

	_needs_path = true
	_has_requested_path = false

	_set_state(State.MOVE_TO)


func _physics_process(delta: float) -> void:

	_repath_time = maxf(_repath_time - delta, 0.0)

	var desired_velocity := Vector3.ZERO

	# Navigation maps synchronize after scene setup.
	if _navigation_ready():
		_update_destination()

		if _has_requested_path:
			desired_velocity = _get_navigation_velocity()

	velocity.x = move_toward(
		velocity.x,
		desired_velocity.x,
		acceleration * delta
	)
	velocity.z = move_toward(
		velocity.z,
		desired_velocity.z,
		acceleration * delta
	)

	move_and_slide()
	_turn_visuals(delta)


func _navigation_ready() -> bool:
	var navigation_map := navigation_agent.get_navigation_map()

	if not navigation_map.is_valid():
		return false

	return (
		NavigationServer3D.map_get_iteration_id(navigation_map) > 0
	)


func _update_destination() -> void:
	match state:
		State.FOLLOW:
			if not is_instance_valid(_follow_target):
				command_stay()
				return

			# World-space offsets keep each rat's slot stable.
			var target_position := (
				_follow_target.global_position + _follow_offset
			)

			var target_moved := (
				target_position.distance_to(_last_requested_target)
				>= target_move_threshold
			)

			if _needs_path or (
				_repath_time <= 0.0 and target_moved
			):
				_request_path(target_position)
				_repath_time = repath_interval

		State.MOVE_TO:
			if _needs_path:
				_request_path(_destination)


func _request_path(world_position: Vector3) -> void:
	navigation_agent.target_position = world_position

	_last_requested_target = world_position
	_needs_path = false
	_has_requested_path = true


func _get_navigation_velocity() -> Vector3:
	if state != State.FOLLOW and state != State.MOVE_TO:
		return Vector3.ZERO

	# Advance the agent's internal path logic once per physics tick.
	var next_position := navigation_agent.get_next_path_position()

	if navigation_agent.is_navigation_finished():
		return Vector3.ZERO

	var direction := next_position - global_position
	direction.y = 0.0

	if direction.length_squared() < 0.0001:
		return Vector3.ZERO

	return direction.normalized() * move_speed




func _turn_visuals(delta: float) -> void:
	var horizontal_velocity := Vector3(
		velocity.x,
		0.0,
		velocity.z
	)

	if horizontal_velocity.length_squared() < 0.01:
		return

	# Assumes the model faces local -Z.
	var target_angle := atan2(
		-horizontal_velocity.x,
		-horizontal_velocity.z
	)

	visuals.rotation.y = lerp_angle(
		visuals.rotation.y,
		target_angle,
		minf(turn_speed * delta, 1.0)
	)


func _set_state(new_state: State) -> void:
	if state == new_state:
		return

	state = new_state
	state_changed.emit(state)
