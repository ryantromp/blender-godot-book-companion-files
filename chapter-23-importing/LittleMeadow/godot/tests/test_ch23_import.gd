extends Node
## Chapter 23: every .glb from Blender imported without trouble, and what arrived matches the export report
## (tests/data/ch23_expected.json is made from work/ch20/export_report.json).

const MODELS: String = "res://assets/models/"
const EXPECTED_PATH: String = "res://tests/data/ch23_expected.json"
const SHARED_DIR: String = "res://assets/materials/"
const SHOWCASE: String = "res://scenes/world/asset_showcase.tscn"

var expected: Dictionary = {}


func before_all(_t: Variant) -> void:
	expected = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED_PATH))


func _nodes(root: Node) -> Array[Node]:
	var all: Array[Node] = [root]
	all.append_array(root.find_children("*", "", true, false))
	return all


func _import_one(asset: String) -> Dictionary:
	var scene: PackedScene = load(MODELS + asset + ".glb")
	var info: Dictionary = {"scene": scene}
	if scene == null:
		return info
	var root: Node = scene.instantiate()
	var tris: int = 0
	var materials: Dictionary = {}
	var shapes: Array[String] = []
	var clips: Dictionary = {}
	var box := AABB()
	var first: bool = true
	for node in _nodes(root):
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			for s in mesh_node.mesh.get_surface_count():
				var arrays: Array = mesh_node.mesh.surface_get_arrays(s)
				tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				var mat: Material = mesh_node.mesh.surface_get_material(s)
				materials[mat.resource_name] = mat.resource_path
			var local_box: AABB = mesh_node.transform * mesh_node.get_aabb()
			box = local_box if first else box.merge(local_box)
			first = false
		elif node is CollisionShape3D:
			shapes.append((node as CollisionShape3D).shape.get_class())
		elif node is AnimationPlayer:
			var player := node as AnimationPlayer
			for clip_name in player.get_animation_list():
				var clip: Animation = player.get_animation(clip_name)
				clips[String(clip_name)] = clip.loop_mode == Animation.LOOP_LINEAR
	info["tris"] = tris
	info["materials"] = materials
	info["shapes"] = shapes
	info["clips"] = clips
	info["size"] = box.size
	root.free()
	return info


func test_every_glb_imports(t: Variant) -> void:
	var on_disk: Array[String] = []
	for file in DirAccess.get_files_at(MODELS):
		if file.ends_with(".glb"):
			on_disk.append(file.get_basename())
	on_disk.sort()
	var wanted: Array = expected["assets"].keys()
	wanted.sort()
	t.eq(on_disk.size(), 67, "67 glb files in assets/models")
	t.eq(on_disk, wanted, "the folder holds exactly the assets of the export report")
	for asset in on_disk:
		t.not_null(load(MODELS + asset + ".glb") as PackedScene, asset + " imports as a PackedScene")


func test_triangles_shapes_and_clips_match_the_report(t: Variant) -> void:
	for asset: String in expected["assets"]:
		var want: Dictionary = expected["assets"][asset]
		var got: Dictionary = _import_one(asset)
		if not t.not_null(got["scene"], asset):
			continue
		t.eq(got["tris"], int(want["tris"]), asset + " triangles")
		t.eq(got["shapes"], want["shapes"], asset + " collision shapes")
		var want_clips: Dictionary = want["clips"]
		var got_clips: Dictionary = got["clips"]
		var want_names: Array = want_clips.keys()
		var got_names: Array = got_clips.keys()
		want_names.sort()
		got_names.sort()
		t.eq(got_names, want_names, asset + " clip names (the -loop suffix is gone)")
		for clip_name: String in want_clips:
			t.eq(got_clips.get(clip_name), want_clips[clip_name], clip_name + " loop flag")


