@tool
extends EditorScript
## Chapter 29: open this script and press Ctrl+Shift+X (Cmd+Shift+X on a Mac).
## It writes res://resources/ui/hud_theme.tres: one look for every panel, label and button of the HUD.

const FILE: String = "res://resources/ui/hud_theme.tres"
const TEXT: Color = Color("F4F1E8")
const DARK: Color = Color("1B1B1B")
const LINE: Color = Color("3E4F45")
const GOLD: Color = Color("F2C94C")


func _run() -> void:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_stylebox("panel", "PanelContainer", _box(Color("1B2420", 0.88), LINE, 8, 10, 8))
	theme.set_type_variation("SlotPanel", "PanelContainer")
	theme.set_stylebox("panel", "SlotPanel", _box(Color("121815"), LINE, 6, 4, 4))
	theme.set_stylebox("normal", "Button", _box(Color("2A362F"), Color("51655A"), 6, 12, 6))
	theme.set_stylebox("hover", "Button", _box(Color("364539"), Color("7C9784"), 6, 12, 6))
	theme.set_stylebox("pressed", "Button", _box(GOLD, Color("FFE08A"), 6, 12, 6))
	theme.set_stylebox("hover_pressed", "Button", _box(Color("F6D567"), Color("FFE08A"), 6, 12, 6))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("disabled", "Button", _box(Color("1B2420"), LINE, 6, 12, 6))
	theme.set_stylebox("tab_selected", "TabContainer", _box(Color("2A362F"), GOLD, 6, 14, 6))
	theme.set_stylebox("tab_unselected", "TabContainer", _box(Color("1B2420"), LINE, 6, 14, 6))
	theme.set_stylebox("tab_hovered", "TabContainer", _box(Color("364539"), Color("7C9784"), 6, 14, 6))
	theme.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", DARK)
	theme.set_color("font_hover_pressed_color", "Button", DARK)
	theme.set_color("font_disabled_color", "Button", Color("7C8A82"))
	theme.set_color("font_selected_color", "TabContainer", GOLD)
	theme.set_color("font_unselected_color", "TabContainer", TEXT)
	theme.set_color("font_hovered_color", "TabContainer", Color.WHITE)
	var error: int = ResourceSaver.save(theme, FILE)
	print("Theme saved to ", FILE, " (error code ", error, ")")


func _box(fill: Color, line: Color, radius: int, margin_x: int, margin_y: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = line
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box
