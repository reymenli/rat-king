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
const VEHICLE_RATS := 20
const FIST_RATS := 30
const RATAZORD_RATS := 99  # every rat but the last, who waits behind the scientist
const FIST_RANGE := 12.0
const RAT_MODEL := preload("res://assets/models/characters/rats/SK_Rat_E.glb")
var structures: Array[Rat_Structure] = []

var rats_out: Array[Rat] = []

# Following rats walk in single file: the player's path is recorded as a trail, and each
# following rat chases its own spot on it, LINE_GAP metres apart.
const LINE_GAP := 0.75
const TRAIL_STEP := 0.15
var _trail: PackedVector3Array = []  # newest first
var _spots: Array[Node3D] = []
var selection: Array[Rat] = []  # rats tagged with left click. Commands go to these when there are any
var rat_total : int
var rat_available : int

enum COMMAND {
	FOLLOW,
	STAY,
	MOVE_TO,
	STACK,
	BRIDGE,
	VEHICLE,
	FIST,
	RATAZORD
}
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("rat_manager")
	for i in MAX_FOLLOWING:
		var spot := Node3D.new()
		spot.top_level = true
		add_child(spot)
		_spots.append(spot)
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
	if ability == COMMAND.VEHICLE:
		if rat_total >= VEHICLE_RATS:
			player.set_vehicle(not player.in_vehicle)
		return
	if ability == COMMAND.FIST:
		if rat_total >= FIST_RATS:
			_fist()
		return
	if ability == COMMAND.RATAZORD:
		if rat_total >= RATAZORD_RATS:
			_ratazord()
		return
	if ability == COMMAND.FOLLOW and target == null:
		player.set_vehicle(false)  # Follow is the universal release
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
			_follow_in_line(rat)
		if ability == COMMAND.STAY:
			rat.stay()
		if ability == COMMAND.MOVE_TO:
			# Each rat gets its own spot in a small ring so they do not fight over one point.
			var spot := Vector3.ZERO if selected.size() == 1 else Vector3.RIGHT.rotated(Vector3.UP, i * TAU / selected.size()) * 0.3
			rat.move_to(player.aim_point + spot)

func _follow_in_line(rat: Rat) -> void:
	rat.follow(_spots[0], 0.2)  # the real spot is set every frame in _update_line


func _physics_process(_delta: float) -> void:
	_update_line()


func _update_line() -> void:
	var feet := _player_feet()
	if _trail.is_empty() or _trail[0].distance_to(feet) > TRAIL_STEP:
		_trail.insert(0, feet)
		_trail.resize(mini(_trail.size(), int(LINE_GAP * (MAX_FOLLOWING + 1) / TRAIL_STEP) + 2))
	var place := 0
	for rat in rats_out:
		if rat.state != Rat.State.FOLLOW or not rat._follow_player in _spots:
			continue
		var spot := _spots[place]
		spot.global_position = _trail_point((place + 1) * LINE_GAP)
		rat._follow_player = spot
		place += 1


# The point `distance` metres back along the player's path.
func _trail_point(distance: float) -> Vector3:
	var walked := 0.0
	for i in range(1, _trail.size()):
		var step := _trail[i - 1].distance_to(_trail[i])
		if walked + step >= distance:
			return _trail[i - 1].lerp(_trail[i], (distance - walked) / step)
		walked += step
	return _trail[-1] if not _trail.is_empty() else _player_feet()


func _say(speaker: String, line: String) -> void:
	(get_tree().get_first_node_in_group("hud") as HUD).say(speaker, [line])


# A ball of rats, used for the Giant Fist.
func _rat_ball(count: int, radius: float) -> Node3D:
	var ball := Node3D.new()
	ball.top_level = true
	add_child(ball)
	for i in count:
		var rat := RAT_MODEL.instantiate() as Node3D
		ball.add_child(rat)
		var dir := Vector3.FORWARD.rotated(Vector3.UP, i * 2.4).rotated(Vector3.RIGHT, (i % 5) * 0.6 - 1.2)
		rat.position = dir * radius
		rat.look_at_from_position(rat.position, Vector3.ZERO)
		(rat.get_node("AnimationPlayer") as AnimationPlayer).play("Brace")
	return ball


