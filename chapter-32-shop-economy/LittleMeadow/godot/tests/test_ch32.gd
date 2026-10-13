extends Node

const FARM: String = "res://scenes/world/farm.tscn"
const STOCK: String = "res://resources/shop/stock.tres"
const ITEMS: String = "res://resources/items/"
const PROBE := Vector3(0.5, 0.0, 12.0)
const TICKS: int = 480
const SPEEDUP: float = 8.0

var _log: Array[String] = []
var _shops: Array[Shop] = []
var _stock_ref: ShopStock
var _catalog: BuildCatalog


func before_each(_t: Variant) -> void:
	Engine.physics_ticks_per_second = TICKS
	Engine.time_scale = SPEEDUP
	GameClock.running = false
	GameClock.paused = false
	GameClock.set_time(1, 360)
	Inventory.clear()
	Inventory.give_starting_items()
	Economy.money = Economy.START_MONEY
	Economy.ledger.clear()
	for plan: BuildItemData in _stock().plans:
		plan.unlocked = false
	_catalog = load("res://resources/buildables/catalog.tres") as BuildCatalog
	for item: BuildItemData in _catalog.items:
		if item.id != &"shed" and item.id != &"well":
			item.unlocked = true
	for node: Node in Engine.get_main_loop().root.get_children():
		if node.scene_file_path == FARM:
			node.free()
	for node: Node in Engine.get_main_loop().get_nodes_in_group(&"fx"):
		node.free()
	Fx.active = 0
	_log.clear()
	if not Events.money_moved.is_connected(_on_moved):
		Events.money_moved.connect(_on_moved)
		Events.item_bought.connect(_on_bought)
		Events.item_sold.connect(_on_sold)
		Events.plan_unlocked.connect(_on_plan)
		Events.trade_denied.connect(_on_denied)
		Events.day_summary.connect(_on_summary)
		Events.shop_opened.connect(_on_opened)
		Events.shop_closed.connect(_on_closed)
		Events.hint_shown.connect(_on_hint)


func after_each(_t: Variant) -> void:
	for shop: Shop in _shops:
		if is_instance_valid(shop):
			shop.free()
	_shops.clear()
	for plan: BuildItemData in _stock().plans:
		plan.unlocked = true
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	GameClock.running = false
	GameClock.paused = false


func _on_moved(amount: int, reason: String) -> void:
	_log.append("moved:%d:%s" % [amount, reason])


func _on_bought(item: ItemData, amount: int, coins: int) -> void:
	_log.append("bought:%s:%d:%d" % [item.id, amount, coins])


func _on_sold(item: ItemData, amount: int, coins: int) -> void:
	_log.append("sold:%s:%d:%d" % [item.id, amount, coins])


func _on_plan(plan: BuildItemData) -> void:
	_log.append("plan:%s" % plan.id)


func _on_denied(reason: String) -> void:
	_log.append("denied:" + reason)


func _on_summary(day: int, earned: int, spent: int) -> void:
	_log.append("summary:%d:%d:%d" % [day, earned, spent])


func _on_opened() -> void:
	_log.append("opened")


func _on_closed() -> void:
	_log.append("closed")


func _on_hint(text: String) -> void:
	_log.append("hint:" + text)


func _count(prefix: String) -> int:
	var n: int = 0
	for line: String in _log:
		if line.begins_with(prefix):
			n += 1
	return n


func _stock() -> ShopStock:
	_stock_ref = load(STOCK) as ShopStock
	return _stock_ref


func _item(id: String) -> ItemData:
	return load(ITEMS + id + ".tres") as ItemData


func _shop() -> Shop:
	var shop := Shop.new()
	shop.stock = _stock()
	add_child(shop)
	_shops.append(shop)
	return shop


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var up := event.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)


func _fill_bag_except(keep: int, filler: ItemData) -> void:
	Inventory.clear()
	Inventory.add(filler, filler.stack_size * (Inventory.SLOT_COUNT - keep))


func _farm(t: Variant) -> Node:
	await t.frames(2)
	var farm: Node = t.load_scene(FARM)
	await t.physics_frames(3)
	var map: RID = (farm.get_node("World") as NavigationRegion3D).get_navigation_map()
	var waited: int = 0
	while NavigationServer3D.map_get_closest_point(map, PROBE).distance_to(PROBE) > 1.0 and waited < 300:
		NavigationServer3D.map_force_update(map)
		await t.physics_frames(1)
		waited += 1
	return farm


func _panel(farm: Node) -> ShopPanel:
	return farm.get_node("Hud/ShopPanel") as ShopPanel


func _feedback(farm: Node) -> MoneyFeedback:
	return farm.get_node("Hud/MoneyFeedback") as MoneyFeedback


func _buttons(grid: GridContainer) -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in grid.get_children():
		if child is Button:
			found.append(child as Button)
	return found


func _look_at(farm: Node, point: Vector3) -> CameraRig:
	var rig := farm.get_node("CameraRig") as CameraRig
	rig.target = null
	rig.global_position = point
	rig.snap()
	return rig


func _screen(farm: Node, point: Vector3) -> Vector2:
	return (farm.get_node("CameraRig") as CameraRig).camera.unproject_position(point)


func test_the_wobble_repeats_and_stays_within_ten_percent(t: Variant) -> void:
	var carrot: ItemData = _item("carrot")
	var first := Market.new()
	var second := Market.new()
	for day: int in range(1, 31):
		first.day = day
		second.day = day
		var wobble: float = first.wobble(carrot)
		t.approx(wobble, second.wobble(carrot), 0.000001, "day %d: the same seed, day and item give the same wobble" % day)
		t.ok(wobble >= 0.90 - 0.0001 and wobble <= 1.10 + 0.0001, "day %d: %.2f is within 90 to 110 percent" % [day, wobble])
		var steps: float = (wobble - 1.0) / 0.05
		t.approx(steps, roundf(steps), 0.0001, "day %d: the wobble is a whole number of 5 percent steps" % day)


