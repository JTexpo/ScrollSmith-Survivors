extends GutTest

var _indicator: HitIndicator


func before_each() -> void:
	FxSettings.reset()
	_indicator = HitIndicator.new()
	add_child_autofree(_indicator)


func after_each() -> void:
	FxSettings.reset()


func _arcs() -> Array[Sprite2D]:
	return _indicator.visible_arcs()


func test_a_hit_from_the_left_shows_an_arc_at_the_left_edge() -> void:
	_indicator.show_hit(Vector2(-1, 0))
	assert_eq(_arcs().size(), 1)
	assert_lt(_arcs()[0].position.x, 20.0)
	assert_false(_arcs()[0].flip_h)


func test_right_top_and_bottom_hits_flip_the_arc_the_right_way() -> void:
	_indicator.show_hit(Vector2(1, 0))
	var right := _arcs()[0]
	assert_gt(right.position.x, 440.0)
	assert_true(right.flip_h)
	_indicator.clear()
	_indicator.show_hit(Vector2(0, -1))
	var top := _arcs()[0]
	assert_lt(top.position.y, 20.0)
	assert_false(top.flip_v)
	_indicator.clear()
	_indicator.show_hit(Vector2(0, 1))
	var bottom := _arcs()[0]
	assert_gt(bottom.position.y, 240.0)
	assert_true(bottom.flip_v)


func test_the_arc_slides_along_the_edge_towards_the_hits_other_component() -> void:
	_indicator.show_hit(Vector2(-1, -0.8))
	var high := _arcs()[0].position.y
	_indicator.clear()
	_indicator.show_hit(Vector2(-1, 0.8))
	var low := _arcs()[0].position.y
	assert_lt(high, low)


func test_the_arc_fades_out_and_hides() -> void:
	_indicator.show_hit(Vector2(-1, 0))
	_indicator.advance(0.05)
	assert_almost_eq(_arcs()[0].modulate.a, 1.0, 0.001)
	_indicator.advance(0.15)
	assert_lt(_arcs()[0].modulate.a, 1.0)
	_indicator.advance(1.0)
	assert_eq(_arcs().size(), 0)


func test_at_most_three_arcs_at_once_and_the_oldest_is_reused() -> void:
	_indicator.show_hit(Vector2(-1, 0))
	_indicator.advance(0.01)
	_indicator.show_hit(Vector2(1, 0))
	_indicator.advance(0.01)
	_indicator.show_hit(Vector2(0, -1))
	_indicator.advance(0.01)
	_indicator.show_hit(Vector2(0, 1))
	assert_eq(_arcs().size(), HitIndicator.MAX_ARCS)
	var any_left := false
	for arc in _arcs():
		if arc.position.x < 20.0 and arc.position.y > 20.0 and arc.position.y < 240.0:
			any_left = true
	assert_false(any_left, "the oldest (left) arc was reused for the newest hit")


func test_arcs_are_never_scaled_or_rotated() -> void:
	for direction in [Vector2(-1, 0), Vector2(1, 0.4), Vector2(0.2, -1), Vector2(-0.3, 1)]:
		_indicator.show_hit(direction)
	for arc in _arcs():
		assert_eq(arc.scale, Vector2.ONE)
		assert_eq(arc.rotation, 0.0)
		assert_eq(arc.position, arc.position.round(), "on whole pixels")


func test_turning_the_indicators_off_shows_nothing() -> void:
	FxSettings.hit_indicators = false
	_indicator.show_hit(Vector2(-1, 0))
	assert_eq(_arcs().size(), 0)


func test_a_zero_direction_is_harmless() -> void:
	_indicator.show_hit(Vector2.ZERO)
	assert_lte(_arcs().size(), 1)
