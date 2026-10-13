class_name BuildMode
extends Node

signal item_changed(item: BuildItemData)
signal category_changed(category: BuildItemData.Category)
signal removing_changed(removing: bool)
signal status_changed(text: String, fits: bool)
signal nav_baked

const GROUND_MASK: int = 1
const RAY_LENGTH: float = 200.0
const GRID_SHADER: Shader = preload("res://resources/buildables/grid_lines.gdshader")

@export var catalog: BuildCatalog
@export var farmer: Farmer
@export var world: NavigationRegion3D
@export var placed_root: Node3D
@export var bake_delay: float = 0.4

var active: bool = false
var removing: bool = false
var current: BuildItemData
var category: BuildItemData.Category = BuildItemData.Category.FENCE
var turns: int = 0
var cell: Vector2i = Vector2i.ZERO
var dragging: bool = false
var map: BuildMap = BuildMap.new()
var ghost: BuildGhost
var status: String = ""

var _drag_start: Vector2i
var _pieces: Array[BuildGhost] = []
var _eraser: BuildGhost
var _grid: MeshInstance3D
var _mouse: Vector2 = Vector2(-1.0, -1.0)
var _count: int = 0
var _bake_timer: Timer
var _interaction: InteractionController


func _ready() -> void:
	map.scan_world(world, placed_root)
	_interaction = farmer.get_node("InteractionController") as InteractionController
	_eraser = BuildGhost.create(null)
	_grid = MeshInstance3D.new()
	_grid.mesh = QuadMesh.new()
	(_grid.mesh as QuadMesh).size = Vector2(16.0, 16.0)
	(_grid.mesh as QuadMesh).orientation = PlaneMesh.FACE_Y
	_grid.material_override = ShaderMaterial.new()
	(_grid.material_override as ShaderMaterial).shader = GRID_SHADER
	_bake_timer = Timer.new()
	_bake_timer.one_shot = true
	_bake_timer.timeout.connect(_bake)
	for node: Node in [_eraser, _grid, _bake_timer]:
		add_child(node)
	if not catalog.items.is_empty():
		select(catalog.items[0])


func set_active(on: bool) -> void:
	if on == active:
		return
	if on and not get_tree().get_nodes_in_group(&"modal").is_empty():
		return
	active = on
	GameClock.paused = on
	_lock_farmer(on)
	if not on:
		dragging = false
		removing = false
	_refresh()
	Events.build_mode_changed.emit(on)


func select(item: BuildItemData) -> void:
	dragging = false
	set_removing(false)
	current = item
	if not item.rotatable:
		turns = 0
	if ghost != null:
		ghost.queue_free()
	for piece: BuildGhost in _pieces:
		piece.queue_free()
	_pieces.clear()
	ghost = BuildGhost.create(item)
	add_child(ghost)
	if item.category != category:
		category = item.category
		category_changed.emit(category)
	item_changed.emit(item)
	_refresh()


func select_number(number: int) -> void:
	var items: Array[BuildItemData] = catalog.in_category(category)
	if number >= 1 and number <= items.size():
		select(items[number - 1])


func set_category(new_category: BuildItemData.Category) -> void:
	var items: Array[BuildItemData] = catalog.in_category(new_category)
	if new_category != category and not items.is_empty():
		select(items[0])


func step_item(step: int) -> void:
	var items: Array[BuildItemData] = catalog.in_category(category)
	select(items[posmod(items.find(current) + step, items.size())])


func rotate_item(step: int) -> void:
	if current.rotatable:
		turns = posmod(turns + step, 4)
		_refresh()


func set_removing(on: bool) -> void:
	if on != removing:
		removing = on
		dragging = false
		removing_changed.emit(on)
		_refresh()


func cancel() -> void:
	if dragging:
		dragging = false
		_refresh()
	elif removing:
		set_removing(false)
	else:
		set_active(false)


func aim_at(point: Vector3) -> void:
	cell = BuildGrid.cell_of(point)
	_refresh()


func fit_problem(item: BuildItemData, lowest: Vector2i, quarter_turns: int) -> String:
	var cells: Array[Vector2i] = BuildGrid.cells_for(lowest, BuildGrid.turned(item.footprint, quarter_turns))
	var problem: String = map.problem_for(cells)
	if problem == "" and cells.has(BuildGrid.cell_of(farmer.global_position)):
		problem = "The farmer is in the way."
	for animal: Node in get_tree().get_nodes_in_group(&"animals"):
		if problem == "" and cells.has(BuildGrid.cell_of((animal as Node3D).global_position)):
			problem = "An animal is in the way."
	return problem


func problem_for(item: BuildItemData, lowest: Vector2i, quarter_turns: int) -> String:
	if not item.unlocked:
		return "You need the plan for the %s. The stall sells it." % item.display_name.to_lower()
	var problem: String = fit_problem(item, lowest, quarter_turns)
	if problem == "" and Economy.money < item.cost:
		problem = "Not enough coins: the %s costs %d." % [item.display_name.to_lower(), item.cost]
	return problem