func test_the_wobble_changes_with_the_day_the_item_and_the_world_seed(t: Variant) -> void:
	var carrot: ItemData = _item("carrot")
	var wheat: ItemData = _item("wheat")
	var market := Market.new()
	var seen: Dictionary = {}
	var differs: bool = false
	var other_seed := Market.new()
	other_seed.world_seed = 7
	var seed_differs: bool = false
	for day: int in range(1, 31):
		market.day = day
		other_seed.day = day
		seen[market.wobble(carrot)] = true
		differs = differs or not is_equal_approx(market.wobble(carrot), market.wobble(wheat))
		seed_differs = seed_differs or not is_equal_approx(market.wobble(carrot), other_seed.wobble(carrot))
	t.ok(seen.size() >= 4, "30 days of carrots show %d different wobbles" % seen.size())
	t.ok(differs, "carrots and wheat do not wobble together")
	t.ok(seed_differs, "another world seed gives another year")


func test_demand_falls_five_percent_a_unit_down_to_half(t: Variant) -> void:
	var carrot: ItemData = _item("carrot")
	var market := Market.new()
	t.approx(market.demand(carrot), 1.0, 0.0001, "nothing sold: full price")
	market.record(carrot, 1)
	t.approx(market.demand(carrot), 0.95, 0.0001, "one sold")
	market.record(carrot, 2)
	t.approx(market.demand(carrot), 0.85, 0.0001, "three sold")
	t.approx(market.demand(carrot, 2), 0.75, 0.0001, "two more would take it to 75 percent")
	market.record(carrot, 7)
	t.approx(market.demand(carrot), 0.5, 0.0001, "ten sold: half")
	t.approx(market.demand(carrot, 5), 0.5, 0.0001, "and never lower than half")
	t.approx(market.demand(_item("wheat")), 1.0, 0.0001, "wheat is not touched by carrots")


func test_the_price_is_the_usual_price_times_wobble_times_demand(t: Variant) -> void:
	var carrot: ItemData = _item("carrot")
	var market := Market.new()
	for day: int in range(1, 8):
		market.day = day
		var wobble: float = market.wobble(carrot)
		t.eq(market.price_of(carrot), roundi(12.0 * wobble), "day %d: 12 coins times %.2f" % [day, wobble])
	market.day = 1
	market.record(carrot, 4)
	t.eq(market.price_of(carrot), roundi(12.0 * market.wobble(carrot) * 0.8), "four sold: 80 percent")
	var egg: ItemData = _item("egg")
	market.record(egg, 20)
	t.ok(market.price_of(egg) >= 1, "a price never falls below one coin")
	var cheap := ItemData.new()
	cheap.sell_price = 1
	market.sold[cheap.id] = 10
	t.eq(market.price_of(cheap), 1, "half of one coin is still one coin")


func test_what_the_stall_does_not_buy_costs_nothing_to_ask_about(t: Variant) -> void:
	var market := Market.new()
	t.eq(market.price_of(_item("seed_carrot")), 0, "seeds have no sell price")
	t.eq(market.price_of(_item("hay")), 0, "neither has hay")
	t.eq(market.quote(_item("seed_carrot"), 5), 0, "five of them are worth 0")


func test_a_quote_adds_each_unit_at_the_price_the_one_before_left_behind(t: Variant) -> void:
	var carrot: ItemData = _item("carrot")
	var market := Market.new()
	var expected: int = 0
	for unit: int in 5:
		expected += market.price_of(carrot, unit)
	t.eq(market.quote(carrot, 5), expected, "the quote is the sum of five falling prices")
	t.ok(market.quote(carrot, 5) < 5 * market.price_of(carrot), "so it is less than five times the first price")
	t.eq(market.quote(carrot, 1), market.price_of(carrot), "one unit is the price")
	t.eq(market.quote(carrot, 0), 0, "none is nothing")
	t.eq(market.sold.size(), 0, "asking never changes the market")


func test_selling_is_remembered_and_the_memory_is_capped(t: Variant) -> void:
	var carrot: ItemData = _item("carrot")
	var market := Market.new()
	market.record(carrot, 3)
	market.record(carrot, 4)
	t.eq(market.sold[&"carrot"], 7, "3 and 4 make 7")
	market.record(carrot, 100)
	t.eq(market.sold[&"carrot"], Market.MAX_SOLD, "the count stops at %d" % Market.MAX_SOLD)


func test_four_units_come_back_each_morning(t: Variant) -> void:
	var carrot: ItemData = _item("carrot")
	var market := Market.new()
	market.record(carrot, 10)
	market.new_day(2)
	t.eq(market.day, 2, "the market knows the day")
	t.eq(market.sold[&"carrot"], 6, "10 less 4")
	market.new_day(3)
	t.eq(market.sold[&"carrot"], 2, "6 less 4")
	market.new_day(4)
	t.ok(not market.sold.has(&"carrot"), "2 less 4 is nothing: the entry is gone")
	t.approx(market.demand(carrot), 1.0, 0.0001, "full price again")
	market.record(carrot, Market.MAX_SOLD)
	for day: int in range(5, 10):
		market.new_day(day)
	t.ok(not market.sold.has(&"carrot"), "a full market is back to normal after five mornings")


