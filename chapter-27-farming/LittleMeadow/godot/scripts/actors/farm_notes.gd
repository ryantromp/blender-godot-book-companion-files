class_name FarmNotes
extends CanvasLayer
## Temporary text under the water level: the day, what is in hand, how many plots are ripe,
## a tally of the harvest and the last hint. Chapter 29 replaces it with the real HUD and the Inventory.

var harvested: Dictionary = {}

var _label := Label.new()
var _hint: String = ""

@onready var farmer: Farmer = get_parent() as Farmer


func _ready() -> void:
	_label.position = Vector2(16.0, 46.0)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color("14191A"))
	add_child(_label)
	Events.crop_harvested.connect(_on_crop_harvested)
	Events.hint_shown.connect(func(text: String) -> void: _hint = text)
	Events.tool_changed.connect(func(_tool: StringName, _crop: CropData) -> void: _hint = "")


func _process(_delta: float) -> void:
	var ripe: int = 0
	for plot: SoilPlot in get_tree().get_nodes_in_group(&"soil_plots"):
		if plot.state == SoilPlot.State.RIPE:
			ripe += 1
	var held: String = String(farmer.tools.current)
	if farmer.tools.current == &"seeds" and farmer.tools.crop != null:
		held += " (%s)" % farmer.tools.crop.display_name.to_lower()
	var tally: PackedStringArray = []
	for crop_id: StringName in harvested:
		tally.append("%s %d" % [crop_id, harvested[crop_id]])
	_label.text = "Day %d  %s\nIn hand: %s\nRipe plots: %d\nHarvested: %s\n%s" % [
		GameClock.day, GameClock.time_text(), held, ripe, ", ".join(tally) if not tally.is_empty() else "nothing", _hint,
	]


func _on_crop_harvested(crop: CropData, _plot: SoilPlot) -> void:
	harvested[crop.id] = int(harvested.get(crop.id, 0)) + 1
