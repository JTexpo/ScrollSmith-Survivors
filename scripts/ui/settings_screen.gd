class_name SettingsScreen
extends CanvasLayer
## The Settings screen (shared by the home screen and the pause menu): music and effects volume, the screen-effect switches and the two
## strengths, a Reduce motion preset, the performance overlay, and Controls and Credits pages. Every change applies at once (the static
## settings change and `SettingsEvents` announces it) and is saved at once, so quitting cannot lose it. It works while the tree is paused
## and handles its own touches, including dragging a slider (mouse emulation is off).

signal closed

const ROW_X := 8.0
const SLIDER_X := 112.0
const SLIDER_SIZE := Vector2(200, 22)
const TOGGLE_SIZE := Vector2(224, 22)
const SLIDERS := [
	["music", "Music", 20.0],
	["sfx", "Effects", 44.0],
	["shake_scale", "Screen shake", 68.0],
	["flash_scale", "Screen flashes", 92.0],
]
const SWITCH_NAMES := {
	"particles": "Sparks and dust",
	"low_health_frame": "Low-health frame",
	"heart_beat": "Heartbeat",
	"hurt_feedback": "Hurt flash",
	"hit_indicators": "Hit arrows",
	"low_mana_pulse": "Low-mana pulse",
	"perf_overlay": "Performance overlay",
}

var settings_path: String = SettingsStore.DEFAULT_PATH

var _open: bool = false
var _page: StringName = &"main"
var _pages: Dictionary = {}
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _toggles: Dictionary = {}
var _fullscreen_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 24
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var viewport := get_viewport()
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		if _page != &"main":
			show_page(&"main")
		else:
			close()
		viewport.set_input_as_handled()
	elif handle_input(event):
		viewport.set_input_as_handled()


## Turns a touch into the left mouse press, release or drag the controls expect. False while closed.
func handle_input(event: InputEvent) -> bool:
	if not _open:
		return false
	if event is InputEventScreenTouch:
		get_viewport().push_input(TouchBridge.to_mouse_button(event), true)
		return true
	if event is InputEventScreenDrag:
		var motion := InputEventMouseMotion.new()
		motion.position = event.position
		motion.global_position = event.position
		motion.relative = event.relative
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
		return true
	return false


func open() -> void:
	_open = true
	visible = true
	show_page(&"main")
	_refresh()
	(_sliders["music"] as HSlider).grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


func show_page(page: StringName) -> void:
	_page = page
	for key in _pages:
		(_pages[key] as Control).visible = key == page


func page() -> StringName:
	return _page


func slider(key: String) -> HSlider:
	return _sliders.get(key) as HSlider


func toggle_button(key: String) -> Button:
	return _toggles.get(key) as Button


func fullscreen_button() -> Button:
	return _fullscreen_button


## Flips full screen (inside the tap or click that pressed it, as a browser requires), remembers the choice and saves it.
func toggle_fullscreen() -> void:
	GameSettings.fullscreen = ScreenMode.toggle()
	_changed()


func switch_count() -> int:
	return _toggles.size()


func set_music(value: float) -> void:
	GameSettings.music_volume = clampf(value, 0.0, 1.0)
	_changed()


func set_sfx(value: float) -> void:
	GameSettings.sfx_volume = clampf(value, 0.0, 1.0)
	_changed()


func set_switch(key: String, on: bool) -> void:
	FxSettings.set_switch(key, on)
	_changed()


## `key` is `shake_scale` or `flash_scale`.
func set_strength(key: String, value: float) -> void:
	FxSettings.apply({key: value})
	_changed()


func reduce_motion() -> void:
	FxSettings.reduce_motion()
	_changed()


func _changed() -> void:
	SettingsEvents.announce()
	SettingsStore.save_file(settings_path)
	_refresh()


func _refresh() -> void:
	if _sliders.is_empty():
		return
	_set_slider("music", GameSettings.music_volume)
	_set_slider("sfx", GameSettings.sfx_volume)
	_set_slider("shake_scale", FxSettings.shake_scale)
	_set_slider("flash_scale", FxSettings.flash_scale)
	for key in _toggles:
		var on := FxSettings.get_switch(key)
		var button := _toggles[key] as Button
		button.set_pressed_no_signal(on)
		button.text = "%s: %s" % [SWITCH_NAMES.get(key, key), "on" if on else "off"]
	if _fullscreen_button != null:
		_fullscreen_button.text = "Full screen: %s" % ("on" if ScreenMode.is_fullscreen() else "off")


