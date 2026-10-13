@tool
class_name ScratchCropData
extends Resource

@export var crop_name: String = ""
@export var days_to_grow: int = 3
@export var sell_price: int = 5
@export var color: Color = Color.WHITE

func describe() -> String:
	return "%s: %d days, %d coins" % [crop_name, days_to_grow, sell_price]
