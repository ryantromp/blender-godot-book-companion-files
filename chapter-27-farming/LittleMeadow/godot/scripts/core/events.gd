extends Node
## The signal bus. Any script can emit or connect a signal here
## without knowing who is on the other side. Later chapters add signals.

@warning_ignore("unused_signal")
signal day_started(day: int)
@warning_ignore("unused_signal")
signal hour_changed(hour: int)
@warning_ignore("unused_signal")
signal interaction_started(interactable: Interactable, farmer: Farmer)
@warning_ignore("unused_signal")
signal interaction_finished(interactable: Interactable, farmer: Farmer)
@warning_ignore("unused_signal")
signal water_level_changed(level: int, capacity: int)
@warning_ignore("unused_signal")
signal crop_harvested(crop: CropData, plot: SoilPlot)
@warning_ignore("unused_signal")
signal tool_changed(tool_name: StringName, crop: CropData)
@warning_ignore("unused_signal")
signal hint_shown(text: String)
