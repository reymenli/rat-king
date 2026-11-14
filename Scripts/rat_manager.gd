class_name Rat_Manager
extends Node
signal count_changed(total:int)

@export var player: CharacterBody3D
@export var rat_scene: PackedScene
@export var structure_scene: PackedScene

const MAX_FOLLOWING = 5

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
	var wheel := player.command_wheel as Command_Wheel
	wheel.ability_chosen.connect(_on_ability_chosen)
	
	for rat in get_children():
		if rat is Rat:
			recruit(rat)
	count_changed.emit(rat_total)
	pass # Replace with function body.
	
func command(ability: COMMAND) -> void:
	if ability == COMMAND.BRIDGE:
		_build(Rat_Structure.Structure.BRIDGE, BRIDGE_RATS)
		return
	if ability == COMMAND.STACK:
		_build(Rat_Structure.Structure.STACK, STACK_RATS)
		return
	if ability == COMMAND.FOLLOW:
		_release_structures()
	if ability == COMMAND.MOVE_TO:
		_refill()
	
	for rat in rats_out:
		if ability == COMMAND.FOLLOW:
			rat.follow(player)
		if ability == COMMAND.STAY:
			rat.stay()
		if ability == COMMAND.MOVE_TO:
			rat.move_to(player.aim_point)
		
func _on_ability_chosen(ability: COMMAND) -> void:
	var target := player.aim_collider as Rat
	command(ability)
	return

func recruit(rat: Rat) -> void:
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
func _process(delta: float) -> void:
	pass
	

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
		rat.global_position = player.global_position
		rats_out.append(rat)
		rat.follow(player)
		in_bank -= 1

func _player_feet() -> Vector3:
	var capsule := player.get_node("CollisionShape3D").shape as CapsuleShape3D
	return player.global_position - Vector3(0, capsule.height / 2.0, 0)
