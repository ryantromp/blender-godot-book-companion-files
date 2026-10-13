extends Node
## Chapter 28: animals as data, a state machine that wanders on the navigation mesh, feeding, and one product a day.
## The clock runs like in Chapter 25: 480 physics steps a second and Engine.time_scale 8, so every step is 1/60 s of game time.
## Chapter 29 note: the FeedBag node and the FarmNotes tally are gone. The feed now comes out of the Inventory
## autoload (grain for chickens, hay for cows, biscuits for the dog), so the checks below count items there.

const FARM: String = "res://scenes/world/farm.tscn"
const PROBE := Vector3(0.5, 0.0, 12.0)
const TICKS: int = 480
const SPEEDUP: float = 8.0
const PEN := Rect2(-22.0, -3.0, 6.0, 6.0)
const PADDOCK := Rect2(-20.0, 12.0, 12.0, 8.0)
const GRAIN: ItemData = preload("res://resources/items/grain.tres")
const HAY: ItemData = preload("res://resources/items/hay.tres")
const BISCUIT: ItemData = preload("res://resources/items/dog_biscuit.tres")
const EGG: ItemData = preload("res://resources/items/egg.tres")
const NAMES: PackedStringArray = ["Chicken_1", "Chicken_2", "Chicken_3", "Cow_1", "Cow_2", "Dog_1"]

var _log: Array[String] = []


func before_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = TICKS
	Engine.time_scale = SPEEDUP
	GameClock.day = 1
	GameClock.minute_of_day = 360
	_log.clear()
	Inventory.clear()
	Inventory.give_starting_items()
	if not Events.animal_fed.is_connected(_on_fed):
		Events.animal_fed.connect(_on_fed)
		Events.product_collected.connect(_on_collected)
		Events.hint_shown.connect(_on_hint)
		Events.item_removed.connect(_on_removed)


func after_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	Input.action_release("move_run")


func _on_fed(animal: Animal) -> void:
	_log.append("fed:" + animal.name)


func _on_collected(item: ItemData, animal: Animal) -> void:
	_log.append("collected:%s:%s" % [item.id, animal.name])


func _on_hint(text: String) -> void:
	_log.append("hint:" + text)


func _on_removed(item: ItemData, amount: int) -> void:
	_log.append("removed:%s:%d" % [item.id, amount])


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
	return farm


func _animal(farm: Node, animal_name: String) -> Animal:
	return farm.get_node("Animals/" + animal_name) as Animal


func _seed(farm: Node) -> void:
	for index: int in NAMES.size():
		_animal(farm, NAMES[index]).rng.seed = 280 + index


func _screen(farm: Node, point: Vector3) -> Vector2:
	return (farm.get_node("CameraRig") as CameraRig).camera.unproject_position(point)


func _look_at(farm: Node, point: Vector3) -> void:
	var rig := farm.get_node("CameraRig") as CameraRig
	rig.target = null
	rig.global_position = point
	rig.snap()


## What the InteractionController does on arrival: ask, play the clip, interact. Returns whether it agreed.
func _use(farmer: Farmer, spot: Interactable) -> bool:
	if not spot.can_interact(farmer):
		return false
	if spot.action_name != "":
		farmer.animation.play_action(StringName(spot.action_name))
	await spot.interact(farmer)
	return true


func _pickups(farm: Node) -> Array[Node]:
	return farm.get_tree().get_nodes_in_group(&"pickups")


func _footprints(farm: Node) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for node: Node in farm.get_node("World").find_children("Footprint", "NavigationObstacle3D", true, false):
		var obstacle := node as NavigationObstacle3D
		var polygon := PackedVector2Array()
		for corner: Vector3 in obstacle.vertices:
			var world: Vector3 = obstacle.global_transform * corner
			polygon.append(Vector2(world.x, world.z))
		polygons.append(polygon)
	return polygons


