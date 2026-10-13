class_name WaterPump
extends Interactable
## The pump by the field. One use plays the lever clip and, when it ends, fills the watering can.

@export var animation_player: AnimationPlayer

var _busy: bool = false


func can_interact(farmer: Farmer) -> bool:
	return not _busy and not farmer.can.is_full()


func interact(farmer: Farmer) -> void:
	_busy = true
	animation_player.play(&"mach_pump_pump")
	await animation_player.animation_finished
	farmer.can.refill()
	_busy = false
	interacted.emit(farmer)
