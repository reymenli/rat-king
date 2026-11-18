extends SceneTree
# Builds the area scenes in Scenes/levels/ from the room layouts written below.
#
#   <godot> --headless --path . --script tools/build_levels.gd
#
# WARNING: this overwrites the scenes. Once an area is being edited by hand in the
# editor, remove its build_* call from _initialize() so those edits are not lost.
#
# Layouts are drawn on the kit's 2 m grid. A cell is one floor tile, named by its
# (x, z) grid position. Walls are worked out from the cells: an edge gets a wall
# when there is no cell on the other side or the other cell belongs to another room.

const LAB := "res://assets/models/environment/lab/"
const HIDE := "res://assets/models/environment/hideout/"
const LEVELS := "res://Scenes/levels/"
const CELL := 2.0
const WALL_HEIGHT := 3.0
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

var level: Node3D
var geo: NavigationRegion3D  # floors, walls and big props: what the rats path around
var ceilings: Node3D
var things: Node3D  # interactables, pickups, hazards
var rats: Node3D
var triggers: Node3D
var lights: Node3D
var hideout := false  # which kit the shell is built from

var cells := {}  # Vector2i -> {h = floor height, top = ceiling height, room = id}
var rooms: Array[Rect2i] = []
var portals := {}  # edge -> "open" (no wall), "doorway" (frame only), "door" (frame and sliding door)
var doors := {}  # edge -> the sliding door placed there


func _initialize() -> void:
	await process_frame  # nodes only count as inside the tree once the main loop runs
	DirAccess.make_dir_recursive_absolute(LEVELS)
	build_tutorial()
	build_hideout()
	build_left_zone()
	build_right_zone()
	build_final_zone()
	quit()


# ---------------------------------------------------------------- areas

