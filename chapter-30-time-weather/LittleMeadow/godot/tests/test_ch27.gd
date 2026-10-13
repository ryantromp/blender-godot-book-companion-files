extends Node
## Chapter 27: items and crops as resources, the soil plot, growth over days, the tool belt and the harvest.
## The clock runs like in Chapter 25: 480 physics steps a second and Engine.time_scale 8, so every step is 1/60 s of game time.
## Chapter 29 note: the FarmNotes tally is gone. The last test now reads the HUD and the Inventory instead,
## and before_each gives the bag its starting items, because planting uses up seeds.

const FARM: String = "res://scenes/world/farm.tscn"
const PROBE := Vector3(0.5, 0.0, 12.0)
const STEP: float = 1.0 / 60.0
const TICKS: int = 480
const SPEEDUP: float = 8.0
const CROPS: PackedStringArray = ["carrot", "wheat", "pumpkin"]

var _log: Array[String] = []


func before_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = TICKS
	Engine.time_scale = SPEEDUP
	GameClock.running = false
	GameClock.day = 1
	GameClock.minute_of_day = 360
	_log.clear()
	Inventory.clear()
	Inventory.give_starting_items()
	if not Events.crop_harvested.is_connected(_on_harvested):
		Events.crop_harvested.connect(_on_harvested)
		Events.hint_shown.connect(_on_hint)
		Events.day_started.connect(_on_day)
		Events.tool_changed.connect(_on_tool)
		Events.water_level_changed.connect(_on_water)


func after_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	Input.action_release("move_run")


func _on_harvested(crop: CropData, plot: SoilPlot) -> void:
	_log.append("harvest:%s:%s" % [crop.id, plot.get_parent().name])


func _on_hint(text: String) -> void:
	_log.append("hint:" + text)


func _on_day(day: int) -> void:
	_log.append("day:%d" % day)


func _on_tool(tool_name: StringName, _crop: CropData) -> void:
	_log.append("tool:" + String(tool_name))


func _on_water(level: int, _capacity: int) -> void:
	_log.append("water:%d" % level)


func _count(prefix: String) -> int:
	var n: int = 0
	for line: String in _log:
		if line.begins_with(prefix):
			n += 1
	return n


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


func _plot(farm: Node, column: int, row: int) -> SoilPlot:
	return farm.get_node("World/Field/Plot_%d_%d/Soil" % [column, row]) as SoilPlot


func _crop(crop_name: String) -> CropData:
	return load("res://resources/crops/%s.tres" % crop_name) as CropData


## What the InteractionController does on arrival: ask, play the clip, interact. Returns whether the plot agreed.
func _use(farmer: Farmer, plot: SoilPlot, tool_name: StringName) -> bool:
	farmer.tools.select(tool_name)
	if not plot.can_interact(farmer):
		return false
	if plot.action_name != "":
		farmer.animation.play_action(StringName(plot.action_name))
	await plot.interact(farmer)
	return true


func _sleep(farm: Node, farmer: Farmer) -> void:
	(farm.get_node("World/Buildings/Farmhouse/Door") as SleepSpot).interact(farmer)


## The name of the model shown on a plot, or "" when it shows none.
func _shown(plot: SoilPlot) -> String:
	var anchor: Node = plot.get_parent().get_node("Crop")
	if anchor.get_child_count() == 0:
		return ""
	return String(anchor.get_child(0).get_child(0).name)


func _look(plot: SoilPlot) -> PlotLook:
	return plot.get_parent() as PlotLook


func _screen(farm: Node, point: Vector3) -> Vector2:
	return (farm.get_node("CameraRig") as CameraRig).camera.unproject_position(point)


func _look_at(farm: Node, point: Vector3) -> void:
	var rig := farm.get_node("CameraRig") as CameraRig
	rig.target = null
	rig.global_position = point
	rig.snap()


