extends Node

const FARM: String = "res://scenes/world/farm.tscn"
const TITLE: String = "res://scenes/ui/title.tscn"
const CROP_FOLDER: String = "res://resources/crops/"
const ITEM_FOLDER: String = "res://resources/items/"
const TEST_FOLDER: String = "user://saves_test"
const REAL_FOLDER: String = "user://saves"
const TEST_SETTINGS: String = "user://settings_test.cfg"
const REAL_SETTINGS: String = "user://settings.cfg"
const TICKS: int = 480
const SPEEDUP: float = 8.0
const MONKEY_SEED: int = 35
const MONKEY_EVENTS: int = 300


class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var _mutex: Mutex = Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		var text: String = "%s (%s:%d) %s %s" % [function, file.get_file(), line, code, rationale]
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings.append(text)
		else:
			errors.append(text)
		_mutex.unlock()

	func clear() -> void:
		_mutex.lock()
		errors.clear()
		warnings.clear()
		_mutex.unlock()


var _catcher: ErrorCatcher
var _folder_before: String = ""
var _saves_before: Array[String] = []
var _settings_before: String = ""
var _settings_path_before: String = ""
var _log: Array[String] = []


func before_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = TICKS
	Engine.time_scale = SPEEDUP
	GameClock.running = false
	GameClock.paused = false
	GameClock.set_time(1, 360)
	get_tree().paused = false
	_free_scenes()
	Fx.active = 0
	if _folder_before == "":
		_folder_before = SaveSystem.folder
		_settings_path_before = Settings.path
	_saves_before = _listing(REAL_FOLDER)
	_settings_before = _fingerprint(REAL_SETTINGS)
	SaveSystem.folder = TEST_FOLDER
	SaveSystem.autosave_enabled = false
	SaveSystem.current_slot = 1
	SaveSystem.playtime = 0.0
	SaveSystem.last_error = ""
	Settings.path = TEST_SETTINGS
	Settings.reset()
	Settings.apply()
	_wipe(TEST_FOLDER)
	DirAccess.remove_absolute(TEST_SETTINGS)
	Flow.fade_seconds = 0.0
	Flow.busy = false
	Flow.last_message = ""
	AudioBus.min_gap_msec = 0
	AudioBus.missing.clear()
	Flow.reset_run()
	_log.clear()
	_catcher = ErrorCatcher.new()
	OS.add_logger(_catcher)


func after_each(t: Variant) -> void:
	OS.remove_logger(_catcher)
	t.eq(_catcher.errors, [] as Array[String], "no error was logged")
	t.eq(_catcher.warnings, [] as Array[String], "no warning was logged")
	get_tree().paused = false
	_free_scenes()
	_wipe(TEST_FOLDER)
	DirAccess.remove_absolute(TEST_SETTINGS)
	SaveSystem.folder = _folder_before
	SaveSystem.autosave_enabled = false
	t.eq(_listing(REAL_FOLDER), _saves_before, "the real save folder was not touched")
	t.eq(_fingerprint(REAL_SETTINGS), _settings_before, "the real settings file was not touched")
	Settings.path = _settings_path_before
	Settings.reset()
	Settings.apply()
	AudioBus.min_gap_msec = 40
	Flow.fade_seconds = 0.5
	Flow.busy = false
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	GameClock.running = false
	GameClock.paused = false
	Input.action_release("move_run")


func _free_scenes() -> void:
	var root: Node = Engine.get_main_loop().root
	for node: Node in root.get_children():
		if node.scene_file_path == FARM or node.scene_file_path == TITLE:
			node.free()
	Engine.get_main_loop().current_scene = null
	for node: Node in Engine.get_main_loop().get_nodes_in_group(&"fx"):
		node.free()


func _listing(folder: String) -> Array[String]:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(folder):
		return found
	for file: String in DirAccess.get_files_at(folder):
		found.append("%s:%d" % [file, FileAccess.get_file_as_bytes(folder + "/" + file).size()])
	return found


