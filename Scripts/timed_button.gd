class_name TimedButton
extends Interactable
# Player only. Stays active for a set time after being pressed, then turns itself off.

signal pressed
signal released

@export_group("Nodes")
@export var animation_player: AnimationPlayer
@export var label: Label3D  # shows the seconds left

@export_group("Button Settings")
@export_range(1.0, 30.0) var active_seconds := 10.0

var _time_left := 0.0


func _ready() -> void:
	super()
	prompt_text = "Press button"
	label.text = ""


func is_pressed() -> bool:
	return _time_left > 0.0


func interact(_player: CharacterBody3D) -> void:
	var was_pressed := is_pressed()
	_time_left = active_seconds  # pressing again restarts the timer
	if not was_pressed:
		animation_player.play("Press")
		pressed.emit()


func _process(delta: float) -> void:
	if not is_pressed():
		return
	_time_left -= delta
	label.text = str(ceili(_time_left)) if is_pressed() else ""
	if not is_pressed():
		animation_player.play("Release")
		released.emit()
