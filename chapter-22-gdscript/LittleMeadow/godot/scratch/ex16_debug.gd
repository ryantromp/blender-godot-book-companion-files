extends Node

var prices: Dictionary[String, int] = {"carrot": 5, "wheat": 3}

func _ready() -> void:
	var total: int = 0
	for crop: String in prices:
		total += prices[crop]
		print(crop, " running total ", total)
	print("sack worth ", total)
	get_tree().quit()
