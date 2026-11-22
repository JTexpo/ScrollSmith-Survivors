class_name RunClockLabel
extends Label
## TEMPORARY look: the run clock as "M:SS". It reads the pausable RunClock about four times a second from
## _process, so it stops while the game is paused.

const UPDATE_EVERY := 0.25

var _since_update: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 8)
	text = clock_text()


func _process(delta: float) -> void:
	_since_update += delta
	if _since_update >= UPDATE_EVERY:
		_since_update = 0.0
		text = clock_text()


## "5:07" for 307 seconds. Minutes keep counting past an hour.
static func format(seconds: float) -> String:
	var whole := maxi(int(seconds), 0)
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]


func clock_text() -> String:
	return format(RunClock.seconds())
