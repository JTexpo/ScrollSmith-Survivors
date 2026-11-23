extends GutTest


func _rect() -> MapObstacle:
	var obstacle := MapObstacle.new()
	obstacle.kind = MapObstacle.Kind.RECT
	obstacle.position = Vector2(100, 100)
	obstacle.size = Vector2(40, 20)
	return obstacle


func _circle() -> MapObstacle:
	var obstacle := MapObstacle.new()
	obstacle.kind = MapObstacle.Kind.CIRCLE
	obstacle.position = Vector2(200, 100)
	obstacle.radius = 10.0
	return obstacle


func test_a_rect_contains_its_inside_and_not_its_outside() -> void:
	var rect := _rect()
	assert_true(rect.contains(Vector2(100, 100)))
	assert_true(rect.contains(Vector2(119, 109)))
	assert_false(rect.contains(Vector2(121, 100)))
	assert_false(rect.contains(Vector2(100, 111)))


func test_grow_widens_a_rect_and_a_circle() -> void:
	assert_false(_rect().contains(Vector2(125, 100)))
	assert_true(_rect().contains(Vector2(125, 100), 6.0))
	assert_false(_circle().contains(Vector2(215, 100)))
	assert_true(_circle().contains(Vector2(215, 100), 6.0))


func test_a_circle_contains_by_radius() -> void:
	assert_true(_circle().contains(Vector2(209, 100)))
	assert_false(_circle().contains(Vector2(208, 108)))


func test_overlaps_rect_for_both_kinds() -> void:
	assert_true(_rect().overlaps_rect(Rect2(110, 95, 30, 30)))
	assert_false(_rect().overlaps_rect(Rect2(130, 95, 10, 10)))
	assert_true(_circle().overlaps_rect(Rect2(205, 95, 20, 20)))
	assert_false(_circle().overlaps_rect(Rect2(215, 95, 10, 10)))
	assert_true(_circle().overlaps_rect(Rect2(215, 95, 10, 10), 6.0))


func test_a_segment_through_a_shape_is_blocked_and_one_beside_it_is_not() -> void:
	assert_true(_rect().blocks_segment(Vector2(60, 100), Vector2(140, 100)))
	assert_false(_rect().blocks_segment(Vector2(60, 130), Vector2(140, 130)))
	assert_true(_circle().blocks_segment(Vector2(160, 100), Vector2(240, 100)))
	assert_false(_circle().blocks_segment(Vector2(160, 120), Vector2(240, 120)))


func test_a_segment_ending_inside_a_shape_is_blocked() -> void:
	assert_true(_rect().blocks_segment(Vector2(60, 100), Vector2(100, 100)))
	assert_true(_circle().blocks_segment(Vector2(160, 100), Vector2(200, 100)))


func test_a_segment_entirely_inside_is_blocked() -> void:
	assert_true(_rect().blocks_segment(Vector2(95, 100), Vector2(105, 100)))
	assert_true(_circle().blocks_segment(Vector2(198, 100), Vector2(202, 100)))


func test_bounds_cover_the_shape() -> void:
	assert_eq(_rect().bounds(), Rect2(80, 90, 40, 20))
	assert_eq(_circle().bounds(), Rect2(190, 90, 20, 20))


func test_is_valid_rejects_zero_sizes() -> void:
	assert_true(_rect().is_valid())
	assert_true(_circle().is_valid())
	var flat := _rect()
	flat.size = Vector2(40, 0)
	assert_false(flat.is_valid())
	var empty := _circle()
	empty.radius = 0.0
	assert_false(empty.is_valid())


func test_a_grown_segment_test_catches_a_near_miss() -> void:
	# The rect spans x 80 to 120, y 90 to 110. A segment 4 px above it misses it exactly but not when grown by 6.
	assert_false(_rect().blocks_segment(Vector2(60, 86), Vector2(140, 86)))
	assert_true(_rect().blocks_segment(Vector2(60, 86), Vector2(140, 86), 6.0))
	assert_false(_rect().blocks_segment(Vector2(60, 80), Vector2(140, 80), 6.0), "10 px away is still clear")
	# The circle (centre (200, 100), radius 10): a segment 14 px above the centre.
	assert_false(_circle().blocks_segment(Vector2(160, 86), Vector2(240, 86)))
	assert_true(_circle().blocks_segment(Vector2(160, 86), Vector2(240, 86), 6.0))
