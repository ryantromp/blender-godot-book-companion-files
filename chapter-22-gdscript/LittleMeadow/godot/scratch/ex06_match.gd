@tool
extends EditorScript

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

func _run() -> void:
	for season: Season in Season.values():
		match season:
			Season.SPRING, Season.SUMMER:
				print(Season.keys()[season], ": plant")
			Season.AUTUMN:
				print(Season.keys()[season], ": harvest")
			_:
				print(Season.keys()[season], ": rest")
