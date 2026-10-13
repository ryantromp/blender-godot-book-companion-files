class_name Shop
extends Node

@export var stock: ShopStock

var market: Market = Market.new()


func _ready() -> void:
	market.day = GameClock.day
	Events.day_started.connect(_on_day_started)


func buy_problem(item: ItemData, amount: int = 1) -> String:
	if not stock.buy_items.has(item):
		return "That is not for sale."
	if Economy.money < item.buy_price * amount:
		return "Not enough coins: you need %d." % (item.buy_price * amount)
	if not Inventory.can_add(item, amount):
		return "There is no room in your bag for %d." % amount
	return ""


func buy(item: ItemData, amount: int = 1) -> String:
	var problem: String = buy_problem(item, amount)
	if problem != "":
		Events.trade_denied.emit(problem)
		return problem
	var price: int = item.buy_price * amount
	Economy.spend(price, "Bought %d %s" % [amount, item.display_name])
	Inventory.add(item, amount)
	Events.item_bought.emit(item, amount, price)
	return ""


func sell_problem(item: ItemData, amount: int = 1) -> String:
	if item.sell_price <= 0:
		return "The stall does not buy that."
	if amount <= 0 or Inventory.count_of(item) < amount:
		return "You do not have that many."
	return ""


func sell(item: ItemData, amount: int = 1) -> String:
	var problem: String = sell_problem(item, amount)
	if problem != "":
		Events.trade_denied.emit(problem)
		return problem
	var coins: int = market.quote(item, amount)
	Inventory.remove(item, amount)
	market.record(item, amount)
	Economy.add_money(coins, "Sold %d %s" % [amount, item.display_name])
	Events.item_sold.emit(item, amount, coins)
	return ""


func sell_all(item: ItemData) -> String:
	return sell(item, Inventory.count_of(item))


func plan_problem(plan: BuildItemData) -> String:
	if plan.unlocked:
		return "You already have this plan."
	if Economy.money < plan.unlock_price:
		return "Not enough coins: you need %d." % plan.unlock_price
	return ""


func unlock(plan: BuildItemData) -> String:
	var problem: String = plan_problem(plan)
	if problem != "":
		Events.trade_denied.emit(problem)
		return problem
	Economy.spend(plan.unlock_price, "Plan for the %s" % plan.display_name.to_lower())
	plan.unlocked = true
	Events.plan_unlocked.emit(plan)
	return ""


func to_save() -> Dictionary:
	var unlocked: Array[String] = []
	for plan: BuildItemData in stock.plans:
		if plan.unlocked:
			unlocked.append(String(plan.id))
	var sold: Dictionary = {}
	for id: StringName in market.sold:
		sold[String(id)] = market.sold[id]
	return {"sold": sold, "unlocked": unlocked}


func from_save(data: Dictionary) -> void:
	market.sold.clear()
	for id: String in data["sold"]:
		market.sold[StringName(id)] = int(data["sold"][id])
	market.day = GameClock.day
	for plan: BuildItemData in stock.plans:
		plan.unlocked = data["unlocked"].has(String(plan.id))
		if plan.unlocked:
			Events.plan_unlocked.emit(plan)


func _on_day_started(day: int) -> void:
	market.new_day(day)
