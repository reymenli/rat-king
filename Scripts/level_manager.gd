class_name Level_Manager
extends Node
# The main node. Holds the player, the rats and the UI, and swaps the current area in and out.

@export var player: CharacterBody3D
@export var rat_manager: Rat_Manager
@export var hud: HUD
@export_file("*.tscn") var start_level := "res://Scenes/levels/tutorial.tscn"

var zones_done := {}  # zone name -> true, used to unseal the final pipe
var dialogue_seen := {}  # "Area/Trigger" -> true, so lines play once per run
var has_cheese := false  # taken in the final zone, shows on the hideout table
var won := false  # the cheese has been brought home at least once
var last_rat_joined := false  # the 100th rat came out from behind the scientist
var scientist_gone := false  # Ratazord knocked him out of the way

var _level: Node


func _ready() -> void:
	add_to_group("level_manager")
	go_to(start_level)


func show_win() -> void:
	add_child(preload("res://Scripts/win_screen.gd").new())


# Testing shortcut from Settings: both wings done, 99 rats in the bank, straight to the final zone.
func skip_to_final() -> void:
	zones_done["left"] = true
	zones_done["right"] = true
	rat_manager.add_to_bank(maxi(0, 99 - rat_manager.rat_total))
	go_to("res://Scenes/levels/final_zone.tscn")


# Loads an area and puts the player on the Marker3D called `spawn` inside it.
func go_to(level_path: String, spawn := "PlayerSpawn") -> void:
	if _level:
		remove_child(_level)
		_level.queue_free()
	_level = (load(level_path) as PackedScene).instantiate()
	add_child(_level)
	move_child(_level, 0)

	var marker := _level.get_node_or_null(spawn) as Node3D
	if marker == null:
		marker = _level.get_node("PlayerSpawn")
	player.global_position = marker.global_position
	player.camera_pivot.rotation = Vector3(-0.15, marker.global_rotation.y, 0)  # looking slightly down
	player.velocity = Vector3.ZERO
	player.reset_safe_spot()
	rat_manager.gather()
