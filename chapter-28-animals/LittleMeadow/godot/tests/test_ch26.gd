extends Node
## Chapter 26: Interactable, hover and click, the watering can, the pump, the windmill, the tractor and the crate.
## The clock runs like in Chapter 25: 480 physics steps a second and Engine.time_scale 8, so every step is 1/60 s of game time.

const FARM: String = "res://scenes/world/farm.tscn"
const PROBE := Vector3(0.5, 0.0, 12.0)
const STEP: float = 1.0 / 60.0
const TICKS: int = 480
const SPEEDUP: float = 8.0

var _log: Array[String] = []


func before_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = TICKS
	Engine.time_scale = SPEEDUP
	_log.clear()
	if not Events.interaction_started.is_connected(_on_started):
		Events.interaction_started.connect(_on_started)
		Events.interaction_finished.connect(_on_finished)
		Events.water_level_changed.connect(_on_water)


func after_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	Input.action_release("move_run")


func _on_started(target: Interactable, _farmer: Farmer) -> void:
	_log.append("started:" + target.get_parent().name)


func _on_finished(target: Interactable, _farmer: Farmer) -> void:
	_log.append("finished:" + target.get_parent().name)


func _on_water(level: int, capacity: int) -> void:
	_log.append("water:%d/%d" % [level, capacity])


func _count(prefix: String) -> int:
	var n: int = 0
	for line: String in _log:
		if line.begins_with(prefix):
			n += 1
	return n


func _farm(t: Variant) -> Node:
	await t.frames(2) # the farm of the last test is freed at the end of a frame, and its colliders would still answer a ray
	var farm: Node = t.load_scene(FARM)
	await t.physics_frames(3)
	# an empty navigation map answers map_get_closest_point() with (0, 0, 0): wait until the probe point is found
	var map: RID = (farm.get_node("World") as NavigationRegion3D).get_navigation_map()
	var waited: int = 0
	while NavigationServer3D.map_get_closest_point(map, PROBE).distance_to(PROBE) > 1.0 and waited < 300:
		NavigationServer3D.map_force_update(map)
		await t.physics_frames(1)
		waited += 1
	return farm


## Points the camera at `point` and detaches it from the farmer, so the point is in the middle of the screen.
func _look_at(farm: Node, point: Vector3) -> CameraRig:
	var rig := farm.get_node("CameraRig") as CameraRig
	rig.target = null
	rig.global_position = point
	rig.snap()
	return rig


func _screen(farm: Node, point: Vector3) -> Vector2:
	return (farm.get_node("CameraRig") as CameraRig).camera.unproject_position(point)


func _machine(farm: Node, machine_name: String) -> Interactable:
	return farm.get_node("World/Machines/%s/Interactable" % machine_name) as Interactable


func _crate(farm: Node, crate_name: String) -> Interactable:
	return farm.get_node("World/Props/%s/Interactable" % crate_name) as Interactable


func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _wait_until_still(t: Variant, farmer: Farmer, limit: float = 60.0) -> float:
	var steps: int = 0
	while farmer.walking and steps < int(limit / STEP):
		await t.physics_frames(1)
		steps += 1
	return steps * STEP


func test_the_farmer_scene_has_the_new_nodes(t: Variant) -> void:
	var farmer := (load("res://scenes/actors/farmer.tscn") as PackedScene).instantiate() as Farmer
	add_child(farmer)
	var controller := farmer.get_node("InteractionController") as InteractionController
	t.not_null(controller, "the farmer has an InteractionController")
	t.ok(controller.label is Label3D, "the controller made a Label3D for the prompt")
	var can := farmer.get_node("WateringCan") as WateringCan
	t.not_null(can, "the farmer has a WateringCan")
	t.eq(farmer.can, can, "Farmer.can is that node")
	t.eq(can.water_level, 0, "the can starts empty")
	t.eq(can.capacity, 5, "capacity")
	var label := farmer.get_node("CanLabel") as CanLabel
	t.not_null(label, "a CanLabel on the farmer")
	t.eq(label.can, can, "the label knows the can")
	farmer.free()


