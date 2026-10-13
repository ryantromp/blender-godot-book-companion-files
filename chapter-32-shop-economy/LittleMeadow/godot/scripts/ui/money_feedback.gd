class_name MoneyFeedback
extends Control

const RISE: float = 36.0
const LIFE: float = 1.2
const SUMMARY_SECONDS: float = 8.0
const GAIN: Color = Color("9BE29B")
const LOSS: Color = Color("FF9A8A")

var _tween: Tween

@onready var summary: PanelContainer = %Summary
@onready var title: Label = %SummaryTitle
@onready var earned: Label = %EarnedValue
@onready var spent: Label = %SpentValue
@onready var net: Label = %NetValue
@onready var lines: Label = %SummaryLines


func _ready() -> void:
	summary.visible = false
	Events.money_moved.connect(_on_money_moved)
	Events.day_summary.connect(_on_day_summary)


func _on_money_moved(amount: int, _reason: String) -> void:
	var pop := Label.new()
	pop.text = "%+d" % amount
	pop.position = Vector2(size.x - 130.0, 56.0)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.add_theme_font_size_override("font_size", 30)
	pop.add_theme_color_override("font_color", GAIN if amount > 0 else LOSS)
	pop.add_theme_color_override("font_outline_color", Color("1B1B1B"))
	pop.add_theme_constant_override("outline_size", 8)
	add_child(pop)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(pop, "position:y", pop.position.y + RISE, LIFE)
	tween.tween_property(pop, "modulate:a", 0.0, LIFE)
	tween.chain().tween_callback(pop.queue_free)


func _on_day_summary(day: int, earned_total: int, spent_total: int) -> void:
	if earned_total == 0 and spent_total == 0:
		return
	title.text = "Day %d is over" % day
	earned.text = "+%d" % earned_total
	spent.text = "-%d" % spent_total
	net.text = "%+d" % (earned_total - spent_total)
	var entries: Array[Dictionary] = Economy.entries_for(day)
	var text: Array[String] = []
	for entry: Dictionary in entries.slice(0, 5):
		text.append("%s  %+d" % [entry["reason"], entry["amount"]])
	if entries.size() > 5:
		text.append("and %d more" % (entries.size() - 5))
	lines.text = "\n".join(text)
	summary.modulate.a = 1.0
	summary.visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(SUMMARY_SECONDS)
	_tween.tween_property(summary, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(summary.hide)


func _on_continue_pressed() -> void:
	summary.hide()
