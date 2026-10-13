extends Node
## Chapter 25: the farmer scene, click to move, the state machine, the marker and the camera follow.
## The tests speed up the clock without changing the size of a step: the engine runs 480 physics steps a second and
## Engine.time_scale is 8, so every step is still 1/60 s of game time, and a 20 second walk takes about 2.5 seconds.

const FARM: String = "res://scenes/world/farm.tscn"
const FARMER: String = "res://scenes/actors/farmer.tscn"
const START := Vector3(0.5, 0.0, -3.5)
const STEP: float = 1.0 / 60.0
const TICKS: int = 480
const SPEEDUP: float = 8.0
const CLIPS: PackedStringArray = [
	"char_farmer_idle", "char_farmer_walk", "char_farmer_run",
	"char_farmer_plant", "char_farmer_water", "char_farmer_harvest",
]


func before_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = TICKS
	Engine.time_scale = SPEEDUP


func after_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	Input.action_release("move_run")


## The footprint of every building and machine as a polygon on the ground (x and z), in world space.
func _footprints(farm: Node) -> Dictionary:
	var result: Dictionary = {}
	for group_name: String in ["Buildings", "Machines"]:
		for item: Node in farm.get_node("World/" + group_name).get_children():
			var obstacle := item.get_node("Footprint") as NavigationObstacle3D
			var corners := PackedVector2Array()
			for point: Vector3 in obstacle.vertices:
				var world: Vector3 = obstacle.global_transform * point
				corners.append(Vector2(world.x, world.z))
			result[item.name] = corners
	return result


func _inside_any(point: Vector2, polygons: Dictionary) -> String:
	for key: String in polygons:
		if Geometry2D.is_point_in_polygon(point, polygons[key]):
			return key
	return ""


func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


## Loads the farm and waits until the navigation map has the baked mesh.
func _farm(t: Variant) -> Node:
	var farm: Node = t.load_scene(FARM)
	await t.physics_frames(3)
	NavigationServer3D.map_force_update((farm.get_node("World") as NavigationRegion3D).get_navigation_map())
	return farm


## Lets game time run until the farmer has arrived (or `limit` seconds have passed). Returns the seconds used.
func _walk(t: Variant, farmer: Farmer, limit: float = 90.0, trail: Array[Vector3] = []) -> float:
	var steps: int = 0
	while farmer.walking and steps < int(limit / STEP):
		await t.physics_frames(1)
		steps += 1
		trail.append(farmer.global_position)
	return steps * STEP


