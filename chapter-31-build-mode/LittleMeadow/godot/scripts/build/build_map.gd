class_name BuildMap
extends RefCounted
## What stands on each cell. A cell that is not in the Dictionary is free.

const REASONS: Dictionary = {
	&"outside": "That is outside the farm.",
	&"scenery": "Something is in the way.",
	&"placed": "You already built there.",
	&"soil": "That is farm soil.",
	&"water": "That is water.",
	&"slope": "The hill is too steep to build on.",
}

var kinds: Dictionary[Vector2i, StringName] = {}
var owners: Dictionary[Vector2i, Node3D] = {}


func kind_at(cell: Vector2i) -> StringName:
	return &"outside" if not BuildGrid.in_bounds(cell) else kinds.get(cell, &"")


func problem_for(cells: Array[Vector2i]) -> String:
	for cell: Vector2i in cells:
		var kind: StringName = kind_at(cell)
		if kind != &"":
			return REASONS[kind]
	return ""


func reserve(cells: Array[Vector2i], kind: StringName, owner: Node3D = null) -> void:
	for cell: Vector2i in cells:
		kinds[cell] = kind
		if owner != null:
			owners[cell] = owner


func release(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		kinds.erase(cell)
		owners.erase(cell)


func scan_world(world: Node3D, placed_root: Node) -> void:
	for node: Node in world.find_children("Footprint", "NavigationObstacle3D", true, false):
		if placed_root.is_ancestor_of(node):
			continue
		var obstacle := node as NavigationObstacle3D
		var outline := PackedVector2Array()
		for vertex: Vector3 in obstacle.vertices:
			var point: Vector3 = obstacle.global_transform * vertex
			outline.append(Vector2(point.x, point.z))
		var is_water: bool = obstacle.get_parent().scene_file_path.contains("pond")
		reserve(BuildGrid.cells_under(outline), &"water" if is_water else &"scenery")
	for plot: Node in world.get_tree().get_nodes_in_group(&"soil_plots"):
		reserve([BuildGrid.cell_of((plot as Node3D).global_position)], &"soil")
	for tile: Node3D in world.get_node("Terrain").get_children():
		var path: String = tile.scene_file_path
		if tile.global_position.y > 0.01 or path.contains("slope") or path.contains("corner"):
			var corner: Vector3 = tile.global_position - Vector3(2.0, 0.0, 2.0)
			reserve(BuildGrid.cells_for(BuildGrid.cell_of(corner), Vector2i(4, 4)), &"slope")
