@tool
extends EditorScript

func _run() -> void:
	var water: int = 2
	if water >= 3:
		print("soil is wet")
	elif water > 0:
		print("soil is damp")
	else:
		print("soil is dry")
