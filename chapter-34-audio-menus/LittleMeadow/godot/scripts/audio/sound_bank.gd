class_name SoundBank
extends Resource

@export var sounds: Array[SoundData] = []


func find(id: StringName) -> SoundData:
	for sound: SoundData in sounds:
		if sound.id == id:
			return sound
	return null


func ids() -> Array[StringName]:
	var found: Array[StringName] = []
	for sound: SoundData in sounds:
		found.append(sound.id)
	return found
