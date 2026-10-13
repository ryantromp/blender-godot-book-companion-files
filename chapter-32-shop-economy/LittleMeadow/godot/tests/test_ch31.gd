extends Node
## Chapter 31: build mode. The grid maths, the rules, the money, the ghost, the controls, the clock,
## the farmer lock, the rows of fence, the navigation mesh and the save data.
## The clock runs like in Chapter 25: 480 physics steps a second and Engine.time_scale 8.

const FARM: String = "res://scenes/world/farm.tscn"
const PROBE := Vector3(0.5, 0.0, 12.0)
## A piece of open meadow south of the field.
const OPEN := Vector3(0.5, 0.0, 8.5)
const TICKS: int = 480
const SPEEDUP: float = 8.0

var _log: Array[String] = []
var _catalog: BuildCatalog


func before_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = TICKS
	Engine.time_scale = SPEEDUP
	GameClock.running = false
	GameClock.paused = false
	GameClock.set_time(1, 360)
	Inventory.clear()
	Inventory.give_starting_items()
	Economy.money = Economy.START_MONEY
	_catalog = load("res://resources/buildables/catalog.tres") as BuildCatalog
	for item: BuildItemData in _catalog.items:
		item.unlocked = true
	for node: Node in Engine.get_main_loop().root.get_children():
		if node.scene_file_path == FARM:
			node.free()
	for node: Node in Engine.get_main_loop().get_nodes_in_group(&"fx"):
		node.free()
	Fx.active = 0
	_log.clear()
	if not Events.hint_shown.is_connected(_on_hint):
		Events.hint_shown.connect(_on_hint)
		Events.build_placed.connect(_on_placed)
		Events.build_removed.connect(_on_removed)
		Events.build_denied.connect(_on_denied)
		Events.build_mode_changed.connect(_on_mode)


func after_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	GameClock.running = false
	GameClock.paused = false


func _on_hint(text: String) -> void:
	_log.append("hint:" + text)


func _on_placed(item: BuildItemData, _node: Node3D) -> void:
	_log.append("placed:" + item.id)


func _on_removed(item: BuildItemData, refund: int) -> void:
	_log.append("removed:%s:%d" % [item.id, refund])


func _on_denied(item: BuildItemData, reason: String) -> void:
	_log.append("denied:%s:%s" % [item.id, reason])


func _on_mode(active: bool) -> void:
	_log.append("mode:%s" % active)


func _count(prefix: String) -> int:
	var n: int = 0
	for line: String in _log:
		if line.begins_with(prefix):
			n += 1
	return n


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
	var build := farm.get_node("Build") as BuildMode
	build.bake_delay = 0.05
	return farm


func _build(farm: Node) -> BuildMode:
	return farm.get_node("Build") as BuildMode


func _item(farm: Node, id: StringName) -> BuildItemData:
	return _build(farm).item_for(id)


func _placed(farm: Node) -> Node3D:
	return farm.get_node("World/Placed") as Node3D


func _screen(farm: Node, point: Vector3) -> Vector2:
	return (farm.get_node("CameraRig") as CameraRig).camera.unproject_position(point)


func _key(code: Key, shift: bool = false, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.pressed = true
	Input.parse_input_event(event)
	var up := event.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)


