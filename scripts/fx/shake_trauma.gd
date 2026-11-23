class_name ShakeTrauma
extends RefCounted
## The "trauma" behind a screen shake, pure so its rules are testable. Hits add trauma (capped at 1), it drains quickly, and the
## shake is a random whole-pixel offset of `round(max_px * trauma^2 * scale)`. A hit inside the gap since the last one adds nothing, so
## twenty hits in a frame shake once. The scale is held between 0 and 1: the comfort maximum can never be exceeded.

const DECAY_PER_SECOND := 3.0

var _value: float = 0.0
var _last_msec: int = -1000000


func add(amount: float, now_msec: int, gap_msec: int) -> bool:
	if now_msec - _last_msec < gap_msec:
		return false
	_last_msec = now_msec
	_value = minf(_value + amount, 1.0)
	return true


func decay(delta: float) -> void:
	_value = maxf(_value - DECAY_PER_SECOND * delta, 0.0)


func value() -> float:
	return _value


func offset_px(max_px: float, scale: float, rng: RandomNumberGenerator) -> Vector2:
	var magnitude := int(round(max_px * _value * _value * clampf(scale, 0.0, 1.0)))
	if magnitude <= 0:
		return Vector2.ZERO
	return Vector2(rng.randi_range(-magnitude, magnitude), rng.randi_range(-magnitude, magnitude))
