class_name PauseMenu
extends CanvasLayer

signal opened
signal closed

@export var farmer: Farmer
@export var build: BuildMode
@export var save_panel: SavePanel

var is_open: bool = false

@onready var menu: Control = %Menu
@onready var resume_button: Button = %ResumeButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var settings_button: Button = %SettingsButton
@onready var title_button: Button = %TitleButton
@onready var quit_button: Button = %QuitButton
@onready var settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	visible = false
	resume_button.pressed.connect(resume)
	save_button.pressed.connect(_open_slots.bind(true))
	load_button.pressed.connect(_open_slots.bind(false))
	settings_button.pressed.connect(_open_settings)
	title_button.pressed.connect(Flow.to_title)
	quit_button.pressed.connect(Flow.quit_game)
	save_panel.closed.connect(_on_panel_closed)
	settings_panel.closed.connect(_on_panel_closed)


func can_open() -> bool:
	return (not is_open and not Flow.busy
		and get_tree().get_nodes_in_group(&"modal").is_empty()
		and not (build != null and build.active)
		and not farmer.walking)


func open() -> void:
	is_open = true
	get_tree().paused = true
	visible = true
	menu.visible = true
	AudioBus.play(&"ui_open")
	opened.emit()


func resume() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	AudioBus.play(&"ui_close")
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_open:
		if get_tree().get_nodes_in_group(&"modal").is_empty():
			resume()
			get_viewport().set_input_as_handled()
	elif can_open():
		open()
		get_viewport().set_input_as_handled()


func _open_slots(saving: bool) -> void:
	save_panel.allow_save = saving
	save_panel.allow_load = not saving
	if save_panel.open():
		menu.visible = false


func _open_settings() -> void:
	if settings_panel.open():
		menu.visible = false


func _on_panel_closed() -> void:
	save_panel.allow_save = true
	save_panel.allow_load = true
	menu.visible = is_open