# Giant Fist: aim at a breakable wall, the rats ball up into a fist and smash it.
func _fist() -> void:
	var wall := _breakable_under_crosshair()
	if wall == null:
		_say("Rat King", "gotta aim the fist at somethin breakable.")
		return
	var fist := _rat_ball(28, 0.55)
	var start: Vector3 = player.global_position + Vector3.UP * 0.8 - player.camera.global_basis.z * 0.8
	fist.global_position = start
	var hit: Vector3 = player.aim_point
	var tween := create_tween()
	tween.tween_property(fist, "global_position", start - player.camera.global_basis.z * 0.4, 0.15)  # wind up
	tween.tween_property(fist, "global_position", hit, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(wall.queue_free)
	tween.tween_property(fist, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(fist.queue_free)


func _breakable_under_crosshair() -> Node3D:
	var node: Node = player.aim_collider
	if player.global_position.distance_to(player.aim_point) > FIST_RANGE:
		return null
	while node:
		if node.is_in_group("breakable"):
			return node as Node3D
		node = node.get_parent()
	return null


# Ratazord: the finale. A giant rat smashes the glass and sends the scientist flying,
# then the last rat (who was behind the scientist) joins as the 100th.
func _ratazord() -> void:
	var scientist := get_tree().get_first_node_in_group("scientist") as Node3D
	if scientist == null:
		_say("Rat King", "not here. save it for the guy with the cheese.")
		return
	var glass := get_tree().get_nodes_in_group("ratazord_glass")
	var target := scientist.global_position
	if not glass.is_empty():
		target = (glass[0] as Node3D).global_position
		for pane in glass:
			target = target.lerp((pane as Node3D).global_position, 0.5)
	var mech := RAT_MODEL.instantiate() as Node3D
	mech.top_level = true
	add_child(mech)
	mech.global_position = player.global_position - Vector3.UP * 0.85
	mech.scale = Vector3.ONE * 0.5
	mech.look_at(Vector3(target.x, mech.global_position.y, target.z), Vector3.UP, true)
	(mech.get_node("AnimationPlayer") as AnimationPlayer).play("Run")
	_say("Scientist", "wait. WAIT. that's not... that's not POSSIBLE--")
	var tween := create_tween()
	tween.tween_property(mech, "scale", Vector3.ONE * 7.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mech, "global_position", Vector3(target.x, mech.global_position.y, target.z), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		for pane in get_tree().get_nodes_in_group("ratazord_glass"):
			pane.queue_free()
		var away := (scientist.global_position - target).normalized() * 6.0 + Vector3.UP * 3.0
		var fly := create_tween().set_parallel()
		fly.tween_property(scientist, "global_position", scientist.global_position + away, 0.9)
		fly.tween_property(scientist, "rotation:x", scientist.rotation.x - TAU * 2.0, 0.9)
		fly.chain().tween_callback(scientist.queue_free)
		_say("Scientist", "NOOOOooo..."))
	tween.tween_interval(0.6)
	tween.tween_property(mech, "scale", Vector3.ZERO, 0.4)
	tween.tween_callback(mech.queue_free)
	tween.tween_callback(func() -> void:
		add_to_bank(1)  # the last rat was waiting behind him
		_say("Rat King", "that's what ya get, four-eyes. and that makes a hundred. now... the cheese."))


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
		_follow_in_line(rat)
	else: # If you recruited and already have 5 following you, it just gets rid of it
		rat.queue_free()
	count_changed.emit(rat_total)

# Brings every rat to the player. Used when the player travels through a pipe.
func gather() -> void:
	_release_structures()
	for rat in rats_out:
		rat.global_position = _beside_player()
		_follow_in_line(rat)

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

# Puts rats straight into the bank (the skip button in Settings uses this).
func add_to_bank(count: int) -> void:
	rat_total += count
	rat_available += count
	_refill()
	count_changed.emit(rat_total)

func _refill() -> void:
	var in_bank := rat_available - rats_out.size()
	while rats_out.size() < MAX_FOLLOWING and in_bank > 0:
		var rat:= rat_scene.instantiate() as Rat
		add_child(rat)
		rat.global_position = _beside_player()
		rats_out.append(rat)
		_follow_in_line(rat)
		in_bank -= 1

# A spot near the player's feet, spread out so new rats do not spawn inside each other.
func _beside_player() -> Vector3:
	return _player_feet() + Vector3(randf_range(-0.7, 0.7), 0.1, randf_range(-0.7, 0.7))

func _player_feet() -> Vector3:
	var capsule := player.get_node("CollisionShape3D").shape as CapsuleShape3D
	return player.global_position - Vector3(0, capsule.height / 2.0, 0)
