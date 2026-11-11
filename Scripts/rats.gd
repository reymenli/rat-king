extends CharacterBody3D

signal state_changed(new_state: int)

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

var _follow_player: Node3D

var speed = 3.0

enum State {
	IDLE,
	FOLLOW,
	STAY,
	MOVE_TO
}

var state: State = State.IDLE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if state == State.MOVE_TO:
		_process_move_to()
	
	if state == State.FOLLOW:
		_process_follow()
		
	move_and_slide()

func move_to(position: Vector3) -> void:
	navigation_agent_3d.target_position = position
	_set_state(State.MOVE_TO)
	
func follow(target: Node3D) -> void:
	_follow_player = target # We get the player node and store it as a variable. 
	_set_state(State.FOLLOW)

func _process_move_to() -> void:
	if navigation_agent_3d.is_navigation_finished(): 
		velocity.x = 0.0
		velocity.z = 0.0
		_set_state(State.IDLE)
		return
		
	var next_path = navigation_agent_3d.get_next_path_position()
	var direction: Vector3 = next_path - global_position # Where we want to go Minus where we are right now in a 3d vector.
	direction.y = 0.0
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
func _process_follow() -> void:
	if not is_instance_valid(_follow_player):
		_set_state(State.IDLE)
		return
	
	navigation_agent_3d.target_position = _follow_player.global_position
	 
	if navigation_agent_3d.is_navigation_finished(): # Stay where you are, but you're still in follow mode
		velocity.x = 0.0
		velocity.z = 0.0
		
	var next_path = navigation_agent_3d.get_next_path_position()
	var direction: Vector3 = next_path - global_position # Where we want to go Minus where we are right now in a 3d vector.
	direction.y = 0.0
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
func _set_state(new_state: State) -> void:
	if state == new_state:
		return

	state = new_state
	state_changed.emit(state)