func _set_slider(key: String, value: float) -> void:
	(_sliders[key] as HSlider).set_value_no_signal(value)
	(_value_labels[key] as Label).text = "%d%%" % roundi(value * 100.0)


func _on_slider_changed(value: float, key: String) -> void:
	match key:
		"music":
			set_music(value)
		"sfx":
			set_sfx(value)
		_:
			set_strength(key, value)


func _on_toggle_pressed(key: String) -> void:
	set_switch(key, not FxSettings.get_switch(key))


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var content := UiKit.window(root)
	var main := Control.new()
	main.name = "MainPage"
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(main)
	_pages[&"main"] = main
	_add_label(main, "Settings", Vector2(ROW_X, 3), &"Heading")
	for row in SLIDERS:
		var key: String = row[0]
		_add_label(main, row[1], Vector2(ROW_X, row[2] + 5.0))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.position = Vector2(SLIDER_X, row[2])
		slider.custom_minimum_size = SLIDER_SIZE
		slider.size = SLIDER_SIZE
		slider.focus_mode = Control.FOCUS_ALL
		slider.value_changed.connect(_on_slider_changed.bind(key))
		main.add_child(slider)
		_sliders[key] = slider
		_value_labels[key] = _add_label(main, "", Vector2(SLIDER_X + SLIDER_SIZE.x + 8.0, row[2] + 5.0))
	var index := 0
	for key in FxSettings.SWITCH_KEYS:
		var toggle := UiKit.button("", &"")
		toggle.toggle_mode = true
		toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		toggle.position = Vector2(ROW_X + (index % 2) * 236.0, 124.0 + floorf(index / 2.0) * 24.0)
		toggle.custom_minimum_size = TOGGLE_SIZE
		toggle.pressed.connect(_on_toggle_pressed.bind(key))
		main.add_child(toggle)
		_toggles[key] = toggle
		index += 1
	_fullscreen_button = UiKit.button("", &"")
	_fullscreen_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_fullscreen_button.position = Vector2(ROW_X + 236.0, 124.0 + 3.0 * 24.0)
	_fullscreen_button.custom_minimum_size = TOGGLE_SIZE
	_fullscreen_button.pressed.connect(toggle_fullscreen)
	main.add_child(_fullscreen_button)
	_add_button(main, "Reduce motion", Vector2(8, 236), Vector2(112, 28)).pressed.connect(reduce_motion)
	_add_button(main, "Controls", Vector2(128, 236), Vector2(80, 28)).pressed.connect(show_page.bind(&"controls"))
	_add_button(main, "Credits", Vector2(216, 236), Vector2(80, 28)).pressed.connect(show_page.bind(&"credits"))
	_add_button(main, "Close", Vector2(392, 236), UiKit.ACTION_SIZE, &"ButtonRed").pressed.connect(close)
	_pages[&"controls"] = _text_page(content, "Controls", ControlsText.lines())
	_pages[&"credits"] = _text_page(content, "Credits", CreditsText.LINES)
	show_page(&"main")


func _text_page(content: Control, title: String, lines: Array[String]) -> Control:
	var page := Control.new()
	page.name = "%sPage" % title
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(page)
	_add_label(page, title, Vector2(ROW_X, 3), &"Heading")
	var text := _add_label(page, "\n".join(lines), Vector2(ROW_X, 20))
	text.custom_minimum_size = Vector2(464, 200)
	text.size = text.custom_minimum_size
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_button(page, "Back", Vector2(392, 236), UiKit.ACTION_SIZE, &"ButtonRed").pressed.connect(show_page.bind(&"main"))
	return page


func _add_label(parent: Control, text: String, at: Vector2, variation: StringName = &"") -> Label:
	var label := UiKit.label(text, variation)
	label.position = at
	parent.add_child(label)
	return label


func _add_button(parent: Control, text: String, at: Vector2, minimum: Vector2, variation: StringName = &"") -> Button:
	var button := UiKit.button(text, variation)
	button.position = at
	button.custom_minimum_size = minimum
	parent.add_child(button)
	return button
