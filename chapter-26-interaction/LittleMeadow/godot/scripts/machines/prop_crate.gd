extends Node3D
## A crate that jumps a little when the farmer uses it. The Interactable below tells it with a signal.

@onready var crate: MeshInstance3D = $prop_crate_small


func _on_interactable_interacted(_farmer: Farmer) -> void:
	var tween := create_tween()
	tween.tween_property(crate, "position:y", 0.15, 0.12)
	tween.tween_property(crate, "position:y", 0.0, 0.12)
