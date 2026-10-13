class_name AnimalSpot
extends Interactable
## The part of an animal the mouse can find. It asks the Animal whether feeding is allowed and,
## after the farmer's clip ends, tells the Animal to eat.

var _busy: bool = false

@onready var animal: Animal = get_parent() as Animal


func can_interact(farmer: Farmer) -> bool:
	var problem: String = animal.problem_for(farmer)
	if problem != "":
		Events.hint_shown.emit(problem)
	return problem == "" and not _busy


func interact(farmer: Farmer) -> void:
	_busy = true
	await farmer.animation.wait_for_action()
	animal.feed_by(farmer)
	_busy = false
	super(farmer)
