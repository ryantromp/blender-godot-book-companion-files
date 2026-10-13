class_name FeedBag
extends Node
## The farmer's bag of animal feed. One scoop feeds one animal. The farm leaves a full bag every
## morning, so there is nothing to buy yet. Chapter 29 replaces the counter with real items.

@export var capacity: int = 8

var scoops: int = 0


func _ready() -> void:
	Events.day_started.connect(_on_day_started)
	refill()


func is_empty() -> bool:
	return scoops <= 0


func refill() -> void:
	scoops = capacity
	Events.feed_level_changed.emit(scoops, capacity)


## Uses one scoop. Returns false, and changes nothing, when the bag is empty.
func use() -> bool:
	if is_empty():
		return false
	scoops -= 1
	Events.feed_level_changed.emit(scoops, capacity)
	return true


func _on_day_started(_day: int) -> void:
	refill()
