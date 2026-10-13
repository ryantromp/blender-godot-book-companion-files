extends Node
## Chapter 24: the farm scene loads, everything in it exists, nothing overlaps, the camera keeps to its limits,
## and a path through the baked navigation mesh goes around the barn.

const FARM: String = "res://scenes/world/farm.tscn"
const RIG: String = "res://scenes/world/camera_rig.tscn"
const OBSTACLE_LAYER: int = 8
const COUNTS: Dictionary = {
	"Terrain": 144, "Paths": 16, "Field": 40, "Buildings": 5, "Machines": 4, "Fences": 64,
	"Cliffs": 13, "Rocks": 15, "Trees": 33, "Plants": 71, "Props": 23,
}


## The footprint of every building and machine as a polygon on the ground (x and z), in world space.
func _footprints(farm: Node) -> Dictionary:
	var result: Dictionary = {}
	for group_name: String in ["Buildings", "Machines"]:
		for item: Node in farm.get_node("World/" + group_name).get_children():
			var obstacle := item.get_node("Footprint") as NavigationObstacle3D
			var corners := PackedVector2Array()
			for point: Vector3 in obstacle.vertices:
				var world: Vector3 = obstacle.global_transform * point
				corners.append(Vector2(world.x, world.z))
			result[item.name] = corners
	return result


func _inside_any(point: Vector2, polygons: Dictionary) -> String:
	for key: String in polygons:
		if Geometry2D.is_point_in_polygon(point, polygons[key]):
			return key
	return ""


func test_farm_loads_with_the_expected_groups(t: Variant) -> void:
	var farm: Node = t.load_scene(FARM)
	t.not_null(farm, "farm.tscn loads")
	for group_name: String in COUNTS:
		var group: Node = farm.get_node_or_null("World/" + group_name)
		t.not_null(group, "World/%s exists" % group_name)
		if group != null:
			t.eq(group.get_child_count(), COUNTS[group_name], "%s count" % group_name)
	for node_name: String in ["Sun", "WorldEnvironment", "CameraRig", "FarmerStart", "Backdrop"]:
		t.ok(farm.get_node_or_null(node_name) != null, "Farm has %s" % node_name)
	t.ok(farm.get_node("World") is NavigationRegion3D, "World is a NavigationRegion3D")
	t.ok(farm.get_node("World/Plants/GrassTufts") is MultiMeshInstance3D, "grass is one MultiMeshInstance3D")
	t.eq((farm.get_node("World/Plants/GrassTufts") as MultiMeshInstance3D).multimesh.instance_count, 1400, "1,400 tufts")
	t.ok((farm.get_node("Sun") as DirectionalLight3D).shadow_enabled, "the sun casts shadows")
	farm.queue_free()


func test_the_layout_and_the_scene_agree(t: Variant) -> void:
	var farm: Node = t.load_scene(FARM)
	var seen: Dictionary = {}
	for item: FarmLayout.Placement in FarmLayout.placements():
		# The Animals group sits under Farm, outside the navigation region, so the bake never sees it (Chapter 28).
		var prefix: String = "" if item.group == "Animals" else "World/"
		var node: Node3D = farm.get_node_or_null("%s%s/%s" % [prefix, item.group, item.node_name]) as Node3D
		t.not_null(node, "%s/%s is in the scene" % [item.group, item.node_name])
		if node != null:
			t.vec_approx(node.position, item.position, 0.001, "%s position" % item.node_name)
			t.ok(absf(angle_difference(deg_to_rad(node.rotation_degrees.y), deg_to_rad(item.yaw))) < 0.001, "%s turn" % item.node_name)
		t.ok(not seen.has(item.group + item.node_name), "%s/%s is listed once" % [item.group, item.node_name])
		seen[item.group + item.node_name] = true
	t.eq(seen.size(), 433, "433 listed placements, six of them animals (the 71st Plants node is the grass)")
	farm.queue_free()


func test_every_asset_name_resolves(t: Variant) -> void:
	for item: FarmLayout.Placement in FarmLayout.placements():
		t.ok(ResourceLoader.exists(item.scene), "%s exists" % item.scene)
		t.ok(load(item.scene) is PackedScene, "%s is a scene" % item.scene)
	for entry: Dictionary in WrapperBuilder.ASSETS:
		var glb: String = WrapperBuilder.MODELS + (entry["asset"] as String) + ".glb"
		var wrapper: String = (entry["dir"] as String) + (entry["asset"] as String) + ".tscn"
		t.ok(ResourceLoader.exists(glb), "%s exists" % glb)
		t.ok(ResourceLoader.exists(wrapper), "%s exists" % wrapper)


