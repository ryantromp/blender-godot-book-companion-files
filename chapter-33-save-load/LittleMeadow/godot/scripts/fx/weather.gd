class_name Weather
extends Node3D

enum State { CLEAR, CLOUDY, RAIN }

const NAMES: Array[String] = ["Clear", "Cloudy", "Rain"]

@export var world_seed: int = 3041
@export var weights: Array[float] = [0.5, 0.3, 0.2]
@export var first_day_clear: bool = true
@export_enum("Rolled", "Clear", "Cloudy", "Rain") var forced: int = 0
@export var farmer: Farmer
@export var rain_height: float = 12.0

var state: State = State.CLEAR
var daylight: float = 1.0

@onready var rain: GPUParticles3D = $Rain


func _ready() -> void:
	Events.day_started.connect(_on_day_started, CONNECT_DEFERRED)
	set_state.call_deferred(state_for_day(GameClock.day))


func _process(_delta: float) -> void:
	if farmer != null:
		rain.global_position = farmer.global_position + Vector3.UP * rain_height
	var streak := rain.draw_pass_1.material as StandardMaterial3D
	streak.albedo_color.a = lerpf(0.12, 0.45, daylight)


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


func save_key() -> String:
	return "weather"


func to_save() -> Dictionary:
	return {"seed": world_seed, "state": state}


func from_save(data: Dictionary) -> void:
	world_seed = int(data["seed"])
	set_state(clampi(int(data["state"]), 0, State.size() - 1) as State)


func state_name() -> String:
	return NAMES[state]


func _on_day_started(day: int) -> void:
	set_state(state_for_day(day))
