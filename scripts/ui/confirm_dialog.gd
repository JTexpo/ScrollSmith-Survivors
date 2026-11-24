class_name ConfirmDialog
extends CanvasLayer
## A yes-or-no card over everything: a title, a message, a red Cancel (focused first, the safe choice) and a green confirm button. Esc, the
## back button, a click or tap outside the card, and the Cancel button all cancel. Confirming is ignored for `input_guard_msec` after it
## opens, so a button held down from the press that opened it cannot confirm. It works while the tree is paused and handles its own
## touches (mouse emulation is off). Used for New game (twice) and Quit to home.

signal confirmed
signal cancelled

const CARD := Rect2(80, 70, 320, 130)
const BUTTON_SIZE := Vector2(96, 28)

var input_guard_msec: int = 300

var _open: bool = false
var _opened_at_msec: int = 0
var _title: Label
var _message: Label
var _confirm: Button
var _cancel: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var card := Panel.new()
	card.name = "Card"
	card.position = CARD.position
	card.size = CARD.size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	_title = UiKit.label("", &"Heading")
	_title.position = Vector2(CARD.position.x + 12, CARD.position.y + 8)
	_title.custom_minimum_size = Vector2(CARD.size.x - 24, 12)
	add_child(_title)
	_message = UiKit.label("")
	_message.position = Vector2(CARD.position.x + 12, CARD.position.y + 26)
	_message.custom_minimum_size = Vector2(CARD.size.x - 24, 50)
	_message.size = _message.custom_minimum_size
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	_cancel = UiKit.button("Cancel", &"ButtonRed")
	_cancel.position = Vector2(CARD.position.x + 16, CARD.end.y - BUTTON_SIZE.y - 10)
	_cancel.custom_minimum_size = BUTTON_SIZE
	_cancel.pressed.connect(_cancel_now)
	add_child(_cancel)
	_confirm = UiKit.button("OK", &"ButtonGreen")
	_confirm.position = Vector2(CARD.end.x - BUTTON_SIZE.x - 16, CARD.end.y - BUTTON_SIZE.y - 10)
	_confirm.custom_minimum_size = BUTTON_SIZE
	_confirm.pressed.connect(_confirm_now)
	add_child(_confirm)
	# The two buttons are direct children of the layer, so Godot finds no neighbour between them: say so, for keyboard and controller.
	_cancel.focus_neighbor_right = _cancel.get_path_to(_confirm)
	_confirm.focus_neighbor_left = _confirm.get_path_to(_cancel)
	_cancel.focus_next = _cancel.get_path_to(_confirm)
	_confirm.focus_previous = _confirm.get_path_to(_cancel)
	_confirm.focus_next = _confirm.get_path_to(_cancel)
	_cancel.focus_previous = _cancel.get_path_to(_confirm)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	# Taken first: a confirmed tap can change the scene (Quit to home, Play), which takes this node out of the tree.
	var viewport := get_viewport()
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		_cancel_now()
		viewport.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not CARD.has_point(event.position):
		_cancel_now()
		viewport.set_input_as_handled()
	elif handle_input(event):
		viewport.set_input_as_handled()


## Shows the card. Cancel has focus, so Enter or the controller's accept is the safe choice.
func ask(title: String, message: String, confirm_label: String, cancel_label: String = "Cancel") -> void:
	_title.text = title
	_message.text = message
	_confirm.text = confirm_label
	_cancel.text = cancel_label
	_open = true
	_opened_at_msec = Time.get_ticks_msec()
	visible = true
	_cancel.grab_focus()


func is_open() -> bool:
	return _open


## A touch outside the card cancels; one on it becomes the left mouse press or release the buttons expect. False while closed.
func handle_input(event: InputEvent) -> bool:
	if not _open or not event is InputEventScreenTouch:
		return false
	if event.pressed and not CARD.has_point(event.position):
		_cancel_now()
		return true
	get_viewport().push_input(TouchBridge.to_mouse_button(event), true)
	return true


func _confirm_now() -> void:
	if not _open or Time.get_ticks_msec() - _opened_at_msec < input_guard_msec:
		return
	_close()
	confirmed.emit()


func _cancel_now() -> void:
	if not _open:
		return
	_close()
	cancelled.emit()


func _close() -> void:
	_open = false
	visible = false
