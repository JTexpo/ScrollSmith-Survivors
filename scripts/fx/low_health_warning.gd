class_name LowHealthWarning
extends CanvasLayer
## Makes remaining health impossible to miss. Below the first threshold (50%) the heart on the health bar beats slowly (`beat` with
## level 1). Below the second (30%) a dithered red frame pulses round the screen edge, the heart beats faster and the sound board plays
## a heartbeat (`beat` with level 2); the rate and the frame's strength rise as health falls. It is off at full health, gone at once on a
## heal and on death, and invisible behind a pause screen. The frame is a 480 by 270 pixel image at scale 1, never above the config's
## opacity and never faster than its top rate.

signal beat(level: int)

var _config: ImpactConfig
var _frame: TextureRect
var _ratio: float = 1.0
var _alive: bool = true
var _phase: float = 0.0


func _init() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_frame = TextureRect.new()
	_frame.name = "Frame"
	_frame.texture = ImageTexture.create_from_image(VignetteImage.build())
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.stretch_mode = TextureRect.STRETCH_KEEP
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.modulate.a = 0.0
	add_child(_frame)


func _process(delta: float) -> void:
	advance(delta)


func bind(health: HealthComponent) -> void:
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_on_health_changed(health.current_health, health.max_health)


## 0 above the first threshold, 1 from there down to the second, 2 below it (and alive).
func level() -> int:
	if not _alive:
		return 0
	var numbers := _numbers()
	if _ratio <= numbers.health_warn_from:
		return 2
	if _ratio <= numbers.health_beat_from:
		return 1
	return 0


## Beats per second at this health: slow above the warning threshold, rising as health falls below it.
func rate() -> float:
	var numbers := _numbers()
	if level() == 2:
		return lerpf(numbers.warn_rate_high, numbers.warn_rate_low, clampf(_ratio / numbers.health_warn_from, 0.0, 1.0))
	return numbers.beat_rate_slow


func frame_alpha() -> float:
	return _frame.modulate.a if _frame != null else 0.0


## Moves the pulse forward. `_process` calls it every frame; tests call it by hand.
func advance(delta: float) -> void:
	if _frame == null:
		return
	var current := level()
	if current == 0 or get_tree().paused:
		_frame.modulate.a = 0.0
		if current == 0:
			_phase = 0.0
		return
	_phase += rate() * delta
	if _phase >= 1.0:
		_phase -= floorf(_phase)
		beat.emit(current)
	if current == 2 and FxSettings.low_health_frame:
		var numbers := _numbers()
		var intensity := lerpf(1.0, 0.5, clampf(_ratio / numbers.health_warn_from, 0.0, 1.0))
		_frame.modulate.a = numbers.warn_max_alpha * intensity * (0.5 + 0.5 * cos(TAU * _phase))
	else:
		_frame.modulate.a = 0.0


func _on_health_changed(current: float, maximum: float) -> void:
	_ratio = current / maximum if maximum > 0.0 else 0.0
	_alive = current > 0.0
	if level() == 0 and _frame != null:
		_frame.modulate.a = 0.0


func _on_died() -> void:
	_alive = false
	if _frame != null:
		_frame.modulate.a = 0.0


func _numbers() -> ImpactConfig:
	if _config == null:
		_config = ImpactConfig.default_config()
	return _config
