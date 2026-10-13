@tool
extends EditorScript

const FOLDER: String = "res://assets/audio/"
const FILE: String = "res://resources/audio/sound_bank.tres"
const SFX: StringName = &"SFX"
const MUSIC: StringName = &"Music"
const AMBIENCE: StringName = &"Ambience"

const TABLE: Array[Array] = [
	[&"ui_click", "sfx_ui_click.wav", SFX, -6.0, 0.03, 1.0],
	[&"ui_tick", "sfx_ui_tick.wav", SFX, -8.0, 0.03, 1.0],
	[&"ui_open", "sfx_ui_open.wav", SFX, -6.0, 0.02, 1.0],
	[&"ui_close", "sfx_ui_close.wav", SFX, -6.0, 0.02, 1.0],
	[&"coin", "sfx_coin.wav", SFX, -4.0, 0.05, 1.5],
	[&"buy", "sfx_buy.wav", SFX, -4.0, 0.05, 1.5],
	[&"sell", "sfx_sell.wav", SFX, -5.0, 0.05, 1.5],
	[&"unlock", "sfx_unlock.wav", SFX, -4.0, 0.02, 0.5],
	[&"pickup", "sfx_pickup.wav", SFX, -4.0, 0.05, 1.5],
	[&"harvest", "sfx_harvest.wav", SFX, -3.0, 0.05, 1.5],
	[&"feed", "sfx_feed.wav", SFX, -4.0, 0.05, 1.5],
	[&"hoe", "sfx_hoe.wav", SFX, -2.0, 0.05, 1.5],
	[&"seed", "sfx_seed.wav", SFX, -3.0, 0.05, 1.5],
	[&"water", "sfx_water.wav", SFX, -4.0, 0.03, 1.0],
	[&"hammer", "sfx_hammer.wav", SFX, -2.0, 0.05, 1.5],
	[&"crunch", "sfx_crunch.wav", SFX, -2.0, 0.05, 1.5],
	[&"denied", "sfx_denied.wav", SFX, -5.0, 0.03, 1.0],
	[&"footstep", "sfx_footstep.wav", SFX, -9.0, 0.08, 2.5],
	[&"chime", "sfx_chime.wav", SFX, -6.0, 0.0, 0.0],
	[&"save", "sfx_save.wav", SFX, -6.0, 0.0, 0.0],
	[&"load", "sfx_load.wav", SFX, -6.0, 0.0, 0.0],
	[&"rain", "amb_rain.ogg", AMBIENCE, -6.0, 0.0, 0.0],
	[&"birds", "amb_birds.ogg", AMBIENCE, -4.0, 0.0, 0.0],
	[&"crickets", "amb_crickets.ogg", AMBIENCE, -4.0, 0.0, 0.0],
	[&"music_day", "music_day.ogg", MUSIC, -4.0, 0.0, 0.0],
	[&"music_night", "music_night.ogg", MUSIC, -5.0, 0.0, 0.0],
]


func _run() -> void:
	var bank := SoundBank.new()
	for row: Array in TABLE:
		var sound := SoundData.new()
		sound.id = row[0]
		sound.stream = load(FOLDER + String(row[1])) as AudioStream
		sound.bus = row[2]
		sound.volume_db = row[3]
		sound.pitch_range = row[4]
		sound.volume_range = row[5]
		bank.sounds.append(sound)
	var error: int = ResourceSaver.save(bank, FILE)
	print("Sound bank saved to ", FILE, " with ", bank.sounds.size(), " sounds (error code ", error, ")")
