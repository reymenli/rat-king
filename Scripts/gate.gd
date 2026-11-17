extends Node3D
# A door or gate. It opens while every wired plate, lever and button is active.

@export_group("Nodes")
@export var animation_player: AnimationPlayer

@export_group("Wiring")
@export var plates: Array[PressurePlate] = []
@export var levers: Array[Lever] = []
@export var buttons: Array[TimedButton] = []

@export_group("Animations")
@export var open_animation: StringName = &"Open"
@export var close_animation: StringName = &"Close"

var is_open := false

func _ready() -> void:
	if plates.is_empty() and levers.is_empty() and buttons.is_empty():
		push_warning("Gate '%s' has nothing wired to it." % name)
		return

	for plate in plates:
		if plate == null:
			push_warning("Gate '%s' has an empty plate slot." % name)
			continue
		plate.pressed.connect(_update)
		plate.released.connect(_update)

	for lever in levers:
		if lever == null:
			push_warning("Gate '%s' has an empty lever slot." % name)
			continue
		lever.turned_on.connect(_update)
		lever.turned_off.connect(_update)

	for button in buttons:
		if button == null:
			push_warning("Gate '%s' has an empty button slot." % name)
			continue
		button.pressed.connect(_update)
		button.released.connect(_update)

func _update() -> void:
	var should_open := _all_satisfied()
	if should_open == is_open:
		return

	is_open = should_open
	animation_player.play(open_animation if is_open else close_animation)

func _all_satisfied() -> bool:
	for plate in plates:
		if plate == null or not plate.is_pressed():
			return false
	for lever in levers:
		if lever == null or not lever.is_on():
			return false
	for button in buttons:
		if button == null or not button.is_pressed():
			return false
	return true