func build_tutorial() -> void:
	begin("Tutorial", false)

	# R1 wake-up cell: move, look, recruit two rats, pull a lever.
	room(0, 0, 3, 3)
	# R2: a pressure plate that needs two rats (Go To / Stay).
	room(3, 0, 4, 3)
	# R3: key and a cage of four rats.
	room(7, 0, 4, 3)
	# R4: tall room with a ledge. Stack to reach the timed button on it.
	room(11, 0, 4, 3, 6.0)
	reshape(13, 0, 2, 3, 1.5, 6.0)
	# R5: corridor with a 6 m spike pit, too wide to jump. Bridge is the only way over.
	room(11, 3, 2, 7)
	reshape(11, 5, 2, 3, -1.0, 3.0)
	# R6: the way out, a sewage pipe.
	room(11, 10, 2, 3, 4.5)

	portal(Vector2i(2, 1), Vector2i(3, 1), "door")
	portal(Vector2i(6, 1), Vector2i(7, 1), "door")
	portal(Vector2i(10, 1), Vector2i(11, 1), "doorway")
	portal(Vector2i(11, 2), Vector2i(11, 3), "door")
	portal(Vector2i(11, 9), Vector2i(11, 10), "open")  # the gate fills these two
	portal(Vector2i(12, 9), Vector2i(12, 10), "open")
	portal(Vector2i(11, 12), Vector2i(11, 13), "open")  # the pipe mouth fills these two
	portal(Vector2i(12, 12), Vector2i(12, 13), "open")
	build_shell()

	spawn("PlayerSpawn", at(1, 1), -90.0)

	# R1
	wild_rat(at(2, 0, 0.1) + Vector3(0.2, 0, 0))
	wild_rat(at(2, 2, 0.1) + Vector3(0.2, 0, 0.3))
	var lever1: Lever = put("res://Scenes/lever.tscn", Vector3(3, 1.0, 0.13))
	door_at(Vector2i(2, 1), Vector2i(3, 1)).levers.append(lever1)
	sign_arrow("Green", Vector3(5.86, 2.4, 3), -90.0)
	say("Start", at(0, 1), Vector3(3, 3, 3), "Rat King", [
		"Ugh... my head. Another morning in the Lab.",
		"WASD to walk, Space to jump. The mouse looks around.",
		"Holding right click steadies my aim.",
		"Those two look lost. If I stand close, hold Q and pick Follow, they will join me.",
		"Then that lever by the door. E pulls it."])

	# R2
	var plate1: PressurePlate = put("res://Scenes/pressure_plate.tscn", at(4, 0))
	plate1.rats_needed = 2
	door_at(Vector2i(6, 1), Vector2i(7, 1)).plates.append(plate1)
	put(LAB + "signage/signs/SM_Sign_RatOnly.glb", Vector3(9, 1.6, 0.13))
	say("Plate", at(3, 1), Vector3(1.5, 3, 5.5), "Rat King", [
		"A pressure plate. It ignores me, it only answers to rats.",
		"I aim at the plate, hold Q and pick Go To. Two rats should hold it down.",
		"Stay keeps them where they are. Follow calls them back to me."])

	# R3
	put("res://Scenes/key.tscn", at(8, 2, 0.8))
	cage_with_rats(at(10, 0) + Vector3(0.2, 0, -0.2), 0.0, 4)
	say("Cage", at(7, 1), Vector3(1.5, 3, 5.5), "Scientist", [
		"Subject K-1 is out of containment again. How... curious."])
	say("Cage2", at(8, 1), Vector3(1.5, 3, 5.5), "Rat King", [
		"They locked my brothers and sisters in a cage.",
		"There is a key lying around here. With it I can open the cage with E."])

	# R4
	var button: TimedButton = put("res://Scenes/button.tscn", Vector3(29.87, 2.6, 3), -90.0)
	button.active_seconds = 12.0
	door_at(Vector2i(11, 2), Vector2i(11, 3)).buttons.append(button)
	sign_arrow("Orange", Vector3(23, 2.5, 5.86), 180.0)
	say("Stack", at(11, 1), Vector3(1.5, 3, 5.5), "Rat King", [
		"That button is up on the ledge, too high for a jump.",
		"Stack: four rats pile up under my feet. From the top of the pile I can jump the rest.",
		"The button runs on a timer and the door is back down here. I will have to hurry."])

	# R5
	for x in [11, 12]:
		for z in [5, 6, 7]:
			put("res://Scenes/spikes.tscn", at(x, z, -1.0))
	put(LAB + "signage/signs/SM_Sign_Spikes.glb", Vector3(22.13, 1.5, 9), 90.0)
	say("Bridge", at(11, 3) + Vector3(1, 0, 0), Vector3(3.5, 3, 1.5), "Rat King", [
		"Spikes, and the gap is too wide to jump.",
		"Bridge: six rats link up straight ahead of me. I face the gap, hold Q and pick Bridge.",
		"Once I am across, Follow brings everyone back."])
	var plate2: PressurePlate = put("res://Scenes/pressure_plate.tscn", at(12, 8))
	plate2.rats_needed = 3
	var lever2: Lever = put("res://Scenes/lever.tscn", Vector3(22.13, 1.0, 19), 90.0)
	var gate := put("res://Scenes/gate.tscn", Vector3(24, 0, 20))
	gate.plates.append(plate2)
	gate.levers.append(lever2)
	say("Gate", at(11, 8) + Vector3(1, 0, 0), Vector3(3.5, 3, 1.5), "Rat King", [
		"A gate with two locks. A plate for three rats and a lever for me."])

	# R6
	tube("Tutorial", Vector3(24, 0, 26), 180.0, "Green", "hideout.tscn", "FromTutorial", "FromHideout")
	say("Exit", at(11, 10) + Vector3(1, 0, 0), Vector3(3.5, 3, 1.5), "Scientist", [
		"Let it run. The cheese stays with me."])
	say("Exit2", at(11, 11) + Vector3(1, 0, 0), Vector3(3.5, 3, 1.5), "Rat King", [
		"A sewage pipe. Smells like home."])

	finish("tutorial.tscn")