func test_the_rule_in_numbers_for_day_one(t: Variant) -> void:
	var market := Market.new()
	var wobble: float = market.wobble(_item("carrot"))
	var line: Array[String] = []
	for sold: int in 11:
		line.append(str(market.price_of(_item("carrot"), sold)))
	print("LM32 carrot day 1: wobble %.2f, prices after 0..10 sold: %s" % [wobble, ", ".join(line)])
	t.eq(line, ["11", "10", "10", "9", "9", "8", "8", "7", "6", "6", "5"] as Array[String], "the numbers of the book (wobble 0.90 on day 1)")
	for sold: int in 10:
		t.ok(market.price_of(_item("carrot"), sold + 1) <= market.price_of(_item("carrot"), sold), "the price never goes up while selling (%d)" % sold)


func test_the_purse_starts_with_one_hundred_coins(t: Variant) -> void:
	t.eq(Economy.START_MONEY, 100, "the constant")
	t.eq(Economy.money, 100, "the purse of a new game")
	t.eq(Economy.ledger.size(), 0, "and the book is empty")


func test_the_ledger_remembers_day_amount_reason_and_balance(t: Variant) -> void:
	Economy.add_money(30, "Sold 2 Carrot")
	GameClock.set_time(2, 400)
	t.ok(Economy.spend(12, "Bought 3 Carrot seeds"), "the spend worked")
	t.eq(Economy.ledger.size(), 2, "two lines")
	t.eq(Economy.ledger[0], {"day": 1, "amount": 30, "reason": "Sold 2 Carrot", "balance": 130}, "the first line")
	t.eq(Economy.ledger[1], {"day": 2, "amount": -12, "reason": "Bought 3 Carrot seeds", "balance": 118}, "the second line: minus when spent")
	t.eq(Economy.money, 118, "the purse")


func test_a_refused_spend_and_a_zero_move_leave_no_trace(t: Variant) -> void:
	t.ok(not Economy.spend(101, "too much"), "101 of 100 is refused")
	t.ok(not Economy.spend(-5, "negative"), "a negative spend is refused")
	Economy.add_money(0, "nothing")
	Economy.add_money(-5, "negative")
	t.ok(Economy.spend(0, "free"), "spending 0 works")
	t.eq(Economy.money, 100, "the purse is unchanged")
	t.eq(Economy.ledger.size(), 0, "and nothing was written")
	t.eq(_count("moved"), 0, "and nothing was announced")


func test_the_ledger_keeps_the_last_two_hundred_lines(t: Variant) -> void:
	for number: int in 250:
		Economy.add_money(1, "line %d" % number)
	t.eq(Economy.ledger.size(), Economy.LEDGER_LIMIT, "capped")
	t.eq(Economy.ledger[0]["reason"], "line 50", "the 50 oldest lines were dropped")
	t.eq(Economy.ledger[-1]["reason"], "line 249", "the newest is last")
	t.eq(Economy.money, 350, "the purse counts every coin, also those of dropped lines")


func test_a_day_adds_up_to_earned_spent_and_net(t: Variant) -> void:
	Economy.add_money(40, "Sold")
	Economy.spend(15, "Bought")
	Economy.add_money(5, "Sold")
	GameClock.set_time(2, 360)
	Economy.add_money(99, "Sold on day 2")
	t.eq(Economy.entries_for(1).size(), 3, "three lines on day 1")
	t.eq(Economy.entries_for(3).size(), 0, "none on day 3")
	t.eq(Economy.summary_for(1), {"day": 1, "earned": 45, "spent": 15, "net": 30}, "day 1")
	t.eq(Economy.summary_for(2), {"day": 2, "earned": 99, "spent": 0, "net": 99}, "day 2")
	t.eq(Economy.summary_for(3), {"day": 3, "earned": 0, "spent": 0, "net": 0}, "day 3")


func test_a_new_day_sends_the_summary_of_the_day_before(t: Variant) -> void:
	Economy.add_money(40, "Sold")
	Economy.spend(15, "Bought")
	Events.day_started.emit(2)
	t.eq(_count("summary"), 1, "one summary")
	t.ok(_log.has("summary:1:40:15"), "day 1: earned 40, spent 15")
	Events.day_started.emit(3)
	t.ok(_log.has("summary:2:0:0"), "a quiet day sends zeros (the window decides to stay away)")


func test_every_move_is_announced_with_its_sign_and_reason(t: Variant) -> void:
	Economy.add_money(7, "Sold 1 Egg")
	Economy.spend(3, "Bought 1 Hay")
	t.eq(_log, ["moved:7:Sold 1 Egg", "moved:-3:Bought 1 Hay"] as Array[String], "plus when earned, minus when spent")


func test_the_purse_and_the_book_survive_a_save(t: Variant) -> void:
	Economy.add_money(40, "Sold")
	Economy.spend(15, "Bought")
	var data: Dictionary = Economy.to_save()
	var json: String = JSON.stringify(data)
	Economy.money = 1
	Economy.ledger.clear()
	Economy.from_save(JSON.parse_string(json) as Dictionary)
	t.eq(Economy.money, 125, "the purse")
	t.eq(Economy.ledger.size(), 2, "the book")
	t.eq(Economy.ledger[1], {"day": 1, "amount": -15, "reason": "Bought", "balance": 125}, "a line, after a trip through JSON (floats became ints again)")
	t.eq(typeof(Economy.ledger[1]["amount"]), TYPE_INT, "an int")


func test_the_stock_file_lists_six_things_and_two_plans(t: Variant) -> void:
	var stock: ShopStock = _stock()
	t.eq(stock.buy_items.size(), 6, "three seeds, grain, hay and dog biscuits")
	t.eq(stock.plans.size(), 2, "the shed and the well")
	var ids: Array[String] = []
	for item: ItemData in stock.buy_items:
		ids.append(String(item.id))
		t.ok(item.buy_price > 0, "%s has a price" % item.id)
		t.ok(item.sell_price == 0, "%s cannot be sold back, so buying is never a loop" % item.id)
	ids.sort()
	t.eq(ids, ["dog_biscuit", "grain", "hay", "seed_carrot", "seed_pumpkin", "seed_wheat"] as Array[String], "the six")
	var plans: Array[String] = []
	for plan: BuildItemData in stock.plans:
		plans.append(String(plan.id))
		t.ok(plan.unlock_price > 0, "%s has a price" % plan.id)
	plans.sort()
	t.eq(plans, ["shed", "well"] as Array[String], "the plans")


