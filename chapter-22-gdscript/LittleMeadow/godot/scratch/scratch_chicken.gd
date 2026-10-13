class_name ScratchChicken
extends ScratchAnimal

var eggs: int = 0

func speak() -> String:
	return "%s says cluck" % animal_name

func lay_egg() -> void:
	eggs += 1
	energy -= 3
