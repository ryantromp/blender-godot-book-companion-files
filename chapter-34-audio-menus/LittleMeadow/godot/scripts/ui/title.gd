extends Control

@onready var new_button: Button = %NewButton
@onready var continue_button: Button = %ContinueButton
@onready var load_button: Button = %LoadButton
@onready var settings_button: Button = %SettingsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton
@onready var message_label: Label = %MessageLabel
@onready var save_panel: SavePanel = %SavePanel
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var credits_panel: CreditsPanel = %CreditsPanel


func _ready() -> void:
	GameClock.running = false
	get_tree().paused = false
	new_button.pressed.connect(Flow.new_game)
	continue_button.pressed.connect(Flow.continue_game)
	load_button.pressed.connect(save_panel.open)
	settings_button.pressed.connect(settings_panel.open)
	credits_button.pressed.connect(credits_panel.open)
	quit_button.pressed.connect(Flow.quit_game)
	save_panel.closed.connect(refresh)
	save_panel.allow_save = false
	message_label.text = Flow.last_message
	Flow.last_message = ""
	AudioBus.play_music(&"music_day")
	refresh()


func refresh() -> void:
	var slot: int = Flow.newest_slot()
	continue_button.disabled = slot < 0
	continue_button.tooltip_text = "There is no saved game yet." if slot < 0 else ""
	continue_button.text = "Continue"
	if slot >= 0:
		var entry: Dictionary = SaveSystem.list_slots()[slot]
		continue_button.text = "Continue: day %d, %s" % [entry["day"], entry["time"]]
	load_button.disabled = false
