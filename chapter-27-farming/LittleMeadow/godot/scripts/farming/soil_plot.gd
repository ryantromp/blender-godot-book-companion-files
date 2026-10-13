class_name SoilPlot
extends Interactable
## One square of the field. It remembers what is in it and which tool the farmer needs next.
## EMPTY -> TILLED -> PLANTED -> WATERED -> (sleep) -> PLANTED or RIPE -> harvest -> TILLED.

signal changed

enum State { EMPTY, TILLED, PLANTED, WATERED, RIPE }

# One entry per State, in the order of the enum.
const TOOL_FOR: Array[StringName] = [&"hoe", &"seeds", &"can", &"", &"hand"]
const CLIP_FOR: Array[String] = ["plant", "plant", "water", "", "harvest"]
const PROMPT_FOR: Array[String] = [
	"Till the soil", "Plant a seed", "Water the {crop}", "The {crop} is watered", "Harvest the {crop}",
]
const HINT_FOR: Array[String] = [
	"Dry ground. Take the hoe (1).", "Tilled. Take the seeds (2).", "Thirsty. Take the can (3).",
	"Watered. It grows while you sleep.", "Ripe. Use your hands (4).",
]

var state: State = State.EMPTY
var crop: CropData
var stage: int = 0
var days_watered: int = 0

var _busy: bool = false


func _ready() -> void:
	super()
	Events.day_started.connect(_on_day_started)
	_set_state(State.EMPTY)


## Called once per click by the InteractionController. A refusal says why, through the bus.
func can_interact(farmer: Farmer) -> bool:
	var problem: String = _problem(farmer)
	if problem != "":
		Events.hint_shown.emit(problem)
	else:
		action_name = CLIP_FOR[state]
	return problem == "" and not _busy


func interact(farmer: Farmer) -> void:
	_busy = true
	await farmer.animation.wait_for_action()
	match state:
		State.EMPTY:
			_set_state(State.TILLED)
		State.TILLED:
			crop = farmer.tools.crop
			stage = 0
			days_watered = 0
			_set_state(State.PLANTED)
		State.PLANTED:
			if farmer.can.use():
				_set_state(State.WATERED)
		State.RIPE:
			var harvested: CropData = crop
			crop = null
			_set_state(State.TILLED)
			Events.crop_harvested.emit(harvested, self)
	_busy = false
	interacted.emit(farmer)


func _problem(farmer: Farmer) -> String:
	var held: StringName = farmer.tools.current
	if held != TOOL_FOR[state]:
		return HINT_FOR[state]
	if held == &"can" and farmer.can.is_empty():
		return "The can is empty. Fill it at the pump."
	if held == &"seeds" and farmer.tools.crop == null:
		return "There are no seeds in the bag."
	return ""


func _on_day_started(_day: int) -> void:
	if state != State.WATERED:
		return
	days_watered += 1
	if days_watered >= crop.days_per_stage:
		days_watered = 0
		stage += 1
	_set_state(State.RIPE if stage >= crop.last_stage() else State.PLANTED)


func _set_state(new_state: State) -> void:
	state = new_state
	var crop_name: String = crop.display_name.to_lower() if crop != null else ""
	prompt_text = PROMPT_FOR[state].format({"crop": crop_name})
	changed.emit()
