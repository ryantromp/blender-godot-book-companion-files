extends Node

const TITLE: String = "res://scenes/ui/title.tscn"
const FARM: String = "res://scenes/world/farm.tscn"
const STOCK: ShopStock = preload("res://resources/shop/stock.tres")
const WINDOW_TITLE: String = "Little Meadow"

var fade_seconds: float = 0.5
var busy: bool = false
var last_message: String = ""

var _veil: ColorRect
var _fps: Label
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().title = WINDOW_TITLE
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color(0.06, 0.09, 0.07, 0.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_veil)
	_fps = Label.new()
	_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps.position = Vector2(-120.0, 8.0)
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fps)
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()
	get_tree().node_added.connect(_on_node_added)


func _process(_delta: float) -> void:
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


func farm_running() -> bool:
	return SaveSystem.saveables().has("farmer")


func newest_slot() -> int:
	var best: int = -1
	var best_time: String = ""
	for entry: Dictionary in SaveSystem.list_slots():
		if entry["exists"] and entry["error"] == "" and String(entry["saved_at"]) >= best_time:
			best = entry["slot"]
			best_time = entry["saved_at"]
	return best


func reset_run() -> void:
	GameClock.set_time(1, 6 * 60)
	GameClock.paused = false
	Inventory.clear()
	Inventory.give_starting_items()
	Economy.from_save({"money": Economy.START_MONEY, "ledger": []})
	SaveSystem.playtime = 0.0
	SaveSystem.current_slot = 1
	SaveSystem.last_error = ""
	Fx.active = 0
	for plan: BuildItemData in STOCK.plans:
		plan.unlocked = false
	AudioBus.reset_world()


func new_game() -> void:
	await _enter_farm(-1)


func continue_game() -> void:
	var slot: int = newest_slot()
	if slot >= 0:
		await _enter_farm(slot)


func load_slot(slot: int) -> bool:
	if farm_running():
		return SaveSystem.load_game(slot)
	_enter_farm(slot)
	return true


func to_title(message: String = "") -> void:
	if busy:
		return
	busy = true
	if message == "" and farm_running() and SaveSystem.autosave_enabled:
		SaveSystem.save_game(SaveSystem.AUTOSAVE_SLOT)
	last_message = message
	await _fade_to(1.0)
	get_tree().paused = false
	GameClock.running = false
	reset_run()
	get_tree().change_scene_to_file(TITLE)
	await get_tree().scene_changed
	await _fade_to(0.0)
	busy = false


func quit_game() -> void:
	if farm_running() and SaveSystem.autosave_enabled:
		SaveSystem.save_game(SaveSystem.AUTOSAVE_SLOT)
	get_tree().quit()


func _enter_farm(slot: int) -> void:
	if busy:
		return
	busy = true
	await _fade_to(1.0)
	reset_run()
	GameClock.running = true
	get_tree().change_scene_to_file(FARM)
	await get_tree().scene_changed
	await get_tree().process_frame
	if slot >= 0 and not SaveSystem.load_game(slot):
		var message: String = SaveSystem.last_error
		busy = false
		to_title(message)
		return
	await _fade_to(0.0)
	busy = false


func _fade_to(alpha: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	if fade_seconds <= 0.0:
		_veil.color.a = alpha
		return
	_tween = create_tween()
	_tween.tween_property(_veil, "color:a", alpha, fade_seconds)
	await _tween.finished


func _on_settings_changed() -> void:
	_fps.visible = Settings.show_fps


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
