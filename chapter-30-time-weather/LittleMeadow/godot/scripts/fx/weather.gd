class_name Weather
extends Node3D
## The weather of the day: clear, cloudy or rain, rolled from a seed. Rain falls around the farmer.

enum State { CLEAR, CLOUDY, RAIN }

const NAMES: Array[String] = ["Clear", "Cloudy", "Rain"]

## Picks the weather of every day. Chapter 33 saves it.
@export var world_seed: int = 3041
## Chance of each state, in the order of the enum.
@export var weights: Array[float] = [0.5, 0.3, 0.2]
## Day 1 is always clear, so a new game starts friendly.
@export var first_day_clear: bool = true
## Rolled for the real game. The others force one weather on every day, to look at rain at once.
@export_enum("Rolled", "Clear", "Cloudy", "Rain") var forced: int = 0
@export var farmer: Farmer
## How high above the farmer the rain starts, in metres.
@export var rain_height: float = 12.0

var state: State = State.CLEAR
## 0 at night to 1 at noon. DayNight sets it, and the rain streaks follow it.
var daylight: float = 1.0

@onready var rain: GPUParticles3D = $Rain


func _ready() -> void:
	# Deferred, so the plots and the HUD hear the new day after they have joined the bus.
	Events.day_started.connect(_on_day_started, CONNECT_DEFERRED)
	set_state.call_deferred(state_for_day(GameClock.day))


func _process(_delta: float) -> void:
	if farmer != null:
		rain.global_position = farmer.global_position + Vector3.UP * rain_height
	# Streaks fade with the light and stay a soft grey at night.
	var streak := rain.draw_pass_1.material as StandardMaterial3D
	streak.albedo_color.a = lerpf(0.12, 0.45, daylight)


## The weather of one day. It depends only on the seed and the day number.
func state_for_day(day: int) -> State:
	if forced > 0:
		return (forced - 1) as State
	if first_day_clear and day <= 1:
		return State.CLEAR
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(world_seed * 7919 + day)
	return rng.rand_weighted(PackedFloat32Array(weights)) as State


func set_state(new_state: State) -> void:
	state = new_state
	rain.emitting = state == State.RAIN
	Events.weather_changed.emit(state)


func state_name() -> String:
	return NAMES[state]


func _on_day_started(day: int) -> void:
	set_state(state_for_day(day))
