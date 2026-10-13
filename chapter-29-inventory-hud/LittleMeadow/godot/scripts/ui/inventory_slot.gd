class_name InventorySlot
extends PanelContainer
## One square of the bag grid. show_stack() fills it from an ItemStack, or clears it.
## Until real icons arrive (Chapter 34) a coloured rectangle with two letters stands in for the icon.

@onready var swatch: ColorRect = $Swatch
@onready var picture: TextureRect = $Picture
@onready var badge: Label = $Badge
@onready var count_label: Label = $Count


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	show_stack(null)


func show_stack(stack: ItemStack) -> void:
	var filled: bool = stack != null and not stack.is_empty()
	var drawn: bool = filled and stack.item.icon == null
	swatch.visible = drawn
	badge.visible = drawn
	picture.visible = filled and not drawn
	count_label.visible = filled and stack.count > 1
	tooltip_text = ""
	if not filled:
		return
	var item: ItemData = stack.item
	swatch.color = item.color
	badge.text = item.short_name
	badge.add_theme_color_override("font_color", Color("1B1B1B") if item.color.get_luminance() > 0.5 else Color.WHITE)
	picture.texture = item.icon
	count_label.text = str(stack.count)
	tooltip_text = "%s\n%d of %d" % [item.display_name, stack.count, item.stack_size]


func _on_mouse_entered() -> void:
	self_modulate = Color(1.4, 1.4, 1.4)


func _on_mouse_exited() -> void:
	self_modulate = Color.WHITE
