class_name Ambience
extends Node

const LAYERS: Array[StringName] = [&"birds", &"crickets", &"rain"]
const FADE_SECONDS: float = 3.0
const DAWN: Vector2 = Vector2(330.0, 420.0)
const DUSK: Vector2 = Vector2(1110.0, 1200.0)

var raining: bool = false
var gains: Dictionary[StringName, float] = {}

var _players: Dictionary[StringName, AudioStreamPlayer] = {}


func _ready() -> void:
	for layer: StringName in LAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = &"Ambience"
		add_child(player)
		_players[layer] = player
		gains[layer] = 0.0
	Events.weather_changed.connect(_on_weather_changed)
	Events.hour_changed.connect(_on_hour_changed.unbind(1))
	Events.game_loaded.connect(snap.unbind(1))
	_choose_music(0.0)


func day_weight(minute: float) -> float:
	return smoothstep(DAWN.x, DAWN.y, minute) - smoothstep(DUSK.x, DUSK.y, minute)


func targets(minute: float) -> Dictionary[StringName, float]:
	var day: float = day_weight(minute)
	var wet: float = 1.0 if raining else 0.0
	return {
		&"birds": day * (1.0 - 0.75 * wet),
		&"crickets": (1.0 - day) * (1.0 - 0.6 * wet),
		&"rain": wet,
	}


func snap() -> void:
	gains = targets(GameClock.minute_float())
	_apply()
	_choose_music(2.0)


func reset() -> void:
	raining = false
	snap()


func _process(delta: float) -> void:
	var wanted: Dictionary[StringName, float] = targets(GameClock.minute_float())
	for layer: StringName in LAYERS:
		gains[layer] = move_toward(gains[layer], wanted[layer], delta / FADE_SECONDS)
	_apply()


func _apply() -> void:
	for layer: StringName in LAYERS:
		var player: AudioStreamPlayer = _players[layer]
		var data: SoundData = AudioBus.BANK.find(layer)
		if gains[layer] < 0.01:
			player.stop()
		elif data != null:
			if not player.playing:
				player.stream = data.stream
				player.play()
			player.volume_db = data.volume_db + linear_to_db(gains[layer])


func _choose_music(fade: float) -> void:
	var sound: StringName = &"music_day" if day_weight(GameClock.minute_float()) >= 0.5 else &"music_night"
	AudioBus.play_music(sound, fade)


func _on_weather_changed(state: Weather.State) -> void:
	raining = state == Weather.State.RAIN


func _on_hour_changed() -> void:
	_choose_music(4.0)