func build_hideout() -> void:
	begin("Hideout", true)
	room(0, 0, 7, 7, 6.0)
	for i in [2, 3, 4]:  # a 6 m gap in the middle of each wall for a tube
		portal(Vector2i(i, 6), Vector2i(i, 7), "open")
		portal(Vector2i(i, 0), Vector2i(i, -1), "open")
		portal(Vector2i(0, i), Vector2i(-1, i), "open")
		portal(Vector2i(6, i), Vector2i(7, i), "open")
	build_shell()

	tube("Tutorial", Vector3(7, 0, 14), 180.0, "Green", "tutorial.tscn", "FromHideout", "FromTutorial")
	tube("Left", Vector3(0, 0, 7), 90.0, "Teal", "left_zone.tscn", "PlayerSpawn", "FromLeft")
	tube("Right", Vector3(14, 0, 7), -90.0, "Orange", "right_zone.tscn", "PlayerSpawn", "FromRight")
	var final_pipe := tube("Final_Sealed", Vector3(7, 0, 0), 0.0, "Red", "final_zone.tscn", "PlayerSpawn", "FromFinal")
	final_pipe.requires_zones = PackedStringArray(["left", "right"])
	spawn("PlayerSpawn", Vector3(7, 0, 10.5), 0.0)

	var furniture := HIDE + "furniture/SM_Hide_%s.glb"
	put(furniture % "Cheese_Table", Vector3(7, 0, 7), 0.0, geo)
	# TV corner
	put(furniture % "TV_Stack", Vector3(1.2, 0, 11.0), 90.0, geo)
	put(furniture % "Couch_Sectional_Brown", Vector3(4.4, 0, 11.4), -90.0, geo)
	put(furniture % "Armchair_Green", Vector3(2.6, 0, 12.9), 160.0, geo)
	put(furniture % "Beanbag", Vector3(2.8, 0, 9.0), 40.0, geo)
	# nests
	put(furniture % "Nest_Mattress", Vector3(11.6, 0, 1.6), 0.0, geo)
	put(furniture % "Nest_Mattress", Vector3(12.6, 0, 3.6), 70.0, geo)
	put(furniture % "Couch_Pallet", Vector3(10.6, 0, 3.9), 200.0, geo)
	# storage
	put(furniture % "Crate_Stack", Vector3(12.4, 0, 12.2), -20.0, geo)
	put(furniture % "Crate", Vector3(10.8, 0, 12.9), 15.0, geo)
	put(furniture % "Barrel", Vector3(1.2, 0, 1.2), 0.0, geo)
	put(furniture % "Barrel", Vector3(2.1, 0, 1.5), 0.0, geo)
	put(furniture % "TireChair", Vector3(2.4, 0, 3.4), 120.0, geo)
	put(HIDE + "lighting/SM_HLight_FireBarrel.glb", Vector3(10.2, 0, 9.8), 0.0, geo)
	_light(Vector3(10.2, 1.6, 9.8), Color(1.0, 0.5, 0.15), 2.5, 7.0)
	for x in [2.0, 12.0]:
		put(HIDE + "lighting/SM_Hide_StringLights_4m.glb", Vector3(x, 3.4, 0.2), 0.0, lights)
		put(HIDE + "lighting/SM_Hide_StringLights_4m.glb", Vector3(x, 3.4, 13.8), 180.0, lights)

	# recruited rats loiter here (decoration, they cannot be recruited again)
	for pos: Vector3 in [Vector3(5.5, 0.1, 9.6), Vector3(3.4, 0.1, 10.2), Vector3(9.0, 0.1, 8.6),
			Vector3(11.0, 0.1, 2.6), Vector3(8.4, 0.1, 5.6), Vector3(5.2, 0.1, 5.0)]:
		put("res://Scenes/rats.tscn", pos, pos.x * 67.0, rats)

	say("Home", Vector3(7, 0, 10.5), Vector3(4, 3, 4), "Rat King", [
		"The hideout. Nobody in a white coat has ever found this place.",
		"Three more pipes lead back into the Lab. Teal goes left, orange goes right.",
		"The big red one is sealed. It will not open until both zones are cleared."])
	finish("hideout.tscn")