func _fingerprint(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "missing"
	return "%d:%d" % [FileAccess.get_file_as_bytes(path).size(), FileAccess.get_modified_time(path)]


func _wipe(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + "/" + file)
	DirAccess.remove_absolute(folder)


func _item(id: String) -> ItemData:
	return load(ITEM_FOLDER + id + ".tres") as ItemData


func _tap(t: Variant, keycode: Key) -> void:
	t.key(keycode, true)
	await t.frames(2)
	t.key(keycode, false)
	await t.frames(1)


func _settle_farm(t: Variant, farm: Node) -> void:
	var probe: Vector3 = Vector3(0.5, 0.0, 12.0)
	var map: RID = (farm.get_node("World") as NavigationRegion3D).get_navigation_map()
	var waited: int = 0
	while NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) > 1.0 and waited < 300:
		NavigationServer3D.map_force_update(map)
		await t.physics_frames(1)
		waited += 1


func _start_from_title(t: Variant) -> Node:
	var title: Node = t.load_scene(TITLE)
	Engine.get_main_loop().current_scene = title
	await t.frames(3)
	var button: Button = title.get_node("%NewButton") as Button
	await t.click(button.get_global_rect().get_center())
	var waited: int = 0
	while not Flow.farm_running() and waited < 600:
		await t.frames(1)
		waited += 1
	var farm: Node = Engine.get_main_loop().current_scene
	await t.physics_frames(3)
	await _settle_farm(t, farm)
	return farm


func _screen(farm: Node, point: Vector3) -> Vector2:
	return (farm.get_node("CameraRig") as CameraRig).camera.unproject_position(point)


func _look_at(farm: Node, point: Vector3) -> void:
	var rig: CameraRig = farm.get_node("CameraRig") as CameraRig
	rig.target = null
	rig.global_position = point
	rig.snap()


func _click_world(t: Variant, farm: Node, point: Vector3) -> void:
	_look_at(farm, point)
	await t.physics_frames(2)
	await t.click(_screen(farm, point))


func _wait_for_idle(t: Variant, farmer: Farmer) -> void:
	var steps: int = 0
	while (farmer.walking or farmer.animation.is_acting()) and steps < 4000:
		await t.physics_frames(1)
		steps += 1
	await t.physics_frames(8)


func _use_plot(t: Variant, farm: Node, farmer: Farmer, plot: SoilPlot, keycode: Key) -> void:
	await _tap(t, keycode)
	await _click_world(t, farm, plot.global_position + Vector3(0.0, 0.1, 0.0))
	await _wait_for_idle(t, farmer)


func _fill_can(t: Variant, farm: Node, farmer: Farmer) -> void:
	var pump: WaterPump = farm.find_children("*", "WaterPump", true, false)[0] as WaterPump
	await _click_world(t, farm, pump.global_position + Vector3(0.0, 0.65, 0.0))
	var steps: int = 0
	while not farmer.can.is_full() and steps < 4000:
		await t.physics_frames(1)
		steps += 1
	await _wait_for_idle(t, farmer)


func _snapshot_text() -> String:
	var systems: Dictionary = SaveSystem.snapshot()
	for key: String in systems:
		if key.begins_with("animal/"):
			(systems[key] as Dictionary).erase("position")
			(systems[key] as Dictionary).erase("yaw")
	return JSON.stringify(systems, "\t", true)


func _monitor(monitor: Performance.Monitor) -> int:
	return int(Performance.get_monitor(monitor))


