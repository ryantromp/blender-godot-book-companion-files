extends Node

var steps: int = 0
var frames: int = 0

func _process(_delta: float) -> void:
	frames += 1

func _physics_process(delta: float) -> void:
	steps += 1
	if steps == 120:
		print(steps, " steps of ", delta, " s, drawn frames: ", frames)
		get_tree().quit()
