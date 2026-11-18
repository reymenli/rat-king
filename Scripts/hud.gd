class_name HUD
extends CanvasLayer
# Crosshair, rat and key counters, the "E" prompt and the dialogue box.

const SPEAKER_COLORS := {"Rat King": Color(1.0, 0.82, 0.25), "Scientist": Color(0.45, 0.85, 1.0)}
const PORTRAITS := {
	"Rat King": preload("res://assets/ui/portraits/rat_king.png"),
	"Scientist": preload("res://assets/ui/portraits/scientist.png"),
}

@onready var crosshair: ColorRect = $Crosshair
@onready var rat_count: Label = $RatCount
@onready var key_count: Label = $KeyCount
@onready var prompt: Label = $Prompt
@onready var flash: ColorRect = $Flash
@onready var dialogue: Control = $Dialogue
@onready var speaker_label: Label = $Dialogue/Margin/Cols/Rows/Speaker
@onready var line_label: RichTextLabel = $Dialogue/Margin/Cols/Rows/Line
@onready var portrait: TextureRect = $Dialogue/Margin/Cols/Portrait

var _player: CharacterBody3D
var _queue: Array = []  # [speaker, text] pairs waiting to be shown
var _time_left := 0.0


func _ready() -> void:
	add_to_group("hud")
	dialogue.hide()
	_player = get_tree().get_first_node_in_group("player")
	var rats := get_tree().get_first_node_in_group("rat_manager") as Rat_Manager
	rats.count_changed.connect(_show_rats)
	rats.selection_changed.connect(func(n: int) -> void:
		_selected = n
		_show_rats(rats.rat_total))
	_show_rats(rats.rat_total)
	_player.keys_changed.connect(_show_keys)
	_show_keys(_player.keys)
	_player.hover_changed.connect(_show_prompt)
	_show_prompt(null)
	_player.got_hurt.connect(_flash_red)


var _selected := 0

func _show_rats(total: int) -> void:
	rat_count.text = "Rats x%d" % total + ("  (%d tagged)" % _selected if _selected > 0 else "")


func _show_keys(count: int) -> void:
	key_count.text = "Keys x%d" % count


func _show_prompt(target: Interactable) -> void:
	prompt.text = ("[E]  " + target.prompt_text) if target else ""


func _flash_red() -> void:
	flash.color.a = 0.45
	create_tween().tween_property(flash, "color:a", 0.0, 0.5)


# Queues lines for the dialogue box. The game keeps running while they show.
func say(speaker: String, lines: PackedStringArray) -> void:
	for line in lines:
		_queue.append([speaker, line])
	if not dialogue.visible:
		_next_line()


func _next_line() -> void:
	if _queue.is_empty():
		dialogue.hide()
		return
	var entry: Array = _queue.pop_front()
	speaker_label.text = entry[0]
	var color: Color = SPEAKER_COLORS.get(entry[0], Color.WHITE)
	speaker_label.modulate = color
	portrait.texture = PORTRAITS.get(entry[0])
	line_label.text = entry[1]
	line_label.visible_ratio = 0.0
	dialogue.show()
	_time_left = 2.0 + entry[1].length() * 0.05  # time to read, then the next line plays by itself


func _process(delta: float) -> void:
	var on_target: bool = _player.aimed_rat() != null or is_instance_valid(_player.hovered)
	crosshair.color = Color(1.0, 0.82, 0.25) if on_target else Color.WHITE
	if not dialogue.visible:
		return
	line_label.visible_ratio = minf(1.0, line_label.visible_ratio + delta * 40.0 / maxf(1.0, line_label.text.length()))
	_time_left -= delta
	if _time_left <= 0.0:
		_next_line()