func test_every_crop_pays_more_than_its_seed_costs(t: Variant) -> void:
	var market := Market.new()
	for pair: Array in [["carrot", "seed_carrot"], ["wheat", "seed_wheat"], ["pumpkin", "seed_pumpkin"]]:
		var crop: ItemData = _item(pair[0])
		var seed_item: ItemData = _item(pair[1])
		for day: int in range(1, 31):
			market.day = day
			t.ok(market.price_of(crop) > seed_item.buy_price, "day %d: a %s sells for %d, its seed costs %d" % [day, crop.id, market.price_of(crop), seed_item.buy_price])


func test_buying_charges_gives_and_tells(t: Variant) -> void:
	var shop: Shop = _shop()
	var seeds: ItemData = _item("seed_carrot")
	var before: int = Inventory.count_of(seeds)
	t.eq(shop.buy(seeds, 3), "", "no problem")
	t.eq(Economy.money, 100 - 3 * seeds.buy_price, "3 seeds at %d" % seeds.buy_price)
	t.eq(Inventory.count_of(seeds), before + 3, "three more in the bag")
	t.eq(_log, ["moved:-12:Bought 3 Carrot seeds", "bought:seed_carrot:3:12"] as Array[String], "the purse spoke first, then the shop")
	t.eq(Economy.ledger[0]["reason"], "Bought 3 Carrot seeds", "the book has the reason")


func test_buying_without_enough_coins_changes_nothing(t: Variant) -> void:
	var shop: Shop = _shop()
	var seeds: ItemData = _item("seed_pumpkin")
	Economy.money = 13
	var before: int = Inventory.count_of(seeds)
	var problem: String = shop.buy(seeds, 1)
	t.eq(problem, "Not enough coins: you need 14.", "the message says how much")
	t.eq(Economy.money, 13, "no coin left the purse")
	t.eq(Inventory.count_of(seeds), before, "nothing came into the bag")
	t.eq(Economy.ledger.size(), 0, "nothing in the book")
	t.eq(_log, ["denied:Not enough coins: you need 14."] as Array[String], "one denial and nothing else")
	t.eq(shop.buy_problem(seeds, 1), problem, "buy_problem gives the same text without doing anything")
	Economy.money = 14
	t.eq(shop.buy(seeds, 1), "", "exactly enough is enough")
	t.eq(Economy.money, 0, "and now the purse is empty")


func test_buying_into_a_full_bag_changes_nothing(t: Variant) -> void:
	var shop: Shop = _shop()
	var seeds: ItemData = _item("seed_carrot")
	_fill_bag_except(0, _item("hay"))
	t.eq(Inventory.used_slots(), Inventory.SLOT_COUNT, "the bag is full of hay")
	var problem: String = shop.buy(seeds, 1)
	t.eq(problem, "There is no room in your bag for 1.", "the message")
	t.eq(Economy.money, 100, "no charge")
	t.eq(Inventory.count_of(seeds), 0, "no seeds")
	t.eq(Economy.ledger.size(), 0, "no line in the book")


func test_a_purchase_that_would_overflow_a_stack_is_refused_as_a_whole(t: Variant) -> void:
	var shop: Shop = _shop()
	var seeds: ItemData = _item("seed_carrot")
	_fill_bag_except(1, _item("hay"))
	Inventory.add(seeds, seeds.stack_size - 1)
	t.eq(Inventory.count_of(seeds), seeds.stack_size - 1, "one place left in the last stack")
	t.eq(shop.buy(seeds, 5), "There is no room in your bag for 5.", "five do not fit")
	t.eq(Economy.money, 100, "so not even the one that would have fitted is paid for")
	t.eq(Inventory.count_of(seeds), seeds.stack_size - 1, "and none arrived")
	t.eq(shop.buy(seeds, 1), "", "one fits")
	t.eq(Inventory.count_of(seeds), seeds.stack_size, "the stack is full now")
	t.eq(Economy.money, 100 - seeds.buy_price, "and one seed was paid for")
	t.ne(shop.buy(seeds, 1), "", "the next one does not")


func test_buying_what_the_stall_does_not_sell_is_refused(t: Variant) -> void:
	var shop: Shop = _shop()
	t.eq(shop.buy(_item("egg"), 1), "That is not for sale.", "eggs are not on the shelf")
	t.eq(Economy.money, 100, "no charge")
	t.eq(_count("denied"), 1, "one denial")


func test_selling_pays_the_quote_and_the_next_price_is_lower(t: Variant) -> void:
	var shop: Shop = _shop()
	var carrot: ItemData = _item("carrot")
	Inventory.add(carrot, 10)
	var first: int = shop.market.price_of(carrot)
	var quote: int = shop.market.quote(carrot, 3)
	t.eq(shop.sell(carrot, 3), "", "no problem")
	t.eq(Economy.money, 100 + quote, "paid the quote")
	t.eq(Inventory.count_of(carrot), 7, "three left the bag")
	t.eq(shop.market.sold[&"carrot"], 3, "the market remembers three")
	t.ok(shop.market.price_of(carrot) < first, "so the next carrot is cheaper")
	t.eq(_log[1], "sold:carrot:3:%d" % quote, "the shop told the bus what it paid")
	t.eq(Economy.ledger[0]["reason"], "Sold 3 Carrot", "and the book")


