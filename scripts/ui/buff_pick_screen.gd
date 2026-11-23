class_name BuffPickScreen
extends CanvasLayer
## A small screen that lists buffs and asks the player to pick one (a
## level's "chosen buff" reward, asked at the start of a run). It cannot be cancelled, and it holds
## no rules: Main decides which buffs are on offer and what the pick does. It pauses the world while
## open and works with mouse, keyboard, controller focus, and touch (bridged, because mouse
## emulation is off).

signal chosen(scroll: ScrollData)

const BUTTON_SIZE := Vector2(300, 26)

## Tests turn this off so the test runner itself is not paused.
@export var pause_tree: bool = true

var _open: bool = false
var _options: Array[ScrollData] = []
var _title_label: Label
var _box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if handle_input(event):
		get_viewport().set_input_as_handled()


## Swallows cancel and pause while open: this screen has to be answered.
func _unhandled_input(event: InputEvent) -> void:
	if _open and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()


## Turns a touch into a left mouse press so the buttons react (see CraftingScreen.handle_input).
func handle_input(event: InputEvent) -> bool:
	if not _open or not event is InputEventScreenTouch:
		return false
	get_viewport().push_input(TouchBridge.to_mouse_button(event), true)
	return true


## Does nothing with an empty list, so a pick with nothing to offer never freezes the game.
func open(options: Array[ScrollData], title: String) -> void:
	if options.is_empty():
		return
	_options = options.duplicate()
	_title_label.text = title
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	for i in _options.size():
		var button := _button("%s\n%s" % [_options[i].display_name, effect_text(_options[i])])
		button.pressed.connect(choose.bind(i))
		_box.add_child(button)
	_open = true
	visible = true
	if pause_tree:
		GamePause.set_paused(get_tree(), true)
	(_box.get_child(0) as Button).grab_focus()


func choose(index: int) -> void:
	if not _open or index < 0 or index >= _options.size():
		return
	var picked := _options[index]
	_open = false
	visible = false
	if pause_tree:
		GamePause.set_paused(get_tree(), false)
	chosen.emit(picked)


func is_open() -> bool:
	return _open


func option_count() -> int:
	return _options.size() if _open else 0


func button_text(index: int) -> String:
	return (_box.get_child(index) as Button).text


func first_button_has_focus() -> bool:
	return _box.get_child_count() > 0 and (_box.get_child(0) as Button).has_focus()


## "damage x1.5, cost x1.5": only the numbers that differ from neutral.
static func effect_text(scroll: ScrollData) -> String:
	var effect := scroll.buff
	var parts: Array[String] = []
	if effect == null:
		return ""
	if not is_equal_approx(effect.damage_multiplier, 1.0):
		parts.append("damage x%s" % _number(effect.damage_multiplier))
	if not is_equal_approx(effect.max_mana_multiplier, 1.0):
		parts.append("mana pool x%s" % _number(effect.max_mana_multiplier))
	if effect.vulnerability_bonus > 0.0:
		parts.append("strong-hit bonus +%s" % _number(effect.vulnerability_bonus))
	if effect.ignores_resistance:
		parts.append("ignores resistance")
	if effect.extra_copies > 0:
		parts.append("+%d copy" % effect.extra_copies if effect.extra_copies == 1 else "+%d copies" % effect.extra_copies)
	if not is_equal_approx(effect.cost_multiplier, 1.0):
		parts.append("cost x%s" % _number(effect.cost_multiplier))
	return ", ".join(parts)


static func _number(value: float) -> String:
	return String.num(value, 2)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var content := UiKit.window(root)
	_title_label = UiKit.label("", &"Heading")
	_title_label.position = Vector2(90, 24)
	content.add_child(_title_label)
	_box = VBoxContainer.new()
	_box.position = Vector2(90, 44)
	_box.add_theme_constant_override("separation", 3)
	content.add_child(_box)


func _button(text: String) -> Button:
	var button := UiKit.button(text)
	button.custom_minimum_size = BUTTON_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button
