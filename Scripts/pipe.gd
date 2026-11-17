extends Area3D
# A sewage pipe mouth. Walking in takes the player (and the rats) to another area.

@export_file("*.tscn") var target_level: String
@export var target_spawn := "PlayerSpawn"  # name of a Marker3D in the target level
## Zone that counts as finished once the player leaves through this pipe.
@export var completes_zone := ""
## Zones that must be finished before this pipe opens.
@export var requires_zones: PackedStringArray
@export var sealed_line := "Sealed tight. I need to clear the Left and Right zones first."


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var manager := get_tree().get_first_node_in_group("level_manager") as Level_Manager
	for zone in requires_zones:
		if not manager.zones_done.has(zone):
			manager.hud.say("Rat King", [sealed_line])
			return
	if completes_zone != "":
		manager.zones_done[completes_zone] = true
	manager.go_to.call_deferred(target_level, target_spawn)  # deferred: we are inside a physics callback
