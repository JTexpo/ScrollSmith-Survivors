extends GutTest

var _camera: Camera2D
var _shake: CameraShake
var _now: int = 0


func before_each() -> void:
	FxSettings.reset()
	_now = 0
	_camera = Camera2D.new()
	add_child_autofree(_camera)
	_shake = CameraShake.new()
	_shake.clock = func() -> int: return _now
	add_child_autofree(_shake)
	_shake.bind(_camera)


func after_each() -> void:
	FxSettings.reset()


func test_a_heavy_hit_moves_the_camera_offset_and_it_settles_to_zero() -> void:
	_shake.shake(1.0)
	var moved := false
	for i in 20:
		_shake.advance(0.016)
		if _camera.offset != Vector2.ZERO:
			moved = true
	assert_true(moved)
	_shake.advance(3.0)
	assert_eq(_camera.offset, Vector2.ZERO)


func test_a_light_hit_below_the_threshold_does_not_shake() -> void:
	_shake.shake(0.2)
	_shake.advance(0.016)
	assert_eq(_camera.offset, Vector2.ZERO)
	assert_eq(_shake.shakes_made(), 0)


func test_twenty_hits_in_one_frame_shake_once() -> void:
	for i in 20:
		_shake.shake(1.0)
	assert_eq(_shake.shakes_made(), 1)


func test_shake_scale_zero_never_moves_the_camera() -> void:
	FxSettings.shake_scale = 0.0
	for i in 30:
		_now += 100
		_shake.shake(1.0)
		_shake.advance(0.016)
		assert_eq(_camera.offset, Vector2.ZERO)


func test_the_offset_never_exceeds_four_pixels_whatever_the_scale() -> void:
	FxSettings.shake_scale = 9.0
	for i in 60:
		_now += 100
		_shake.shake(1.0)
		_shake.advance(0.016)
		assert_lte(absf(_camera.offset.x), 4.0)
		assert_lte(absf(_camera.offset.y), 4.0)
		assert_eq(_camera.offset, _camera.offset.round())


func test_an_unbound_shake_does_nothing_and_does_not_crash() -> void:
	var loose := CameraShake.new()
	add_child_autofree(loose)
	loose.shake(1.0)
	loose.advance(0.1)
	assert_true(true)


func test_the_camera_is_restored_when_the_shake_leaves_the_tree() -> void:
	_shake.shake(1.0)
	_shake.advance(0.016)
	_shake.free()
	assert_eq(_camera.offset, Vector2.ZERO)
