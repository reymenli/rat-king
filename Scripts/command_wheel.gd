class_name Command_Wheel
extends Control

signal ability_chosen(ability: Rat_Manager.COMMAND)

@export_group("Command_Slots")
@export var follow : Button 
@export var stay : Button 
@export var bridge : Button 
@export var stack : Button 
@export var ratazord : Button 
@export var fist : Button 
@export var vehicle : Button 


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_follow_pressed() -> void:
	print("Pressed Follow")
	ability_chosen.emit(Rat_Manager.COMMAND.FOLLOW)
	pass # Replace with function body.


func _on_stay_pressed() -> void:
	print("Pressed Stay")
	ability_chosen.emit(Rat_Manager.COMMAND.STAY)
	pass # Replace with function body.

func _on_direct_pressed() -> void:
	print("Pressed direct / move_to")
	ability_chosen.emit(Rat_Manager.COMMAND.MOVE_TO)
	pass # Replace with function body.

func _on_bridge_pressed() -> void:
	print("Pressed bridge")
	ability_chosen.emit(Rat_Manager.COMMAND.BRIDGE)
	pass # Replace with function body.


func _on_stack_pressed() -> void:
	print("Pressed stack")
	ability_chosen.emit(Rat_Manager.COMMAND.STACK)
	pass # Replace with function body.


func _on_ratazord_pressed() -> void:
	print("Pressed")
	pass # Replace with function body.


func _on_fist_pressed() -> void:
	print("Pressed")
	pass # Replace with function body.


func _on_vehicle_pressed() -> void:
	print("Pressed")
	pass # Replace with function body.
