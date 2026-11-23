extends GutTest



func _rectangle() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, 120), Vector2(0, 120)])


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_count_follows_the_area_within_the_limits() -> void:
	assert_eq(EffectPlan.count_for(0.0), EffectPlan.MIN_SPRITES)
	assert_eq(EffectPlan.count_for(6000.0), 10)
	assert_eq(EffectPlan.count_for(1.0e9), EffectPlan.MAX_SPRITES)
	assert_eq(EffectPlan.MIN_SPRITES, 3)
	assert_eq(EffectPlan.MAX_SPRITES, 24)


func test_spots_are_inside_the_polygon_and_deterministic() -> void:
	var triangle := PackedVector2Array([Vector2(0, 0), Vector2(120, 20), Vector2(30, 90)])
	var spots := EffectPlan.spots(triangle, 10, _rng(4))
	assert_eq(spots.size(), 10)
	for spot in spots:
		assert_true(Geometry2D.is_point_in_polygon(spot, triangle), "%s is inside" % spot)
	assert_eq(EffectPlan.spots(triangle, 10, _rng(4)), spots, "the same seed gives the same spots")
	assert_ne(EffectPlan.spots(triangle, 10, _rng(5)), spots)


func test_spots_are_spread_out_not_clumped() -> void:
	var spots := EffectPlan.spots(_rectangle(), 12, _rng(2))
	assert_eq(spots.size(), 12)
	var closest := INF
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			closest = minf(closest, spots[i].distance_to(spots[j]))
	assert_gt(closest, 15.0, "no two effect sprites sit on top of each other")


func test_a_degenerate_polygon_gives_no_spots() -> void:
	assert_eq(EffectPlan.spots(PackedVector2Array(), 5, _rng()).size(), 0)
	assert_eq(EffectPlan.spots(PackedVector2Array([Vector2(1, 1), Vector2(5, 5)]), 5, _rng()).size(), 0)
	assert_eq(EffectPlan.spots(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(20, 0)]), 5, _rng()).size(), 0, "a flat polygon has no room")
	assert_eq(EffectPlan.spots(_rectangle(), 0, _rng()).size(), 0)


func test_rising_delays_start_nearest_the_origin_first() -> void:
	var spots := EffectPlan.spots(_rectangle(), 12, _rng(3))
	var delays := EffectPlan.delays(spots, true, Vector2.ZERO, 0.4, _rng())
	assert_eq(delays.size(), spots.size())
	var order: Array = range(spots.size())
	order.sort_custom(func(a: int, b: int) -> bool: return spots[a].length() < spots[b].length())
	for k in range(1, order.size()):
		assert_gte(delays[order[k]], delays[order[k - 1]], "a farther spot never starts before a nearer one")


func test_falling_delays_are_in_range_and_not_ordered_by_distance() -> void:
	var spots := EffectPlan.spots(_rectangle(), 12, _rng(3))
	var delays := EffectPlan.delays(spots, false, Vector2.ZERO, 0.4, _rng(9))
	var ordered_by_distance := true
	var order: Array = range(spots.size())
	order.sort_custom(func(a: int, b: int) -> bool: return spots[a].length() < spots[b].length())
	for k in range(1, order.size()):
		if delays[order[k]] < delays[order[k - 1]]:
			ordered_by_distance = false
	assert_false(ordered_by_distance, "falling effects land in a random order")
	assert_eq(EffectPlan.delays(spots, false, Vector2.ZERO, 0.4, _rng(9)), delays, "and the same seed gives the same order")


func test_every_delay_is_within_the_window() -> void:
	var spots := EffectPlan.spots(_rectangle(), 12, _rng(3))
	for rises in [true, false]:
		for delay in EffectPlan.delays(spots, rises, Vector2(10, 10), 0.4, _rng()):
			assert_gte(delay, 0.0)
			assert_lte(delay, 0.4)
	assert_eq(EffectPlan.delays([] as Array[Vector2], true, Vector2.ZERO, 0.4, _rng()).size(), 0)
