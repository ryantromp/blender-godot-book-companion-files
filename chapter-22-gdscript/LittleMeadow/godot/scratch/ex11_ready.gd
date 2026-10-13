extends Node

@export var greeting: String = "hello meadow"
@onready var hen: Node = $Hen

func _init() -> void:
	print("1 _init: hen is ", hen)

func _ready() -> void:
	print("3 _ready: ", greeting, ", hen is ", hen.name)


func _on_hen_ready() -> void:
	print("2 Hen is ready")
