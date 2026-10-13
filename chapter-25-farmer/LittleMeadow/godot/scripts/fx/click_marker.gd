class_name ClickMarker
extends Node3D
## A ring on the ground that shrinks and fades away. It stays where it was put when its parent moves.

@export var lifetime: float = 0.8

var tween: Tween

@onready var ring: MeshInstance3D = $Ring


func _ready() -> void:
	top_level = true
	visible = false


func show_at(point: Vector3) -> void:
	global_position = point + Vector3(0.0, 0.03, 0.0)
	var material := ring.material_override as StandardMaterial3D
	material.albedo_color.a = 1.0
	ring.scale = Vector3(1.6, 1.0, 1.6)
	visible = true
	if tween != null:
		tween.kill()
	tween = create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(ring, "scale", Vector3(0.7, 1.0, 0.7), lifetime).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material, "albedo_color:a", 0.0, lifetime)
	tween.chain().tween_callback(hide)
