extends Node


func _ready() -> void:
	var label: Label = $Label
	label.text = "Little Meadow %s" % ProjectSettings.get_setting("application/config/version")
	print(label.text)
