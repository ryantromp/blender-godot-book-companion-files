class_name CanLabel
extends CanvasLayer
## A plain text label for the water level, in the top left corner. Chapter 29 replaces it with the real HUD.

@export var can: WateringCan

var _label := Label.new()


func _ready() -> void:
	_label.position = Vector2(16.0, 12.0)
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color("14191A"))
	add_child(_label)
	_show(can.water_level, can.capacity)
	Events.water_level_changed.connect(_show)


func _show(level: int, capacity: int) -> void:
	_label.text = "Water %d / %d" % [level, capacity]
