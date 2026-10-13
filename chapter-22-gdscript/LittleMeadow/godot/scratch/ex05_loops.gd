@tool
extends EditorScript

func _run() -> void:
	for row: int in range(3):
		print("planting row ", row)
	var growth: float = 0.0
	var days: int = 0
	while growth < 1.0:
		growth += 0.3
		days += 1
	print("grown after ", days, " days")
