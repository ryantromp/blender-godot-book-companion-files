class_name WateringCan
extends Node

@export var capacity: int = 5

var water_level: int = 0


func is_full() -> bool:
	return water_level >= capacity


func save_key() -> String:
	return "can"


func to_save() -> Dictionary:
	return {"level": water_level}


func from_save(data: Dictionary) -> void:
	water_level = clampi(int(data["level"]), 0, capacity)
	Events.water_level_changed.emit(water_level, capacity)


func is_empty() -> bool:
	return water_level <= 0


func refill() -> void:
	water_level = capacity
	Events.water_level_changed.emit(water_level, capacity)


func use() -> bool:
	if is_empty():
		return false
	water_level -= 1
	Events.water_level_changed.emit(water_level, capacity)
	return true
