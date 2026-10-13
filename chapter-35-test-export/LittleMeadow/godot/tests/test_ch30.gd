extends Node
## Chapter 30: the clock that runs by itself, the light of the day, the weather and the effects.
## Time is simulated: the tests call GameClock._process() with a made-up delta, or advance_minutes(),
## so nothing waits for real seconds. The physics clock is sped up like in Chapter 25.

const FARM: String = "res://scenes/world/farm.tscn"
const PROBE := Vector3(0.5, 0.0, 12.0)
const TICKS: int = 480
const SPEEDUP: float = 8.0
const CARROT: CropData = preload("res://resources/crops/carrot.tres")
const GRAIN: ItemData = preload("res://resources/items/grain.tres")
const EGG: ItemData = preload("res://resources/items/egg.tres")

var _weather_log: Array[int] = []
var _days: Array[int] = []


func before_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = TICKS
	Engine.time_scale = SPEEDUP
	GameClock.running = false
	GameClock.paused = false
	GameClock.speed = 1.0
	# A farm left over from another test file would add its own effects and its own weather.
	for node: Node in Engine.get_main_loop().root.get_children():
		if node.scene_file_path == FARM:
			node.free()
	GameClock.set_time(1, 360)
	Inventory.clear()
	Inventory.give_starting_items()
	Fx.active = 0
	_weather_log.clear()
	_days.clear()
	if not Events.weather_changed.is_connected(_on_weather):
		Events.weather_changed.connect(_on_weather)
		Events.day_started.connect(_on_day)


func after_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	GameClock.running = false
	Input.action_release("move_run")


func _on_weather(state: Weather.State) -> void:
	_weather_log.append(state)


func _on_day(day: int) -> void:
	_days.append(day)


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


func _effects(farm: Node) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in farm.get_tree().get_nodes_in_group(&"fx"):
		if node.is_inside_tree() and not node.is_queued_for_deletion():
			found.append(node)
	return found


func _clear_effects(farm: Node) -> void:
	for node: Node in farm.get_tree().get_nodes_in_group(&"fx"):
		node.free()
	Fx.active = 0


func _use(farmer: Farmer, spot: Interactable, tool_name: StringName) -> bool:
	farmer.tools.select(tool_name)
	if not spot.can_interact(farmer):
		return false
	if spot.action_name != "":
		farmer.animation.play_action(StringName(spot.action_name))
	await spot.interact(farmer)
	return true


## A day with each weather, found by asking the seed.
func _day_with(weather: Weather, wanted: Weather.State) -> int:
	for day: int in range(2, 400):
		if weather.state_for_day(day) == wanted:
			return day
	return -1


# ---------------------------------------------------------------- the clock

func test_the_clock_turns_real_seconds_into_game_minutes(t: Variant) -> void:
	GameClock.running = true
	GameClock._process(30.0)
	t.eq(GameClock.time_text(), "07:00", "30 real seconds are 60 game minutes")
	GameClock._process(0.25)
	t.eq(GameClock.minute_of_day, 420, "a quarter of a second is half a minute, not yet a minute")
	t.approx(GameClock.minute_float(), 420.5, 0.0001, "minute_float() keeps the half minute for smooth light")
	GameClock._process(0.25)
	t.eq(GameClock.minute_of_day, 421, "the two halves make a whole minute")
	t.approx(GameClock.minute_float(), 421.0, 0.0001, "and nothing is left over")
	GameClock.speed = 2.0
	GameClock._process(10.0)
	t.eq(GameClock.minute_of_day, 461, "speed 2 doubles the pace: 10 s are 40 minutes")


func test_a_stopped_or_paused_clock_stands_still(t: Variant) -> void:
	GameClock.running = false
	GameClock._process(100.0)
	t.eq(GameClock.minute_of_day, 360, "running = false: no change")
	GameClock.running = true
	GameClock.paused = true
	GameClock._process(100.0)
	t.eq(GameClock.minute_of_day, 360, "paused: no change")
	GameClock.paused = false
	GameClock._process(1.0)
	t.eq(GameClock.minute_of_day, 362, "unpaused: it moves again")


