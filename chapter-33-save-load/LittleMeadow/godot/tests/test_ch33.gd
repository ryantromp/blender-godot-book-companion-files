extends Node

const FARM: String = "res://scenes/world/farm.tscn"
const ITEMS: String = "res://resources/items/"
const CROPS: String = "res://resources/crops/"
const TEST_FOLDER: String = "user://saves_test"
const REAL_FOLDER: String = "user://saves"
const PROBE := Vector3(0.5, 0.0, 12.0)
const TICKS: int = 480
const SPEEDUP: float = 8.0

var _hints: Array[String] = []
var _events: Array[String] = []
var _real_before: Array[String] = []
var _folder_before: String = ""
var _crops: Array[CropData] = []


func before_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = TICKS
	Engine.time_scale = SPEEDUP
	GameClock.running = false
	GameClock.paused = false
	GameClock.set_time(1, 360)
	Inventory.clear()
	Inventory.give_starting_items()
	Economy.money = Economy.START_MONEY
	Economy.ledger.clear()
	for node: Node in Engine.get_main_loop().root.get_children():
		if node.scene_file_path == FARM:
			node.free()
	for node: Node in Engine.get_main_loop().get_nodes_in_group(&"fx"):
		node.free()
	Fx.active = 0
	if _folder_before == "":
		_folder_before = SaveSystem.folder
	_real_before = _listing(REAL_FOLDER)
	SaveSystem.folder = TEST_FOLDER
	SaveSystem.autosave_enabled = false
	SaveSystem.current_slot = 1
	SaveSystem.playtime = 0.0
	SaveSystem.last_error = ""
	_wipe(TEST_FOLDER)
	_hints.clear()
	_events.clear()
	if not Events.hint_shown.is_connected(_on_hint):
		Events.hint_shown.connect(_on_hint)
		Events.game_saved.connect(_on_saved)
		Events.game_loaded.connect(_on_loaded)
		Events.save_failed.connect(_on_failed)
	_crops.clear()
	for id: String in ["carrot", "wheat", "pumpkin"]:
		_crops.append(load(CROPS + id + ".tres") as CropData)


func after_each(t: Variant) -> void:
	_wipe(TEST_FOLDER)
	SaveSystem.folder = _folder_before
	SaveSystem.autosave_enabled = false
	SaveSystem.current_slot = 1
	t.eq(_listing(REAL_FOLDER), _real_before, "the real save folder was not touched")
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	GameClock.running = false
	GameClock.paused = false


func _on_hint(text: String) -> void:
	_hints.append(text)


func _on_saved(slot: int) -> void:
	_events.append("saved:%d" % slot)


func _on_loaded(slot: int) -> void:
	_events.append("loaded:%d" % slot)


func _on_failed(message: String) -> void:
	_events.append("failed:" + message)


func _listing(folder: String) -> Array[String]:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(folder):
		return found
	for file: String in DirAccess.get_files_at(folder):
		found.append("%s:%d:%d" % [file, FileAccess.get_file_as_bytes(folder + "/" + file).size(), FileAccess.get_modified_time(folder + "/" + file)])
	return found


func _wipe(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + "/" + file)
	for sub: String in DirAccess.get_directories_at(folder):
		DirAccess.remove_absolute(folder + "/" + sub)
	DirAccess.remove_absolute(folder)