func build_left_zone() -> void:
	begin("LeftZone", false)
	room(0, 0, 3, 3, 4.5)  # A: arrival
	room(0, -4, 3, 4)  # B: two plates, one command per rat
	room(0, -9, 3, 5)  # C: 6 m electrified pit, then a cage
	reshape(0, -8, 3, 3, -1.0, 3.0)
	room(0, -13, 3, 4, 6.0)  # D: lever up on a ledge
	reshape(0, -13, 3, 2, 1.5, 6.0)
	room(3, -11, 3, 3, 4.5)  # E: way out
	for x in 3:
		portal(Vector2i(x, 2), Vector2i(x, 3), "open")
	for z in [-11, -10, -9]:
		portal(Vector2i(5, z), Vector2i(6, z), "open")
	portal(Vector2i(1, 0), Vector2i(1, -1), "doorway")
	portal(Vector2i(1, -4), Vector2i(1, -5), "door")
	portal(Vector2i(1, -9), Vector2i(1, -10), "doorway")
	portal(Vector2i(2, -10), Vector2i(3, -10), "door")
	build_shell()

	tube("Left", Vector3(3, 0, 6), 180.0, "Teal", "hideout.tscn", "FromLeft", "PlayerSpawn")
	say("Arrive", at(1, 1), Vector3(5, 3, 3), "Scientist", [
		"Movement in the left wing. Bring up the cameras."])

	# B
	var plate_a: PressurePlate = put("res://Scenes/pressure_plate.tscn", at(0, -3))
	var plate_b: PressurePlate = put("res://Scenes/pressure_plate.tscn", at(2, -3))
	plate_a.rats_needed = 2
	plate_b.rats_needed = 2
	var door_b := door_at(Vector2i(1, -4), Vector2i(1, -5))
	door_b.plates.append(plate_a)
	door_b.plates.append(plate_b)
	wild_rat(at(1, -2, 0.1))
	wild_rat(at(2, -1, 0.1))
	say("Plates", at(1, -1), Vector3(5, 3, 1.5), "Rat King", [
		"Two plates, two rats each. Sending everyone to one plate will not do it.",
		"If my crosshair is on one rat when I give a command, only that rat listens."])

	# C
	for x in 3:
		for z in [-8, -7, -6]:
			hazard_floor(LAB + "hazards/SM_ElectricFloor_2x2.glb", at(x, z, -1.0))
	mount(LAB + "signage/signs/SM_Sign_Electric.glb", Vector2i(0, -5), Vector2i(-1, 0), 1.5)
	put("res://Scenes/key.tscn", at(2, -9, 0.8))
	cage_with_rats(at(0, -9) + Vector3(-0.2, 0, -0.2), 0.0, 6)
	say("Pit", at(1, -5), Vector3(5, 3, 1.5), "Rat King", [
		"The floor down there is live. Bridge will get me over."])

	# D
	var lever: Lever = mount("res://Scenes/lever.tscn", Vector2i(1, -13), Vector2i(0, -1), 2.5)
	door_at(Vector2i(2, -10), Vector2i(3, -10)).levers.append(lever)
	say("Ledge", at(1, -10), Vector3(5, 3, 1.5), "Rat King", [
		"The switch for this door is up on that ledge. Time for a Stack."])

	# E
	var exit_pipe := tube("Left", Vector3(12, 0, -19), -90.0, "Teal", "hideout.tscn", "FromLeft", "ExitSpawn")
	exit_pipe.completes_zone = "left"
	say("Done", at(3, -10), Vector3(1.5, 3, 5), "Rat King", [
		"That is the left wing done. This pipe runs straight back to the hideout."])
	finish("left_zone.tscn")


