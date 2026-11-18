extends CanvasLayer
# Shown once when the cheese is brought home. Pauses the game. "keep playin" goes back to the
# hideout with the cheese on the table as a trophy, "main menu" leaves.

const TITLE := "res://Scenes/main_menu.tscn"


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	center.add_child(rows)

	var title := Label.new()
	title.text = "THE CHEESE IS OURS"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	var line := Label.new()
	line.text = "the king brought it home. long live the king."
	line.add_theme_font_size_override("font_size", 22)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(line)

	var keep := _button("keep playin", rows)
	keep.pressed.connect(func() -> void:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		queue_free())
	_button("main menu", rows).pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(TITLE))
	keep.grab_focus()


func _button(text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 56)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 26)
	parent.add_child(button)
	return button
