@tool
extends EditorScript

func _run() -> void:
	var crops: Array[String] = ["carrot", "wheat"]
	crops.append("pumpkin")
	print(crops, " size ", crops.size(), ", last: ", crops[-1])
	var prices: Dictionary[String, int] = {"carrot": 5, "wheat": 3}
	prices["pumpkin"] = 12
	for crop: String in crops:
		print(crop, " sells for ", prices.get(crop, 0))
