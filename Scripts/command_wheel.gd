class_name Command_Wheel
extends Control
# Radial command wheel, drawn at the centre of the screen where the crosshair is.
# Hold Q to open it (the game pauses), move the mouse onto a slice and let go of Q to pick it.
# Letting go with the cursor still in the middle, or right clicking, cancels.

signal ability_chosen(ability: Rat_Manager.COMMAND)

const OUTER_RADIUS := 230.0
const INNER_RADIUS := 80.0  # the cancel zone in the middle
const GAP := 0.03  # radians of empty space between slices

# Clockwise from the top. [label, command (-1 = not in the game yet), rats needed]
const SLICES := [
	["Follow", Rat_Manager.COMMAND.FOLLOW, 0],
	["Stay", Rat_Manager.COMMAND.STAY, 0],
	["Bridge", Rat_Manager.COMMAND.BRIDGE, Rat_Manager.BRIDGE_RATS],
	["Vehicle", -1, 20],
	["Ratazord", -1, 100],
	["Fist", -1, 30],
	["Stack", Rat_Manager.COMMAND.STACK, Rat_Manager.STACK_RATS],
	["Go To", Rat_Manager.COMMAND.MOVE_TO, 0],
]

var rat_total := 0  # kept up to date by the Rat_Manager, used to grey out slices

var _open := false
var _cursor := Vector2.ZERO  # virtual cursor, measured from the centre of the wheel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working while the game is paused
	hide()


func _input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed("command_wheel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_set_open(true)
		return

	if event.is_action_released("command_wheel"):
		var slice := _hovered_slice()
		_set_open(false)
		if slice >= 0 and _is_enabled(slice):
			ability_chosen.emit(SLICES[slice][1])
	elif event.is_action_pressed("rmb"):
		_set_open(false)
	elif event is InputEventMouseMotion:
		_cursor = (_cursor + event.relative).limit_length(OUTER_RADIUS)
		queue_redraw()
	get_viewport().set_input_as_handled()  # nothing else reacts while the wheel is open


func _set_open(value: bool) -> void:
	_open = value
	_cursor = Vector2.ZERO
	visible = value
	get_tree().paused = value
	queue_redraw()


func _is_enabled(slice: int) -> bool:
	return SLICES[slice][1] >= 0 and rat_total >= SLICES[slice][2]


# Which slice the cursor is on, or -1 while it is still in the middle.
func _hovered_slice() -> int:
	if _cursor.length() < INNER_RADIUS:
		return -1
	var angle := atan2(_cursor.x, -_cursor.y)  # 0 at the top, growing clockwise
	return posmod(roundi(angle / (TAU / SLICES.size())), SLICES.size())


func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(-screen, screen * 2.0), Color(0, 0, 0, 0.4))  # dim the paused game

	var font := get_theme_default_font()
	var step := TAU / SLICES.size()
	var hovered := _hovered_slice()
	for i in SLICES.size():
		var enabled := _is_enabled(i)
		var color := Color(0.08, 0.08, 0.1, 0.8)
		if i == hovered:
			color = Color(1.0, 0.82, 0.25, 0.95) if enabled else Color(0.45, 0.2, 0.2, 0.9)
		elif not enabled:
			color = Color(0.25, 0.25, 0.27, 0.55)
		var middle := i * step - PI / 2.0  # draw angles start at +X, so shift the top slice up
		draw_colored_polygon(_slice_points(middle - step / 2.0 + GAP, middle + step / 2.0 - GAP), color)

		var text_color := Color.BLACK if (i == hovered and enabled) else (Color.WHITE if enabled else Color(1, 1, 1, 0.45))
		var at := Vector2.from_angle(middle) * (INNER_RADIUS + OUTER_RADIUS) / 2.0
		_draw_centered(font, at, SLICES[i][0], 20, text_color)
		if SLICES[i][2] > 0:
			_draw_centered(font, at + Vector2(0, 22), "%d rats" % SLICES[i][2], 14, text_color)

	draw_circle(Vector2.ZERO, INNER_RADIUS - 8.0, Color(0.08, 0.08, 0.1, 0.8))
	_draw_centered(font, Vector2.ZERO, "Cancel" if hovered < 0 else SLICES[hovered][0], 18, Color.WHITE)
	draw_line(Vector2.ZERO, _cursor, Color(1, 1, 1, 0.3), 2.0)
	draw_circle(_cursor, 7.0, Color.WHITE)


func _slice_points(from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 13:
		points.append(Vector2.from_angle(lerpf(from, to, i / 12.0)) * OUTER_RADIUS)
	for i in 13:
		points.append(Vector2.from_angle(lerpf(to, from, i / 12.0)) * INNER_RADIUS)
	return points


func _draw_centered(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at + Vector2(-width / 2.0, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