func test_items_and_crops_load_with_the_right_fields(t: Variant) -> void:
	var days: Dictionary = {"carrot": 1, "wheat": 1, "pumpkin": 2}
	for crop_name: String in CROPS:
		var crop: CropData = _crop(crop_name)
		t.not_null(crop, "%s.tres loads as a CropData" % crop_name)
		t.eq(crop.id, StringName(crop_name), "%s id" % crop_name)
		t.eq(crop.display_name, crop_name.capitalize(), "%s name" % crop_name)
		t.eq(crop.days_per_stage, days[crop_name], "%s days per stage" % crop_name)
		t.eq(crop.stage_scenes.size(), 4, "%s has four stage models" % crop_name)
		t.eq(crop.last_stage(), 3, "%s ripe stage" % crop_name)
		t.eq(crop.days_to_grow(), 3 * days[crop_name], "%s days to grow" % crop_name)
		t.ok(crop.sell_price > 0, "%s has a placeholder price" % crop_name)
		for stage: int in 4:
			t.eq(crop.stage_scenes[stage].resource_path, "res://assets/models/crop_%s_s%d.glb" % [crop_name, stage], "%s stage %d model" % [crop_name, stage])
		t.eq(crop.seed_item.id, StringName("seed_" + crop_name), "%s seed item" % crop_name)
		t.eq(crop.harvest_item.id, StringName(crop_name), "%s harvest item" % crop_name)
		for item: ItemData in [crop.seed_item, crop.harvest_item]:
			t.ok(item.display_name != "" and item.stack_size == 99, "%s has a name and a stack size" % item.id)
			t.eq(item.resource_path.get_base_dir(), "res://resources/items", "%s lives in resources/items" % item.id)
	t.eq(_crop("pumpkin").harvest_item.display_name, "Pumpkin", "item display name")
	t.eq(_crop("carrot").seed_item.display_name, "Carrot seeds", "seed display name")
	var plain := ItemData.new()
	t.eq(plain.stack_size, 99, "default stack size")
	t.eq(CropData.new().days_per_stage, 1, "default days per stage")


