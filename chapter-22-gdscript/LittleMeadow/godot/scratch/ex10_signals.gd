@tool
extends EditorScript

signal harvested(crop: String, amount: int)

func _on_harvested(crop: String, amount: int) -> void:
	print("barn stores ", amount, " ", crop)

func _run() -> void:
	harvested.connect(_on_harvested)
	harvested.emit("carrot", 3)
