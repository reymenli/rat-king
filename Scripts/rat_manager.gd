class_name Rat_Manager
extends Node
signal count_changed(total:int)
signal selection_changed(count: int)

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
var selection: Array[Rat] = []  # rats tagged with left click. Commands go to these when there are any
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
	wheel.hover_changed.connect(_show_ghost)
	_ghost = _make_ghost()
	count_changed.connect(func(total: int) -> void: wheel.rat_total = total)

	for rat in get_children():
		if rat is Rat:
			recruit(rat)
	rat_total += debug_start_rats
	rat_available += debug_start_rats
	_refill.call_deferred()
	count_changed.emit(rat_total)

# Left click on a rat that follows you tags it, clicking again untags it.
func toggle_selected(rat: Rat) -> void:
	if rat not in rats_out:
		return
	if rat in selection:
		selection.erase(rat)
	else:
		selection.append(rat)
	rat.set_selected(rat in selection)
	selection_changed.emit(selection.size())

func clear_selection() -> void:
	for rat in selection:
		if is_instance_valid(rat):
			rat.set_selected(false)
	selection.clear()
	selection_changed.emit(0)

# Runs an ability. Goes to the aimed rat if there is one, else to the tagged rats, else to every rat out.
func command(ability: COMMAND, target: Rat = null) -> void:
	var tagged: Array[Rat] = selection.filter(func(r: Rat) -> bool: return is_instance_valid(r) and r in rats_out)
	clear_selection()
	if ability == COMMAND.BRIDGE:
		_build(Rat_Structure.Structure.BRIDGE, BRIDGE_RATS)
		return
	if ability == COMMAND.STACK:
		_build(Rat_Structure.Structure.STACK, STACK_RATS)
		return
	if ability == COMMAND.FOLLOW:
		_recruit_nearby(target)
		if target == null and tagged.is_empty():
			_release_structures()
	if ability == COMMAND.MOVE_TO:
		_refill()

	var selected: Array[Rat] = rats_out
	if target and target in rats_out:
		selected = [target]
	elif not tagged.is_empty():
		selected = tagged
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
	player.gesture()
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

func _can_build(count: int) -> bool:
	return player.is_on_floor() and count <= rat_available

func _build(structure: Rat_Structure.Structure, count: int) -> void:
	if not _can_build(count):
		return

	for i in mini(count, rats_out.size()):
		rats_out.pop_back().queue_free()
	rat_available -= count

	var struct := structure_scene.instantiate() as Rat_Structure
	add_child(struct)
	structures.append(struct)

	struct.build(structure, count, _structure_feet(structure), _build_yaw())
	if structure == Rat_Structure.Structure.STACK:
		player.global_position.y += count * Rat_Structure.RAT_HEIGHT

# Structures are built the way the camera looks, so the ghost is always in front of the crosshair.
func _build_yaw() -> float:
	return player.camera_pivot.global_rotation.y

# Where a structure starts: a Stack under the player, a Bridge just in front of them.
func _structure_feet(structure: Rat_Structure.Structure) -> Vector3:
	if structure == Rat_Structure.Structure.BRIDGE:
		return _player_feet() + Basis(Vector3.UP, _build_yaw()) * Vector3(0, 0, -0.5)
	return _player_feet()

# See-through box showing where Bridge or Stack will go while its wheel slice is hovered.
# Green when it can be built, red when it can't (too few rats, or in the air).
var _ghost: MeshInstance3D

func _make_ghost() -> MeshInstance3D:
	var ghost := MeshInstance3D.new()
	ghost.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true  # still visible through the floor of a pit or a wall
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.material_override = mat
	ghost.top_level = true
	ghost.hide()
	add_child(ghost)
	return ghost

func _show_ghost(ability: int) -> void:
	var structure: Rat_Structure.Structure
	var count: int
	if ability == COMMAND.BRIDGE:
		structure = Rat_Structure.Structure.BRIDGE
		count = BRIDGE_RATS
	elif ability == COMMAND.STACK:
		structure = Rat_Structure.Structure.STACK
		count = STACK_RATS
	else:
		_ghost.hide()
		return
	var box_size := Rat_Structure.box_size_for(structure, count)
	(_ghost.mesh as BoxMesh).size = box_size
	var basis := Basis(Vector3.UP, _build_yaw())
	_ghost.global_transform = Transform3D(basis, _structure_feet(structure) + basis * Rat_Structure.box_center_for(structure, box_size))
	var ok := _can_build(count)
	(_ghost.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.4, 0.35) if ok else Color(1.0, 0.25, 0.25, 0.35)
	_ghost.show()

func _release_structures() -> void:
	for s in structures:
		s.release()
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