func test_a_scripted_day_from_the_title_screen_to_a_saved_game(t: Variant) -> void:
	var nodes_before: int = _monitor(Performance.OBJECT_NODE_COUNT)
	var orphans_before: int = _monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var farm: Node = await _start_from_title(t)
	t.ok(Flow.farm_running(), "the New Game button started the farm")
	t.eq(GameClock.day, 1, "day 1")
	t.eq(GameClock.time_text(), "06:00", "at six in the morning")
	t.eq(Economy.money, Economy.START_MONEY, "100 coins")
	t.eq(Inventory.count_of(_item("seed_carrot")), 8, "eight carrot seeds")
	GameClock.running = false
	var farmer: Farmer = farm.get_node("Farmer") as Farmer
	var plot: SoilPlot = farm.get_node("World/Field/Plot_3_2/Soil") as SoilPlot
	t.eq(plot.state, SoilPlot.State.EMPTY, "the plot starts empty")
	await _use_plot(t, farm, farmer, plot, KEY_1)
	t.eq(plot.state, SoilPlot.State.TILLED, "the hoe tilled the soil")
	await _use_plot(t, farm, farmer, plot, KEY_2)
	t.eq(plot.state, SoilPlot.State.PLANTED, "the seeds were planted")
	t.eq(Inventory.count_of(_item("seed_carrot")), 7, "one seed was used")
	t.ok(farmer.can.is_empty(), "the can starts empty")
	await _fill_can(t, farm, farmer)
	t.ok(farmer.can.is_full(), "the pump filled the can")
	await _use_plot(t, farm, farmer, plot, KEY_3)
	t.eq(plot.state, SoilPlot.State.WATERED, "the can watered the plant")
	t.eq(farmer.can.water_level, farmer.can.capacity - 1, "one can of water was used")
	var door: SleepSpot = farm.get_node("World/Buildings/Farmhouse/Door") as SleepSpot
	var nights: int = 0
	while plot.state != SoilPlot.State.RIPE and nights < 6:
		door.interact(farmer)
		nights += 1
		await t.physics_frames(4)
		if plot.state == SoilPlot.State.PLANTED:
			await _use_plot(t, farm, farmer, plot, KEY_3)
	t.eq(plot.state, SoilPlot.State.RIPE, "the carrot is ripe")
	t.eq(nights, 3, "after three nights")
	t.eq(GameClock.day, 4, "on day 4")
	await _use_plot(t, farm, farmer, plot, KEY_4)
	t.eq(plot.state, SoilPlot.State.TILLED, "the harvest leaves tilled soil")
	var carrot: ItemData = _item("carrot")
	t.eq(Inventory.count_of(carrot), 1, "one carrot is in the bag")
	var money_before: int = Economy.money
	Events.shop_requested.emit()
	await t.frames(2)
	var panel: ShopPanel = farm.get_node("Hud/ShopPanel") as ShopPanel
	t.ok(panel.is_open, "the shop window is open")
	var sell: Button = _button(panel.sell_grid, "Sell 1")
	t.not_null(sell, "there is a Sell 1 button")
	panel.tabs.current_tab = 1
	await t.frames(2)
	await t.click(sell.get_global_rect().get_center())
	await t.frames(2)
	t.eq(Inventory.count_of(carrot), 0, "the carrot was sold")
	t.ok(Economy.money > money_before, "coins came in")
	panel.close()
	var build: BuildMode = farm.get_node("Build") as BuildMode
	var placed_before: int = farm.get_tree().get_nodes_in_group(&"placed").size()
	await _tap(t, KEY_B)
	t.ok(build.active, "build mode is on")
	t.eq(build.current.id, &"fence", "the fence is selected")
	var spot: Vector3 = Vector3(2.5, 0.0, 14.5)
	_look_at(farm, spot)
	await t.physics_frames(2)
	var coins: int = Economy.money
	t.mouse_move(_screen(farm, spot))
	await t.frames(3)
	await t.click(_screen(farm, spot))
	await t.frames(3)
	t.eq(farm.get_tree().get_nodes_in_group(&"placed").size(), placed_before + 1, "a fence section stands")
	t.eq(Economy.money, coins - 6, "it cost 6 coins")
	await _tap(t, KEY_B)
	t.ok(not build.active, "build mode is off")
	var before: String = _snapshot_text()
	await _tap(t, KEY_F5)
	t.ok(SaveSystem.has_save(1), "F5 wrote slot 1")
	var money_saved: int = Economy.money
	Economy.add_money(500, "test")
	farmer.global_position += Vector3(3.0, 0.0, 0.0)
	plot.from_save({"state": 0, "crop": "", "stage": 0, "days_watered": 0})
	t.ok(_snapshot_text() != before, "the game changed after the save")
	await _tap(t, KEY_F9)
	t.eq(_snapshot_text(), before, "F9 brought every system back exactly")
	t.eq(Economy.money, money_saved, "the coins are back")
	farm.queue_free()
	Engine.get_main_loop().current_scene = null
	await t.frames(4)
	var nodes_after: int = _monitor(Performance.OBJECT_NODE_COUNT)
	var orphans_after: int = _monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	t.ok(orphans_after <= orphans_before, "no orphan node was left (%d before, %d after)" % [orphans_before, orphans_after])
	t.ok(nodes_after <= nodes_before + 2, "the node count is back (%d before, %d after)" % [nodes_before, nodes_after])