func test_the_clock_runs_by_itself_in_the_tree(t: Variant) -> void:
	await t.frames(2)
	GameClock.running = true
	var start: int = GameClock.minute_of_day
	await t.secs(1.0)
	GameClock.running = false
	t.ok(GameClock.minute_of_day > start, "after a second of game time the clock moved (%d to %d)" % [start, GameClock.minute_of_day])


func test_a_new_day_is_announced_once_and_the_hours_follow(t: Variant) -> void:
	GameClock.running = true
	GameClock.minute_of_day = 23 * 60 + 58
	for i: int in 40:
		GameClock._process(0.5)
	t.eq(_days, [2] as Array[int], "day_started fired once while the clock crossed midnight")
	t.eq(GameClock.day, 2, "day 2")
	t.eq(GameClock.minute_of_day, 23 * 60 + 58 + 40 - 1440, "and the minutes carried over")


func test_growth_and_products_happen_once_per_new_day(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var plot := _plot(farm, 0, 0)
	plot.crop = CARROT
	plot.state = SoilPlot.State.WATERED
	plot.days_watered = 0
	plot.stage = 0
	var hen := farm.get_node("Animals/Chicken_2") as Animal
	t.ok(await _use(farmer, hen.spot, &"hand"), "the hen is fed")
	GameClock.running = true
	GameClock.minute_of_day = 1439 * 1
	GameClock.speed = 1.0
	for i: int in 20:
		GameClock._process(0.5)
	t.eq(GameClock.day, 2, "midnight passed once")
	t.eq(plot.days_watered + plot.stage * CARROT.days_per_stage, 1, "the crop grew exactly one day")
	await t.physics_frames(2)
	t.eq(farm.get_tree().get_nodes_in_group(&"pickups").size(), 1, "the hen laid exactly one egg")
	farm.queue_free()


func test_the_sleep_door_still_ends_the_day_at_the_next_morning(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	GameClock.running = true
	GameClock.minute_of_day = 14 * 60
	(farm.get_node("World/Buildings/Farmhouse/Door") as SleepSpot).interact(farmer)
	await t.physics_frames(2)
	t.eq(GameClock.day, 2, "one new day")
	t.eq(GameClock.time_text(), "06:00", "06:00")
	farm.queue_free()


# ---------------------------------------------------------------- the weather

func test_the_weather_of_a_day_depends_only_on_the_seed_and_the_day(t: Variant) -> void:
	var weather := (load("res://scenes/fx/weather.tscn") as PackedScene).instantiate() as Weather
	t.add(weather)
	await t.frames(2)
	t.eq(weather.state_for_day(1), Weather.State.CLEAR, "day 1 is always clear")
	var first: Array[int] = []
	var second: Array[int] = []
	for day: int in range(2, 60):
		first.append(weather.state_for_day(day))
		second.append(weather.state_for_day(day))
	t.eq(first, second, "asking twice gives the same answers")
	weather.world_seed = 7
	var other: Array[int] = []
	for day: int in range(2, 60):
		other.append(weather.state_for_day(day))
	t.ne(first, other, "another seed gives another run of days")
	weather.world_seed = 3041
	weather.free()


func test_the_weights_decide_how_often_each_weather_comes(t: Variant) -> void:
	var weather := (load("res://scenes/fx/weather.tscn") as PackedScene).instantiate() as Weather
	t.add(weather)
	await t.frames(2)
	var counts: Array[int] = [0, 0, 0]
	for day: int in range(2, 2002):
		counts[weather.state_for_day(day)] += 1
	t.ok(absf(counts[0] / 2000.0 - 0.5) < 0.05, "about half the days are clear (%d)" % counts[0])
	t.ok(absf(counts[1] / 2000.0 - 0.3) < 0.05, "about three in ten are cloudy (%d)" % counts[1])
	t.ok(absf(counts[2] / 2000.0 - 0.2) < 0.05, "about one in five is rainy (%d)" % counts[2])
	weather.weights = [0.0, 0.0, 1.0]
	t.eq(weather.state_for_day(2), Weather.State.RAIN, "weights 0, 0, 1 mean rain every day")
	weather.weights = [0.5, 0.3, 0.2]
	weather.forced = 2
	t.eq(weather.state_for_day(5), Weather.State.CLOUDY, "Forced = Cloudy overrides the roll")
	weather.free()


func test_a_new_day_rolls_the_weather_and_tells_the_bus(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var weather := farm.get_node("Weather") as Weather
	await t.frames(2)
	t.eq(weather.state, Weather.State.CLEAR, "the first day is clear")
	_weather_log.clear()
	var rainy: int = _day_with(weather, Weather.State.RAIN)
	GameClock.day = rainy - 1
	GameClock.minute_of_day = 360
	GameClock.advance_minutes(1440)
	t.eq(_weather_log.size(), 0, "the roll waits for the end of the frame")
	await t.frames(2)
	t.eq(GameClock.day, rainy, "the day the seed calls rainy")
	t.eq(_weather_log, [Weather.State.RAIN] as Array[int], "weather_changed(RAIN) fired once")
	t.eq(weather.state, Weather.State.RAIN, "and the node knows it")
	t.ok(weather.rain.emitting, "the rain falls")
	GameClock.advance_minutes(1440)
	await t.frames(2)
	t.eq(weather.state, weather.state_for_day(rainy + 1), "the next day rolls again")
	t.eq(weather.rain.emitting, weather.state == Weather.State.RAIN, "rain falls only on rainy days")
	farm.queue_free()


func test_the_rain_follows_the_farmer(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var weather := farm.get_node("Weather") as Weather
	var farmer := farm.get_node("Farmer") as Farmer
	farmer.global_position = Vector3(4.0, 0.0, 3.0)
	await t.frames(2)
	t.vec_approx(weather.rain.global_position, farmer.global_position + Vector3(0.0, weather.rain_height, 0.0), 0.01, "the rain stands above the farmer")
	farmer.global_position = Vector3(-6.0, 0.0, 8.0)
	await t.frames(2)
	t.vec_approx(weather.rain.global_position, farmer.global_position + Vector3(0.0, weather.rain_height, 0.0), 0.01, "and moves with the farmer")
	farm.queue_free()


func test_rain_waters_planted_crops_and_leaves_the_rest_alone(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var weather := farm.get_node("Weather") as Weather
	var planted := _plot(farm, 0, 0)
	var bare := _plot(farm, 1, 0)
	var tilled := _plot(farm, 2, 0)
	var ripe := _plot(farm, 3, 0)
	planted.crop = CARROT
	planted.state = SoilPlot.State.PLANTED
	tilled.state = SoilPlot.State.TILLED
	ripe.crop = CARROT
	ripe.state = SoilPlot.State.RIPE
	weather.set_state(Weather.State.CLOUDY)
	t.eq(planted.state, SoilPlot.State.PLANTED, "clouds do not water")
	weather.set_state(Weather.State.RAIN)
	t.eq(planted.state, SoilPlot.State.WATERED, "rain waters the planted crop")
	t.eq(bare.state, SoilPlot.State.EMPTY, "bare ground stays bare")
	t.eq(tilled.state, SoilPlot.State.TILLED, "tilled ground without a seed stays as it is")
	t.eq(ripe.state, SoilPlot.State.RIPE, "a ripe crop stays ripe")
	var days: int = planted.days_watered
	GameClock.advance_minutes(1440)
	t.ok(planted.days_watered == days + 1 or planted.stage > 0 or planted.state == SoilPlot.State.RIPE, "the rained-on crop grew in the night")
	farm.queue_free()


func test_the_hud_shows_the_weather(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var weather := farm.get_node("Weather") as Weather
	var hud := farm.get_node("Hud") as Hud
	t.ok(hud.has_node("Root/TopBar/TopMargin/TopRow/WeatherLabel"), "the HUD has a WeatherLabel")
	await t.frames(2)
	t.eq(hud.weather_label.text, "Clear", "day 1 says Clear")
	weather.set_state(Weather.State.RAIN)
	t.eq(hud.weather_label.text, "Rain", "rain says Rain")
	weather.set_state(Weather.State.CLOUDY)
	t.eq(hud.weather_label.text, "Cloudy", "clouds say Cloudy")
	farm.queue_free()


# ---------------------------------------------------------------- the light

func _daynight(farm: Node) -> DayNight:
	return farm.get_node("DayNight") as DayNight


func test_the_light_follows_the_hour(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var dn := _daynight(farm)
	var sun := farm.get_node("Sun") as DirectionalLight3D
	var moon := farm.get_node("Moon") as DirectionalLight3D
	dn.apply(12.0 * 60.0)
	t.approx(sun.light_energy, 1.0, 0.02, "noon: full sun")
	t.ok(sun.visible, "the sun is on at noon")
	t.ok(not moon.visible, "the moon is off at noon")
	t.ok((-sun.global_basis.z).y < -0.5, "the noon sun shines steeply down")
	dn.apply(6.0 * 60.0)
	t.ok(sun.light_energy > 0.4 and sun.light_energy < 0.8, "06:00: a low sun (%.2f)" % sun.light_energy)
	t.ok(sun.light_color.r > sun.light_color.b, "the morning light is warm")
	dn.apply(18.0 * 60.0)
	t.ok(sun.light_energy > 0.4 and sun.light_energy < 0.8, "18:00: a low sun again (%.2f)" % sun.light_energy)
	t.ok(sun.light_color.r > sun.light_color.b, "the evening light is warm")
	dn.apply(21.0 * 60.0)
	t.ok(not sun.visible, "21:00: the sun is off")
	t.ok(moon.visible, "the moon is on")
	t.ok(moon.light_color.b > moon.light_color.r, "and it is blue")
	t.ok(moon.light_energy < 0.6 and moon.light_energy > 0.05, "but dim (%.2f)" % moon.light_energy)
	dn.apply(0.0)
	t.ok(not sun.visible and moon.visible, "midnight: only the moon")
	t.ok((-moon.global_basis.z).y < -0.3, "the moon shines down from the sky")
	farm.queue_free()


func test_the_light_changes_smoothly(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var dn := _daynight(farm)
	var sun := farm.get_node("Sun") as DirectionalLight3D
	var moon := farm.get_node("Moon") as DirectionalLight3D
	var worst: float = 0.0
	var last: float = -1.0
	for minute: int in range(0, 1440, 5):
		dn.apply(float(minute))
		var total: float = sun.light_energy + moon.light_energy
		if last >= 0.0:
			worst = maxf(worst, absf(total - last))
		last = total
	t.ok(worst < 0.2, "no jump bigger than 0.2 in 5 minutes (worst %.3f)" % worst)
	farm.queue_free()


func test_the_shadows_keep_working_day_and_night(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var sun := farm.get_node("Sun") as DirectionalLight3D
	var moon := farm.get_node("Moon") as DirectionalLight3D
	t.ok(sun.shadow_enabled, "the sun casts shadows")
	t.ok(moon.shadow_enabled, "so does the moon")
	t.ok(not (sun.visible and moon.visible and sun.light_energy > 0.1 and moon.light_energy > 0.1), "never two strong shadow lights at once")
	farm.queue_free()


func test_the_sky_and_ambient_light_follow_the_hour(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var dn := _daynight(farm)
	var environment: Environment = (farm.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky: ProceduralSkyMaterial = environment.sky.sky_material
	dn.apply(12.0 * 60.0)
	var noon_top: Color = sky.sky_top_color
	var noon_ambient: float = environment.ambient_light_energy
	var noon_shade: Color = environment.ambient_light_color
	dn.apply(0.0)
	t.ok(sky.sky_top_color.get_luminance() < noon_top.get_luminance() * 0.5, "the night sky is much darker than the noon sky")
	t.ok(sky.sky_top_color.b > sky.sky_top_color.r, "and bluish")
	t.ok(environment.ambient_light_energy < noon_ambient, "the shade is weaker at night")
	t.ok(environment.ambient_light_color.b > environment.ambient_light_color.r, "and blue")
	t.ok(environment.ambient_light_color.b - environment.ambient_light_color.r > noon_shade.b - noon_shade.r, "bluer than at noon")
	t.eq(environment.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR, "the shade has its own colour, it does not wait for the sky")
	farm.queue_free()


func test_weather_dims_the_light_and_thickens_the_fog(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var dn := _daynight(farm)
	var weather := farm.get_node("Weather") as Weather
	var sun := farm.get_node("Sun") as DirectionalLight3D
	var environment: Environment = (farm.get_node("WorldEnvironment") as WorldEnvironment).environment
	weather.set_state(Weather.State.CLEAR)
	dn.snap()
	dn.apply(12.0 * 60.0)
	var clear_energy: float = sun.light_energy
	t.ok(not environment.fog_enabled, "no fog on a clear day")
	weather.set_state(Weather.State.CLOUDY)
	dn.snap()
	dn.apply(12.0 * 60.0)
	var cloudy_energy: float = sun.light_energy
	weather.set_state(Weather.State.RAIN)
	dn.snap()
	dn.apply(12.0 * 60.0)
	t.ok(cloudy_energy < clear_energy and sun.light_energy < cloudy_energy, "clear > cloudy > rain")
	t.ok(environment.fog_enabled and environment.fog_density > 0.005, "rain brings fog")
	weather.set_state(Weather.State.CLEAR)
	dn.snap()
	t.ok(not environment.fog_enabled, "and the fog goes away again")
	farm.queue_free()


func test_the_curves_are_proper_resources(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var dn := _daynight(farm)
	t.eq(dn.sun_energy.get_point_count(), 9, "the sun curve has nine points, set by hand in the editor")
	t.approx(dn.sun_energy.sample_baked(0.5), 1.0, 0.01, "full at noon")
	t.approx(dn.sun_energy.sample_baked(0.0), 0.0, 0.001, "zero at midnight")
	t.eq(dn.sun_color.get_point_count(), 6, "the sun colour has six stops")
	t.eq(dn.sky_top.get_point_count(), 12, "the sky has 12 stops, two hours apart")
	t.eq(dn.sky_horizon.get_point_count(), 12, "so does the horizon")
	t.eq(dn.ambient_color.get_point_count(), 12, "the shade colour has 12 stops")
	t.ok(dn.ambient_energy.sample_baked(0.5) > dn.ambient_energy.sample_baked(0.0), "more shade light at noon than at midnight")
	farm.queue_free()


# ---------------------------------------------------------------- the effects

func test_fx_spawn_starts_an_effect_that_frees_itself(t: Variant) -> void:
	var farm: Node = await _farm(t)
	_clear_effects(farm)
	var puff: Node3D = Fx.spawn(farm, &"dust", Vector3(2.0, 0.0, 3.0))
	t.not_null(puff, "spawn returns the new effect")
	t.vec_approx(puff.global_position, Vector3(2.0, 0.0, 3.0), 0.001, "it stands where it was told")
	t.eq(Fx.active, 1, "one effect is running")
	t.ok(puff.is_in_group(&"fx"), "it is in the group fx")
	var burst := puff.get_node("Burst") as GPUParticles3D
	await t.physics_frames(2)
	t.ok(burst.emitting, "the particles are emitting")
	var waited: float = 0.0
	while is_instance_valid(puff) and not puff.is_queued_for_deletion() and waited < 8.0:
		await t.secs(0.2)
		waited += 0.2
	t.ok(not is_instance_valid(puff) or puff.is_queued_for_deletion(), "the Timer freed the effect")
	await t.frames(2)
	t.eq(Fx.active, 0, "and the counter is back to zero")
	farm.queue_free()


func test_fx_spawn_refuses_unknown_names_and_too_many(t: Variant) -> void:
	var farm: Node = await _farm(t)
	_clear_effects(farm)
	t.eq(Fx.spawn(farm, &"fireworks", Vector3.ZERO), null, "an unknown name gives null")
	for i: int in Fx.MAX_ACTIVE:
		Fx.spawn(farm, &"sparkle", Vector3.ZERO)
	t.eq(Fx.active, Fx.MAX_ACTIVE, "the cap is reached")
	t.eq(Fx.spawn(farm, &"sparkle", Vector3.ZERO), null, "one more is refused")
	_clear_effects(farm)
	farm.queue_free()


func test_every_effect_scene_uses_the_flipbook_in_the_same_way(t: Variant) -> void:
	for scene_path: String in [
		"res://scenes/fx/dust_puff.tscn", "res://scenes/fx/water_splash.tscn", "res://scenes/fx/sparkle.tscn",
		"res://scenes/fx/chimney_smoke.tscn",
	]:
		var root: Node = (load(scene_path) as PackedScene).instantiate()
		var particles: GPUParticles3D = null
		for child: Node in root.get_children():
			if child is GPUParticles3D:
				particles = child
		t.not_null(particles, "%s holds a GPUParticles3D" % scene_path)
		if particles == null:
			continue
		var mesh := particles.draw_pass_1 as QuadMesh
		var material := mesh.material as StandardMaterial3D
		t.eq(material.billboard_mode, BaseMaterial3D.BILLBOARD_PARTICLES, "%s: particle billboard" % scene_path)
		t.eq(material.particles_anim_h_frames, 4, "%s: four columns" % scene_path)
		t.eq(material.particles_anim_v_frames, 4, "%s: four rows" % scene_path)
		t.ok(not material.particles_anim_loop, "%s: the 16 frames play once" % scene_path)
		t.eq(particles.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s: no shadow from a sprite" % scene_path)
		var sheet: Texture2D = material.albedo_texture
		t.ok(sheet.get_width() % 4 == 0 and sheet.get_height() % 4 == 0, "%s: the sheet divides into 4 x 4" % scene_path)
		root.free()


func test_the_effect_scenes_clean_up_after_themselves(t: Variant) -> void:
	for scene_path: String in [
		"res://scenes/fx/dust_puff.tscn", "res://scenes/fx/water_splash.tscn", "res://scenes/fx/sparkle.tscn",
	]:
		var root: Node = (load(scene_path) as PackedScene).instantiate()
		var life := root.get_node("Life") as Timer
		var burst := root.get_node("Burst") as GPUParticles3D
		t.ok(life.autostart and life.one_shot, "%s: the Timer starts itself and runs once" % scene_path)
		t.ok(life.wait_time >= burst.lifetime, "%s: the Timer outlasts the particles" % scene_path)
		t.ok(burst.one_shot, "%s: one burst" % scene_path)
		t.eq(life.get_signal_connection_list(&"timeout").size(), 1, "%s: timeout is connected" % scene_path)
		root.free()


func test_arriving_starts_dust(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	_clear_effects(farm)
	farmer.arrived.emit(Vector3(1.0, 0.0, 1.0))
	t.eq(_effects(farm).size(), 1, "one puff on arrival")
	t.vec_approx(_effects(farm)[0].global_position, Vector3(1.0, 0.0, 1.0), 0.001, "where the farmer stopped")
	_clear_effects(farm)
	farm.queue_free()


func test_starting_to_run_starts_dust_once(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	await t.physics_frames(5)
	_clear_effects(farm)
	Input.action_press("move_run")
	farmer.walk_to(Vector3(4.0, 0.0, 12.0))
	var frames: int = 0
	while farmer.speed <= farmer.run_threshold and frames < 600:
		await t.physics_frames(1)
		frames += 1
	t.ok(farmer.speed > farmer.run_threshold, "the farmer is running (%d frames)" % frames)
	t.eq(_effects(farm).size(), 1, "one puff at the start of the run")
	await t.physics_frames(30)
	var after: int = _effects(farm).size()
	t.ok(after <= 2, "running on does not make a puff every frame (%d)" % after)
	_clear_effects(farm)
	farm.queue_free()


func test_watering_makes_a_splash_but_other_work_does_not(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var plot := _plot(farm, 0, 1)
	_clear_effects(farm)
	plot.state = SoilPlot.State.TILLED
	Events.interaction_finished.emit(plot, farmer)
	t.eq(_effects(farm).size(), 0, "tilling makes no splash")
	plot.crop = CARROT
	plot.state = SoilPlot.State.WATERED
	Events.interaction_finished.emit(plot, farmer)
	t.eq(_effects(farm).size(), 1, "watering does")
	t.vec_approx(_effects(farm)[0].global_position, plot.global_position + Vector3(0.0, 0.1, 0.0), 0.001, "on the plot")
	_clear_effects(farm)
	farm.queue_free()


func test_a_crop_that_ripens_sparkles_once(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var plot := _plot(farm, 0, 2)
	_clear_effects(farm)
	plot.crop = CARROT
	plot.stage = CARROT.last_stage() - 1
	plot.days_watered = CARROT.days_per_stage - 1
	plot.state = SoilPlot.State.WATERED
	GameClock.advance_minutes(1440)
	t.eq(plot.state, SoilPlot.State.RIPE, "the crop is ripe")
	t.eq(_effects(farm).size(), 1, "one sparkle")
	plot.changed.emit()
	t.eq(_effects(farm).size(), 1, "a second change while ripe does not add another")
	_clear_effects(farm)
	farm.queue_free()


func test_a_collected_product_sparkles(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var hen := farm.get_node("Animals/Chicken_2") as Animal
	_clear_effects(farm)
	Events.product_collected.emit(EGG, hen)
	t.eq(_effects(farm).size(), 1, "one sparkle at the hen")
	_clear_effects(farm)
	farm.queue_free()


func test_the_farm_keeps_its_particle_budget(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var systems: int = 0
	var amount: int = 0
	var stack: Array[Node] = [farm]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is GPUParticles3D:
			systems += 1
			amount += (node as GPUParticles3D).amount
	t.ok(systems <= 8, "at most 8 particle systems wait in the farm (%d)" % systems)
	t.ok(amount <= 2000, "and at most 2000 particles in all (%d)" % amount)
	t.eq(farm.get_node("World/Buildings/Farmhouse").get_children().filter(func(n: Node) -> bool: return n.name == "ChimneySmoke").size(), 1, "the farmhouse has its chimney smoke")
	t.eq(farm.get_node("Effects").get_child_count(), 3, "three tree tops drop leaves")
	farm.queue_free()


func test_the_sheets_are_imported_without_compression(t: Variant) -> void:
	for sheet: String in ["vfx_dust_puff", "vfx_water_splash", "vfx_sparkle"]:
		var config := ConfigFile.new()
		config.load("res://assets/textures/%s.png.import" % sheet)
		t.eq(config.get_value("params", "compress/mode"), 0, "%s: Lossless" % sheet)
		t.eq(config.get_value("params", "mipmaps/generate"), true, "%s: mipmaps" % sheet)