func build_right_zone() -> void:
	begin("RightZone", false)
	room(0, 0, 3, 3, 4.5)  # A: arrival
	room(0, -6, 3, 6)  # B: timed door at the end of a spike slalom
	room(0, -10, 3, 4, 6.0)  # C: key on a ledge, cage, two-lock door
	reshape(0, -10, 3, 1, 1.5, 6.0)
	room(3, -9, 3, 3, 4.5)  # D: way out
	for x in 3:
		portal(Vector2i(x, 2), Vector2i(x, 3), "open")
	for z in [-9, -8, -7]:
		portal(Vector2i(5, z), Vector2i(6, z), "open")
	portal(Vector2i(1, 0), Vector2i(1, -1), "doorway")
	portal(Vector2i(1, -6), Vector2i(1, -7), "door")
	portal(Vector2i(2, -8), Vector2i(3, -8), "door")
	build_shell()

	tube("Right", Vector3(3, 0, 6), 180.0, "Orange", "hideout.tscn", "FromRight", "PlayerSpawn")
	say("Arrive", at(1, 1), Vector3(5, 3, 3), "Scientist", [
		"Now the right wing. It learns quickly. Note that down."])

	# B
	for cell: Vector2i in [Vector2i(0, -2), Vector2i(1, -2), Vector2i(1, -4), Vector2i(2, -4)]:
		put("res://Scenes/spikes.tscn", at(cell.x, cell.y, 0.02))
	var button: TimedButton = mount("res://Scenes/button.tscn", Vector2i(0, -1), Vector2i(-1, 0), 1.2)
	button.active_seconds = 8.0
	door_at(Vector2i(1, -6), Vector2i(1, -7)).buttons.append(button)
	mount(LAB + "signage/signs/SM_Sign_Spikes.glb", Vector2i(2, -1), Vector2i(1, 0), 1.5)
	wild_rat(at(0, -5, 0.1))
	wild_rat(at(2, -5, 0.1))
	say("Slalom", at(1, -1), Vector3(5, 3, 1.5), "Rat King", [
		"A timed button, and the door is past the spikes.",
		"Rats run straight into spikes. They faint, then find me again a little later."])

	# C
	put("res://Scenes/key.tscn", at(0, -10, 2.3))
	cage_with_rats(at(2, -7) + Vector3(0.2, 0, 0.2), 180.0, 6)
	var plate: PressurePlate = put("res://Scenes/pressure_plate.tscn", at(1, -8))
	plate.rats_needed = 3
	var lever: Lever = mount("res://Scenes/lever.tscn", Vector2i(0, -8), Vector2i(-1, 0), 1.0)
	var door_c := door_at(Vector2i(2, -8), Vector2i(3, -8))
	door_c.plates.append(plate)
	door_c.levers.append(lever)
	say("Key", at(1, -7), Vector3(5, 3, 1.5), "Rat King", [
		"A cage down here and its key up on the ledge."])

	# D
	var exit_pipe := tube("Right", Vector3(12, 0, -15), -90.0, "Orange", "hideout.tscn", "FromRight", "ExitSpawn")
	exit_pipe.completes_zone = "right"
	say("Done", at(3, -8), Vector3(1.5, 3, 5), "Rat King", [
		"Right wing done. Back to the hideout."])
	finish("right_zone.tscn")


func build_final_zone() -> void:
	begin("FinalZone", false)
	room(0, 0, 3, 3, 4.5)  # A: arrival
	room(0, -5, 3, 5)  # B: observation corridor
	room(0, -8, 3, 3)  # C: the cheese chamber, behind glass for now
	for x in 3:
		portal(Vector2i(x, 2), Vector2i(x, 3), "open")
		portal(Vector2i(x, -5), Vector2i(x, -6), "open")
		put(LAB + "architecture/glass/SM_Glass_Wall_2x3.glb", at(x, -5) + Vector3(0, 0, -1), 0.0, geo)
	portal(Vector2i(1, 0), Vector2i(1, -1), "doorway")
	build_shell()

	tube("Final_Sealed", Vector3(3, 0, 6), 180.0, "Red", "hideout.tscn", "FromFinal", "PlayerSpawn")
	put(HIDE + "furniture/SM_Hide_Cheese_Table.glb", at(1, -7), 0.0, geo)
	put("res://assets/models/cheese.glb", at(1, -7, 1.09) + Vector3(0.5, 0, 0))
	_light(at(1, -7, 2.2), Color(1.0, 0.85, 0.3), 3.0, 5.0)
	say("Glass", at(1, -3), Vector3(5, 3, 1.5), "Scientist", [
		"Ah, K-1. You came all this way for the cheese.",
		"You will need far more friends than that to get through this glass."])
	say("Glass2", at(1, -4), Vector3(5, 3, 1.5), "Rat King", [
		"Ninety-nine rats. Then nothing in this Lab will stop us.",
		"Odd. I can almost remember how that cheese tastes."])
	finish("final_zone.tscn")


# ---------------------------------------------------------------- building blocks

