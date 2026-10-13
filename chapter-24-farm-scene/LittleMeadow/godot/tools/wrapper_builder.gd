@tool
class_name WrapperBuilder
extends RefCounted
## Chapter 24: writes one inherited wrapper scene for every imported model that the farm places and
## that has to block the farmer. A wrapper that already has a Footprint (the barn you make by hand) is
## kept as it is. The crate of Chapter 23 has none yet, so it is written again with the same scene id.
##
## Each wrapper is a short text file: it inherits the .glb, puts the solid thing on layer 4
## (obstacle), and adds a NavigationObstacle3D called Footprint for the navigation bake.

const MODELS: String = "res://assets/models/"
const WORLD: String = "res://scenes/world/"
const PROPS: String = "res://scenes/props/"
const OBSTACLE_LAYER: int = 8
const FOOTPRINT_Y: float = -0.25
const FOOTPRINT_HEIGHT: float = 2.5
## The bake looks at the centre of each 0.25 m cell, so a footprint thinner than a cell can slip between
## two centres and carve nothing. Every footprint is at least this thick, whatever the model measures.
const FOOTPRINT_MIN_THICKNESS: float = 0.3

## No shape key: the .glb holds a convex hull, which is moved to layer 4.
## "box" (x, y, z) and "cylinder" (radius, height): a new Body with that shape, sized in metres.
const ASSETS: Array[Dictionary] = [
	{"asset": "bld_farmhouse", "dir": WORLD, "root": "Farmhouse"},
	{"asset": "bld_barn", "dir": WORLD, "root": "Barn"},
	{"asset": "bld_shed", "dir": WORLD, "root": "Shed"},
	{"asset": "bld_chicken_coop", "dir": WORLD, "root": "ChickenCoop"},
	{"asset": "bld_well", "dir": WORLD, "root": "Well"},
	{"asset": "mach_tractor", "dir": WORLD, "root": "Tractor"},
	{"asset": "mach_cart", "dir": WORLD, "root": "Cart"},
	{"asset": "mach_windmill", "dir": WORLD, "root": "Windmill"},
	{"asset": "mach_pump", "dir": WORLD, "root": "Pump"},
	{"asset": "cliff_straight", "dir": WORLD, "root": "CliffStraight"},
	{"asset": "cliff_corner", "dir": WORLD, "root": "CliffCorner"},
	{"asset": "ter_pond", "dir": WORLD, "root": "Pond", "ring": 1.9, "foot_y": -0.6, "foot_height": 1.2},
	{"asset": "fence_post", "dir": PROPS, "root": "FencePost"},
	{"asset": "fence_rail", "dir": PROPS, "root": "FenceRail"},
	{"asset": "fence_corner", "dir": PROPS, "root": "FenceCorner"},
	{"asset": "fence_gate", "dir": PROPS, "root": "FenceGate"},
	{"asset": "rock_a", "dir": PROPS, "root": "RockA"},
	{"asset": "rock_b", "dir": PROPS, "root": "RockB"},
	{"asset": "rock_c", "dir": PROPS, "root": "RockC"},
	{"asset": "prop_crate_small", "dir": PROPS, "root": "CrateSmall", "box": Vector3(0.6, 0.6, 0.6)},
	{"asset": "prop_crate_large", "dir": PROPS, "root": "CrateLarge", "box": Vector3(1.0, 0.8, 1.0)},
	{"asset": "prop_barrel", "dir": PROPS, "root": "Barrel", "cylinder": Vector2(0.3, 0.9)},
	{"asset": "prop_bucket", "dir": PROPS, "root": "Bucket", "cylinder": Vector2(0.2, 0.35)},
	{"asset": "prop_sack", "dir": PROPS, "root": "Sack", "box": Vector3(0.5, 0.6, 0.4)},
	{"asset": "prop_hay_bale", "dir": PROPS, "root": "HayBale", "box": Vector3(0.9, 0.5, 0.5)},
	{"asset": "prop_trough", "dir": PROPS, "root": "Trough", "box": Vector3(1.6, 0.45, 0.5)},
	{"asset": "prop_lantern", "dir": PROPS, "root": "Lantern", "cylinder": Vector2(0.1, 0.35)},
	{"asset": "prop_sign_post", "dir": PROPS, "root": "SignPost", "box": Vector3(0.8, 1.4, 0.1)},
	{"asset": "tree_oak", "dir": PROPS, "root": "TreeOak", "cylinder": Vector2(0.3, 2.4)},
	{"asset": "tree_pine", "dir": PROPS, "root": "TreePine", "cylinder": Vector2(0.4, 2.0)},
]


func build() -> int:
	var written: int = 0
	for entry: Dictionary in ASSETS:
		var path: String = (entry["dir"] as String) + (entry["asset"] as String) + ".tscn"
		if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).contains("Footprint"):
			print("kept    ", path)
			continue
		var scene_id: String = _scene_id(path)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(_scene_text(entry, scene_id))
		file.close()
		written += 1
		print("wrote   ", path)
	print("WrapperBuilder: %d wrappers written" % written)
	return written


