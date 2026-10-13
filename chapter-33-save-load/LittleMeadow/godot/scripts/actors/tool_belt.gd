class_name ToolBelt
extends Node

const TOOLS: Array[StringName] = [&"hoe", &"seeds", &"can", &"hand"]

@export var crops: Array[CropData] = []

var current: StringName = &"hand"
var crop: CropData


func _ready() -> void:
	if not crops.is_empty():
		crop = crops[0]


func select(tool_name: StringName) -> void:
	if tool_name == &"seeds" and current == &"seeds" and not crops.is_empty():
		crop = crops[(crops.find(crop) + 1) % crops.size()]
	current = tool_name
	Events.tool_changed.emit(current, crop)


func save_key() -> String:
	return "tools"


func to_save() -> Dictionary:
	return {"current": String(current), "crop": String(crop.id) if crop != null else ""}


func from_save(data: Dictionary) -> void:
	current = StringName(data["current"]) if TOOLS.has(StringName(data["current"])) else &"hand"
	crop = crops[0] if not crops.is_empty() else null
	for candidate: CropData in crops:
		if String(candidate.id) == String(data["crop"]):
			crop = candidate
	Events.tool_changed.emit(current, crop)


func _unhandled_input(event: InputEvent) -> void:
	for index: int in TOOLS.size():
		if event.is_action_pressed("tool_%d" % (index + 1)):
			select(TOOLS[index])
	var step: int = int(event.is_action_pressed("tool_next")) - int(event.is_action_pressed("tool_prev"))
	if step != 0:
		select(TOOLS[posmod(TOOLS.find(current) + step, TOOLS.size())])
