class_name MapSelectScreen
extends CanvasLayer
## The map select: one card per catalog entry (a schematic preview, the name, the theme line, the boss and the player's best on that map),
## Back and Play. A tap or click on a card starts that map; Play starts the focused one. Left and right move between cards. It runs while
## paused and takes its own touches (mouse emulation is off), deciding each one by where it lands, so nothing is bridged. It opens only
## from the home screen's Play button and starts nothing itself: it announces the choice and the home screen loads the scene.

signal closed
signal map_chosen(entry: MapEntry)

const CARD_SIZE := Vector2(144, 162)
const CARD_GAP := 8.0
const CARDS_TOP := 30.0
const BUTTON_SIZE := Vector2(80, 28)
const BUTTONS_Y := 236.0

## Ignores a choice this long after opening, so the press that opened it (a held button) cannot choose.
var input_guard_msec: int = 300

var _open: bool = false
var _opened_msec: int = 0
## The card Play starts: the last one that had focus (Play itself takes focus when it is clicked or reached by key, so focus alone cannot say).
var _selected: int = 0
var _entries: Array[MapEntry] = []
var _cards: Array[Button] = []
var _card_texts: Array[String] = []
var _content: Control
var _back: Button
var _play: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 26
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_content = UiKit.window(root)
	var title := UiKit.label("Choose a map", &"Heading")
	title.position = Vector2(8, 3)
	_content.add_child(title)
	_back = _add_button("Back", Vector2(8, BUTTONS_Y), &"ButtonRed")
	_back.pressed.connect(close)
	_play = _add_button("Play", Vector2(96, BUTTONS_Y), &"ButtonGreen")
	_play.pressed.connect(func() -> void: choose(_selected))
	_back.focus_neighbor_right = _back.get_path_to(_play)
	_play.focus_neighbor_left = _play.get_path_to(_back)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	# Taken first: choosing a map changes the scene, which takes this screen out of the tree before we return.
	var viewport := get_viewport()
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
		viewport.set_input_as_handled()
	elif handle_event(event):
		viewport.set_input_as_handled()


## Decides a touch (or a left click outside everything) by where it lands: a card starts its map, Play starts the focused one, Back or
## anywhere else closes. Returns true when the event was used. False while closed and for every other kind of event.
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
		if _hits_something(position):
			return false
	else:
		return false
	for i in _cards.size():
		if _cards[i].get_global_rect().has_point(position):
			choose(i)
			return true
	if _play.get_global_rect().has_point(position):
		_play.pressed.emit()
	else:
		close()
	return true


## Opens with a card for every entry; focus starts on `last_map`'s card (the first card when it is not in the catalog).
func open(profile: PlayerProfile, catalog: MapCatalog, last_map: StringName) -> void:
	_clear_cards()
	var focus_index := 0
	for entry in catalog.entries:
		if entry == null or entry.map == null:
			continue
		if entry.map.id == last_map:
			focus_index = _entries.size()
		_entries.append(entry)
	var count := _entries.size()
	var left := (480.0 - count * CARD_SIZE.x - (count - 1) * CARD_GAP) / 2.0
	for i in count:
		_add_card(i, _entries[i], profile, Vector2(left + i * (CARD_SIZE.x + CARD_GAP), CARDS_TOP))
	_wire_focus()
	_open = true
	_opened_msec = Time.get_ticks_msec()
	_selected = focus_index
	visible = true
	if count > 0:
		_cards[focus_index].grab_focus()
	else:
		_play.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


## Announces the choice of card `index`. Ignored for a bad index and inside the input guard after opening.
func choose(index: int) -> void:
	if not _open or index < 0 or index >= _entries.size():
		return
	if Time.get_ticks_msec() - _opened_msec < input_guard_msec:
		return
	map_chosen.emit(_entries[index])


func card_count() -> int:
	return _cards.size()


func card_button(index: int) -> Button:
	return _cards[index]


## The card's name, theme line, boss line and best line, one per line.
func card_text(index: int) -> String:
	return _card_texts[index]


## The index of the card that has focus, or -1.
func focused_index() -> int:
	for i in _cards.size():
		if _cards[i].has_focus():
			return i
	return -1


func _hits_something(position: Vector2) -> bool:
	for card in _cards:
		if card.get_global_rect().has_point(position):
			return true
	return _play.get_global_rect().has_point(position) or _back.get_global_rect().has_point(position)


func _clear_cards() -> void:
	for card in _cards:
		_content.remove_child(card)
		card.queue_free()
	_cards.clear()
	_entries.clear()
	_card_texts.clear()


func _add_card(index: int, entry: MapEntry, profile: PlayerProfile, at: Vector2) -> void:
	var card := UiKit.button("")
	card.position = at
	card.size = CARD_SIZE
	card.custom_minimum_size = CARD_SIZE
	card.pressed.connect(choose.bind(index))
	card.focus_entered.connect(func() -> void: _selected = index)
	_content.add_child(card)
	var preview := MapPreview.new()
	preview.position = Vector2(8, 8)
	preview.set_map(entry.map)
	card.add_child(preview)
	var name_label := UiKit.label(entry.map.display_name, &"Heading")
	name_label.position = Vector2(8, 84)
	name_label.size = Vector2(128, 12)
	card.add_child(name_label)
	var theme_label := UiKit.label(entry.map.description)
	# Wrapping first: a label's width is held at its unwrapped text width until it wraps, so a size set before it would be stretched.
	theme_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	theme_label.position = Vector2(8, 98)
	theme_label.size = Vector2(128, 32)
	card.add_child(theme_label)
	var boss_text := "Boss: %s" % entry.boss_name() if not entry.boss_name().is_empty() else ""
	var boss_label := UiKit.label(boss_text, &"Muted")
	boss_label.position = Vector2(8, 134)
	boss_label.size = Vector2(128, 12)
	card.add_child(boss_label)
	var seconds := profile.best_seconds(entry.map.id)
	var best_text := "Best: %s" % RunClockLabel.format(seconds) if seconds > 0 else "No best yet"
	var best_label := UiKit.label(best_text, &"Muted")
	best_label.position = Vector2(8, 146)
	best_label.size = Vector2(128, 12)
	card.add_child(best_label)
	_cards.append(card)
	_card_texts.append("\n".join([entry.map.display_name, entry.map.description, boss_text, best_text]))


func _wire_focus() -> void:
	for i in _cards.size():
		if i > 0:
			_cards[i].focus_neighbor_left = _cards[i].get_path_to(_cards[i - 1])
		if i < _cards.size() - 1:
			_cards[i].focus_neighbor_right = _cards[i].get_path_to(_cards[i + 1])
		_cards[i].focus_neighbor_bottom = _cards[i].get_path_to(_play)
	if not _cards.is_empty():
		_play.focus_neighbor_top = _play.get_path_to(_cards[0])
		_back.focus_neighbor_top = _back.get_path_to(_cards[0])


func _add_button(text: String, at: Vector2, variation: StringName) -> Button:
	var button := UiKit.button(text, variation)
	button.position = at
	button.custom_minimum_size = BUTTON_SIZE
	_content.add_child(button)
	return button