func test_selling_what_you_do_not_have_or_what_nobody_wants_is_refused(t: Variant) -> void:
	var shop: Shop = _shop()
	var carrot: ItemData = _item("carrot")
	Inventory.add(carrot, 2)
	t.eq(shop.sell(carrot, 3), "You do not have that many.", "three of two")
	t.eq(shop.sell(carrot, 0), "You do not have that many.", "none at all")
	t.eq(shop.sell(_item("seed_carrot"), 1), "The stall does not buy that.", "seeds")
	t.eq(Inventory.count_of(carrot), 2, "the carrots are still there")
	t.eq(Economy.money, 100, "no coins")
	t.eq(shop.market.sold.size(), 0, "and no memory of a sale")
	t.eq(_count("denied"), 3, "three denials")


func test_sell_all_empties_the_stack_for_the_sum_of_falling_prices(t: Variant) -> void:
	var shop: Shop = _shop()
	var carrot: ItemData = _item("carrot")
	Inventory.add(carrot, 6)
	var expected: int = shop.market.quote(carrot, 6)
	t.eq(shop.sell_all(carrot), "", "no problem")
	t.eq(Inventory.count_of(carrot), 0, "none left")
	t.eq(Economy.money, 100 + expected, "paid for six")
	t.eq(shop.sell_all(carrot), "You do not have that many.", "a second time there is nothing to sell")


func test_the_price_comes_back_in_the_morning_over_the_bus(t: Variant) -> void:
	var shop: Shop = _shop()
	var carrot: ItemData = _item("carrot")
	Inventory.add(carrot, 10)
	shop.sell_all(carrot)
	t.eq(shop.market.sold[&"carrot"], 10, "ten sold")
	Events.day_started.emit(2)
	t.eq(shop.market.day, 2, "the shop heard the new day")
	t.eq(shop.market.sold[&"carrot"], 6, "four units came back")
	t.approx(shop.market.demand(carrot), 0.7, 0.0001, "demand 70 percent")
	Events.day_started.emit(3)
	Events.day_started.emit(4)
	t.approx(shop.market.demand(carrot), 1.0, 0.0001, "after three mornings: full again")


func test_a_plan_is_bought_once_and_unlocks_building(t: Variant) -> void:
	var shop: Shop = _shop()
	var shed: BuildItemData = _stock().plans[0]
	t.ok(not shed.unlocked, "locked at the start")
	t.eq(shop.plan_problem(shed), "", "affordable")
	t.eq(shop.unlock(shed), "", "no problem")
	t.ok(shed.unlocked, "the flag is set")
	t.eq(Economy.money, 100 - shed.unlock_price, "paid %d" % shed.unlock_price)
	t.eq(_log, ["moved:-%d:Plan for the shed" % shed.unlock_price, "plan:shed"] as Array[String], "the purse, then the announcement")
	t.eq(shop.unlock(shed), "You already have this plan.", "the second time")
	t.eq(Economy.money, 100 - shed.unlock_price, "and no second charge")


func test_a_plan_needs_the_coins(t: Variant) -> void:
	var shop: Shop = _shop()
	var well: BuildItemData = _stock().plans[1]
	Economy.money = well.unlock_price - 1
	t.eq(shop.unlock(well), "Not enough coins: you need %d." % well.unlock_price, "one coin short")
	t.ok(not well.unlocked, "still locked")
	t.eq(Economy.money, well.unlock_price - 1, "no charge")


func test_the_stall_remembers_sales_and_plans_in_a_save(t: Variant) -> void:
	var shop: Shop = _shop()
	var carrot: ItemData = _item("carrot")
	Inventory.add(carrot, 5)
	shop.sell(carrot, 5)
	shop.unlock(_stock().plans[0])
	var json: String = JSON.stringify(shop.to_save())
	shop.market.sold.clear()
	_stock().plans[0].unlocked = false
	_log.clear()
	shop.from_save(JSON.parse_string(json) as Dictionary)
	t.eq(shop.market.sold[&"carrot"], 5, "five carrots sold, after a trip through JSON")
	t.ok(_stock().plans[0].unlocked, "the shed is unlocked again")
	t.ok(not _stock().plans[1].unlocked, "the well is not")
	t.eq(_log, ["plan:shed"] as Array[String], "and the menu was told about the shed")


