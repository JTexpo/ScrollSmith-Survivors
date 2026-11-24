extends GutTest
## The strike points of a lightning attack: the first on the centre (the player's spot), the rest seeded within the spread, all inside the
## arena and not stacked on one spot.

const BOUNDS := Rect2(0, 0, 960, 540)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_the_first_point_is_the_centre() -> void:
	var points := LightningPlan.points(Vector2(400, 300), 5, 70.0, 28.0, BOUNDS, _rng(1))
	assert_eq(points.size(), 5)
	assert_eq(points[0], Vector2(400, 300))


func test_the_first_point_is_clamped_into_the_bounds() -> void:
	var points := LightningPlan.points(Vector2(-50, 900), 3, 70.0, 28.0, BOUNDS, _rng(1))
	assert_eq(points[0], Vector2(0, 540))


func test_every_point_is_inside_the_bounds_and_within_the_spread() -> void:
	for seed_value in 60:
		for centre in [Vector2(5, 5), Vector2(955, 535), Vector2(480, 270), Vector2(10, 530)]:
			var points := LightningPlan.points(centre, 7, 76.0, 26.0, BOUNDS, _rng(seed_value))
			var anchor: Vector2 = centre.clamp(BOUNDS.position, BOUNDS.end)
			for point in points:
				assert_true(BOUNDS.grow(0.001).has_point(point), "%s is inside the arena" % point)
				assert_lte(point.distance_to(anchor), 76.0 + 0.001, "%s is within the spread of %s" % [point, anchor])


func test_points_are_deterministic_for_a_seed() -> void:
	assert_eq(LightningPlan.points(Vector2(400, 300), 5, 70.0, 28.0, BOUNDS, _rng(9)), LightningPlan.points(Vector2(400, 300), 5, 70.0, 28.0, BOUNDS, _rng(9)))


func test_points_do_not_stack_on_one_spot() -> void:
	var spread_out := 0
	for seed_value in 200:
		var points := LightningPlan.points(Vector2(480, 270), 5, 70.0, 28.0, BOUNDS, _rng(seed_value))
		var apart := true
		for i in points.size():
			for j in range(i + 1, points.size()):
				if points[i].distance_to(points[j]) < 28.0:
					apart = false
		if apart:
			spread_out += 1
	assert_gte(spread_out, 190, "at least 95% of seeds keep every pair of strikes 28 px apart")


func test_a_count_of_zero_or_less_gives_no_points() -> void:
	assert_true(LightningPlan.points(Vector2(400, 300), 0, 70.0, 28.0, BOUNDS, _rng(1)).is_empty())
	assert_true(LightningPlan.points(Vector2(400, 300), -3, 70.0, 28.0, BOUNDS, _rng(1)).is_empty())


func test_a_count_of_one_gives_only_the_centre() -> void:
	assert_eq(LightningPlan.points(Vector2(400, 300), 1, 70.0, 28.0, BOUNDS, _rng(1)), [Vector2(400, 300)] as Array[Vector2])