func test_the_watering_can_counts_and_tells_the_bus(t: Variant) -> void:
	var can := WateringCan.new()
	can.capacity = 3
	add_child(can)
	t.ok(can.is_empty() and not can.is_full(), "new can is empty")
	t.ok(not can.use(), "using an empty can fails")
	t.eq(_log.size(), 0, "and tells nobody")
	can.refill()
	t.eq(can.water_level, 3, "refill fills to capacity")
	t.ok(can.is_full(), "full")
	t.ok(can.use(), "use works")
	t.eq(can.water_level, 2, "one less")
	t.eq(_log, ["water:3/3", "water:2/3"] as Array[String], "the bus got both changes")
	can.free()


func test_the_base_class(t: Variant) -> void:
	var plain := Interactable.new()
	t.eq(plain.prompt_text, "Use", "default prompt")
	t.approx(plain.interact_range, 1.5, 0.0001, "default range")
	t.eq(plain.action_name, &"", "default action name")
	t.ok(plain.has_signal("hovered") and plain.has_signal("unhovered") and plain.has_signal("interacted"), "three signals")
	var farmer := (load("res://scenes/actors/farmer.tscn") as PackedScene).instantiate() as Farmer
	t.ok(plain.can_interact(farmer), "the base class always allows")
	var heard: Array[Farmer] = []
	plain.interacted.connect(func(f: Farmer) -> void: heard.append(f))
	plain.interact(farmer)
	t.eq(heard.size(), 1, "interact() sends interacted once")
	t.ok(WaterPump.new() is Interactable and TractorSwitch.new() is Interactable, "the machines extend Interactable")
	plain.free()
	farmer.free()