func begin(level_name: String, use_hideout_kit: bool) -> void:
	hideout = use_hideout_kit
	cells.clear()
	rooms.clear()
	portals.clear()
	doors.clear()

	level = Node3D.new()
	level.name = level_name
	root.add_child(level)
	geo = _group(NavigationRegion3D.new(), "Geometry")
	ceilings = _group(Node3D.new(), "Ceilings")
	things = _group(Node3D.new(), "Interactables")
	rats = _group(Node3D.new(), "Rats")
	triggers = _group(Node3D.new(), "Triggers")
	lights = _group(Node3D.new(), "Lights")

	# Indoors: no sky, a flat ambient light so nothing is pitch black, lamps do the rest.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.85, 0.7) if hideout else Color(0.85, 0.92, 1.0)
	env.ambient_light_energy = 0.45 if hideout else 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var world := WorldEnvironment.new()
	world.environment = env
	_group(world, "WorldEnvironment")


func _group(node: Node, node_name: String) -> Node:
	node.name = node_name
	level.add_child(node)
	node.owner = level
	return node


# Adds a room of w by d cells. `top` is the ceiling height, `h` the floor height.
func room(x: int, z: int, w: int, d: int, top := 3.0, h := 0.0) -> void:
	rooms.append(Rect2i(x, z, w, d))
	for cx in range(x, x + w):
		for cz in range(z, z + d):
			cells[Vector2i(cx, cz)] = {"h": h, "top": top, "room": rooms.size()}


# Changes floor and ceiling height for part of a room (ledges, pits, low ducts).
func reshape(x: int, z: int, w: int, d: int, h: float, top: float) -> void:
	for cx in range(x, x + w):
		for cz in range(z, z + d):
			cells[Vector2i(cx, cz)].h = h
			cells[Vector2i(cx, cz)].top = top


func portal(a: Vector2i, b: Vector2i, kind: String) -> void:
	portals[_edge(a, b)] = kind


func door_at(a: Vector2i, b: Vector2i) -> Node3D:
	return doors[_edge(a, b)]


func _edge(a: Vector2i, b: Vector2i) -> Array:
	return [a, b] if (a.x < b.x or (a.x == b.x and a.y < b.y)) else [b, a]


# World position of the middle of a cell.
func at(x: int, z: int, y := 0.0) -> Vector3:
	return Vector3((x + 0.5) * CELL, y, (z + 0.5) * CELL)


func piece(folder: String, piece_name: String) -> String:
	if hideout:
		return HIDE + "architecture/%s/SM_%s_Hideout.glb" % [folder, piece_name]
	return LAB + "architecture/%s/SM_%s.glb" % [folder, piece_name]


func put(path: String, pos: Vector3, yaw := 0.0, parent: Node = null) -> Node3D:
	var node := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D  # edit state: only changed properties get saved
	(parent if parent else things).add_child(node, true)
	node.owner = level
	node.position = pos
	node.rotation_degrees.y = yaw
	return node


# Floors, ceilings, walls and lamps for every cell declared so far.
func build_shell() -> void:
	var done := {}
	for cell: Vector2i in cells:
		var info: Dictionary = cells[cell]
		put(piece("floors", "Floor_2x2"), at(cell.x, cell.y, info.h), 0.0, geo)
		put(piece("ceilings", "Ceiling_2x2"), at(cell.x, cell.y, info.top), 0.0, ceilings)
		for dir in DIRS:
			var edge := _edge(cell, cell + dir)
			if not done.has(edge):
				done[edge] = true
				_build_edge(cell, dir, edge)

	for rect in rooms:  # roughly one lamp per 3 by 3 cells
		for ix in ceili(rect.size.x / 3.0):
			for iz in ceili(rect.size.y / 3.0):
				var cell := Vector2i(
					rect.position.x + mini(ix * 3 + 1, rect.size.x - 1),
					rect.position.y + mini(iz * 3 + 1, rect.size.y - 1))
				_lamp(at(cell.x, cell.y, cells[cell].top))