func try_place(item: BuildItemData, lowest: Vector2i, quarter_turns: int) -> Node3D:
	var problem: String = problem_for(item, lowest, quarter_turns)
	if problem != "":
		_deny(item, problem)
		return null
	return _place(item, lowest, quarter_turns)


func remove(node: Node3D) -> bool:
	if not is_instance_valid(node) or not node.is_in_group(&"placed"):
		return false
	var item: BuildItemData = catalog.find(node.get_meta(&"build_id"))
	map.release(_cells_of(node))
	var spot: Vector3 = node.global_position
	placed_root.remove_child(node)
	node.queue_free()
	Economy.add_money(item.refund(), "Took down the %s" % item.display_name.to_lower())
	Fx.spawn(self, &"dust", spot)
	Events.build_removed.emit(item, item.refund())
	_request_bake()
	_refresh()
	return true


func save_key() -> String:
	return "build"


func to_save() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for node: Node in placed_root.get_children():
		var lowest: Vector2i = node.get_meta(&"build_cell")
		data.append({"id": String(node.get_meta(&"build_id")), "cell": [lowest.x, lowest.y], "turns": node.get_meta(&"build_turns")})
	return data


func from_save(data: Array) -> int:
	clear_placed()
	var restored: int = 0
	for entry: Variant in data:
		if not (entry is Dictionary and entry.has_all(["id", "cell", "turns"])):
			continue
		var item: BuildItemData = catalog.find(StringName(entry["id"]))
		var lowest := Vector2i(int(entry["cell"][0]), int(entry["cell"][1]))
		if item != null and fit_problem(item, lowest, int(entry["turns"])) == "":
			_build(item, lowest, int(entry["turns"]), false)
			restored += 1
	return restored


func clear_placed() -> void:
	for node: Node in placed_root.get_children():
		map.release(_cells_of(node as Node3D))
		placed_root.remove_child(node)
		node.queue_free()
	_request_bake()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_toggle"):
		set_active(not active)
	elif not active:
		return
	elif event.is_action_pressed("build_rotate"):
		rotate_item(-1 if (event as InputEventWithModifiers).shift_pressed else 1)
	elif event.is_action_pressed("build_remove"):
		set_removing(not removing)
	elif event.is_action_pressed("build_place"):
		_press()
	elif event.is_action_released("build_place"):
		_release()
	elif event.is_action_pressed("build_cancel") or event.is_action_pressed("ui_cancel"):
		cancel()
	elif event.is_action_pressed("tool_next"):
		step_item(1)
	elif event.is_action_pressed("tool_prev"):
		step_item(-1)
	elif not _pick_by_number(event):
		return
	get_viewport().set_input_as_handled()


func _pick_by_number(event: InputEvent) -> bool:
	for number: int in range(1, 7):
		if event.is_action_pressed("tool_%d" % number):
			select_number(number)
			return true
	return false


func _input(event: InputEvent) -> void:
	if active and event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position


func _physics_process(_delta: float) -> void:
	if not active or _mouse.x < 0.0:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	var from: Vector3 = camera.project_ray_origin(_mouse)
	var to: Vector3 = from + camera.project_ray_normal(_mouse) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, GROUND_MASK)
	var hit: Dictionary = farmer.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("position") and BuildGrid.cell_of(hit["position"]) != cell:
		aim_at(hit["position"])


func _press() -> void:
	if removing:
		var target: Node3D = map.owners.get(cell)
		if target == null:
			Events.hint_shown.emit("Only things you built can be taken down.")
		else:
			remove(target)
	elif current.line:
		dragging = true
		_drag_start = cell
		_refresh()
	else:
		try_place(current, _lowest(cell, turns), turns)


func _release() -> void:
	if not dragging:
		return
	dragging = false
	var row_turns: int = _row_turns()
	var built: int = 0
	var first_problem: String = ""
	for anchor: Vector2i in BuildGrid.line_anchors(_drag_start, cell, current.footprint.x):
		var lowest: Vector2i = _lowest(anchor, row_turns)
		var problem: String = problem_for(current, lowest, row_turns)
		if problem == "":
			_place(current, lowest, row_turns)
			built += 1
		elif first_problem == "":
			first_problem = problem
	if built == 0:
		_deny(current, first_problem)
	_refresh()


func _row_turns() -> int:
	return turns if _drag_start == cell else BuildGrid.line_turns(_drag_start, cell)


func _deny(item: BuildItemData, problem: String) -> void:
	Events.hint_shown.emit(problem)
	Events.build_denied.emit(item, problem)


func _lowest(anchor: Vector2i, quarter_turns: int) -> Vector2i:
	return BuildGrid.lowest_cell(anchor, BuildGrid.turned(current.footprint, quarter_turns))


