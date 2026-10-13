@tool
extends EditorScript
## Chapter 24: open this script and press Ctrl+Shift+X (Cmd+Shift+X on a Mac).
## It writes the wrapper scenes in res://scenes/world and res://scenes/props.


func _run() -> void:
	WrapperBuilder.new().build()
	EditorInterface.get_resource_filesystem().scan()
