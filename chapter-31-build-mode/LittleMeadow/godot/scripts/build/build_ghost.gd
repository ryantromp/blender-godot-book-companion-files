class_name BuildGhost
extends Node3D
## The see-through preview of a build, a plate on the ground and a price tag.

const GOOD: Color = Color(0.3, 0.9, 0.4, 0.45)
const BAD: Color = Color(0.95, 0.28, 0.22, 0.45)

var valid: bool = true
var model: Node3D
var plate: MeshInstance3D
var tag: Label3D

var _tint: StandardMaterial3D = _make_material(false)
var _plate_material: StandardMaterial3D = _make_material(true)


static func create(item: BuildItemData) -> BuildGhost:
	var ghost := BuildGhost.new()
	ghost.plate = MeshInstance3D.new()
	ghost.plate.mesh = PlaneMesh.new()
	ghost.plate.material_override = ghost._plate_material
	ghost.plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.plate.position.y = 0.03
	ghost.add_child(ghost.plate)
	ghost.tag = Label3D.new()
	ghost.tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost.tag.fixed_size = true
	ghost.tag.no_depth_test = true
	ghost.tag.pixel_size = 0.0005
	ghost.tag.font_size = 56
	ghost.tag.outline_size = 12
	ghost.tag.position.y = 2.4
	ghost.add_child(ghost.tag)
	if item != null:
		ghost.model = item.scene.instantiate()
		ghost._strip(ghost.model)
		ghost.model.position = item.pivot_offset
		ghost.add_child(ghost.model)
		ghost.set_plate_size(Vector2(item.footprint))
	return ghost


func place_on_grid(lowest: Vector2i, size: Vector2i, turns: int) -> void:
	position = BuildGrid.middle(lowest, size)
	rotation.y = BuildGrid.yaw(turns)


func set_plate_size(size: Vector2) -> void:
	(plate.mesh as PlaneMesh).size = size - Vector2(0.12, 0.12)


func set_valid(fits: bool, text: String = "") -> void:
	valid = fits
	_tint.albedo_color = GOOD if fits else BAD
	_plate_material.albedo_color = GOOD if fits else BAD
	tag.text = text
	tag.modulate = Color("FFF5CC") if fits else Color("FF9A8A")
	tag.outline_modulate = Color("14191A")


func _make_material(flat: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = GOOD
	if flat:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _strip(root: Node3D) -> void:
	for node: Node in root.find_children("*", "CollisionObject3D", true, false):
		if is_instance_valid(node):
			node.free()
	for node: Node in root.find_children("*", "NavigationObstacle3D", true, false):
		node.free()
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = _tint
		mesh.material_overlay = null
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