func test_the_farmer_scene_is_built_as_planned(t: Variant) -> void:
	var farmer := (load(FARMER) as PackedScene).instantiate() as Farmer
	t.not_null(farmer, "farmer.tscn has the Farmer script on a CharacterBody3D")
	t.eq(farmer.name, &"Farmer", "root name")
	t.eq(farmer.collision_layer, 4, "the farmer is on layer 3, actor (value 4)")
	t.eq(farmer.collision_mask, 9, "the farmer collides with ground (1) and obstacle (8)")
	var shape := (farmer.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	t.not_null(shape, "the body is a capsule")
	t.approx(shape.radius, 0.35, 0.001, "capsule radius is smaller than the navigation radius")
	t.approx(shape.height, 1.7, 0.001, "capsule height")
	var agent := farmer.get_node("NavigationAgent3D") as NavigationAgent3D
	t.approx(agent.radius, 0.5, 0.001, "agent radius")
	t.approx(agent.height, 1.75, 0.001, "agent height")
	t.approx(agent.path_desired_distance, 0.3, 0.001, "path_desired_distance")
	t.approx(agent.target_desired_distance, 0.15, 0.001, "target_desired_distance")
	t.approx(agent.path_height_offset, 0.45, 0.001, "path_height_offset undoes the float of the mesh")
	t.ok(not agent.avoidance_enabled, "avoidance is off")
	var model := farmer.get_node("Model") as Node3D
	t.not_null(model, "the glb is a child named Model")
	t.approx(absf(model.rotation_degrees.y), 180.0, 0.01, "the model is turned to face -Z")
	var player := farmer.get_node("Model/AnimationPlayer") as AnimationPlayer
	for clip: String in CLIPS:
		t.ok(player.has_animation(clip), "clip %s" % clip)
	var tree := farmer.get_node("AnimationTree") as AnimationTree
	t.ok(tree is FarmerAnimation, "the tree has the FarmerAnimation script")
	t.eq(tree.anim_player, NodePath("../Model/AnimationPlayer"), "the tree reads the clips of the model")
	t.eq(tree.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS, "the tree steps with physics")
	var root := tree.tree_root as AnimationNodeBlendTree
	for node_name: String in ["Locomotion", "Pace", "Action", "ActionPick"]:
		t.ok(root.has_node(node_name), "the tree has %s" % node_name)
	var machine := root.get_node("Locomotion") as AnimationNodeStateMachine
	for state: String in ["idle", "walk", "run"]:
		t.ok(machine.has_node(state), "state %s" % state)
	t.eq(machine.get_transition_count(), 6, "six transitions: Start, idle<>walk, walk<>run, run to idle")
	farmer.free()


func test_the_move_run_action_is_shift(t: Variant) -> void:
	t.ok(InputMap.has_action("move_run"), "move_run exists")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.pressed = true
	t.ok(event.is_action("move_run"), "Shift is move_run")


func test_the_farm_holds_the_farmer_and_the_camera_follows(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var start := farm.get_node("FarmerStart") as Marker3D
	t.not_null(farmer, "the farm has a Farmer")
	t.vec_approx(farmer.global_position, start.global_position, 0.001, "the farmer stands on FarmerStart")
	var rig := farm.get_node("CameraRig") as CameraRig
	t.eq(rig.target, farmer, "the camera rig targets the farmer")
	t.vec_approx(rig.global_position, farmer.global_position, 0.01, "the rig started on the farmer")
	farm.queue_free()


func test_a_walk_across_the_farm_goes_through_the_barn_gap(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var shapes: Dictionary = _footprints(farm)
	var goal := Vector3(14.0, 0.0, -20.0)
	var targets: Array[Vector3] = []
	var arrivals: Array[Vector3] = []
	farmer.target_set.connect(func(p: Vector3) -> void: targets.append(p))
	farmer.arrived.connect(func(p: Vector3) -> void: arrivals.append(p))
	farmer.walk_to(goal)
	var trail: Array[Vector3] = []
	var seconds: float = await _walk(t, farmer, 90.0, trail)
	t.ok(not farmer.walking, "the farmer arrived (%.1f s of game time)" % seconds)
	t.eq(targets.size(), 1, "target_set fired once")
	t.eq(arrivals.size(), 1, "arrived fired once")
	var wanted: Vector3 = targets[0]
	t.ok(_flat(farmer.global_position).distance_to(_flat(wanted)) <= farmer.agent.target_desired_distance, "stopped within target_desired_distance (%.3f m)" % _flat(farmer.global_position).distance_to(_flat(wanted)))
	t.ok(_flat(wanted).distance_to(_flat(goal)) < 0.6, "the goal was on walkable ground")
	var through_gap: bool = false
	var inside: String = ""
	for point: Vector3 in trail:
		var flat: Vector2 = _flat(point)
		if _inside_any(flat, shapes) != "":
			inside = _inside_any(flat, shapes)
		if flat.y < -15.0 and flat.y > -16.0 and flat.x > 13.0 and flat.x < 15.5:
			through_gap = true
	t.eq(inside, "", "the farmer never stood inside a footprint")
	t.ok(through_gap, "the path went through the gap between the barn and the shed")
	t.ok(absf(farmer.global_position.y) < 0.2, "the farmer stands on the ground")
	t.ok(trail.size() > 600, "the walk took a real time (%d steps)" % trail.size())
	farm.queue_free()


func test_the_hill_is_climbed(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	Input.action_press("move_run")
	farmer.walk_to(Vector3(18.0, 1.0, 2.0))
	var seconds: float = await _walk(t, farmer, 60.0)
	t.ok(not farmer.walking, "arrived on the hill (%.1f s)" % seconds)
	t.ok(farmer.global_position.y > 0.9, "the farmer is up the hill (y %.2f)" % farmer.global_position.y)
	farm.queue_free()


func test_the_state_machine_follows_the_speed(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var animation := farmer.get_node("AnimationTree") as FarmerAnimation
	await t.physics_frames(5)
	t.eq(animation.current_state(), &"idle", "the farmer starts idle")
	var visited: Array[StringName] = [animation.current_state()]
	Input.action_press("move_run")
	farmer.walk_to(START + Vector3(0.0, 0.0, 10.0))
	var pace_when_running: float = 0.0
	while farmer.walking:
		await t.physics_frames(1)
		var state: StringName = animation.current_state()
		if state != visited[-1]:
			visited.append(state)
		if state == &"run":
			pace_when_running = float(animation.get("parameters/Pace/scale"))
	await t.physics_frames(30)
	if animation.current_state() != visited[-1]:
		visited.append(animation.current_state())
	t.eq(visited, [&"idle", &"walk", &"run", &"idle"] as Array[StringName], "idle, walk, run, idle (%s)" % str(visited))
	t.approx(pace_when_running, farmer.run_speed / FarmerAnimation.RUN_CLIP_SPEED, 0.05, "the run clip is paced to the ground speed")
	# Without Shift the farmer only walks.
	Input.action_release("move_run")
	visited = [animation.current_state()]
	farmer.walk_to(START)
	while farmer.walking:
		await t.physics_frames(1)
		if animation.current_state() != visited[-1]:
			visited.append(animation.current_state())
	await t.physics_frames(30)
	if animation.current_state() != visited[-1]:
		visited.append(animation.current_state())
	t.eq(visited, [&"idle", &"walk", &"idle"] as Array[StringName], "without Shift: idle, walk, idle (%s)" % str(visited))
	farm.queue_free()


func test_a_click_on_the_pond_ends_on_the_bank(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var rig := farm.get_node("CameraRig") as CameraRig
	rig.target = null
	rig.global_position = Vector3(10.0, 0.0, 14.0)
	rig.snap()
	farmer.global_position = Vector3(10.0, 0.0, 8.0)
	await t.physics_frames(3)
	var centre: Vector2 = t.screen_size() / 2.0
	var hit: Variant = farmer.pick_ground(centre)
	t.not_null(hit, "the ray hits the pond")
	t.ok(absf((hit as Vector3).x - 10.0) < 0.5 and absf((hit as Vector3).z - 14.0) < 0.5, "the ray lands in the middle of the pond %s" % str(hit))
	var targets: Array[Vector3] = []
	farmer.target_set.connect(func(p: Vector3) -> void: targets.append(p))
	await t.click(centre)
	t.eq(targets.size(), 1, "the click set a target")
	var pond_centre := Vector2(10.0, 14.0)
	var bank: float = _flat(targets[0]).distance_to(pond_centre)
	t.ok(bank > 1.9 and bank < 2.8, "the goal is on the bank, %.2f m from the middle of the pond" % bank)
	await _walk(t, farmer, 60.0)
	var end: float = _flat(farmer.global_position).distance_to(pond_centre)
	t.ok(end > 1.9, "the farmer never reached the water (%.2f m from the middle)" % end)
	t.ok(_flat(farmer.global_position).distance_to(_flat(targets[0])) <= farmer.agent.target_desired_distance, "and stopped at the goal")
	farm.queue_free()


func test_a_click_on_a_building_ends_at_its_edge(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var rig := farm.get_node("CameraRig") as CameraRig
	var shapes: Dictionary = _footprints(farm)
	farmer.global_position = Vector3(8.5, 0.0, -7.0)
	rig.target = null
	rig.global_position = Vector3(8.5, 0.0, -9.0)
	rig.snap()
	await t.physics_frames(3)
	var aim: Vector2 = rig.camera.unproject_position(Vector3(8.5, 1.5, -11.0))
	var hit: Variant = farmer.pick_ground(aim)
	t.not_null(hit, "the ray hits the barn")
	t.ok((hit as Vector3).y > 0.3, "it hit the wall, not the grass behind (y %.2f)" % (hit as Vector3).y)
	await t.click(aim)
	await _walk(t, farmer, 60.0)
	var inside: String = _inside_any(_flat(farmer.global_position), shapes)
	t.eq(inside, "", "the farmer stands outside every footprint")
	var at: Vector3 = farmer.global_position
	t.ok(at.z > -11.0 and at.z < -10.2, "the farmer ended at the south edge of the barn (z %.2f)" % at.z)
	t.ok(absf(at.x - (hit as Vector3).x) < 1.0, "straight below the click (x %.2f)" % at.x)
	farm.queue_free()


func test_signals_fire_once_and_a_new_click_replaces_the_goal(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var targets: Array[Vector3] = []
	var arrivals: Array[Vector3] = []
	farmer.target_set.connect(func(p: Vector3) -> void: targets.append(p))
	farmer.arrived.connect(func(p: Vector3) -> void: arrivals.append(p))
	farmer.walk_to(Vector3(0.5, 0.0, 12.0))
	await t.physics_frames(60)
	farmer.walk_to(Vector3(-6.0, 0.0, -3.5))
	await _walk(t, farmer, 60.0)
	t.eq(targets.size(), 2, "two clicks, two target_set")
	t.eq(arrivals.size(), 1, "one arrival: the first goal was replaced")
	t.ok(_flat(arrivals[0]).distance_to(Vector2(-6.0, -3.5)) < 0.2, "the arrival is at the second goal")
	await t.physics_frames(60)
	t.eq(arrivals.size(), 1, "no second arrival while standing still")
	# Escape cancels a walk and sends no arrival.
	farmer.walk_to(Vector3(0.5, 0.0, 12.0))
	await t.physics_frames(30)
	await t.tap_action("ui_cancel", 1)
	t.ok(not farmer.walking, "Escape stops the walk")
	var spot: Vector3 = farmer.global_position
	await t.physics_frames(60)
	t.vec_approx(farmer.global_position, spot, 0.05, "and the farmer stays")
	t.eq(arrivals.size(), 1, "a cancelled walk does not arrive")
	farm.queue_free()


func test_the_marker_shows_and_fades(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var marker := farmer.get_node("ClickMarker") as ClickMarker
	t.ok(not marker.visible, "the marker starts hidden")
	farmer.walk_to(Vector3(5.0, 0.0, 0.0))
	t.ok(marker.visible, "a click shows it")
	t.ok(_flat(marker.global_position).distance_to(Vector2(5.0, 0.0)) < 0.3, "at the goal")
	t.ok(marker.global_position.y > 0.0 and marker.global_position.y < 0.2, "just above the ground")
	var spot: Vector3 = marker.global_position
	var material := marker.ring.material_override as StandardMaterial3D
	await t.physics_frames(int(marker.lifetime * 60.0 / 2.0))
	t.ok(material.albedo_color.a < 1.0 and material.albedo_color.a > 0.0, "half way it is half transparent (%.2f)" % material.albedo_color.a)
	t.ok(farmer.global_position.distance_to(START) > 0.3, "the farmer has walked on")
	t.vec_approx(marker.global_position, spot, 0.001, "the marker stayed on the ground while the farmer moved")
	await t.physics_frames(int(marker.lifetime * 60.0))
	t.ok(not marker.visible, "after its lifetime it is hidden")
	farm.queue_free()


func test_the_camera_follows_and_still_turns_while_walking(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var rig := farm.get_node("CameraRig") as CameraRig
	farmer.walk_to(Vector3(0.5, 0.0, 12.0))
	await t.physics_frames(120)
	var moved: float = _flat(farmer.global_position).distance_to(_flat(START))
	t.ok(moved > 2.0, "the farmer has walked %.1f m" % moved)
	t.ok(_flat(rig.global_position).distance_to(_flat(farmer.global_position)) < 1.0, "the camera is close behind")
	var yaw_before: float = rig.wanted_yaw
	var at_before: Vector3 = farmer.global_position
	t.press_action("cam_rotate_left")
	await t.physics_frames(30)
	t.release_action("cam_rotate_left")
	t.ok(rig.wanted_yaw > yaw_before, "Q turns the camera while the farmer walks")
	t.ok(_flat(farmer.global_position).distance_to(_flat(at_before)) > 0.4, "and the farmer keeps walking")
	await _walk(t, farmer, 60.0)
	t.ok(_flat(farmer.global_position).distance_to(Vector2(0.5, 12.0)) < 0.3, "the walk still ends at the clicked goal after the turn")
	await t.physics_frames(120)
	t.ok(_flat(rig.global_position).distance_to(_flat(farmer.global_position)) < 0.05, "the camera settles on the farmer")
	farm.queue_free()


func test_the_action_clips_play_once(t: Variant) -> void:
	var farmer := (load(FARMER) as PackedScene).instantiate() as Farmer
	t.add(farmer)
	await t.physics_frames(3)
	var animation := farmer.get_node("AnimationTree") as FarmerAnimation
	var player := farmer.get_node("Model/AnimationPlayer") as AnimationPlayer
	t.ok(not animation.is_acting(), "no action at the start")
	for action: StringName in [&"plant", &"water", &"harvest"]:
		animation.play_action(action)
		await t.physics_frames(3)
		t.ok(animation.is_acting(), "%s is playing" % action)
		var length: float = player.get_animation("char_farmer_" + action).length
		await t.physics_frames(int(length * 60.0) + 40)
		t.ok(not animation.is_acting(), "%s ended by itself after %.2f s" % [action, length])
		t.eq(animation.current_state(), &"idle", "back to idle after %s" % action)
	farmer.queue_free()


func _pose_sum(skeleton: Skeleton3D) -> float:
	var total: float = 0.0
	for bone: int in skeleton.get_bone_count():
		var q: Quaternion = skeleton.get_bone_pose_rotation(bone)
		total += q.x * (bone + 1) + q.y * (bone + 2)
	return total


func test_the_clips_reach_the_bones(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var skeleton := farmer.get_node("Model/char_farmer_rig/Skeleton3D") as Skeleton3D
	await t.physics_frames(30)
	var idle_pose: float = _pose_sum(skeleton)
	farmer.walk_to(START + Vector3(0.0, 0.0, 10.0))
	await t.physics_frames(60)
	var poses: Array[float] = []
	for i in 6:
		await t.physics_frames(12)
		poses.append(_pose_sum(skeleton))
	t.ok(absf(poses[0] - idle_pose) > 0.01, "the walk pose differs from the idle pose")
	var spread: float = poses.max() - poses.min()
	t.ok(spread > 0.01, "the pose keeps changing while the farmer walks (%f)" % spread)
	farm.queue_free()
