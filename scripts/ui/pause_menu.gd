class_name PauseMenu
extends CanvasLayer
## The in-run pause menu: Resume, Settings (the shared `SettingsScreen`) and Quit to home (after a confirmation). It opens from the
## `pause` key or controller Start, or from the HUD pause button, only when `available` says so (Main: the player is alive and no other
## screen or the inventory is open), pauses through `GamePause` (which also freezes `GameTime`), and unpauses on every way out. It works
## while the tree is paused and handles its own touches (mouse emulation is off).

signal resumed
signal quit_requested

const CARD := Rect2(150, 60, 180, 150)
const BUTTON_SIZE := Vector2(120, 28)

## Asked before opening on the `pause` key. Main replaces it.
var available: Callable = func() -> bool: return true
var home_scene_path: String = Scenes.HOME

var _open: bool = false
var _resume: Button
var _settings_button: Button
var _quit: Button
var _root: Control
var _settings: SettingsScreen
var _confirm: ConfirmDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 22
	visible = false
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var card := Panel.new()
	card.position = CARD.position
	card.size = CARD.size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(card)
	var title := UiKit.label("Paused", &"Heading")
	title.position = Vector2(CARD.position.x + 12, CARD.position.y + 8)
	_root.add_child(title)
	_resume = _add_button("Resume", 0, &"ButtonGreen")
	_resume.pressed.connect(close)
	_settings_button = _add_button("Settings", 1)
	_settings_button.pressed.connect(open_settings)
	_quit = _add_button("Quit to home", 2, &"ButtonRed")
	_quit.pressed.connect(request_quit)
	_settings = (load("res://scenes/ui/settings_screen.tscn") as PackedScene).instantiate() as SettingsScreen
	add_child(_settings)
	_confirm = (load("res://scenes/ui/confirm_dialog.tscn") as PackedScene).instantiate() as ConfirmDialog
	add_child(_confirm)
	_confirm.confirmed.connect(_quit_confirmed)


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		return
	if _open:
		if not _settings.is_open() and not _confirm.is_open():
			close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause") and bool(available.call()):
		open()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if handle_input(event):
		get_viewport().set_input_as_handled()


## Turns a touch into the left mouse press or release the buttons expect. False while closed, or while Settings or the confirmation
## is open (they handle their own touches).
func handle_input(event: InputEvent) -> bool:
	if not _open or _settings.is_open() or _confirm.is_open() or not event is InputEventScreenTouch:
		return false
	get_viewport().push_input(TouchBridge.to_mouse_button(event), true)
	return true


func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	GamePause.set_paused(get_tree(), true)
	_resume.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	GamePause.set_paused(get_tree(), false)
	resumed.emit()


func is_open() -> bool:
	return _open


func settings_screen() -> SettingsScreen:
	return _settings


func confirm_dialog() -> ConfirmDialog:
	return _confirm


func open_settings() -> void:
	_root.visible = false
	if not _settings.closed.is_connected(_on_settings_closed):
		_settings.closed.connect(_on_settings_closed)
	_settings.open()


func request_quit() -> void:
	_confirm.ask("Quit to home?", "This run's potions, scrolls and spells will be lost. Your XP and Gold are already saved.", "Quit")


func _on_settings_closed() -> void:
	_root.visible = true
	if _open:
		_resume.grab_focus()


func _quit_confirmed() -> void:
	_open = false
	visible = false
	GamePause.set_paused(get_tree(), false)
	quit_requested.emit()
	SceneSwitcher.change_to(get_tree(), home_scene_path)


func _add_button(text: String, index: int, variation: StringName = &"") -> Button:
	var button := UiKit.button(text, variation)
	button.position = Vector2(CARD.position.x + (CARD.size.x - BUTTON_SIZE.x) / 2.0, CARD.position.y + 32.0 + index * 36.0)
	button.custom_minimum_size = BUTTON_SIZE
	_root.add_child(button)
	return button