func test_the_animal_files_load_with_the_right_fields(t: Variant) -> void:
	var expected: Dictionary = {
		"chicken": ["Chicken", &"grain", &"egg", &"peck", &""],
		"cow": ["Cow", &"hay", &"milk", &"graze", &""],
		"dog": ["Dog", &"dog_biscuit", &"", &"", &"bark"],
	}
	for kind: String in expected:
		var data := load("res://resources/animals/%s.tres" % kind) as AnimalData
		t.not_null(data, "%s.tres is an AnimalData" % kind)
		var want: Array = expected[kind]
		t.eq(data.id, StringName(kind), "%s id" % kind)
		t.eq(data.display_name, want[0], "%s name" % kind)
		t.eq(data.feed_item.id, want[1], "%s eats %s" % [kind, want[1]])
		if want[2] == &"":
			t.eq(data.product, null, "the %s makes nothing" % kind)
			t.eq(data.product_mesh, null, "and has no product mesh")
		else:
			t.eq(data.product.id, want[2], "%s makes %s" % [kind, want[2]])
			t.not_null(data.product_mesh, "%s has a product mesh" % kind)
		t.eq(data.eat_clip, want[3], "%s eat clip" % kind)
		t.eq(data.cheer_clip, want[4], "%s cheer clip" % kind)
		t.ok(data.speed > 0.0 and data.clip_speed > 0.0 and data.wander_radius > 0.0, "%s numbers are positive" % kind)
		t.ok(data.idle_seconds.x <= data.idle_seconds.y and data.eat_seconds.x <= data.eat_seconds.y, "%s ranges are ordered" % kind)
		t.ok(data.days_to_produce >= 1, "%s days to produce" % kind)
	for item_name: String in ["egg", "milk", "grain", "hay", "dog_biscuit"]:
		var item := load("res://resources/items/%s.tres" % item_name) as ItemData
		t.not_null(item, "%s.tres is an ItemData" % item_name)
		t.eq(item.id, StringName(item_name), "%s id" % item_name)
	t.eq((load("res://resources/items/dog_biscuit.tres") as ItemData).display_name, "Dog biscuit", "display name")


