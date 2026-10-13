extends SceneTree

func _init() -> void:
	var m := Market.new()
	var carrot: ItemData = load("res://resources/items/carrot.tres")
	var out: Dictionary = {"base": carrot.sell_price, "table": [], "week": [], "recover": []}
	for sold: int in 11:
		m.sold[carrot.id] = sold
		out["table"].append(m.price_of(carrot))
	m.sold.clear()
	for day: int in range(1, 8):
		m.day = day
		out["week"].append(m.price_of(carrot))
	m.day = 1
	m.sold[carrot.id] = 10
	for morning: int in 4:
		out["recover"].append(m.price_of(carrot))
		m.new_day(1 + morning + 1)
	print("DUMP ", JSON.stringify(out))
	quit()
