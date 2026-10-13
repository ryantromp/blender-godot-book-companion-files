class_name SoundData
extends Resource

@export var id: StringName
@export var stream: AudioStream
@export var bus: StringName = &"SFX"
@export_range(-30.0, 12.0, 0.5) var volume_db: float = 0.0
@export_range(0.0, 0.3, 0.01) var pitch_range: float = 0.05
@export_range(0.0, 6.0, 0.5) var volume_range: float = 1.5
