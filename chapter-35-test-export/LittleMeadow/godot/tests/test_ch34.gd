extends Node

const FARM: String = "res://scenes/world/farm.tscn"
const TITLE: String = "res://scenes/ui/title.tscn"
const ITEMS: String = "res://resources/items/"
const SAMPLE: String = "res://tests/data/sample_slot.json"
const TEST_FOLDER: String = "user://saves_test"
const REAL_FOLDER: String = "user://saves"
const TEST_SETTINGS: String = "user://settings_test.cfg"
const REAL_SETTINGS: String = "user://settings.cfg"
const AUDIO_FOLDER: String = "res://assets/audio/"
const PROBE := Vector3(0.5, 0.0, 12.0)
const TICKS: int = 480
const SPEEDUP: float = 8.0
const SOUND_NAMES: Array[StringName] = [
	&"ui_click", &"ui_tick", &"ui_open", &"ui_close", &"coin", &"buy", &"sell", &"unlock", &"pickup", &"harvest",
	&"feed", &"hoe", &"seed", &"water", &"hammer", &"crunch", &"denied", &"footstep", &"chime", &"save", &"load",
	&"rain", &"birds", &"crickets", &"music_day", &"music_night",
]

var _heard: Array = []
var _hints: Array[String] = []
var _folder_before: String = ""
var _real_saves_before: Array[String] = []
var _real_settings_before: String = ""
var _settings_path_before: String = ""


func before_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = TICKS
	Engine.time_scale = SPEEDUP
	GameClock.running = false
	GameClock.paused = false
	GameClock.set_time(1, 360)
	get_tree().paused = false
	Inventory.clear()
	Inventory.give_starting_items()
	Economy.money = Economy.START_MONEY
	Economy.ledger.clear()
	var root: Node = Engine.get_main_loop().root
	for node: Node in root.get_children():
		if node.scene_file_path == FARM or node.scene_file_path == TITLE:
			node.free()
	Engine.get_main_loop().current_scene = null
	for node: Node in Engine.get_main_loop().get_nodes_in_group(&"fx"):
		node.free()
	Fx.active = 0
	if _folder_before == "":
		_folder_before = SaveSystem.folder
		_settings_path_before = Settings.path
	_real_saves_before = _listing(REAL_FOLDER)
	_real_settings_before = _fingerprint(REAL_SETTINGS)
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
	_heard.clear()
	_hints.clear()
	AudioBus.min_gap_msec = 0
	AudioBus.missing.clear()
	Flow.fade_seconds = 0.0
	Flow.busy = false
	Flow.last_message = ""
	if not AudioBus.requested.is_connected(_on_heard):
		AudioBus.requested.connect(_on_heard)
		Events.hint_shown.connect(_on_hint)


func after_each(t: Variant) -> void:
	get_tree().paused = false
	var root: Node = Engine.get_main_loop().root
	for node: Node in root.get_children():
		if node.scene_file_path == FARM or node.scene_file_path == TITLE:
			node.free()
	Engine.get_main_loop().current_scene = null
	_wipe(TEST_FOLDER)
	DirAccess.remove_absolute(TEST_SETTINGS)
	SaveSystem.folder = _folder_before
	SaveSystem.autosave_enabled = false
	SaveSystem.current_slot = 1
	t.eq(_listing(REAL_FOLDER), _real_saves_before, "the real save folder was not touched")
	t.eq(_fingerprint(REAL_SETTINGS), _real_settings_before, "the real settings file was not touched")
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
	Events.hour_changed.emit(12)


func _on_heard(sound: StringName, position: Variant) -> void:
	_heard.append([sound, position])


func _on_hint(text: String) -> void:
	_hints.append(text)


func _names() -> Array[StringName]:
	var found: Array[StringName] = []
	for entry: Array in _heard:
		found.append(entry[0])
	return found


func _listing(folder: String) -> Array[String]:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(folder):
		return found
	for file: String in DirAccess.get_files_at(folder):
		found.append("%s:%d:%d" % [file, FileAccess.get_file_as_bytes(folder + "/" + file).size(), FileAccess.get_modified_time(folder + "/" + file)])
	return found