func _build_edge(cell: Vector2i, dir: Vector2i, edge: Array) -> void:
	var a: Dictionary = cells[cell]
	var kind: String = portals.get(edge, "")
	var mid := at(cell.x, cell.y) + Vector3(dir.x, 0, dir.y) * CELL / 2.0
	var yaw := 90.0 if dir.x != 0 else 0.0
	var b: Variant = cells.get(cell + dir)

	if b == null or b.room != a.room or kind != "":
		var base: float = a.h if b == null else minf(a.h, b.h)
		var top: float = a.top if b == null else maxf(a.top, b.top)
		var y := base + (WALL_HEIGHT if kind == "open" else 0.0)  # an opening still gets wall above it
		while y < top - 0.01:
			var is_frame := kind.begins_with("door") and is_equal_approx(y, base)
			put(piece("walls", "Wall_Door_2x3" if is_frame else "Wall_2x3"), mid + Vector3.UP * y, yaw, geo)
			y += WALL_HEIGHT
		if kind == "door":
			doors[edge] = put("res://Scenes/sliding_door.tscn", mid + Vector3.UP * base, yaw)
		return

	# Same room: close the step where the floor or the ceiling changes height.
	if not is_equal_approx(a.h, b.h):
		put(piece("walls", "Wall_2x3"), mid + Vector3.UP * (maxf(a.h, b.h) - WALL_HEIGHT), yaw, geo)
	if not is_equal_approx(a.top, b.top):
		put(piece("walls", "Wall_Half_2x1"), mid + Vector3.UP * minf(a.top, b.top), yaw, geo)


func _lamp(pos: Vector3) -> void:
	var model := HIDE + "lighting/SM_HLight_Lantern_Hanging.glb" if hideout else LAB + "lighting/SM_Light_Fluorescent_1.2m.glb"
	put(model, pos, 0.0, lights)
	_light(pos + Vector3.DOWN * (1.2 if hideout else 0.5), Color(1.0, 0.75, 0.45) if hideout else Color(0.9, 0.96, 1.0), 1.5, 9.0)