func _button(parent: Node, text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and (child as Button).text == text:
			return child as Button
	return null


func test_the_error_catcher_sees_an_error_and_a_warning(t: Variant) -> void:
	push_warning("ch35 probe warning")
	push_error("ch35 probe error")
	await t.frames(1)
	t.eq(_catcher.warnings.size(), 1, "one warning was caught")
	t.eq(_catcher.errors.size(), 1, "one error was caught")
	t.ok(_catcher.errors[0].contains("ch35 probe error"), "with its text")
	_catcher.clear()


const MONKEY_KEYS: Array[Key] = [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_B, KEY_R, KEY_X, KEY_I, KEY_Q, KEY_E,
	KEY_ESCAPE, KEY_F5, KEY_F9, KEY_F10, KEY_TAB, KEY_SPACE, KEY_ENTER,
]


func _monkey_args() -> Dictionary:
	var seed_value: int = MONKEY_SEED
	var count: int = MONKEY_EVENTS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--monkey-seed="):
			seed_value = int(argument.substr(14))
		elif argument.begins_with("--monkey-events="):
			count = int(argument.substr(16))
	return {"seed": seed_value, "events": count}


func _disarm_quit_buttons() -> void:
	for node: Node in Engine.get_main_loop().root.find_children("*Quit*", "Button", true, false):
		(node as Button).disabled = true


func _visible_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in Engine.get_main_loop().root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.is_visible_in_tree() and not button.disabled and not button.name.contains("Quit"):
			found.append(button)
	return found


func test_a_monkey_pressing_everything_at_random_breaks_nothing(t: Variant) -> void:
	var setup: Dictionary = _monkey_args()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = setup["seed"]
	var farm: Node = await _start_from_title(t)
	GameClock.running = true
	var size: Vector2 = t.screen_size()
	var trail: Array[String] = []
	var seen: Dictionary = {}
	for name: String in ["day_started", "crop_harvested", "build_placed", "build_removed", "item_bought", "item_sold", "game_saved", "game_loaded", "interaction_finished", "build_mode_changed", "shop_opened", "tool_changed", "hint_shown"]:
		var counter: Callable = func(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void: seen[name] = seen.get(name, 0) + 1
		(Events.get(name) as Signal).connect(counter)
	var reported: int = 0
	for step: int in setup["events"]:
		_disarm_quit_buttons()
		var roll: int = rng.randi_range(0, 99)
		var event: String
		var spots: Array[Node] = []
		if Flow.farm_running():
			spots = Engine.get_main_loop().current_scene.find_children("*", "Interactable", true, false)
		if roll < 25:
			var point: Vector2 = Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y))
			var button: MouseButton = MOUSE_BUTTON_LEFT if rng.randf() < 0.85 else MOUSE_BUTTON_RIGHT
			event = "click %s %d" % [point.round(), button]
			await t.click(point, button)
		elif roll < 45 and not spots.is_empty():
			var spot: Interactable = spots[rng.randi_range(0, spots.size() - 1)] as Interactable
			event = "interactable %s" % spot.get_parent().name
			var farmer: Farmer = Engine.get_main_loop().current_scene.get_node_or_null("Farmer") as Farmer
			if farmer != null and rng.randf() < 0.7:
				var wanted: StringName = &"hand"
				if spot is SoilPlot and SoilPlot.TOOL_FOR[(spot as SoilPlot).state] != &"":
					wanted = SoilPlot.TOOL_FOR[(spot as SoilPlot).state]
				if not (farmer.get_node("../Build") as BuildMode).active:
					farmer.tools.select(wanted)
			_look_at(Engine.get_main_loop().current_scene, spot.global_position)
			await t.physics_frames(2)
			await t.click(_screen(Engine.get_main_loop().current_scene, spot.global_position + Vector3(0.0, 0.2, 0.0)))
			await t.physics_frames(rng.randi_range(0, 120))
		elif roll < 62:
			var keycode: Key = MONKEY_KEYS[rng.randi_range(0, MONKEY_KEYS.size() - 1)]
			event = "key %s" % OS.get_keycode_string(keycode)
			await _tap(t, keycode)
		elif roll < 68:
			var wheel: MouseButton = MOUSE_BUTTON_WHEEL_UP if rng.randf() < 0.5 else MOUSE_BUTTON_WHEEL_DOWN
			event = "wheel %d" % wheel
			var point: Vector2 = Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y))
			t.mouse_move(point)
			t.mouse_button(point, wheel, true)
			await t.frames(1)
			t.mouse_button(point, wheel, false)
		elif roll < 74:
			var point: Vector2 = Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y))
			event = "move %s" % point.round()
			t.mouse_move(point)
		elif roll < 82:
			var minutes: int = rng.randi_range(30, 900)
			event = "clock +%d" % minutes
			GameClock.advance_minutes(minutes)
		elif roll < 93:
			var buttons: Array[Button] = _visible_buttons()
			if buttons.is_empty():
				event = "no button"
			else:
				var chosen: Button = buttons[rng.randi_range(0, buttons.size() - 1)]
				event = "button %s '%s'" % [chosen.name, chosen.text]
				await t.click(chosen.get_global_rect().get_center())
		elif roll < 96:
			event = "shop"
			Events.shop_requested.emit()
		else:
			event = "run %s" % (not Input.is_action_pressed("move_run"))
			if Input.is_action_pressed("move_run"):
				Input.action_release("move_run")
			else:
				Input.action_press("move_run")
		trail.append("%d %s" % [step, event])
		if trail.size() > 12:
			trail.pop_front()
		await t.frames(rng.randi_range(1, 4))
		if _catcher.errors.size() + _catcher.warnings.size() > reported:
			reported = _catcher.errors.size() + _catcher.warnings.size()
			print("LM_MONKEY first problem after: ", " | ".join(trail))
			break
	Input.action_release("move_run")
	print("LM_MONKEY seed %d, %d events, day %d, %d coins, scene %s, signals %s" % [setup["seed"], setup["events"], GameClock.day, Economy.money, Engine.get_main_loop().current_scene.name if Engine.get_main_loop().current_scene != null else "none", seen])
	t.eq(_catcher.errors, [] as Array[String], "the monkey caused no error (seed %d)" % setup["seed"])
	t.eq(_catcher.warnings, [] as Array[String], "the monkey caused no warning (seed %d)" % setup["seed"])
	_catcher.clear()
	if reported == 0:
		t.ok(Flow.farm_running() or Engine.get_main_loop().current_scene != null, "a scene is still running")


func test_the_script_cost_of_a_frame_is_measured_and_reported(t: Variant) -> void:
	var farm: Node = await _start_from_title(t)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 0
	GameClock.running = true
	await t.frames(30)
	var orphans_before: int = _monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var frame_ms: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for frame: int in 240:
		await t.frames(1)
		var now: int = Time.get_ticks_usec()
		frame_ms.append((now - last) / 1000.0)
		last = now
	frame_ms.sort()
	var total: float = 0.0
	for value: float in frame_ms:
		total += value
	var mean: float = total / frame_ms.size()
	print("LM_FRAMETIME mean %.3f ms, median %.3f ms, worst %.3f ms over %d frames, %d nodes (informational: headless, nothing is drawn, this machine only)" % [mean, frame_ms[frame_ms.size() / 2], frame_ms[-1], frame_ms.size(), _monitor(Performance.OBJECT_NODE_COUNT)])
	t.ok(is_finite(mean) and mean > 0.0, "the frame time is a real number")
	t.ok(farm.is_inside_tree(), "the farm kept running while it was measured")
	t.ok(_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) <= orphans_before, "no new orphan node in 240 frames")
