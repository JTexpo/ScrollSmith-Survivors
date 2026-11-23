class_name XpBar
extends Control
## A thin sky-blue XP bar along the top of the screen with the level next to it. It only shows what a RunProgress
## reports and holds no rules.

const BAR_HEIGHT := 4.0
const TEXT_AT := Vector2(92, 5)

var _progress: RunProgress
var _track: LevelTrack
var _ratio: float = 0.0
var _level: int = 1

var _bar: ProgressBar
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar = UiKit.bar(&"BarXp")
	_bar.name = "Bar"
	_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_bottom = BAR_HEIGHT
	add_child(_bar)
	_label = UiKit.label("", &"HudLabel")
	_label.name = "Level"
	_label.position = TEXT_AT
	add_child(_label)
	_update()


func bind(progress: RunProgress) -> void:
	_progress = progress
	_track = progress.track
	progress.xp_changed.connect(refresh)
	refresh(progress.profile.total_xp, progress.level())


func refresh(total_xp: int, level: int) -> void:
	_level = level
	_ratio = _track.progress(total_xp) if _track != null else 0.0
	_update()


func level_text() -> String:
	if _track != null and _level >= _track.max_level():
		return "Lv %d MAX" % _level
	return "Lv %d" % _level


func fill_ratio() -> float:
	return _ratio


func _update() -> void:
	if _label == null:
		return
	_label.text = level_text()
	_bar.value = _ratio