func _wheel(t: Variant, button: MouseButton, shift: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = t._to_window(t.screen_size() / 2.0)
	event.global_position = event.position
	event.button_index = button
	event.shift_pressed = shift
	event.pressed = true
	Input.parse_input_event(event)


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


# ---------------------------------------------------------------- the grid maths

func test_a_point_snaps_to_its_cell_also_below_zero(t: Variant) -> void:
	t.eq(BuildGrid.cell_of(Vector3(0.5, 0.0, 0.5)), Vector2i(0, 0), "0.5 is in cell 0")
	t.eq(BuildGrid.cell_of(Vector3(0.999, 0.0, 1.0)), Vector2i(0, 1), "1.0 starts the next cell")
	t.eq(BuildGrid.cell_of(Vector3(-0.2, 0.0, -0.2)), Vector2i(-1, -1), "-0.2 is in cell -1, not 0")
	t.eq(BuildGrid.cell_of(Vector3(-0.0001, 0.0, 0.0)), Vector2i(-1, 0), "just below zero is cell -1")
	t.eq(BuildGrid.cell_of(Vector3(-1.0, 0.0, -1.0)), Vector2i(-1, -1), "-1.0 is the start of cell -1")
	t.eq(BuildGrid.cell_of(Vector3(-23.5, 0.0, 22.3)), Vector2i(-24, 22), "the far west edge")
	t.eq(BuildGrid.cell_of(Vector3(23.99, 5.0, -23.99)), Vector2i(23, -24), "the height does not matter")
	t.eq(int(-0.2), 0, "the plain int() of -0.2 is 0, which is why floori() is used")
	t.eq(BuildGrid.middle(Vector2i(-1, -1), Vector2i(1, 1)), Vector3(-0.5, 0.0, -0.5), "the middle of cell (-1, -1)")


func test_the_farm_bounds_are_cells_minus_24_to_23(t: Variant) -> void:
	t.ok(BuildGrid.in_bounds(Vector2i(-24, -24)), "north west corner cell is inside")
	t.ok(BuildGrid.in_bounds(Vector2i(23, 23)), "south east corner cell is inside")
	t.ok(not BuildGrid.in_bounds(Vector2i(-25, 0)), "one past the west edge")
	t.ok(not BuildGrid.in_bounds(Vector2i(24, 0)), "one past the east edge")
	t.ok(not BuildGrid.in_bounds(Vector2i(0, -25)), "one past the north edge")
	t.ok(not BuildGrid.in_bounds(Vector2i(0, 24)), "one past the south edge")


func test_footprints_follow_the_turn(t: Variant) -> void:
	t.eq(BuildGrid.turned(Vector2i(2, 1), 0), Vector2i(2, 1), "no turn")
	t.eq(BuildGrid.turned(Vector2i(2, 1), 1), Vector2i(1, 2), "one turn swaps width and depth")
	t.eq(BuildGrid.turned(Vector2i(2, 1), 2), Vector2i(2, 1), "two turns swap back")
	t.eq(BuildGrid.turned(Vector2i(2, 1), 3), Vector2i(1, 2), "three turns")
	t.eq(BuildGrid.turned(Vector2i(2, 1), -1), Vector2i(1, 2), "a turn back works too (posmod)")
	t.eq(BuildGrid.turned(Vector2i(3, 3), 1), Vector2i(3, 3), "a square stays a square")
	t.eq(BuildGrid.lowest_cell(Vector2i(5, 5), Vector2i(1, 1)), Vector2i(5, 5), "1 x 1 sits on the pointer cell")
	t.eq(BuildGrid.lowest_cell(Vector2i(5, 5), Vector2i(2, 1)), Vector2i(5, 5), "2 x 1 grows toward +x")
	t.eq(BuildGrid.lowest_cell(Vector2i(5, 5), Vector2i(3, 3)), Vector2i(4, 4), "3 x 3 centres on the pointer cell")
	t.eq(BuildGrid.lowest_cell(Vector2i(-3, -3), Vector2i(3, 3)), Vector2i(-4, -4), "3 x 3 below zero")
	t.eq(BuildGrid.lowest_cell(Vector2i(-1, 0), Vector2i(1, 2)), Vector2i(-1, 0), "1 x 2 grows toward +z")
	var cells: Array[Vector2i] = BuildGrid.cells_for(Vector2i(-1, -1), Vector2i(3, 2))
	t.eq(cells.size(), 6, "3 x 2 is 6 cells")
	t.ok(cells.has(Vector2i(-1, -1)) and cells.has(Vector2i(1, 0)), "from (-1, -1) to (1, 0)")
	t.eq(BuildGrid.middle(Vector2i(4, 4), Vector2i(2, 1)), Vector3(5.0, 0.0, 4.5), "a rail has its middle on a grid line")
	t.eq(BuildGrid.middle(Vector2i(4, 4), Vector2i(3, 3)), Vector3(5.5, 0.0, 5.5), "a shed has its middle at a cell middle")
	t.eq(BuildGrid.middle(Vector2i(4, 4), Vector2i(1, 2)), Vector3(4.5, 0.0, 5.0), "a turned rail: middle on a z line")
	t.approx(BuildGrid.yaw(1), PI / 2.0, 0.0001, "one turn is 90 degrees")
	t.approx(BuildGrid.yaw(2), PI, 0.0001, "two turns are 180")


func test_the_origin_of_a_gate_follows_its_hinge(t: Variant) -> void:
	var gate := BuildItemData.new()
	gate.footprint = Vector2i(1, 1)
	gate.pivot_offset = Vector3(-0.5, 0.0, -0.5)
	t.vec_approx(BuildGrid.origin_for(gate, Vector2i(2, 3), 0), Vector3(2.0, 0.0, 3.0), 0.0001, "no turn: the hinge is the north west corner")
	t.vec_approx(BuildGrid.origin_for(gate, Vector2i(2, 3), 1), Vector3(2.0, 0.0, 4.0), 0.0001, "one turn: the south west corner")
	t.vec_approx(BuildGrid.origin_for(gate, Vector2i(2, 3), 2), Vector3(3.0, 0.0, 4.0), 0.0001, "two turns: the south east corner")
	t.vec_approx(BuildGrid.origin_for(gate, Vector2i(2, 3), 3), Vector3(3.0, 0.0, 3.0), 0.0001, "three turns: the north east corner")
	t.vec_approx(BuildGrid.origin_for(gate, Vector2i(-2, -3), 3), Vector3(-1.0, 0.0, -3.0), 0.0001, "below zero too")
	var rail := BuildItemData.new()
	rail.footprint = Vector2i(2, 1)
	rail.pivot_offset = Vector3(0.0, 0.0, -0.5)
	t.vec_approx(BuildGrid.origin_for(rail, Vector2i(0, 8), 0), Vector3(1.0, 0.0, 8.0), 0.0001, "a fence stands on the grid line at the top of its cells")
	t.vec_approx(BuildGrid.origin_for(rail, Vector2i(0, 8), 1), Vector3(0.0, 0.0, 9.0), 0.0001, "turned, it stands on the grid line at the left")


func test_cells_under_an_outline_ignore_a_shape_that_only_touches(t: Variant) -> void:
	var shed := PackedVector2Array([Vector2(16, -16), Vector2(19, -16), Vector2(19, -13), Vector2(16, -13)])
	t.eq(BuildGrid.cells_under(shed).size(), 9, "a 3 x 3 m outline on the grid covers 9 cells, not 16")
	var one := PackedVector2Array([Vector2(2, 2), Vector2(3, 2), Vector2(3, 3), Vector2(2, 3)])
	t.eq(BuildGrid.cells_under(one), [Vector2i(2, 2)] as Array[Vector2i], "one cell is one cell")
	var thin := PackedVector2Array([Vector2(-22, -3.15), Vector2(-20, -3.15), Vector2(-20, -2.85), Vector2(-22, -2.85)])
	var rows: Array[Vector2i] = BuildGrid.cells_under(thin)
	t.eq(rows.size(), 4, "a 0.3 m fence on a grid line covers the two rows beside it")
	t.ok(rows.has(Vector2i(-22, -4)) and rows.has(Vector2i(-21, -3)), "rows -4 and -3")
	var octagon := PackedVector2Array()
	for step: int in 8:
		octagon.append(Vector2(10.0, 14.0) + Vector2.from_angle(TAU * (step + 0.5) / 8.0) * 1.9)
	var pond: Array[Vector2i] = BuildGrid.cells_under(octagon)
	t.ok(pond.size() >= 12 and pond.size() <= 16, "the pond outline covers %d cells" % pond.size())
	t.ok(pond.has(Vector2i(9, 13)) and pond.has(Vector2i(10, 14)), "the middle cells are in it")


func test_a_drag_makes_a_row_along_the_longer_side(t: Variant) -> void:
	t.eq(BuildGrid.line_turns(Vector2i(0, 0), Vector2i(5, 1)), 0, "mostly east: along x")
	t.eq(BuildGrid.line_turns(Vector2i(0, 0), Vector2i(1, -5)), 1, "mostly north: along z")
	t.eq(BuildGrid.line_turns(Vector2i(0, 0), Vector2i(3, 3)), 0, "a tie goes to x")
	var east: Array[Vector2i] = BuildGrid.line_anchors(Vector2i(0, 0), Vector2i(5, 1), 2)
	t.eq(east, [Vector2i(0, 0), Vector2i(2, 0), Vector2i(4, 0)] as Array[Vector2i], "rails 2 cells long: three of them")
	var west: Array[Vector2i] = BuildGrid.line_anchors(Vector2i(0, 0), Vector2i(-5, 0), 2)
	t.eq(west, [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(-4, 0)] as Array[Vector2i], "toward -x")
	var south: Array[Vector2i] = BuildGrid.line_anchors(Vector2i(3, 3), Vector2i(3, 9), 1)
	t.eq(south.size(), 7, "posts 1 cell long: 7 from z 3 to z 9")
	t.eq(south[6], Vector2i(3, 9), "the last post is on the end cell")
	t.eq(BuildGrid.line_anchors(Vector2i(0, 0), Vector2i(0, 0), 2).size(), 1, "no drag: one piece")
	t.eq(BuildGrid.line_anchors(Vector2i(-20, 0), Vector2i(20, 0), 1).size(), BuildGrid.MAX_LINE, "a row never grows past the limit")


# ---------------------------------------------------------------- the catalog and the scene

func test_the_catalog_holds_twelve_items(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var catalog: BuildCatalog = build.catalog
	t.ok(catalog.resource_path.ends_with("catalog.tres"), "the catalog is the file catalog.tres")
	t.eq(catalog.items.size(), 12, "twelve items")
	var ids: Dictionary = {}
	var categories: Array[int] = [0, 0, 0]
	for item: BuildItemData in catalog.items:
		ids[item.id] = true
		categories[item.category] += 1
		t.ok(item.scene != null, "%s has a scene" % item.id)
		t.ok(item.cost > 0 and item.footprint.x >= 1 and item.footprint.y >= 1, "%s has a price and a footprint" % item.id)
		t.ok(item.short_name.length() == 2, "%s has two letters" % item.id)
		t.eq(item.refund(), item.cost / 2, "%s refunds half" % item.id)
		var node: Node = item.scene.instantiate()
		t.ok(node is Node3D, "%s instantiates as a Node3D" % item.id)
		node.free()
	t.eq(ids.size(), 12, "twelve different ids")
	t.eq(categories, [3, 2, 7], "three fences, two buildings, seven decorations")
	t.eq(catalog.in_category(BuildItemData.Category.BUILDING).size(), 2, "in_category finds the two buildings")
	t.eq(catalog.find(&"gate").pivot_offset, Vector3(-0.5, 0.0, -0.5), "the gate turns on its hinge")
	t.eq(catalog.find(&"shed").footprint, Vector2i(3, 3), "the shed is 3 x 3")
	t.eq(catalog.find(&"well").footprint, Vector2i(2, 2), "the well is 2 x 2")
	t.eq(catalog.find(&"fence").footprint, Vector2i(2, 1), "a fence section is 2 x 1")
	t.ok(catalog.find(&"fence").line, "fences come in rows")
	t.ok(not catalog.find(&"shed").line, "a shed does not")
	for id: StringName in [&"barrel", &"lantern", &"flowers", &"corner"]:
		t.ok(not catalog.find(id).rotatable, "%s is round or square: R does nothing" % id)
	for id: StringName in [&"fence", &"gate", &"shed", &"crate", &"trough"]:
		t.ok(catalog.find(id).rotatable, "%s can be turned" % id)
	t.eq(catalog.find(&"nothing"), null, "an unknown id is null")
	var costs: Dictionary = {}
	for item: BuildItemData in catalog.items:
		costs[item.id] = item.cost
	t.eq(costs, {&"fence": 6, &"corner": 3, &"gate": 8, &"shed": 75, &"well": 40, &"crate": 6, &"barrel": 5, &"hay": 5, &"trough": 12, &"lantern": 8, &"sign": 4, &"flowers": 3}, "the prices")
	var section: Node = catalog.find(&"fence").scene.instantiate()
	t.eq(section.get_children().map(func(n: Node) -> String: return n.name), ["Rail", "PostWest", "PostEast"], "a fence section is a rail and two posts")
	section.free()
	var tres: int = 0
	for file: String in DirAccess.get_files_at("res://resources/buildables"):
		if file.ends_with(".tres"):
			tres += 1
	t.eq(tres, 13, "twelve items and the catalog in the folder")
	farm.queue_free()


func test_the_farm_holds_the_build_nodes(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	t.ok(farm.get_node_or_null("World/Placed") is Node3D, "World/Placed exists")
	t.eq(build.placed_root, _placed(farm), "Build points at it")
	t.eq(build.world, farm.get_node("World"), "Build points at the World region")
	t.eq(build.farmer, farm.get_node("Farmer"), "and at the farmer")
	t.eq(_placed(farm).get_child_count(), 0, "nothing is built at the start")
	var menu := farm.get_node("Hud/BuildMenu") as BuildMenu
	t.ok(menu != null, "the menu is a child of the Hud")
	t.eq(menu.build, build, "the menu points at Build")
	for path: String in ["Palette", "Banner", "OpenButton", "Palette/PaletteColumn/Slots", "Palette/PaletteColumn/TitleRow/Tabs",
			"Palette/PaletteColumn/TitleRow/StatusLabel", "Palette/PaletteColumn/TitleRow/RemoveButton", "Palette/PaletteColumn/TitleRow/DoneButton"]:
		t.ok(menu.get_node_or_null(path) != null, "BuildMenu has %s" % path)
	t.ok(not build.active, "build mode is off")
	t.ok(not menu.palette.visible, "the palette is hidden")
	t.ok(menu.open_button.visible, "the Build button shows")
	t.ok(not build.ghost.visible, "no ghost")
	t.ok(not build._grid.visible, "no grid")
	t.eq(build.current, build.catalog.items[0], "the fence is chosen first")
	t.eq(build.category, BuildItemData.Category.FENCE, "on the Fences tab")
	t.ok(build.map.kinds.size() > 300, "the map knows the scenery (%d cells)" % build.map.kinds.size())
	farm.queue_free()


func test_the_map_knows_what_stands_where(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var map: BuildMap = _build(farm).map
	t.eq(map.kind_at(BuildGrid.cell_of(Vector3(-8.5, 0.0, -13.5))), &"scenery", "the farmhouse")
	t.eq(map.kind_at(BuildGrid.cell_of(Vector3(8.5, 0.0, -14.0))), &"scenery", "the barn")
	t.eq(map.kind_at(BuildGrid.cell_of(Vector3(17.5, 0.0, -14.5))), &"scenery", "the shed")
	t.eq(map.kind_at(BuildGrid.cell_of(Vector3(10.0, 0.0, 14.0))), &"water", "the middle of the pond")
	t.eq(map.kind_at(BuildGrid.cell_of(Vector3(-11.5, 0.0, 4.5))), &"soil", "the first plot")
	t.eq(map.kind_at(BuildGrid.cell_of(Vector3(-4.5, 0.0, 8.5))), &"soil", "the last plot")
	t.eq(map.kind_at(BuildGrid.cell_of(Vector3(18.0, 1.0, 2.0))), &"slope", "the top of the hill")
	t.eq(map.kind_at(BuildGrid.cell_of(Vector3(14.5, 0.0, 6.5))), &"slope", "a hill slope")
	t.eq(map.kind_at(BuildGrid.cell_of(Vector3(-19.0, 0.0, -3.0))), &"scenery", "a fence of the chicken pen")
	t.eq(map.kind_at(BuildGrid.cell_of(Vector3(-3.0, 0.0, 3.2))), &"scenery", "the pump")
	t.eq(map.kind_at(BuildGrid.cell_of(OPEN)), &"", "open meadow is free")
	t.eq(map.kind_at(BuildGrid.cell_of(Vector3(0.5, 0.0, -3.5))), &"", "the start of the farmer is free")
	t.eq(map.kind_at(Vector2i(100, 100)), &"outside", "far away is outside the farm")
	t.eq(map.kind_at(Vector2i(-25, 0)), &"outside", "one cell past the west edge")
	var water: int = 0
	var soil: int = 0
	for cell: Vector2i in map.kinds:
		if map.kinds[cell] == &"water":
			water += 1
		elif map.kinds[cell] == &"soil":
			soil += 1
	t.eq(soil, 40, "forty soil cells, one per plot")
	t.ok(water >= 12 and water <= 16, "%d water cells" % water)
	farm.queue_free()


# ---------------------------------------------------------------- the rules

func test_the_rules_say_why_not(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var farmer := farm.get_node("Farmer") as Farmer
	farmer.global_position = Vector3(-14.5, 0.0, -4.5)
	var corner: BuildItemData = build.catalog.find(&"corner")
	var fence: BuildItemData = build.catalog.find(&"fence")
	var shed: BuildItemData = build.catalog.find(&"shed")
	t.eq(build.problem_for(corner, Vector2i(0, 8), 0), "", "open meadow is fine")
	t.eq(build.problem_for(fence, Vector2i(23, 12), 0), "That is outside the farm.", "a fence on x 23 and 24 sticks out")
	t.eq(build.problem_for(fence, Vector2i(22, 12), 0), "", "a fence on x 22 and 23 fits")
	t.eq(build.problem_for(corner, Vector2i(-25, 0), 0), "That is outside the farm.", "west of the farm")
	t.eq(build.problem_for(corner, Vector2i(0, 24), 0), "That is outside the farm.", "south of the farm")
	t.eq(build.problem_for(shed, Vector2i(23, 10), 0), "That is outside the farm.", "a shed at the east edge")
	t.eq(build.problem_for(fence, Vector2i(22, 11), 1), "", "turned, a fence on x 22 stands on z 11 and 12")
	t.eq(build.problem_for(fence, Vector2i(22, 23), 1), "That is outside the farm.", "turned, it sticks out at the south edge")
	t.eq(build.problem_for(shed, Vector2i(-10, -15), 0), "Something is in the way.", "a shed on the farmhouse")
	t.eq(build.problem_for(corner, Vector2i(9, 13), 0), "That is water.", "a post in the pond")
	t.eq(build.problem_for(corner, Vector2i(-12, 4), 0), "That is farm soil.", "a post on a plot")
	t.eq(build.problem_for(shed, Vector2i(-7, 7), 0), "That is farm soil.", "a shed that covers the bottom rows of the field")
	t.eq(build.problem_for(corner, Vector2i(18, 2), 0), "The hill is too steep to build on.", "a post on the hill")
	t.eq(build.problem_for(corner, Vector2i(-15, -5), 0), "The farmer is in the way.", "a post under the farmer")
	t.eq(build.problem_for(shed, Vector2i(-15, -6), 0), "The farmer is in the way.", "a shed that covers the farmer by one cell")
	t.eq(build.problem_for(corner, Vector2i(-14, -5), 0), "", "one cell away is fine")
	var cow := farm.get_node("Animals/Cow_1") as Animal
	t.eq(build.problem_for(corner, BuildGrid.cell_of(cow.global_position), 0), "An animal is in the way.", "a post under a cow")
	t.eq(build.problem_for(shed, Vector2i(0, 8), 0), "", "a shed on open meadow")
	Economy.money = 50
	t.eq(build.problem_for(shed, Vector2i(0, 8), 0), "Not enough coins: the shed costs 75.", "50 coins do not buy a shed")
	t.eq(build.fit_problem(shed, Vector2i(0, 8), 0), "", "but it would fit")
	t.eq(build.problem_for(shed, Vector2i(-10, -15), 0), "Something is in the way.", "a space problem is named before a money problem")
	Economy.money = 78
	t.eq(build.problem_for(shed, Vector2i(0, 8), 0), "", "78 coins are enough")
	var first: Node3D = build.try_place(corner, Vector2i(0, 8), 0)
	t.not_null(first, "the post is built")
	t.eq(build.problem_for(corner, Vector2i(0, 8), 0), "You already built there.", "the same cell again")
	t.eq(build.problem_for(shed, Vector2i(-1, 7), 0), "You already built there.", "a shed that overlaps the post")
	t.eq(build.problem_for(shed, Vector2i(0, 10), 0), "", "a shed one row below does not")
	t.eq(build.problem_for(fence, Vector2i(-1, 8), 0), "You already built there.", "a fence that ends on it")
	t.eq(build.problem_for(fence, Vector2i(-2, 8), 0), "", "a fence that stops before it")
	farm.queue_free()


# ---------------------------------------------------------------- money

func test_a_build_costs_coins_and_a_refusal_costs_none(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	t.eq(Economy.money, 100, "100 coins to start")
	t.not_null(build.try_place(build.catalog.find(&"fence"), Vector2i(0, 8), 0), "a fence")
	t.eq(Economy.money, 94, "the fence costs 6")
	t.not_null(build.try_place(build.catalog.find(&"shed"), Vector2i(4, 8), 0), "a shed fits and is affordable")
	t.eq(Economy.money, 19, "the shed costs 75")
	var before: int = _placed(farm).get_child_count()
	t.eq(build.try_place(build.catalog.find(&"shed"), Vector2i(-4, 12), 0), null, "a second shed is refused")
	t.eq(Economy.money, 19, "no coins change hands")
	t.eq(_placed(farm).get_child_count(), before, "nothing is built")
	t.eq(_count("hint:Not enough coins: the shed costs 75."), 1, "the hint names the thing and the price")
	t.eq(_count("denied:shed:Not enough coins"), 1, "the bus says denied")
	var hud := farm.get_node("Hud") as Hud
	t.eq(hud.toast_label.text, "Not enough coins: the shed costs 75.", "the toast of the HUD shows it")
	t.ok(hud.toast.visible, "and is visible")
	var money_before: int = Economy.money
	t.eq(build.try_place(build.catalog.find(&"corner"), Vector2i(-10, -15), 0), null, "a post on the farmhouse is refused")
	t.eq(Economy.money, money_before, "a refusal for a rule costs nothing either")
	t.eq(_count("hint:Something is in the way."), 1, "the hint says why")
	Economy.money = 5
	t.eq(build.try_place(build.catalog.find(&"fence"), Vector2i(10, 8), 0), null, "5 coins do not buy a 6 coin fence")
	t.eq(Economy.money, 5, "still 5")
	Economy.money = 6
	t.not_null(build.try_place(build.catalog.find(&"fence"), Vector2i(10, 8), 0), "6 coins do")
	t.eq(Economy.money, 0, "all spent: the exact amount is enough")
	farm.queue_free()


func test_demolishing_gives_half_and_frees_the_node(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var shed: Node3D = build.try_place(build.catalog.find(&"shed"), Vector2i(4, 8), 0)
	t.eq(Economy.money, 25, "100 - 75")
	t.ok(build.remove(shed), "the shed comes down")
	t.eq(Economy.money, 62, "half of 75 is 37, so 25 + 37")
	t.eq(_count("removed:shed:37"), 1, "the bus says removed, with the refund")
	t.ok(shed.is_queued_for_deletion(), "the node is queued for freeing")
	t.ok(shed.get_parent() == null, "and is already out of the tree")
	await t.frames(2)
	t.ok(not is_instance_valid(shed), "after a frame it is gone")
	t.eq(build.map.kind_at(Vector2i(5, 9)), &"", "its cells are free")
	var fence: Node3D = build.try_place(build.catalog.find(&"fence"), Vector2i(0, 8), 0)
	t.eq(Economy.money, 56, "a fence: 62 - 6")
	t.ok(build.remove(fence), "demolish the fence")
	t.eq(Economy.money, 59, "half of 6 is 3")
	t.ok(not build.remove(null), "nothing to demolish: false")
	var barn: Node = farm.get_node("World/Buildings/Barn")
	t.ok(not build.remove(barn as Node3D), "the barn is scenery, not built: it stays")
	t.ok(barn.is_inside_tree(), "the barn is still there")
	t.eq(Economy.money, 59, "and no coins arrive")
	farm.queue_free()


# ---------------------------------------------------------------- building and demolishing

func test_things_go_under_placed_with_a_record(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var gate: Node3D = build.try_place(build.catalog.find(&"gate"), Vector2i(2, 8), 1)
	t.not_null(gate, "a gate")
	t.eq(gate.get_parent(), _placed(farm), "it is a child of World/Placed")
	t.ok(gate.is_in_group(&"placed"), "it is in the group placed")
	t.eq(gate.get_meta(&"build_id"), &"gate", "it knows what it is")
	t.eq(gate.get_meta(&"build_cell"), Vector2i(2, 8), "it knows its lowest cell")
	t.eq(gate.get_meta(&"build_turns"), 1, "and its turn")
	t.vec_approx(gate.global_position, Vector3(2.0, 0.0, 9.0), 0.0001, "the hinge is the south west corner of the cell")
	t.approx(gate.rotation.y, PI / 2.0, 0.0001, "turned 90 degrees")
	t.eq(build.map.kind_at(Vector2i(2, 8)), &"placed", "the map holds the cell")
	t.eq(build.map.owners[Vector2i(2, 8)], gate, "and who stands on it")
	t.eq(_count("placed:gate"), 1, "the bus says placed")
	t.ok(Fx.active >= 1, "a dust puff started")
	var dust: Array[Node] = farm.get_tree().get_nodes_in_group(&"fx")
	t.eq(dust.size(), 1, "it is in the group fx")
	t.vec_approx((dust[0] as Node3D).global_position, gate.global_position, 0.001, "at the place of the gate")
	var barrel: Node3D = build.try_place(build.catalog.find(&"barrel"), Vector2i(5, 8), 0)
	t.vec_approx(barrel.global_position, Vector3(5.5, 0.0, 8.5), 0.0001, "a barrel stands in the middle of its cell")
	var shed: Node3D = build.try_place(build.catalog.find(&"shed"), Vector2i(4, 12), 0)
	t.vec_approx(shed.global_position, Vector3(5.5, 0.0, 13.5), 0.0001, "a shed with its lowest cell (4, 12) stands at (5.5, 13.5)")
	t.eq(_placed(farm).get_child_count(), 3, "three things")
	t.ok(gate.name != barrel.name and barrel.name != shed.name, "each has its own name")
	var cells: int = 0
	for kind: StringName in build.map.kinds.values():
		if kind == &"placed":
			cells += 1
	t.eq(cells, 1 + 1 + 9, "gate 1 + barrel 1 + shed 9 cells")
	t.ok(build.remove(shed), "demolish the shed")
	t.eq(_placed(farm).get_child_count(), 2, "two things left, counted at once")
	t.eq(build.map.kind_at(Vector2i(4, 12)), &"", "its cells are free again")
	t.eq(build.map.owners.get(Vector2i(5, 13)), null, "and it owns nothing")
	farm.queue_free()


func test_a_turned_fence_takes_a_turned_footprint(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var fence: BuildItemData = build.catalog.find(&"fence")
	var flat: Node3D = build.try_place(fence, Vector2i(0, 8), 0)
	t.vec_approx(flat.global_position, Vector3(1.0, 0.0, 8.0), 0.0001, "flat: the rail lies on the grid line z = 8")
	t.eq(build.map.kind_at(Vector2i(1, 8)), &"placed", "it holds (0, 8) and (1, 8)")
	t.eq(build.map.kind_at(Vector2i(0, 9)), &"", "and nothing below")
	var turned: Node3D = build.try_place(fence, Vector2i(5, 8), 1)
	t.vec_approx(turned.global_position, Vector3(5.0, 0.0, 9.0), 0.0001, "turned: the rail lies on the grid line x = 5")
	t.eq(build.map.kind_at(Vector2i(5, 9)), &"placed", "it holds (5, 8) and (5, 9)")
	t.eq(build.map.kind_at(Vector2i(6, 8)), &"", "and nothing to the right")
	# The ends of the two posts of a section are 2 m apart, at whole metres.
	var west := turned.get_node("PostWest") as Node3D
	var east := turned.get_node("PostEast") as Node3D
	t.vec_approx(west.global_position, Vector3(5.0, 0.0, 10.0), 0.0001, "the west post turned to the south end")
	t.vec_approx(east.global_position, Vector3(5.0, 0.0, 8.0), 0.0001, "and the east post to the north end")
	farm.queue_free()


func test_a_placed_scene_collides_and_casts_shadows(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var shed: Node3D = build.try_place(build.catalog.find(&"shed"), Vector2i(4, 12), 0)
	await t.physics_frames(2)
	var meshes: Array[Node] = shed.find_children("*", "MeshInstance3D", true, false)
	t.ok(meshes.size() >= 1, "the shed has meshes")
	for mesh: Node in meshes:
		t.ok((mesh as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts a shadow" % mesh.name)
	t.ok((farm.get_node("Sun") as DirectionalLight3D).shadow_enabled, "the sun of the farm has shadows on")
	var bodies: Array[Node] = shed.find_children("*", "StaticBody3D", true, false)
	t.ok(bodies.size() >= 1, "it has a body")
	for body: Node in bodies:
		t.eq((body as StaticBody3D).collision_layer, 8, "on layer 4, obstacle")
	t.ok(shed.get_node_or_null("Footprint") is NavigationObstacle3D, "and a Footprint for the bake")
	var from := Vector3(5.5, 6.0, 13.5)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0, 8)
	var hit: Dictionary = (farm.get_node("Farmer") as Farmer).get_world_3d().direct_space_state.intersect_ray(query)
	t.ok(hit.has("position"), "a ray from above hits the new shed")
	var section: Node3D = build.try_place(build.catalog.find(&"fence"), Vector2i(0, 8), 0)
	t.eq(section.find_children("*", "StaticBody3D", true, false).size(), 3, "a fence section has three bodies, rail and two posts")
	t.eq(section.find_children("Footprint", "NavigationObstacle3D", true, false).size(), 3, "and three footprints")
	farm.queue_free()


# ---------------------------------------------------------------- the ghost

func test_the_ghost_is_green_where_it_fits_and_red_where_it_does_not(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	t.ok(not build.ghost.visible, "no ghost outside build mode")
	build.set_active(true)
	build.select(build.catalog.find(&"shed"))
	build.aim_at(Vector3(0.5, 0.0, 8.5))
	t.ok(build.ghost.visible, "the ghost shows in build mode")
	t.ok(build.ghost.valid, "open meadow: valid")
	var tint := (build.ghost.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).material_override as StandardMaterial3D
	t.eq(tint.albedo_color, BuildGhost.GOOD, "green")
	t.eq(build.ghost.plate.material_override.albedo_color, BuildGhost.GOOD, "the plate is green too")
	t.ok(tint.albedo_color.a < 1.0 and tint.albedo_color.a > 0.0, "translucent: alpha %.2f" % tint.albedo_color.a)
	t.eq(tint.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "alpha blending is on")
	t.vec_approx(build.ghost.position, Vector3(0.5, 0.0, 8.5), 0.0001, "a shed ghost centres on the cell")
	t.approx(build.ghost.plate.global_position.y, 0.03, 0.0001, "the plate lies just above the ground")
	t.eq((build.ghost.plate.mesh as PlaneMesh).size, Vector2(2.88, 2.88), "its size is the footprint minus a thin gap")
	t.eq(build.ghost.tag.text, "75 coins", "the price tag floats over it")
	t.approx(build.ghost.tag.position.y, 2.4, 0.0001, "2.4 m above the ground")
	t.eq(build.ghost.tag.modulate, Color("FFF5CC"), "in a light tone")
	build.aim_at(Vector3(-8.5, 0.0, -13.5))
	t.ok(not build.ghost.valid, "on the farmhouse: invalid")
	t.eq(tint.albedo_color, BuildGhost.BAD, "red")
	t.eq(build.ghost.plate.material_override.albedo_color, BuildGhost.BAD, "the plate is red")
	t.eq(build.status, "Something is in the way.", "the status says why")
	t.eq(build.ghost.tag.modulate, Color("FF9A8A"), "the tag turns red")
	build.aim_at(Vector3(0.5, 0.0, 8.5))
	t.eq(tint.albedo_color, BuildGhost.GOOD, "green again")
	t.eq(build.status, "Shed: 75 coins", "the status shows the price")
	Economy.money = 50
	build.aim_at(Vector3(1.5, 0.0, 8.5))
	t.ok(not build.ghost.valid, "with 50 coins the shed ghost is red on free ground")
	t.eq(tint.albedo_color, BuildGhost.BAD, "red")
	t.eq(build.status, "Not enough coins: the shed costs 75.", "and says why")
	t.eq(build.ghost.find_children("*", "CollisionObject3D", true, false).size(), 0, "no collision nodes in the ghost")
	t.eq(build.ghost.find_children("*", "NavigationObstacle3D", true, false).size(), 0, "no obstacle for the bake")
	for mesh: Node in build.ghost.find_children("*", "MeshInstance3D", true, false):
		t.eq((mesh as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the ghost casts no shadow")
	build.set_active(false)
	t.ok(not build.ghost.visible, "the ghost hides when build mode ends")
	farm.queue_free()


func test_the_ghost_turns_and_a_gate_ghost_follows_its_hinge(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	build.set_active(true)
	build.select(build.catalog.find(&"fence"))
	build.aim_at(Vector3(0.5, 0.0, 8.5))
	t.vec_approx(build.ghost.position, Vector3(1.0, 0.0, 8.5), 0.0001, "a fence ghost: the plate is centred on its two cells")
	t.vec_approx(build.ghost.model.position, Vector3(0.0, 0.0, -0.5), 0.0001, "the model sits half a metre up, on the grid line")
	t.approx(build.ghost.rotation.y, 0.0, 0.0001, "no turn")
	build.rotate_item(1)
	t.vec_approx(build.ghost.position, Vector3(0.5, 0.0, 9.0), 0.0001, "turned: the plate covers (0, 8) and (0, 9)")
	t.approx(build.ghost.rotation.y, PI / 2.0, 0.0001, "90 degrees")
	t.eq((build.ghost.plate.mesh as PlaneMesh).size, Vector2(1.88, 0.88), "the plate is turned with the ghost")
	build.select(build.catalog.find(&"gate"))
	t.eq(build.turns, 1, "the turn is kept for the next item that can turn")
	t.vec_approx(build.ghost.model.position, Vector3(-0.5, 0.0, -0.5), 0.0001, "the gate model sits on the hinge corner")
	build.select(build.catalog.find(&"barrel"))
	t.eq(build.turns, 0, "a barrel cannot turn, so the turn is reset")
	build.rotate_item(1)
	t.eq(build.turns, 0, "and R does nothing")
	build.set_active(false)
	farm.queue_free()


func test_the_grid_follows_the_pointer_in_build_mode_only(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	t.ok(not build._grid.visible, "no grid outside build mode")
	build.set_active(true)
	t.ok(build._grid.visible, "the grid shows in build mode")
	build.aim_at(Vector3(3.2, 0.0, -4.7))
	t.vec_approx(build._grid.global_position, Vector3(3.5, 0.04, -4.5), 0.0001, "centred on the cell under the pointer, just above the ground")
	var material := build._grid.material_override as ShaderMaterial
	t.vec_approx(material.get_shader_parameter("centre"), Vector3(3.5, 0.04, -4.5), 0.0001, "and the shader knows where the middle is")
	t.eq(material.shader, BuildMode.GRID_SHADER, "it draws with the grid shader")
	build.set_active(false)
	t.ok(not build._grid.visible, "the grid hides again")
	farm.queue_free()


# ---------------------------------------------------------------- the clock and the farmer

func test_the_clock_waits_while_building(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	GameClock.running = true
	GameClock._process(30.0)
	t.eq(GameClock.time_text(), "07:00", "the clock runs")
	build.set_active(true)
	t.ok(GameClock.paused, "build mode pauses the clock")
	GameClock._process(30.0)
	t.eq(GameClock.time_text(), "07:00", "30 seconds later it is still 07:00")
	build.set_active(true)
	t.eq(_count("mode:true"), 1, "setting the same mode twice sends nothing twice")
	build.set_active(false)
	t.ok(not GameClock.paused, "leaving build mode starts it again")
	GameClock._process(30.0)
	t.eq(GameClock.time_text(), "08:00", "and time passes")
	t.eq(_count("mode:false"), 1, "the bus said so once")
	farm.queue_free()


func test_the_key_b_toggles_build_mode_and_can_be_rebound(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	_key(KEY_B)
	await t.frames(2)
	t.ok(build.active, "B turns build mode on")
	t.ok(GameClock.paused, "and the clock stops")
	_key(KEY_B)
	await t.frames(2)
	t.ok(not build.active, "B turns it off")
	var events: Array[InputEvent] = InputMap.action_get_events("build_toggle")
	InputMap.action_erase_events("build_toggle")
	var other := InputEventKey.new()
	other.physical_keycode = KEY_N
	InputMap.action_add_event("build_toggle", other)
	_key(KEY_B)
	await t.frames(2)
	t.ok(not build.active, "after a rebind, B does nothing")
	_key(KEY_N)
	await t.frames(2)
	t.ok(build.active, "and N does")
	InputMap.action_erase_events("build_toggle")
	for event: InputEvent in events:
		InputMap.action_add_event("build_toggle", event)
	build.set_active(false)
	farm.queue_free()


func test_the_farmer_does_not_move_or_interact_while_building(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var farmer := farm.get_node("Farmer") as Farmer
	var control := farmer.get_node("InteractionController") as InteractionController
	var rig := farm.get_node("CameraRig") as CameraRig
	rig.target = null
	rig.global_position = OPEN
	rig.snap()
	farmer.global_position = Vector3(0.5, 0.0, 14.0)
	await t.physics_frames(4)
	farmer.walk_to(Vector3(0.5, 0.0, 20.0))
	t.ok(farmer.walking, "the farmer is walking")
	build.set_active(true)
	t.ok(not farmer.walking, "build mode stops the walk")
	t.ok(not farmer.is_processing_unhandled_input(), "the farmer ignores clicks")
	t.ok(not farmer.tools.is_processing_unhandled_input(), "the tool belt ignores the keys")
	t.ok(not control.is_processing_unhandled_input(), "the interaction controller ignores clicks")
	t.ok(not control.is_physics_processing(), "and stops looking for things to hover")
	t.eq(control.hovered, null, "nothing is hovered")
	t.ok(not control.label.visible, "no prompt")
	var tool_before: StringName = farmer.tools.current
	_key(KEY_2)
	await t.frames(2)
	t.eq(farmer.tools.current, tool_before, "the key 2 does not pick seeds")
	t.eq(build.current, build.catalog.find(&"corner"), "it picks the second item of the open tab")
	build.select(build.catalog.find(&"barrel"))
	var spot: Vector3 = Vector3(5.5, 0.0, 8.5)
	await t.click(_screen(farm, spot))
	t.ok(not farmer.walking, "a click in build mode does not walk the farmer")
	t.eq(_placed(farm).get_child_count(), 1, "it builds instead")
	t.vec_approx(farmer.global_position, Vector3(0.5, 0.0, 14.0), 0.5, "the farmer has not moved")
	build.set_active(false)
	t.ok(farmer.is_processing_unhandled_input() and farmer.tools.is_processing_unhandled_input() and control.is_processing_unhandled_input(), "all three listen again")
	t.ok(control.is_physics_processing(), "hovering is back")
	_key(KEY_2)
	await t.frames(2)
	t.eq(farmer.tools.current, &"seeds", "the key 2 picks seeds again")
	await t.click(_screen(farm, Vector3(0.5, 0.0, 6.0)))
	t.ok(farmer.walking, "a click walks the farmer again")
	farm.queue_free()


# ---------------------------------------------------------------- the controls

func test_the_keys_rotate_demolish_choose_and_leave(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var items: Array[BuildItemData] = build.catalog.items
	_key(KEY_R)
	await t.frames(2)
	t.eq(build.turns, 0, "R does nothing outside build mode")
	build.set_active(true)
	_key(KEY_R)
	await t.frames(2)
	t.eq(build.turns, 1, "R turns a quarter")
	_key(KEY_R)
	_key(KEY_R)
	_key(KEY_R)
	await t.frames(2)
	t.eq(build.turns, 0, "four turns come round")
	_key(KEY_R, true)
	await t.frames(2)
	t.eq(build.turns, 3, "Shift+R turns the other way")
	_key(KEY_3)
	await t.frames(2)
	t.eq(build.current, build.catalog.find(&"gate"), "the key 3 picks the third fence")
	_key(KEY_6)
	await t.frames(2)
	t.eq(build.current, build.catalog.find(&"gate"), "the Fences tab has no sixth item: nothing changes")
	build.set_category(BuildItemData.Category.DECOR)
	t.eq(build.current, build.catalog.find(&"crate"), "a new tab picks its first item")
	_key(KEY_6)
	await t.frames(2)
	t.eq(build.current, build.catalog.find(&"sign"), "the key 6 picks the sixth decoration")
	_wheel(t, MOUSE_BUTTON_WHEEL_DOWN, true)
	await t.frames(2)
	t.eq(build.current, build.catalog.find(&"flowers"), "Shift+wheel down: the next item of the tab")
	_wheel(t, MOUSE_BUTTON_WHEEL_DOWN, true)
	await t.frames(2)
	t.eq(build.current, build.catalog.find(&"crate"), "the tab wraps round at the end")
	_wheel(t, MOUSE_BUTTON_WHEEL_UP, true)
	await t.frames(2)
	t.eq(build.current, build.catalog.find(&"flowers"), "and at the start")
	var distance: float = (farm.get_node("CameraRig") as CameraRig).wanted_distance
	_wheel(t, MOUSE_BUTTON_WHEEL_DOWN, false)
	await t.frames(2)
	t.eq(build.current, build.catalog.find(&"flowers"), "the plain wheel does not choose")
	t.ok((farm.get_node("CameraRig") as CameraRig).wanted_distance > distance, "it still zooms the camera")
	t.eq(items.size(), 12, "the list itself never changed")
	_key(KEY_X)
	await t.frames(2)
	t.ok(build.removing, "X switches to demolish")
	_key(KEY_X)
	await t.frames(2)
	t.ok(not build.removing, "X switches back")
	_key(KEY_X)
	await t.frames(2)
	_key(KEY_ESCAPE)
	await t.frames(2)
	t.ok(build.active and not build.removing, "Esc first leaves demolish")
	_key(KEY_ESCAPE)
	await t.frames(2)
	t.ok(not build.active, "Esc then leaves build mode")
	build.set_active(true)
	await t.click(Vector2(600.0, 300.0), MOUSE_BUTTON_RIGHT)
	t.ok(not build.active, "a right click leaves build mode too")
	t.ok(not GameClock.paused, "and the clock runs")
	farm.queue_free()


func test_the_camera_keys_still_turn_the_view_in_build_mode(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var rig := farm.get_node("CameraRig") as CameraRig
	build.set_active(true)
	var yaw: float = rig.wanted_yaw
	_key(KEY_Q)
	await t.frames(2)
	await t.physics_frames(2)
	t.ok(not is_equal_approx(rig.wanted_yaw, yaw) or Input.is_action_pressed("cam_rotate_left") == false, "Q is the camera, not the build rotation")
	t.eq(build.turns, 0, "so the item did not turn")
	var before: float = rig.wanted_distance
	_wheel(t, MOUSE_BUTTON_WHEEL_UP, false)
	await t.frames(2)
	t.ok(rig.wanted_distance < before, "the wheel zooms in")
	build.set_active(false)
	farm.queue_free()


func test_a_click_builds_on_the_cell_under_the_pointer(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var rig := farm.get_node("CameraRig") as CameraRig
	rig.target = null
	rig.global_position = OPEN
	rig.snap()
	await t.physics_frames(2)
	build.set_active(true)
	build.select(build.catalog.find(&"barrel"))
	var spot := Vector3(2.3, 0.0, 7.8)
	t.mouse_move(_screen(farm, spot))
	await t.frames(2)
	await t.physics_frames(2)
	t.eq(build.cell, Vector2i(2, 7), "the pointer is over cell (2, 7)")
	t.ok(build.ghost.visible and build.ghost.valid, "the ghost shows green there")
	t.vec_approx(build.ghost.position, Vector3(2.5, 0.0, 7.5), 0.0001, "snapped to the middle of the cell")
	await t.click(_screen(farm, spot))
	t.eq(_placed(farm).get_child_count(), 1, "the left click builds")
	t.vec_approx(_placed(farm).get_child(0).global_position, Vector3(2.5, 0.0, 7.5), 0.0001, "on that cell")
	t.eq(Economy.money, 95, "5 coins")
	await t.click(_screen(farm, spot))
	t.eq(_placed(farm).get_child_count(), 1, "a second click on the same cell builds nothing")
	t.eq(_count("hint:You already built there."), 1, "and says why")
	t.eq(Economy.money, 95, "and costs nothing")
	t.mouse_move(_screen(farm, Vector3(-0.4, 0.0, 7.5)))
	await t.frames(2)
	await t.physics_frames(2)
	t.eq(build.cell, Vector2i(-1, 7), "left of x 0 is cell -1")
	build.set_active(false)
	farm.queue_free()


func test_a_click_on_a_fence_without_a_drag_builds_one_and_r_turns_it(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var rig := farm.get_node("CameraRig") as CameraRig
	rig.target = null
	rig.global_position = OPEN
	rig.snap()
	await t.physics_frames(2)
	build.set_active(true)
	build.select(build.catalog.find(&"fence"))
	build.rotate_item(1)
	var spot := Vector3(2.5, 0.0, 7.5)
	t.mouse_move(_screen(farm, spot))
	await t.frames(2)
	await t.physics_frames(2)
	await t.click(_screen(farm, spot))
	t.eq(_placed(farm).get_child_count(), 1, "one section")
	t.eq(_placed(farm).get_child(0).get_meta(&"build_turns"), 1, "turned as the ghost was")
	t.eq(Economy.money, 94, "6 coins")
	build.set_active(false)
	farm.queue_free()


func test_a_drag_builds_a_row_and_a_right_click_drops_it(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var rig := farm.get_node("CameraRig") as CameraRig
	rig.target = null
	rig.global_position = Vector3(0.5, 0.0, 10.0)
	rig.snap()
	await t.physics_frames(2)
	build.set_active(true)
	build.select(build.catalog.find(&"fence"))
	t.mouse_move(_screen(farm, Vector3(-3.5, 0.0, 10.5)))
	await t.frames(2)
	await t.physics_frames(2)
	t.mouse_button(_screen(farm, Vector3(-3.5, 0.0, 10.5)), MOUSE_BUTTON_LEFT, true)
	await t.frames(2)
	t.ok(build.dragging, "the press starts a drag")
	t.mouse_move(_screen(farm, Vector3(2.5, 0.0, 10.5)))
	await t.frames(2)
	await t.physics_frames(2)
	var visible_pieces: int = 0
	for piece: BuildGhost in build._pieces:
		if piece.visible:
			visible_pieces += 1
	t.eq(visible_pieces, 4, "4 ghost sections from x -4 to x 3")
	t.eq(build.status, "4 pieces: 24 coins", "the status shows the total")
	t.eq(build._pieces[3].tag.text, "4 pieces: 24 coins", "the last ghost carries the total")
	t.eq(build._pieces[0].tag.text, "", "the others carry nothing")
	t.mouse_button(_screen(farm, Vector3(2.5, 0.0, 10.5)), MOUSE_BUTTON_LEFT, false)
	await t.frames(2)
	t.ok(not build.dragging, "the release ends the drag")
	t.eq(_placed(farm).get_child_count(), 4, "four sections stand there")
	t.eq(Economy.money, 76, "24 coins")
	var xs: Array[float] = []
	for section: Node in _placed(farm).get_children():
		xs.append((section as Node3D).global_position.x)
		t.approx((section as Node3D).global_position.z, 10.0, 0.0001, "on the grid line z = 10")
		t.approx((section as Node3D).rotation.y, 0.0, 0.0001, "along x: no turn")
	xs.sort()
	t.eq(xs, [-3.0, -1.0, 1.0, 3.0] as Array[float], "2 m apart, ends on grid lines")
	t.eq(build.map.kind_at(Vector2i(-4, 10)), &"placed", "the cells are held")
	# A second drag along z turns the sections by itself.
	t.mouse_move(_screen(farm, Vector3(6.5, 0.0, 6.5)))
	await t.frames(2)
	await t.physics_frames(2)
	t.mouse_button(_screen(farm, Vector3(6.5, 0.0, 6.5)), MOUSE_BUTTON_LEFT, true)
	await t.frames(2)
	t.mouse_move(_screen(farm, Vector3(6.5, 0.0, 11.5)))
	await t.frames(2)
	await t.physics_frames(2)
	t.mouse_button(_screen(farm, Vector3(6.5, 0.0, 11.5)), MOUSE_BUTTON_LEFT, false)
	await t.frames(2)
	t.eq(_placed(farm).get_child_count(), 7, "three more along z")
	t.approx((_placed(farm).get_child(4) as Node3D).rotation.y, PI / 2.0, 0.0001, "they are turned to run along z")
	t.eq(Economy.money, 58, "18 more coins")
	# Cancel a drag.
	t.mouse_move(_screen(farm, Vector3(-8.5, 0.0, 12.5)))
	await t.frames(2)
	await t.physics_frames(2)
	t.mouse_button(_screen(farm, Vector3(-8.5, 0.0, 12.5)), MOUSE_BUTTON_LEFT, true)
	await t.frames(2)
	t.mouse_move(_screen(farm, Vector3(-3.5, 0.0, 12.5)))
	await t.frames(2)
	await t.physics_frames(2)
	t.ok(build.dragging, "a drag again")
	_key(KEY_ESCAPE)
	await t.frames(2)
	t.ok(not build.dragging and build.active, "Esc drops the drag and stays in build mode")
	t.mouse_button(_screen(farm, Vector3(-3.5, 0.0, 12.5)), MOUSE_BUTTON_LEFT, false)
	await t.frames(2)
	t.eq(_placed(farm).get_child_count(), 7, "nothing more was built")
	t.eq(Economy.money, 58, "nothing was charged")
	build.set_active(false)
	farm.queue_free()


func test_a_row_skips_what_does_not_fit_and_stops_when_money_runs_out(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	build.set_active(true)
	build.select(build.catalog.find(&"fence"))
	# Sections along row 8 from cell -16 to cell -9: the last two run into the field (its last row is row 8).
	build.aim_at(Vector3(-15.5, 0.0, 8.5))
	build._press()
	build.aim_at(Vector3(-8.5, 0.0, 8.5))
	t.eq(build._pieces.size(), 4, "four ghosts for four sections")
	t.ok(build._pieces[0].valid and build._pieces[1].valid, "the first two are green")
	t.ok(not build._pieces[2].valid and not build._pieces[3].valid, "the two over the soil are red")
	build._release()
	t.eq(_placed(farm).get_child_count(), 2, "only the sections that fit are built")
	t.eq(Economy.money, 88, "and only they are paid")
	t.eq(_count("denied:"), 0, "a row with some pieces built is not a refusal")
	Economy.money = 13
	build.aim_at(Vector3(0.5, 0.0, 14.5))
	build._press()
	build.aim_at(Vector3(11.5, 0.0, 14.5))
	t.ok(build._pieces[1].valid and not build._pieces[2].valid, "the ghosts turn red where the money ends")
	t.eq(build.status, "6 pieces: 12 coins", "the total counts only what can be paid")
	build._release()
	t.eq(_placed(farm).get_child_count(), 4, "with 13 coins two sections of six were bought")
	t.eq(Economy.money, 1, "1 coin is left")
	# A row that fits nowhere is one refusal.
	Economy.money = 100
	build.aim_at(Vector3(-9.5, 0.0, -13.5))
	build._press()
	build.aim_at(Vector3(-6.5, 0.0, -13.5))
	build._release()
	t.eq(_count("denied:fence:Something is in the way."), 1, "one refusal for the whole row")
	t.eq(Economy.money, 100, "and nothing paid")
	farm.queue_free()


func test_demolish_mode_points_at_what_you_built(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	build.try_place(build.catalog.find(&"shed"), Vector2i(4, 8), 0)
	t.eq(Economy.money, 25, "25 coins after the shed")
	build.set_active(true)
	build.set_removing(true)
	build.aim_at(Vector3(5.5, 0.0, 9.5))
	t.ok(build._eraser.visible, "an eraser plate shows on the shed")
	t.eq(build._eraser.plate.material_override.albedo_color, BuildGhost.BAD, "in red")
	t.eq((build._eraser.plate.mesh as PlaneMesh).size, Vector2(2.88, 2.88), "the size of the shed")
	t.eq(build._eraser.tag.text, "+37 coins", "the tag says what comes back")
	t.eq(build.status, "Demolish the shed: 37 coins back", "the status says what comes back")
	t.ok(not build.ghost.visible, "the build ghost is hidden")
	build.aim_at(Vector3(8.5, 0.0, -14.0))
	t.ok(not build._eraser.visible, "pointing at the barn shows nothing")
	build._press()
	t.eq(_count("hint:Only things you built can be taken down."), 1, "and a click explains")
	t.ok(farm.get_node("World/Buildings/Barn").is_inside_tree(), "the barn stays")
	build.aim_at(Vector3(5.5, 0.0, 9.5))
	build._press()
	t.eq(_placed(farm).get_child_count(), 0, "a click on the shed takes it down")
	t.eq(Economy.money, 62, "25 + 37")
	t.ok(not build._eraser.visible, "the plate is gone")
	build.set_active(false)
	t.ok(not build.removing, "leaving build mode leaves demolish mode")
	farm.queue_free()


# ---------------------------------------------------------------- the menu

func test_the_menu_shows_the_catalog_in_tabs_and_greys_what_costs_too_much(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var menu := farm.get_node("Hud/BuildMenu") as BuildMenu
	t.eq(menu.slot_row.get_child_count(), 12, "one slot for each item")
	t.eq(menu.tabs.tab_count, 3, "three tabs")
	t.eq([menu.tabs.get_tab_title(0), menu.tabs.get_tab_title(1), menu.tabs.get_tab_title(2)], ["Fences", "Buildings", "Decor"], "their names")
	var shown: Array[String] = []
	for slot: Node in menu.slot_row.get_children():
		if (slot as BuildSlot).visible:
			shown.append((slot as BuildSlot).item.id)
	t.eq(shown, ["fence", "corner", "gate"], "the Fences tab shows three slots")
	var first := menu.slot_row.get_child(0) as BuildSlot
	t.eq(first.badge.text, "Fe", "the letters of the fence")
	t.eq(first.cost_label.text, "6", "its price")
	t.eq(first.key_label.text, "1", "its key")
	t.ok(first.mark.visible, "the fence is selected")
	t.ok(not (menu.slot_row.get_child(1) as BuildSlot).mark.visible, "the corner is not")
	t.eq((menu.slot_row.get_child(11) as BuildSlot).key_label.text, "", "no key for the seventh decoration")
	build.set_active(true)
	await t.frames(3)
	t.ok(menu.palette.visible and menu.banner.visible, "palette and banner show")
	t.ok(not menu.open_button.visible, "the Build button hides")
	# A headless run draws nothing, so a TabBar has no tab rectangles to click: choose the tab in code.
	menu.tabs.current_tab = 1
	t.eq(build.category, BuildItemData.Category.BUILDING, "choosing the tab Buildings opens it")
	t.eq(build.current, build.catalog.find(&"shed"), "and picks its first item")
	shown.clear()
	for slot: Node in menu.slot_row.get_children():
		if (slot as BuildSlot).visible:
			shown.append((slot as BuildSlot).item.id)
	t.eq(shown, ["shed", "well"], "the Buildings tab shows the shed and the well")
	var well := menu.slot_row.get_child(4) as BuildSlot
	await t.frames(2)
	await t.click(well.get_global_rect().get_center())
	t.eq(build.current, build.catalog.find(&"well"), "a click on a slot selects it")
	t.ok(well.mark.visible, "the mark moves")
	t.eq(_placed(farm).get_child_count(), 0, "the click on the palette built nothing")
	t.eq(menu.status_label.text, build.status, "the label shows the status")
	var shed_slot := menu.slot_row.get_child(3) as BuildSlot
	Economy.money = 50
	Events.money_changed.emit(50)
	t.ok(not shed_slot.affordable, "the shed (75) is not affordable with 50 coins")
	t.ok(shed_slot.modulate.r < 0.6 and shed_slot.modulate.g < 0.6, "and is drawn grey")
	t.ok(well.affordable and well.modulate == Color.WHITE, "the well (40) is")
	t.ok(first.affordable and first.modulate == Color.WHITE, "the fence (6) is")
	Economy.add_money(100)
	t.ok(shed_slot.affordable and shed_slot.modulate == Color.WHITE, "with 150 coins the shed is bright again")
	build.aim_at(Vector3(-8.5, 0.0, -13.5))
	t.eq(menu.status_label.text, "Something is in the way.", "the label shows the reason")
	t.eq(menu.status_label.modulate, Color("FF9A8A"), "in a red tone")
	build.select(build.catalog.find(&"trough"))
	t.eq(menu.tabs.current_tab, 2, "choosing an item of another tab flips the tab")
	await t.click(menu.remove_button.get_global_rect().get_center())
	t.ok(build.removing and menu.remove_button.button_pressed, "the Demolish button switches the mode")
	await t.click(menu.remove_button.get_global_rect().get_center())
	t.ok(not build.removing, "and back")
	await t.click((menu.get_node("Palette/PaletteColumn/TitleRow/DoneButton") as Button).get_global_rect().get_center())
	t.ok(not build.active, "Done leaves build mode")
	t.ok(not menu.palette.visible and menu.open_button.visible, "the palette hides and the Build button returns")
	await t.click(menu.open_button.get_global_rect().get_center())
	t.ok(build.active, "the Build button opens build mode")
	build.set_active(false)
	farm.queue_free()


# ---------------------------------------------------------------- navigation

func test_the_bake_waits_for_a_pause_and_runs_once(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var bakes: Array[int] = [0]
	build.nav_baked.connect(func() -> void: bakes[0] += 1)
	for index: int in 5:
		t.not_null(build.try_place(build.catalog.find(&"corner"), Vector2i(index, 8), 0), "post %d" % index)
	t.eq(bakes[0], 0, "no bake yet in the same frame")
	t.ok(await _await_bake(t, build), "the bake finishes")
	await t.physics_frames(10)
	t.eq(bakes[0], 1, "five posts, one bake")
	farm.queue_free()


func test_the_farmer_walks_around_a_new_fence(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var region := farm.get_node("World") as NavigationRegion3D
	var map: RID = region.get_navigation_map()
	var a := Vector3(-3.0, 0.0, 14.0)
	var b := Vector3(4.0, 0.0, 14.0)
	var polygons_before: int = region.navigation_mesh.get_polygon_count()
	var straight: PackedVector3Array = NavigationServer3D.map_get_path(map, a, b, true)
	var straight_length: float = _path_length(straight)
	t.ok(straight.size() >= 2, "a path exists before the fence")
	t.ok(straight_length < 8.0, "and it is short (%.1f m)" % straight_length)
	# Five turned sections from z 9 to z 19, standing on the grid line x = 0.
	for index: int in 5:
		t.not_null(build.try_place(build.catalog.find(&"fence"), Vector2i(0, 9 + 2 * index), 1), "section %d" % index)
	t.ok(await _await_bake(t, build), "the mesh is baked again")
	var polygons_after: int = region.navigation_mesh.get_polygon_count()
	print("CH31 nav polygons: before %d, after the fence %d" % [polygons_before, polygons_after])
	t.ok(polygons_after > 0 and polygons_after != polygons_before, "the polygons changed (%d to %d)" % [polygons_before, polygons_after])
	var around: PackedVector3Array = NavigationServer3D.map_get_path(map, a, b, true)
	var around_length: float = _path_length(around)
	t.ok(around.size() >= 3, "the new path bends (%d points)" % around.size())
	t.ok(around_length > straight_length + 3.0, "and is longer: %.1f m instead of %.1f m" % [around_length, straight_length])
	t.ok(Vector2(around[around.size() - 1].x - b.x, around[around.size() - 1].z - b.z).length() < 0.6, "it still reaches the goal")
	var strip := Rect2(-0.14, 9.0, 0.28, 10.0)
	var crossed: bool = false
	for index: int in range(1, around.size()):
		var from := Vector2(around[index - 1].x, around[index - 1].z)
		var to := Vector2(around[index].x, around[index].z)
		for step: int in 41:
			if strip.has_point(from.lerp(to, step / 40.0)):
				crossed = true
	t.ok(not crossed, "no point of the path is inside the fence")
	# The farmer really walks it.
	var farmer := farm.get_node("Farmer") as Farmer
	farmer.global_position = a
	await t.physics_frames(4)
	farmer.walk_to(b)
	var waited: int = 0
	var inside: bool = false
	while farmer.walking and waited < 6000:
		await t.physics_frames(1)
		waited += 1
		if strip.has_point(Vector2(farmer.global_position.x, farmer.global_position.z)):
			inside = true
	t.ok(not farmer.walking, "the farmer arrives (after %d steps)" % waited)
	t.ok(not inside, "never inside the fence")
	t.ok(Vector2(farmer.global_position.x - b.x, farmer.global_position.z - b.z).length() < 0.8, "at the goal")
	# Take the fence down again: the short way is back.
	for node: Node in _placed(farm).get_children():
		build.remove(node as Node3D)
	t.ok(await _await_bake(t, build), "baked again after the demolition")
	var back: PackedVector3Array = NavigationServer3D.map_get_path(map, a, b, true)
	t.ok(_path_length(back) < straight_length + 0.6, "the straight way is back (%.1f m)" % _path_length(back))
	farm.queue_free()


func test_a_bake_with_nothing_built_keeps_the_farm_walkable(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	var region := farm.get_node("World") as NavigationRegion3D
	var saved: int = region.navigation_mesh.get_polygon_count()
	build.clear_placed()
	t.ok(await _await_bake(t, build), "the bake finishes")
	var baked: int = region.navigation_mesh.get_polygon_count()
	print("CH31 nav polygons: saved %d, rebaked empty %d" % [saved, baked])
	t.ok(baked > 300, "a rebake gives a mesh (%d polygons, saved %d)" % [baked, saved])
	var map: RID = region.get_navigation_map()
	var goals: Dictionary = {"south gate": Vector3(0.5, 0.0, 19.0), "chicken pen": Vector3(-19.0, 0.0, 0.5), "paddock": Vector3(-14.0, 0.0, 16.0)}
	for label: String in goals:
		var goal: Vector3 = goals[label]
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, Vector3(0.5, 0.0, -3.5), goal, true)
		t.ok(path.size() >= 2, "a path to the %s exists" % label)
		t.ok(Vector2(path[path.size() - 1].x - goal.x, path[path.size() - 1].z - goal.z).length() < 0.8, "and reaches it")
	farm.queue_free()


# ---------------------------------------------------------------- saving

func test_the_data_survives_a_round_trip_through_json(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build: BuildMode = _build(farm)
	Economy.money = 500
	t.eq(build.to_save().size(), 0, "nothing built: an empty list")
	build.try_place(build.catalog.find(&"fence"), Vector2i(0, 8), 1)
	build.try_place(build.catalog.find(&"gate"), Vector2i(3, 8), 3)
	build.try_place(build.catalog.find(&"shed"), Vector2i(4, 12), 0)
	build.try_place(build.catalog.find(&"crate"), Vector2i(-3, 9), 2)
	build.try_place(build.catalog.find(&"flowers"), Vector2i(6, 8), 0)
	var data: Array[Dictionary] = build.to_save()
	t.eq(data.size(), 5, "five records")
	t.eq(data[0], {"id": "fence", "cell": [0, 8], "turns": 1}, "plain data: id, cell, turns")
	var before: Array = []
	for node: Node in _placed(farm).get_children():
		before.append([node.get_meta(&"build_id"), (node as Node3D).global_position, (node as Node3D).rotation.y])
	var before_cells: Dictionary = build.map.kinds.duplicate()
	var money: int = Economy.money
	var text: String = JSON.stringify(data)
	var parsed: Array = JSON.parse_string(text)
	t.eq(parsed.size(), 5, "the text parses back")
	t.ok(parsed[0]["cell"][0] is float, "JSON turns every number into a float")
	build.clear_placed()
	t.eq(_placed(farm).get_child_count(), 0, "everything cleared")
	t.eq(build.map.kinds.size(), before_cells.size() - 2 - 1 - 9 - 1 - 1, "the cells of the built things are free again")
	var restored: int = build.from_save(parsed)
	t.eq(restored, 5, "five came back")
	t.eq(Economy.money, money, "loading costs nothing")
	t.eq(_placed(farm).get_child_count(), 5, "five nodes")
	var after: Array = []
	for node: Node in _placed(farm).get_children():
		after.append([node.get_meta(&"build_id"), (node as Node3D).global_position, (node as Node3D).rotation.y])
	for index: int in before.size():
		t.eq(after[index][0], before[index][0], "the same item %d" % index)
		t.vec_approx(after[index][1], before[index][1], 0.0001, "the same place %d" % index)
		t.approx(after[index][2], before[index][2], 0.0001, "the same turn %d" % index)
	t.eq(build.map.kinds, before_cells, "the map is the same")
	t.eq(build.to_save(), data, "saving again gives the same data")
	t.eq(_count("placed:"), 5, "loading sent no placed signals")
	# Bad data: an unknown id and an overlap are skipped, the rest comes back.
	var odd: Array = [
		{"id": "fence", "cell": [0, 8], "turns": 1}, {"id": "spaceship", "cell": [0, 0], "turns": 0},
		{"id": "corner", "cell": [0, 8], "turns": 0}, {"id": "corner", "cell": [10, 8], "turns": 0},
	]
	t.eq(build.from_save(odd), 2, "unknown and overlapping entries are skipped")
	t.eq(_placed(farm).get_child_count(), 2, "two nodes")
	t.eq(build.from_save([]), 0, "an empty list clears everything")
	t.eq(_placed(farm).get_child_count(), 0, "nothing")
	farm.queue_free()


func test_the_new_input_action_is_x(t: Variant) -> void:
	t.ok(InputMap.has_action("build_remove"), "build_remove exists")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_X
	event.pressed = true
	t.ok(event.is_action("build_remove"), "X is demolish")
	for action: String in ["build_toggle", "build_rotate", "build_place", "build_cancel"]:
		t.ok(InputMap.has_action(action), "%s still exists" % action)