func test_wrappers_block_on_the_obstacle_layer(t: Variant) -> void:
	for entry: Dictionary in WrapperBuilder.ASSETS:
		var path: String = (entry["dir"] as String) + (entry["asset"] as String) + ".tscn"
		var root: Node = (load(path) as PackedScene).instantiate()
		var bodies: Array[Node] = root.find_children("*", "StaticBody3D", true, false)
		t.ok(not bodies.is_empty(), "%s has a body" % path)
		for body: Node in bodies:
			# The pond keeps the glb's ground layer, so a click ray still hits the water. Its Footprint keeps the farmer out.
			var wanted: int = 1 if entry["asset"] == "ter_pond" else OBSTACLE_LAYER
			t.eq((body as StaticBody3D).collision_layer, wanted, "%s: %s is on the right layer" % [path, body.name])
		var footprint := root.get_node_or_null("Footprint") as NavigationObstacle3D
		t.not_null(footprint, "%s has a Footprint" % path)
		if footprint != null:
			t.ok(footprint.affect_navigation_mesh, "%s: Footprint cuts the bake" % path)
			t.ok(footprint.vertices.size() >= 4, "%s: Footprint has a shape" % path)
		root.free()


func test_buildings_and_machines_do_not_overlap(t: Variant) -> void:
	var farm: Node = t.load_scene(FARM)
	var shapes: Dictionary = _footprints(farm)
	t.eq(shapes.size(), 9, "five buildings and four machines")
	var names: Array = shapes.keys()
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var common: Array[PackedVector2Array] = Geometry2D.intersect_polygons(shapes[names[i]], shapes[names[j]])
			t.ok(common.is_empty(), "%s and %s do not overlap" % [names[i], names[j]])
		for point: Vector2 in shapes[names[i]]:
			t.ok(absf(point.x) < 24.0 and absf(point.y) < 24.0, "%s stays inside the 48 m farm" % names[i])
	farm.queue_free()


func test_camera_zoom_rotate_and_bounds(t: Variant) -> void:
	var rig: CameraRig = (load(RIG) as PackedScene).instantiate() as CameraRig
	t.add(rig)
	await t.frames(2)
	t.approx(rig.pivot.rotation_degrees.x, -50.0, 0.01, "pitch is -50 degrees")
	t.ok(rig.camera.global_transform.basis.z.y > 0.7, "the camera looks down from above")
	for i: int in 40:
		await t.tap_action("cam_zoom_out", 1)
	t.approx(rig.wanted_distance, rig.zoom_max, 0.001, "zoom out stops at the maximum")
	for i: int in 60:
		await t.tap_action("cam_zoom_in", 1)
	t.approx(rig.wanted_distance, rig.zoom_min, 0.001, "zoom in stops at the minimum")
	await t.frames(120)
	t.approx(rig.distance, rig.zoom_min, 0.05, "the camera glides to the minimum")
	var yaw_before: float = rig.wanted_yaw
	t.press_action("cam_rotate_left")
	await t.frames(10)
	t.release_action("cam_rotate_left")
	t.ok(rig.wanted_yaw > yaw_before, "Q turns the rig one way")
	yaw_before = rig.wanted_yaw
	t.press_action("cam_rotate_right")
	await t.frames(10)
	t.release_action("cam_rotate_right")
	t.ok(rig.wanted_yaw < yaw_before, "E turns it back")
	yaw_before = rig.wanted_yaw
	t.press_action("cam_rotate_drag")
	var drag := InputEventMouseMotion.new()
	drag.relative = t.tree.root.get_final_transform().basis_xform(Vector2(100.0, 0.0))
	Input.parse_input_event(drag)
	await t.frames(2)
	t.release_action("cam_rotate_drag")
	t.approx(rig.wanted_yaw, yaw_before - 100.0 * rig.drag_degrees_per_pixel, 0.01, "a middle-button drag turns by 0.3 degrees a pixel")
	rig.global_position = Vector3(100.0, 0.0, -100.0)
	await t.frames(2)
	t.approx(rig.global_position.x, rig.bounds, 0.001, "the rig stays inside the farm (x)")
	t.approx(rig.global_position.z, -rig.bounds, 0.001, "the rig stays inside the farm (z)")
	var target := Node3D.new()
	t.add(target)
	target.global_position = Vector3(5.0, 0.0, 7.0)
	rig.target = target
	rig.snap()
	t.vec_approx(rig.global_position, target.global_position, 0.001, "snap() jumps to the target")
	rig.queue_free()
	target.queue_free()


