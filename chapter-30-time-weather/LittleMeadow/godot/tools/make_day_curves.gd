@tool
extends EditorScript
## Press Ctrl+Shift+X (Cmd+Shift+X on a Mac) to write sky_top, sky_horizon, ambient_color and
## ambient_energy into res://resources/fx/. A row is an hour (0 to 24) and a value; 24 closes the day.

const FOLDER: String = "res://resources/fx/"

const SKY_TOP: Array = [
	[0.0, "141C4C"], [4.0, "1A2358"], [5.0, "2E3470"], [6.0, "8E8CBE"], [8.0, "5A8ED8"], [12.0, "5485D1"],
	[16.0, "5A8ED8"], [18.0, "8A6EA6"], [19.0, "3E3270"], [20.0, "222859"], [22.0, "18204F"], [24.0, "141C4C"],
]
const SKY_HORIZON: Array = [
	[0.0, "2A3A72"], [4.0, "30407A"], [5.0, "E9905F"], [6.0, "F6BE8E"], [8.0, "C2D8EE"], [12.0, "B8D1EB"],
	[16.0, "C2D8EE"], [18.0, "F5A877"], [19.0, "E5704F"], [20.0, "46406F"], [22.0, "2E3E78"], [24.0, "2A3A72"],
]
const AMBIENT_COLOR: Array = [
	[0.0, "3C4C92"], [4.0, "3E4E92"], [5.0, "9A7FA8"], [6.0, "D9B79C"], [8.0, "C4D2E8"], [12.0, "BBD0EC"],
	[16.0, "C4D2E8"], [18.0, "D9A98C"], [19.0, "A07C9C"], [20.0, "46538F"], [22.0, "3C4C92"], [24.0, "3C4C92"],
]
const AMBIENT: Array = [
	[0.0, 0.4], [5.0, 0.4], [6.0, 0.5], [8.0, 0.7], [16.0, 0.7], [18.0, 0.5], [19.0, 0.4], [24.0, 0.4],
]


func _run() -> void:
	_save(_gradient(SKY_TOP), "sky_top.tres")
	_save(_gradient(SKY_HORIZON), "sky_horizon.tres")
	_save(_gradient(AMBIENT_COLOR), "ambient_color.tres")
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = 1.0
	for row: Array in AMBIENT:
		curve.add_point(Vector2(row[0] / 24.0, row[1]))
	_save(curve, "ambient_energy.tres")


func _gradient(rows: Array) -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for row: Array in rows:
		offsets.append(row[0] / 24.0)
		colors.append(Color(row[1]))
	gradient.offsets = offsets
	gradient.colors = colors
	return gradient


func _save(resource: Resource, file: String) -> void:
	var error: int = ResourceSaver.save(resource, FOLDER + file)
	print("Saved ", FOLDER + file, " (error code ", error, ")")