func _write(slot: int, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.folder)
	var file: FileAccess = FileAccess.open(SaveSystem.path_for(slot), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _write_dict(slot: int, data: Dictionary) -> void:
	_write(slot, JSON.stringify(data, "\t", false))


func _valid() -> Dictionary:
	return JSON.parse_string(JSON.stringify(SaveSystem.make_save())) as Dictionary


func _item(id: String) -> ItemData:
	return load(ITEMS + id + ".tres") as ItemData


func _farm(t: Variant) -> Node:
	await t.frames(2)
	var farm: Node = t.load_scene(FARM)
	await t.physics_frames(3)
	var map: RID = (farm.get_node("World") as NavigationRegion3D).get_navigation_map()
	var waited: int = 0
	while NavigationServer3D.map_get_closest_point(map, PROBE).distance_to(PROBE) > 1.0 and waited < 300:
		NavigationServer3D.map_force_update(map)
		await t.physics_frames(1)
		waited += 1
	return farm


func _plots(farm: Node) -> Array[SoilPlot]:
	var found: Array[SoilPlot] = []
	for node: Node in farm.get_tree().get_nodes_in_group(&"soil_plots"):
		found.append(node as SoilPlot)
	found.sort_custom(func(a: SoilPlot, b: SoilPlot) -> bool: return String(a.get_parent().name) < String(b.get_parent().name))
	return found


func _animals(farm: Node) -> Array[Animal]:
	var found: Array[Animal] = []
	for node: Node in farm.get_node("Animals").get_children():
		if node is Animal:
			found.append(node as Animal)
	return found


func _hen(farm: Node) -> Animal:
	return farm.get_node("Animals/Chicken_1") as Animal


func _build(farm: Node) -> BuildMode:
	return farm.get_node("Build") as BuildMode


func _panel(farm: Node) -> SavePanel:
	return farm.get_node("Hud/SavePanel") as SavePanel


func _await_bake(t: Variant, build: BuildMode) -> bool:
	var done: Array[bool] = [false]
	build.nav_baked.connect(func() -> void: done[0] = true, CONNECT_ONE_SHOT)
	var waited: int = 0
	while not done[0] and waited < 2400:
		await t.physics_frames(1)
		waited += 1
	var map: RID = build.world.get_navigation_map()
	NavigationServer3D.map_force_update(map)
	await t.physics_frames(3)
	return done[0]


func _path_length(path: PackedVector3Array) -> float:
	var length: float = 0.0
	for index: int in range(1, path.size()):
		length += Vector2(path[index].x, path[index].z).distance_to(Vector2(path[index - 1].x, path[index - 1].z))
	return length


func _dress(farm: Node) -> void:
	var build: BuildMode = _build(farm)
	build.try_place(build.catalog.find(&"fence"), Vector2i(0, 9), 1)
	build.try_place(build.catalog.find(&"fence"), Vector2i(0, 11), 1)
	build.try_place(build.catalog.find(&"crate"), Vector2i(6, 14), 0)
	GameClock.set_time(4, 13 * 60 + 25)
	Economy.money = 300
	Economy.add_money(21, "Sold carrots")
	Inventory.clear()
	Inventory.add(_item("carrot"), 7)
	Inventory.add(_item("seed_wheat"), 3)
	Inventory.add(_item("egg"), 2)
	var weather := farm.get_node("Weather") as Weather
	weather.world_seed = 4242
	weather.set_state(Weather.State.RAIN)
	var farmer := farm.get_node("Farmer") as Farmer
	farmer.global_position = Vector3(3.5, 0.0, 10.25)
	farmer.rotation.y = 1.234
	farmer.tools.select(&"can")
	farmer.tools.crop = farmer.tools.crops[1]
	farmer.can.water_level = 3
	var plots: Array[SoilPlot] = _plots(farm)
	plots[0].crop = _crops[1]
	plots[0].stage = 1
	plots[0].days_watered = 2
	plots[0]._set_state(SoilPlot.State.WATERED)
	plots[1]._set_state(SoilPlot.State.TILLED)
	plots[2].crop = _crops[0]
	plots[2].stage = _crops[0].last_stage()
	plots[2]._set_state(SoilPlot.State.RIPE)
	var hen: Animal = _hen(farm)
	hen.global_position = Vector3(-18.5, 0.0, -2.75)
	hen.rotation.y = -0.5
	hen.fed = true
	hen.days_fed = 1
	var other: Animal = farm.get_node("Animals/Chicken_2") as Animal
	other.global_position = Vector3(-17.0, 0.0, -4.5)
	other._spawn_product(Vector3(-16.5, 0.0, -4.0))
	(farm.get_node("Animals/Cow_1") as Animal).days_fed = 2


func _wreck(farm: Node) -> void:
	var build: BuildMode = _build(farm)
	build.clear_placed()
	GameClock.set_time(9, 100)
	Economy.money = 1
	Economy.ledger.clear()
	Inventory.clear()
	Inventory.add(_item("hay"), 1)
	var weather := farm.get_node("Weather") as Weather
	weather.world_seed = 7
	weather.set_state(Weather.State.CLEAR)
	var farmer := farm.get_node("Farmer") as Farmer
	farmer.global_position = Vector3(-9.0, 0.0, 6.0)
	farmer.rotation.y = 0.0
	farmer.tools.select(&"hoe")
	farmer.can.water_level = 0
	for plot: SoilPlot in _plots(farm):
		plot.crop = null
		plot.stage = 0
		plot.days_watered = 0
		plot._set_state(SoilPlot.State.EMPTY)
	for animal: Animal in _animals(farm):
		animal.fed = false
		animal.days_fed = 0
		if animal.has_product():
			animal.pickup.free()
			animal.pickup = null
	_hen(farm).global_position = Vector3(-14.0, 0.0, 3.0)


func test_tests_never_touch_the_real_saves(t: Variant) -> void:
	t.eq(SaveSystem.folder, TEST_FOLDER, "the tests save into their own folder")
	t.ne(SaveSystem.folder, SaveSystem.FOLDER, "which is not the real one")
	t.ne(_folder_before, SaveSystem.FOLDER, "and a headless run never used the real one either (%s)" % _folder_before)
	t.ok(not SaveSystem.autosave_enabled, "autosave is off")
	t.eq(SaveSystem.path_for(2), "user://saves_test/slot_2.json", "the path of slot 2")
	var farm: Node = await _farm(t)
	t.ok(SaveSystem.save_game(2), "save slot 2")
	t.ok(FileAccess.file_exists(TEST_FOLDER + "/slot_2.json"), "it lands in the test folder")
	t.ok(not FileAccess.file_exists(REAL_FOLDER + "/slot_2.json"), "and not in the real one")
	farm.queue_free()


func test_every_system_has_a_key_and_the_keys_are_unique(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var nodes: Dictionary[String, Node] = SaveSystem.saveables()
	var members: Array[Node] = farm.get_tree().get_nodes_in_group(&"saveable")
	t.eq(nodes.size(), members.size(), "as many keys as saveable nodes (%d), so no two share a key" % members.size())
	for key: String in ["clock", "weather", "inventory", "economy", "shop", "build", "farmer", "tools", "can"]:
		t.ok(nodes.has(key), "key %s" % key)
	t.eq(_plots(farm).size(), 40, "the field has 40 plots")
	var plot_keys: int = 0
	var animal_keys: int = 0
	for key: String in nodes:
		if key.begins_with("plot/"):
			plot_keys += 1
		if key.begins_with("animal/"):
			animal_keys += 1
	t.eq(plot_keys, _plots(farm).size(), "one key for each plot")
	t.eq(animal_keys, 6, "one key for each animal")
	t.ok(nodes.has("plot/Plot_3_1") and nodes.has("animal/Cow_2"), "keys come from the names in the scene")
	t.eq(SaveSystem._missing_core(), "", "all the core systems are there")
	var order: Array[String] = SaveSystem._order(nodes)
	t.eq(order.slice(0, 7), SaveSystem.CORE, "the core systems load first, in the fixed order")
	t.eq(order.size(), nodes.size(), "and nothing is left out")
	farm.queue_free()


func test_a_round_trip_gives_back_exactly_the_same_state(t: Variant) -> void:
	var farm: Node = await _farm(t)
	_dress(farm)
	await t.physics_frames(2)
	var before: Dictionary = SaveSystem.snapshot()
	t.ok(before.size() > 40, "the snapshot has %d systems" % before.size())
	t.ok(SaveSystem.save_game(1), "save")
	_wreck(farm)
	t.ne(SaveSystem.snapshot(), before, "the wrecked farm is different")
	t.ok(SaveSystem.load_game(1), "load")
	await t.physics_frames(2)
	var after: Dictionary = SaveSystem.snapshot()
	t.eq(after.keys(), before.keys(), "the same keys")
	for key: String in before:
		t.eq(after[key], before[key], "system %s is the same" % key)
	t.eq(after, before, "the whole snapshot is deep equal")
	t.eq(GameClock.day, 4, "day 4")
	t.eq(GameClock.time_text(), "13:25", "13:25")
	t.eq(Economy.money, 321, "321 coins")
	t.eq(Economy.ledger.size(), 4, "three purchases and one sale in the ledger")
	t.eq(Inventory.count_of(_item("carrot")), 7, "seven carrots")
	t.eq(Inventory.count_of(_item("hay")), 0, "the hay of the wrecked farm is gone")
	t.eq((farm.get_node("Weather") as Weather).state, Weather.State.RAIN, "rain")
	t.eq((farm.get_node("Weather") as Weather).world_seed, 4242, "the world seed")
	var farmer := farm.get_node("Farmer") as Farmer
	t.vec_approx(farmer.global_position, Vector3(3.5, 0.0, 10.25), 0.002, "the farmer stands where he stood")
	t.approx(farmer.rotation.y, 1.234, 0.002, "and looks the same way")
	t.eq(farmer.tools.current, &"can", "the can is in his hand")
	t.eq(farmer.tools.crop, farmer.tools.crops[1], "with wheat chosen")
	t.eq(farmer.can.water_level, 3, "three litres")
	var plots: Array[SoilPlot] = _plots(farm)
	t.eq(plots[0].state, SoilPlot.State.WATERED, "a watered plot")
	t.eq(plots[0].crop, _crops[1], "with wheat")
	t.eq(plots[0].stage, 1, "stage 1")
	t.eq(plots[0].days_watered, 2, "two days watered")
	t.eq(plots[1].state, SoilPlot.State.TILLED, "a tilled plot")
	t.eq(plots[2].state, SoilPlot.State.RIPE, "a ripe plot")
	t.eq(plots[3].state, SoilPlot.State.EMPTY, "an empty plot")
	t.ok(_hen(farm).fed and _hen(farm).days_fed == 1, "the fed hen")
	t.vec_approx(_hen(farm).global_position, Vector3(-18.5, 0.0, -2.75), 0.002, "stands where she stood")
	t.ok((farm.get_node("Animals/Chicken_2") as Animal).has_product(), "the egg is back")
	t.ok(not (farm.get_node("Animals/Chicken_3") as Animal).has_product(), "no egg that was never there")
	t.eq((farm.get_node("Animals/Cow_1") as Animal).days_fed, 2, "the cow remembers two days")
	t.eq(_build(farm).placed_root.get_child_count(), 3, "three things built")
	t.eq(Economy.money, 321, "and loading them cost nothing")
	farm.queue_free()


func test_the_file_on_disk_is_readable_json(t: Variant) -> void:
	var farm: Node = await _farm(t)
	_dress(farm)
	t.ok(SaveSystem.save_game(3), "save slot 3")
	var text: String = FileAccess.get_file_as_string(SaveSystem.path_for(3))
	var parser := JSON.new()
	t.eq(parser.parse(text), OK, "it parses")
	var data: Dictionary = parser.data
	t.eq(data.keys(), ["version", "saved_at", "summary", "systems"], "the four top level keys, in order")
	t.eq(int(data["version"]), SaveSystem.VERSION, "the version")
	t.eq(data["summary"]["day"], 4.0, "JSON stores every number as a float")
	t.eq(data["summary"]["time"], "13:25", "the time text")
	t.eq(data["summary"]["money"], 321.0, "the money")
	t.ok(text.begins_with("{\n\t\"version\": 2,"), "tabs, one key per line, version first")
	t.ok(text.find("\"economy\"") > text.find("\"clock\""), "the clock comes before the economy")
	t.eq((data["systems"]["clock"] as Dictionary).keys(), ["day", "minute"], "the clock has two fields")
	farm.queue_free()


func test_a_save_is_written_through_a_temporary_file(t: Variant) -> void:
	var farm: Node = await _farm(t)
	_write(2, "stale")
	DirAccess.rename_absolute(SaveSystem.path_for(2), SaveSystem.path_for(2) + ".tmp")
	t.ok(FileAccess.file_exists(SaveSystem.path_for(2) + ".tmp"), "a leftover temp file from a crash")
	t.ok(SaveSystem.save_game(2), "saving still works")
	t.eq(Array(DirAccess.get_files_at(TEST_FOLDER)), ["slot_2.json"], "only the finished file is left")
	t.ok(SaveSystem.save_game(2), "saving over an existing file")
	t.eq(Array(DirAccess.get_files_at(TEST_FOLDER)), ["slot_2.json"], "still only one file")
	t.ok(SaveSystem.read_slot(2)["error"] == "", "and it is a good one")
	var first: String = FileAccess.get_file_as_string(SaveSystem.path_for(2))
	GameClock.set_time(2, 600)
	t.ok(SaveSystem.save_game(2), "a second save with a new time")
	t.ne(FileAccess.get_file_as_string(SaveSystem.path_for(2)), first, "replaces the content")
	farm.queue_free()


func test_a_failed_write_keeps_the_old_save_and_leaves_no_temp_file(t: Variant) -> void:
	var farm: Node = await _farm(t)
	t.ok(SaveSystem.save_game(1), "a good save first")
	var good: String = FileAccess.get_file_as_string(SaveSystem.path_for(1))
	DirAccess.rename_absolute(SaveSystem.path_for(1), SaveSystem.path_for(1) + ".keep")
	DirAccess.make_dir_absolute(SaveSystem.path_for(1))
	t.ok(not SaveSystem.save_game(1), "the rename onto a folder fails")
	t.eq(SaveSystem.last_error, "Could not finish writing the save.", "and says so")
	t.ok(not FileAccess.file_exists(SaveSystem.path_for(1) + ".tmp"), "the temp file is cleaned up")
	t.eq(_events.back(), "failed:Could not finish writing the save.", "save_failed was emitted")
	t.eq(_hints.back(), "Could not finish writing the save.", "and a hint")
	DirAccess.remove_absolute(SaveSystem.path_for(1))
	DirAccess.rename_absolute(SaveSystem.path_for(1) + ".keep", SaveSystem.path_for(1))
	t.eq(FileAccess.get_file_as_string(SaveSystem.path_for(1)), good, "the earlier file was never touched")
	farm.queue_free()


func test_a_damaged_file_is_refused_and_nothing_changes(t: Variant) -> void:
	var farm: Node = await _farm(t)
	_dress(farm)
	t.ok(SaveSystem.save_game(1), "save")
	_wreck(farm)
	var before: Dictionary = SaveSystem.snapshot()
	var good: String = FileAccess.get_file_as_string(SaveSystem.path_for(1))
	var cases: Dictionary = {
		"cut in half": good.substr(0, good.length() / 2),
		"not json at all": "this is not a save",
		"empty": "",
		"blank": "  \n\t ",
		"an array": "[1, 2, 3]",
		"a number": "42",
	}
	for name: String in cases:
		_write(1, cases[name])
		_events.clear()
		t.ok(not SaveSystem.load_game(1), "%s: load says no" % name)
		t.ne(SaveSystem.last_error, "", "%s: there is a message (%s)" % [name, SaveSystem.last_error])
		t.eq(SaveSystem.snapshot(), before, "%s: nothing changed" % name)
		t.eq(_events.size(), 1, "%s: one event" % name)
		t.ok(_events[0].begins_with("failed:"), "%s: save_failed" % name)
	_write(1, "{ \"version\": 2,\n  oops")
	t.ok(not SaveSystem.load_game(1), "a broken line")
	t.ok(SaveSystem.last_error.begins_with("The save file is damaged (line "), "the message names a line: %s" % SaveSystem.last_error)
	_write(1, "")
	t.eq(SaveSystem.last_error if not SaveSystem.load_game(1) else "", "The save file is empty.", "an empty file")
	t.ok(not SaveSystem.load_game(2), "an empty slot")
	t.eq(SaveSystem.last_error, "There is no save in this slot.", "says there is nothing")
	farm.queue_free()


func test_a_wrong_version_is_refused(t: Variant) -> void:
	var farm: Node = await _farm(t)
	_dress(farm)
	_wreck(farm)
	var before: Dictionary = SaveSystem.snapshot()
	var data: Dictionary = _valid()
	data["version"] = 3
	_write_dict(1, data)
	t.ok(not SaveSystem.load_game(1), "version 3")
	t.eq(SaveSystem.last_error, "This save comes from a newer game (version 3).", "a newer game")
	data["version"] = 99
	_write_dict(1, data)
	t.ok(not SaveSystem.load_game(1), "version 99")
	data["version"] = 0
	_write_dict(1, data)
	t.ok(not SaveSystem.load_game(1), "version 0")
	t.eq(SaveSystem.last_error, "This save has a version that never existed (0).", "never existed")
	data["version"] = "2"
	_write_dict(1, data)
	t.ok(not SaveSystem.load_game(1), "a version written as text")
	t.eq(SaveSystem.last_error, "The save has no version number.", "is not a number")
	data.erase("version")
	_write_dict(1, data)
	t.ok(not SaveSystem.load_game(1), "no version at all")
	t.eq(SaveSystem.last_error, "The save has no version number.", "no number")
	t.eq(SaveSystem.snapshot(), before, "through all of that nothing changed")
	farm.queue_free()


func test_missing_or_wrong_keys_are_refused_before_anything_is_applied(t: Variant) -> void:
	var farm: Node = await _farm(t)
	_dress(farm)
	var saved: Dictionary = _valid()
	_wreck(farm)
	var before: Dictionary = SaveSystem.snapshot()
	var problems: Dictionary = {}
	var broken: Dictionary = saved.duplicate(true)
	broken["systems"].erase("economy")
	problems["The save has nothing for 'economy'."] = broken
	broken = saved.duplicate(true)
	broken["systems"].erase("plot/Plot_5_2")
	problems["The save has nothing for 'plot/Plot_5_2'."] = broken
	broken = saved.duplicate(true)
	broken["systems"]["clock"].erase("minute")
	problems["'clock' has no valid 'minute'."] = broken
	broken = saved.duplicate(true)
	broken["systems"]["clock"]["minute"] = "noon"
	problems["'clock' has no valid 'minute'. (text)"] = broken
	broken = saved.duplicate(true)
	broken["systems"]["farmer"] = [1, 2]
	problems["'farmer' should be a dictionary."] = broken
	broken = saved.duplicate(true)
	broken["systems"]["build"] = {}
	problems["'build' should be a array."] = broken
	broken = saved.duplicate(true)
	broken["systems"]["animal/Cow_1"]["position"] = "here"
	problems["'animal/Cow_1' has no valid 'position'."] = broken
	broken = saved.duplicate(true)
	broken["summary"].erase("money")
	problems["The summary has no valid 'money'."] = broken
	broken = saved.duplicate(true)
	broken.erase("systems")
	problems["The save has no valid 'systems'."] = broken
	broken = saved.duplicate(true)
	broken["saved_at"] = 5
	problems["The save has no valid 'saved_at'."] = broken
	for expected: String in problems:
		_write_dict(1, problems[expected])
		t.ok(not SaveSystem.load_game(1), "refused: " + expected)
		if not expected.ends_with("(text)"):
			t.eq(SaveSystem.last_error, expected, "the message")
		t.eq(SaveSystem.snapshot(), before, "nothing was applied: " + expected)
	farm.queue_free()


func test_unknown_keys_and_odd_entries_do_not_stop_a_load(t: Variant) -> void:
	var farm: Node = await _farm(t)
	_dress(farm)
	var saved: Dictionary = _valid()
	saved["systems"]["tractor"] = {"fuel": 3}
	saved["systems"]["inventory"]["stacks"].append({"slot": 20})
	saved["systems"]["inventory"]["stacks"].append("junk")
	saved["systems"]["inventory"]["stacks"].append({"slot": 21, "id": "no_such_item", "count": 2})
	saved["systems"]["inventory"]["stacks"].append({"slot": 99, "id": "carrot", "count": 2})
	saved["systems"]["economy"]["ledger"].append({"day": 1})
	saved["systems"]["build"].append({"id": "fence"})
	saved["systems"]["build"].append({"id": "castle", "cell": [1, 1], "turns": 0})
	saved["systems"]["tools"]["current"] = "chainsaw"
	saved["systems"]["can"]["level"] = 500
	saved["systems"]["clock"]["minute"] = 99999
	saved["systems"]["plot/Plot_0_0"]["crop"] = "turnip"
	saved["systems"]["plot/Plot_0_0"]["state"] = 3
	saved["systems"]["plot/Plot_0_1"]["stage"] = 40
	saved["systems"]["weather"]["state"] = 17
	_write_dict(1, saved)
	_wreck(farm)
	t.ok(SaveSystem.load_game(1), "the load goes through")
	t.eq(Inventory.used_slots(), 3, "only the three good stacks arrived")
	t.eq(Economy.ledger.size(), 4, "the half ledger line was skipped")
	t.eq(_build(farm).placed_root.get_child_count(), 3, "the two bad build entries were skipped")
	var farmer := farm.get_node("Farmer") as Farmer
	t.eq(farmer.tools.current, &"hand", "an unknown tool becomes the hand")
	t.eq(farmer.can.water_level, farmer.can.capacity, "a water level is clamped to the can")
	t.eq(GameClock.minute_of_day, 24 * 60 - 1, "a minute is clamped to the day")
	t.eq(_plots(farm)[0].state, SoilPlot.State.TILLED, "a plot with a crop nobody knows is tilled earth")
	t.eq(_plots(farm)[0].crop, null, "with no crop")
	t.ok(_plots(farm)[1].stage <= (_plots(farm)[1].crop.last_stage() if _plots(farm)[1].crop != null else 0), "a stage is clamped")
	t.eq((farm.get_node("Weather") as Weather).state, Weather.State.RAIN, "a weather state is clamped")
	farm.queue_free()


func test_a_new_system_the_old_file_does_not_know_is_refused(t: Variant) -> void:
	var farm: Node = await _farm(t)
	t.ok(SaveSystem.save_game(1), "an old save")
	var extra := Node.new()
	extra.set_script(load("res://tests/data/extra_saveable.gd"))
	farm.add_child(extra)
	var before: Dictionary = SaveSystem.snapshot()
	t.ok(before.has("extra"), "the new node is part of the snapshot")
	t.ok(not SaveSystem.load_game(1), "the old file has nothing for it")
	t.eq(SaveSystem.last_error, "The save has nothing for 'extra'.", "so the load is refused")
	t.eq(SaveSystem.snapshot(), before, "and nothing changed")
	extra.free()
	farm.queue_free()


func test_the_sample_file_in_the_book_is_a_real_save_that_loads(t: Variant) -> void:
	var farm: Node = await _farm(t)
	DirAccess.make_dir_recursive_absolute(SaveSystem.folder)
	var text: String = FileAccess.get_file_as_string("res://tests/data/sample_slot.json")
	t.ok(text.length() > 1000, "the sample file is there")
	var file: FileAccess = FileAccess.open(SaveSystem.path_for(1), FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var read: Dictionary = SaveSystem.read_slot(1)
	t.eq(read["error"], "", "the sample reads cleanly")
	t.eq(int(read["data"]["version"]), SaveSystem.VERSION, "at the current version")
	t.eq(SaveSystem.validate(read["data"]), "", "and it matches the live systems")
	t.eq(int(read["data"]["summary"]["money"]), 212, "212 coins in the summary")
	t.ok(SaveSystem.load_game(1), "it loads")
	t.eq(Economy.money, 212, "with 212 coins")
	t.eq(GameClock.day, 3, "on day 3")
	t.eq(GameClock.minute_of_day, 930, "at 15:30")
	farm.queue_free()


func test_a_version_1_file_is_upgraded_to_version_2(t: Variant) -> void:
	var farm: Node = await _farm(t)
	_dress(farm)
	var old: Dictionary = _valid()
	old["version"] = 1
	old["summary"]["coins"] = old["summary"]["money"]
	old["summary"].erase("money")
	_write_dict(1, old)
	var read: Dictionary = SaveSystem.read_slot(1)
	t.eq(read["error"], "", "a version 1 file is readable")
	t.eq(int(read["data"]["version"]), 2, "it now says version 2")
	t.ok(read["data"]["summary"].has("money") and not read["data"]["summary"].has("coins"), "coins became money")
	t.eq(read["data"]["summary"]["money"], 321.0, "with the same number")
	t.eq(FileAccess.get_file_as_string(SaveSystem.path_for(1)).find("\"coins\"") >= 0, true, "the file on disk is left alone")
	var entry: Dictionary = SaveSystem.list_slots()[1]
	t.eq(entry["money"], 321, "the slot list shows the money")
	_wreck(farm)
	t.ok(SaveSystem.load_game(1), "and it loads")
	t.eq(Economy.money, 321, "with 321 coins")
	t.eq(GameClock.day, 4, "on day 4")
	var plain: Dictionary = {"version": 2, "summary": {"coins": 5}}
	t.eq(SaveSystem.upgrade(plain), "", "a version 2 file is not touched")
	t.ok(plain["summary"].has("coins"), "its coins stay")
	t.eq(SaveSystem.upgrade({"version": 1}), "", "a version 1 file with no summary does not crash the upgrade")
	farm.queue_free()


func test_the_slot_list_has_one_entry_for_each_slot(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var empty: Array[Dictionary] = SaveSystem.list_slots()
	t.eq(empty.size(), 4, "the autosave and three slots")
	t.eq(empty.map(func(e: Dictionary) -> String: return e["label"]), ["Autosave", "Slot 1", "Slot 2", "Slot 3"], "the labels")
	for entry: Dictionary in empty:
		t.ok(not entry["exists"] and entry["error"] == "", "slot %d is empty" % entry["slot"])
		t.ok(not SaveSystem.has_save(entry["slot"]), "has_save says no")
	GameClock.set_time(3, 7 * 60 + 30)
	Economy.money = 250
	SaveSystem.playtime = 3725.9
	t.ok(SaveSystem.save_game(2), "save slot 2")
	var slots: Array[Dictionary] = SaveSystem.list_slots()
	t.ok(slots[2]["exists"], "slot 2 exists")
	t.eq(slots[2]["day"], 3, "day 3")
	t.eq(slots[2]["time"], "07:30", "07:30")
	t.eq(slots[2]["money"], 250, "250 coins")
	t.eq(slots[2]["playtime"], 3725, "3725 seconds played")
	t.eq(slots[2]["error"], "", "no error")
	var stamp := RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$")
	t.ok(stamp.search(slots[2]["saved_at"]) != null, "an ISO timestamp: %s" % slots[2]["saved_at"])
	t.ok(not slots[1]["exists"] and not slots[3]["exists"], "the others are still empty")
	t.eq(SaveSystem.current_slot, 2, "the last manual slot is remembered")
	t.ok(SaveSystem.save_game(SaveSystem.AUTOSAVE_SLOT), "the autosave slot")
	t.eq(SaveSystem.current_slot, 2, "an autosave does not change the remembered slot")
	t.ok(SaveSystem.list_slots()[0]["exists"], "slot 0 exists")
	_write(3, "garbage")
	var bad: Dictionary = SaveSystem.list_slots()[3]
	t.ok(bad["exists"], "a damaged file still exists")
	t.ok(String(bad["error"]).begins_with("The save file is damaged"), "and has an error: %s" % bad["error"])
	t.ok(SaveSystem.delete_slot(3), "delete the damaged one")
	t.ok(not SaveSystem.has_save(3), "gone")
	t.ok(not SaveSystem.delete_slot(3), "deleting nothing says false")
	t.ok(not SaveSystem.save_game(4), "slot 4 does not exist")
	t.eq(SaveSystem.last_error, "There is no slot 4.", "says so")
	t.ok(not SaveSystem.save_game(-1), "nor slot -1")
	farm.queue_free()


func test_saving_and_loading_tell_the_game_about_it(t: Variant) -> void:
	var farm: Node = await _farm(t)
	t.ok(SaveSystem.save_game(1), "save")
	t.eq(_events, ["saved:1"], "game_saved(1)")
	t.eq(_hints, ["Game saved"], "the toast text")
	_events.clear()
	_hints.clear()
	t.ok(SaveSystem.load_game(1), "load")
	t.eq(_events, ["loaded:1"], "game_loaded(1)")
	t.eq(_hints, ["Game loaded"], "and its toast")
	farm.queue_free()


func test_without_a_farm_there_is_nothing_to_save_or_load(t: Variant) -> void:
	t.ok(not SaveSystem.save_game(1), "no save without a farm")
	t.eq(SaveSystem.last_error, "There is no farm running to save.", "the message")
	t.ok(not SaveSystem.has_save(1), "and no file")
	t.ok(not SaveSystem.load_game(1), "no load without a farm")
	t.eq(SaveSystem.last_error, "There is no farm running to load into.", "the message")
	t.eq(SaveSystem.saveables().size(), 3, "only the three autoloads are saveable")


func test_loading_restores_the_light_and_the_camera(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var sun := farm.get_node("Sun") as DirectionalLight3D
	GameClock.set_time(2, 12 * 60)
	(farm.get_node("DayNight") as DayNight).snap()
	var noon: float = sun.light_energy
	t.ok(noon > 0.3, "the sun shines at noon (%.2f)" % noon)
	t.ok(SaveSystem.save_game(1), "save at noon")
	GameClock.set_time(2, 2 * 60)
	(farm.get_node("DayNight") as DayNight).snap()
	t.ok(sun.light_energy < noon * 0.2, "it is dark at 02:00 (%.2f)" % sun.light_energy)
	var rig := farm.get_node("CameraRig") as CameraRig
	rig.target = null
	rig.global_position = Vector3(10.0, 0.0, 10.0)
	rig.snap()
	t.ok(SaveSystem.load_game(1), "load")
	t.approx(sun.light_energy, noon, 0.001, "the light jumped to noon at once")
	t.eq(GameClock.time_text(), "12:00", "the clock says noon")
	farm.queue_free()


func test_a_built_fence_blocks_the_path_again_after_a_load(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var region := farm.get_node("World") as NavigationRegion3D
	var map: RID = region.get_navigation_map()
	var a := Vector3(-3.0, 0.0, 14.0)
	var b := Vector3(4.0, 0.0, 14.0)
	var straight: float = _path_length(NavigationServer3D.map_get_path(map, a, b, true))
	t.ok(straight < 8.0, "the open meadow: %.1f m" % straight)
	for index: int in 5:
		t.not_null(build.try_place(build.catalog.find(&"fence"), Vector2i(0, 9 + 2 * index), 1), "section %d" % index)
	t.ok(await _await_bake(t, build), "baked with the fence")
	var around: float = _path_length(NavigationServer3D.map_get_path(map, a, b, true))
	t.ok(around > straight + 3.0, "the detour: %.1f m" % around)
	var money: int = Economy.money
	t.ok(SaveSystem.save_game(1), "save with the fence")
	build.clear_placed()
	t.ok(await _await_bake(t, build), "baked without it")
	var open: float = _path_length(NavigationServer3D.map_get_path(map, a, b, true))
	t.ok(open < straight + 0.6, "the open way again: %.1f m" % open)
	t.eq(build.map.kind_at(Vector2i(0, 9)), &"", "the grid is free again")
	t.ok(SaveSystem.load_game(1), "load")
	t.eq(build.placed_root.get_child_count(), 5, "five sections are back")
	t.eq(build.map.kind_at(Vector2i(0, 9)), &"placed", "the grid holds them")
	t.eq(Economy.money, money, "they cost nothing")
	t.ok(await _await_bake(t, build), "the mesh is baked again after the load")
	var again: float = _path_length(NavigationServer3D.map_get_path(map, a, b, true))
	t.ok(again > straight + 3.0, "the fence blocks again: %.1f m" % again)
	t.approx(again, around, 0.3, "by the same detour")
	farm.queue_free()


func test_a_new_day_saves_the_autosave_slot_once_the_day_has_started(t: Variant) -> void:
	var farm: Node = await _farm(t)
	SaveSystem.autosave_enabled = true
	GameClock.set_time(3, 23 * 60 + 50)
	Economy.money = 77
	t.ok(not SaveSystem.has_save(0), "no autosave yet")
	GameClock.advance_minutes(20)
	t.ok(not SaveSystem.has_save(0), "not in the same frame, the day is not set up yet")
	await t.frames(3)
	t.ok(SaveSystem.has_save(0), "an autosave a moment later")
	var entry: Dictionary = SaveSystem.list_slots()[0]
	t.eq(entry["day"], 4, "day 4")
	t.eq(entry["time"], "00:10", "00:10, the clock is already past midnight")
	t.eq(entry["money"], 77, "77 coins")
	t.eq(_hints.count("Game saved"), 1, "one toast")
	t.eq(_events, ["saved:0"], "one game_saved(0)")
	t.eq(SaveSystem.current_slot, 1, "the manual slot is not changed")
	var weather := farm.get_node("Weather") as Weather
	var data: Dictionary = SaveSystem.read_slot(0)["data"]
	t.eq(int(data["systems"]["weather"]["state"]), int(weather.state), "the autosave holds the weather of the new day")
	SaveSystem.autosave_enabled = false
	_events.clear()
	GameClock.advance_minutes(24 * 60)
	await t.frames(3)
	t.eq(_events, [], "with autosave off nothing is written")
	farm.queue_free()


func test_closing_the_window_autosaves(t: Variant) -> void:
	var farm: Node = await _farm(t)
	SaveSystem.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	t.ok(not SaveSystem.has_save(0), "with autosave off a close request writes nothing")
	SaveSystem.autosave_enabled = true
	GameClock.set_time(6, 9 * 60)
	SaveSystem.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	t.ok(SaveSystem.has_save(0), "with it on, the autosave slot is written")
	t.eq(SaveSystem.list_slots()[0]["day"], 6, "with the day of the close")
	t.eq(_hints.back(), "Game saved", "and a toast")
	farm.queue_free()


func test_opening_the_panel_pauses_the_clock_and_locks_out_the_other_windows(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: SavePanel = _panel(farm)
	var shop := farm.get_node("Hud/ShopPanel") as ShopPanel
	var build: BuildMode = _build(farm)
	t.ok(not panel.visible and not panel.is_open, "closed at the start")
	t.ok(not GameClock.paused, "the clock runs")
	t.ok(panel.open(), "open")
	t.ok(panel.visible and panel.is_in_group(&"modal"), "visible, and in the modal group")
	t.ok(GameClock.paused, "the clock is paused")
	t.ok(not shop.open(), "the shop refuses to open on top of it")
	build.set_active(true)
	t.ok(not build.active, "build mode refuses too")
	var closed: Array[bool] = [false]
	panel.closed.connect(func() -> void: closed[0] = true)
	panel.close()
	t.ok(closed[0], "closed was emitted")
	t.ok(not panel.visible and not panel.is_in_group(&"modal"), "hidden, and out of the group")
	t.ok(not GameClock.paused, "the clock runs again")
	t.ok(shop.open(), "now the shop opens")
	t.ok(not panel.open(), "and the save panel refuses")
	t.ok(not panel.is_open, "it stays closed")
	shop.close()
	build.set_active(true)
	t.ok(build.active, "build mode on")
	t.ok(not panel.open(), "the panel refuses while building")
	t.eq(_hints.back(), "Close build mode first.", "and says why")
	build.set_active(false)
	GameClock.paused = true
	t.ok(panel.open(), "open on a paused clock")
	panel.close()
	t.ok(GameClock.paused, "closing leaves the clock paused, as it found it")
	GameClock.paused = false
	farm.queue_free()


func test_the_panel_lists_the_slots_and_asks_before_it_overwrites(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: SavePanel = _panel(farm)
	GameClock.set_time(5, 8 * 60 + 5)
	Economy.money = 420
	panel.open()
	t.eq(panel.rows.get_child_count(), 4, "four rows")
	var row: Control = panel.rows.get_child(1)
	t.eq((row.get_child(0) as Label).text, "Slot 1", "the name")
	t.eq((row.get_child(1) as Label).text, "Empty", "an empty slot says Empty")
	t.ok(not (row.get_child(2) as Button).disabled, "Save is on")
	t.ok((row.get_child(3) as Button).disabled and (row.get_child(4) as Button).disabled, "Load and Delete are off")
	t.ok((panel.rows.get_child(0).get_child(2) as Button).disabled, "the autosave row cannot be saved by hand")
	(row.get_child(2) as Button).pressed.emit()
	t.ok(SaveSystem.has_save(1), "Save on an empty slot saves at once")
	t.ok(not panel.confirm_row.visible, "without asking")
	t.eq(panel.message_label.text, "Saved to Slot 1.", "and says so")
	row = panel.rows.get_child(1)
	var info: String = (row.get_child(1) as Label).text
	t.ok(info.begins_with("Day 5, 08:05   420 coins\n"), "the row shows day, time and money: %s" % info.replace("\n", " / "))
	t.ok(info.contains("played 0 h 00 min"), "and the play time")
	Economy.money = 999
	(row.get_child(2) as Button).pressed.emit()
	t.ok(panel.confirm_row.visible, "Save on a used slot asks first")
	t.eq(panel.confirm_label.text, "Overwrite Slot 1?", "the question")
	t.eq(SaveSystem.list_slots()[1]["money"], 420, "nothing is written yet")
	panel.no_button.pressed.emit()
	t.ok(not panel.confirm_row.visible, "No closes the question")
	t.eq(SaveSystem.list_slots()[1]["money"], 420, "and the file is the same")
	(panel.rows.get_child(1).get_child(2) as Button).pressed.emit()
	panel.yes_button.pressed.emit()
	t.eq(SaveSystem.list_slots()[1]["money"], 999, "Yes overwrites")
	t.ok(not panel.confirm_row.visible, "and the question is gone")
	(panel.rows.get_child(1).get_child(4) as Button).pressed.emit()
	t.eq(panel.confirm_label.text, "Delete Slot 1 for good?", "Delete asks too")
	panel.yes_button.pressed.emit()
	t.ok(not SaveSystem.has_save(1), "the file is gone")
	t.eq((panel.rows.get_child(1).get_child(1) as Label).text, "Empty", "the row is empty again")
	panel.close()
	farm.queue_free()


func test_the_panel_shows_why_a_slot_cannot_be_loaded(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: SavePanel = _panel(farm)
	SaveSystem.save_game(1)
	_write(2, "{ broken")
	var data: Dictionary = _valid()
	data["version"] = 7
	_write_dict(3, data)
	panel.open()
	var damaged: Control = panel.rows.get_child(2)
	var text: String = (damaged.get_child(1) as Label).text
	t.ok(text.begins_with("Damaged: The save file is damaged (line"), "a damaged slot says so: %s" % text)
	t.eq((damaged.get_child(1) as Label).get_theme_color("font_color"), SavePanel.BAD, "in red")
	t.ok((damaged.get_child(3) as Button).disabled, "Load is off")
	t.ok((damaged.get_child(3) as Button).tooltip_text.begins_with("The save file is damaged"), "and the tooltip says why")
	t.ok(not (damaged.get_child(4) as Button).disabled, "Delete still works, so the slot can be cleared")
	var newer: Control = panel.rows.get_child(3)
	t.eq((newer.get_child(1) as Label).text, "Damaged: This save comes from a newer game (version 7).", "a newer file")
	var good: Control = panel.rows.get_child(1)
	t.ok(not (good.get_child(3) as Button).disabled, "a good slot can be loaded")
	_wreck(farm)
	(good.get_child(3) as Button).pressed.emit()
	t.ok(not panel.is_open, "loading closes the panel")
	t.eq(_events.back(), "loaded:1", "and loads")
	t.ok(not GameClock.paused, "the clock runs")
	farm.queue_free()


func test_a_panel_can_be_made_load_only(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: SavePanel = _panel(farm)
	SaveSystem.save_game(1)
	panel.allow_save = false
	panel.open()
	for index: int in 4:
		var row: Control = panel.rows.get_child(index)
		t.ok((row.get_child(2) as Button).disabled, "row %d: Save is off" % index)
		t.eq((row.get_child(2) as Button).tooltip_text, "Saving is not possible here.", "row %d: and says why" % index)
	t.ok(not (panel.rows.get_child(1).get_child(3) as Button).disabled, "Load is on")
	panel.close()
	panel.allow_save = true
	panel.allow_load = false
	panel.open()
	t.ok((panel.rows.get_child(1).get_child(3) as Button).disabled, "with loading off, Load is off")
	panel.close()
	panel.allow_load = true
	farm.queue_free()


func test_the_function_keys_save_load_and_open_the_menu(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: SavePanel = _panel(farm)
	GameClock.set_time(7, 15 * 60)
	await t.frames(2)
	t.key(KEY_F5)
	t.key(KEY_F5, false)
	await t.frames(2)
	t.ok(SaveSystem.has_save(1), "F5 saves into the current slot")
	GameClock.set_time(2, 100)
	t.key(KEY_F9)
	t.key(KEY_F9, false)
	await t.frames(2)
	t.eq(GameClock.day, 7, "F9 loads it")
	t.eq(_hints.back(), "Game loaded", "with a toast")
	t.key(KEY_F10)
	t.key(KEY_F10, false)
	await t.frames(2)
	t.ok(panel.is_open, "F10 opens the panel")
	SaveSystem.delete_slot(1)
	t.key(KEY_F5)
	t.key(KEY_F5, false)
	await t.frames(2)
	t.ok(not SaveSystem.has_save(1), "F5 does nothing while the panel is open")
	t.key(KEY_F10)
	t.key(KEY_F10, false)
	await t.frames(2)
	t.ok(not panel.is_open, "F10 closes it again")
	t.key(KEY_F10)
	t.key(KEY_F10, false)
	await t.frames(2)
	t.key(KEY_ESCAPE)
	t.key(KEY_ESCAPE, false)
	await t.frames(2)
	t.ok(not panel.is_open, "Escape closes it too")
	farm.queue_free()


func test_a_save_taken_in_the_middle_of_a_walk_loads_as_a_stopped_farmer(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	farmer.global_position = Vector3(0.5, 0.0, 10.0)
	farmer.walk_to(Vector3(6.5, 0.0, 12.0))
	await t.physics_frames(30)
	t.ok(farmer.walking, "he is walking")
	t.ok(SaveSystem.save_game(1), "save on the way")
	var spot: Vector3 = farmer.global_position
	await t.physics_frames(60)
	t.ok(farmer.global_position.distance_to(spot) > 0.3, "he walks on")
	t.ok(SaveSystem.load_game(1), "load")
	t.ok(not farmer.walking, "he stands still")
	t.vec_approx(farmer.global_position, spot, 0.002, "where he was saved")
	await t.physics_frames(30)
	t.vec_approx(farmer.global_position, spot, 0.002, "and he stays there")
	farm.queue_free()
