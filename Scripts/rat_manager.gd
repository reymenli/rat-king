class_name Rat_Manager
extends Node
signal count_changed(total:int)

@export var player: CharacterBody3D
@export var rat_scene: PackedScene
@export var structure_scene: PackedScene
## Rats already in the bank when the game starts. Handy for testing abilities.
@export var debug_start_rats := 0

const MAX_FOLLOWING = 5
const RECRUIT_RADIUS := 5.0  # Follow also recruits free rats this close to the player

const STACK_RATS := 4
const BRIDGE_RATS := 6
var structures: Array[Rat_Structure] = []

var rats_out: Array[Rat] = []
var rat_total : int
var rat_available : int

enum COMMAND {
	FOLLOW,
	STAY,
	MOVE_TO,
	STACK,
	BRIDGE
}
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("rat_manager")
	var wheel := player.command_wheel as Command_Wheel
	wheel.ability_chosen.connect(_on_ability_chosen)
	count_changed.connect(func(total: int) -> void: wheel.rat_total = total)

	for rat in get_children():
		if rat is Rat:
			recruit(rat)
	rat_total += debug_start_rats
	rat_available += debug_start_rats
	_refill.call_deferred()
	count_changed.emit(rat_total)

# Runs an ability. With a target it applies to that one rat, otherwise to every rat out.
func command(ability: COMMAND, target: Rat = null) -> void:
	if ability == COMMAND.BRIDGE:
		_build(Rat_Structure.Structure.BRIDGE, BRIDGE_RATS)
		return
	if ability == COMMAND.STACK:
		_build(Rat_Structure.Structure.STACK, STACK_RATS)
		return
	if ability == COMMAND.FOLLOW:
		_recruit_nearby(target)
		if target == null:
			_release_structures()
	if ability == COMMAND.MOVE_TO:
		_refill()

	var selected: Array[Rat] = rats_out
	if target and target in rats_out:
		selected = [target]
	for i in selected.size():
		var rat := selected[i]
		if ability == COMMAND.FOLLOW:
			rat.follow(player)
		if ability == COMMAND.STAY:
			rat.stay()
		if ability == COMMAND.MOVE_TO:
			# Each rat gets its own spot in a small ring so they do not fight over one point.
			var spot := Vector3.ZERO if selected.size() == 1 else Vector3.RIGHT.rotated(Vector3.UP, i * TAU / selected.size()) * 0.3
			rat.move_to(player.aim_point + spot)

func _on_ability_chosen(ability: COMMAND) -> void:
	command(ability, player.aimed_rat())

# Free rats placed in a level are in the "wild_rats" group until they join.
func _recruit_nearby(target: Rat) -> void:
	if target and target.is_in_group("wild_rats"):
		recruit(target)
	for node in get_tree().get_nodes_in_group("wild_rats"):
		var rat := node as Rat
		if rat.global_position.distance_to(player.global_position) < RECRUIT_RADIUS:
			recruit(rat)

func recruit(rat: Rat) -> void:
	rat.remove_from_group("wild_rats")
	rat_total += 1
	rat_available += 1
	if rats_out.size() < MAX_FOLLOWING: # If the rat out size is less than 5
		if rat.get_parent() != self: # If the rat isn't under rat manager, but is under the level
			rat.reparent(self) #Make it a child of rat_manager
		rats_out.append(rat)
		rat.follow(player)
	else: # If you recruited and already have 5 following you, it just gets rid of it
		rat.queue_free()
	count_changed.emit(rat_total)

# Brings every rat to the player. Used when the player travels through a pipe.
func gather() -> void:
	_release_structures()
	for rat in rats_out:
		rat.global_position = _beside_player()
		rat.follow(player)

func _build(structure: Rat_Structure.Structure, count: int) -> void:
	if not player.is_on_floor():
		return
	if count > rat_available:
		return

	for i in mini(count, rats_out.size()):
		rats_out.pop_back().queue_free()
	rat_available -= count

	var struct := structure_scene.instantiate() as Rat_Structure
	add_child(struct)
	structures.append(struct)

	var feet := _player_feet()
	var yaw: float = player.mesh.global_rotation.y
	if structure == Rat_Structure.Structure.STACK:
		struct.build(structure, count, feet, yaw)
		player.global_position.y += count * Rat_Structure.RAT_HEIGHT
	elif structure == Rat_Structure.Structure.BRIDGE:
		var forward: Vector3 = -player.mesh.global_basis.z
		struct.build(structure, count, feet + forward * 0.5, yaw)

func _release_structures() -> void:
	for s in structures:
		s.queue_free()
	structures.clear()
	rat_available = rat_total
	_refill()

func _refill() -> void:
	var in_bank := rat_available - rats_out.size()
	while rats_out.size() < MAX_FOLLOWING and in_bank > 0:
		var rat:= rat_scene.instantiate() as Rat
		add_child(rat)
		rat.global_position = _beside_player()
		rats_out.append(rat)
		rat.follow(player)
		in_bank -= 1

# A spot near the player's feet, spread out so new rats do not spawn inside each other.
func _beside_player() -> Vector3:
	return _player_feet() + Vector3(randf_range(-0.7, 0.7), 0.1, randf_range(-0.7, 0.7))

func _player_feet() -> Vector3:
	var capsule := player.get_node("CollisionShape3D").shape as CapsuleShape3D
	return player.global_position - Vector3(0, capsule.height / 2.0, 0)
