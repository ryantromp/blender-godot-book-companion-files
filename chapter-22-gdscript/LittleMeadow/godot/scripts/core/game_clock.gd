extends Node
## Day counter and time of day. Time does not pass by itself yet:
## Chapter 30 calls advance_minutes() from _process().

const MINUTES_PER_DAY: int = 24 * 60

var day: int = 1
var minute_of_day: int = 6 * 60


func get_hour() -> int:
	return floori(minute_of_day / 60.0)


func advance_minutes(minutes: int) -> void:
	var old_hour: int = get_hour()
	var total: int = minute_of_day + minutes
	while total >= MINUTES_PER_DAY:
		total -= MINUTES_PER_DAY
		day += 1
		Events.day_started.emit(day)
	minute_of_day = total
	if get_hour() != old_hour:
		Events.hour_changed.emit(get_hour())


func time_text() -> String:
	return "%02d:%02d" % [get_hour(), minute_of_day % 60]
