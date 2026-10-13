class_name CreditsPanel
extends Control

signal closed

const FILE: String = "res://resources/credits.json"

var is_open: bool = false

@onready var text: RichTextLabel = %CreditsText
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	text.meta_clicked.connect(_on_meta_clicked)
	text.text = build_text(FILE)


func build_text(path: String) -> String:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return "The credits file could not be read."
	var lines: PackedStringArray = [String(data.get("intro", ""))]
	for section: Dictionary in data.get("sections", []):
		lines.append("\n[b]%s[/b]" % section.get("heading", ""))
		for item: Dictionary in section.get("items", []):
			var line: String = "%s: %s" % [item.get("name", ""), item.get("detail", "")]
			if item.has("license"):
				line += " (%s)" % item["license"]
			if item.has("url"):
				line += "  [url]%s[/url]" % item["url"]
			lines.append(line)
	return "\n".join(lines)


func open() -> bool:
	if is_open or not get_tree().get_nodes_in_group(&"modal").is_empty():
		return false
	is_open = true
	add_to_group(&"modal")
	visible = true
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	remove_from_group(&"modal")
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open:
		if event.is_action_pressed("ui_cancel"):
			close()
		get_viewport().set_input_as_handled()


func _on_meta_clicked(meta: Variant) -> void:
	if String(meta).begins_with("https://"):
		OS.shell_open(String(meta))
