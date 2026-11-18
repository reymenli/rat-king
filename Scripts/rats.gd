class_name Rat
extends CharacterBody3D

signal state_changed(new_state: int)

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var visuals: Node3D = $Visuals
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var animation_player: AnimationPlayer = $Visuals/SK_Rat_E/AnimationPlayer

var _follow_player: Node3D

var speed = 5.5  # a little faster than the player, so the line can keep up
var turn_speed = 10.0
const FOLLOW_DISTANCE := 1.0
var follow_distance := FOLLOW_DISTANCE  # how close to its target a following rat stops
const ARRIVE_DISTANCE := 0.3  # how close counts as "there" for Go To
const STUCK_TIME := 1.0  # seconds of getting nowhere before the rat gives up
const REJOIN_DELAY := 10.0  # seconds a fainted rat is gone for

enum State {
	FOLLOW,
	STAY,
	MOVE_TO,
	FAINTED
}

var state: State = State.STAY

var _marker: Label3D  # yellow arrow over the head while the rat is tagged

var _steering := false  # true on frames where the rat is trying to get somewhere
var _stuck_time := 0.0


func set_selected(value: bool) -> void:
	if _marker == null:
		_marker = Label3D.new()
		_marker.text = "▼"
		_marker.font_size = 64
		_marker.outline_size = 12
		_marker.modulate = Color(1.0, 0.82, 0.25)
		_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marker.no_depth_test = true
		_marker.position.y = 0.55
		add_child(_marker)
	_marker.visible = value

func _physics_process(delta: float) -> void:
	if state == State.FAINTED:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta

	if state == State.MOVE_TO:
		_process_move_to()
	elif state == State.FOLLOW:
		_process_follow()
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	var moving := Vector2(velocity.x, velocity.z).length() > 0.1
	animation_player.play("Run" if moving else "Idle")
	var before := global_position
	move_and_slide()
	_face_velocity(delta)
	_check_stuck(global_position.distance_to(before) / delta, delta)

# A rat that wants to move but cannot (closed door, ledge, pit, another rat in the way)
# stops if it was sent somewhere, or pops up next to the player if it was following.
func _check_stuck(real_speed: float, delta: float) -> void:
	_stuck_time = _stuck_time + delta if (_steering and real_speed < speed * 0.3) else 0.0
	_steering = false
	if _stuck_time < STUCK_TIME:
		return
	_stuck_time = 0.0
	if state == State.MOVE_TO:
		_set_state(State.STAY)
	elif state == State.FOLLOW:
		global_position = _follow_player.global_position + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))

func move_to(position: Vector3) -> void:
	if state == State.FAINTED:
		return
	navigation_agent_3d.target_position = position
	_set_state(State.MOVE_TO)

func stay() -> void:
	if state == State.FAINTED:
		return
	_set_state(State.STAY)

func follow(target: Node3D, distance := FOLLOW_DISTANCE) -> void:
	_follow_player = target # The player, or the rat's spot in the line behind the player.
	follow_distance = distance
	if state == State.FAINTED:
		return
	_set_state(State.FOLLOW)

# Called by hazards. The rat faints, poofs away, and comes back next to the player later.
func faint() -> void:
	if state == State.FAINTED:
		return
	_set_state(State.FAINTED)
	velocity = Vector3.ZERO
	animation_player.play("Faint")
	await animation_player.animation_finished
	hide()
	collision_shape_3d.disabled = true  # also takes the rat off any pressure plate
	await get_tree().create_timer(REJOIN_DELAY, false).timeout
	if is_instance_valid(_follow_player):
		global_position = _follow_player.global_position + Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6))
	# Let physics see the new position first, or the hazard catches the rat again at the old one.
	await get_tree().physics_frame
	await get_tree().physics_frame
	collision_shape_3d.disabled = false
	show()
	_set_state(State.FOLLOW if is_instance_valid(_follow_player) else State.STAY)

func _process_move_to() -> void:
	var to_target := navigation_agent_3d.target_position - global_position
	to_target.y = 0.0
	if to_target.length() < ARRIVE_DISTANCE:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_state(State.STAY)
	elif navigation_agent_3d.is_navigation_finished():
		_steer(to_target)  # the path ends a little short, so walk the last bit in a straight line
	else:
		_steer_along_path()

func _process_follow() -> void:
	if not is_instance_valid(_follow_player):
		_set_state(State.STAY)
		return

	navigation_agent_3d.target_position = _follow_player.global_position

	var to_target := _follow_player.global_position - global_position
	to_target.y = 0.0
	# So rats keep a distance away when following player
	if to_target.length() < follow_distance or navigation_agent_3d.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		_steering = to_target.length() > maxf(follow_distance, FOLLOW_DISTANCE) * 3.0  # the path ended but the target is still far away
		return

	_steer_along_path()

func _steer_along_path() -> void:
	var next_path = navigation_agent_3d.get_next_path_position()
	_steer(next_path - global_position) # Where we want to go Minus where we are right now in a 3d vector.

func _steer(direction: Vector3) -> void:
	direction.y = 0.0
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_steering = true

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
