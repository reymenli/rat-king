extends SceneTree
# Plays through the tutorial by script and checks each mechanic still works.
#
#   <godot> --headless --path . --script tools/smoke_test.gd
#
# Prints PASS / FAIL per step and exits with the number of failures.

var failures := 0
var manager: Level_Manager
var player: CharacterBody3D
var rat_manager: Rat_Manager


func _initialize() -> void:
	Engine.time_scale = 4.0  # run 4x faster...
	Engine.physics_ticks_per_second = 240  # ...with the same physics step as the real game
	manager = (load("res://Scenes/level_manager.tscn") as PackedScene).instantiate()
	root.add_child(manager)
	player = manager.player
	rat_manager = manager.rat_manager
	var hurts := [0]
	player.got_hurt.connect(func() -> void: hurts[0] += 1)
	await wait(1.0)
	var things := manager._level.get_node("Interactables")
	check(manager._level.name == "Tutorial", "tutorial is the first area")
	check(player.is_on_floor(), "player lands on the floor")
	check(rat_manager.rat_total == 0, "player starts with no rats")

	# Esc pause menu: opens and pauses, Esc in Settings goes back, Esc again resumes
	var pause := manager.get_node("PauseLayer/PauseMenu") as Control
	await press_esc()
	check(pause.visible and paused, "Esc opens the pause menu and pauses")
	pause._show_settings(true)
	await press_esc()
	check(pause.visible and not pause.settings.visible, "Esc in Settings goes back to the pause buttons")
	await press_esc()
	check(not pause.visible and not paused, "Esc again resumes the game")

	# recruit the two free rats
	move_player(Vector3(4.5, 1, 3))
	await wait(0.3)
	rat_manager.command(Rat_Manager.COMMAND.FOLLOW)
	check(rat_manager.rat_total == 2, "Follow recruits the nearby free rats")

	# lever opens the first door
	var door1 := things.get_node("SlidingDoor")
	things.get_node("Lever").interact(player)
	check(door1.is_open, "lever opens the door")

	# Go To puts two rats on the plate, which opens the second door
	move_player(Vector3(8, 1, 3))
	await wait(3.0)  # let the rats come through the opening door
	var plate := things.get_node("PressurePlate") as PressurePlate
	player.aim_point = plate.global_position
	rat_manager.command(Rat_Manager.COMMAND.MOVE_TO)
	await wait(6.0)
	check(plate.is_pressed(), "two rats sent with Go To press the plate")
	check(things.get_node("SlidingDoor2").is_open, "plate opens the door")

	# key, then cage
	move_player(Vector3(17, 1, 5))
	await wait(0.3)
	check(player.keys == 1, "walking over the key picks it up")
	rat_manager.command(Rat_Manager.COMMAND.FOLLOW)
	await wait(3.0)  # rats behind the closed door get pulled to the player
	check(not plate.is_pressed(), "plate releases when the rats leave")
	things.get_node("Cage").interact(player)
	await wait(3.0)
	check(player.keys == 0 and rat_manager.rat_total == 6, "cage uses the key and frees four rats")
	check(rat_manager.rats_out.size() == 5, "only five rats are out at once")

	# stack lifts the player
	move_player(Vector3(25, 1, 3))
	await wait(0.5)
	var before := player.global_position.y
	rat_manager.command(Rat_Manager.COMMAND.STACK)
	await wait(0.5)
	check(player.global_position.y > before + 0.8, "Stack lifts the player about 1 m")
	move_player(Vector3(27.5, 3.2, 3))
	await wait(0.5)
	check(absf(player.global_position.y - 2.35) < 0.2, "the ledge holds the player")
	var button := things.get_node("Button") as TimedButton
	button.interact(player)
	check(things.get_node("SlidingDoor3").is_open, "button opens the timed door")
	await wait(13.0)
	check(not things.get_node("SlidingDoor3").is_open, "timed door closes again")

	# bridge carries the player over the spike pit
	rat_manager.command(Rat_Manager.COMMAND.FOLLOW)
	move_player(Vector3(24, 1, 9.5))
	player.mesh.rotation.y = PI  # face +Z, towards the pit
	await wait(0.5)
	rat_manager.command(Rat_Manager.COMMAND.BRIDGE)
	check(rat_manager.structures.size() == 1, "Bridge builds with six rats")
	move_player(Vector3(24, 1, 12), false)
	await wait(0.5)
	check(absf(player.global_position.y - 0.85) < 0.15 and hurts[0] == 0, "player can stand on the bridge over the pit")
	move_player(Vector3(24, 1, 15))
	await wait(0.5)
	rat_manager.command(Rat_Manager.COMMAND.FOLLOW)
	await wait(0.5)
	check(rat_manager.rats_out.size() == 5, "Follow releases the bridge and brings the rats back")

	# hazards
	var rat: Rat = rat_manager.rats_out[0]
	rat.global_position = Vector3(23, -0.7, 11)
	await wait(1.0)
	check(rat.state == Rat.State.FAINTED, "a rat faints on spikes")
	check(rat_manager.rat_total == 6, "the rat count does not drop while a rat is fainted")
	await wait(12.0)
	check(rat.state == Rat.State.FOLLOW and rat.global_position.distance_to(player.global_position) < 4.0, "the fainted rat rejoins the player")
	var safe := player.global_position
	move_player(Vector3(24, 0, 12), false)
	await wait(1.5)
	check(hurts[0] > 0 and player.global_position.distance_to(safe) < 1.0, "spikes send the player back to safe ground")

	# two-lock gate
	var plate2 := things.get_node("PressurePlate2") as PressurePlate
	player.aim_point = plate2.global_position
	rat_manager.command(Rat_Manager.COMMAND.MOVE_TO)
	await wait(5.0)
	var gate := things.get_node("Gate")
	if not plate2.is_pressed():
		for r in rat_manager.rats_out: print("  rat ", r.state, " ", r.global_position.snapped(Vector3.ONE * 0.1), " target ", plate2.global_position)
	check(plate2.is_pressed() and not gate.is_open, "plate alone does not open the gate")
	things.get_node("Lever2").interact(player)
	check(gate.is_open, "plate and lever together open the gate")

	# pipe to the hideout
	move_player(Vector3(24, 1, 24.5))
	await wait(1.0)
	check(manager._level.name == "Hideout", "the pipe leads to the hideout")
	check(rat_manager.rats_out[0].global_position.distance_to(player.global_position) < 3.0, "rats travel with the player")
	move_player(Vector3(7, 1, 1.5))
	await wait(1.0)
	check(manager._level.name == "Hideout", "the final pipe is sealed")

	# zones: each exit pipe marks its zone done, both together unseal the final pipe
	for zone: Array in [["left_zone", Vector3(10.5, 1, -19), "left"], ["right_zone", Vector3(10.5, 1, -15), "right"]]:
		manager.go_to("res://Scenes/levels/%s.tscn" % zone[0])
		await wait(1.0)
		check(player.is_on_floor(), "%s loads and the player stands in it" % zone[0])
		move_player(zone[1])
		await wait(1.0)
		check(manager._level.name == "Hideout" and manager.zones_done.has(zone[2]), "%s exit pipe returns to the hideout and marks the zone done" % zone[0])
	move_player(Vector3(7, 1, 1.5))
	await wait(1.0)
	check(manager._level.name == "FinalZone" and player.is_on_floor(), "the final pipe opens once both zones are done")

	print("smoke test: %d failure(s)" % failures)
	quit(failures)


func move_player(pos: Vector3, mark_safe := true) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	if mark_safe:
		player.reset_safe_spot()


func press_esc() -> void:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	await process_frame


func wait(seconds: float) -> void:
	await create_timer(seconds, true, true).timeout


func check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1
