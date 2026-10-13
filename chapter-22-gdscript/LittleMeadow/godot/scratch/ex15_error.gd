@tool
extends EditorScript

func _run() -> void:
	var prices: Dictionary = {"carrot": 5}
	var total: int = 3
	print("carrot ", prices["carrot"] * total)
	print("pumpkin ", prices["pumpkin"] * total)
