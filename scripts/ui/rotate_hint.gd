class_name RotateHint
extends CanvasLayer
## A card that asks a phone player to turn the phone sideways. It shows only in a browser, on a touch device, while the window is taller than it
## is wide. The game is paused while it shows (so nobody dies unseen), and the card un-pauses only what it paused itself: a pause the player
## or a pick screen already made is left alone. While it shows it swallows every input event (the screens behind it, such as the map select,
## the pause menu or the shop, keep working while the game is paused and would otherwise act on blind taps); when it is not showing it is hidden
## (not just transparent) and never touches input. It gives its own pause back if it leaves the tree while showing, so a scene change cannot
## strand a paused game.

const CARD_COLOR := Color("1b1226")
const TEXT_COLOR := Color("fff6e8")

var _card: Control
var _showing: bool = false
## True while the pause in effect is this card's own.
var _paused_by_card: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 70
	_card = Control.new()
	_card.name = "Card"
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = CARD_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(backdrop)
	var title := UiKit.label("Turn your phone sideways", &"Heading")
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.add_child(title)


func _input(_event: InputEvent) -> void:
	if _showing:
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_release_pause()


func _process(_delta: float) -> void:
	update_for(Vector2(get_window().size), OS.has_feature("web"), DisplayServer.is_touchscreen_available())


## True only in a browser, on a touch device, when the window is taller than it is wide.
static func should_show(window_size: Vector2, is_web: bool, has_touch: bool) -> bool:
	return is_web and has_touch and window_size.y > window_size.x


func is_showing() -> bool:
	return _showing


func card() -> Control:
	return _card


func update_for(window_size: Vector2, is_web: bool, has_touch: bool) -> void:
	var wanted := should_show(window_size, is_web, has_touch)
	if wanted == _showing:
		# Belt and braces: whatever un-paused the game while the card shows, the card pauses it again.
		if _showing and not get_tree().paused:
			_claim_pause()
		return
	_showing = wanted
	_card.visible = wanted
	if wanted:
		if not get_tree().paused:
			_claim_pause()
	else:
		_release_pause()


func _claim_pause() -> void:
	GamePause.set_paused(get_tree(), true)
	_paused_by_card = true


func _release_pause() -> void:
	if _paused_by_card:
		GamePause.set_paused(get_tree(), false)
		_paused_by_card = false
