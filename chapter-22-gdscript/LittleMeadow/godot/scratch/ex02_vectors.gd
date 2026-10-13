@tool
extends EditorScript

func _run() -> void:
	var tile := Vector2(3, 4)
	var spot := Vector3(1.0, 0.5, -2.0)
	print("tile length: ", tile.length())
	print("spot + up: ", spot + Vector3.UP)
	print("spot * 2: ", spot * 2.0)
	var grass := Color.html("#5E9E47")
	print("grass green: ", snappedf(grass.g, 0.01))
	print("half way to white: ", grass.lerp(Color.WHITE, 0.5).to_html())
