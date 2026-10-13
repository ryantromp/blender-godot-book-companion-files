@tool
extends EditorScript

func crop_value(days: int, price: float = 2.5) -> float:
	return days * price

func describe(crop: String, value: float) -> String:
	return "%s is worth %.1f coins" % [crop, value]

func _run() -> void:
	print(describe("carrot", crop_value(4)))
	print(describe("pumpkin", crop_value(10, 3.0)))
