extends Node

func _ready() -> void:
	Events.day_started.connect(_on_day_started)
	print("start: day ", GameClock.day, ", ", GameClock.time_text())
	GameClock.advance_minutes(20 * 60)
	print("later: day ", GameClock.day, ", ", GameClock.time_text())
	get_tree().quit()

func _on_day_started(day: int) -> void:
	print("Events: day ", day)
