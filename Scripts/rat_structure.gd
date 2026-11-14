class_name Rat_Structure
extends StaticBody3D

enum Structure {
	STACK,
	BRIDGE
}

const RAT_HEIGHT := 0.25
const RAT_LENGTH := 0.7
const WIDTH := 1.2

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var MeshInstance: MeshInstance3D = $placeholder

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
	
	var box_mesh := BoxMesh.new()
	box.size = box_size
	MeshInstance.mesh = box_mesh
	MeshInstance.position = center

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
