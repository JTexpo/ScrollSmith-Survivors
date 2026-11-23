class_name ScreenFlash
extends CanvasLayer
## A soft white tint over the whole screen for a moment, only for heavy hits. Never more than the config's opacity (about 12%), never
## more often than its gap (about three a second), and `FxSettings.flash_scale` of 0 turns it off. A scale above 1 is held to 1.

var clock: Callable = func() -> int: return Time.get_ticks_msec()

var _rect: ColorRect
var _config: ImpactConfig
var _left: float = 0.0
var _last_msec: int = -1000000
var _flashes: int = 0


func _init() -> void:
	layer = 50


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.name = "Rect"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(1, 1, 1, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func flash(weight: float) -> void:
	var numbers := _numbers()
	var strength := clampf(FxSettings.flash_scale, 0.0, 1.0)
	if weight < numbers.flash_from or strength <= 0.0 or _rect == null:
		return
	var now: int = clock.call()
	if now - _last_msec < numbers.flash_gap_msec:
		return
	_last_msec = now
	_flashes += 1
	_left = numbers.flash_seconds
	_rect.color = Color(1, 1, 1, numbers.flash_max_alpha * strength)
	set_process(true)


func advance(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0 and _rect != null:
		_rect.color = Color(1, 1, 1, 0)
		set_process(false)


func flashes_made() -> int:
	return _flashes


func _numbers() -> ImpactConfig:
	if _config == null:
		_config = ImpactConfig.default_config()
	return _config