func _fingerprint(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "absent"
	return "%d:%d" % [FileAccess.get_file_as_bytes(path).size(), FileAccess.get_modified_time(path)]


func _wipe(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + "/" + file)
	DirAccess.remove_absolute(folder)


func _write_sample(slot: int, saved_at: String) -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.folder)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE))
	data["saved_at"] = saved_at
	var file: FileAccess = FileAccess.open(SaveSystem.path_for(slot), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", false))
	file.close()


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


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


func _find(node: Node, type: Variant) -> Node:
	for child: Node in node.get_children():
		if is_instance_of(child, type):
			return child
		var deeper: Node = _find(child, type)
		if deeper != null:
			return deeper
	return null


func _bump(t: Variant, minutes: int) -> void:
	GameClock.running = true
	await t.frames(minutes)
	GameClock.running = false


func _esc(t: Variant) -> void:
	t.key(KEY_ESCAPE, true)
	await t.frames(2)
	t.key(KEY_ESCAPE, false)
	await t.frames(2)


func _spoken(emit: Callable, expected: Array[StringName], label: String, t: Variant) -> void:
	_heard.clear()
	emit.call()
	t.eq(_names(), expected, label)


# ---- settings -------------------------------------------------------------------------------------------------------


func test_tests_use_their_own_files(t: Variant) -> void:
	t.eq(Settings.path, TEST_SETTINGS, "the test settings path is in use")
	t.eq(SaveSystem.folder, TEST_FOLDER, "the test save folder is in use")
	t.ok(Settings.FILE != TEST_SETTINGS, "and it is not the real one")


func test_settings_start_at_the_defaults(t: Variant) -> void:
	t.approx(Settings.master, 0.8, 0.0001, "master")
	t.approx(Settings.music, 0.6, 0.0001, "music")
	t.approx(Settings.sfx, 0.8, 0.0001, "sfx")
	t.approx(Settings.ambience, 0.7, 0.0001, "ambience")
	t.ok(not Settings.muted and not Settings.fullscreen and not Settings.show_fps, "the switches are off")


func test_settings_round_trip_through_the_file(t: Variant) -> void:
	Settings.master = 0.35
	Settings.music = 0.0
	Settings.sfx = 1.0
	Settings.ambience = 0.5
	Settings.muted = true
	Settings.show_fps = true
	t.ok(Settings.save_file(), "saved")
	t.ok(FileAccess.file_exists(TEST_SETTINGS), "the file exists")
	Settings.reset()
	t.approx(Settings.master, 0.8, 0.0001, "reset went back to the default")
	t.ok(Settings.load_file(), "loaded")
	t.approx(Settings.master, 0.35, 0.0001, "master came back")
	t.approx(Settings.music, 0.0, 0.0001, "music came back")
	t.approx(Settings.sfx, 1.0, 0.0001, "sfx came back")
	t.approx(Settings.ambience, 0.5, 0.0001, "ambience came back")
	t.ok(Settings.muted and Settings.show_fps and not Settings.fullscreen, "the switches came back")
	var file := ConfigFile.new()
	t.eq(file.load(TEST_SETTINGS), OK, "it is a real ConfigFile")
	t.approx(float(file.get_value("audio", "master")), 0.35, 0.0001, "master sits in the audio section")
	t.eq(file.get_value("display", "show_fps"), true, "show_fps sits in the display section")


func test_settings_clamp_what_the_file_says(t: Variant) -> void:
	_write_text(TEST_SETTINGS, "[audio]\nmaster=2.5\nmusic=-3.0\nsfx=0.25\nambience=1\nmuted=true\n")
	t.ok(Settings.load_file(), "loaded")
	t.approx(Settings.master, 1.0, 0.0001, "too loud is clamped to 1")
	t.approx(Settings.music, 0.0, 0.0001, "negative is clamped to 0")
	t.approx(Settings.sfx, 0.25, 0.0001, "a normal value stays")
	t.approx(Settings.ambience, 1.0, 0.0001, "an integer is accepted")
	t.ok(Settings.muted, "and the switch stays")
	Settings.set_volume("sfx", 7.0)
	t.approx(Settings.sfx, 1.0, 0.0001, "set_volume clamps too")
	Settings.set_volume("sfx", -1.0)
	t.approx(Settings.sfx, 0.0, 0.0001, "and clamps below")


func test_settings_fall_back_to_defaults_when_the_file_is_missing_or_wrong(t: Variant) -> void:
	Settings.master = 0.1
	t.ok(not Settings.load_file(), "a missing file is reported")
	t.approx(Settings.master, 0.8, 0.0001, "and the defaults are back")
	_write_text(TEST_SETTINGS, "[audio]\nmaster=@@@\n")
	Settings.master = 0.1
	t.ok(not Settings.load_file(), "a damaged file is reported")
	t.approx(Settings.master, 0.8, 0.0001, "and the defaults are back")
	_write_text(TEST_SETTINGS, "this is not a config file at all")
	Settings.master = 0.1
	Settings.load_file()
	t.approx(Settings.master, 0.8, 0.0001, "a file with nothing useful in it gives the defaults")
	_write_text(TEST_SETTINGS, "[audio]\nmaster=\"loud\"\nmusic=nan\nsfx=inf\nmuted=\"yes\"\n[display]\nfullscreen=7\n")
	t.ok(Settings.load_file(), "a readable file with wrong values loads")
	t.approx(Settings.master, 0.8, 0.0001, "text instead of a number gives the default")
	t.approx(Settings.music, 0.6, 0.0001, "nan gives the default")
	t.approx(Settings.sfx, 0.8, 0.0001, "inf gives the default")
	t.ok(not Settings.muted, "text instead of a switch gives the default")
	t.ok(not Settings.fullscreen, "a number instead of a switch gives the default")


func test_settings_are_applied_to_the_buses(t: Variant) -> void:
	for bus_name: StringName in [&"Master", &"Music", &"SFX", &"Ambience"]:
		t.ok(AudioServer.get_bus_index(bus_name) >= 0, "the %s bus exists" % bus_name)
	Settings.set_volume("music", 0.5)
	t.approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), linear_to_db(0.5), 0.01, "music 0.5 is about -6 dB")
	Settings.set_volume("sfx", 1.0)
	t.approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX")), 0.0, 0.01, "sfx 1.0 is 0 dB")
	Settings.set_volume("ambience", 0.0)
	t.ok(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Ambience")) < -60.0, "ambience 0 is silent, not minus infinity")
	t.ok(is_finite(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Ambience"))), "and finite")
	Settings.set_volume("master", 0.25)
	t.approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master")), linear_to_db(0.25), 0.01, "master 0.25")
	t.ok(not AudioServer.is_bus_mute(0), "not muted")
	Settings.muted = true
	Settings.apply()
	t.ok(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")), "mute reaches the Master bus")
	Settings.muted = false
	Settings.apply()
	t.ok(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")), "and lifts again")


func test_the_changed_signal_follows_apply(t: Variant) -> void:
	var count: Array[int] = [0]
	var listener: Callable = func() -> void: count[0] += 1
	Settings.changed.connect(listener)
	Settings.set_volume("music", 0.3)
	Settings.apply()
	Settings.changed.disconnect(listener)
	t.eq(count[0], 2, "set_volume and apply each tell the others")


# ---- the bus layout -------------------------------------------------------------------------------------------------


func test_the_bus_layout_has_four_buses_that_all_end_in_master(t: Variant) -> void:
	t.eq(AudioServer.bus_count, 4, "four buses")
	t.eq(AudioServer.get_bus_name(0), "Master", "Master is first")
	for bus_name: StringName in [&"Music", &"SFX", &"Ambience"]:
		var index: int = AudioServer.get_bus_index(bus_name)
		t.eq(AudioServer.get_bus_send(index), &"Master", "%s sends to Master" % bus_name)
	t.ok(AudioServer.get_bus_effect_count(0) >= 1, "Master has an effect")
	t.ok(AudioServer.get_bus_effect(0, 0) is AudioEffectHardLimiter, "and it is a limiter")
	t.eq(ProjectSettings.get_setting("audio/buses/default_bus_layout"), "res://default_bus_layout.tres", "the project points at the layout file")
	var layout: AudioBusLayout = load("res://default_bus_layout.tres") as AudioBusLayout
	t.not_null(layout, "the layout file loads")


# ---- sound names, bank and files --------------------------------------------------------------------------------------


func test_every_sound_name_is_in_the_bank_with_a_stream(t: Variant) -> void:
	for sound: StringName in SOUND_NAMES:
		var data: SoundData = AudioBus.BANK.find(sound)
		t.not_null(data, "%s is in the bank" % sound)
		if data != null:
			t.not_null(data.stream, "%s has a stream" % sound)
			t.ok(AudioServer.get_bus_index(data.bus) >= 0, "%s goes to a bus that exists" % sound)
	t.eq(AudioBus.BANK.ids().size(), SOUND_NAMES.size(), "the bank holds exactly these names")
	var seen: Dictionary = {}
	for sound: StringName in AudioBus.BANK.ids():
		t.ok(not seen.has(sound), "%s appears once" % sound)
		seen[sound] = true


func test_every_audio_file_exists_is_imported_and_used(t: Variant) -> void:
	var used: Dictionary = {}
	var total: int = 0
	for data: SoundData in AudioBus.BANK.sounds:
		var path: String = data.stream.resource_path
		used[path] = true
		t.ok(path.begins_with(AUDIO_FOLDER), "%s lives in assets/audio" % path)
		t.ok(FileAccess.file_exists(path), "%s exists" % path)
		t.ok(FileAccess.file_exists(path + ".import"), "%s has an .import file" % path)
		t.ok(ResourceLoader.exists(path), "%s can be loaded" % path)
		t.ok(path.ends_with(".wav") or path.ends_with(".ogg"), "%s is a wav or an ogg" % path)
	for file: String in DirAccess.get_files_at(AUDIO_FOLDER):
		if file.ends_with(".wav") or file.ends_with(".ogg"):
			t.ok(used.has(AUDIO_FOLDER + file), "%s is used by a sound" % file)
			total += FileAccess.get_file_as_bytes(AUDIO_FOLDER + file).size()
	t.ok(total > 100000 and total < 15 * 1024 * 1024, "the audio weighs %d bytes, under 15 MB" % total)
	t.ok(FileAccess.file_exists(AUDIO_FOLDER + "README_LICENSES.txt"), "the licence note is next to the sounds")
	t.ok(FileAccess.file_exists("res://assets/fonts/OFL.txt"), "the font licence is kept")


func test_loops_loop_and_one_shots_do_not(t: Variant) -> void:
	for sound: StringName in [&"rain", &"birds", &"crickets", &"music_day", &"music_night"]:
		var stream: AudioStream = AudioBus.BANK.find(sound).stream
		t.ok(stream is AudioStreamOggVorbis, "%s is an ogg" % sound)
		t.ok((stream as AudioStreamOggVorbis).loop, "%s loops" % sound)
	for sound: StringName in [&"coin", &"hammer", &"chime", &"ui_click"]:
		var stream: AudioStream = AudioBus.BANK.find(sound).stream
		t.ok(stream is AudioStreamWAV, "%s is a wav" % sound)
		t.eq((stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s plays once" % sound)


# ---- the AudioBus ---------------------------------------------------------------------------------------------------


func test_a_missing_sound_warns_once_and_does_not_crash(t: Variant) -> void:
	t.ok(not AudioBus.play(&"no_such_sound"), "play says false")
	t.ok(not AudioBus.play(&"no_such_sound", Vector3(1, 2, 3)), "also with a position")
	t.ok(not AudioBus.play(&"no_such_sound"), "and again")
	t.eq(AudioBus.missing[&"no_such_sound"], 3, "all three were counted")
	t.eq(_names(), [&"no_such_sound", &"no_such_sound", &"no_such_sound"], "every request was announced")
	t.ok(AudioBus.play(&"coin"), "a real sound still plays afterwards")
	var playing: StringName = AudioBus.music_name
	AudioBus.play_music(&"no_such_music")
	t.eq(AudioBus.music_name, playing, "an unknown music name changes nothing")


func test_a_flat_sound_and_a_placed_sound_use_different_players(t: Variant) -> void:
	for child: Node in AudioBus.get_children():
		if child is AudioStreamPlayer3D:
			(child as AudioStreamPlayer3D).stop()
	var before: int = AudioBus.pool_size()
	t.ok(AudioBus.play(&"coin"), "a flat sound")
	t.ok(AudioBus.play(&"hammer", Vector3(2, 0, 3)), "a placed sound")
	t.eq(_heard[0][1], null, "the first had no position")
	t.eq(_heard[1][1], Vector3(2, 0, 3), "the second kept its position")
	t.eq(AudioBus.pool_size(), before, "no player was added")
	var placed: int = 0
	for child: Node in AudioBus.get_children():
		if child is AudioStreamPlayer3D and (child as AudioStreamPlayer3D).playing:
			placed += 1
			t.vec_approx((child as AudioStreamPlayer3D).global_position, Vector3(2, 0, 3), 0.001, "the 3D player sits at the position")
	t.eq(placed, 1, "exactly one 3D player is busy")


func test_the_pool_is_reused_and_never_grows(t: Variant) -> void:
	var before: int = AudioBus.pool_size()
	var children: int = AudioBus.get_child_count()
	for index: int in AudioBus.POOL_FLAT + 12:
		AudioBus.play(&"ui_click")
	t.eq(AudioBus.pool_size(), before, "the pool has the same size")
	t.eq(AudioBus.get_child_count(), children, "and no nodes were added")
	t.ok(AudioBus.playing_count() <= before, "never more voices than players")
	for index: int in AudioBus.POOL_SPATIAL + 5:
		AudioBus.play(&"hammer", Vector3(index, 0, 0))
	t.eq(AudioBus.pool_size(), before, "also for placed sounds")


func test_a_quick_repeat_is_dropped(t: Variant) -> void:
	AudioBus.min_gap_msec = 10000
	AudioBus._last.erase(&"coin")
	AudioBus._last.erase(&"buy")
	t.ok(AudioBus.play(&"coin"), "the first plays")
	t.ok(not AudioBus.play(&"coin"), "the second, straight after, is dropped")
	t.ok(AudioBus.play(&"buy"), "another sound is not affected")
	AudioBus.min_gap_msec = 0
	t.ok(AudioBus.play(&"coin"), "with the gap removed it plays again")


func test_pitch_and_volume_vary_inside_the_range(t: Variant) -> void:
	var data: SoundData = AudioBus.BANK.find(&"coin")
	var pitches: Array[float] = []
	var volumes: Array[float] = []
	for index: int in 20:
		AudioBus.play(&"coin")
		var voice: AudioStreamPlayer = AudioBus._flat[AudioBus._flat.size() - 1]
		for player: Node in AudioBus._flat:
			if (player as AudioStreamPlayer).stream == data.stream and (player as AudioStreamPlayer).playing:
				voice = player as AudioStreamPlayer
		pitches.append(voice.pitch_scale)
		volumes.append(voice.volume_db)
	for pitch: float in pitches:
		t.ok(absf(pitch - 1.0) <= data.pitch_range + 0.0001, "pitch %.3f is inside the range" % pitch)
	for volume: float in volumes:
		t.ok(absf(volume - data.volume_db) <= data.volume_range + 0.0001, "volume %.2f is inside the range" % volume)
	t.ok(pitches.max() - pitches.min() > 0.0, "and it is not always the same")


func test_music_crossfades_between_two_players(t: Variant) -> void:
	AudioBus.music_name = &""
	AudioBus.play_music(&"music_day", 0.0)
	t.eq(AudioBus.music_name, &"music_day", "the name is kept")
	var first: AudioStreamPlayer = AudioBus._music[AudioBus._front]
	t.ok(first.playing, "it plays")
	t.eq(first.bus, &"Music", "on the Music bus")
	AudioBus.play_music(&"music_day", 0.0)
	t.ok(AudioBus._music[AudioBus._front] == first, "asking for the same track changes nothing")
	AudioBus.play_music(&"music_night", 0.0)
	var second: AudioStreamPlayer = AudioBus._music[AudioBus._front]
	t.ok(second != first, "the other player takes over")
	t.ok(second.playing and not first.playing, "and the old one has stopped")
	t.ok(first.volume_db <= AudioBus.SILENT_DB + 0.01, "after a fade of zero it is silent")
	AudioBus.play_music(&"music_day", 0.4)
	var third: AudioStreamPlayer = AudioBus._music[AudioBus._front]
	t.ok(third.playing and second.playing, "during a real fade both play")
	await t.secs(0.2)
	t.ok(third.volume_db > AudioBus.SILENT_DB + 1.0, "the new one is coming up")
	await t.secs(0.4)
	t.ok(not second.playing, "afterwards the old one is stopped")
	AudioBus._music[0].stop()
	AudioBus._music[1].stop()
	AudioBus.music_name = &""


func test_every_button_makes_a_click(t: Variant) -> void:
	var button := Button.new()
	t.add(button)
	await t.frames(1)
	button.pressed.emit()
	t.eq(_names(), [&"ui_click"], "a button added after the start clicks")
	_heard.clear()
	var toggle := CheckButton.new()
	t.add(toggle)
	await t.frames(1)
	toggle.pressed.emit()
	t.eq(_names(), [&"ui_click"], "a check button clicks too")
	button.free()
	toggle.free()


# ---- the hooks ------------------------------------------------------------------------------------------------------


func test_every_event_hook_asks_for_the_right_sound(t: Variant) -> void:
	_spoken(func() -> void: Events.build_removed.emit(null, 4), [&"crunch"], "build_removed", t)
	_spoken(func() -> void: Events.build_denied.emit(null, "no"), [&"denied"], "build_denied", t)
	_spoken(func() -> void: Events.trade_denied.emit("no"), [&"denied"], "trade_denied", t)
	_spoken(func() -> void: Events.save_failed.emit("no"), [&"denied"], "save_failed", t)
	_spoken(func() -> void: Events.item_bought.emit(load(ITEMS + "egg.tres") as ItemData, 1, 5), [&"buy"], "item_bought", t)
	_spoken(func() -> void: Events.item_sold.emit(load(ITEMS + "egg.tres") as ItemData, 1, 5), [&"sell"], "item_sold", t)
	_spoken(func() -> void: Events.plan_unlocked.emit(null), [&"unlock"], "plan_unlocked", t)
	_spoken(func() -> void: Events.shop_opened.emit(), [&"ui_open"], "shop_opened", t)
	_spoken(func() -> void: Events.shop_closed.emit(), [&"ui_close"], "shop_closed", t)
	_spoken(func() -> void: Events.game_saved.emit(1), [&"save"], "game_saved", t)
	_spoken(func() -> void: Events.game_loaded.emit(1), [&"load"], "game_loaded", t)
	_spoken(func() -> void: Events.tool_changed.emit(&"hoe", null), [&"ui_tick"], "tool_changed", t)
	_spoken(func() -> void: Events.build_mode_changed.emit(true), [&"ui_open"], "build mode on", t)
	_spoken(func() -> void: Events.build_mode_changed.emit(false), [&"ui_close"], "build mode off", t)
	_spoken(func() -> void: Events.money_moved.emit(5, "sold"), [&"coin"], "money in", t)
	_spoken(func() -> void: Events.money_moved.emit(-5, "bought"), [], "money out is quiet", t)
	_spoken(func() -> void: Events.hour_changed.emit(5), [&"chime"], "the five o'clock chime", t)
	_spoken(func() -> void: Events.hour_changed.emit(6), [], "no chime at six", t)
	_spoken(func() -> void: Events.hour_changed.emit(17), [], "no chime at five in the afternoon", t)


func test_the_hooks_that_have_a_place_give_it(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var plot: SoilPlot = farm.get_tree().get_nodes_in_group(&"soil_plots")[0] as SoilPlot
	var hen := farm.get_node("Animals/Chicken_1") as Animal
	var spot := Node3D.new()
	spot.position = Vector3(3, 0, 4)
	farm.add_child(spot)
	_heard.clear()
	Events.build_placed.emit(null, spot)
	t.eq(_names(), [&"hammer"], "build_placed")
	t.vec_approx(_heard[0][1], Vector3(3, 0, 4), 0.001, "at the new piece")
	_heard.clear()
	Events.crop_harvested.emit(load("res://resources/crops/carrot.tres") as CropData, plot)
	t.eq(_names(), [&"harvest"], "crop_harvested")
	t.vec_approx(_heard[0][1], plot.global_position, 0.001, "at the plot")
	_heard.clear()
	Events.product_collected.emit(load(ITEMS + "egg.tres") as ItemData, hen)
	t.eq(_names(), [&"pickup"], "product_collected")
	t.vec_approx(_heard[0][1], hen.global_position, 0.001, "at the animal")
	_heard.clear()
	Events.animal_fed.emit(hen)
	t.eq(_names(), [&"feed"], "animal_fed")
	for tool_name: StringName in [&"hoe", &"seeds", &"can"]:
		farmer.tools.select(tool_name)
		_heard.clear()
		Events.interaction_finished.emit(plot, farmer)
		var expected: StringName = {&"hoe": &"hoe", &"seeds": &"seed", &"can": &"water"}[tool_name]
		t.eq(_names(), [expected], "a plot with the %s tool" % tool_name)
		t.vec_approx(_heard[0][1], plot.global_position, 0.001, "at the plot")
	farmer.tools.select(&"hand")
	_heard.clear()
	Events.interaction_finished.emit(plot, farmer)
	t.eq(_names(), [], "the bare hand is quiet at a plot")
	var pump: Node = _find(farm, WaterPump)
	t.not_null(pump, "the farm has a pump")
	if pump != null:
		_heard.clear()
		Events.interaction_finished.emit(pump as WaterPump, farmer)
		t.eq(_names(), [&"water"], "the pump")
	farm.queue_free()


func test_the_farmer_makes_footsteps_while_walking(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	t.ok(farmer.get_node_or_null("Footsteps") is Footsteps, "the farmer carries a Footsteps node")
	farmer.global_position = Vector3(0.5, 0.0, 10.0)
	await t.physics_frames(20)
	_heard.clear()
	await t.physics_frames(40)
	t.eq(_names().count(&"footstep"), 0, "standing still is silent")
	farmer.walk_to(Vector3(8.5, 0.0, 12.0))
	var waited: int = 0
	while _names().count(&"footstep") < 3 and waited < 900:
		await t.physics_frames(1)
		waited += 1
	t.ok(_names().count(&"footstep") >= 3, "walking gives steps (%d heard)" % _names().count(&"footstep"))
	for entry: Array in _heard:
		if entry[0] == &"footstep":
			t.ok(entry[1] is Vector3, "each step has a place")
			break
	farm.queue_free()


# ---- ambience -------------------------------------------------------------------------------------------------------


func test_ambience_follows_the_time_of_day(t: Variant) -> void:
	var ambience: Ambience = AudioBus.ambience
	var noon: Dictionary = ambience.targets(12.0 * 60.0)
	var midnight: Dictionary = ambience.targets(0.0)
	t.approx(noon[&"birds"], 1.0, 0.001, "birds at noon")
	t.approx(noon[&"crickets"], 0.0, 0.001, "no crickets at noon")
	t.approx(midnight[&"birds"], 0.0, 0.001, "no birds at midnight")
	t.approx(midnight[&"crickets"], 1.0, 0.001, "crickets at midnight")
	var dawn: Dictionary = ambience.targets(375.0)
	t.ok(dawn[&"birds"] > 0.0 and dawn[&"birds"] < 1.0, "birds fade in at dawn")
	t.ok(dawn[&"crickets"] > 0.0 and dawn[&"crickets"] < 1.0, "crickets fade out at dawn")
	t.approx(ambience.day_weight(720.0), 1.0, 0.001, "day weight at noon")
	t.approx(ambience.day_weight(1300.0), 0.0, 0.001, "day weight at night")


func test_rain_starts_a_loop_and_clearing_ends_it(t: Variant) -> void:
	var ambience: Ambience = AudioBus.ambience
	GameClock.set_time(1, 12 * 60)
	Events.weather_changed.emit(Weather.State.CLEAR)
	ambience.snap()
	t.approx(ambience.gains[&"rain"], 0.0, 0.001, "no rain gain when clear")
	t.ok(not ambience._players[&"rain"].playing, "the rain player is stopped")
	Events.weather_changed.emit(Weather.State.RAIN)
	t.ok(ambience.raining, "rain is noticed")
	var wet: Dictionary = ambience.targets(12.0 * 60.0)
	t.approx(wet[&"rain"], 1.0, 0.001, "the rain target is full")
	t.ok(wet[&"birds"] < 0.5, "and the birds go quieter")
	ambience.snap()
	t.ok(ambience._players[&"rain"].playing, "the rain loop plays")
	t.eq(ambience._players[&"rain"].bus, &"Ambience", "on the Ambience bus")
	Events.weather_changed.emit(Weather.State.CLEAR)
	ambience._process(1.5)
	t.ok(ambience.gains[&"rain"] > 0.0 and ambience.gains[&"rain"] < 1.0, "the rain fades out, not off")
	ambience._process(5.0)
	t.approx(ambience.gains[&"rain"], 0.0, 0.001, "and then it is gone")
	t.ok(not ambience._players[&"rain"].playing, "the player stops")
	ambience.reset()


func test_the_music_follows_day_and_night(t: Variant) -> void:
	GameClock.set_time(1, 12 * 60)
	AudioBus.music_name = &""
	AudioBus.ambience.snap()
	t.eq(AudioBus.music_name, &"music_day", "day music at noon")
	GameClock.set_time(1, 23 * 60)
	AudioBus.ambience.snap()
	t.eq(AudioBus.music_name, &"music_night", "night music at eleven")
	AudioBus._music[0].stop()
	AudioBus._music[1].stop()
	AudioBus.music_name = &""


# ---- the settings panel ---------------------------------------------------------------------------------------------


func test_the_settings_panel_drives_the_settings(t: Variant) -> void:
	var panel := (load("res://scenes/ui/settings_panel.tscn") as PackedScene).instantiate() as SettingsPanel
	t.add(panel)
	await t.frames(2)
	t.ok(not panel.visible, "closed at the start")
	Settings.music = 0.25
	t.ok(panel.open(), "opens")
	t.ok(panel.is_in_group(&"modal"), "and is modal")
	t.ok(not panel.open(), "a second open is refused")
	var slider := panel.get_node("%MusicSlider") as HSlider
	t.approx(slider.value, 0.25, 0.001, "the slider shows the setting")
	slider.value = 0.9
	t.approx(Settings.music, 0.9, 0.001, "moving the slider moves the setting")
	t.eq((panel.get_node("%MusicValue") as Label).text, "90%", "and the label shows a percentage")
	t.approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), linear_to_db(0.9), 0.01, "and the bus")
	var mute := panel.get_node("%MuteCheck") as CheckButton
	mute.button_pressed = true
	t.ok(Settings.muted, "the mute switch works")
	var fps := panel.get_node("%FpsCheck") as CheckButton
	fps.button_pressed = true
	t.ok(Settings.show_fps, "the fps switch works")
	t.ok(Flow._fps.visible, "and the counter shows")
	fps.button_pressed = false
	panel.get_node("%DefaultsButton").pressed.emit()
	t.approx(Settings.music, 0.6, 0.001, "back to defaults")
	t.ok(not Settings.muted, "the switches too")
	t.approx(slider.value, 0.6, 0.001, "and the slider follows")
	panel.close()
	t.ok(not panel.visible and not panel.is_in_group(&"modal"), "closed")
	t.ok(FileAccess.file_exists(TEST_SETTINGS), "closing saved the file")
	panel.free()


func test_escape_closes_the_settings_panel(t: Variant) -> void:
	var panel := (load("res://scenes/ui/settings_panel.tscn") as PackedScene).instantiate() as SettingsPanel
	t.add(panel)
	await t.frames(2)
	panel.open()
	await _esc(t)
	t.ok(not panel.is_open, "Esc closes it")
	panel.free()


# ---- credits --------------------------------------------------------------------------------------------------------


func test_the_credits_text_comes_from_the_generated_file(t: Variant) -> void:
	var panel := (load("res://scenes/ui/credits_panel.tscn") as PackedScene).instantiate() as CreditsPanel
	t.add(panel)
	await t.frames(2)
	var text: String = panel.build_text(CreditsPanel.FILE)
	t.ok(text.length() > 200, "the text is not empty")
	t.ok(text.contains("Nunito"), "the font is credited")
	t.ok(text.contains("OFL") or text.contains("Open Font"), "with its licence")
	t.ok(text.contains("Blender"), "Blender is credited")
	t.ok(text.contains("Godot"), "Godot is credited")
	t.eq(panel.text.text, text, "the panel shows that text")
	t.eq(panel.build_text("res://does_not_exist.json"), "The credits file could not be read.", "a missing file gives a plain message")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CreditsPanel.FILE))
	t.ok(data.has("sections") and data["sections"].size() >= 3, "the file has sections")
	t.ok(panel.open(), "opens")
	t.ok(panel.is_in_group(&"modal"), "modal")
	await _esc(t)
	t.ok(not panel.is_open, "Esc closes it")
	panel.free()


# ---- the title screen and the flow ---------------------------------------------------------------------------------


func test_continue_is_enabled_only_when_a_save_exists(t: Variant) -> void:
	var title: Control = t.load_scene(TITLE)
	await t.frames(2)
	var button := title.get_node("%ContinueButton") as Button
	t.ok(button.disabled, "no save: Continue is grey")
	t.eq(button.text, "Continue", "and says only Continue")
	t.eq(Flow.newest_slot(), -1, "there is no newest slot")
	_write_sample(2, "2026-10-10T10:00:00")
	(title as Node).call("refresh")
	t.ok(not button.disabled, "one save: Continue is on")
	t.ok(button.text.begins_with("Continue: day"), "and shows the day: %s" % button.text)
	t.eq(Flow.newest_slot(), 2, "the newest slot is 2")
	_write_sample(3, "2026-10-11T09:00:00")
	t.eq(Flow.newest_slot(), 3, "a later save wins")
	_write_text(SaveSystem.path_for(3), "broken")
	t.eq(Flow.newest_slot(), 2, "a damaged file is skipped")
	SaveSystem.delete_slot(2)
	SaveSystem.delete_slot(3)
	(title as Node).call("refresh")
	t.ok(button.disabled, "no save again: grey again")
	title.free()


func test_the_title_screen_buttons(t: Variant) -> void:
	var title: Control = t.load_scene(TITLE)
	await t.frames(2)
	t.eq((title.get_node("%NewButton") as Button).text, "New Game", "New Game")
	t.ok(not (title.get_node("%NewButton") as Button).disabled, "is on")
	t.ok(not (title.get_node("%LoadButton") as Button).disabled, "Load is on")
	t.eq(title.get_node("%SavePanel").allow_save, false, "the Load window cannot save")
	var settings := title.get_node("%SettingsPanel") as SettingsPanel
	(title.get_node("%SettingsButton") as Button).pressed.emit()
	t.ok(settings.is_open, "Settings opens the panel")
	settings.close()
	var credits := title.get_node("%CreditsPanel") as CreditsPanel
	(title.get_node("%CreditsButton") as Button).pressed.emit()
	t.ok(credits.is_open, "Credits opens the panel")
	credits.close()
	t.ok(not GameClock.running, "the clock stands still on the title screen")
	t.eq(AudioBus.music_name, &"music_day", "the title plays the day music")
	title.free()


func test_the_load_window_on_the_title_screen_shows_only_loading(t: Variant) -> void:
	_write_sample(1, "2026-10-10T10:00:00")
	var title: Control = t.load_scene(TITLE)
	await t.frames(2)
	var panel := title.get_node("%SavePanel") as SavePanel
	t.ok(panel.open(), "opens")
	t.ok((panel.rows.get_child(1).get_child(2) as Button).disabled, "Save is off")
	t.ok(not (panel.rows.get_child(1).get_child(3) as Button).disabled, "Load is on for a real slot")
	panel.close()
	title.free()


func test_continue_loads_the_newest_save_after_the_farm_is_running(t: Variant) -> void:
	_write_sample(1, "2026-10-10T10:00:00")
	_write_sample(2, "2026-10-12T10:00:00")
	var loaded: Array[int] = []
	var listener: Callable = func(slot: int) -> void: loaded.append(slot)
	Events.game_loaded.connect(listener)
	await Flow.continue_game()
	Events.game_loaded.disconnect(listener)
	t.eq(loaded, [2], "only the newest slot was loaded")
	var scene: Node = t.tree.current_scene
	t.not_null(scene, "there is a current scene")
	t.eq(scene.scene_file_path, FARM, "and it is the farm")
	t.ok(Flow.farm_running(), "the farm is running")
	t.ok(not Flow.busy, "the flow is free again")
	t.ok(GameClock.running, "the clock runs")
	t.ok(AudioBus.music_name != &"", "and music plays")


func test_continue_with_no_save_does_nothing(t: Variant) -> void:
	await Flow.continue_game()
	t.eq(t.tree.current_scene, null, "no scene was loaded")
	t.ok(not Flow.busy, "the flow is free")


func test_a_broken_save_sends_the_player_back_to_the_title_with_a_message(t: Variant) -> void:
	_write_sample(1, "2026-10-10T10:00:00")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.path_for(1)))
	data["version"] = 99
	_write_text(SaveSystem.path_for(1), JSON.stringify(data))
	await Flow.load_slot(1)
	await t.frames(6)
	var scene: Node = t.tree.current_scene
	t.not_null(scene, "a scene is up")
	t.eq(scene.scene_file_path, TITLE, "it is the title screen")
	t.ok((scene.get_node("%MessageLabel") as Label).text != "", "with a message about the save")
	t.ok(not Flow.busy, "and the flow is free")


# ---- new game ------------------------------------------------------------------------------------------------------


func test_new_game_resets_every_system(t: Variant) -> void:
	await Flow.new_game()
	var farm: Node = t.tree.current_scene
	t.eq(farm.scene_file_path, FARM, "the first new game builds the farm")
	await t.physics_frames(3)
	var build := farm.get_node("Build") as BuildMode
	var weather := farm.get_node("Weather") as Weather
	var farmer := farm.get_node("Farmer") as Farmer
	GameClock.set_time(9, 15 * 60)
	GameClock.paused = true
	Economy.money = 7
	Economy.add_money(10, "test")
	Inventory.clear()
	Inventory.add(load(ITEMS + "hay.tres") as ItemData, 3)
	SaveSystem.playtime = 5000.0
	SaveSystem.current_slot = 3
	weather.set_state(Weather.State.RAIN)
	Events.weather_changed.emit(Weather.State.RAIN)
	var plan: BuildItemData = Flow.STOCK.plans[0]
	plan.unlocked = true
	var plot: SoilPlot = farm.get_tree().get_nodes_in_group(&"soil_plots")[0] as SoilPlot
	plot._set_state(SoilPlot.State.TILLED)
	farmer.global_position = Vector3(-9.0, 0.0, 4.0)
	var hen := farm.get_node("Animals/Chicken_1") as Animal
	hen.fed = true
	var item: BuildItemData = build.catalog.find(&"fence")
	t.ok(build.try_place(item, Vector2i(-12, 3), 0) != null, "a fence was built")
	t.ok(build.placed_root.get_child_count() > 0, "so there is something placed")
	Events.build_mode_changed.emit(false)
	await Flow.new_game()
	await t.physics_frames(3)
	var fresh: Node = t.tree.current_scene
	t.ok(fresh != farm and not is_instance_valid(farm), "the old farm is gone")
	t.eq(fresh.scene_file_path, FARM, "a new farm stands in its place")
	t.eq(GameClock.day, 1, "day one")
	t.eq(GameClock.get_hour(), 6, "six in the morning")
	t.ok(not GameClock.paused, "the clock is not paused")
	t.ok(GameClock.running, "and it runs")
	t.eq(Economy.money, Economy.START_MONEY, "starting money")
	t.eq(Economy.ledger.size(), 0, "an empty ledger")
	var start_bag: Dictionary = Inventory.to_save()
	Inventory.clear()
	Inventory.give_starting_items()
	t.eq(start_bag, Inventory.to_save(), "the bag is the same as a first start")
	t.approx(SaveSystem.playtime, 0.0, 0.5, "the play time starts again")
	t.eq(SaveSystem.current_slot, 1, "slot 1 is the working slot")
	t.ok(not Flow.STOCK.plans[0].unlocked, "the shop plans are locked again")
	var now: Node = t.tree.current_scene
	t.eq((now.get_node("Weather") as Weather).state, Weather.State.CLEAR, "clear weather")
	t.eq((now.get_node("Build") as BuildMode).placed_root.get_child_count(), 0, "nothing built")
	for p: Node in now.get_tree().get_nodes_in_group(&"soil_plots"):
		t.eq((p as SoilPlot).state, SoilPlot.State.EMPTY, "every plot is empty")
	for animal: Node in now.get_node("Animals").get_children():
		if animal is Animal:
			t.ok(not (animal as Animal).fed, "no animal is fed")
	t.ok(not Flow.busy, "the flow is free")
	t.eq(get_tree().paused, false, "the tree is not paused")


func test_new_game_does_not_touch_the_saves(t: Variant) -> void:
	_write_sample(1, "2026-10-10T10:00:00")
	var before: Array[String] = _listing(TEST_FOLDER)
	await Flow.new_game()
	t.eq(_listing(TEST_FOLDER), before, "the save files are as they were")
	t.eq(Flow.newest_slot(), 1, "and Continue would still find them")


# ---- the pause menu and the Esc order -----------------------------------------------------------------------------


func test_the_pause_menu_stops_and_restarts_the_clock(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var pause := farm.get_node("PauseMenu") as PauseMenu
	GameClock.running = true
	await t.frames(3)
	var before: float = GameClock.minute_float()
	t.ok(before > 360.0, "the clock was running")
	pause.open()
	t.ok(get_tree().paused, "the tree is paused")
	t.ok(pause.visible and pause.is_open, "the menu shows")
	var paused_at: float = GameClock.minute_float()
	await t.frames(10)
	t.approx(GameClock.minute_float(), paused_at, 0.0001, "no time passes while paused")
	t.ok(not GameClock.paused, "the clock's own pause flag is not used for this")
	pause.resume()
	t.ok(not get_tree().paused, "the tree runs again")
	await t.frames(10)
	t.ok(GameClock.minute_float() > paused_at, "time passes again")
	farm.queue_free()


func test_escape_opens_and_closes_the_pause_menu(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var pause := farm.get_node("PauseMenu") as PauseMenu
	t.ok(not pause.is_open, "closed at the start")
	await _esc(t)
	t.ok(pause.is_open, "Esc opens the menu when nothing else is open")
	t.ok(get_tree().paused, "and pauses")
	await _esc(t)
	t.ok(not pause.is_open, "a second Esc closes it")
	t.ok(not get_tree().paused, "and the game runs")
	farm.queue_free()


func test_escape_closes_the_shop_before_it_opens_the_pause_menu(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var pause := farm.get_node("PauseMenu") as PauseMenu
	var shop := farm.get_node("Hud/ShopPanel") as ShopPanel
	t.ok(shop.open(), "the shop is open")
	await _esc(t)
	t.ok(not shop.is_open, "Esc closed the shop")
	t.ok(not pause.is_open, "and did not open the pause menu")
	await _esc(t)
	t.ok(pause.is_open, "the next Esc does")
	farm.queue_free()


func test_escape_leaves_build_mode_before_it_opens_the_pause_menu(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var pause := farm.get_node("PauseMenu") as PauseMenu
	var build := farm.get_node("Build") as BuildMode
	build.set_active(true)
	t.ok(build.active, "build mode is on")
	await _esc(t)
	t.ok(not build.active, "Esc left build mode")
	t.ok(not pause.is_open, "and did not open the pause menu")
	await _esc(t)
	t.ok(pause.is_open, "the next Esc does")
	farm.queue_free()


func test_escape_stops_a_walk_before_it_opens_the_pause_menu(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var pause := farm.get_node("PauseMenu") as PauseMenu
	var farmer := farm.get_node("Farmer") as Farmer
	farmer.global_position = Vector3(0.5, 0.0, 10.0)
	farmer.walk_to(Vector3(8.5, 0.0, 12.0))
	await t.physics_frames(10)
	t.ok(farmer.walking, "he is walking")
	await _esc(t)
	t.ok(not farmer.walking, "Esc stopped the walk")
	t.ok(not pause.is_open, "and did not open the pause menu")
	await _esc(t)
	t.ok(pause.is_open, "the next Esc does")
	farm.queue_free()


func test_escape_closes_a_window_opened_from_the_pause_menu_first(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var pause := farm.get_node("PauseMenu") as PauseMenu
	var slots := farm.get_node("Hud/SavePanel") as SavePanel
	await _esc(t)
	t.ok(pause.is_open, "paused")
	pause.save_button.pressed.emit()
	t.ok(slots.is_open, "the save window is open")
	t.ok(slots.allow_save and not slots.allow_load, "it can only save")
	t.ok(not pause.menu.visible, "the pause buttons are hidden behind it")
	await _esc(t)
	t.ok(not slots.is_open, "Esc closed the save window")
	t.ok(pause.is_open and pause.menu.visible, "the pause menu is back")
	t.ok(slots.allow_save and slots.allow_load, "and the window is a normal one again")
	pause.load_button.pressed.emit()
	t.ok(slots.is_open and not slots.allow_save, "Load opens it load-only")
	await _esc(t)
	pause.settings_button.pressed.emit()
	t.ok(pause.settings_panel.is_open, "Settings opens the panel")
	await _esc(t)
	t.ok(not pause.settings_panel.is_open, "Esc closes it")
	t.ok(pause.is_open, "still paused")
	await _esc(t)
	t.ok(not pause.is_open, "the last Esc resumes")
	farm.queue_free()


func test_the_pause_menu_refuses_to_open_over_other_things(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var pause := farm.get_node("PauseMenu") as PauseMenu
	t.ok(pause.can_open(), "free: it may open")
	(farm.get_node("Build") as BuildMode).set_active(true)
	t.ok(not pause.can_open(), "not while building")
	(farm.get_node("Build") as BuildMode).set_active(false)
	var panel := farm.get_node("Hud/SavePanel") as SavePanel
	panel.open()
	t.ok(not pause.can_open(), "not over a modal window")
	panel.close()
	Flow.busy = true
	t.ok(not pause.can_open(), "not during a scene change")
	Flow.busy = false
	t.ok(pause.can_open(), "free again")
	farm.queue_free()


func test_the_pause_menu_goes_to_the_title_and_back(t: Variant) -> void:
	await Flow.new_game()
	await t.physics_frames(3)
	var farm: Node = t.tree.current_scene
	var pause := farm.get_node("PauseMenu") as PauseMenu
	pause.open()
	t.ok(get_tree().paused, "paused")
	pause.title_button.pressed.emit()
	await t.frames(6)
	var title: Node = t.tree.current_scene
	t.not_null(title, "a scene is up")
	t.eq(title.scene_file_path, TITLE, "the title screen")
	t.ok(not get_tree().paused, "the tree is not paused on the title screen")
	t.ok(not GameClock.running, "the clock stands still there")
	t.ok(not Flow.busy, "the flow is free")


# ---- project polish --------------------------------------------------------------------------------------------------


func test_the_project_is_set_up_for_the_title_screen(t: Variant) -> void:
	var main: String = ProjectSettings.get_setting("application/run/main_scene")
	var path: String = main
	if main.begins_with("uid://"):
		path = ResourceUID.get_id_path(ResourceUID.text_to_id(main))
	t.eq(path, TITLE, "the main scene is the title screen")
	t.eq(ProjectSettings.get_setting("application/config/name"), "Little Meadow", "the window title")
	t.eq(get_window().title, "Little Meadow", "and it is in use")
	t.ok(FileAccess.file_exists(ProjectSettings.get_setting("application/config/icon")), "the icon exists")
	var order: Array[String] = []
	for key: String in ["Events", "GameClock", "Inventory", "Economy", "SaveSystem", "Settings", "AudioBus", "Flow"]:
		t.ok(ProjectSettings.has_setting("autoload/" + key), "%s is an autoload" % key)
		order.append(key)
	var names: Array[String] = []
	for property: Dictionary in ProjectSettings.get_property_list():
		if String(property["name"]).begins_with("autoload/"):
			names.append(String(property["name"]).trim_prefix("autoload/"))
	names.sort_custom(func(a: String, b: String) -> bool:
		return ProjectSettings.get_order("autoload/" + a) < ProjectSettings.get_order("autoload/" + b))
	t.eq(names.slice(names.size() - 3), ["Settings", "AudioBus", "Flow"] as Array[String], "the new autoloads come last, in this order")


func test_the_font_is_in_the_theme(t: Variant) -> void:
	var theme := load("res://resources/ui/hud_theme.tres") as Theme
	t.ok(theme.default_font is FontVariation, "the default font is a font variation")
	var variation := theme.default_font as FontVariation
	t.ok(variation.base_font.resource_path.ends_with("Nunito-VariableFont_wght.ttf"), "built on Nunito")
	t.eq(int(variation.variation_opentype.get(TextServerManager.get_primary_interface().name_to_tag("wght"), 0)), 500, "at a medium weight")
	var plain: float = variation.base_font.get_string_size("Little Meadow", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var medium: float = variation.get_string_size("Little Meadow", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	t.ok(medium > plain, "the weight really changes the text (%.0f is wider than %.0f)" % [medium, plain])
	t.eq(theme.get_type_variation_base(&"HeadingLabel"), &"Label", "the heading look exists")


func test_buttons_show_the_pointing_hand(t: Variant) -> void:
	var button := Button.new()
	t.add(button)
	await t.frames(1)
	t.eq(button.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND, "a button gets the hand cursor")
	button.free()
