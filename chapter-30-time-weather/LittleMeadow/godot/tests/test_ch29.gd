extends Node
## Chapter 29: the Inventory and Economy autoloads, the seeds and the feed that come out of the bag, and the HUD.
## The clock runs like in Chapter 25: 480 physics steps a second and Engine.time_scale 8, so every step is 1/60 s of game time.

const FARM: String = "res://scenes/world/farm.tscn"
const PROBE := Vector3(0.5, 0.0, 12.0)
const TICKS: int = 480
const SPEEDUP: float = 8.0
const ITEM_IDS: PackedStringArray = [
	"seed_carrot", "seed_wheat", "seed_pumpkin", "carrot", "wheat", "pumpkin", "hay", "grain", "dog_biscuit", "egg", "milk",
]
const CARROT: ItemData = preload("res://resources/items/carrot.tres")
const SEED_CARROT: ItemData = preload("res://resources/items/seed_carrot.tres")
const HAY: ItemData = preload("res://resources/items/hay.tres")
const GRAIN: ItemData = preload("res://resources/items/grain.tres")
const EGG: ItemData = preload("res://resources/items/egg.tres")

var _log: Array[String] = []


func before_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = TICKS
	Engine.time_scale = SPEEDUP
	GameClock.running = false
	GameClock.day = 1
	GameClock.minute_of_day = 360
	Inventory.clear()
	Inventory.give_starting_items()
	Economy.money = Economy.START_MONEY
	_log.clear()
	if not Events.item_added.is_connected(_on_added):
		Events.item_added.connect(_on_added)
		Events.item_removed.connect(_on_removed)
		Events.inventory_changed.connect(_on_changed)
		Events.money_changed.connect(_on_money)
		Events.hint_shown.connect(_on_hint)


func after_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	Input.action_release("move_run")


func _on_added(item: ItemData, amount: int) -> void:
	_log.append("added:%s:%d" % [item.id, amount])


func _on_removed(item: ItemData, amount: int) -> void:
	_log.append("removed:%s:%d" % [item.id, amount])


func _on_changed() -> void:
	_log.append("changed")


func _on_money(money: int) -> void:
	_log.append("money:%d" % money)


func _on_hint(text: String) -> void:
	_log.append("hint:" + text)


func _count(prefix: String) -> int:
	var n: int = 0
	for line: String in _log:
		if line.begins_with(prefix):
			n += 1
	return n


func _thing(item_id: String, size: int) -> ItemData:
	var item := ItemData.new()
	item.id = StringName(item_id)
	item.display_name = item_id.capitalize()
	item.stack_size = size
	return item


func _farm(t: Variant) -> Node:
	await t.frames(2)
	var farm: Node = (load(FARM) as PackedScene).instantiate()
	t.add(farm)
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


func _animal(farm: Node, animal_name: String) -> Animal:
	return farm.get_node("Animals/" + animal_name) as Animal


func _screen(farm: Node, point: Vector3) -> Vector2:
	return (farm.get_node("CameraRig") as CameraRig).camera.unproject_position(point)


func _look_at(farm: Node, point: Vector3) -> void:
	var rig := farm.get_node("CameraRig") as CameraRig
	rig.target = null
	rig.global_position = point
	rig.snap()


## What the InteractionController does on arrival: ask, play the clip, interact. Returns whether the spot agreed.
func _use(farmer: Farmer, spot: Interactable, tool_name: StringName) -> bool:
	farmer.tools.select(tool_name)
	if not spot.can_interact(farmer):
		return false
	if spot.action_name != "":
		farmer.animation.play_action(StringName(spot.action_name))
	await spot.interact(farmer)
	return true


func _sleep(farm: Node, farmer: Farmer) -> void:
	(farm.get_node("World/Buildings/Farmhouse/Door") as SleepSpot).interact(farmer)


