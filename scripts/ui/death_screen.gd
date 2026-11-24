class_name DeathScreen
extends CanvasLayer
## The "You died" overlay: a dimmed world, a cream card with the run recap, a green Shop button and a Home button. Restarting is
## the R key, a controller button or a tap anywhere else.

signal restart_requested
## The player asked for the shop (the Shop button, a tap on it, or Enter or the controller's accept
## while it has focus). The screen then counts as "shop open" until `set_shop_open(false)`.
signal shop_requested
## The player asked for the home screen (the Home button or a tap on it). The run is left, not restarted.
signal home_requested

## Ignore restart input for this long after dying, so a held button doesn't skip the screen.
var input_delay_msec: int = 500
var restart_scene_path: String = ""
var home_scene_path: String = Scenes.HOME

var _shown_at_msec: int = 0
var _shop_open: bool = false

@onready var _recap: Control = $Recap
@onready var _shop_button: Button = $ShopButton
@onready var _home_button: Button = $HomeButton


func _ready() -> void:
	visible = false
	_shop_button.visible = false
	_home_button.visible = false
	_shop_button.pressed.connect(_request_shop)
	_home_button.pressed.connect(_request_home)
	# Both buttons are direct children of the layer, so Godot finds no neighbour between them: say so, for keyboard and controller.
	_shop_button.focus_neighbor_right = _shop_button.get_path_to(_home_button)
	_home_button.focus_neighbor_left = _home_button.get_path_to(_shop_button)
	_shop_button.focus_next = _shop_button.get_path_to(_home_button)
	_home_button.focus_previous = _home_button.get_path_to(_shop_button)
	_home_button.focus_next = _home_button.get_path_to(_shop_button)
	_shop_button.focus_previous = _shop_button.get_path_to(_home_button)


## Listens in _input, which runs before any control sees the event. _unhandled_input would never hear
## a tap that a control under the finger swallowed, and a screen-sized control would silently break
## "tap to restart" on a phone.
func _input(event: InputEvent) -> void:
	handle_event(event)


const ROW_TOP := 38.0
const ROW_STEP := 14.0
const LABEL_X := 70.0
const VALUE_X := 230.0
const BEST_X := 292.0

var _recap_rows: Array[Dictionary] = []


## Shows the run recap under "You died": one line per row (`RunRecap.rows`): its label, its value, and its best or "New best!".
func set_recap(rows: Array[Dictionary]) -> void:
	_recap_rows = rows
	for child in _recap.get_children():
		_recap.remove_child(child)
		child.queue_free()
	for i in rows.size():
		var y := ROW_TOP + i * ROW_STEP
		_add_label(rows[i]["label"], Vector2(LABEL_X, y), 150.0)
		_add_label(rows[i]["value"], Vector2(VALUE_X, y), 56.0)
		if rows[i]["new_best"]:
			_add_label("New best!", Vector2(BEST_X, y), 110.0, &"Heading")
		elif not String(rows[i]["best"]).is_empty():
			_add_label(rows[i]["best"], Vector2(BEST_X, y), 110.0, &"Muted")


## The recap as plain lines ("label: value  best X" or "label: value  New best!"), or "" when none was set.
func recap_text() -> String:
	var lines := PackedStringArray()
	for row in _recap_rows:
		var line := "%s: %s" % [row["label"], row["value"]]
		if row["new_best"]:
			line += "  New best!"
		elif not String(row["best"]).is_empty():
			line += "  %s" % row["best"]
		lines.append(line)
	return "\n".join(lines)


func _add_label(text: String, at: Vector2, width: float, variation: StringName = &"") -> void:
	var label := UiKit.label(text, variation)
	label.position = at
	label.size = Vector2(width, 12)
	label.clip_text = true
	_recap.add_child(label)


func show_death() -> void:
	if restart_scene_path.is_empty() and get_tree().current_scene != null:
		restart_scene_path = get_tree().current_scene.scene_file_path
	_shown_at_msec = Time.get_ticks_msec()
	visible = true
	_shop_button.visible = true
	_home_button.visible = true
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
		if touched and _home_button.visible and _home_button.get_global_rect().has_point(event.position):
			_request_home()
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


## Same guards as the shop button: nothing before death, inside the input delay or while the shop is open. It leaves the run and goes to
## the home screen; it is never a restart.
func _request_home() -> void:
	if not visible or _shop_open or Time.get_ticks_msec() - _shown_at_msec < input_delay_msec:
		return
	home_requested.emit()
	go_home()


func go_home() -> Error:
	return SceneSwitcher.change_to(get_tree(), home_scene_path)


func restart() -> Error:
	return SceneSwitcher.change_to(get_tree(), restart_scene_path)