func _light(pos: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	lights.add_child(light, true)
	light.owner = level
	light.position = pos


# A sewage tube set into a wall, with a pipe trigger at its mouth, a sign above it and a
# spawn point in front of it. `wall_mid` is the floor point in the middle of the 6 m opening,
# `yaw` turns the mouth to face into the room.
const TUBE_NAMES := {
	"tutorial.tscn": "TUTORIAL",
	"hideout.tscn": "HIDEOUT",
	"left_zone.tscn": "LEFT WING",
	"right_zone.tscn": "RIGHT WING",
	"final_zone.tscn": "THE CHEESE",
}


func tube(kind: String, wall_mid: Vector3, yaw: float, sign_color: String, target: String, target_spawn: String, own_spawn: String) -> Area3D:
	var inward := Basis(Vector3.UP, deg_to_rad(yaw)).z
	put(HIDE + "architecture/tubes/SM_Hide_TubeWall_6x4.glb", wall_mid, yaw, geo)
	put(HIDE + "architecture/tubes/SM_Hide_Tube_%s.glb" % kind, wall_mid, yaw, geo)
	put(HIDE + "signage/SM_Hide_Sign_Plank_%s.glb" % sign_color, wall_mid + inward * 0.34 + Vector3.UP * 3.75, yaw)
	var label := Label3D.new()
	_group(label, "SignTo" + target.get_basename().to_pascal_case())
	label.text = TUBE_NAMES[target]
	label.font_size = 64
	label.outline_size = 16
	label.pixel_size = 0.006
	label.position = wall_mid + inward * 0.45 + Vector3.UP * 3.75
	label.rotation_degrees.y = yaw
	spawn(own_spawn, wall_mid + inward * 4.5, yaw + 180.0)
	# Invisible lid over the pipe mouth on layer 4 (camera only), so the camera behind the player
	# can't slide into the dark pipe. The player, rats and aim ray don't collide with layer 4.
	var lid := StaticBody3D.new()
	_group(lid, "CameraLid" + target.get_basename().to_pascal_case())
	lid.collision_layer = 8
	lid.collision_mask = 0
	lid.position = wall_mid + inward * 1.35 + Vector3.UP * 1.6  # the pipe rim sticks out 1.26 m
	lid.rotation_degrees.y = yaw
	var lid_shape := CollisionShape3D.new()
	var lid_box := BoxShape3D.new()
	lid_box.size = Vector3(3.6, 3.6, 0.2)
	lid_shape.shape = lid_box
	lid.add_child(lid_shape)
	lid_shape.owner = level
	var area := _trigger("PipeTo" + target.get_basename().to_pascal_case(), "res://Scripts/pipe.gd",
		wall_mid + inward * 1.5 + Vector3.UP * 1.2, Vector3(2.4, 2.4, 1.0))
	area.rotation_degrees.y = yaw
	area.target_level = LEVELS + target
	area.target_spawn = target_spawn
	return area


func spawn(marker_name: String, floor_pos: Vector3, yaw: float) -> void:
	var marker := Marker3D.new()
	_group(marker, marker_name)
	marker.position = floor_pos + Vector3.UP * 1.0  # the player's origin is at its middle
	marker.rotation_degrees.y = yaw


# A free rat that joins when the player uses Follow near it.
func wild_rat(pos: Vector3) -> void:
	var rat := put("res://Scenes/rats.tscn", pos, pos.z * 67.0, rats)
	rat.add_to_group("wild_rats", true)


func caged_rat(cage: Node3D, offset: Vector2) -> void:
	var rat := (load("res://Scenes/rats.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	cage.add_child(rat, true)
	rat.owner = level
	rat.position = Vector3(offset.x, 0.06, offset.y)
	rat.process_mode = Node.PROCESS_MODE_DISABLED  # the cage switches them on when it opens


func sign_arrow(color: String, pos: Vector3, yaw: float) -> void:
	put(LAB + "signage/signs/SM_Sign_Arrow_%s.glb" % color, pos, yaw)


# Puts something on a wall of a cell, facing into the cell. `dir` points from the cell to the wall.
func mount(path: String, cell: Vector2i, dir: Vector2i, y: float) -> Node3D:
	var pos := at(cell.x, cell.y, y) + Vector3(dir.x, 0, dir.y) * (CELL / 2.0 - 0.13)
	return put(path, pos, rad_to_deg(atan2(-dir.x, -dir.y)))


# A floor tile model that faints rats and sends the player back, e.g. the electric floor.
func hazard_floor(model: String, pos: Vector3) -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 6
	area.set_script(load("res://Scripts/hazard.gd"))
	things.add_child(area, true)
	area.owner = level
	area.position = pos
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(1.9, 0.5, 1.9)
	shape.position.y = 0.25
	area.add_child(shape)
	shape.owner = level
	put(model, Vector3.ZERO, 0.0, area)


func cage_with_rats(pos: Vector3, yaw: float, count: int) -> void:
	var cage := put("res://Scenes/cage.tscn", pos, yaw)
	for i in count:
		caged_rat(cage, Vector2(-0.3 + 0.12 * i, -0.2 + 0.35 * (i % 2)))


# An invisible box that only notices the player, running `script_path` when entered.
func _trigger(node_name: String, script_path: String, pos: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.collision_layer = 0
	area.collision_mask = 2
	area.set_script(load(script_path))
	triggers.add_child(area, true)
	area.owner = level
	area.position = pos
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	area.add_child(shape)
	shape.owner = level
	return area


func say(node_name: String, floor_pos: Vector3, size: Vector3, speaker: String, lines: Array) -> void:
	var area := _trigger("Say" + node_name, "res://Scripts/dialogue_trigger.gd", floor_pos + Vector3.UP * size.y / 2.0, size)
	area.speaker = speaker
	area.lines = PackedStringArray(lines)


func finish(file_name: String) -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = 0.25  # rats are small
	mesh.agent_height = 0.5
	mesh.agent_max_climb = 0.25
	geo.navigation_mesh = mesh
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, geo)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)

	var packed := PackedScene.new()
	packed.pack(level)
	var error := ResourceSaver.save(packed, LEVELS + file_name)
	print("%s: %d cells, %d nav polygons, save %s" % [file_name, cells.size(), mesh.get_polygon_count(), error_string(error)])
	root.remove_child(level)
	level.free()
