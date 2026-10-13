class_name BuildGrid
extends RefCounted
## The 1 m build grid over the 48 by 48 m farm. Pure functions, nothing is stored.

const HALF: int = 24
const MAX_LINE: int = 24


static func cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x), floori(point.z))


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= -HALF and cell.x < HALF and cell.y >= -HALF and cell.y < HALF


static func turned(size: Vector2i, turns: int) -> Vector2i:
	return Vector2i(size.y, size.x) if posmod(turns, 2) == 1 else size


static func lowest_cell(anchor: Vector2i, size: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	return anchor - Vector2i((size.x - 1) / 2, (size.y - 1) / 2)


static func cells_for(lowest: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for z: int in size.y:
		for x: int in size.x:
			cells.append(lowest + Vector2i(x, z))
	return cells


static func middle(lowest: Vector2i, size: Vector2i) -> Vector3:
	return Vector3(lowest.x + size.x / 2.0, 0.0, lowest.y + size.y / 2.0)


static func yaw(turns: int) -> float:
	return deg_to_rad(90.0 * turns)


static func origin_for(item: BuildItemData, lowest: Vector2i, turns: int) -> Vector3:
	var spot: Vector3 = middle(lowest, turned(item.footprint, turns))
	return spot + Basis(Vector3.UP, yaw(turns)) * item.pivot_offset


static func cells_under(outline: PackedVector2Array) -> Array[Vector2i]:
	var box := Rect2(outline[0], Vector2.ZERO)
	for corner: Vector2 in outline:
		box = box.expand(corner)
	var found: Array[Vector2i] = []
	for z: int in range(floori(box.position.y), ceili(box.end.y)):
		for x: int in range(floori(box.position.x), ceili(box.end.x)):
			var square := PackedVector2Array([Vector2(x, z), Vector2(x + 1, z), Vector2(x + 1, z + 1), Vector2(x, z + 1)])
			if not Geometry2D.intersect_polygons(square, outline).is_empty():
				found.append(Vector2i(x, z))
	return found


static func line_turns(start: Vector2i, end: Vector2i) -> int:
	return 0 if absi(end.x - start.x) >= absi(end.y - start.y) else 1


static func line_anchors(start: Vector2i, end: Vector2i, length: int) -> Array[Vector2i]:
	var along_x: bool = line_turns(start, end) == 0
	var distance: int = (end.x - start.x) if along_x else (end.y - start.y)
	var sign_step: int = -1 if distance < 0 else 1
	var anchors: Array[Vector2i] = []
	@warning_ignore("integer_division")
	for index: int in mini(absi(distance) / maxi(length, 1) + 1, MAX_LINE):
		var step: int = index * length * sign_step
		anchors.append(start + (Vector2i(step, 0) if along_x else Vector2i(0, step)))
	return anchors
