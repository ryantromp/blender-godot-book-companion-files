extends Node
## Day counter and time of day. _process() turns real seconds into game minutes.

const MINUTES_PER_DAY: int = 24 * 60
## Two game minutes per real second: a day lasts 12 real minutes.
const MINUTES_PER_REAL_SECOND: float = 2.0

var day: int = 1
var minute_of_day: int = 6 * 60
## False stops the driver. The tests switch it off and call advance_minutes() themselves.
var running: bool = true
## True while a panel wants the world to wait.
var paused: bool = false
## 1.0 is normal. 2.0 makes time pass twice as fast.
var speed: float = 1.0

var _carry: float = 0.0


func _process(delta: float) -> void:
	if not running or paused:
		return
	_carry += delta * MINUTES_PER_REAL_SECOND * speed
	var whole: int = floori(_carry)
	if whole > 0:
		_carry -= whole
		advance_minutes(whole)


func get_hour() -> int:
	return floori(minute_of_day / 60.0)


## The minute plus the part of a minute still waiting, for smooth light.
func minute_float() -> float:
	return minute_of_day + _carry


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


## Sets the day and the minute at once. No signals. Saving and the tests use it.
func set_time(new_day: int, new_minute: int) -> void:
	day = new_day
	minute_of_day = new_minute
	_carry = 0.0


func time_text() -> String:
	return "%02d:%02d" % [get_hour(), minute_of_day % 60]
