class_name SavePanel
extends Control

signal closed

const BAD: Color = Color("FF9A8A")
const HINT: String = "F5 saves, F9 loads, F10 opens this window."

@export var build: BuildMode
@export var allow_save: bool = true
@export var allow_load: bool = true

var is_open: bool = false

var _was_paused: bool = false
var _pending: Callable

@onready var rows: VBoxContainer = %Rows
@onready var confirm_row: HBoxContainer = %ConfirmRow
@onready var confirm_label: Label = %ConfirmLabel
@onready var message_label: Label = %MessageLabel
@onready var close_button: Button = %CloseButton
@onready var yes_button: Button = %YesButton
@onready var no_button: Button = %NoButton


func _ready() -> void:
	visible = false
	confirm_row.visible = false
	close_button.pressed.connect(close)
	yes_button.pressed.connect(_confirm)
	no_button.pressed.connect(_cancel_ask)
	Events.save_menu_requested.connect(open)


func open() -> bool:
	if is_open:
		return true
	if build != null and build.active:
		Events.hint_shown.emit("Close build mode first.")
		return false
	if not get_tree().get_nodes_in_group(&"modal").is_empty():
		return false
	is_open = true
	_was_paused = GameClock.paused
	GameClock.paused = true
	add_to_group(&"modal")
	visible = true
	message_label.text = HINT
	refresh()
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	_cancel_ask()
	GameClock.paused = _was_paused
	remove_from_group(&"modal")
	visible = false
	closed.emit()


func refresh() -> void:
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for entry: Dictionary in SaveSystem.list_slots():
		rows.add_child(_make_row(entry))


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("save_menu"):
		if confirm_row.visible:
			_cancel_ask()
		else:
			close()
	get_viewport().set_input_as_handled()


func _make_row(entry: Dictionary) -> HBoxContainer:
	var slot: int = entry["slot"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := Label.new()
	name_label.text = entry["label"]
	name_label.custom_minimum_size.x = 96.0
	var info := Label.new()
	info.text = _info_text(entry)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 330.0
	if entry["error"] != "":
		info.add_theme_color_override("font_color", BAD)
	var save_problem: String = ""
	if not allow_save:
		save_problem = "Saving is not possible here."
	elif slot == SaveSystem.AUTOSAVE_SLOT:
		save_problem = "The game fills this slot by itself."
	var load_problem: String = ""
	if not allow_load:
		load_problem = "Loading is not possible here."
	elif not entry["exists"]:
		load_problem = "Nothing is saved here."
	elif entry["error"] != "":
		load_problem = entry["error"]
	for child: Control in [name_label, info,
			_button("Save", save_problem, _on_save_pressed.bind(entry)),
			_button("Load", load_problem, _on_load_pressed.bind(slot)),
			_button("Delete", "" if entry["exists"] else "Nothing is saved here.", _on_delete_pressed.bind(entry))]:
		row.add_child(child)
	return row


func _info_text(entry: Dictionary) -> String:
	if not entry["exists"]:
		return "Empty"
	if entry["error"] != "":
		return "Damaged: " + entry["error"]
	var minutes: int = floori(entry["playtime"] / 60.0)
	return "Day %d, %s   %d coins\n%s   played %d h %02d min" % [
		entry["day"], entry["time"], entry["money"],
		String(entry["saved_at"]).replace("T", "  "), floori(minutes / 60.0), minutes % 60]


func _button(text: String, problem: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = problem != ""
	button.tooltip_text = problem
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


func _on_save_pressed(entry: Dictionary) -> void:
	if entry["exists"]:
		_ask("Overwrite %s?" % entry["label"], _save.bind(entry["slot"]))
	else:
		_save(entry["slot"])


func _on_load_pressed(slot: int) -> void:
	if SaveSystem.load_game(slot):
		close()
	else:
		message_label.text = SaveSystem.last_error


func _on_delete_pressed(entry: Dictionary) -> void:
	_ask("Delete %s for good?" % entry["label"], _delete.bind(entry["slot"]))


func _save(slot: int) -> void:
	if SaveSystem.save_game(slot):
		message_label.text = "Saved to %s." % SaveSystem.label_for(slot)
	else:
		message_label.text = SaveSystem.last_error
	refresh()


func _delete(slot: int) -> void:
	SaveSystem.delete_slot(slot)
	message_label.text = "Deleted %s." % SaveSystem.label_for(slot)
	refresh()


func _ask(question: String, action: Callable) -> void:
	confirm_label.text = question
	_pending = action
	confirm_row.visible = true


func _confirm() -> void:
	var action: Callable = _pending
	_cancel_ask()
	action.call()


func _cancel_ask() -> void:
	confirm_row.visible = false
	_pending = Callable()
