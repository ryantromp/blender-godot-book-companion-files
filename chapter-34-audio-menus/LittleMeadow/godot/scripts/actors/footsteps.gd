class_name Footsteps
extends Node

const STEP_LENGTH: Dictionary = {&"walk": 0.5, &"run": 0.88}

var _walked: float = 0.0

@onready var farmer: Farmer = get_parent() as Farmer


func _physics_process(delta: float) -> void:
	var length: float = STEP_LENGTH.get(farmer.animation.current_state(), 0.0)
	if length == 0.0 or not farmer.is_on_floor():
		_walked = length * 0.5
		return
	_walked += farmer.speed * delta
	if _walked >= length:
		_walked -= length
		AudioBus.play(&"footstep", farmer.global_position)