func test_the_scenes_are_built_as_planned(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var animals: Array[Node] = farm.get_tree().get_nodes_in_group(&"animals")
	t.eq(animals.size(), 6, "six animals in the group animals")
	t.eq(farm.get_node("Animals").get_child_count(), 6, "six children of Animals")
	var clips: Dictionary = {
		"chicken": ["idle", "walk", "peck"], "cow": ["idle", "walk", "graze"], "dog": ["idle", "walk", "bark"],
	}
	for animal_name: String in NAMES:
		var animal := _animal(farm, animal_name)
		t.not_null(animal, animal_name)
		t.ok(animal is CharacterBody3D, "%s is a CharacterBody3D" % animal_name)
		t.eq(animal.collision_layer, 4, "%s is on layer 3 (actor)" % animal_name)
		t.eq(animal.collision_mask, 9, "%s looks at ground and obstacles" % animal_name)
		t.not_null(animal.data, "%s has its data" % animal_name)
		t.ok(animal.spot is AnimalSpot and animal.spot is Interactable, "%s has an AnimalSpot (an Interactable)" % animal_name)
		t.eq(animal.spot.collision_layer, 2, "%s spot on layer 2" % animal_name)
		t.eq(animal.spot.collision_mask, 0, "%s spot looks at nothing" % animal_name)
		t.ok((animal.get_node("CollisionShape3D") as CollisionShape3D).shape is CapsuleShape3D, "%s has a capsule" % animal_name)
		t.not_null((animal.get_node("Spot/CollisionShape3D") as CollisionShape3D).shape, "%s spot has a shape" % animal_name)
		t.ok(animal.agent is NavigationAgent3D, "%s has a NavigationAgent3D" % animal_name)
		t.approx(animal.agent.path_height_offset, 0.45, 0.0001, "%s agent path_height_offset" % animal_name)
		t.eq(animal.home, animal.global_position, "%s home is where it was placed" % animal_name)
		t.ok(animal.is_in_group(&"animals"), "%s is in the group" % animal_name)
		for clip: String in clips[String(animal.data.id)]:
			t.ok(animal.player.has_animation("an_%s_%s" % [animal.data.id, clip]), "%s has the clip %s" % [animal_name, clip])
		t.eq(animal.player.get_animation("an_%s_walk" % animal.data.id).loop_mode, Animation.LOOP_LINEAR, "the walk clip loops")
		t.eq(animal.state, Animal.State.IDLE, "%s starts idle" % animal_name)
		t.eq(animal.fed, false, "%s starts hungry" % animal_name)
	var model := _animal(farm, "Chicken_1").get_node("Model") as Node3D
	t.approx(absf(model.rotation_degrees.y), 180.0, 0.01, "the model is turned by 180 degrees so -Z is the front")
	t.eq(_animal(farm, "Dog_1").data.id, &"dog", "the dog")
	t.ok(not farm.get_node("Farmer").has_node("FeedBag"), "the FeedBag node of Chapter 28 is gone")
	t.eq(Inventory.count_of(GRAIN), 6, "six grain in the bag at the start")
	farm.queue_free()


func test_animals_stay_in_their_region_and_never_enter_a_building(t: Variant) -> void:
	var farm: Node = await _farm(t)
	_seed(farm)
	var footprints: Array[PackedVector2Array] = _footprints(farm)
	t.ok(footprints.size() >= 10, "found the footprints of the buildings and machines (%d)" % footprints.size())
	var visited: Dictionary = {}
	var moved: Dictionary = {}
	var lowest: float = 0.0
	var worst_home: float = 0.0
	for name_in: String in NAMES:
		visited[name_in] = {}
		moved[name_in] = 0.0
	var last: Dictionary = {}
	for name_in: String in NAMES:
		last[name_in] = _animal(farm, name_in).global_position
	var bad: Array[String] = []
	var frames: int = 0
	while frames < 36000: # ten minutes of game time
		await t.physics_frames(20)
		frames += 20
		for name_in: String in NAMES:
			var animal := _animal(farm, name_in)
			visited[name_in][animal.state] = true
			moved[name_in] += animal.global_position.distance_to(last[name_in])
			last[name_in] = animal.global_position
			lowest = minf(lowest, animal.global_position.y)
			var flat := Vector2(animal.global_position.x, animal.global_position.z)
			worst_home = maxf(worst_home, flat.distance_to(Vector2(animal.home.x, animal.home.z)) / animal.data.wander_radius)
			if name_in.begins_with("Chicken") and not PEN.grow(-0.3).has_point(flat):
				bad.append("%s left the pen at %s" % [name_in, flat])
			if name_in.begins_with("Cow") and not PADDOCK.grow(-0.3).has_point(flat):
				bad.append("%s left the paddock at %s" % [name_in, flat])
			for polygon: PackedVector2Array in footprints:
				if Geometry2D.is_point_in_polygon(flat, polygon):
					bad.append("%s stands inside a footprint at %s" % [name_in, flat])
	t.eq(bad, [] as Array[String], "no animal left its region or entered a building in 10 minutes")
	t.ok(lowest > -0.3, "nobody fell through the ground (lowest y %.3f)" % lowest)
	t.ok(worst_home < 1.8, "nobody went further than 1.8 times its radius from home (%.2f)" % worst_home)
	for name_in: String in NAMES:
		var seen: Dictionary = visited[name_in]
		t.ok(seen.has(Animal.State.IDLE) and seen.has(Animal.State.WANDER), "%s visited IDLE and WANDER" % name_in)
		t.ok(moved[name_in] > 8.0, "%s walked %.1f m in ten minutes" % [name_in, moved[name_in]])
		if not name_in.begins_with("Dog"):
			t.ok(seen.has(Animal.State.EAT), "%s visited EAT" % name_in)
		else:
			t.ok(not seen.has(Animal.State.EAT), "the dog never eats on its own")
	farm.queue_free()


func test_a_wandering_animal_walks_at_its_speed_and_stops_for_the_mouse(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var cow := _animal(farm, "Cow_1")
	cow.rng.seed = 5
	cow.data = cow.data.duplicate() as AnimalData
	cow.data.idle_seconds = Vector2(0.1, 0.1)
	cow.data.eat_chance = 0.0
	var controller := farm.get_node("Farmer/InteractionController") as InteractionController
	var waited: int = 0
	while cow.state != Animal.State.WANDER and waited < 900:
		await t.physics_frames(10)
		waited += 10
	t.eq(cow.state, Animal.State.WANDER, "the cow set off")
	t.approx(cow.player.speed_scale, cow.data.speed / cow.data.clip_speed, 0.001, "the walk clip is scaled to the speed")
	t.eq(cow.player.current_animation, "an_cow_walk", "the walk clip plays")
	# A goal can be only a step away, so look at the speed a few frames into a walk and try again if it ended.
	var walking: float = 0.0
	for attempt: int in 8:
		await t.physics_frames(8)
		if cow.state == Animal.State.WANDER:
			walking = Vector2(cow.velocity.x, cow.velocity.z).length()
			break
		while cow.state != Animal.State.WANDER:
			await t.physics_frames(2)
	t.approx(walking, cow.data.speed, 0.05, "the cow walks at %.2f m/s" % cow.data.speed)
	_look_at(farm, cow.global_position)
	await t.physics_frames(2)
	t.mouse_move(_screen(farm, cow.global_position + Vector3(0.0, 0.8, 0.0)))
	await t.frames(2)
	await t.physics_frames(4)
	t.eq(controller.hovered, cow.spot, "the controller hovers the cow")
	t.eq(cow.state, Animal.State.IDLE, "a hovered cow stops")
	t.eq(controller.label.text, "Feed cow", "the prompt says Feed cow")
	var before: Vector3 = cow.global_position
	await t.physics_frames(120)
	t.vec_approx(cow.global_position, before, 0.001, "and stays where it is while the mouse is on it")
	t.mouse_move(_screen(farm, cow.global_position + Vector3(6.0, 0.0, 0.0)))
	await t.frames(2)
	await t.physics_frames(30)
	t.eq(cow.state, Animal.State.WANDER, "when the mouse leaves, it walks on")
	farm.queue_free()


func test_feeding_then_a_new_day_gives_exactly_one_egg(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var hen := _animal(farm, "Chicken_1")
	farmer.tools.select(&"hand")
	t.eq(hen.spot.prompt_text, "Feed chicken", "the prompt before")
	_log.clear()
	var agreed: bool = await _use(farmer, hen.spot)
	t.ok(agreed, "the chicken agreed to be fed")
	t.eq(_count("fed:"), 1, "animal_fed fired once")
	t.eq(_log.filter(func(l: String) -> bool: return l.begins_with("fed:")), ["fed:Chicken_1"], "for this chicken")
	t.ok(hen.fed, "the chicken is fed")
	t.eq(hen.spot.prompt_text, "Chicken is fed", "the prompt after")
	t.eq(Inventory.count_of(GRAIN), 5, "one grain used")
	t.eq(hen.state, Animal.State.EAT, "it pecks")
	t.eq(hen.player.current_animation, "an_chicken_peck", "with the peck clip")
	t.eq(_pickups(farm).size(), 0, "no egg yet")
	GameClock.advance_minutes(1440)
	await t.physics_frames(2)
	t.eq(_pickups(farm).size(), 1, "exactly one egg after the day changed")
	t.ok(hen.has_product(), "the hen knows")
	t.ok(not hen.fed, "hungry again")
	t.eq(hen.spot.prompt_text, "Feed chicken", "the prompt is back")
	var egg: Node3D = _pickups(farm)[0] as Node3D
	var spot := egg.get_node("Spot") as ProductPickup
	t.eq(spot.item.id, &"egg", "it is an egg")
	t.eq(spot.animal, hen, "from this hen")
	t.eq(spot.prompt_text, "Collect egg", "the prompt says Collect egg")
	t.eq(spot.collision_layer, 2, "layer 2")
	t.ok(PEN.has_point(Vector2(egg.global_position.x, egg.global_position.z)), "the egg lies in the pen at %s" % egg.global_position)
	t.approx(egg.global_position.y, hen.global_position.y, 0.001, "on the ground")
	t.ok((egg.get_node("Mesh") as MeshInstance3D).mesh is SphereMesh, "drawn with a SphereMesh")
	t.ok((egg.get_node("Mesh") as MeshInstance3D).position.y > 0.05, "resting on the ground, not sunk in it")
	_log.clear()
	GameClock.advance_minutes(1440)
	await t.physics_frames(2)
	t.eq(_pickups(farm).size(), 1, "an unfed day adds no second egg")
	var other := _animal(farm, "Chicken_2")
	t.ok(not other.has_product(), "the other chickens laid nothing")
	t.eq(Inventory.count_of(GRAIN), 5, "the grain does not come back by itself")
	t.ok(not await _use(farmer, hen.spot), "a hen with an egg waiting is not fed again")
	t.eq(_log.filter(func(l: String) -> bool: return l.begins_with("hint:")), ["hint:Collect the egg first."], "and says why")
	_log.clear()
	t.ok(await _use(farmer, spot), "the egg can be collected")
	await t.frames(2)
	t.eq(_log.filter(func(l: String) -> bool: return l.begins_with("collected:")), ["collected:egg:Chicken_1"], "product_collected once, with the item and the hen")
	t.eq(_pickups(farm).size(), 0, "the egg is gone")
	t.ok(not hen.has_product(), "the hen can be fed again")
	farm.queue_free()


func test_unfed_animals_make_nothing(t: Variant) -> void:
	var farm: Node = await _farm(t)
	for night: int in 4:
		GameClock.advance_minutes(1440)
		await t.physics_frames(2)
	t.eq(_pickups(farm).size(), 0, "four nights, nobody fed, no product at all")
	t.eq(_count("collected:"), 0, "nothing collected")
	for animal_name: String in NAMES:
		t.eq(_animal(farm, animal_name).days_fed, 0, "%s has no fed days" % animal_name)
	farm.queue_free()


func test_a_cow_gives_milk_and_a_dog_only_barks(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var cow := _animal(farm, "Cow_2")
	var dog := _animal(farm, "Dog_1")
	farmer.tools.select(&"hand")
	t.ok(await _use(farmer, cow.spot), "the cow is fed")
	t.eq(cow.state, Animal.State.EAT, "it grazes")
	t.eq(cow.player.current_animation, "an_cow_graze", "with the graze clip")
	t.ok(await _use(farmer, dog.spot), "the dog is fed")
	t.eq(dog.state, Animal.State.CHEER, "it cheers")
	t.eq(dog.player.current_animation, "an_dog_bark", "with the bark clip")
	t.eq(Inventory.count_of(HAY), 5, "one hay used")
	t.eq(Inventory.count_of(BISCUIT), 3, "one biscuit used")
	t.eq(_count("fed:"), 2, "two animals were fed")
	await t.physics_frames(90)
	t.ok(dog.state != Animal.State.CHEER, "the bark ends (state %d)" % dog.state)
	t.ok(dog.player.current_animation != "an_dog_bark", "and the clip changes")
	GameClock.advance_minutes(1440)
	await t.physics_frames(2)
	t.eq(_pickups(farm).size(), 1, "one product: the milk, and nothing from the dog")
	var spot := (_pickups(farm)[0] as Node).get_node("Spot") as ProductPickup
	t.eq(spot.item.id, &"milk", "milk")
	t.eq(spot.prompt_text, "Collect milk", "Collect milk")
	t.ok((spot.get_parent().get_node("Mesh") as MeshInstance3D).mesh is CylinderMesh, "a pail drawn with a CylinderMesh")
	t.ok(PADDOCK.has_point(Vector2(spot.get_parent().global_position.x, spot.get_parent().global_position.z)), "inside the paddock")
	t.ok(not dog.has_product() and not dog.fed, "the dog made nothing and is hungry again")
	farm.queue_free()


func test_a_slow_animal_needs_two_fed_days_for_one_product(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var cow := _animal(farm, "Cow_1")
	cow.data = cow.data.duplicate() as AnimalData
	cow.data.days_to_produce = 2
	farmer.tools.select(&"hand")
	t.ok(await _use(farmer, cow.spot), "fed on day 1")
	GameClock.advance_minutes(1440)
	await t.physics_frames(2)
	t.eq(_pickups(farm).size(), 0, "no milk after one fed day")
	t.eq(cow.days_fed, 1, "one fed day counted")
	GameClock.advance_minutes(1440)
	await t.physics_frames(2)
	t.eq(cow.days_fed, 1, "a day without feed does not count and does not reset")
	t.ok(await _use(farmer, cow.spot), "fed on day 3")
	GameClock.advance_minutes(1440)
	await t.physics_frames(2)
	t.eq(_pickups(farm).size(), 1, "milk after the second fed day")
	t.eq(cow.days_fed, 0, "the count starts again")
	farm.queue_free()


func test_the_rules_say_why_they_refuse(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var hen := _animal(farm, "Chicken_3")
	farmer.tools.select(&"hoe")
	_log.clear()
	t.ok(not hen.spot.can_interact(farmer), "the hoe does not feed")
	t.eq(_log, ["hint:Use your hands (4)."] as Array[String], "and says so")
	farmer.tools.select(&"hand")
	Inventory.remove(GRAIN, Inventory.count_of(GRAIN))
	_log.clear()
	t.ok(not hen.spot.can_interact(farmer), "no grain does not feed")
	t.eq(_log, ["hint:You have no grain."] as Array[String], "and says so")
	Inventory.add(GRAIN, 6)
	_log.clear()
	t.ok(await _use(farmer, hen.spot), "fed")
	_log.clear()
	t.ok(not hen.spot.can_interact(farmer), "a fed hen is not fed twice")
	t.eq(_log, ["hint:Chicken is fed. Come back tomorrow."] as Array[String], "and says so")
	t.eq(Inventory.count_of(GRAIN), 5, "no grain was used by the refusals")
	_log.clear()
	farmer.tools.select(&"seeds")
	GameClock.advance_minutes(1440)
	await t.physics_frames(2)
	var egg_spot := (_pickups(farm)[0] as Node).get_node("Spot") as ProductPickup
	_log.clear()
	t.ok(not egg_spot.can_interact(farmer), "seeds do not collect an egg")
	t.eq(_log, ["hint:Use your hands (4)."] as Array[String], "the egg says so too")
	farm.queue_free()


func test_a_click_walks_to_the_chicken_and_feeds_it(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var controller := farm.get_node("Farmer/InteractionController") as InteractionController
	var hen := _animal(farm, "Chicken_1")
	farmer.tools.select(&"hand")
	farmer.global_position = Vector3(-14.0, 0.0, 0.2)
	await t.physics_frames(2)
	_look_at(farm, hen.global_position)
	await t.physics_frames(2)
	var aim: Vector2 = _screen(farm, hen.global_position + Vector3(0.0, 0.25, 0.0))
	t.mouse_move(aim)
	await t.frames(2)
	await t.physics_frames(4)
	t.eq(controller.hovered, hen.spot, "the ray finds the chicken")
	t.eq(controller.label.text, "Feed chicken", "the prompt says Feed chicken")
	_log.clear()
	await t.click(aim)
	var waited: int = 0
	while not hen.fed and waited < 1800:
		await t.physics_frames(1)
		waited += 1
	t.ok(hen.fed, "the farmer walked over and fed the chicken (%d physics frames)" % waited)
	t.eq(_count("fed:"), 1, "animal_fed fired once")
	t.eq(_log.filter(func(l: String) -> bool: return l.begins_with("removed:")), ["removed:grain:1"], "the bag told the bus once: one grain")
	t.ok(Vector2(farmer.global_position.x - hen.global_position.x, farmer.global_position.z - hen.global_position.z).length() <= hen.spot.interact_range + 0.2, "the farmer stands within reach")
	t.eq(hen.state, Animal.State.EAT, "the chicken pecks")
	GameClock.advance_minutes(1440)
	await t.physics_frames(2)
	var egg := _pickups(farm)[0] as Node3D
	_look_at(farm, egg.global_position)
	await t.physics_frames(2)
	var egg_aim: Vector2 = _screen(farm, egg.global_position + Vector3(0.0, 0.12, 0.0))
	t.mouse_move(egg_aim)
	await t.frames(2)
	await t.physics_frames(4)
	t.eq(controller.label.text, "Collect egg", "the prompt over the egg")
	_log.clear()
	await t.click(egg_aim)
	waited = 0
	while _count("collected:") == 0 and waited < 1800:
		await t.physics_frames(1)
		waited += 1
	t.eq(_count("collected:"), 1, "a click on the egg collected it once (%d frames)" % waited)
	await t.frames(2)
	t.eq(_pickups(farm).size(), 0, "the egg is gone")
	farm.queue_free()


func test_the_bag_holds_the_feed_and_the_eggs(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	farmer.tools.select(&"hand")
	t.eq(Inventory.count_of(GRAIN), 6, "the grain at the start")
	t.eq(Inventory.count_of(EGG), 0, "no egg yet")
	await _use(farmer, _animal(farm, "Chicken_1").spot)
	await _use(farmer, _animal(farm, "Chicken_2").spot)
	t.eq(Inventory.count_of(GRAIN), 4, "two grain gone")
	GameClock.advance_minutes(1440)
	await t.physics_frames(2)
	for egg: Node in _pickups(farm):
		await _use(farmer, egg.get_node("Spot") as Interactable)
	await t.frames(2)
	t.eq(Inventory.count_of(EGG), 2, "two eggs in the bag")
	t.eq(Inventory.count_of(GRAIN), 4, "the grain is not refilled")
	farm.queue_free()


func test_the_navigation_mesh_is_the_one_of_chapter_24(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var mesh: NavigationMesh = (farm.get_node("World") as NavigationRegion3D).navigation_mesh
	t.eq(mesh.get_polygon_count(), 511, "the mesh was not baked again: 511 polygons")
	t.eq(farm.get_node("World").find_children("*", "CharacterBody3D", true, false).size(), 0, "the animals are not part of the baked World")
	farm.queue_free()
