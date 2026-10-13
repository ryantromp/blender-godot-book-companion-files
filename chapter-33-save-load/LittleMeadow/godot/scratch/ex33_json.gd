@tool
extends EditorScript

const PATH: String = "user://quick_win.json"


func _run() -> void:
	var data: Dictionary = {"day": 3, "money": 120, "bag": ["carrot", "egg"]}
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var text: String = FileAccess.get_file_as_string(PATH)
	print(text)
	var back: Dictionary = JSON.parse_string(text)
	print(back)
	print("day came back as a ", type_string(typeof(back["day"])), ", not an int")
	print("the file is ", ProjectSettings.globalize_path(PATH))
