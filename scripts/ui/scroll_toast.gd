class_name ScrollToast
extends Label
## A short "+ Fire Scroll" message shown when a scroll is collected, on a dark pill in the scroll's colour. A newer pickup replaces it. It only processes while it is showing.

## Seconds the message stays, including the fade at the end.
const DURATION := 1.2
const FADE := 0.4

var _time_left: float = 0.0


func _ready() -> void:
	visible = false
	set_process(false)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		visible = false
		set_process(false)
		return
	modulate.a = clampf(_time_left / FADE, 0.0, 1.0)


func show_scroll(scroll: ScrollData) -> void:
	text = "+ %s Scroll" % scroll.display_name
	reset_size()
	add_theme_color_override("font_color", scroll.color)
	modulate.a = 1.0
	_time_left = DURATION
	visible = true
	set_process(true)


func is_showing() -> bool:
	return visible
