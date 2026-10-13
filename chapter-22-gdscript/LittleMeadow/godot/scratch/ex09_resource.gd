@tool
extends EditorScript

func _run() -> void:
	var tomato: ScratchCropData = load("res://scratch/tomato.tres")
	print(tomato.describe())
	var copy: ScratchCropData = tomato.duplicate()
	copy.sell_price = 99
	print("copy ", copy.sell_price, ", original ", tomato.sell_price)
	print("colour ", tomato.color.to_html())
