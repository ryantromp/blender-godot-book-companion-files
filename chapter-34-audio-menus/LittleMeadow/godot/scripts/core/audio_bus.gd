extends Node

signal requested(sound: StringName, position: Variant)

const BANK: SoundBank = preload("res://resources/audio/sound_bank.tres")
const POOL_FLAT: int = 10
const POOL_SPATIAL: int = 8
const SILENT_DB: float = -80.0

var min_gap_msec: int = 40
var missing: Dictionary[StringName, int] = {}
var music_name: StringName = &""
var ambience: Ambience

var _flat: Array[Node] = []
var _spatial: Array[Node] = []
var _music: Array[AudioStreamPlayer] = []
var _front: int = 0
var _stamp: Dictionary[Node, int] = {}
var _last: Dictionary[StringName, int] = {}
var _fades: Dictionary[Node, Tween] = {}
var _tick: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index: int in POOL_FLAT:
		_flat.append(_add(AudioStreamPlayer.new()))
	for index: int in POOL_SPATIAL:
		var player := AudioStreamPlayer3D.new()
		player.unit_size = 24.0
		player.max_distance = 90.0
		player.panning_strength = 0.6
		_spatial.append(_add(player))
	for index: int in 2:
		_music.append(_add(AudioStreamPlayer.new()) as AudioStreamPlayer)
	ambience = _add(Ambience.new()) as Ambience
	_add(AudioHooks.new())
	get_tree().node_added.connect(_on_node_added)


func play(sound: StringName, position: Variant = null) -> bool:
	requested.emit(sound, position)
	var data: SoundData = BANK.find(sound)
	if data == null or data.stream == null:
		missing[sound] = missing.get(sound, 0) + 1
		if missing[sound] == 1:
			push_warning("AudioBus: there is no sound called '%s'." % sound)
		return false
	var now: int = Time.get_ticks_msec()
	if now - _last.get(sound, -min_gap_msec) < min_gap_msec:
		return false
	_last[sound] = now
	var voice: Variant = _take(_spatial if position is Vector3 else _flat)
	if position is Vector3:
		voice.global_position = position
	voice.stream = data.stream
	voice.bus = data.bus
	voice.pitch_scale = 1.0 + randf_range(-data.pitch_range, data.pitch_range)
	voice.volume_db = data.volume_db + randf_range(-data.volume_range, data.volume_range)
	voice.play()
	return true


func play_music(sound: StringName, fade: float = 3.0) -> void:
	var data: SoundData = BANK.find(sound)
	if sound == music_name or data == null:
		return
	music_name = sound
	var outgoing: AudioStreamPlayer = _music[_front]
	_front = 1 - _front
	var incoming: AudioStreamPlayer = _music[_front]
	incoming.stream = data.stream
	incoming.bus = data.bus
	incoming.volume_db = SILENT_DB
	incoming.play()
	_fade(incoming, data.volume_db, fade, false)
	_fade(outgoing, SILENT_DB, fade, true)


func playing_count() -> int:
	var count: int = 0
	for voice: Variant in _flat + _spatial:
		count += int(voice.playing)
	return count


func pool_size() -> int:
	return _flat.size() + _spatial.size()


func reset_world() -> void:
	ambience.reset()


func _add(node: Node) -> Node:
	add_child(node)
	return node


func _take(pool: Array[Node]) -> Node:
	var chosen: Node = pool[0]
	for voice: Variant in pool:
		if not voice.playing:
			chosen = voice
			break
		if _stamp.get(voice, 0) < _stamp.get(chosen, 0):
			chosen = voice
	_tick += 1
	_stamp[chosen] = _tick
	return chosen


func _fade(player: AudioStreamPlayer, to_db: float, seconds: float, stop_after: bool) -> void:
	if _fades.has(player) and _fades[player].is_valid():
		_fades[player].kill()
	if seconds <= 0.0:
		player.volume_db = to_db
		if stop_after:
			player.stop()
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", to_db, seconds)
	if stop_after:
		tween.tween_callback(player.stop)
	_fades[player] = tween


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not (node as BaseButton).pressed.is_connected(_on_button_pressed):
		(node as BaseButton).pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	play(&"ui_click")
