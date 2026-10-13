extends Node

const VERSION: int = 2
const AUTOSAVE_SLOT: int = 0
const SLOT_COUNT: int = 3
const FOLDER: String = "user://saves"
const HEADLESS_FOLDER: String = "user://saves_headless"
const CORE: Array[String] = ["clock", "weather", "inventory", "economy", "shop", "build", "farmer"]

var folder: String = FOLDER
var autosave_enabled: bool = true
var current_slot: int = 1
var playtime: float = 0.0
var last_error: String = ""

var _autosave_waiting: bool = false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		folder = HEADLESS_FOLDER
		autosave_enabled = false
	Events.day_started.connect(_on_day_started)


func _process(delta: float) -> void:
	playtime += delta


func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().get_nodes_in_group(&"modal").is_empty():
		return
	if event.is_action_pressed("quick_save"):
		save_game(current_slot)
	elif event.is_action_pressed("quick_load"):
		load_game(current_slot)
	elif event.is_action_pressed("save_menu"):
		Events.save_menu_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and autosave_enabled:
		save_game(AUTOSAVE_SLOT)


func path_for(slot: int) -> String:
	return "%s/slot_%d.json" % [folder, slot]


func label_for(slot: int) -> String:
	return "Autosave" if slot == AUTOSAVE_SLOT else "Slot %d" % slot


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(path_for(slot))


func saveables() -> Dictionary[String, Node]:
	var found: Dictionary[String, Node] = {}
	for node: Node in get_tree().get_nodes_in_group(&"saveable"):
		found[String(node.call(&"save_key"))] = node
	return found


func snapshot() -> Dictionary:
	var nodes: Dictionary[String, Node] = saveables()
	var systems: Dictionary = {}
	for key: String in _order(nodes):
		systems[key] = nodes[key].call(&"to_save")
	return systems


func make_save() -> Dictionary:
	return {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"summary": {"day": GameClock.day, "time": GameClock.time_text(), "money": Economy.money, "playtime": int(playtime)},
		"systems": snapshot(),
	}


func save_game(slot: int) -> bool:
	if slot < AUTOSAVE_SLOT or slot > SLOT_COUNT:
		return _fail("There is no slot %d." % slot)
	if _missing_core() != "":
		return _fail("There is no farm running to save.")
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return _fail("Could not make the folder for the saves.")
	var path: String = path_for(slot)
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return _fail("Could not write the save: %s." % error_string(FileAccess.get_open_error()))
	var written: bool = file.store_string(JSON.stringify(make_save(), "\t", false))
	file.close()
	if not written or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		DirAccess.remove_absolute(path + ".tmp")
		return _fail("Could not finish writing the save.")
	if slot != AUTOSAVE_SLOT:
		current_slot = slot
	last_error = ""
	Events.game_saved.emit(slot)
	Events.hint_shown.emit("Game saved")
	return true


func load_game(slot: int) -> bool:
	if _missing_core() != "":
		return _fail("There is no farm running to load into.")
	var read: Dictionary = read_slot(slot)
	if read["error"] != "":
		return _fail(read["error"])
	var data: Dictionary = read["data"]
	var problem: String = validate(data)
	if problem != "":
		return _fail(problem)
	var nodes: Dictionary[String, Node] = saveables()
	for key: String in _order(nodes):
		nodes[key].call(&"from_save", data["systems"][key])
	playtime = float(data["summary"]["playtime"])
	if slot != AUTOSAVE_SLOT:
		current_slot = slot
	last_error = ""
	Events.game_loaded.emit(slot)
	Events.hint_shown.emit("Game loaded")
	return true


func delete_slot(slot: int) -> bool:
	return has_save(slot) and DirAccess.remove_absolute(path_for(slot)) == OK


func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot: int in range(AUTOSAVE_SLOT, SLOT_COUNT + 1):
		var entry: Dictionary = {
			"slot": slot, "label": label_for(slot), "exists": has_save(slot), "error": "",
			"day": 0, "time": "", "money": 0, "playtime": 0, "saved_at": "",
		}
		if entry["exists"]:
			var read: Dictionary = read_slot(slot)
			entry["error"] = read["error"]
			if read["error"] == "":
				var summary: Dictionary = read["data"]["summary"]
				entry["day"] = int(summary["day"])
				entry["time"] = String(summary["time"])
				entry["money"] = int(summary["money"])
				entry["playtime"] = int(summary["playtime"])
				entry["saved_at"] = String(read["data"]["saved_at"])
		slots.append(entry)
	return slots


