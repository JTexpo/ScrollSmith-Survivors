extends GutTest

var _health: HealthComponent
var _warning: LowHealthWarning
var _beats: Array[int] = []


func before_each() -> void:
	_health = HealthComponent.new()
	_health.max_health = 100.0
	add_child_autofree(_health)
	_health.current_health = 100.0
	_warning = LowHealthWarning.new()
	add_child_autofree(_warning)
	_warning.bind(_health)
	_beats = []
	_warning.beat.connect(func(level: int) -> void: _beats.append(level))


func after_each() -> void:
	get_tree().paused = false


func _set_health(fraction: float) -> void:
	_health.current_health = 100.0 * fraction
	_health.health_changed.emit(_health.current_health, _health.max_health)


func test_the_level_follows_health() -> void:
	assert_eq(_warning.level(), 0)
	_set_health(0.6)
	assert_eq(_warning.level(), 0)
	_set_health(0.5)
	assert_eq(_warning.level(), 1)
	_set_health(0.31)
	assert_eq(_warning.level(), 1)
	_set_health(0.3)
	assert_eq(_warning.level(), 2)
	_set_health(0.05)
	assert_eq(_warning.level(), 2)


func test_a_heal_clears_the_warning_at_once() -> void:
	_set_health(0.1)
	_warning.advance(0.2)
	assert_gt(_warning.frame_alpha(), 0.0)
	_set_health(1.0)
	assert_eq(_warning.level(), 0)
	assert_eq(_warning.frame_alpha(), 0.0)


func test_death_clears_it() -> void:
	_set_health(0.1)
	_health.current_health = 0.0
	_health.died.emit()
	assert_eq(_warning.level(), 0)
	_warning.advance(0.5)
	assert_eq(_warning.frame_alpha(), 0.0)


func test_a_warning_made_while_already_low_starts_at_the_right_level() -> void:
	var low := HealthComponent.new()
	low.max_health = 100.0
	add_child_autofree(low)
	low.current_health = 20.0
	var fresh := LowHealthWarning.new()
	add_child_autofree(fresh)
	fresh.bind(low)
	assert_eq(fresh.level(), 2)


func test_the_alpha_never_exceeds_the_cap_and_is_zero_at_levels_zero_and_one() -> void:
	var cap := ImpactConfig.default_config().warn_max_alpha
	for fraction in [1.0, 0.7, 0.5, 0.4]:
		_set_health(fraction)
		for i in 60:
			_warning.advance(0.05)
			assert_eq(_warning.frame_alpha(), 0.0, "no frame above the warning threshold (%s)" % fraction)
	for fraction in [0.3, 0.2, 0.1, 0.01]:
		_set_health(fraction)
		var biggest := 0.0
		for i in 80:
			_warning.advance(0.02)
			biggest = maxf(biggest, _warning.frame_alpha())
			assert_lte(_warning.frame_alpha(), cap + 0.0001)
		assert_gt(biggest, 0.05, "the frame is visible at %s" % fraction)


func test_the_rate_rises_as_health_falls_and_never_exceeds_two_hertz() -> void:
	var config := ImpactConfig.default_config()
	_set_health(0.3)
	var at_threshold := _warning.rate()
	assert_almost_eq(at_threshold, config.warn_rate_low, 0.001)
	_set_health(0.15)
	var middle := _warning.rate()
	_set_health(0.0001)
	var near_death := _warning.rate()
	assert_gt(middle, at_threshold)
	assert_gt(near_death, middle)
	assert_lte(near_death, config.warn_rate_high + 0.0001)
	_set_health(0.4)
	assert_almost_eq(_warning.rate(), config.beat_rate_slow, 0.001)


func test_beats_are_emitted_at_the_rate() -> void:
	_set_health(0.15)
	var rate := _warning.rate()
	for i in 80:
		_warning.advance(0.025)
	assert_between(_beats.size(), int(floor(rate * 2.0)) - 1, int(ceil(rate * 2.0)) + 1)
	for level in _beats:
		assert_eq(level, 2)
	_beats.clear()
	_set_health(0.4)
	for i in 100:
		_warning.advance(0.05)
	assert_gt(_beats.size(), 0)
	for level in _beats:
		assert_eq(level, 1, "the slow heart beat is level one")


func test_no_beats_above_the_threshold() -> void:
	_set_health(0.9)
	for i in 200:
		_warning.advance(0.05)
	assert_eq(_beats.size(), 0)


func test_the_warning_is_silent_while_paused() -> void:
	_set_health(0.1)
	_warning.advance(0.1)
	get_tree().paused = true
	_warning.advance(0.1)
	assert_eq(_warning.frame_alpha(), 0.0)
	assert_eq(_beats.size(), 0 if _beats.is_empty() else _beats.size())
	var before := _beats.size()
	for i in 100:
		_warning.advance(0.05)
	assert_eq(_beats.size(), before, "no beats while paused")


func test_the_frame_is_never_scaled_or_rotated_and_ignores_the_mouse() -> void:
	var frame := _warning.get_node("Frame") as TextureRect
	assert_eq(frame.scale, Vector2.ONE)
	assert_eq(frame.rotation, 0.0)
	assert_eq(frame.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(frame.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(frame.texture.get_size(), Vector2(480, 270))
	assert_eq(_warning.scale, Vector2.ONE)


func test_it_keeps_running_while_the_tree_is_paused_so_it_can_hide() -> void:
	assert_eq(_warning.process_mode, Node.PROCESS_MODE_ALWAYS)
