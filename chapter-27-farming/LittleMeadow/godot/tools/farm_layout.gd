@tool
class_name FarmLayout
extends RefCounted
## Chapter 24: where everything on the farm stands. All numbers are metres.
## x runs east, z runs south (the default camera looks north, toward -z), y is up.
## The farm is 48 by 48 m, centred on the origin, cut into 12 by 12 ground tiles of 4 m.

const COLUMNS: int = 12
const TILE: float = 4.0
const HILL_CELL: Vector2i = Vector2i(10, 6)
const POND_CELL: Vector2i = Vector2i(8, 9)
const HILL_HEIGHT: float = 1.0

const MODELS: String = "res://assets/models/"
const WORLD: String = "res://scenes/world/"
const PROPS: String = "res://scenes/props/"

## Width and depth of what each scene covers on the ground (before it is turned).
const FOOT: Dictionary = {
	"bld_farmhouse": Vector2(6.0, 5.0), "bld_barn": Vector2(8.0, 6.0), "bld_shed": Vector2(3.0, 3.0),
	"bld_chicken_coop": Vector2(2.0, 2.0), "bld_well": Vector2(1.6, 1.6), "mach_tractor": Vector2(1.6, 3.0),
	"mach_cart": Vector2(1.0, 1.8), "mach_windmill": Vector2(3.0, 3.0), "mach_pump": Vector2(0.4, 0.6),
	"path_straight": Vector2(4.0, 1.0), "path_corner": Vector2(1.0, 1.0), "field_plot": Vector2(1.0, 1.0),
	"fence_rail": Vector2(2.0, 0.4), "fence_gate": Vector2(1.0, 1.0), "ter_pond": Vector2(4.5, 4.5),
	"gn_scatter": Vector2(4.0, 4.0),
}


class Placement:
	var group: String
	var node_name: String
	var scene: String
	var position: Vector3
	var yaw: float

	func _init(g: String, n: String, s: String, p: Vector3, y: float = 0.0) -> void:
		group = g
		node_name = n
		scene = s
		position = p
		yaw = y


static func tile_center(column: int, row: int) -> Vector3:
	var half: float = COLUMNS * TILE / 2.0
	return Vector3(-half + TILE * (column + 0.5), 0.0, -half + TILE * (row + 0.5))


## Tile scene and turn for the 3 by 3 hill: a flat top, four slopes, four corners.
static func hill_piece(column: int, row: int) -> Array:
	var dx: int = column - HILL_CELL.x
	var dz: int = row - HILL_CELL.y
	if dx == 0 and dz == 0:
		return ["ter_tile_flat", 0.0, HILL_HEIGHT]
	if dx == 0:
		return ["ter_tile_slope", 180.0 if dz < 0 else 0.0, 0.0]
	if dz == 0:
		return ["ter_tile_slope", -90.0 if dx < 0 else 90.0, 0.0]
	var turn: float = 0.0
	if dx < 0 and dz < 0:
		turn = -90.0
	elif dx > 0 and dz < 0:
		turn = 180.0
	elif dx > 0 and dz > 0:
		turn = 90.0
	return ["ter_tile_corner", turn, 0.0]


static func _add(list: Array[Placement], group: String, node_name: String, scene: String,
		position: Vector3, yaw: float = 0.0) -> void:
	list.append(Placement.new(group, node_name, scene, position, yaw))


static func _terrain(list: Array[Placement]) -> void:
	for row: int in COLUMNS:
		for column: int in COLUMNS:
			var cell := Vector2i(column, row)
			var centre: Vector3 = tile_center(column, row)
			var label: String = "Tile_%02d_%02d" % [column, row]
			if cell == POND_CELL:
				_add(list, "Terrain", "Pond", WORLD + "ter_pond.tscn", centre)
				continue
			var piece: Array = ["ter_tile_flat", 0.0, 0.0]
			if absi(column - HILL_CELL.x) <= 1 and absi(row - HILL_CELL.y) <= 1:
				piece = hill_piece(column, row)
			centre.y = piece[2]
			_add(list, "Terrain", label, MODELS + "%s.glb" % piece[0], centre, piece[1])


