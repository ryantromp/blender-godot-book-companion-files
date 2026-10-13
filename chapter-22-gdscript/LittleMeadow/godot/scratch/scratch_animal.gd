class_name ScratchAnimal
extends RefCounted
## Practice class. The real Animal class comes in Chapter 28.

var animal_name: String
var energy: int = 10

func _init(given_name: String) -> void:
	animal_name = given_name

func speak() -> String:
	return "%s makes a sound" % animal_name