func test_materials_are_the_four_shared_ones(t: Variant) -> void:
	var seen: Dictionary = {}
	for asset: String in expected["assets"]:
		var want: Array = expected["assets"][asset]["materials"]
		var got: Dictionary = _import_one(asset)["materials"]
		var got_names: Array = got.keys()
		got_names.sort()
		t.eq(got_names, want, asset + " material names")
		for mat_name: String in got:
			t.eq(got[mat_name], SHARED_DIR + mat_name + ".tres", asset + ": " + mat_name + " is the shared file, not a copy")
			seen[mat_name] = true
	for mat_name in ["M_farm", "M_farm_ao", "M_emissive"]:
		var farm_mat: BaseMaterial3D = load(SHARED_DIR + mat_name + ".tres")
		t.eq(farm_mat.cull_mode, BaseMaterial3D.CULL_DISABLED, mat_name + " is double sided (Blender Backface Culling off)")
	var char_mat: BaseMaterial3D = load(SHARED_DIR + "M_char.tres")
	t.eq(char_mat.cull_mode, BaseMaterial3D.CULL_BACK, "M_char hides back faces (Blender Backface Culling on)")
	var seen_names: Array = seen.keys()
	seen_names.sort()
	t.eq(seen_names, ["M_char", "M_emissive", "M_farm", "M_farm_ao"], "exactly four materials in the whole set")


func test_sizes_match_after_the_axis_swap(t: Variant) -> void:
	for asset: String in expected["assets"]:
		var want: Array = expected["assets"][asset]["size"]
		var got: Vector3 = _import_one(asset)["size"]
		t.vec_approx(got, Vector3(want[0], want[1], want[2]), 0.006, asset + " size in metres (Blender x, z, y)")
	var crate: Vector3 = _import_one("prop_crate_small")["size"]
	t.vec_approx(crate, Vector3(0.6, 0.6, 0.6), 0.001, "the small crate is 0.6 m on every side")


func test_import_settings_in_project(t: Variant) -> void:
	var defaults: Dictionary = ProjectSettings.get_setting("importer_defaults/scene", {})
	t.ok(str(defaults.get("import_script/path", "")).begins_with("uid://"), "Import Script > Path is saved as the project default for Scene")
	var script_path: String = ResourceUID.get_id_path(ResourceUID.text_to_id(defaults["import_script/path"]))
	t.eq(script_path, "res://scripts/core/lm_post_import.gd", "and it points at the post-import script")
	for atlas in ["T_farm_atlas", "T_char_atlas"]:
		var cfg := ConfigFile.new()
		cfg.load("res://assets/textures/%s.png.import" % atlas)
		t.eq(cfg.get_value("params", "compress/mode"), 0, atlas + " is Lossless")
		t.eq(cfg.get_value("params", "mipmaps/generate"), true, atlas + " keeps its mipmaps")


func test_crate_wrapper_is_an_inherited_scene(t: Variant) -> void:
	var wrapper: PackedScene = load("res://scenes/props/prop_crate_small.tscn")
	t.not_null(wrapper, "wrapper scene loads")
	var base: PackedScene = wrapper.get_state().get_node_instance(0)
	t.eq(base.resource_path, MODELS + "prop_crate_small.glb", "the wrapper inherits from the glb")
	var crate: Node = wrapper.instantiate()
	var body := crate.get_node("Body") as StaticBody3D
	t.not_null(body, "Body was added in the wrapper")
	t.eq(body.collision_layer, 8, "layer 4 (obstacle) is bit value 8")
	var shape := (body.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	t.vec_approx(shape.size, Vector3(0.6, 0.6, 0.6), 0.001, "box matches the 0.6 m crate")
	t.not_null(crate.get_node_or_null("prop_crate_small"), "the imported mesh node is still there")
	crate.free()


func test_showcase_lays_out_every_asset(t: Variant) -> void:
	var showcase: Node3D = t.load_scene(SHOWCASE)
	await t.frames(3)
	t.eq(showcase.bays.size(), 10, "ten bays")
	var found: Array[String] = []
	for bay in showcase.bays:
		for item in bay.get_children():
			if item.scene_file_path != "":
				found.append(String(item.name))
	found.sort()
	var wanted: Array = expected["assets"].keys()
	wanted.sort()
	t.eq(found, wanted, "all 67 assets are placed once")
	var farmer: AnimationPlayer = showcase.get_node("Characters/char_farmer/AnimationPlayer")
	t.eq(String(farmer.current_animation), "char_farmer_idle", "the farmer plays idle")
	t.ok(farmer.is_playing(), "and is playing")
	var cow: AnimationPlayer = showcase.get_node("Characters/an_cow/AnimationPlayer")
	t.eq(String(cow.current_animation), "an_cow_idle", "the cow plays idle")
	showcase.free()