static func _paths(list: Array[Placement]) -> void:
	var straight: String = MODELS + "path_straight.glb"
	var corner: String = MODELS + "path_corner.glb"
	_add(list, "Paths", "Door_House", straight, Vector3(-8.5, 0.0, -9.0), 90.0)
	_add(list, "Paths", "Bend_House", corner, Vector3(-8.5, 0.0, -6.5), 180.0)
	_add(list, "Paths", "Door_Barn", straight, Vector3(8.5, 0.0, -9.0), 90.0)
	_add(list, "Paths", "Bend_Barn", corner, Vector3(8.5, 0.0, -6.5), -90.0)
	for i: int in 4:
		_add(list, "Paths", "Yard_%d" % i, straight, Vector3(-6.0 + 4.0 * i, 0.0, -6.5))
	for i: int in 7:
		_add(list, "Paths", "South_%d" % i, straight, Vector3(0.5, 0.0, -4.0 + 4.0 * i), 90.0)
	_add(list, "Paths", "To_Field", straight, Vector3(-2.0, 0.0, 6.5))
	for row: int in 5:
		for column: int in 8:
			_add(list, "Field", "Plot_%d_%d" % [column, row], WORLD + "soil_plot.tscn",
					Vector3(-11.5 + column, 0.0, 4.5 + row))


static func _fence_side(list: Array[Placement], tag: String, start: Vector2, end: Vector2,
		open_from: float, open_to: float) -> void:
	var length: float = start.distance_to(end)
	var direction: Vector2 = (end - start) / length
	var yaw: float = 0.0 if absf(direction.x) > 0.5 else 90.0
	var steps: int = roundi(length / 2.0)
	for i: int in steps:
		var along: float = 2.0 * i
		if along >= open_from and along < open_to:
			continue
		var middle: Vector2 = start + direction * (along + 1.0)
		_add(list, "Fences", "%s_Rail_%d" % [tag, i], PROPS + "fence_rail.tscn", Vector3(middle.x, 0.0, middle.y), yaw)
	for i: int in range(1, steps):
		var post: Vector2 = start + direction * (2.0 * i)
		_add(list, "Fences", "%s_Post_%d" % [tag, i], PROPS + "fence_post.tscn", Vector3(post.x, 0.0, post.y))


static func _fence_rectangle(list: Array[Placement], tag: String, corner_a: Vector2, corner_b: Vector2,
		east_open_from: float, east_open_to: float) -> void:
	var nw := Vector2(corner_a.x, corner_a.y)
	var ne := Vector2(corner_b.x, corner_a.y)
	var se := Vector2(corner_b.x, corner_b.y)
	var sw := Vector2(corner_a.x, corner_b.y)
	_fence_side(list, tag + "N", nw, ne, -1.0, -1.0)
	_fence_side(list, tag + "E", ne, se, east_open_from, east_open_to)
	_fence_side(list, tag + "S", se, sw, -1.0, -1.0)
	_fence_side(list, tag + "W", sw, nw, -1.0, -1.0)
	var corners: Array[Vector2] = [nw, ne, se, sw]
	for i: int in 4:
		_add(list, "Fences", "%s_Corner_%d" % [tag, i], PROPS + "fence_corner.tscn", Vector3(corners[i].x, 0.0, corners[i].y))


static func _fences(list: Array[Placement]) -> void:
	# Chicken pen, 6 by 6 m. The east side has a 2 m opening and the gate stands open, swung into the pen.
	_fence_rectangle(list, "Pen", Vector2(-22.0, -3.0), Vector2(-16.0, 3.0), 2.0, 4.0)
	_add(list, "Fences", "Pen_Gate", PROPS + "fence_gate.tscn", Vector3(-16.0, 0.0, -1.0), 180.0)
	# Cow paddock, 12 by 8 m, opening on the east side.
	_fence_rectangle(list, "Paddock", Vector2(-20.0, 12.0), Vector2(-8.0, 20.0), 2.0, 4.0)
	_add(list, "Fences", "Paddock_Gate", PROPS + "fence_gate.tscn", Vector3(-8.0, 0.0, 14.0), 180.0)


static func _cliffs(list: Array[Placement]) -> void:
	for i: int in 11:
		_add(list, "Cliffs", "Cliff_%02d" % i, WORLD + "cliff_straight.tscn", Vector3(-20.0 + 4.0 * i, 0.0, -23.25))
	_add(list, "Cliffs", "Cliff_West", WORLD + "cliff_corner.tscn", Vector3(-23.0, 0.0, -23.0), 90.0)
	_add(list, "Cliffs", "Cliff_East", WORLD + "cliff_corner.tscn", Vector3(23.0, 0.0, -23.0), 0.0)


