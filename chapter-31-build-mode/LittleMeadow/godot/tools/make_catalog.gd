@tool
extends EditorScript
## Chapter 31: run with Ctrl+Shift+X. Writes the item files and catalog.tres.

const FOLDER: String = "res://resources/buildables/"
const PROPS: String = "res://scenes/props/"
const WORLD: String = "res://scenes/world/"
const FENCE: int = BuildItemData.Category.FENCE
const BUILDING: int = BuildItemData.Category.BUILDING
const DECOR: int = BuildItemData.Category.DECOR
const EDGE: Vector3 = Vector3(0.0, 0.0, -0.5)
const CORNER: Vector3 = Vector3(-0.5, 0.0, -0.5)

const ROWS: Array = [
	[&"fence", "Fence", FENCE, PROPS + "fence_section.tscn", 6, Vector2i(2, 1), EDGE, true, true, "A98458", "Fe"],
	[&"corner", "Corner post", FENCE, PROPS + "fence_corner.tscn", 3, Vector2i(1, 1), CORNER, false, false, "7A5C38", "Co"],
	[&"gate", "Gate", FENCE, PROPS + "fence_gate.tscn", 8, Vector2i(1, 1), CORNER, true, false, "C29A5B", "Ga"],
	[&"shed", "Shed", BUILDING, WORLD + "bld_shed.tscn", 75, Vector2i(3, 3), Vector3.ZERO, true, false, "B5473B", "Sh"],
	[&"well", "Well", BUILDING, WORLD + "bld_well.tscn", 40, Vector2i(2, 2), Vector3.ZERO, true, false, "7C8A94", "We"],
	[&"crate", "Crate", DECOR, PROPS + "prop_crate_large.tscn", 6, Vector2i(1, 1), Vector3.ZERO, true, false, "C9A66B", "Cr"],
	[&"barrel", "Barrel", DECOR, PROPS + "prop_barrel.tscn", 5, Vector2i(1, 1), Vector3.ZERO, false, false, "8A5A3A", "Ba"],
	[&"hay", "Hay bale", DECOR, PROPS + "prop_hay_bale.tscn", 5, Vector2i(1, 1), Vector3.ZERO, true, false, "D4B84A", "Hy"],
	[&"trough", "Trough", DECOR, PROPS + "prop_trough.tscn", 12, Vector2i(2, 1), Vector3.ZERO, true, false, "6E8CA0", "Tr"],
	[&"lantern", "Lantern", DECOR, PROPS + "prop_lantern.tscn", 8, Vector2i(1, 1), Vector3.ZERO, false, false, "F2C94C", "La"],
	[&"sign", "Signpost", DECOR, PROPS + "prop_sign_post.tscn", 4, Vector2i(1, 1), Vector3.ZERO, true, false, "B08D57", "Si"],
	[&"flowers", "Flower bed", DECOR, PROPS + "flower_bed.tscn", 3, Vector2i(1, 1), Vector3.ZERO, false, false, "E36A8D", "Fl"],
]


func _run() -> void:
	var catalog := BuildCatalog.new()
	for row: Array in ROWS:
		var file: String = FOLDER + "%s.tres" % row[0]
		if not ResourceLoader.exists(file):
			var item := BuildItemData.new()
			item.id = row[0]
			item.display_name = row[1]
			item.category = row[2]
			item.scene = load(row[3]) as PackedScene
			item.cost = row[4]
			item.footprint = row[5]
			item.pivot_offset = row[6]
			item.rotatable = row[7]
			item.line = row[8]
			item.color = Color(row[9])
			item.short_name = row[10]
			print("Saved ", file, " (error code ", ResourceSaver.save(item, file), ")")
		catalog.items.append(load(file) as BuildItemData)
	print("Saved ", FOLDER, "catalog.tres (error code ", ResourceSaver.save(catalog, FOLDER + "catalog.tres"), ")")
