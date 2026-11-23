class_name DeathScreen
extends CanvasLayer
## The "You died" overlay: a dimmed world, a cream card with the run summary and a green Shop button. Restarting is
## the R key, a controller button or a tap anywhere else.

signal restart_requested
## The player asked for the shop (the Shop button, a tap on it, or Enter or the controller's accept
## while it has focus). The screen then counts as "shop open" until `set_shop_open(false)`.
signal shop_requested

## Ignore restart input for this long after dying, so a held button doesn't skip the screen.
var input_delay_msec: int = 500
var restart_scene_path: String = ""

var _shown_at_msec: int = 0
var _shop_open: bool = false

@onready var _summary: Label = $Summary
@onready var _shop_button: Button = $ShopButton


func _ready() -> void:
	visible = false
	_summary.visible = false
	_shop_button.visible = false
	_shop_button.pressed.connect(_request_shop)


## Listens in _input, which runs before any control sees the event. _unhandled_input would never hear
## a tap that a control under the finger swallowed, and a screen-sized control would silently break
## "tap to restart" on a phone.
func _input(event: InputEvent) -> void:
	handle_event(event)


## Adds a line under "You died": the XP and Gold gained this run and the level reached.
## `seconds` of 0 or more adds how long the run lasted.
func set_run_summary(run_xp: int, level: int, run_gold: int = 0, seconds: float = -1.0) -> void:
	_summary.text = "+%d XP, +%d Gold this run, level %d" % [run_xp, run_gold, level]
	if seconds >= 0.0:
		_summary.text += ", survived %s" % RunClockLabel.format(seconds)
	_summary.visible = true


## The summary line, or "" if none was set.
func summary_text() -> String:
	return _summary.text if _summary.visible else ""


func show_death() -> void:
	if restart_scene_path.is_empty() and get_tree().current_scene != null:
		restart_scene_path = get_tree().current_scene.scene_file_path
	_shown_at_msec = Time.get_ticks_msec()
	visible = true
	_shop_button.visible = true
	_shop_button.grab_focus()


## Tells the screen the shop opened or closed. While it is open nothing here restarts the run.
func set_shop_open(open: bool) -> void:
	_shop_open = open
	if not open and visible:
		_shop_button.grab_focus()


func handle_event(event: InputEvent) -> void:
	if not visible or _shop_open or Time.get_ticks_msec() - _shown_at_msec < input_delay_msec:
		return
	var touched := false
	if event is InputEventScreenTouch:
		touched = event.pressed
		# Touches never reach the button (mouse emulation is off), so a tap on it is handled here and
		# is never a restart.
		if touched and _shop_button.visible and _shop_button.get_global_rect().has_point(event.position):
			_request_shop()
			return
	if touched or event.is_action_pressed(&"restart"):
		restart_requested.emit()
		restart()


## Ignored while the death screen is hidden, while the shop is already open, and inside the input
## delay, so a button mashed at the moment of death cannot open the shop and then press inside it.
func _request_shop() -> void:
	if not visible or _shop_open or Time.get_ticks_msec() - _shown_at_msec < input_delay_msec:
		return
	_shop_open = true
	shop_requested.emit()


func restart() -> Error:
	return SceneSwitcher.change_to(get_tree(), restart_scene_path)
