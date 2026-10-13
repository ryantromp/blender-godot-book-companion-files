class_name SettingsPanel
extends Control

signal closed

const KEYS: Array[String] = ["master", "music", "sfx", "ambience"]

var is_open: bool = false

@onready var close_button: Button = %CloseButton
@onready var defaults_button: Button = %DefaultsButton
@onready var mute_check: CheckButton = %MuteCheck
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var fps_check: CheckButton = %FpsCheck


func _ready() -> void:
	visible = false
	for key: String in KEYS:
		var slider: HSlider = get_node("%" + key.capitalize() + "Slider")
		slider.value_changed.connect(_on_slider_changed.bind(key))
		slider.drag_ended.connect(_on_drag_ended.unbind(1))
	close_button.pressed.connect(close)
	defaults_button.pressed.connect(_on_defaults_pressed)
	mute_check.toggled.connect(_on_toggled.bind("muted"))
	fullscreen_check.toggled.connect(_on_toggled.bind("fullscreen"))
	fps_check.toggled.connect(_on_toggled.bind("show_fps"))


func open() -> bool:
	if is_open or not get_tree().get_nodes_in_group(&"modal").is_empty():
		return false
	is_open = true
	add_to_group(&"modal")
	_show_values()
	visible = true
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	remove_from_group(&"modal")
	visible = false
	Settings.save_file()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open:
		if event.is_action_pressed("ui_cancel"):
			close()
		get_viewport().set_input_as_handled()


func _show_values() -> void:
	for key: String in KEYS:
		var slider: HSlider = get_node("%" + key.capitalize() + "Slider")
		slider.set_value_no_signal(Settings.get(key))
		_show_percent(key)
	mute_check.set_pressed_no_signal(Settings.muted)
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	fps_check.set_pressed_no_signal(Settings.show_fps)


func _show_percent(key: String) -> void:
	var slider: HSlider = get_node("%" + key.capitalize() + "Slider")
	var label: Label = get_node("%" + key.capitalize() + "Value")
	label.text = "%d%%" % roundi(slider.value * 100.0)


func _on_slider_changed(value: float, key: String) -> void:
	Settings.set_volume(key, value)
	_show_percent(key)


func _on_drag_ended() -> void:
	AudioBus.play(&"ui_tick")
	Settings.save_file()


func _on_toggled(pressed: bool, key: String) -> void:
	Settings.set(key, pressed)
	Settings.apply()
	Settings.save_file()


func _on_defaults_pressed() -> void:
	Settings.reset()
	Settings.apply()
	Settings.save_file()
	_show_values()
