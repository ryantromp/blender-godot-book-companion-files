extends SceneTree


func _initialize() -> void:
	var svg: String = FileAccess.get_file_as_string("res://icon.svg")
	var image: Image = Image.new()
	var error: int = image.load_svg_from_string(svg, 8.0)
	if error != OK:
		printerr("Could not read icon.svg: %s" % error_string(error))
		quit(1)
		return
	var path: String = ProjectSettings.globalize_path("res://packaging/icon_1024.png")
	image.save_png(path)
	print("Saved %s (%d x %d)" % [path, image.get_width(), image.get_height()])
	quit(0)
