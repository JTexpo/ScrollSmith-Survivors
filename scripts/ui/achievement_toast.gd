class_name AchievementToast
extends Label
## "Achievement unlocked: defeat the Tempest Dragon" on a dark pill. Several unlocks queue and show one after another; each stays
## for DURATION seconds and fades over the last FADE. It counts `_process` time, so it freezes while the game is paused, and it
## never takes a touch.

const DURATION := 3.0
const FADE := 0.5

var _queue: Array[String] = []
var _time_left: float = 0.0
## Where the middle of the pill is in the scene; it stays there however wide the text makes it.
var _center_x: float = 0.0


func _ready() -> void:
	_center_x = position.x + size.x * 0.5
	visible = false
	set_process(false)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		if _queue.is_empty():
			visible = false
			set_process(false)
		else:
			_show_next()
		return
	modulate.a = clampf(_time_left / FADE, 0.0, 1.0)


## Shows the unlock now, or after the ones already waiting.
func show_unlocked(data: AchievementData) -> void:
	_queue.append(data.toast_text())
	if not visible:
		_show_next()


func is_showing() -> bool:
	return visible


func queued_count() -> int:
	return _queue.size()


func _show_next() -> void:
	text = _queue.pop_front()
	reset_size()
	UiKit.fit_centered(self, _center_x)
	modulate.a = 1.0
	_time_left = DURATION
	visible = true
	set_process(true)
