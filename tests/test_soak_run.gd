extends GutTest
## The soak maths: samples of node, object, orphan and memory counts taken each round, and a verdict that a run stayed flat.


func _samples(nodes: Array, orphans: Array = []) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for i in nodes.size():
		found.append({"round": i, "nodes": float(nodes[i]), "objects": float(nodes[i]) * 3.0, "orphans": float(orphans[i]) if i < orphans.size() else 0.0, "static_mb": 100.0})
	return found


func test_slope_of_a_flat_series_is_zero() -> void:
	assert_almost_eq(SoakRun.trend_slope([5.0, 5.0, 5.0, 5.0] as Array[float]), 0.0, 0.0001)


func test_slope_of_a_rising_series_is_positive() -> void:
	assert_almost_eq(SoakRun.trend_slope([1.0, 2.0, 3.0, 4.0] as Array[float]), 1.0, 0.0001)


func test_slope_ignores_noise_around_a_flat_line() -> void:
	assert_lt(absf(SoakRun.trend_slope([100.0, 102.0, 99.0, 101.0, 100.0, 98.0, 101.0, 100.0] as Array[float])), 0.5)


func test_verdict_passes_a_flat_run() -> void:
	var verdict := SoakRun.verdict(_samples([1000, 1005, 998, 1002, 1001, 999, 1003, 1000]), 2, 0.1)
	assert_true(verdict["ok"], str(verdict["problems"]))


func test_verdict_fails_a_growing_run() -> void:
	var nodes := []
	var value := 1000.0
	for i in 8:
		nodes.append(value)
		value *= 1.05
	var verdict := SoakRun.verdict(_samples(nodes), 2, 0.1)
	assert_false(verdict["ok"])
	assert_gt((verdict["problems"] as PackedStringArray).size(), 0)


func test_verdict_fails_a_slow_steady_climb_even_inside_the_band() -> void:
	var nodes := []
	for i in 12:
		nodes.append(1000.0 + i * 8.0)
	var verdict := SoakRun.verdict(_samples(nodes), 2, 0.2)
	assert_false(verdict["ok"], "a steady climb is a leak even while it is inside the band")


func test_verdict_fails_when_orphans_grow() -> void:
	var verdict := SoakRun.verdict(_samples([1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000], [0, 0, 0, 2, 5, 9, 14, 20]), 2, 0.1)
	assert_false(verdict["ok"])


func test_verdict_ignores_the_warmup_rounds() -> void:
	var verdict := SoakRun.verdict(_samples([3000, 2000, 1000, 1002, 999, 1001, 1000, 998]), 2, 0.1)
	assert_true(verdict["ok"], str(verdict["problems"]))


func test_verdict_needs_enough_samples() -> void:
	var verdict := SoakRun.verdict(_samples([1000, 1000, 1000]), 2, 0.1)
	assert_false(verdict["ok"], "too few samples is a failure, not a pass")


func test_take_reads_real_monitors() -> void:
	var sample := SoakRun.take(3)
	assert_eq(sample["round"], 3)
	for key in ["nodes", "objects", "static_mb"]:
		assert_gt(float(sample[key]), 0.0, key)
	assert_true(sample.has("orphans"))


func test_a_looser_slope_limit_accepts_a_slow_climb_that_the_default_rejects() -> void:
	var nodes := []
	for i in 12:
		nodes.append(1000.0 + i * 8.0)
	assert_false(SoakRun.verdict(_samples(nodes), 2, 0.2)["ok"])
	assert_true(SoakRun.verdict(_samples(nodes), 2, 0.2, 0.02)["ok"], "the short suite run uses a looser limit")


func test_one_late_blip_does_not_trip_a_loose_limit_but_a_real_climb_still_does() -> void:
	assert_true(SoakRun.verdict(_samples([757, 757, 757, 757, 757, 757, 757, 766]), 3, 0.5, 0.02)["ok"])
	var climbing := []
	for i in 8:
		climbing.append(757.0 + i * 60.0)
	assert_false(SoakRun.verdict(_samples(climbing), 3, 0.5, 0.02)["ok"])
