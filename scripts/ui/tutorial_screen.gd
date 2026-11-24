class_name TutorialScreen
extends CanvasLayer
## The Tutorial: four pages (`TutorialPages`), each with a title, a row of sprites drawn 1:1 and a few short lines, with Back, Next (Done on
## the last page) and Close and a page counter. Left and right turn the page, Esc or the controller's back button closes. It never opens
## by itself: the home screen's Tutorial button opens it. Works while paused and takes its own touches (mouse emulation is off).

signal closed

const PICTURE_Y := 66.0
const PICTURE_STEP := 56.0
const LINES_Y := 100.0
const BUTTON_SIZE := Vector2(80, 28)

var _open: bool = false
var _index: int = 0
var _pages: Array[TutorialPage] = []
var _title: Label
var _lines: Label
var _counter: Label
var _pictures: Control
var _back: Button
var _next: Button
var _close: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 26
	visible = false
	_pages = TutorialPages.pages()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var content := UiKit.window(root)
	_title = UiKit.label("", &"Heading")
	_title.position = Vector2(8, 3)
	content.add_child(_title)
	_pictures = Control.new()
	_pictures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_pictures)
	_lines = UiKit.label("")
	_lines.position = Vector2(20, LINES_Y)
	_lines.size = Vector2(440, 100)
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_lines)
	_counter = UiKit.label("", &"Muted")
	_counter.position = Vector2(184, 244)
	_counter.size = Vector2(112, 12)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_counter)
	_back = _add_button(content, "Back", Vector2(8, 236), &"")
	_back.pressed.connect(back)
	_next = _add_button(content, "Next", Vector2(96, 236), &"ButtonGreen")
	_next.pressed.connect(next)
	_close = _add_button(content, "Close", Vector2(392, 236), &"ButtonRed")
	_close.pressed.connect(close)
	# Buttons that share a parent still need explicit neighbours for keyboard and controller (they sit side by side).
	_back.focus_neighbor_right = _back.get_path_to(_next)
	_next.focus_neighbor_left = _next.get_path_to(_back)
	_next.focus_neighbor_right = _next.get_path_to(_close)
	_close.focus_neighbor_left = _close.get_path_to(_next)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	# Taken first: a bridged tap on Close or Done takes this screen out of view before we return.
	var viewport := get_viewport()
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
		viewport.set_input_as_handled()
	elif event.is_action_pressed(&"ui_right"):
		next()
		viewport.set_input_as_handled()
	elif event.is_action_pressed(&"ui_left"):
		back()
		viewport.set_input_as_handled()
	elif handle_input(event):
		viewport.set_input_as_handled()


## Turns a touch into the left mouse press or release the buttons expect. False while closed.
func handle_input(event: InputEvent) -> bool:
	if not _open or not event is InputEventScreenTouch:
		return false
	get_viewport().push_input(TouchBridge.to_mouse_button(event), true)
	return true


func open() -> void:
	_open = true
	_index = 0
	visible = true
	_show_page()
	_next.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


## Next page; on the last page it is Done and closes.
func next() -> void:
	if _index >= _pages.size() - 1:
		close()
		return
	_index += 1
	_show_page()


func back() -> void:
	if _index <= 0:
		return
	_index -= 1
	_show_page()


func page_index() -> int:
	return _index


func page_count() -> int:
	return _pages.size()


func counter_text() -> String:
	return _counter.text


func title_text() -> String:
	return _title.text


func lines_text() -> String:
	return _lines.text


func picture_count() -> int:
	return _pictures.get_child_count()


func _show_page() -> void:
	var page := _pages[_index]
	_title.text = page.title
	_lines.text = "\n".join(page.lines)
	_counter.text = "%d of %d" % [_index + 1, _pages.size()]
	_back.disabled = _index == 0
	var last := _index == _pages.size() - 1
	_next.text = "Done" if last else "Next"
	for child in _pictures.get_children():
		_pictures.remove_child(child)
		child.queue_free()
	var total := page.sprites.size()
	for i in total:
		var x := 240.0 + (i - (total - 1) / 2.0) * PICTURE_STEP
		_pictures.add_child(_picture(page.sprites[i], Vector2(x, PICTURE_Y)))


## A sprite drawn 1:1 at a point (its first animation, so a sheet of frames shows one frame).
func _picture(sprite_name: StringName, at: Vector2) -> BodyView:
	var view := BodyView.new()
	view.position = at
	view.shadow_enabled = true
	if view.set_look(sprite_name):
		var data := SpriteLibrary.find(sprite_name)
		var names := data.frames().get_animation_names()
		if not names.is_empty():
			view.play(names[0])
	return view


func _add_button(parent: Control, text: String, at: Vector2, variation: StringName) -> Button:
	var button := UiKit.button(text, variation)
	button.position = at
	button.custom_minimum_size = BUTTON_SIZE
	parent.add_child(button)
	return button
