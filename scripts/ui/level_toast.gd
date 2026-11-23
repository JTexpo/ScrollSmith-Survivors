class_name LevelToast
extends Label
## "Level 4! More spell mana" shown when a level is reached, on a dark pill. Level-ups in a row
## are listed one per line (the newest last, at most MAX_LINES) so a big XP gain does not hide the
## earlier rewards. It only processes while it is showing.

const DURATION := 2.5
const FADE := 0.5
const MAX_LINES := 4

var _lines: Array[String] = []
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
		visible = false
		set_process(false)
		_lines.clear()
		return
	modulate.a = clampf(_time_left / FADE, 0.0, 1.0)


## `detail` replaces the reward's own description when it is not empty (a random buff names the buff).
func show_level_up(level: int, reward: LevelReward, detail: String = "") -> void:
	var line := detail if not detail.is_empty() else (reward.description if reward != null else "")
	_add_line("Level %d! %s" % [level, line])


func _add_line(line: String) -> void:
	_lines.append(line)
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	text = "\n".join(_lines)
	reset_size()
	UiKit.fit_centered(self, _center_x)
	modulate.a = 1.0
	_time_left = DURATION
	visible = true
	set_process(true)


## Adds a plain line (no "Level N!" prefix), for example a note about a buff rolled at run start.
func show_message(message: String) -> void:
	_add_line(message)


func is_showing() -> bool:
	return visible
