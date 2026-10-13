class_name ShopPanel
extends Control

const SLOT_SCENE: PackedScene = preload("res://scenes/ui/inventory_slot.tscn")
const GOOD: Color = Color("9BE29B")
const BAD: Color = Color("FF9A8A")

@export var shop: Shop
@export var build: BuildMode

var is_open: bool = false

var _was_paused: bool = false

@onready var tabs: TabContainer = %Tabs
@onready var buy_grid: GridContainer = %BuyGrid
@onready var sell_grid: GridContainer = %SellGrid
@onready var plan_grid: GridContainer = %PlanGrid
@onready var purse_label: Label = %PurseLabel
@onready var message_label: Label = %MessageLabel


func _ready() -> void:
	visible = false
	Events.shop_requested.connect(open)
	Events.money_changed.connect(_on_changed.unbind(1))
	Events.inventory_changed.connect(_on_changed)
	Events.plan_unlocked.connect(_on_changed.unbind(1))
	Events.item_bought.connect(_on_bought)
	Events.item_sold.connect(_on_sold)
	Events.plan_unlocked.connect(_on_unlocked)
	Events.trade_denied.connect(_say)


func open() -> bool:
	if is_open:
		return true
	if build != null and build.active:
		Events.hint_shown.emit("Close build mode first.")
		return false
	is_open = true
	_was_paused = GameClock.paused
	GameClock.paused = true
	add_to_group(&"modal")
	visible = true
	tabs.current_tab = 0
	_say("Welcome. Buy seeds and feed, sell what you grew.")
	_refresh()
	Events.shop_opened.emit()
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	GameClock.paused = _was_paused
	remove_from_group(&"modal")
	visible = false
	Events.shop_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	for number: int in tabs.get_tab_count():
		if event.is_action_pressed("tool_%d" % (number + 1)):
			tabs.current_tab = number
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	if not is_open:
		return
	purse_label.text = "%d coins" % Economy.money
	_clear(buy_grid)
	for item: ItemData in shop.stock.buy_items:
		var have: int = Inventory.count_of(item)
		_add_row(buy_grid, item, have, "%s\nyou have %d" % [item.display_name, have], "%d coins" % item.buy_price, [
			["Buy 1", shop.buy_problem(item, 1), shop.buy.bind(item, 1)],
			["Buy 5", shop.buy_problem(item, 5), shop.buy.bind(item, 5)]])
	_clear(sell_grid)
	for item: ItemData in _sellable():
		var have: int = Inventory.count_of(item)
		var now: int = shop.market.price_of(item)
		var price: String = "%d each" % now
		if now != item.sell_price:
			price += "\nusually %d" % item.sell_price
		_add_row(sell_grid, item, have, "%s\nyou have %d" % [item.display_name, have], price, [
			["Sell 1", shop.sell_problem(item, 1), shop.sell.bind(item, 1)],
			["Sell all: %d" % shop.market.quote(item, have), shop.sell_problem(item, have), shop.sell_all.bind(item)]],
			GOOD if now > item.sell_price else BAD if now < item.sell_price else Color.WHITE)
	if sell_grid.get_child_count() == 0:
		_add_note(sell_grid, "Nothing to sell yet. Harvest a crop or collect an egg.")
	_clear(plan_grid)
	for plan: BuildItemData in shop.stock.plans:
		_add_row(plan_grid, _icon_for(plan), 1, "%s\n%d by %d cells, builds for %d" % [plan.display_name, plan.footprint.x, plan.footprint.y, plan.cost],
			"owned" if plan.unlocked else "%d coins" % plan.unlock_price, [
			["Owned" if plan.unlocked else "Unlock", shop.plan_problem(plan), shop.unlock.bind(plan)]])


func _sellable() -> Array[ItemData]:
	var found: Array[ItemData] = []
	for stack: ItemStack in Inventory.slots:
		if not stack.is_empty() and stack.item.sell_price > 0 and not found.has(stack.item):
			found.append(stack.item)
	return found


func _icon_for(plan: BuildItemData) -> ItemData:
	var item := ItemData.new()
	item.display_name = plan.display_name
	item.color = plan.color
	item.short_name = plan.short_name
	return item


func _add_row(grid: GridContainer, item: ItemData, count: int, text: String, price: String, buttons: Array, price_color: Color = Color.WHITE) -> void:
	var slot: InventorySlot = SLOT_SCENE.instantiate()
	grid.add_child(slot)
	var stack := ItemStack.new()
	stack.item = item
	stack.count = maxi(count, 1)
	slot.show_stack(stack)
	slot.tooltip_text = item.display_name
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 250.0
	grid.add_child(label)
	var price_label := Label.new()
	price_label.text = price
	price_label.custom_minimum_size.x = 120.0
	price_label.add_theme_color_override("font_color", price_color)
	grid.add_child(price_label)
	for entry: Array in buttons:
		var button := Button.new()
		button.text = entry[0]
		button.disabled = entry[1] != ""
		button.tooltip_text = entry[1]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[2])
		grid.add_child(button)
	for cell: Control in [slot, label, price_label]:
		cell.modulate.a = 0.45 if buttons[0][1] != "" else 1.0


func _add_note(grid: GridContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	grid.add_child(label)


func _clear(grid: GridContainer) -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


func _say(text: String) -> void:
	message_label.text = text


func _on_changed() -> void:
	_refresh()


func _on_bought(item: ItemData, amount: int, coins: int) -> void:
	_say("Bought %d %s for %d coins." % [amount, item.display_name, coins])


func _on_sold(item: ItemData, amount: int, coins: int) -> void:
	_say("Sold %d %s for %d coins." % [amount, item.display_name, coins])


func _on_unlocked(plan: BuildItemData) -> void:
	_say("You can build the %s now. Press B." % plan.display_name.to_lower())
