@tool
extends EditorScript

func _run() -> void:
	var hen := ScratchChicken.new("Henrietta")
	hen.lay_egg()
	print(hen.speak(), ", eggs ", hen.eggs, ", energy ", hen.energy)
	var thing := ScratchAnimal.new("Thing")
	print(thing.speak())
	print("hen is an animal: ", hen is ScratchAnimal)