func test_the_files_of_the_shed_and_the_well_say_locked(t: Variant) -> void:
	for id: String in ["shed", "well"]:
		var fresh := ResourceLoader.load("res://resources/buildables/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE) as BuildItemData
		t.ok(not fresh.unlocked, "%s.tres is locked as saved on disk" % id)
	for id: String in ["fence", "corner", "gate", "crate", "trough"]:
		var fresh := ResourceLoader.load("res://resources/buildables/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE) as BuildItemData
		t.ok(fresh.unlocked, "%s.tres is unlocked: the default of the flag is true" % id)
	t.ok(BuildItemData.new().unlocked, "a new BuildItemData is unlocked")


func test_a_locked_plan_is_hidden_from_the_catalog_and_refused_by_the_rules(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build := farm.get_node("Build") as BuildMode
	var shed: BuildItemData = build.catalog.find(&"shed")
	t.ok(not build.catalog.in_category(BuildItemData.Category.BUILDING).has(shed), "the Building list does not show the locked shed")
	var message: String = build.problem_for(shed, Vector2i(10, 8), 0)
	t.eq(message, "You need the plan for the shed. The stall sells it.", "the rule says where to get it")
	Economy.money = 1000
	t.ne(build.problem_for(shed, Vector2i(10, 8), 0), "", "money does not help")
	shed.unlocked = true
	t.ok(build.catalog.in_category(BuildItemData.Category.BUILDING).has(shed), "unlocked: it is in the list")
	t.eq(build.problem_for(shed, Vector2i(10, 8), 0), "", "and the same spot is fine")
	farm.queue_free()


func test_buying_a_plan_adds_its_slot_to_the_build_palette(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var menu := farm.get_node("Hud/BuildMenu") as BuildMenu
	var slots: HBoxContainer = menu.slot_row
	var before: int = slots.get_child_count()
	var shop := farm.get_node("Shop") as Shop
	t.eq(shop.unlock(_stock().plans[0]), "", "buy the shed plan")
	await t.frames(2)
	t.eq(slots.get_child_count(), before + 1, "the palette has one slot more")
	t.eq(shop.unlock(_stock().plans[1]), "", "buy the well plan")
	await t.frames(2)
	t.eq(slots.get_child_count(), before + 2, "and one more")
	farm.queue_free()


func test_the_farm_has_a_shop_a_stall_a_panel_and_a_feedback_layer(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var shop := farm.get_node("Shop") as Shop
	t.not_null(shop, "the Shop node")
	t.eq(shop.stock.resource_path, STOCK, "its stock is the file stock.tres")
	var panel: ShopPanel = _panel(farm)
	t.not_null(panel, "the ShopPanel is under the Hud")
	t.eq(panel.shop, shop, "it knows the shop")
	t.eq(panel.build, farm.get_node("Build"), "it knows build mode")
	t.ok(not panel.visible and not panel.is_open, "and it starts closed")
	t.not_null(_feedback(farm), "the MoneyFeedback is under the Hud")
	var spot := farm.get_node("World/Stalls/ShopStall/Spot") as ShopSpot
	t.not_null(spot, "the stall has a ShopSpot")
	t.eq(spot.collision_layer, 2, "layer 2")
	t.eq(spot.collision_mask, 0, "looks at nothing")
	t.eq(spot.prompt_text, "Shop", "the prompt")
	t.ok(farm.get_node("World/Stalls/ShopStall/Keeper") is Shopkeeper, "a keeper stands behind it")
	t.eq(farm.get_node("World/Stalls/ShopStall").find_children("*", "CollisionObject3D", true, false).size(), 1, "the only collider of the stall is the spot: it blocks nothing by itself, its Footprint cuts the navigation mesh")
	var found: Array[Interactable] = []
	for node: Node in farm.find_children("*", "Area3D", true, false):
		if node is Interactable:
			found.append(node as Interactable)
	t.eq(found.size(), 52, "the 51 of Chapter 26 and the stall")
	farm.queue_free()


func test_the_stall_is_scenery_for_build_mode_and_a_hole_in_the_navigation_mesh(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var build := farm.get_node("Build") as BuildMode
	var stall := farm.get_node("World/Stalls/ShopStall") as Node3D
	t.vec_approx(stall.global_position, Vector3(3.0, 0.0, -1.0), 0.001, "the stall stands east of the south path")
	var inside: Vector3 = stall.global_position + stall.global_basis * Vector3(0.0, 0.0, 0.5)
	t.eq(build.map.kind_at(BuildGrid.cell_of(inside)), &"scenery", "build mode knows the stall is there")
	t.eq(build.problem_for(build.catalog.find(&"fence"), BuildGrid.cell_of(inside), 0), "Something is in the way.", "so a fence cannot go through it")
	var region := farm.get_node("World") as NavigationRegion3D
	var map: RID = region.get_navigation_map()
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, stall.global_position)
	t.ok(Vector2(closest.x - 3.0, closest.z + 1.0).length() > 0.8, "the mesh has a hole under the stall: the nearest walkable point is %.1f m away" % Vector2(closest.x - 3.0, closest.z + 1.0).length())
	print("LM32 nav polygons with the stall: %d" % region.navigation_mesh.get_polygon_count())
	var from := Vector3(0.5, 0.0, -1.0)
	var to := Vector3(5.5, 0.0, -1.0)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	var length: float = 0.0
	for index: int in range(1, path.size()):
		length += Vector2(path[index].x - path[index - 1].x, path[index].z - path[index - 1].z).length()
	t.ok(length > 5.0 + 0.5, "a walk straight through the stall is %.1f m instead of 5, so the path goes around it" % length)
	farm.queue_free()


func test_opening_the_shop_stops_the_clock_and_closing_gives_it_back(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: ShopPanel = _panel(farm)
	t.ok(panel.open(), "open() says yes")
	t.ok(panel.visible and panel.is_open, "visible")
	t.ok(GameClock.paused, "the clock is stopped")
	t.ok(panel.is_in_group(&"modal"), "the panel is in the group modal")
	t.eq(_log, ["opened"] as Array[String], "the bus knows")
	t.ok(panel.open(), "opening twice is harmless")
	t.eq(_count("opened"), 1, "and says nothing the second time")
	panel.close()
	t.ok(not panel.visible and not panel.is_open, "closed")
	t.ok(not GameClock.paused, "the clock runs again")
	t.ok(not panel.is_in_group(&"modal"), "no longer modal")
	t.eq(_count("closed"), 1, "the bus knows")
	panel.close()
	t.eq(_count("closed"), 1, "closing twice says nothing")
	farm.queue_free()


func test_a_clock_that_was_stopped_stays_stopped(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: ShopPanel = _panel(farm)
	GameClock.paused = true
	panel.open()
	panel.close()
	t.ok(GameClock.paused, "it was paused before the shop, so it is paused after it")
	GameClock.paused = false
	farm.queue_free()


func test_escape_closes_the_shop_and_the_number_keys_switch_tabs(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: ShopPanel = _panel(farm)
	panel.open()
	t.eq(panel.tabs.current_tab, 0, "the Buy tab")
	_key(KEY_2)
	await t.frames(2)
	t.eq(panel.tabs.current_tab, 1, "2 shows Sell")
	_key(KEY_3)
	await t.frames(2)
	t.eq(panel.tabs.current_tab, 2, "3 shows Plans")
	_key(KEY_1)
	await t.frames(2)
	t.eq(panel.tabs.current_tab, 0, "1 shows Buy")
	_key(KEY_ESCAPE)
	await t.frames(2)
	t.ok(not panel.is_open, "Escape closes it")
	t.ok(not GameClock.paused, "and the clock runs")
	farm.queue_free()


func test_while_the_shop_is_open_the_keys_do_not_reach_the_farm(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: ShopPanel = _panel(farm)
	var farmer := farm.get_node("Farmer") as Farmer
	var build := farm.get_node("Build") as BuildMode
	farmer.tools.select(&"hoe")
	panel.open()
	_key(KEY_B)
	await t.frames(2)
	t.ok(not build.active, "B does not start build mode")
	_key(KEY_I)
	await t.frames(2)
	t.ok(not (farm.get_node("Hud") as Hud).bag_panel.visible, "I does not open the bag")
	_key(KEY_3)
	await t.frames(2)
	t.eq(farmer.tools.current, &"hoe", "3 changed the tab, not the tool")
	panel.close()
	_key(KEY_3)
	await t.frames(2)
	t.eq(farmer.tools.current, &"can", "after closing, 3 is the can again")
	farm.queue_free()


func test_the_shop_and_build_mode_keep_out_of_each_other(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: ShopPanel = _panel(farm)
	var build := farm.get_node("Build") as BuildMode
	build.set_active(true)
	t.ok(not panel.open(), "the shop will not open in build mode")
	t.ok(not panel.is_open, "still closed")
	t.ok(_log.has("hint:Close build mode first."), "and it says why")
	build.set_active(false)
	t.ok(panel.open(), "open now")
	build.set_active(true)
	t.ok(not build.active, "build mode will not start while the shop is open")
	panel.close()
	build.set_active(true)
	t.ok(build.active, "after closing it will")
	build.set_active(false)
	farm.queue_free()


func test_the_rows_follow_the_stock_and_the_bag(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: ShopPanel = _panel(farm)
	Inventory.clear()
	panel.open()
	t.eq(panel.buy_grid.get_child_count(), 6 * 5, "six rows of five cells in the Buy tab")
	t.eq(panel.sell_grid.get_child_count(), 1, "Sell shows one note when the bag has nothing to sell")
	t.eq(panel.plan_grid.get_child_count(), 2 * 4, "two rows of four cells in the Plans tab")
	Inventory.add(_item("carrot"), 4)
	Inventory.add(_item("egg"), 2)
	await t.frames(2)
	t.eq(panel.sell_grid.get_child_count(), 2 * 5, "now two rows: carrots and eggs")
	t.eq(_buttons(panel.sell_grid).size(), 4, "each row has Sell 1 and Sell all")
	t.eq(panel.purse_label.text, "100 coins", "the purse label")
	Economy.add_money(5, "gift")
	await t.frames(2)
	t.eq(panel.purse_label.text, "105 coins", "it follows the purse")
	panel.close()
	farm.queue_free()


func test_a_row_you_cannot_afford_is_grey_and_its_button_is_off(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: ShopPanel = _panel(farm)
	Economy.money = 4
	panel.open()
	var buttons: Array[Button] = _buttons(panel.buy_grid)
	t.eq(buttons.size(), 12, "two buttons for each of six rows")
	t.ok(not buttons[0].disabled, "Carrot seeds cost 4: Buy 1 is on")
	t.ok(buttons[1].disabled, "Buy 5 needs 20: it is off")
	t.eq(buttons[1].tooltip_text, "Not enough coins: you need 20.", "and the tooltip says why")
	var pumpkin_row: int = 2
	t.ok(buttons[pumpkin_row * 2].disabled, "pumpkin seeds cost 14: off")
	var slot: Control = panel.buy_grid.get_child(pumpkin_row * 5) as Control
	t.approx(slot.modulate.a, 0.45, 0.001, "its icon is grey")
	t.approx((panel.buy_grid.get_child(pumpkin_row * 5 + 1) as Control).modulate.a, 0.45, 0.001, "and its text")
	t.approx((panel.buy_grid.get_child(0) as Control).modulate.a, 1.0, 0.001, "an affordable row is not")
	panel.close()
	farm.queue_free()


func test_clicking_the_buttons_buys_and_sells(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: ShopPanel = _panel(farm)
	var seeds: ItemData = _item("seed_carrot")
	var have: int = Inventory.count_of(seeds)
	panel.open()
	await t.frames(2)
	var buy_one: Button = _buttons(panel.buy_grid)[0]
	await t.click(buy_one.get_global_rect().get_center())
	await t.frames(2)
	t.eq(Inventory.count_of(seeds), have + 1, "one click, one seed")
	t.eq(Economy.money, 100 - seeds.buy_price, "and four coins")
	t.eq(panel.message_label.text, "Bought 1 Carrot seeds for 4 coins.", "the line at the bottom of the window")
	Inventory.add(_item("carrot"), 3)
	await t.frames(2)
	panel.tabs.current_tab = 1
	await t.frames(2)
	var sell_all: Button = _buttons(panel.sell_grid)[1]
	t.ok(sell_all.text.begins_with("Sell all: "), "the button says what it will bring")
	var quote: int = (farm.get_node("Shop") as Shop).market.quote(_item("carrot"), 3)
	t.eq(sell_all.text, "Sell all: %d" % quote, "exactly the quote")
	var money: int = Economy.money
	await t.click(sell_all.get_global_rect().get_center())
	await t.frames(2)
	t.eq(Inventory.count_of(_item("carrot")), 0, "all carrots are gone")
	t.eq(Economy.money, money + quote, "and the quote is in the purse")
	t.eq(panel.message_label.text, "Sold 3 Carrot for %d coins." % quote, "the message")
	panel.close()
	farm.queue_free()


func test_a_full_bag_shows_a_clear_message_and_costs_nothing(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var panel: ShopPanel = _panel(farm)
	_fill_bag_except(0, _item("egg"))
	panel.open()
	await t.frames(2)
	var buy_one: Button = _buttons(panel.buy_grid)[0]
	t.ok(buy_one.disabled, "Buy 1 is off")
	t.eq(buy_one.tooltip_text, "There is no room in your bag for 1.", "the tooltip")
	t.eq((farm.get_node("Shop") as Shop).buy(_item("seed_carrot"), 1), "There is no room in your bag for 1.", "the shop refuses")
	t.eq(panel.message_label.text, "There is no room in your bag for 1.", "the window shows it")
	t.eq(Economy.money, 100, "no coins moved")
	panel.close()
	farm.queue_free()


func test_a_click_on_the_stall_walks_up_and_opens_the_window(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var farmer := farm.get_node("Farmer") as Farmer
	var panel: ShopPanel = _panel(farm)
	var spot := farm.get_node("World/Stalls/ShopStall/Spot") as ShopSpot
	var middle: Vector3 = (spot.get_node("CollisionShape3D") as CollisionShape3D).global_position
	_look_at(farm, middle)
	farmer.global_position = Vector3(0.5, 0.0, -3.5)
	await t.physics_frames(2)
	await t.click(_screen(farm, middle))
	var steps: int = 0
	while not panel.is_open and steps < 8000:
		await t.physics_frames(1)
		steps += 1
	t.ok(panel.is_open, "the window opened after %d steps" % steps)
	t.ok(GameClock.paused, "the clock is stopped")
	t.ok(farmer.global_position.distance_to(spot.global_position) <= spot.interact_range + 0.5, "the farmer stands at the stall")
	panel.close()
	farm.queue_free()


func test_the_hud_money_label_follows_every_trade(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var hud := farm.get_node("Hud") as Hud
	var shop := farm.get_node("Shop") as Shop
	t.eq(hud.money_label.text, "100 coins", "the start")
	shop.buy(_item("seed_carrot"), 5)
	t.eq(hud.money_label.text, "80 coins", "after five seeds")
	Inventory.add(_item("pumpkin"), 1)
	shop.sell(_item("pumpkin"), 1)
	t.ok(hud.money_label.text != "80 coins", "after a pumpkin: %s" % hud.money_label.text)
	farm.queue_free()


func test_a_trade_makes_a_number_float_up_and_go_away(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var feedback: MoneyFeedback = _feedback(farm)
	var before: int = feedback.get_child_count()
	Economy.add_money(12, "Sold")
	Economy.spend(5, "Bought")
	t.eq(feedback.get_child_count(), before + 2, "two pops")
	var plus := feedback.get_child(before) as Label
	var minus := feedback.get_child(before + 1) as Label
	t.eq(plus.text, "+12", "a plus for coins in")
	t.eq(minus.text, "-5", "a minus for coins out")
	t.eq(plus.get_theme_color("font_color"), MoneyFeedback.GAIN, "green")
	t.eq(minus.get_theme_color("font_color"), MoneyFeedback.LOSS, "red")
	t.eq(plus.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a pop never takes a click")
	var y: float = plus.position.y
	await t.secs(0.4)
	t.ok(plus.position.y > y, "it moves down toward the middle of the screen from the label")
	await t.secs(1.6)
	t.eq(feedback.get_child_count(), before, "both are gone after %.1f seconds" % MoneyFeedback.LIFE)
	farm.queue_free()


func test_the_day_window_shows_the_totals_and_continue_closes_it(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var feedback: MoneyFeedback = _feedback(farm)
	t.ok(not feedback.summary.visible, "hidden at the start")
	Economy.add_money(40, "Sold 3 Carrot")
	Economy.spend(15, "Bought 5 Hay")
	Events.day_started.emit(2)
	t.ok(feedback.summary.visible, "it opens at a new day")
	t.eq(feedback.title.text, "Day 1 is over", "the title names the day that ended")
	t.eq(feedback.earned.text, "+40", "earned")
	t.eq(feedback.spent.text, "-15", "spent")
	t.eq(feedback.net.text, "+25", "net")
	t.eq(feedback.lines.text, "Sold 3 Carrot  +40\nBought 5 Hay  -15", "the lines of the book")
	var button := feedback.get_node("%ContinueButton") as Button
	await t.frames(2)
	await t.click(button.get_global_rect().get_center())
	await t.frames(2)
	t.ok(not feedback.summary.visible, "Continue closes it")
	farm.queue_free()


func test_a_long_day_shows_five_lines_and_a_count_of_the_rest(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var feedback: MoneyFeedback = _feedback(farm)
	for number: int in 8:
		Economy.add_money(2, "Sold %d" % number)
	Events.day_started.emit(2)
	var lines: PackedStringArray = feedback.lines.text.split("\n")
	t.eq(lines.size(), 6, "five lines and one more")
	t.eq(lines[5], "and 3 more", "the rest, counted")
	t.eq(feedback.net.text, "+16", "the totals still count all eight")
	farm.queue_free()


func test_a_day_without_trades_has_no_window(t: Variant) -> void:
	var farm: Node = await _farm(t)
	var feedback: MoneyFeedback = _feedback(farm)
	Events.day_started.emit(2)
	t.ok(not feedback.summary.visible, "nothing earned or spent: no window")
	farm.queue_free()
