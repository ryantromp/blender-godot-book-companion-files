class_name TractorSwitch
extends Interactable
## The tractor stays where it is parked. One use starts it, the next stops it: the wheels
## clip runs all the time and its speed rises to 1 or falls to 0.

@export var animation_player: AnimationPlayer
@export var ramp_time: float = 1.0

var running: bool = false

var _tween: Tween


func _ready() -> void:
	super()
	animation_player.play(&"mach_tractor_drive")
	animation_player.speed_scale = 0.0


func interact(farmer: Farmer) -> void:
	running = not running
	prompt_text = "Stop the tractor" if running else "Start the tractor"
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(animation_player, "speed_scale", 1.0 if running else 0.0, ramp_time)
	interacted.emit(farmer)