static func _buildings(list: Array[Placement]) -> void:
	_add(list, "Buildings", "Farmhouse", WORLD + "bld_farmhouse.tscn", Vector3(-8.5, 0.0, -13.5))
	_add(list, "Buildings", "Barn", WORLD + "bld_barn.tscn", Vector3(8.5, 0.0, -14.0))
	_add(list, "Buildings", "Shed", WORLD + "bld_shed.tscn", Vector3(17.5, 0.0, -14.5))
	_add(list, "Buildings", "ChickenCoop", WORLD + "bld_chicken_coop.tscn", Vector3(-19.6, 0.0, -0.5), 90.0)
	_add(list, "Buildings", "Well", WORLD + "bld_well.tscn", Vector3(0.5, 0.0, -9.5))
	_add(list, "Machines", "Tractor", WORLD + "mach_tractor.tscn", Vector3(15.0, 0.0, -8.5), -35.0)
	_add(list, "Machines", "Cart", WORLD + "mach_cart.tscn", Vector3(-3.5, 0.0, -9.5), 20.0)
	_add(list, "Machines", "Windmill", WORLD + "mach_windmill.tscn", Vector3(-18.0, 0.0, -9.5))
	_add(list, "Machines", "Pump", WORLD + "mach_pump.tscn", Vector3(-3.0, 0.0, 3.2))


static func _props(list: Array[Placement]) -> void:
	_add(list, "Props", "HayBale_1", PROPS + "prop_hay_bale.tscn", Vector3(3.5, 0.0, -13.6), 90.0)
	_add(list, "Props", "HayBale_2", PROPS + "prop_hay_bale.tscn", Vector3(3.5, 0.0, -12.4), 90.0)
	_add(list, "Props", "HayBale_3", PROPS + "prop_hay_bale.tscn", Vector3(3.5, 0.5, -13.0), 90.0)
	_add(list, "Props", "Barrel_1", PROPS + "prop_barrel.tscn", Vector3(5.5, 0.0, -10.3))
	_add(list, "Props", "Barrel_2", PROPS + "prop_barrel.tscn", Vector3(6.3, 0.0, -10.1))
	_add(list, "Props", "Sack_1", PROPS + "prop_sack.tscn", Vector3(11.0, 0.0, -10.3))
	_add(list, "Props", "Sack_2", PROPS + "prop_sack.tscn", Vector3(11.7, 0.0, -10.0), 30.0)
	_add(list, "Props", "CrateLarge_1", PROPS + "prop_crate_large.tscn", Vector3(3.4, 0.0, -10.3), 10.0)
	_add(list, "Props", "Lantern_1", PROPS + "prop_lantern.tscn", Vector3(3.4, 0.8, -10.3))
	_add(list, "Props", "CrateSmall_1", PROPS + "prop_crate_small.tscn", Vector3(4.4, 0.0, -10.0), -15.0)
	_add(list, "Props", "Bucket_1", PROPS + "prop_bucket.tscn", Vector3(1.8, 0.0, -9.0))
	_add(list, "Props", "Barrel_3", PROPS + "prop_barrel.tscn", Vector3(-5.0, 0.0, -10.3))
	_add(list, "Props", "CrateSmall_2", PROPS + "prop_crate_small.tscn", Vector3(-12.2, 0.0, -12.5), 20.0)
	_add(list, "Props", "SignPost_Field", PROPS + "prop_sign_post.tscn", Vector3(-12.6, 0.0, 3.4), 20.0)
	_add(list, "Props", "Bucket_2", PROPS + "prop_bucket.tscn", Vector3(-2.2, 0.0, 3.0))
	_add(list, "Props", "Sack_3", PROPS + "prop_sack.tscn", Vector3(-4.2, 0.0, 3.0), -20.0)
	_add(list, "Props", "Trough_Paddock", PROPS + "prop_trough.tscn", Vector3(-17.0, 0.0, 18.4))
	_add(list, "Props", "HayBale_4", PROPS + "prop_hay_bale.tscn", Vector3(-10.5, 0.0, 18.5), 70.0)
	_add(list, "Props", "Trough_Pen", PROPS + "prop_trough.tscn", Vector3(-18.0, 0.0, 2.0))
	_add(list, "Props", "SignPost_Gate", PROPS + "prop_sign_post.tscn", Vector3(2.4, 0.0, 21.4), -10.0)
	_add(list, "Props", "SignPost_Hill", PROPS + "prop_sign_post.tscn", Vector3(18.0, 1.0, 1.2), 15.0)
	_add(list, "Props", "Lantern_2", PROPS + "prop_lantern.tscn", Vector3(17.2, 1.0, 2.6))
	_add(list, "Props", "Banner", MODELS + "dress_banner.glb", Vector3(19.4, 1.0, 2.4), 20.0)


