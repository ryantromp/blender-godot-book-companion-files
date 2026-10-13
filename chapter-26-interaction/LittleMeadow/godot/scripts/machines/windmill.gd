class_name Windmill
extends Node
## Keeps the blades turning. The wind changes slowly, so the speed of the clip drifts
## between base_speed - gust and base_speed + gust.

@export var animation_player: AnimationPlayer
@export var base_speed: float = 1.0
@export var gust: float = 0.4
@export var gust_period: float = 30.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	animation_player.speed_scale = base_speed + gust * sin(_time * TAU / gust_period)
