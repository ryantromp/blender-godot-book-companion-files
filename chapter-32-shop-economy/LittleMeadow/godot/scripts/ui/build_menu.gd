class_name BuildMenu
extends Control
## The build palette and the hint line. It shows what BuildMode says.

const SLOT_SCENE: PackedScene = preload("res://scenes/ui/build_slot.tscn")

@export var build: BuildMode

var _slots: Array[BuildSlot] = []

@onready var palette: PanelContainer = %Palette
@onready var banner: PanelContainer = %Banner
@onready var tabs: TabBar = %Tabs
@onready var slot_row: HBoxContainer = %Slots
@onready var status_label: Label = %StatusLabel
@onready var remove_button: Button = %RemoveButton
@onready var open_button: Button = %OpenButton


func _ready() -> void:
	for tab_name: String in BuildItemData.CATEGORY_NAMES:
		tabs.add_tab(tab_name)
	_make_slots()
	tabs.tab_changed.connect(_on_tab_changed)
	build.item_changed.connect(_on_item_changed)
	build.category_changed.connect(_on_category_changed)
	build.removing_changed.connect(remove_button.set_pressed_no_signal)
	build.status_changed.connect(_on_status_changed)
	Events.build_mode_changed.connect(_on_mode_changed)
	Events.money_changed.connect(_on_money_changed)
	remove_button.toggled.connect(build.set_removing)
	%DoneButton.pressed.connect(build.set_active.bind(false))
	open_button.pressed.connect(build.set_active.bind(true))
	Events.plan_unlocked.connect(_make_slots.unbind(1))
	_on_mode_changed(build.active)


func _make_slots() -> void:
	for slot: BuildSlot in _slots:
		slot_row.remove_child(slot)
		slot.queue_free()
	_slots.clear()
	for item: BuildItemData in build.catalog.items:
		if item.unlocked:
			var slot: BuildSlot = SLOT_SCENE.instantiate()
			slot_row.add_child(slot)
			slot.show_item(item, build.catalog.in_category(item.category).find(item) + 1)
			slot.picked.connect(build.select)
			_slots.append(slot)
	for index: int in tabs.tab_count:
		tabs.set_tab_hidden(index, build.catalog.in_category(index as BuildItemData.Category).is_empty())
	_on_category_changed(build.category)
	_on_item_changed(build.current)
	_on_money_changed(Economy.money)


func _on_mode_changed(active: bool) -> void:
	palette.visible = active
	banner.visible = active
	open_button.visible = not active


func _on_tab_changed(index: int) -> void:
	build.set_category(index as BuildItemData.Category)


func _on_category_changed(category: BuildItemData.Category) -> void:
	tabs.current_tab = category
	for slot: BuildSlot in _slots:
		slot.visible = slot.item.category == category


func _on_item_changed(item: BuildItemData) -> void:
	for slot: BuildSlot in _slots:
		slot.set_selected(slot.item == item)


func _on_status_changed(text: String, fits: bool) -> void:
	status_label.text = text
	status_label.modulate = Color.WHITE if fits else Color("FF9A8A")


func _on_money_changed(money: int) -> void:
	for slot: BuildSlot in _slots:
		slot.set_affordable(slot.item.cost <= money)
