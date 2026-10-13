extends Node

signal changed

const FILE: String = "user://settings.cfg"
const HEADLESS_FILE: String = "user://settings_headless.cfg"
const BUSES: Dictionary = {
	"master": &"Master", "music": &"Music", "sfx": &"SFX", "ambience": &"Ambience",
}
const SECTIONS: Dictionary = {
	"master": "audio", "music": "audio", "sfx": "audio", "ambience": "audio", "muted": "audio",
	"fullscreen": "display", "show_fps": "display",
}
const DEFAULTS: Dictionary = {
	"master": 0.8, "music": 0.6, "sfx": 0.8, "ambience": 0.7, "muted": false,
	"fullscreen": false, "show_fps": false,
}

var path: String = FILE
var master: float = 0.8
var music: float = 0.6
var sfx: float = 0.8
var ambience: float = 0.7
var muted: bool = false
var fullscreen: bool = false
var show_fps: bool = false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		path = HEADLESS_FILE
	load_file()
	apply()


func reset() -> void:
	for key: String in DEFAULTS:
		set(key, DEFAULTS[key])


func load_file() -> bool:
	reset()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return false
	for key: String in SECTIONS:
		set(key, _clean(key, file.get_value(SECTIONS[key], key, DEFAULTS[key])))
	return true


func save_file() -> bool:
	var file := ConfigFile.new()
	for key: String in SECTIONS:
		file.set_value(SECTIONS[key], key, get(key))
	return file.save(path) == OK


func set_volume(key: String, value: float) -> void:
	set(key, clampf(value, 0.0, 1.0))
	apply()


func apply() -> void:
	for key: String in BUSES:
		var bus: int = AudioServer.get_bus_index(BUSES[key])
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(get(key), 0.0001)))
	var master_bus: int = AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, muted)
	if DisplayServer.get_name() != "headless" and is_fullscreen() != fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()


func is_fullscreen() -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _clean(key: String, value: Variant) -> Variant:
	if DEFAULTS[key] is bool:
		return value if value is bool else DEFAULTS[key]
	if value is float or value is int:
		var number: float = float(value)
		return clampf(number, 0.0, 1.0) if is_finite(number) else DEFAULTS[key]
	return DEFAULTS[key]
