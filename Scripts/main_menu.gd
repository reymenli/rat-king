extends Control
# Title screen: Play, Settings (volume and the controls list) and Exit.
# With pause_menu on, the same menu is the in-game pause menu: Esc opens and closes it over the
# frozen game, and it adds Resume and Main Menu.

const GAME := "res://Scenes/level_manager.tscn"
const TITLE := "res://Scenes/main_menu.tscn"
const CONTROLS := """WASD  move        Shift  run        Space  jump
Mouse  look        Right click (hold)  aim        Scroll  zoom
E  interact        V  first person        Enter  next line
Hold Q  command wheel: move onto a slice and let go to pick it.
Let go in the middle, or right click, to cancel.
Aim at one rat to command only that rat, or left click rats to tag a group.
Esc  pause menu"""

@export var pause_menu := false

@onready var main_buttons: Control = $Center/Rows/Main
@onready var settings: Control = $Center/Rows/Settings
@onready var volume: HSlider = $Center/Rows/Settings/Volume
@onready var play: Button = $Center/Rows/Main/Play
@onready var to_title: Button = $Center/Rows/Main/MainMenu


func _ready() -> void:
	$Center/Rows/Settings/Controls.text = CONTROLS
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0
	volume.value_changed.connect(func(v: float) -> void: AudioServer.set_bus_volume_db(0, linear_to_db(v / 100.0)))
	$Center/Rows/Main/Settings.pressed.connect(_show_settings.bind(true))
	$Center/Rows/Main/Exit.pressed.connect(get_tree().quit)
	$Center/Rows/Settings/Back.pressed.connect(_show_settings.bind(false))
	to_title.visible = pause_menu
	if pause_menu:
		process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working while the game is paused
		$Background.color.a = 0.6  # dim the game instead of hiding it
		play.text = "Resume"
		$Center/Rows/Main/Exit.text = "Quit Game"
		play.pressed.connect(_set_paused.bind(false))
		to_title.pressed.connect(_go_to_title)
		hide()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		play.pressed.connect(func() -> void: get_tree().change_scene_to_file(GAME))
		_show_settings(false)


func _unhandled_input(event: InputEvent) -> void:
	if not pause_menu or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if visible and settings.visible:
		_show_settings(false)  # Esc in Settings goes back a page first
	elif visible:
		_set_paused(false)
	elif not get_tree().paused:  # the command wheel also pauses, leave that alone
		_set_paused(true)


func _set_paused(value: bool) -> void:
	visible = value
	get_tree().paused = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	if value:
		_show_settings(false)


func _go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE)


func _show_settings(value: bool) -> void:
	settings.visible = value
	main_buttons.visible = not value
	(volume if value else play).grab_focus()
