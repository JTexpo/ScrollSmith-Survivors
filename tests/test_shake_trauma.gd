extends GutTest


func test_add_caps_at_one() -> void:
	var trauma := ShakeTrauma.new()
	assert_true(trauma.add(0.7, 0, 80))
	assert_true(trauma.add(0.7, 1000, 80))
	assert_eq(trauma.value(), 1.0)


func test_the_gap_refuses_a_second_add_too_soon() -> void:
	var trauma := ShakeTrauma.new()
	assert_true(trauma.add(0.4, 100, 80))
	assert_false(trauma.add(0.4, 150, 80))
	assert_almost_eq(trauma.value(), 0.4, 0.0001)
	assert_true(trauma.add(0.4, 180, 80))
	assert_almost_eq(trauma.value(), 0.8, 0.0001)


func test_decay_falls_to_zero_and_not_below() -> void:
	var trauma := ShakeTrauma.new()
	trauma.add(1.0, 0, 80)
	trauma.decay(0.2)
	assert_lt(trauma.value(), 1.0)
	trauma.decay(5.0)
	assert_eq(trauma.value(), 0.0)


func test_the_offset_is_whole_pixels_and_never_above_the_cap() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for weight in [0.0, 0.5, 1.0]:
		var trauma := ShakeTrauma.new()
		trauma.add(weight, 0, 80)
		for i in 200:
			var offset := trauma.offset_px(4.0, 1.0, rng)
			assert_eq(offset, offset.round(), "whole pixels")
			assert_lte(absf(offset.x), 4.0)
			assert_lte(absf(offset.y), 4.0)


func test_full_trauma_can_reach_the_cap_and_none_gives_no_shake() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var full := ShakeTrauma.new()
	full.add(1.0, 0, 80)
	var biggest := 0.0
	for i in 400:
		var offset := full.offset_px(4.0, 1.0, rng)
		biggest = maxf(biggest, maxf(absf(offset.x), absf(offset.y)))
	assert_eq(biggest, 4.0, "full trauma reaches the designed maximum")
	var none := ShakeTrauma.new()
	assert_eq(none.offset_px(4.0, 1.0, rng), Vector2.ZERO)


func test_scale_zero_gives_no_offset_and_scale_above_one_is_held_to_the_cap() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var trauma := ShakeTrauma.new()
	trauma.add(1.0, 0, 80)
	for i in 50:
		assert_eq(trauma.offset_px(4.0, 0.0, rng), Vector2.ZERO)
		var big := trauma.offset_px(4.0, 5.0, rng)
		assert_lte(absf(big.x), 4.0, "comfort: a scale above 1 never exceeds the designed maximum")
		assert_lte(absf(big.y), 4.0)