func _centre(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


# ---------------------------------------------------------------- the autoloads and the items

func test_the_autoloads_are_registered_in_order(t: Variant) -> void:
	var names: Array[String] = []
	for setting: Dictionary in ProjectSettings.get_property_list():
		var key: String = setting["name"]
		if key.begins_with("autoload/"):
			names.append(key.trim_prefix("autoload/"))
	names.sort_custom(func(a: String, b: String) -> bool:
		return ProjectSettings.get_order("autoload/" + a) < ProjectSettings.get_order("autoload/" + b))
	t.eq(names, ["Events", "GameClock", "Inventory", "Economy"] as Array[String], "the order of the singletons")
	t.not_null(t.autoload("Inventory"), "Inventory is in the tree")
	t.not_null(t.autoload("Economy"), "Economy is in the tree")


func test_every_item_has_a_colour_and_two_letters(t: Variant) -> void:
	var letters: Array[String] = []
	for item_id: String in ITEM_IDS:
		var item := load("res://resources/items/%s.tres" % item_id) as ItemData
		t.not_null(item, "%s.tres is an ItemData" % item_id)
		t.eq(item.short_name.length(), 2, "%s has two letters" % item_id)
		t.ok(item.color != Color("8A8F98"), "%s has its own colour" % item_id)
		t.ok(not letters.has(item.short_name), "%s has letters of its own (%s)" % [item_id, item.short_name])
		letters.append(item.short_name)


# ---------------------------------------------------------------- the inventory

func test_a_new_bag_has_24_slots_and_the_starting_items(t: Variant) -> void:
	t.eq(Inventory.slots.size(), 24, "24 slots")
	t.eq(Inventory.SLOT_COUNT, 24, "the constant says the same")
	t.eq(Inventory.count_of(SEED_CARROT), 8, "eight carrot seeds")
	t.eq(Inventory.count_of(HAY), 6, "six hay")
	t.eq(Inventory.count_of(GRAIN), 6, "six grain")
	t.eq(Inventory.count_of(CARROT), 0, "no carrot")
	t.eq(Inventory.used_slots(), 6, "six stacks")
	t.eq(Economy.money, 100, "100 coins")


func test_add_stacks_up_to_the_stack_size_and_then_opens_a_new_slot(t: Variant) -> void:
	Inventory.clear()
	var stone := _thing("stone", 10)
	t.eq(Inventory.add(stone, 4), 0, "four fit")
	t.eq(Inventory.used_slots(), 1, "in one slot")
	t.eq(Inventory.add(stone, 4), 0, "four more fit")
	t.eq(Inventory.used_slots(), 1, "still one slot (8 of 10)")
	t.eq(Inventory.add(stone, 5), 0, "five more fit")
	t.eq(Inventory.used_slots(), 2, "a second slot opened")
	t.eq(Inventory.slots[0].count, 10, "the first stack is full")
	t.eq(Inventory.slots[1].count, 3, "the rest is in the second")
	t.eq(Inventory.count_of(stone), 13, "13 in all")
	t.eq(Inventory.add(stone, 0), 0, "adding nothing does nothing")
	t.eq(Inventory.add(stone, -3), 0, "and a negative amount too")
	t.eq(Inventory.count_of(stone), 13, "still 13")


func test_a_full_bag_gives_back_what_did_not_fit(t: Variant) -> void:
	Inventory.clear()
	var stone := _thing("stone", 10)
	t.eq(Inventory.add(stone, 235), 0, "235 stones fill 23.5 slots")
	t.eq(Inventory.used_slots(), 24, "all 24 slots in use")
	t.ok(Inventory.can_add(stone, 5), "five more stones fit")
	t.ok(not Inventory.can_add(stone, 6), "six do not")
	t.ok(not Inventory.can_add(_thing("shell", 5)), "another kind has no empty slot")
	_log.clear()
	t.eq(Inventory.add(stone, 12), 7, "twelve offered, five fit, seven come back")
	t.eq(Inventory.count_of(stone), 240, "the bag holds 240")
	t.eq(_log.filter(func(l: String) -> bool: return l.begins_with("added:")), ["added:stone:5"], "the bus heard about the five")
	_log.clear()
	t.eq(Inventory.add(stone, 3), 3, "a full bag takes nothing")
	t.eq(_log.size(), 0, "and tells nobody")
	t.eq(Inventory.add(_thing("shell", 5), 1), 1, "an empty-handed slot search finds none")


func test_remove_takes_all_or_nothing(t: Variant) -> void:
	Inventory.clear()
	var stone := _thing("stone", 10)
	Inventory.add(stone, 13)
	t.ok(not Inventory.remove(stone, 14), "14 is too many")
	t.eq(Inventory.count_of(stone), 13, "nothing was taken")
	_log.clear()
	t.ok(Inventory.remove(stone, 5), "five can go")
	t.eq(Inventory.count_of(stone), 8, "eight left")
	t.eq(_log, ["removed:stone:5", "changed"] as Array[String], "the bus heard both signals, in this order")
	t.ok(Inventory.remove(stone, 8), "the rest can go")
	t.eq(Inventory.used_slots(), 0, "the emptied slots are free again")
	t.ok(not Inventory.remove(stone), "taking from nothing fails")
	t.ok(not Inventory.remove(stone, 0), "taking nothing fails too")


func test_the_signals_tell_what_changed(t: Variant) -> void:
	Inventory.clear()
	_log.clear()
	Inventory.add(CARROT, 2)
	t.eq(_log, ["added:carrot:2", "changed"] as Array[String], "add tells item_added then inventory_changed")
	_log.clear()
	Inventory.remove(CARROT, 1)
	t.eq(_log, ["removed:carrot:1", "changed"] as Array[String], "remove tells item_removed then inventory_changed")
	_log.clear()
	Inventory.remove(CARROT, 5)
	t.eq(_log.size(), 0, "a refused remove tells nobody")


func test_the_old_farm_notes_and_feed_bag_are_gone(t: Variant) -> void:
	var farmer := (load("res://scenes/actors/farmer.tscn") as PackedScene).instantiate() as Farmer
	add_child(farmer)
	for gone: String in ["FarmNotes", "FeedBag", "CanLabel"]:
		t.ok(not farmer.has_node(gone), "the farmer has no %s any more" % gone)
	farmer.free()
	t.ok(not ClassDB.class_exists(&"FeedBag"), "no native class of that name either")
	t.ok(not FileAccess.file_exists("res://scripts/actors/feed_bag.gd"), "feed_bag.gd is deleted")
	t.ok(not FileAccess.file_exists("res://scripts/actors/farm_notes.gd"), "farm_notes.gd is deleted")


# ---------------------------------------------------------------- money

func test_money_adds_and_spends_and_tells_the_bus(t: Variant) -> void:
	_log.clear()
	Economy.add_money(25)
	t.eq(Economy.money, 125, "125 after earning 25")
	t.ok(Economy.spend(100), "spending 100 works")
	t.eq(Economy.money, 25, "25 left")
	t.ok(not Economy.spend(26), "spending more than there is fails")
	t.eq(Economy.money, 25, "and changes nothing")
	t.ok(Economy.spend(25), "spending all of it works")
	t.eq(Economy.money, 0, "zero")
	Economy.add_money(0)
	Economy.add_money(-5)
	t.eq(Economy.money, 0, "adding nothing or less than nothing does nothing")
	t.ok(not Economy.spend(-5), "spending a negative amount fails")
	t.eq(_log, ["money:125", "money:25", "money:0"] as Array[String], "one signal for each change, none for the refusals")


# ---------------------------------------------------------------- the game uses the bag

func test_planting_uses_a_seed_and_the_harvest_fills_the_bag(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var plot: SoilPlot = _plot(farm, 6, 0)
	farmer.can.refill()
	t.ok(await _use(farmer, plot, &"hoe"), "the ground is broken")
	t.eq(Inventory.count_of(SEED_CARROT), 8, "tilling uses no seed")
	t.ok(await _use(farmer, plot, &"seeds"), "the seed goes in")
	t.eq(Inventory.count_of(SEED_CARROT), 7, "one carrot seed less")
	for night: int in 3:
		await _use(farmer, plot, &"can")
		_sleep(farm, farmer)
	t.eq(plot.state, SoilPlot.State.RIPE, "ripe after three nights")
	_log.clear()
	t.ok(await _use(farmer, plot, &"hand"), "harvested")
	t.eq(Inventory.count_of(CARROT), 1, "one carrot in the bag")
	t.eq(_log.filter(func(l: String) -> bool: return l.begins_with("added:")), ["added:carrot:1"], "item_added fired once")
	farm.queue_free()


func test_planting_is_refused_when_the_seeds_are_gone(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var plot: SoilPlot = _plot(farm, 7, 0)
	t.ok(await _use(farmer, plot, &"hoe"), "the ground is broken")
	Inventory.remove(SEED_CARROT, Inventory.count_of(SEED_CARROT))
	_log.clear()
	t.ok(not await _use(farmer, plot, &"seeds"), "no seed, no planting")
	t.eq(plot.state, SoilPlot.State.TILLED, "the plot stays tilled")
	t.eq(_log, ["hint:You have no carrot seeds."] as Array[String], "and the hint says why")
	farm.queue_free()


func test_a_full_bag_stops_the_harvest_and_keeps_the_crop(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var plot: SoilPlot = _plot(farm, 5, 0)
	farmer.can.refill()
	await _use(farmer, plot, &"hoe")
	await _use(farmer, plot, &"seeds")
	for night: int in 3:
		await _use(farmer, plot, &"can")
		_sleep(farm, farmer)
	Inventory.clear()
	for index: int in Inventory.SLOT_COUNT:
		Inventory.add(_thing("filler_%d" % index, 1), 1)
	_log.clear()
	t.ok(not await _use(farmer, plot, &"hand"), "a full bag refuses the harvest")
	t.eq(plot.state, SoilPlot.State.RIPE, "the carrots keep growing in the ground")
	t.eq(_log, ["hint:Your bag is full."] as Array[String], "and the hint says why")
	farm.queue_free()


func test_feeding_uses_the_right_feed_from_the_bag(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var hen := _animal(farm, "Chicken_1")
	var cow := _animal(farm, "Cow_1")
	var dog := _animal(farm, "Dog_1")
	t.ok(await _use(farmer, hen.spot, &"hand"), "the hen is fed")
	t.eq(Inventory.count_of(GRAIN), 5, "one grain used")
	t.eq(Inventory.count_of(HAY), 6, "no hay used for a hen")
	t.ok(await _use(farmer, cow.spot, &"hand"), "the cow is fed")
	t.eq(Inventory.count_of(HAY), 5, "one hay used")
	t.ok(await _use(farmer, dog.spot, &"hand"), "the dog is fed")
	t.eq(Inventory.count_of(load("res://resources/items/dog_biscuit.tres") as ItemData), 3, "one biscuit used")
	farm.queue_free()


func test_feeding_is_refused_without_feed_and_the_eggs_come_into_the_bag(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var hen := _animal(farm, "Chicken_2")
	Inventory.remove(GRAIN, Inventory.count_of(GRAIN))
	_log.clear()
	t.ok(not await _use(farmer, hen.spot, &"hand"), "no grain, no feeding")
	t.eq(_log, ["hint:You have no grain."] as Array[String], "the hint says why")
	Inventory.add(GRAIN, 2)
	t.ok(await _use(farmer, hen.spot, &"hand"), "with grain the hen is fed")
	GameClock.advance_minutes(1440)
	await t.physics_frames(2)
	var egg: Node = farm.get_tree().get_nodes_in_group(&"pickups")[0]
	t.eq(Inventory.count_of(EGG), 0, "the egg lies on the ground")
	_log.clear()
	t.ok(await _use(farmer, egg.get_node("Spot") as Interactable, &"hand"), "the egg is collected")
	await t.frames(2)
	t.eq(Inventory.count_of(EGG), 1, "and now it is in the bag")
	t.eq(_log.filter(func(l: String) -> bool: return l.begins_with("added:")), ["added:egg:1"], "item_added fired once")
	farm.queue_free()


# ---------------------------------------------------------------- the HUD

func test_the_hud_scene_has_the_node_paths_the_book_names(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var hud := farm.get_node("Hud") as Hud
	t.not_null(hud, "the farm has a Hud (a CanvasLayer)")
	t.ok(hud is CanvasLayer, "it is a CanvasLayer")
	t.eq(hud.farmer, farm.get_node("Farmer"), "its farmer export points at the Farmer")
	for path: String in [
		"Root", "Root/TopBar/TopMargin/TopRow/ClockLabel", "Root/TopBar/TopMargin/TopRow/MoneyLabel",
		"Root/ToolBar/BarRow/ToolRow/Hoe", "Root/ToolBar/BarRow/ToolRow/Seeds", "Root/ToolBar/BarRow/ToolRow/Can",
		"Root/ToolBar/BarRow/ToolRow/Hand", "Root/ToolBar/BarRow/Info/HeldLabel", "Root/ToolBar/BarRow/Info/WaterLabel",
		"Root/ToolBar/BarRow/BagButton", "Root/BagPanel/BagColumn/TitleRow/BagCount", "Root/BagPanel/BagColumn/Grid",
		"Root/Toast/ToastLabel",
	]:
		t.ok(hud.has_node(path), "Hud/%s exists" % path)
	t.eq(hud.grid.get_child_count(), 24, "the grid has 24 slots")
	t.eq(hud.grid.columns, 6, "six columns")
	t.eq(hud.get_node("Root").theme.resource_path, "res://resources/ui/hud_theme.tres", "the theme comes from one file")
	farm.queue_free()


func test_the_hud_shows_the_clock_the_money_the_water_and_the_tool(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var hud := farm.get_node("Hud") as Hud
	await t.frames(2)
	t.eq(hud.clock_label.text, "Day 1   06:00", "the day and the time")
	t.eq(hud.money_label.text, "100 coins", "the money")
	t.eq(hud.water_label.text, "Water 0 / 5", "the empty can")
	t.eq(hud.held_label.text, "Hands: harvest and feed", "bare hands")
	GameClock.advance_minutes(1440 + 75)
	await t.frames(2)
	t.eq(hud.clock_label.text, "Day 2   07:15", "the clock follows GameClock")
	Economy.add_money(50)
	t.eq(hud.money_label.text, "150 coins", "the money follows the bus")
	farmer.can.refill()
	t.eq(hud.water_label.text, "Water 5 / 5", "the water follows the bus")
	farmer.tools.select(&"seeds")
	t.eq(hud.held_label.text, "Carrot seeds x8", "the seeds say which crop and how many")
	farmer.tools.select(&"seeds")
	t.eq(hud.held_label.text, "Wheat seeds x6", "pressing 2 again picks the next crop")
	Inventory.remove(load("res://resources/items/seed_wheat.tres") as ItemData, 2)
	t.eq(hud.held_label.text, "Wheat seeds x4", "the count follows the bag")
	farmer.tools.select(&"can")
	t.eq(hud.held_label.text, "Can: water a planted seed", "the can")
	farm.queue_free()


func test_exactly_one_tool_button_is_lit_and_keys_1_to_4_still_work(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var hud := farm.get_node("Hud") as Hud
	var farmer := farm.get_node("Farmer") as Farmer
	var names: Array[String] = ["Hoe", "Seeds", "Can", "Hand"]
	t.eq(hud.tool_row.get_child_count(), 4, "four tool buttons")
	var keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
	for index: int in 4:
		t.key(keys[index], true)
		await t.frames(2)
		t.key(keys[index], false)
		await t.frames(1)
		t.eq(String(farmer.tools.current), names[index].to_lower(), "key %d picks %s" % [index + 1, names[index]])
		var lit: Array[String] = []
		for button: Button in hud.tool_row.get_children():
			if button.button_pressed:
				lit.append(button.name)
		t.eq(lit, [names[index]] as Array[String], "only %s is lit" % names[index])
	farm.queue_free()


func test_clicking_a_tool_button_selects_that_tool(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var hud := farm.get_node("Hud") as Hud
	var farmer := farm.get_node("Farmer") as Farmer
	await t.frames(3)
	var can_button := hud.get_node("Root/ToolBar/BarRow/ToolRow/Can") as Button
	await t.click(_centre(can_button))
	t.eq(farmer.tools.current, &"can", "the can is in hand after the click")
	t.ok(can_button.button_pressed, "and its button is lit")
	var hoe_button := hud.get_node("Root/ToolBar/BarRow/ToolRow/Hoe") as Button
	await t.click(_centre(hoe_button))
	t.eq(farmer.tools.current, &"hoe", "the hoe after a second click")
	t.ok(hoe_button.button_pressed and not can_button.button_pressed, "the highlight moved")
	await t.click(_centre(hoe_button))
	t.eq(farmer.tools.current, &"hoe", "clicking the lit button keeps the tool")
	t.ok(hoe_button.button_pressed, "and keeps it lit")
	t.ok(not farmer.walking, "none of the clicks sent the farmer walking")
	farm.queue_free()


func test_a_click_on_the_world_passes_through_the_hud_but_a_bar_blocks_it(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var hud := farm.get_node("Hud") as Hud
	var farmer := farm.get_node("Farmer") as Farmer
	var root := hud.get_node("Root") as Control
	t.eq(root.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the full-screen Root ignores the mouse")
	t.eq(hud.toast.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the toast ignores the mouse")
	t.eq((hud.get_node("Root/ToolBar") as Control).mouse_filter, Control.MOUSE_FILTER_STOP, "the tool bar stops it")
	farmer.global_position = Vector3(-14.0, 0.0, 6.5)
	await t.physics_frames(2)
	var ground := Vector3(-8.0, 0.0, 6.5)
	_look_at(farm, ground)
	await t.physics_frames(2)
	var bar := hud.get_node("Root/ToolBar") as Control
	await t.click(bar.get_global_rect().get_center() + Vector2(300.0, 0.0))
	t.ok(not farmer.walking, "a click on the tool bar does not send the farmer anywhere")
	await t.click(_screen(farm, ground))
	t.ok(farmer.walking, "a click on open ground reaches the world through the HUD")
	farm.queue_free()


func test_the_bag_opens_and_closes_with_i_and_with_its_button(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var hud := farm.get_node("Hud") as Hud
	await t.frames(2)
	t.ok(not hud.bag_panel.visible, "the bag starts closed")
	await t.tap_action("inventory_toggle")
	t.ok(hud.bag_panel.visible, "I opens it")
	await t.tap_action("inventory_toggle")
	t.ok(not hud.bag_panel.visible, "I closes it")
	var button := hud.get_node("Root/ToolBar/BarRow/BagButton") as Button
	await t.click(_centre(button))
	t.ok(hud.bag_panel.visible, "the Bag button opens it")
	await t.click(_centre(button))
	t.ok(not hud.bag_panel.visible, "and closes it")
	farm.queue_free()


func test_the_open_bag_shows_a_swatch_two_letters_a_count_and_a_tooltip(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var hud := farm.get_node("Hud") as Hud
	hud.toggle_bag()
	await t.frames(2)
	var first := hud.grid.get_child(0) as InventorySlot
	t.eq(first.badge.text, "Cs", "the first slot holds the carrot seeds")
	t.eq(first.count_label.text, "8", "eight of them")
	t.ok(first.swatch.visible and first.count_label.visible, "the swatch and the count are shown")
	t.eq(first.swatch.color, SEED_CARROT.color, "the swatch has the item's colour")
	t.eq(first.tooltip_text, "Carrot seeds\n8 of 99", "the tooltip names the item and the stack")
	var empty := hud.grid.get_child(10) as InventorySlot
	t.ok(not empty.swatch.visible and not empty.count_label.visible, "an empty slot shows nothing")
	t.eq(empty.tooltip_text, "", "and has no tooltip")
	t.eq(hud.bag_count.text, "6 / 24", "six of 24 slots are used")
	Inventory.add(CARROT, 1)
	await t.frames(1)
	var carrot_slot := hud.grid.get_child(6) as InventorySlot
	t.eq(carrot_slot.badge.text, "Ca", "a new item lands in the next free slot")
	t.ok(not carrot_slot.count_label.visible, "a single item shows no count")
	t.eq(hud.bag_count.text, "7 / 24", "and the counter follows")
	t.eq(first.get_global_rect().size.x, 64.0, "a slot is 64 pixels wide")
	farm.queue_free()


func test_a_toast_appears_for_an_item_and_for_a_hint_and_fades(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var hud := farm.get_node("Hud") as Hud
	await t.frames(2)
	t.ok(not hud.toast.visible, "no toast at the start")
	Inventory.add(CARROT, 2)
	t.ok(hud.toast.visible, "a toast shows")
	t.eq(hud.toast_label.text, "+2 Carrot", "it names the amount and the item")
	Events.hint_shown.emit("Dry ground. Take the hoe (1).")
	t.eq(hud.toast_label.text, "Dry ground. Take the hoe (1).", "a hint becomes a toast")
	await t.secs(0.2)
	t.ok(hud.toast.visible, "it is still there a moment later")
	await t.secs(Hud.TOAST_SECONDS + 0.5 + 0.3)
	t.ok(not hud.toast.visible, "it is gone after its time")
	farm.queue_free()
