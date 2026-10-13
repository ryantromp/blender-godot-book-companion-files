extends Node
## The signal bus. Any script can emit or connect a signal here
## without knowing who is on the other side. Later chapters add signals.

@warning_ignore("unused_signal")
signal day_started(day: int)
@warning_ignore("unused_signal")
signal hour_changed(hour: int)