func test_every_plot_of_the_field_is_a_soil_plot(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var field: Node = farm.get_node("World/Field")
	t.eq(field.get_child_count(), 40, "the field still has 40 plots")
	t.eq(get_tree().get_nodes_in_group(&"soil_plots").size(), 40, "40 nodes in the group soil_plots")
	var names: Dictionary = {}
	for plot_root: Node in field.get_children():
		names[plot_root.name] = true
		var soil := plot_root.get_node_or_null("Soil") as SoilPlot
		t.not_null(soil, "%s has a SoilPlot" % plot_root.name)
		if soil == null:
			continue
		t.ok(soil is Interactable, "%s is an Interactable" % plot_root.name)
		t.eq(soil.collision_layer, 2, "%s layer" % plot_root.name)
		t.eq(soil.collision_mask, 0, "%s mask" % plot_root.name)
		t.eq(soil.state, SoilPlot.State.EMPTY, "%s starts empty" % plot_root.name)
		t.ok(soil.is_in_group(&"soil_plots"), "%s is in the group" % plot_root.name)
		t.ok(plot_root is PlotLook and (plot_root as PlotLook).soil == soil, "%s root draws that plot" % plot_root.name)
		t.ok(not plot_root.get_node("Tilled").visible and not plot_root.get_node("Wet").visible, "%s shows bare ground" % plot_root.name)
	t.eq(names.size(), 40, "40 different names")
	t.ok(names.has(&"Plot_0_0") and names.has(&"Plot_7_4"), "the corner plots keep their names")
	farm.queue_free()


func test_a_full_cycle_on_one_plot_over_three_nights(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var plot: SoilPlot = _plot(farm, 3, 2)
	var heard: Array[int] = [0]
	plot.interacted.connect(func(_f: Farmer) -> void: heard[0] += 1)
	farmer.can.refill()
	_log.clear()
	t.eq(plot.prompt_text, "Till the soil", "prompt of bare ground")
	t.ok(await _use(farmer, plot, &"hoe"), "the hoe tills")
	t.eq(plot.state, SoilPlot.State.TILLED, "tilled")
	t.ok(_look(plot).tilled.visible and not _look(plot).wet.visible, "dark patch, not wet")
	t.eq(plot.prompt_text, "Plant a seed", "prompt of tilled soil")
	farmer.tools.crop = _crop("carrot")
	t.ok(await _use(farmer, plot, &"seeds"), "the seeds plant")
	t.eq(plot.state, SoilPlot.State.PLANTED, "planted")
	t.eq(plot.crop.id, &"carrot", "a carrot")
	t.eq(plot.stage, 0, "stage 0")
	t.eq(_shown(plot), "crop_carrot_s0", "the seed mound shows")
	t.eq(plot.prompt_text, "Water the carrot", "prompt of a dry crop")
	t.eq(_count("day:"), 0, "no night yet")
	var shown: Array[String] = []
	for night: int in 3:
		t.ok(await _use(farmer, plot, &"can"), "night %d: the can waters" % (night + 1))
		t.eq(plot.state, SoilPlot.State.WATERED, "watered")
		t.ok(_look(plot).wet.visible, "the wet patch shows")
		t.eq(farmer.can.water_level, 4 - night, "one watering used, %d left" % (4 - night))
		t.eq(plot.stage, night, "still stage %d before the night" % night)
		_sleep(farm, farmer)
		t.eq(plot.stage, night + 1, "stage %d after the night" % (night + 1))
		t.ok(not _look(plot).wet.visible, "dry again in the morning")
		shown.append(_shown(plot))
	t.eq(shown, ["crop_carrot_s1", "crop_carrot_s2", "crop_carrot_s3"] as Array[String], "the model follows the stage")
	t.eq(plot.state, SoilPlot.State.RIPE, "ripe after three nights")
	t.eq(GameClock.day, 4, "three days passed")
	t.eq(_count("day:"), 3, "day_started fired once per night")
	t.eq(plot.prompt_text, "Harvest the carrot", "prompt of a ripe crop")
	t.eq(_count("harvest:"), 0, "nothing harvested yet")
	t.ok(await _use(farmer, plot, &"hand"), "bare hands harvest")
	t.eq(plot.state, SoilPlot.State.TILLED, "back to tilled soil")
	t.eq(plot.crop, null, "the crop is gone")
	t.eq(_shown(plot), "", "and no model")
	t.ok(_look(plot).tilled.visible, "still a dark patch")
	t.eq(_log.filter(func(l: String) -> bool: return l.begins_with("harvest")), ["harvest:carrot:Plot_3_2"], "crop_harvested fired once, with the crop and the plot")
	t.eq(heard[0], 6, "interacted fired once per use")
	farm.queue_free()


func test_an_unwatered_crop_does_not_grow(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var plot: SoilPlot = _plot(farm, 0, 0)
	farmer.can.refill()
	await _use(farmer, plot, &"hoe")
	farmer.tools.crop = _crop("carrot")
	await _use(farmer, plot, &"seeds")
	for night: int in 3:
		_sleep(farm, farmer)
	t.eq(GameClock.day, 4, "three nights passed")
	t.eq(plot.stage, 0, "no water, no growth: still stage 0")
	t.eq(plot.state, SoilPlot.State.PLANTED, "still waiting for water")
	t.eq(_shown(plot), "crop_carrot_s0", "still the seed mound")
	t.eq(farmer.can.water_level, 5, "the can was not used")
	await _use(farmer, plot, &"can")
	_sleep(farm, farmer)
	t.eq(plot.stage, 1, "one watering, one stage")
	_sleep(farm, farmer)
	t.eq(plot.stage, 1, "and the next dry night changes nothing")
	farm.queue_free()


func test_an_empty_can_refuses_and_a_full_one_is_used(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var plot: SoilPlot = _plot(farm, 1, 1)
	await _use(farmer, plot, &"hoe")
	farmer.tools.crop = _crop("wheat")
	await _use(farmer, plot, &"seeds")
	t.eq(farmer.can.water_level, 0, "the can is empty")
	_log.clear()
	farmer.tools.select(&"can")
	_log.clear()
	t.ok(not plot.can_interact(farmer), "an empty can refuses")
	t.eq(_log, ["hint:The can is empty. Fill it at the pump."] as Array[String], "with one message and nothing else")
	t.eq(plot.state, SoilPlot.State.PLANTED, "the plot did not change")
	t.eq(farmer.can.water_level, 0, "the can did not change")
	farmer.can.refill()
	_log.clear()
	t.ok(await _use(farmer, plot, &"can"), "a filled can works")
	t.eq(farmer.can.water_level, 4, "use() took one watering")
	t.eq(_count("water:4"), 1, "water_level_changed fired once")
	t.eq(_count("hint:"), 0, "and no hint")
	t.eq(plot.state, SoilPlot.State.WATERED, "watered")
	farm.queue_free()


func test_the_wrong_tool_refuses_with_a_message(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var plot: SoilPlot = _plot(farm, 5, 3)
	farmer.can.refill()
	farmer.tools.crop = _crop("carrot")
	var checks: int = 0
	for state: int in 5:
		t.eq(plot.state, state, "the plot is in state %d" % state)
		for tool_name: StringName in ToolBelt.TOOLS:
			if tool_name == SoilPlot.TOOL_FOR[state]:
				continue
			farmer.tools.select(tool_name)
			_log.clear()
			var before: int = farmer.can.water_level
			t.ok(not plot.can_interact(farmer), "state %d refuses the %s" % [state, tool_name])
			t.eq(_log, ["hint:" + SoilPlot.HINT_FOR[state]] as Array[String], "one message for the %s in state %d" % [tool_name, state])
			t.eq(plot.state, state, "the plot stays in state %d" % state)
			t.eq(farmer.can.water_level, before, "no water was used")
			checks += 1
		match state:
			SoilPlot.State.EMPTY, SoilPlot.State.TILLED, SoilPlot.State.PLANTED:
				t.ok(await _use(farmer, plot, SoilPlot.TOOL_FOR[state]), "the right tool works in state %d" % state)
			SoilPlot.State.WATERED:
				_sleep(farm, farmer)
				for night: int in 2:
					await _use(farmer, plot, &"can")
					_sleep(farm, farmer)
	t.eq(checks, 3 + 3 + 3 + 4 + 3, "16 wrong pairs were tried")
	t.eq(plot.state, SoilPlot.State.RIPE, "the walk through the states ends ripe")
	t.eq(SoilPlot.HINT_FOR.size(), 5, "one hint per state")
	farm.queue_free()


func test_slow_crops_need_more_watered_days(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var plot: SoilPlot = _plot(farm, 7, 4)
	farmer.can.capacity = 20
	farmer.can.refill()
	await _use(farmer, plot, &"hoe")
	farmer.tools.crop = _crop("pumpkin")
	await _use(farmer, plot, &"seeds")
	t.eq(plot.crop.days_to_grow(), 6, "a pumpkin takes six watered days")
	var stages: Array[int] = []
	for night: int in 6:
		await _use(farmer, plot, &"can")
		_sleep(farm, farmer)
		stages.append(plot.stage)
	t.eq(stages, [0, 1, 1, 2, 2, 3] as Array[int], "a stage every second night")
	t.eq(plot.state, SoilPlot.State.RIPE, "ripe after six nights")
	t.eq(_shown(plot), "crop_pumpkin_s3", "the big pumpkin shows")
	farm.queue_free()


func test_sleeping_moves_the_clock_to_the_next_morning(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var door := farm.get_node("World/Buildings/Farmhouse/Door") as SleepSpot
	t.ok(door is Interactable, "the door is an Interactable")
	t.eq(door.collision_layer, 2, "layer 2")
	t.eq(door.prompt_text, "Sleep until morning", "prompt")
	t.eq(door.get_parent().name, &"Farmhouse", "on the farmhouse")
	t.eq(door.position, Vector3(0.0, 0.0, 2.6), "the area stands in front of the house, so the reach is measured from the door")
	t.eq(door.get_node("CollisionShape3D").position, Vector3(0.0, 1.1, 0.0), "the box is lifted to the height of a door")
	_sleep(farm, farmer)
	t.eq(GameClock.day, 2, "day 2")
	t.eq(GameClock.time_text(), "06:00", "wake up at 06:00")
	t.eq(_count("day:2"), 1, "day_started(2) once")
	t.eq(_count("hint:Good morning. It is day 2."), 1, "a greeting")
	GameClock.minute_of_day = 23 * 60
	_log.clear()
	_sleep(farm, farmer)
	t.eq(GameClock.day, 3, "from 23:00 the night crosses midnight once")
	t.eq(GameClock.time_text(), "06:00", "and ends at 06:00")
	t.eq(_count("day:"), 1, "one new day")
	GameClock.minute_of_day = 2 * 60
	_log.clear()
	_sleep(farm, farmer)
	t.eq(GameClock.day, 3, "from 02:00 midnight has passed already, so no new day")
	t.eq(GameClock.time_text(), "06:00", "still 06:00")
	t.eq(_count("day:"), 0, "no day_started")
	farm.queue_free()


func test_a_click_on_the_door_walks_there_and_sleeps(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var door := farm.get_node("World/Buildings/Farmhouse/Door") as SleepSpot
	_look_at(farm, Vector3(-8.5, 0.0, -9.0))
	farmer.global_position = Vector3(-8.5, 0.0, -4.0)
	await t.physics_frames(2)
	_log.clear()
	await t.click(_screen(farm, door.global_position + Vector3(0.0, 1.1, 0.0)))
	t.ok(farmer.walking, "the farmer walks to the door")
	var steps: int = 0
	while GameClock.day == 1 and steps < 3000:
		await t.physics_frames(1)
		steps += 1
	t.eq(GameClock.day, 2, "the door was used on arrival")
	t.eq(GameClock.time_text(), "06:00", "the next morning")
	t.eq(_count("hint:Good morning. It is day 2."), 1, "a greeting")
	var flat := Vector2(farmer.global_position.x - door.global_position.x, farmer.global_position.z - door.global_position.z)
	t.ok(flat.length() <= door.interact_range, "the farmer stands within reach of the door")
	farm.queue_free()


func test_the_tool_belt_follows_the_keys(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var belt: ToolBelt = farmer.tools
	t.eq(belt.current, &"hand", "bare hands at the start")
	t.eq(belt.crops.size(), 3, "three crops in the seed bag")
	t.eq(belt.crop.id, &"carrot", "carrot first")
	var expected: Array[StringName] = [&"hoe", &"seeds", &"can", &"hand"]
	var keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
	for index: int in 4:
		t.key(keys[index])
		await t.frames(2)
		t.key(keys[index], false)
		await t.frames(1)
		t.eq(belt.current, expected[index], "key %d" % (index + 1))
	t.eq(_count("tool:"), 4, "tool_changed fired once per key")
	for want: String in ["carrot", "wheat", "pumpkin", "carrot"]:
		await t.tap_action("tool_2")
		t.eq(belt.current, &"seeds", "2 holds the seeds")
		t.eq(belt.crop.id, StringName(want), "pressing 2 gives the %s seeds" % want)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.shift_pressed = true
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await t.frames(2)
	t.eq(belt.current, &"can", "Shift+wheel down steps to the next tool")
	belt.select(&"hoe")
	var up := wheel.duplicate() as InputEventMouseButton
	up.button_index = MOUSE_BUTTON_WHEEL_UP
	Input.parse_input_event(up)
	await t.frames(2)
	t.eq(belt.current, &"hand", "Shift+wheel up from the hoe wraps round to the hands")
	farm.queue_free()


func test_a_click_walks_to_the_plot_waits_for_the_clip_and_changes_it(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var plot: SoilPlot = _plot(farm, 4, 1)
	_look_at(farm, plot.global_position)
	farmer.global_position = Vector3(0.5, 0.0, 1.5)
	await t.physics_frames(2)
	farmer.tools.select(&"hoe")
	_log.clear()
	await t.click(_screen(farm, plot.global_position + Vector3(0.0, 0.1, 0.0)))
	t.ok(farmer.walking, "the farmer walks")
	var steps: int = 0
	while farmer.walking and steps < 3000:
		await t.physics_frames(1)
		steps += 1
	t.ok(steps > 60, "the walk took a while")
	t.ok(Vector2(farmer.global_position.x - plot.global_position.x, farmer.global_position.z - plot.global_position.z).length() <= plot.interact_range, "the farmer stands in range")
	t.eq(plot.state, SoilPlot.State.EMPTY, "the clip is playing, the soil is not tilled yet")
	t.ok(farmer.animation.is_acting(), "the farmer is acting")
	t.eq(plot.action_name, "plant", "the plot asked for the plant clip (the bending motion serves for the hoe)")
	var waited: int = 0
	while plot.state == SoilPlot.State.EMPTY and waited < 600:
		await t.physics_frames(1)
		waited += 1
	t.eq(plot.state, SoilPlot.State.TILLED, "the soil is tilled when the clip ends")
	t.ok(not farmer.animation.is_acting(), "the clip is over")
	t.eq(_count("hint:"), 0, "no hint")
	_log.clear()
	await t.click(_screen(farm, plot.global_position + Vector3(0.0, 0.1, 0.0)))
	await t.physics_frames(4)
	t.eq(_log, ["hint:Tilled. Take the seeds (2)."] as Array[String], "a click with the hoe on tilled soil explains what to do")
	farm.queue_free()


func test_the_hover_finds_the_plot_under_the_mouse(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var controller := farm.get_node("Farmer/InteractionController") as InteractionController
	_look_at(farm, Vector3(-8.0, 0.0, 6.5))
	await t.physics_frames(2)
	var hits: int = 0
	for column: int in [0, 3, 7]:
		for row: int in [0, 2, 4]:
			var plot: SoilPlot = _plot(farm, column, row)
			var found: Interactable = controller.pick(_screen(farm, plot.global_position + Vector3(0.0, 0.1, 0.0)))
			t.eq(found, plot, "the ray finds Plot_%d_%d" % [column, row])
			hits += 1
	t.eq(hits, 9, "nine plots tried")
	var plot_a: SoilPlot = _plot(farm, 2, 2)
	controller.pick(Vector2.ZERO)
	plot_a.set_hovered(true)
	t.ok(plot_a.is_hovered, "hover works on a plot")
	plot_a.set_hovered(false)
	farm.queue_free()


func test_plots_do_not_block_the_farmer_or_change_the_navigation(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var polygons: int = (farm.get_node("World") as NavigationRegion3D).navigation_mesh.get_polygon_count()
	t.eq(polygons, 511, "the baked mesh still has its 511 polygons")
	farmer.global_position = Vector3(-14.0, 0.0, 6.5)
	await t.physics_frames(2)
	farmer.walk_to(Vector3(-2.0, 0.0, 6.5))
	var steps: int = 0
	while farmer.walking and steps < 3000:
		await t.physics_frames(1)
		steps += 1
	t.ok(Vector2(farmer.global_position.x + 2.0, farmer.global_position.z - 6.5).length() < 0.5, "the farmer walked straight across the field (at %s)" % farmer.global_position)
	farm.queue_free()


func test_the_hud_and_the_bag_follow_the_day_the_tool_and_the_harvest(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var hud := farm.get_node("Hud") as Hud
	var carrot := load("res://resources/items/carrot.tres") as ItemData
	var carrot_seed := load("res://resources/items/seed_carrot.tres") as ItemData
	await t.frames(2)
	t.ok(hud.clock_label.text.contains("Day 1   06:00"), "the day and time")
	t.ok(hud.held_label.text.contains("Hands"), "bare hands")
	t.eq(Inventory.count_of(carrot), 0, "nothing harvested")
	farmer.tools.select(&"seeds")
	await t.frames(2)
	t.eq(hud.held_label.text, "Carrot seeds x8", "the seeds say which crop and how many")
	var plot: SoilPlot = _plot(farm, 6, 0)
	farmer.can.refill()
	await _use(farmer, plot, &"hoe")
	await _use(farmer, plot, &"seeds")
	t.eq(Inventory.count_of(carrot_seed), 7, "planting used one seed")
	for night: int in 3:
		await _use(farmer, plot, &"can")
		_sleep(farm, farmer)
	await t.frames(2)
	t.eq(plot.state, SoilPlot.State.RIPE, "the plot is ripe")
	t.ok(hud.clock_label.text.contains("Day 4   06:00"), "day 4")
	await _use(farmer, plot, &"hand")
	await t.frames(2)
	t.eq(Inventory.count_of(carrot), 1, "the harvest is in the bag")
	await _use(farmer, plot, &"hand")
	await t.frames(2)
	t.ok(hud.toast_label.text.contains("Dry ground") or hud.toast_label.text.contains("Tilled. Take the seeds"), "the last hint shows as a toast")
	farm.queue_free()
