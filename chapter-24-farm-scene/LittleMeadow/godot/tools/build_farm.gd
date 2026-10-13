@tool
extends EditorScript
## Chapter 24: open farm.tscn, then open this script and press Ctrl+Shift+X (Cmd+Shift+X on a Mac).
## It places every building, fence, tree and prop of the farm layout in the open scene.


func _run() -> void:
	var farm: Node3D = EditorInterface.get_edited_scene_root() as Node3D
	if farm == null or not farm.has_node("World"):
		push_error("Open farm.tscn first: the scene needs a node called World.")
		return
	var counts: Dictionary = FarmBuilder.new().build(farm)
	print("Farm built: ", counts)
