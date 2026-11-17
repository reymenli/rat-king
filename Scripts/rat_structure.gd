class_name Rat_Structure
extends StaticBody3D

enum Structure {
	STACK,
	BRIDGE
}

const RAT_HEIGHT := 0.25
const RAT_LENGTH := 0.7
const WIDTH := 1.2
const RAT_MODEL := preload("res://assets/models/characters/rats/SK_Rat_E.glb")
const RATS_ACROSS := 4  # rats side by side, so the structure looks as wide as it is

@onready var collision: CollisionShape3D = $CollisionShape3D

# feet is for the floor, or where we're starting. yaw is the way the player is facing
func build (struct: Structure, count: int, feet: Vector3, yaw: float) -> void:
	global_position = feet
	rotation.y = yaw

	var box_size: Vector3
	var center: Vector3
	if struct == Structure.STACK:
		box_size = Vector3(WIDTH, count * RAT_HEIGHT, WIDTH)
		center = Vector3(0, box_size.y / 2.0, 0)
	if struct == Structure.BRIDGE:
		box_size = Vector3(WIDTH, RAT_HEIGHT, count * RAT_LENGTH)
		center = Vector3(0, -box_size.y / 2.0, -box_size.z / 2.0)

	var box := BoxShape3D.new()
	box.size = box_size
	collision.shape = box
	collision.position = center

	# Fill the box with rats: rows of rats lying nose to tail, one layer per RAT_HEIGHT.
	var rows := roundi(box_size.z / RAT_LENGTH)
	var layers := roundi(box_size.y / RAT_HEIGHT)
	for layer in layers:
		for row in rows:
			for i in RATS_ACROSS:
				var rat := RAT_MODEL.instantiate() as Node3D
				add_child(rat)
				rat.position = center + Vector3(
					(i - (RATS_ACROSS - 1) / 2.0) * WIDTH / RATS_ACROSS,
					(layer - layers / 2.0) * RAT_HEIGHT,
					(row - (rows - 1) / 2.0) * RAT_LENGTH)
				rat.rotation.y = PI * ((row + layer + i) % 2)  # alternate so it reads as a pile
