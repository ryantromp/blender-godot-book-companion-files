class_name SleepSpot
extends Interactable
## The farmhouse door. Using it moves the clock to the next morning, which starts a new day.
## Chapter 30 lets time pass by itself, and this becomes the way to skip the night.

@export var wake_hour: int = 6


func interact(farmer: Farmer) -> void:
	var minutes: int = posmod(wake_hour * 60 - GameClock.minute_of_day, GameClock.MINUTES_PER_DAY)
	if minutes == 0:
		minutes = GameClock.MINUTES_PER_DAY
	GameClock.advance_minutes(minutes)
	Events.hint_shown.emit("Good morning. It is day %d." % GameClock.day)
	super(farmer)
