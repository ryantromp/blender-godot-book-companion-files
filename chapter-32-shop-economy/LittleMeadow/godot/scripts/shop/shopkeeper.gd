class_name Shopkeeper
extends Node3D

@export var tint: Color = Color("8FB8D8")


func _ready() -> void:
	(find_child("AnimationPlayer", true, false) as AnimationPlayer).play(&"char_farmer_idle")
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var look := mesh.get_active_material(0).duplicate() as StandardMaterial3D
		look.albedo_color = tint
		mesh.material_override = look
