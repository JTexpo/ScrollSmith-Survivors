class_name SoundTest
extends Control
## A developer tool, not part of the game: every sound and tune in the catalog as a button, so the sounds can be judged by ear.
## Click, tap or press Enter on a button to play it (a tune loops until you press it again or Stop), "Play all" runs the sounds
## one after another, and the line at the bottom shows the sound's length, loudest point and catalog numbers.
## Run it with `godot --path . res://scenes/world/sound_test.tscn`.

const COLUMNS := 4
const COLUMN_WIDTH := 118.0
const ROW_HEIGHT := 19.0
const FIRST_ROW_Y := 22.0
const GAP_BETWEEN_SOUNDS := 0.7

var _catalog: SoundCatalog
var _player: AudioStreamPlayer
var _info: Label
var _buttons: Dictionary = {}
var _play_all_index: int = -1
var _timer: Timer


func _ready() -> void:
	_catalog = SoundCatalog.default_catalog()
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_play_next)
	add_child(_timer)
	var backdrop := ColorRect.new()
	backdrop.color = UiKit.BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var all := UiKit.button("Play all")
	all.position = Vector2(4, 2)
	all.custom_minimum_size = Vector2(110, 18)
	all.pressed.connect(play_all)
	add_child(all)
	var stop := UiKit.button("Stop", &"ButtonRed")
	stop.position = Vector2(122, 2)
	stop.custom_minimum_size = Vector2(110, 18)
	stop.pressed.connect(stop_all)
	add_child(stop)
	_info = UiKit.label("Pick a sound.")
	_info.position = Vector2(6, 235)
	_info.size = Vector2(468, 30)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	var index := 0
	for data in _catalog.sounds:
		var button := UiKit.button(String(data.id), &"ButtonYellow" if data.music else &"")
		button.position = Vector2(4 + (index % COLUMNS) * COLUMN_WIDTH, FIRST_ROW_Y + floorf(float(index) / COLUMNS) * ROW_HEIGHT)
		button.custom_minimum_size = Vector2(COLUMN_WIDTH - 4.0, ROW_HEIGHT - 1.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.pressed.connect(play.bind(data.id))
		add_child(button)
		_buttons[data.id] = button
		index += 1
	if not _buttons.is_empty():
		(_buttons.values()[0] as Button).grab_focus()


## How many sound buttons there are (one per catalog entry).
func sound_count() -> int:
	return _buttons.size()


func is_playing() -> bool:
	return _player.playing


## Plays one sound (or toggles a tune) and shows its numbers.
func play(id: StringName) -> void:
	var data := _catalog.find(id)
	var stream := SoundLibrary.find(id)
	if data == null or stream == null:
		_info.text = "%s: no sound file" % id
		return
	if data.music and _player.playing and _player.stream == stream:
		_player.stop()
		_info.text = "%s stopped" % id
		return
	_player.stream = stream
	_player.volume_db = data.volume_db
	_player.pitch_scale = 1.0
	_player.play()
	_info.text = "%s  %.2f s  %s  %d dB  %s, up to %d at once, gap %d ms, wobble %.1f" % [
		id, stream.get_length(), "loops" if data.music else "plays once", roundi(data.volume_db),
		SoundData.Priority.keys()[data.priority].to_lower(), data.max_voices, data.min_gap_msec, data.wobble]


func play_all() -> void:
	_play_all_index = -1
	_play_next()


func stop_all() -> void:
	_play_all_index = -2
	_timer.stop()
	_player.stop()
	_info.text = "Stopped."


func _play_next() -> void:
	if _play_all_index < -1:
		return
	_play_all_index += 1
	while _play_all_index < _catalog.sounds.size() and _catalog.sounds[_play_all_index].music:
		_play_all_index += 1
	if _play_all_index >= _catalog.sounds.size():
		_play_all_index = -2
		return
	var data := _catalog.sounds[_play_all_index]
	play(data.id)
	var stream := SoundLibrary.find(data.id)
	_timer.start((stream.get_length() if stream != null else 0.2) + GAP_BETWEEN_SOUNDS)
