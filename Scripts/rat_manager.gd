class_name Rat_Manager
extends Node
signal count_changed(total:int)

@export var player: CharacterBody3D
@export var rat_scene: PackedScene

const MAX_FOLLOWING = 5
var rats_out: Array[Rat] = []
var rat_total : int
var rat_available : int

enum COMMAND {
	FOLLOW,
	STAY,
	MOVE_TO
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