## The id of a scene that is already on disk, or a new one.
func _scene_id(path: String) -> String:
	if FileAccess.file_exists(path):
		var first: String = FileAccess.get_file_as_string(path).get_slice("\n", 0)
		var start: int = first.find("uid://")
		if start >= 0:
			return first.substr(start, first.find('"', start) - start)
	return ResourceUID.id_to_text(ResourceUID.create_id())


func _scene_text(entry: Dictionary, scene_id: String) -> String:
	var asset: String = entry["asset"]
	var glb: String = MODELS + asset + ".glb"
	var model: Node = (load(glb) as PackedScene).instantiate()
	var ids: String = "%x" % hash(asset)
	var lines: PackedStringArray = []
	var subs: PackedStringArray = []
	var nodes: PackedStringArray = []
	var next_index: int = model.get_child_count()
	var centre := Vector2.ZERO
	var outline: PackedVector3Array = PackedVector3Array()

	nodes.append('[node name="%s" unique_id=%d instance=ExtResource("1_%s")]\n' % [entry["root"], _uid(asset, "root"), ids.substr(0, 5)])
	var hulls: Array[Node] = model.find_children("*__hull", "StaticBody3D", true, false)
	if not hulls.is_empty():
		var hull: StaticBody3D = hulls[0] as StaticBody3D
		var parent_path: String = str(model.get_path_to(hull.get_parent()))
		nodes.append('[node name="%s" parent="%s" index="%d"]\ncollision_layer = %d\n' % [hull.name, parent_path, hull.get_index(), OBSTACLE_LAYER])
		var points: PackedVector3Array = (hull.get_child(0) as CollisionShape3D).shape.get("points")
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for p: Vector3 in points:
			low = low.min(Vector2(p.x, p.z))
			high = high.max(Vector2(p.x, p.z))
		centre = (low + high) / 2.0
		outline = _rectangle((high - low) / 2.0)
	elif entry.has("box") or entry.has("cylinder"):
		var shape_id: String = ("BoxShape3D_" if entry.has("box") else "CylinderShape3D_") + ids.substr(5, 5)
		var height: float = 0.0
		if entry.has("box"):
			var size: Vector3 = entry["box"]
			height = size.y
			subs.append('[sub_resource type="BoxShape3D" id="%s"]\nsize = Vector3(%s, %s, %s)\n' % [shape_id, _n(size.x), _n(size.y), _n(size.z)])
			outline = _rectangle(Vector2(size.x, size.z) / 2.0)
		else:
			var round_size: Vector2 = entry["cylinder"]
			height = round_size.y
			subs.append('[sub_resource type="CylinderShape3D" id="%s"]\nheight = %s\nradius = %s\n' % [shape_id, _n(round_size.y), _n(round_size.x)])
			outline = _ring(round_size.x)
		nodes.append('[node name="Body" type="StaticBody3D" parent="." index="%d" unique_id=%d]\ncollision_layer = %d\n' % [next_index, _uid(asset, "Body"), OBSTACLE_LAYER])
		nodes.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Body" index="0" unique_id=%d]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, 0)\nshape = SubResource("%s")\n' % [_uid(asset, "Shape"), _n(height / 2.0), shape_id])
		next_index += 1
	if entry.has("ring"):
		outline = _ring(entry["ring"])
	var foot_y: float = entry.get("foot_y", FOOTPRINT_Y)
	var foot_height: float = entry.get("foot_height", FOOTPRINT_HEIGHT)
	var vertices: PackedStringArray = []
	for v: Vector3 in outline:
		vertices.append("%s, 0, %s" % [_n(v.x), _n(v.z)])
	nodes.append('[node name="Footprint" type="NavigationObstacle3D" parent="." index="%d" unique_id=%d]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\nheight = %s\nvertices = PackedVector3Array(%s)\naffect_navigation_mesh = true\n' % [next_index, _uid(asset, "Footprint"), _n(centre.x), _n(foot_y), _n(centre.y), _n(foot_height), ", ".join(vertices)])

	lines.append('[gd_scene format=3 uid="%s"]\n' % scene_id)
	lines.append('[ext_resource type="PackedScene" uid="%s" path="%s" id="1_%s"]\n' % [ResourceUID.id_to_text(ResourceLoader.get_resource_uid(glb)), glb, ids.substr(0, 5)])
	lines.append_array(subs)
	lines.append_array(nodes)
	model.free()
	return "\n".join(lines)


func _rectangle(measured: Vector2) -> PackedVector3Array:
	var half: Vector2 = measured.max(Vector2.ONE * FOOTPRINT_MIN_THICKNESS / 2.0)
	return PackedVector3Array([
		Vector3(-half.x, 0.0, -half.y), Vector3(half.x, 0.0, -half.y),
		Vector3(half.x, 0.0, half.y), Vector3(-half.x, 0.0, half.y)])


func _ring(radius: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i: int in 8:
		var angle: float = TAU * (i + 0.5) / 8.0
		result.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	return result


func _n(value: float) -> String:
	var rounded: float = snappedf(value, 0.0001)
	return str(int(rounded)) if rounded == floorf(rounded) else str(rounded)


func _uid(asset: String, part: String) -> int:
	return hash(asset + "/" + part) & 0x7fffffff