static func _rocks(list: Array[Placement]) -> void:
	var names: Array[String] = ["rock_a", "rock_b", "rock_c"]
	var spots: Array[Vector3] = [
		Vector3(7.6, 0.0, 12.0), Vector3(8.2, 0.0, 16.3), Vector3(12.4, 0.0, 12.2), Vector3(13.0, 0.0, 15.8),
		Vector3(11.0, 0.0, 17.4), Vector3(-21.0, 0.0, -20.5), Vector3(-14.5, 0.0, -20.6), Vector3(-3.0, 0.0, -20.8),
		Vector3(6.0, 0.0, -20.5), Vector3(14.0, 0.0, -20.7), Vector3(19.0, 0.0, -19.0), Vector3(17.0, 1.0, 3.4),
		Vector3(19.6, 1.0, 0.6), Vector3(-6.0, 0.0, 22.0), Vector3(-15.0, 0.0, 6.0),
	]
	for i: int in spots.size():
		_add(list, "Rocks", "Rock_%02d" % i, PROPS + names[i % 3] + ".tscn", spots[i], 37.0 * i)


static func _plants(list: Array[Placement]) -> void:
	var bushes: Array[Vector3] = [
		Vector3(-11.9, 0.0, -10.6), Vector3(-5.2, 0.0, -11.6), Vector3(-13.5, 0.0, -14.5), Vector3(13.8, 0.0, -11.6),
		Vector3(3.2, 0.0, -15.8), Vector3(20.0, 0.0, -12.0), Vector3(-22.5, 0.0, 5.5), Vector3(-15.0, 0.0, 10.0),
		Vector3(-7.0, 0.0, 10.5), Vector3(5.0, 0.0, 6.0), Vector3(14.0, 0.0, 10.0), Vector3(16.5, 0.0, 17.0),
		Vector3(5.5, 0.0, 19.0), Vector3(-1.5, 0.0, 14.0), Vector3(21.0, 0.0, 14.0), Vector3(-9.0, 0.0, -18.5),
	]
	for i: int in bushes.size():
		_add(list, "Plants", "Bush_%02d" % i, MODELS + "bush.glb", bushes[i], 53.0 * i)
	var patches: Array[Vector3] = [
		Vector3(-21.0, 0.0, -17.0), Vector3(21.0, 0.0, -19.0), Vector3(-12.0, 0.0, -20.0),
		Vector3(21.0, 0.0, 19.0), Vector3(2.0, 0.0, 12.0), Vector3(-5.0, 0.0, 20.0),
	]
	for i: int in patches.size():
		_add(list, "Plants", "Meadow_%d" % i, MODELS + "gn_scatter.glb", patches[i], 90.0 * i)


static func _flowers(list: Array[Placement], rng: RandomNumberGenerator) -> void:
	var centres: Array[Vector3] = [
		Vector3(-12.5, 0.0, -9.2), Vector3(-5.5, 0.0, -9.0), Vector3(14.5, 0.0, -11.5), Vector3(7.0, 0.0, 10.0),
		Vector3(6.0, 0.0, 14.5), Vector3(-1.0, 0.0, 17.5), Vector3(14.0, 0.0, 19.0), Vector3(-13.0, 0.0, 1.0),
	]
	var kinds: Array[String] = ["flower_a", "flower_b", "flower_c"]
	var count: int = 0
	for centre: Vector3 in centres:
		for i: int in 6:
			var spot := Vector3(centre.x + rng.randf_range(-1.6, 1.6), 0.0, centre.z + rng.randf_range(-1.6, 1.6))
			_add(list, "Plants", "Flower_%02d" % count, MODELS + kinds[(count + i) % 3] + ".glb", spot, rng.randf_range(0.0, 360.0))
			count += 1