func _refresh() -> void:
	if ghost == null:
		return
	ghost.visible = false
	_eraser.visible = false
	_grid.visible = active
	for piece: BuildGhost in _pieces:
		piece.visible = false
	if not active:
		return
	_grid.global_position = Vector3(cell.x + 0.5, 0.04, cell.y + 0.5)
	(_grid.material_override as ShaderMaterial).set_shader_parameter("centre", _grid.global_position)
	if removing:
		_show_eraser()
	elif dragging:
		_show_row()
	else:
		var problem: String = problem_for(current, _lowest(cell, turns), turns)
		_show(ghost, _lowest(cell, turns), turns, problem, "%d coins" % current.cost)
		_say(problem, "%s: %d coins" % [current.display_name, current.cost])


func _show(piece: BuildGhost, lowest: Vector2i, quarter_turns: int, problem: String, text: String) -> void:
	piece.visible = true
	piece.place_on_grid(lowest, BuildGrid.turned(current.footprint, quarter_turns), quarter_turns)
	piece.set_valid(problem == "", text)


func _show_row() -> void:
	var row_turns: int = _row_turns()
	var cells: Array[Vector2i] = BuildGrid.line_anchors(_drag_start, cell, current.footprint.x)
	while _pieces.size() < cells.size():
		_pieces.append(BuildGhost.create(current))
		add_child(_pieces[-1])
	var purse: int = Economy.money
	var total: int = 0
	for index: int in cells.size():
		var lowest: Vector2i = _lowest(cells[index], row_turns)
		var problem: String = fit_problem(current, lowest, row_turns)
		if problem == "" and purse < current.cost:
			problem = "Not enough coins."
		if problem == "":
			purse -= current.cost
			total += current.cost
		var last: bool = index == cells.size() - 1
		_show(_pieces[index], lowest, row_turns, problem, "%d pieces: %d coins" % [cells.size(), total] if last else "")
	_say("", "%d pieces: %d coins" % [cells.size(), total])


func _show_eraser() -> void:
	var target: Node3D = map.owners.get(cell)
	_eraser.visible = target != null
	if target == null:
		_say("Point at something you built.", "")
		return
	var item: BuildItemData = catalog.find(target.get_meta(&"build_id"))
	var size: Vector2i = BuildGrid.turned(item.footprint, target.get_meta(&"build_turns"))
	_eraser.place_on_grid(target.get_meta(&"build_cell"), size, 0)
	_eraser.set_plate_size(Vector2(size))
	_eraser.set_valid(false, "+%d coins" % item.refund())
	_say("", "Demolish the %s: %d coins back" % [item.display_name.to_lower(), item.refund()])


func _say(problem: String, text: String) -> void:
	status = problem if problem != "" else text
	status_changed.emit(status, problem == "")


func _place(item: BuildItemData, lowest: Vector2i, quarter_turns: int) -> Node3D:
	Economy.spend(item.cost, "Built the %s" % item.display_name.to_lower())
	return _build(item, lowest, quarter_turns, true)


func _build(item: BuildItemData, lowest: Vector2i, quarter_turns: int, with_effect: bool) -> Node3D:
	var node: Node3D = item.scene.instantiate()
	_count += 1
	node.name = "%s_%d" % [item.id, _count]
	placed_root.add_child(node)
	node.global_transform = Transform3D(Basis(Vector3.UP, BuildGrid.yaw(quarter_turns)), BuildGrid.origin_for(item, lowest, quarter_turns))
	node.add_to_group(&"placed")
	node.set_meta(&"build_id", item.id)
	node.set_meta(&"build_cell", lowest)
	node.set_meta(&"build_turns", quarter_turns)
	map.reserve(_cells_of(node), &"placed", node)
	if with_effect:
		Fx.spawn(self, &"dust", node.global_position)
		Events.build_placed.emit(item, node)
	_request_bake()
	_refresh()
	return node


func _cells_of(node: Node3D) -> Array[Vector2i]:
	var item: BuildItemData = catalog.find(node.get_meta(&"build_id"))
	return BuildGrid.cells_for(node.get_meta(&"build_cell"), BuildGrid.turned(item.footprint, node.get_meta(&"build_turns")))


func _lock_farmer(locked: bool) -> void:
	if locked:
		farmer.stop()
		_interaction.pending = null
		if _interaction.hovered != null:
			_interaction.hovered.set_hovered(false)
			_interaction.hovered = null
		_interaction.label.visible = false
	for node: Node in [farmer, farmer.tools, _interaction]:
		node.set_process_unhandled_input(not locked)
	_interaction.set_physics_process(not locked)


func _request_bake() -> void:
	if _bake_timer != null:
		_bake_timer.start(bake_delay)


func _bake() -> void:
	if world.is_baking():
		_bake_timer.start(0.2)
		return
	world.bake_finished.connect(_on_baked, CONNECT_ONE_SHOT)
	world.bake_navigation_mesh(true)


func _on_baked() -> void:
	await get_tree().physics_frame
	nav_baked.emit()
