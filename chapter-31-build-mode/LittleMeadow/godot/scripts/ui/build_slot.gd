class_name BuildSlot
extends PanelContainer
## One square of the build palette.

signal picked(item: BuildItemData)

var item: BuildItemData
var affordable: bool = true

@onready var swatch: ColorRect = $Swatch
@onready var badge: Label = $Badge
@onready var key_label: Label = $Key
@onready var cost_label: Label = $Cost
@onready var mark: ColorRect = $Mark


func _ready() -> void:
	set_selected(false)


func show_item(new_item: BuildItemData, number: int) -> void:
	item = new_item
	swatch.color = item.color
	badge.text = item.short_name
	badge.add_theme_color_override("font_color", Color("1B1B1B") if item.color.get_luminance() > 0.5 else Color.WHITE)
	key_label.text = str(number) if number <= 6 else ""
	cost_label.text = str(item.cost)
	tooltip_text = "%s\n%d coins, %d x %d cells" % [item.display_name, item.cost, item.footprint.x, item.footprint.y]


func set_selected(on: bool) -> void:
	mark.visible = on
	self_modulate = Color(1.5, 1.45, 1.1) if on else Color.WHITE


func set_affordable(yes: bool) -> void:
	affordable = yes
	modulate = Color.WHITE if yes else Color(0.45, 0.45, 0.45, 0.85)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		picked.emit(item)
		accept_event()
