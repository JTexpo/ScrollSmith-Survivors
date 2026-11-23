class_name CameraShake
extends Node
## Shakes the camera by setting its `offset` (the camera's own smoothing is untouched) to whole-pixel offsets that settle back to zero.
## Heavy hits add trauma through `shake(weight)` above the config's threshold; blasts, slams and the player's own hurt add a fixed
## amount through `kick`. It restores the camera when it leaves the tree.

## Milliseconds now; tests replace it so time can be driven by hand.
var clock: Callable = func() -> int: return Time.get_ticks_msec()

var _camera: Camera2D
var _trauma := ShakeTrauma.new()
var _rng := RandomNumberGenerator.new()
var _config: ImpactConfig
var _shakes: int = 0


func _init() -> void:
	_rng.seed = 31


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func bind(camera: Camera2D) -> void:
	_camera = camera


## A hit of this weight shakes the screen if it is heavy enough.
func shake(weight: float) -> void:
	if weight >= _numbers().shake_from:
		kick(weight)


## Adds trauma (a fixed shake) whatever the weight. Refused inside the shake gap.
func kick(amount: float) -> void:
	if _camera == null:
		return
	if _trauma.add(amount, clock.call(), _numbers().shake_gap_msec):
		_shakes += 1
		set_process(true)


func advance(delta: float) -> void:
	if _camera == null:
		return
	_trauma.decay(delta)
	var offset := _trauma.offset_px(_numbers().shake_max_px, FxSettings.shake_scale, _rng)
	if _camera.offset != offset:
		_camera.offset = offset
	if _trauma.value() <= 0.0 and is_processing():
		set_process(false)


## How much shake is left, 0 to 1 (for the effects-test scene's readout).
func trauma() -> float:
	return _trauma.value()


func shakes_made() -> int:
	return _shakes


func _exit_tree() -> void:
	if is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO


func _numbers() -> ImpactConfig:
	if _config == null:
		_config = ImpactConfig.default_config()
	return _config
