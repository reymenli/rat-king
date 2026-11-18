class_name Rat_Structure
extends StaticBody3D

enum Structure {
	STACK,
	BRIDGE
}

const RAT_HEIGHT := 0.25
const RAT_LENGTH := 1.1  # bridge length per rat: 6 rats span a 6 m pit, a walking jump only clears about 4.6 m
const MODEL_LENGTH := 0.6  # spacing of the rat models that fill the box
const WIDTH := 1.2
const RAT_MODELS: Array[PackedScene] = [
	preload("res://assets/models/characters/rats/SK_Rat_E.glb"),
	preload("res://assets/models/characters/rats/SK_Rat_F.glb"),
	preload("res://assets/models/characters/rats/SK_Rat_G.glb"),
]
const FORM_TIME := 0.6  # seconds from the first rat hopping in to the last, so they don't move in lockstep
const RATS_ACROSS := 4  # rats side by side, so the structure looks as wide as it is

@onready var collision: CollisionShape3D = $CollisionShape3D

# Size and centre of the structure's box, relative to `feet`. Also used for the placement ghost.
static func box_size_for(struct: Structure, count: int) -> Vector3:
	if struct == Structure.STACK:
		return Vector3(WIDTH, count * RAT_HEIGHT, WIDTH)
	return Vector3(WIDTH, RAT_HEIGHT, count * RAT_LENGTH)


static func box_center_for(struct: Structure, box_size: Vector3) -> Vector3:
	if struct == Structure.STACK:
		return Vector3(0, box_size.y / 2.0, 0)
	return Vector3(0, -box_size.y / 2.0, -box_size.z / 2.0)


# feet is for the floor, or where we're starting. yaw is the way the player is facing
func build (struct: Structure, count: int, feet: Vector3, yaw: float) -> void:
	global_position = feet
	rotation.y = yaw

	var box_size := box_size_for(struct, count)
	var center := box_center_for(struct, box_size)

	var box := BoxShape3D.new()
	box.size = box_size
	collision.shape = box
	collision.position = center

	# Fill the box with rats: rows of rats lying nose to tail, one layer per RAT_HEIGHT.
	var rows := maxi(roundi(box_size.z / MODEL_LENGTH), 1)
	var layers := roundi(box_size.y / RAT_HEIGHT)
	var stagger := FORM_TIME / (layers * rows * RATS_ACROSS)
	for layer in layers:
		for row in rows:
			for i in RATS_ACROSS:
				var rat := RAT_MODELS[(row + layer * 2 + i) % RAT_MODELS.size()].instantiate() as Node3D
				add_child(rat)
				rat.position = center + Vector3(
					(i - (RATS_ACROSS - 1) / 2.0) * WIDTH / RATS_ACROSS,
					(layer - layers / 2.0) * RAT_HEIGHT,
					(row - (rows - 1) / 2.0) * box_size.z / rows)
				rat.rotation.y = PI * ((row + layer + i) % 2)  # alternate so it reads as a pile
				_hop_in(rat, (layer * rows * RATS_ACROSS + row * RATS_ACROSS + i) * stagger)


# Each rat holds its first frame, hops into place (Form) and then holds the weight (Brace, loops).
func _hop_in(rat: Node3D, delay: float) -> void:
	var anim := rat.get_node("AnimationPlayer") as AnimationPlayer
	anim.play("Form")
	anim.pause()
	anim.queue("Brace")
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(anim):
		anim.play()


# Rats hop off (HopOut), then the structure goes away. Collision goes first so nobody stands on air.
func release() -> void:
	collision.set_deferred("disabled", true)
	var longest := 0.0
	for rat in get_children():
		var anim := rat.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim:
			anim.clear_queue()
			anim.play("HopOut")
			longest = maxf(longest, anim.current_animation_length)
	await get_tree().create_timer(longest).timeout
	queue_free()
