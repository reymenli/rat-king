extends Control
# Title screen: Play, Settings (volume and the controls list) and Exit.

const GAME := "res://Scenes/level_manager.tscn"
const CONTROLS := """WASD  move        Shift  run        Space  jump
Mouse  look        Right click (hold)  aim        Scroll  zoom
E  interact        V  first person        Enter  next line
Hold Q  command wheel: move onto a slice and let go to pick it.
Let go in the middle, or right click, to cancel.
Aim at one rat to command only that rat."""

@onready var main_buttons: Control = $Center/Rows/Main
@onready var settings: Control = $Center/Rows/Settings
@onready var volume: HSlider = $Center/Rows/Settings/Volume


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Center/Rows/Settings/Controls.text = CONTROLS
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0
	volume.value_changed.connect(func(v: float) -> void: AudioServer.set_bus_volume_db(0, linear_to_db(v / 100.0)))
	$Center/Rows/Main/Play.pressed.connect(func() -> void: get_tree().change_scene_to_file(GAME))
	$Center/Rows/Main/Settings.pressed.connect(_show_settings.bind(true))
	$Center/Rows/Main/Exit.pressed.connect(get_tree().quit)
	$Center/Rows/Settings/Back.pressed.connect(_show_settings.bind(false))
	_show_settings(false)


func _show_settings(value: bool) -> void:
	settings.visible = value
	main_buttons.visible = not value
	(volume if value else $Center/Rows/Main/Play).grab_focus()
