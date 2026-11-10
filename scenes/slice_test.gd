extends Node3D
# Throwaway viewer for the Blender slice: rat, sliding door and lever.
# 1 Idle   2 Run   3 Faint   D door open/close   L lever on/off

var door_open := false
var lever_on := false

func _player(node: Node) -> AnimationPlayer:
	return node.find_children("*", "AnimationPlayer", true, false)[0]

func _ready() -> void:
	$Camera3D.look_at_from_position(Vector3(2.0, 1.2, 5.0), Vector3(2.0, 0.9, 0.0))
	_player($Rat).play("Run")
	var help := Label.new()
	help.text = "1 Idle   2 Run   3 Faint   D door   L lever"
	help.position = Vector2(16, 12)
	var layer := CanvasLayer.new()
	layer.add_child(help)
	add_child(layer)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1: _player($Rat).play("Idle")
		KEY_2: _player($Rat).play("Run")
		KEY_3: _player($Rat).play("Faint")
		KEY_D:
			door_open = not door_open
			_player($Door).play("Open" if door_open else "Close")
		KEY_L:
			lever_on = not lever_on
			_player($Lever).play("On" if lever_on else "Off")
