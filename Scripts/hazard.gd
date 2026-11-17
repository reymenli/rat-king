class_name Hazard
extends Area3D
# Spikes, electric floor, lasers. Rats that touch it faint. The player is put back on safe ground.

@export var animation_player: AnimationPlayer  # optional
@export var start_animation: StringName = &"Extend"


func _ready() -> void:
	if animation_player:
		animation_player.play(start_animation)


func _physics_process(_delta: float) -> void:
	# Polled instead of using body_entered so nothing can stand inside it unharmed.
	for body in get_overlapping_bodies():
		if body is Rat:
			body.faint()
		elif body.is_in_group("player"):
			body.hurt()
