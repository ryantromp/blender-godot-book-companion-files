extends Node
## Chapter 22: the practice classes, the tomato resource and the two autoloads behave as the chapter says.

const TWO_DAYS: int = 2 * 24 * 60

var signals_seen: Array[String] = []


func _on_day(day: int) -> void:
	signals_seen.append("day %d" % day)


func _on_hour(hour: int) -> void:
	signals_seen.append("hour %d" % hour)


func test_chicken_inherits_and_overrides(t: Variant) -> void:
	var hen := ScratchChicken.new("Henrietta")
	hen.lay_egg()
	t.eq(hen.eggs, 1, "one egg")
	t.eq(hen.energy, 7, "laying costs 3 energy")
	t.eq(hen.speak(), "Henrietta says cluck", "override wins")
	t.eq(ScratchAnimal.new("Thing").speak(), "Thing makes a sound", "parent speaks plainly")
	t.ok(hen is ScratchAnimal, "a chicken is an animal")


func test_tomato_resource(t: Variant) -> void:
	var tomato: ScratchCropData = load("res://scratch/tomato.tres")
	t.not_null(tomato, "tomato.tres loads")
	t.eq(tomato.crop_name, "tomato", "name")
	t.eq(tomato.days_to_grow, 4, "days")
	t.eq(tomato.sell_price, 9, "price")
	t.eq(tomato.describe(), "tomato: 4 days, 9 coins", "describe")


func test_autoloads_exist(t: Variant) -> void:
	t.not_null(t.autoload("Events"), "Events is registered")
	t.not_null(t.autoload("GameClock"), "GameClock is registered")


func test_game_clock(t: Variant) -> void:
	var clock: Node = t.autoload("GameClock")
	var events: Node = t.autoload("Events")
	var old_day: int = clock.day
	var old_minute: int = clock.minute_of_day
	clock.day = 1
	clock.minute_of_day = 6 * 60
	signals_seen.clear()
	events.day_started.connect(_on_day)
	events.hour_changed.connect(_on_hour)
	t.eq(clock.time_text(), "06:00", "starts at six")
	clock.advance_minutes(30)
	t.eq(clock.time_text(), "06:30", "half an hour later")
	t.eq(signals_seen.size(), 0, "no signal inside the same hour")
	clock.advance_minutes(30)
	t.eq(signals_seen, ["hour 7"], "hour_changed fires at 07:00")
	signals_seen.clear()
	clock.advance_minutes(20 * 60)
	t.eq(clock.day, 2, "rolled over into day 2")
	t.eq(clock.time_text(), "03:00", "03:00 on day 2")
	t.eq(signals_seen, ["day 2", "hour 3"], "day_started, then hour_changed")
	clock.advance_minutes(TWO_DAYS)
	t.eq(clock.day, 4, "two days in one call emit twice")
	events.day_started.disconnect(_on_day)
	events.hour_changed.disconnect(_on_hour)
	clock.day = old_day
	clock.minute_of_day = old_minute

