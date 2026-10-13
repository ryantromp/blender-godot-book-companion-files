class_name Hud
extends CanvasLayer
## The screen display. Clock and money on top, the tool bar at the bottom, the bag at the right
## (press I), and hints as short messages that fade out.

const SLOT_SCENE: PackedScene = preload("res://scenes/ui/inventory_slot.tscn")
const TOAST_SECONDS: float = 3.0
const HELD_TEXT: Dictionary = {
	&"hoe": "Hoe: break dry ground",
	&"can": "Can: water a planted seed",
	&"hand": "Hands: harvest and feed",
}

@export var farmer: Farmer

var _buttons: Dictionary = {}
var _slots: Array[InventorySlot] = []
var _toast_tween: Tween

@onready var clock_label: Label = %ClockLabel
@onready var weather_label: Label = %WeatherLabel
@onready var money_label: Label = %MoneyLabel
@onready var tool_row: HBoxContainer = %ToolRow
@onready var held_label: Label = %HeldLabel
@onready var water_label: Label = %WaterLabel
@onready var bag_panel: PanelContainer = %BagPanel
@onready var bag_count: Label = %BagCount
@onready var grid: GridContainer = %Grid
@onready var toast: PanelContainer = %Toast
@onready var toast_label: Label = %ToastLabel


func _ready() -> void:
	for button: Button in tool_row.get_children():
		var tool_name := StringName(button.name.to_lower())
		_buttons[tool_name] = button
		button.pressed.connect(_on_tool_pressed.bind(tool_name))
	for index: int in Inventory.SLOT_COUNT:
		var slot: InventorySlot = SLOT_SCENE.instantiate()
		grid.add_child(slot)
		_slots.append(slot)
	Events.tool_changed.connect(_on_tool_changed)
	Events.water_level_changed.connect(_on_water_level_changed)
	Events.money_changed.connect(_on_money_changed)
	Events.weather_changed.connect(_on_weather_changed)
	Events.inventory_changed.connect(_on_inventory_changed)
	Events.item_added.connect(_on_item_added)
	Events.hint_shown.connect(show_toast)
	bag_panel.visible = false
	toast.visible = false
	_on_money_changed(Economy.money)
	_on_water_level_changed(farmer.can.water_level, farmer.can.capacity)
	_on_tool_changed(farmer.tools.current, farmer.tools.crop)
	_refresh_bag()


func _process(_delta: float) -> void:
	clock_label.text = "Day %d   %s" % [GameClock.day, GameClock.time_text()]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		toggle_bag()
		get_viewport().set_input_as_handled()


func toggle_bag() -> void:
	bag_panel.visible = not bag_panel.visible
	_refresh_bag()


## Shows a short message in the middle at the top. It fades out after TOAST_SECONDS.
func show_toast(text: String) -> void:
	toast_label.text = text
	toast.modulate.a = 1.0
	toast.visible = true
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(toast.hide)


func _refresh_bag() -> void:
	if not bag_panel.visible:
		return
	for index: int in _slots.size():
		_slots[index].show_stack(Inventory.slots[index])
	bag_count.text = "%d / %d" % [Inventory.used_slots(), Inventory.SLOT_COUNT]


func _update_held() -> void:
	var tool_name: StringName = farmer.tools.current
	if tool_name == &"seeds" and farmer.tools.crop != null:
		var seed_item: ItemData = farmer.tools.crop.seed_item
		held_label.text = "%s x%d" % [seed_item.display_name, Inventory.count_of(seed_item)]
	else:
		held_label.text = String(HELD_TEXT.get(tool_name, ""))


func _on_tool_pressed(tool_name: StringName) -> void:
	farmer.tools.select(tool_name)


func _on_tool_changed(tool_name: StringName, _crop: CropData) -> void:
	for key: StringName in _buttons:
		(_buttons[key] as Button).set_pressed_no_signal(key == tool_name)
	_update_held()


func _on_water_level_changed(level: int, capacity: int) -> void:
	water_label.text = "Water %d / %d" % [level, capacity]


func _on_weather_changed(state: Weather.State) -> void:
	weather_label.text = Weather.NAMES[state]


func _on_money_changed(money: int) -> void:
	money_label.text = "%d coins" % money


func _on_inventory_changed() -> void:
	_refresh_bag()
	_update_held()


func _on_item_added(item: ItemData, amount: int) -> void:
	show_toast("+%d %s" % [amount, item.display_name])


func _on_bag_button_pressed() -> void:
	toggle_bag()