func test_every_interactable_of_the_farm_is_on_layer_2(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var found: Array[Interactable] = []
	for node: Node in farm.find_children("*", "Area3D", true, false):
		if node is Interactable:
			found.append(node as Interactable)
	t.eq(found.size(), 51, "pump, tractor, two small crates, the farmhouse door, 40 soil plots and six animals")
	for item: Interactable in found:
		t.eq(item.collision_layer, 2, "%s is on layer 2 (interactable)" % item.get_parent().name)
		t.eq(item.collision_mask, 0, "%s looks at nothing" % item.get_parent().name)
		var shape := item.get_node("CollisionShape3D") as CollisionShape3D
		t.not_null(shape.shape, "%s has a shape" % item.get_parent().name)
	var farmer := farm.get_node("Farmer") as Farmer
	t.eq(farmer.collision_mask & 2, 0, "the farmer does not look at layer 2")
	farm.queue_free()


func test_hover_picks_the_right_interactable(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var controller := farm.get_node("Farmer/InteractionController") as InteractionController
	var pump: Interactable = _machine(farm, "Pump")
	var tractor: Interactable = _machine(farm, "Tractor")
	var crate: Interactable = _crate(farm, "CrateSmall_1")
	for item: Interactable in [pump, tractor, crate]:
		var rig: CameraRig = _look_at(farm, item.global_position)
		await t.physics_frames(2)
		var centre: Vector2 = _screen(farm, item.global_position + Vector3(0.0, 0.5, 0.0))
		t.eq(controller.pick(centre), item, "the ray finds %s" % item.get_parent().name)
		t.ok(rig != null, "rig")
	_look_at(farm, pump.global_position)
	await t.physics_frames(2)
	var on_grass: Vector2 = _screen(farm, pump.global_position + Vector3(4.0, 0.0, 0.0))
	t.eq(controller.pick(on_grass), null, "the grass beside the pump is no Interactable")
	farm.queue_free()


func test_a_building_in_front_hides_an_interactable(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var controller := farm.get_node("Farmer/InteractionController") as InteractionController
	var barn_spot := Vector3(8.5, 0.0, -17.0) # behind the barn, seen from the south
	var hidden := Interactable.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	shape.shape = box
	hidden.add_child(shape)
	hidden.collision_layer = 2
	hidden.collision_mask = 0
	farm.add_child(hidden)
	hidden.global_position = barn_spot + Vector3(0.0, 0.5, 0.0)
	_look_at(farm, Vector3(8.5, 0.0, -14.0))
	await t.physics_frames(3)
	var aim: Vector2 = _screen(farm, hidden.global_position)
	t.eq(controller.pick(aim), null, "the barn is in front of the box, so the box is not picked")
	hidden.global_position = Vector3(8.5, 0.5, -4.0) # the same box on open ground, in view
	await t.physics_frames(3)
	var clear: Vector2 = _screen(farm, hidden.global_position)
	t.eq(controller.pick(clear), hidden, "on open ground the same box is picked")
	farm.queue_free()


func test_hover_highlights_and_shows_the_prompt(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var controller := farm.get_node("Farmer/InteractionController") as InteractionController
	var pump: Interactable = _machine(farm, "Pump")
	var hovered_count: Array[int] = [0]
	var unhovered_count: Array[int] = [0]
	pump.hovered.connect(func() -> void: hovered_count[0] += 1)
	pump.unhovered.connect(func() -> void: unhovered_count[0] += 1)
	_look_at(farm, pump.global_position)
	await t.physics_frames(2)
	var mesh := farm.get_node("World/Machines/Pump/mach_pump") as MeshInstance3D
	var lever := farm.get_node("World/Machines/Pump/mach_pump/mach_pump__lever") as MeshInstance3D
	t.eq(mesh.material_overlay, null, "no highlight at the start")
	t.ok(not controller.label.visible, "no prompt at the start")
	t.mouse_move(_screen(farm, pump.global_position + Vector3(0.0, 0.5, 0.0)))
	await t.frames(3)
	await t.physics_frames(3)
	t.eq(controller.hovered, pump, "the controller hovers the pump")
	t.ok(pump.is_hovered, "the pump knows")
	t.ok(mesh.material_overlay != null and lever.material_overlay != null, "both meshes carry the overlay")
	t.ok(controller.label.visible, "the prompt shows")
	t.eq(controller.label.text, "Fill the watering can", "with the prompt_text")
	t.vec_approx(controller.label.global_position, pump.global_position + Vector3(0.0, pump.prompt_height, 0.0), 0.001, "above the pump")
	var first: float = (mesh.material_overlay as StandardMaterial3D).albedo_color.a
	await t.physics_frames(8)
	await t.frames(6)
	var second: float = (mesh.material_overlay as StandardMaterial3D).albedo_color.a
	t.ok(absf(first - second) > 0.001, "the highlight pulses (%.3f then %.3f)" % [first, second])
	t.mouse_move(_screen(farm, pump.global_position + Vector3(4.0, 0.0, 0.0)))
	await t.frames(3)
	await t.physics_frames(3)
	t.eq(controller.hovered, null, "nothing hovered over the grass")
	t.eq(mesh.material_overlay, null, "the highlight is gone")
	t.ok(not controller.label.visible, "and the prompt")
	t.eq(hovered_count[0], 1, "hovered fired once")
	t.eq(unhovered_count[0], 1, "unhovered fired once")
	farm.queue_free()


func test_clicking_the_pump_walks_then_pumps_then_fills_the_can(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var controller := farm.get_node("Farmer/InteractionController") as InteractionController
	var pump: Interactable = _machine(farm, "Pump")
	var player := farm.get_node("World/Machines/Pump/AnimationPlayer") as AnimationPlayer
	var started: Array[String] = []
	player.animation_started.connect(func(clip: StringName) -> void: started.append(String(clip)))
	var heard: Array[int] = [0]
	pump.interacted.connect(func(_f: Farmer) -> void: heard[0] += 1)
	_look_at(farm, pump.global_position)
	farmer.global_position = Vector3(0.5, 0.0, -3.5)
	await t.physics_frames(2)
	t.eq(farmer.can.water_level, 0, "the can is empty")
	var targets: Array[Vector3] = []
	farmer.target_set.connect(func(p: Vector3) -> void: targets.append(p))
	await t.click(_screen(farm, pump.global_position + Vector3(0.0, 0.5, 0.0)))
	t.eq(targets.size(), 1, "one goal was set")
	t.ok(farmer.walking, "the farmer walks")
	t.eq(controller.pending, pump, "and the pump is waiting")
	t.eq(_count("started"), 0, "nothing has been used yet")
	var seconds: float = await _wait_until_still(t, farmer)
	t.ok(seconds > 3.0, "the walk took a while (%.1f s)" % seconds)
	var distance: float = _flat(farmer.global_position).distance_to(_flat(pump.global_position))
	t.ok(distance <= pump.interact_range, "the farmer stands %.2f m from the pump, inside %.1f m" % [distance, pump.interact_range])
	t.eq(_count("started:Pump"), 1, "interaction_started fired once")
	t.eq(started, ["mach_pump_pump"] as Array[String], "the lever clip started")
	t.eq(controller.pending, null, "nothing pending any more")
	t.eq(farmer.can.water_level, 0, "the can is still empty while the lever moves")
	await t.secs(1.2)
	t.eq(farmer.can.water_level, 5, "the can is full when the clip has ended")
	t.eq(_count("finished:Pump"), 1, "interaction_finished fired once")
	t.eq(heard[0], 1, "interacted fired once")
	t.eq(_count("water:5/5"), 1, "water_level_changed fired once")
	t.eq(player.current_animation, "", "the clip does not loop")
	var cl := farm.get_node("Farmer/CanLabel").get_child(0) as Label
	t.eq(cl.text, "Water 5 / 5", "the label shows the full can")
	farm.queue_free()


func test_a_full_can_refuses_the_pump(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var pump: Interactable = _machine(farm, "Pump")
	farmer.can.refill()
	_log.clear()
	t.ok(not pump.can_interact(farmer), "the pump says no to a full can")
	_look_at(farm, pump.global_position)
	await t.physics_frames(2)
	await t.click(_screen(farm, pump.global_position + Vector3(0.0, 0.5, 0.0)))
	await _wait_until_still(t, farmer)
	await t.secs(1.5)
	t.eq(_count("started"), 0, "no interaction started")
	t.eq(_count("water"), 0, "no water message")
	farmer.can.use()
	t.ok(pump.can_interact(farmer), "with room in the can the pump says yes")
	farm.queue_free()


func test_walking_away_cancels_the_interaction(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var controller := farm.get_node("Farmer/InteractionController") as InteractionController
	var pump: Interactable = _machine(farm, "Pump")
	_look_at(farm, Vector3(-1.0, 0.0, 0.0))
	farmer.global_position = Vector3(0.5, 0.0, -3.5)
	await t.physics_frames(2)
	await t.click(_screen(farm, pump.global_position + Vector3(0.0, 0.5, 0.0)))
	t.eq(controller.pending, pump, "pending after the click on the pump")
	await t.secs(1.0)
	var ground: Vector2 = _screen(farm, Vector3(4.0, 0.0, -1.0))
	await t.click(ground)
	t.eq(controller.pending, null, "a click on the ground cancels it")
	await _wait_until_still(t, farmer)
	await t.secs(1.5)
	t.eq(_count("started"), 0, "the pump was never used")
	t.eq(farmer.can.water_level, 0, "the can is still empty")
	t.ok(_flat(farmer.global_position).distance_to(Vector2(4.0, -1.0)) < 0.6, "the farmer went where the ground click said")
	# Escape cancels as well
	await t.click(_screen(farm, pump.global_position + Vector3(0.0, 0.5, 0.0)))
	t.eq(controller.pending, pump, "pending again")
	t.key(KEY_ESCAPE, true)
	await t.frames(2)
	t.key(KEY_ESCAPE, false)
	await t.frames(2)
	t.eq(controller.pending, null, "Escape cancels it")
	t.ok(not farmer.walking, "and stops the farmer")
	farm.queue_free()


func test_a_ground_click_still_walks_and_uses_nothing(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var targets: Array[Vector3] = []
	var arrivals: Array[Vector3] = []
	farmer.target_set.connect(func(p: Vector3) -> void: targets.append(p))
	farmer.arrived.connect(func(p: Vector3) -> void: arrivals.append(p))
	await t.physics_frames(2)
	await t.click(t.screen_size() / 2.0 + Vector2(120.0, 60.0))
	t.eq(targets.size(), 1, "target_set fired once")
	await _wait_until_still(t, farmer)
	t.eq(arrivals.size(), 1, "arrived fired once")
	t.eq(_count("started"), 0, "no interaction")
	farm.queue_free()


func test_the_windmill_turns_all_the_time(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var player := farm.get_node("World/Machines/Windmill/AnimationPlayer") as AnimationPlayer
	var blades := farm.get_node("World/Machines/Windmill/mach_windmill/mach_windmill__blades") as Node3D
	t.eq(player.autoplay, "mach_windmill_spin", "autoplay is the spin clip")
	t.ok(player.is_playing(), "the clip plays without anybody starting it")
	t.eq(player.current_animation, "mach_windmill_spin", "it is the spin clip")
	t.eq(player.get_animation("mach_windmill_spin").loop_mode, Animation.LOOP_LINEAR, "the clip loops")
	var angles: Array[float] = []
	var speeds: Array[float] = []
	var wraps: int = 0
	var last_position: float = player.current_animation_position
	for i: int in 24:
		await t.secs(0.5)
		angles.append(blades.rotation.z)
		speeds.append(player.speed_scale)
		if player.current_animation_position < last_position:
			wraps += 1
		last_position = player.current_animation_position
	t.ok(wraps >= 1, "the clip wrapped round %d times in 12 s" % wraps)
	t.ok(absf(angles[-1] - angles[0]) > 0.1 or absf(angles[5] - angles[0]) > 0.1, "the blades turn")
	var lowest: float = speeds.min()
	var highest: float = speeds.max()
	t.ok(lowest >= 0.55 and highest <= 1.45, "the speed stays between 0.6 and 1.4 (%.2f to %.2f)" % [lowest, highest])
	t.ok(highest - lowest > 0.02, "and it does change")
	var biggest_jump: float = 0.0
	for i: int in range(1, speeds.size()):
		biggest_jump = maxf(biggest_jump, absf(speeds[i] - speeds[i - 1]))
	t.ok(biggest_jump < 0.1, "it changes slowly (largest change in half a second %.3f)" % biggest_jump)
	t.ok(player.is_playing(), "and still plays")
	farm.queue_free()


func test_the_tractor_starts_and_stops(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var tractor := _machine(farm, "Tractor") as TractorSwitch
	var player := farm.get_node("World/Machines/Tractor/AnimationPlayer") as AnimationPlayer
	var wheel := farm.get_node("World/Machines/Tractor/mach_tractor/mach_tractor__wheel_rl") as Node3D
	var heard: Array[int] = [0]
	tractor.interacted.connect(func(_f: Farmer) -> void: heard[0] += 1)
	t.ok(not tractor.running, "parked at the start")
	t.eq(tractor.prompt_text, "Start the tractor", "the prompt offers to start it")
	t.approx(player.speed_scale, 0.0, 0.0001, "the wheels stand still")
	var parked: Vector3 = tractor.get_parent().global_position
	_look_at(farm, tractor.global_position)
	farmer.global_position = Vector3(8.0, 0.0, -3.0)
	await t.physics_frames(2)
	var aim: Vector2 = _screen(farm, tractor.global_position + Vector3(0.0, 1.0, 0.0))
	await t.click(aim)
	await _wait_until_still(t, farmer)
	await t.secs(1.5)
	t.ok(tractor.running, "the click started the tractor")
	t.eq(tractor.prompt_text, "Stop the tractor", "the prompt now offers to stop it")
	t.approx(player.speed_scale, 1.0, 0.01, "the wheels run at full speed")
	var angle_a: float = wheel.rotation.x
	await t.secs(0.3)
	var angle_b: float = wheel.rotation.x
	t.ok(absf(angle_a - angle_b) > 0.05, "the wheel turns (%.2f to %.2f)" % [angle_a, angle_b])
	t.eq(_count("started:Tractor"), 1, "one start message")
	t.eq(heard[0], 1, "interacted once")
	await t.click(aim)
	await t.secs(2.0)
	t.ok(not tractor.running, "the second click stopped it")
	t.eq(tractor.prompt_text, "Start the tractor", "the prompt is back")
	t.approx(player.speed_scale, 0.0, 0.01, "the wheels have stopped")
	var angle_c: float = wheel.rotation.x
	await t.secs(0.5)
	t.approx(wheel.rotation.x, angle_c, 0.001, "and stay stopped")
	t.eq(_count("finished:Tractor"), 2, "two finished messages in all")
	t.eq(heard[0], 2, "interacted twice in all")
	t.vec_approx(tractor.get_parent().global_position, parked, 0.0001, "the tractor never left its place")
	farm.queue_free()


func test_the_crate_hops_through_a_signal(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var crate := _crate(farm, "CrateSmall_1")
	var root := crate.get_parent()
	var mesh := root.get_node("prop_crate_small") as MeshInstance3D
	t.ok(crate.interacted.is_connected(root._on_interactable_interacted), "the signal is connected to the crate script")
	t.eq(crate.get_script(), load("res://scripts/core/interactable.gd"), "the crate uses the plain base class")
	_look_at(farm, crate.global_position)
	farmer.global_position = Vector3(0.5, 0.0, -3.5)
	await t.physics_frames(2)
	await t.click(_screen(farm, crate.global_position + Vector3(0.0, 0.3, 0.0)))
	var top: float = 0.0
	var steps: int = 0
	while steps < int(40.0 / STEP):
		await t.physics_frames(1)
		steps += 1
		top = maxf(top, mesh.position.y)
		if _count("finished") > 0 and not farmer.walking and steps > 10 and mesh.position.y == 0.0 and top > 0.0:
			break
	t.ok(top > 0.1, "the crate jumped (%.2f m)" % top)
	t.eq(_count("started:CrateSmall_1"), 1, "one start")
	t.eq(_count("finished:CrateSmall_1"), 1, "one finish")
	farm.queue_free()


func test_a_layer_2_area_does_not_block_the_farmer(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var zone := Interactable.new()
	zone.collision_layer = 2
	zone.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 4.0)
	shape.shape = box
	zone.add_child(shape)
	farm.add_child(zone)
	zone.global_position = Vector3(0.5, 1.5, 3.0) # straight across the path from (0.5, -3.5) to (0.5, 9)
	var polygons: int = (farm.get_node("World") as NavigationRegion3D).navigation_mesh.get_polygon_count()
	t.eq(polygons, 511, "the baked mesh still has its 511 polygons, no new bake was needed")
	await t.physics_frames(2)
	var inside_steps: int = 0
	farmer.walk_to(Vector3(0.5, 0.0, 9.0))
	var steps: int = 0
	while farmer.walking and steps < int(60.0 / STEP):
		await t.physics_frames(1)
		steps += 1
		if absf(farmer.global_position.x - 0.5) < 2.0 and absf(farmer.global_position.z - 3.0) < 2.0:
			inside_steps += 1
	t.ok(inside_steps > 30, "the farmer walked through the area (%d steps inside)" % inside_steps)
	t.ok(_flat(farmer.global_position).distance_to(Vector2(0.5, 9.0)) < 0.2, "and reached the goal")
	t.ok(steps * STEP < 12.5 / 1.2, "at the normal pace (%.1f s for 12.5 m)" % (steps * STEP))
	farm.queue_free()


func test_action_name_plays_a_farmer_clip(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var animation := farmer.get_node("AnimationTree") as FarmerAnimation
	var crate := _crate(farm, "CrateSmall_1")
	crate.action_name = &"harvest"
	_look_at(farm, crate.global_position)
	farmer.global_position = crate.global_position + Vector3(0.0, 0.0, 1.0)
	await t.physics_frames(3)
	t.ok(not animation.is_acting(), "the farmer is not acting")
	await t.click(_screen(farm, crate.global_position + Vector3(0.0, 0.3, 0.0)))
	await t.physics_frames(6)
	t.ok(animation.is_acting(), "the click, already in range, starts the harvest clip at once")
	t.eq(_count("started:CrateSmall_1"), 1, "one start")
	t.ok(not farmer.walking, "and the farmer did not walk")
	await t.secs(3.0)
	t.ok(not animation.is_acting(), "the clip ends by itself")
	farm.queue_free()
