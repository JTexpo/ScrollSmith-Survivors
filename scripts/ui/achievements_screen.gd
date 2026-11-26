class_name AchievementsScreen
extends CanvasLayer
## The Achievements screen: one card per achievement (its icon, name, goal and, for a boss, the spell it gives and where), earned ones in
## colour with a yellow ring and unearned ones with a greyed-out icon and muted text, a count line and a Close button. It is read-only. It
## runs while paused and takes its own touches (mouse emulation is off), deciding each by where it lands, so nothing is bridged: Close or
## the sky margin outside the page closes, a card does nothing. Esc or the back button closes. It opens only from the home screen.

signal closed

const COLUMNS := 3
const CARD_WIDTH := 152.0
const CARD_HEIGHT := 56.0
const GAP_X := 4.0
const GAP_Y := 2.0
const LEFT := 8.0
const GRID_TOP := 30.0
const BOTTOM := 264.0
const TEXT_X := 28.0
const TEXT_WIDTH := 120.0
const CLOSE_POSITION := Vector2(402, 0)
const GREYSCALE_SHADER := "res://resources/ui/grayscale.gdshader"

## Ignores a touch this long after opening, so the press that opened it (a held button) cannot close it.
var input_guard_msec: int = 300

var _open: bool = false
var _opened_msec: int = 0
var _content: Control
var _count: Label
var _close: Button
var _cards: Array[Panel] = []
var _icons: Array[TextureRect] = []
var _earned: Array[bool] = []
var _texts: Array[String] = []
var _greyscale: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 26
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_content = UiKit.window(root)
	var title := UiKit.label("Achievements", &"Heading")
	title.position = Vector2(8, 3)
	_content.add_child(title)
	_count = UiKit.label("", &"Muted")
	_count.position = Vector2(112, 3)
	_content.add_child(_count)
	_close = UiKit.button("Close", &"ButtonRed")
	_close.position = CLOSE_POSITION
	_close.custom_minimum_size = UiKit.ACTION_SIZE
	_close.pressed.connect(close)
	_content.add_child(_close)
	var shader := load(GREYSCALE_SHADER) as Shader
	if shader != null:
		_greyscale = ShaderMaterial.new()
		_greyscale.shader = shader


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var viewport := get_viewport()
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
		viewport.set_input_as_handled()
	elif handle_event(event):
		viewport.set_input_as_handled()


## Decides a touch or a left click by where it lands: Close or the margin outside the page closes; a card does nothing. Returns true when
## the event was used. False while closed and for every other kind of event (a button handles its own mouse click).
func handle_event(event: InputEvent) -> bool:
	if not _open:
		return false
	var position := Vector2.ZERO
	if event is InputEventScreenTouch:
		if not event.pressed:
			return true
		position = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		position = event.position
		if _close.get_global_rect().has_point(position):
			return false
	else:
		return false
	if Time.get_ticks_msec() - _opened_msec < input_guard_msec:
		return true
	if _close.get_global_rect().has_point(position) or not UiKit.WINDOW_RECT.has_point(position):
		close()
	return true


## Builds a card for every achievement in the catalog and shows the screen. `profile` says which are earned.
func open(catalog: AchievementCatalog, profile: PlayerProfile, track: LevelTrack) -> void:
	_clear_cards()
	var entries: Array[AchievementData] = []
	for data in catalog.achievements:
		if data != null:
			entries.append(data)
	var rows := maxi(ceili(float(entries.size()) / COLUMNS), 1)
	var height := minf(CARD_HEIGHT, floorf((BOTTOM - GRID_TOP) / rows) - GAP_Y)
	var earned_count := 0
	for i in entries.size():
		var data := entries[i]
		var earned := profile.has_achievement(data.id)
		if earned:
			earned_count += 1
		var at := Vector2(LEFT + (i % COLUMNS) * (CARD_WIDTH + GAP_X), GRID_TOP + (i / COLUMNS) * (height + GAP_Y))
		_add_card(data, earned, track, at, height)
	_count.text = "%d of %d" % [earned_count, entries.size()]
	_open = true
	_opened_msec = Time.get_ticks_msec()
	visible = true
	_close.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


func card_count() -> int:
	return _cards.size()


func card_earned(index: int) -> bool:
	return _earned[index]


## The card's name, goal and (for a boss) reward line, one per line.
func card_text(index: int) -> String:
	return _texts[index]


func card_rect(index: int) -> Rect2:
	return _cards[index].get_global_rect()


func card_panel_variation(index: int) -> StringName:
	return _cards[index].theme_type_variation


func icon_material(index: int) -> Material:
	return _icons[index].material


func icon_is_grey(index: int) -> bool:
	return _icons[index].material != null


## "3 of 12".
func count_text() -> String:
	return _count.text


func close_button() -> Button:
	return _close


func _clear_cards() -> void:
	for card in _cards:
		_content.remove_child(card)
		card.queue_free()
	_cards.clear()
	_icons.clear()
	_earned.clear()
	_texts.clear()


func _add_card(data: AchievementData, earned: bool, track: LevelTrack, at: Vector2, height: float) -> void:
	var card := Panel.new()
	card.theme_type_variation = &"PanelSlotSelected" if earned else &"PanelSlot"
	card.position = at
	card.size = Vector2(CARD_WIDTH, height)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(card)
	var icon := UiKit.icon(data.icon)
	icon.position = Vector2(6, 6)
	if not earned and _greyscale != null:
		icon.material = _greyscale
	card.add_child(icon)
	var name_label := UiKit.label(data.display_name, &"" if earned else &"Muted")
	name_label.position = Vector2(TEXT_X, 3)
	card.add_child(name_label)
	var goal := UiKit.label(data.goal_text(), &"Muted")
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.position = Vector2(TEXT_X, 14)
	goal.size = Vector2(TEXT_WIDTH, 20)
	card.add_child(goal)
	var lines := [data.display_name, data.goal_text()]
	var reward := data.reward_text(track)
	if not reward.is_empty():
		var reward_label := UiKit.label(reward)
		reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reward_label.position = Vector2(TEXT_X, 34)
		reward_label.size = Vector2(TEXT_WIDTH, 20)
		card.add_child(reward_label)
		lines.append(reward)
	_cards.append(card)
	_icons.append(icon)
	_earned.append(earned)
	_texts.append("\n".join(lines))
