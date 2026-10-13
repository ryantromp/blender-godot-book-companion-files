@tool
extends EditorScript

func _run() -> void:
	var days: int = 3
	var price: float = 2.5
	var crop: String = "carrot"
	var ripe: bool = false
	var total := days * price
	print(crop, " x", days, " = ", total, " coins, ripe: ", ripe)
	print("7 / 2 = ", 7 / 2, "   7 / 2.0 = ", 7 / 2.0)