func test_a_path_goes_around_the_barn(t: Variant) -> void:
	var farm: Node = t.load_scene(FARM)
	await t.frames(3)
	var region := farm.get_node("World") as NavigationRegion3D
	var map: RID = region.get_navigation_map()
	NavigationServer3D.map_force_update(map)
	var mesh: NavigationMesh = region.navigation_mesh
	t.ok(mesh.get_polygon_count() > 200, "the saved mesh holds the bake (%d polygons)" % mesh.get_polygon_count())
	t.approx(mesh.agent_radius, 0.5, 0.001, "agent radius")
	t.approx(mesh.agent_height, 1.75, 0.001, "agent height")
	# A walk from the yard to the farmer start exists.
	var start := Vector3(0.5, 0.0, -3.5)
	var gate := Vector3(0.5, 0.0, 19.0)
	var south: PackedVector3Array = NavigationServer3D.map_get_path(map, start, gate, true)
	t.ok(south.size() >= 2, "a path from the start to the south gate exists")
	t.ok(Vector2(south[south.size() - 1].x, south[south.size() - 1].z).distance_to(Vector2(gate.x, gate.z)) < 1.0, "the path reaches the gate")
	# A walk straight through the barn has to bend around it.
	var barn: PackedVector2Array = _footprints(farm)["Barn"]
	var west := Vector3(1.0, 0.0, -14.0)
	var east := Vector3(16.0, 0.0, -14.0)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, west, east, true)
	t.ok(path.size() >= 3, "the path bends (%d points)" % path.size())
	var length: float = 0.0
	for i: int in range(1, path.size()):
		var a := Vector2(path[i - 1].x, path[i - 1].z)
		var b := Vector2(path[i].x, path[i].z)
		length += a.distance_to(b)
		for step: int in 41:
			var point: Vector2 = a.lerp(b, step / 40.0)
			t.ok(not Geometry2D.is_point_in_polygon(point, barn), "the path is outside the barn at %s" % str(point))
	t.ok(length > 16.0, "the detour is longer than the 15 m straight line (%.1f m)" % length)
	farm.queue_free()


func test_the_hill_and_both_pens_can_be_reached(t: Variant) -> void:
	var farm: Node = t.load_scene(FARM)
	await t.frames(3)
	var map: RID = (farm.get_node("World") as NavigationRegion3D).get_navigation_map()
	NavigationServer3D.map_force_update(map)
	var start := Vector3(0.5, 0.0, -3.5)
	var goals: Dictionary = {"hill top": Vector3(18.0, 1.0, 2.0), "chicken pen": Vector3(-19.0, 0.0, 0.5), "paddock": Vector3(-14.0, 0.0, 16.0)}
	for label: String in goals:
		var goal: Vector3 = goals[label]
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, goal, true)
		t.ok(path.size() >= 2, "a path to the %s exists" % label)
		var end: Vector3 = path[path.size() - 1]
		t.ok(Vector2(end.x - goal.x, end.z - goal.z).length() < 0.6, "the path to the %s ends there" % label)
	farm.queue_free()


func test_no_navigation_polygon_stands_inside_a_building(t: Variant) -> void:
	var farm: Node = t.load_scene(FARM)
	var shapes: Dictionary = _footprints(farm)
	var region := farm.get_node("World") as NavigationRegion3D
	var mesh: NavigationMesh = region.navigation_mesh
	var vertices: PackedVector3Array = mesh.vertices
	var bad: int = 0
	for i: int in mesh.get_polygon_count():
		var sum := Vector3.ZERO
		var indices: PackedInt32Array = mesh.get_polygon(i)
		for index: int in indices:
			sum += vertices[index]
		var centre: Vector3 = region.global_transform * (sum / indices.size())
		if _inside_any(Vector2(centre.x, centre.z), shapes) != "":
			bad += 1
	t.eq(bad, 0, "no polygon centre lies inside a building or machine")
	farm.queue_free()


func test_the_farmer_start_is_on_the_mesh(t: Variant) -> void:
	var farm: Node = t.load_scene(FARM)
	await t.frames(3)
	var map: RID = (farm.get_node("World") as NavigationRegion3D).get_navigation_map()
	NavigationServer3D.map_force_update(map)
	var marker := farm.get_node("FarmerStart") as Marker3D
	var near: Vector3 = NavigationServer3D.map_get_closest_point(map, marker.global_position)
	t.ok(Vector2(near.x - marker.global_position.x, near.z - marker.global_position.z).length() < 0.3, "FarmerStart is on walkable ground")
	farm.queue_free()


func test_title_is_the_main_scene(t: Variant) -> void:
	var setting: String = ProjectSettings.get_setting("application/run/main_scene")
	t.eq(ResourceUID.ensure_path(setting), "res://scenes/ui/title.tscn", "the title scene is the main scene since Chapter 34")
