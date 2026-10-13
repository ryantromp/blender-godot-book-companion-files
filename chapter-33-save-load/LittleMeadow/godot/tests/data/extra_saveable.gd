extends Node

var fuel: int = 1


func _ready() -> void:
	add_to_group(&"saveable")


func save_key() -> String:
	return "extra"


func to_save() -> Dictionary:
	return {"fuel": fuel}


func from_save(data: Dictionary) -> void:
	fuel = int(data["fuel"])