static func _trees(list: Array[Placement], rng: RandomNumberGenerator) -> void:
	var spots: Array[Vector3] = []
	for i: int in 11:
		spots.append(Vector3(-22.4, 0.0, -17.0 + 3.8 * i))
	for i: int in 11:
		spots.append(Vector3(22.4, 0.0, -17.0 + 3.8 * i))
	for i: int in 10:
		spots.append(Vector3(-20.0 + 4.4 * i, 0.0, 22.4))
	spots.append_array([
		Vector3(-14.0, 0.0, -6.0), Vector3(-1.5, 0.0, -17.5), Vector3(-6.0, 0.0, 14.0), Vector3(8.0, 0.0, 8.0),
		Vector3(-14.0, 0.0, -18.0), Vector3(14.0, 0.0, -19.0), Vector3(17.0, 1.0, 3.2),
	])
	var blocked: Array[Rect2] = keepouts(1.2)
	var oaks: int = 0
	var pines: int = 0
	for spot: Vector3 in spots:
		var here := Vector3(spot.x + rng.randf_range(-0.6, 0.6), spot.y, spot.z + rng.randf_range(-0.8, 0.8))
		var hilltop: bool = spot.y > 0.5
		if not hilltop and _inside(blocked, here):
			continue
		if absf(here.x - 0.5) < 3.0 and here.z > 20.0:
			continue
		var oak: bool = rng.randf() < 0.5 and not hilltop
		if oak:
			oaks += 1
		else:
			pines += 1
		var label: String = "Oak_%02d" % oaks if oak else "Pine_%02d" % pines
		_add(list, "Trees", label, PROPS + ("tree_oak.tscn" if oak else "tree_pine.tscn"), here, rng.randf_range(0.0, 360.0))


## Rectangles (x, z, width, depth) that scenery must keep clear, each grown by margin.
static func keepouts(margin: float) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var base: Array[Placement] = []
	_buildings(base)
	_paths(base)
	_fences(base)
	_add(base, "Terrain", "Pond", WORLD + "ter_pond.tscn", tile_center(POND_CELL.x, POND_CELL.y))
	for p: Placement in base:
		var key: String = p.scene.get_file().get_basename()
		if not FOOT.has(key):
			continue
		var size: Vector2 = FOOT[key]
		var turned: float = deg_to_rad(p.yaw)
		var half := Vector2(
				absf(cos(turned)) * size.x / 2.0 + absf(sin(turned)) * size.y / 2.0,
				absf(sin(turned)) * size.x / 2.0 + absf(cos(turned)) * size.y / 2.0)
		rects.append(Rect2(Vector2(p.position.x, p.position.z) - half - Vector2(margin, margin), half * 2.0 + Vector2(margin, margin) * 2.0))
	rects.append(Rect2(Vector2(-12.0 - margin, 4.0 - margin), Vector2(8.0, 5.0) + Vector2(margin, margin) * 2.0))
	var hill: Vector2 = Vector2(tile_center(HILL_CELL.x, HILL_CELL.y).x, tile_center(HILL_CELL.x, HILL_CELL.y).z)
	rects.append(Rect2(hill - Vector2(6.0, 6.0) - Vector2(margin, margin), Vector2(12.0, 12.0) + Vector2(margin, margin) * 2.0))
	return rects


static func _inside(rects: Array[Rect2], point: Vector3) -> bool:
	for r: Rect2 in rects:
		if r.has_point(Vector2(point.x, point.z)):
			return true
	return false


static func placements() -> Array[Placement]:
	var list: Array[Placement] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 24
	_terrain(list)
	_paths(list)
	_buildings(list)
	_fences(list)
	_cliffs(list)
	_props(list)
	_rocks(list)
	_plants(list)
	_flowers(list, rng)
	_trees(list, rng)
	return list


## Where the 1,400 grass tufts stand: random spots on flat ground that nothing else uses.
static func grass_transforms(count: int) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2424
	var blocked: Array[Rect2] = keepouts(0.5)
	var result: Array[Transform3D] = []
	var tries: int = 0
	while result.size() < count and tries < count * 6:
		tries += 1
		var spot := Vector3(rng.randf_range(-23.0, 23.0), 0.0, rng.randf_range(-21.5, 23.0))
		if _inside(blocked, spot):
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.6))
		result.append(Transform3D(basis, spot))
	return result
