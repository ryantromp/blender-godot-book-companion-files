class_name ToolBelt
extends Node
## What the farmer holds. Keys 1 to 4 pick the hoe, the seeds, the can or bare hands, and
## Shift+wheel steps through them. Pressing 2 again while holding seeds picks the next crop.
## The tool bar of the HUD (Chapter 29) shows what it holds and calls select() when a button is clicked.

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


func _unhandled_input(event: InputEvent) -> void:
	for index: int in TOOLS.size():
		if event.is_action_pressed("tool_%d" % (index + 1)):
			select(TOOLS[index])
	var step: int = int(event.is_action_pressed("tool_next")) - int(event.is_action_pressed("tool_prev"))
	if step != 0:
		select(TOOLS[posmod(TOOLS.find(current) + step, TOOLS.size())])