func read_slot(slot: int) -> Dictionary:
	if not has_save(slot):
		return {"error": "There is no save in this slot."}
	var text: String = FileAccess.get_file_as_string(path_for(slot))
	if text.strip_edges() == "":
		return {"error": "The save file is empty."}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"error": "The save file is damaged (line %d: %s)." % [parser.get_error_line(), parser.get_error_message()]}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {"error": "The file is not a save."}
	var data: Dictionary = parser.data
	var problem: String = upgrade(data)
	if problem == "":
		problem = check_header(data)
	return {"error": problem, "data": data}


func upgrade(data: Dictionary) -> String:
	if _kind(data.get("version")) != "number":
		return "The save has no version number."
	var version: int = int(data["version"])
	if version > VERSION:
		return "This save comes from a newer game (version %d)." % version
	if version < 1:
		return "This save has a version that never existed (%d)." % version
	while version < VERSION:
		match version:
			1:
				_migrate_1_to_2(data)
		version += 1
		data["version"] = version
	return ""


func check_header(data: Dictionary) -> String:
	var top: Dictionary = {"saved_at": "string", "summary": "dictionary", "systems": "dictionary"}
	for key: String in top:
		if _kind(data.get(key)) != top[key]:
			return "The save has no valid '%s'." % key
	var fields: Dictionary = {"day": "number", "time": "string", "money": "number", "playtime": "number"}
	for key: String in fields:
		if _kind(data["summary"].get(key)) != fields[key]:
			return "The summary has no valid '%s'." % key
	return ""


func validate(data: Dictionary) -> String:
	var problem: String = check_header(data)
	if problem != "":
		return problem
	var systems: Dictionary = data["systems"]
	var nodes: Dictionary[String, Node] = saveables()
	for key: String in nodes:
		if not systems.has(key):
			return "The save has nothing for '%s'." % key
		problem = _compare(key, nodes[key].call(&"to_save"), systems[key])
		if problem != "":
			return problem
	return ""


func pack(point: Vector3) -> Array:
	return [snappedf(point.x, 0.001), snappedf(point.y, 0.001), snappedf(point.z, 0.001)]


func unpack(values: Array) -> Vector3:
	if values.size() < 3:
		return Vector3.ZERO
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _migrate_1_to_2(data: Dictionary) -> void:
	var summary: Variant = data.get("summary")
	if summary is Dictionary and summary.has("coins"):
		summary["money"] = summary["coins"]
		summary.erase("coins")


func _compare(key: String, live: Variant, saved: Variant) -> String:
	if _kind(live) != _kind(saved):
		return "'%s' should be a %s." % [key, _kind(live)]
	if live is Dictionary:
		var fields: Dictionary = live
		for field: String in fields:
			if _kind(fields[field]) != _kind(saved.get(field)):
				return "'%s' has no valid '%s'." % [key, field]
	return ""


func _kind(value: Variant) -> String:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return "number"
		TYPE_STRING:
			return "string"
		TYPE_ARRAY:
			return "array"
		TYPE_DICTIONARY:
			return "dictionary"
		TYPE_BOOL:
			return "bool"
	return "other"


func _order(nodes: Dictionary[String, Node]) -> Array[String]:
	var order: Array[String] = []
	var rest: Array[String] = []
	for key: String in CORE:
		if nodes.has(key):
			order.append(key)
	for key: String in nodes:
		if not CORE.has(key):
			rest.append(key)
	rest.sort()
	order.append_array(rest)
	return order


func _missing_core() -> String:
	var nodes: Dictionary[String, Node] = saveables()
	for key: String in CORE:
		if not nodes.has(key):
			return key
	return ""


func _fail(message: String) -> bool:
	last_error = message
	Events.save_failed.emit(message)
	Events.hint_shown.emit(message)
	return false


func _on_day_started(_day: int) -> void:
	if not autosave_enabled or _autosave_waiting:
		return
	_autosave_waiting = true
	await get_tree().process_frame
	_autosave_waiting = false
	save_game(AUTOSAVE_SLOT)
