class_name WateringCan
extends Node
## The farmer's watering can. A whole number of waterings, no items yet (Chapter 29).

@export var capacity: int = 5

var water_level: int = 0


func is_full() -> bool:
	return water_level >= capacity


func is_empty() -> bool:
	return water_level <= 0


func refill() -> void:
	water_level = capacity
	Events.water_level_changed.emit(water_level, capacity)


## Uses one watering. Returns false, and changes nothing, when the can is empty.
func use() -> bool:
	if is_empty():
		return false
	water_level -= 1
	Events.water_level_changed.emit(water_level, capacity)
	return true
