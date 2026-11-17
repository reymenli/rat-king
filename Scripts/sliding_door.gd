extends "res://Scripts/gate.gd"
# Same wiring as a gate. `plate` is kept so scenes made for the first version still work.

@export var plate: PressurePlate


func _ready() -> void:
	if plate and plate not in plates:
		plates.append(plate)
	super()
