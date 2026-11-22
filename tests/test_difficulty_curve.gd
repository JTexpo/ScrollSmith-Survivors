extends GutTest

var _curve: DifficultyCurve


func before_each() -> void:
	_curve = DifficultyCurve.default_curve()


func after_each() -> void:
	GameTime.reset()


func test_scales_at_time_zero_are_one() -> void:
	assert_eq(_curve.health_scale(0.0), 1.0)
	assert_eq(_curve.damage_scale(0.0), 1.0)
	assert_eq(_curve.speed_scale(0.0), 1.0)


func test_health_damage_and_speed_scale_with_minutes() -> void:
	assert_almost_eq(_curve.health_scale(600.0), 2.2, 0.0001)
	assert_almost_eq(_curve.damage_scale(600.0), 1.6, 0.0001)
	assert_almost_eq(_curve.speed_scale(600.0), 1.2, 0.0001)
	assert_almost_eq(_curve.health_scale(60.0), 1.12, 0.0001)


func test_speed_scale_is_capped_at_plus_25_percent() -> void:
	assert_almost_eq(_curve.speed_scale(3600.0), 1.25, 0.0001)
	assert_almost_eq(_curve.speed_scale(1.0e6), 1.25, 0.0001)


func test_spawn_interval_shrinks_and_has_a_floor() -> void:
	assert_almost_eq(_curve.spawn_interval(0.0), 0.5, 0.0001)
	assert_almost_eq(_curve.spawn_interval(60.0), 0.5 / 1.15, 0.0001)
	assert_lt(_curve.spawn_interval(600.0), _curve.spawn_interval(60.0))
	assert_almost_eq(_curve.spawn_interval(1.0e6), 0.12, 0.0001)


func test_max_alive_grows_and_is_capped() -> void:
	assert_eq(_curve.max_alive(0.0), 150)
	assert_eq(_curve.max_alive(60.0), 170)
	assert_eq(_curve.max_alive(300.0), 250)
	assert_eq(_curve.max_alive(3600.0), 300)
	assert_eq(_curve.max_alive(1.0e6), 300)


func test_elite_chance_is_zero_until_120_seconds_then_rises_and_is_capped() -> void:
	assert_eq(_curve.elite_chance(0.0), 0.0)
	assert_eq(_curve.elite_chance(119.0), 0.0)
	assert_eq(_curve.elite_chance(120.0), 0.0)
	assert_almost_eq(_curve.elite_chance(180.0), 0.02, 0.0001)
	assert_almost_eq(_curve.elite_chance(420.0), 0.10, 0.0001)
	assert_almost_eq(_curve.elite_chance(3600.0), 0.2, 0.0001)
	assert_almost_eq(_curve.elite_chance(1.0e6), 0.2, 0.0001)


func test_negative_time_is_treated_as_zero() -> void:
	assert_eq(_curve.health_scale(-50.0), 1.0)
	assert_eq(_curve.speed_scale(-50.0), 1.0)
	assert_almost_eq(_curve.spawn_interval(-50.0), 0.5, 0.0001)
	assert_eq(_curve.max_alive(-50.0), 150)
	assert_eq(_curve.elite_chance(-50.0), 0.0)


func test_boss_scales() -> void:
	assert_eq(_curve.boss_health_scale(1), 1.0)
	assert_eq(_curve.boss_damage_scale(1), 1.0)
	assert_almost_eq(_curve.boss_health_scale(3), 2.0, 0.0001)
	assert_almost_eq(_curve.boss_damage_scale(3), 1.4, 0.0001)
	assert_eq(_curve.boss_health_scale(0), 1.0)
	assert_eq(_curve.boss_damage_scale(-4), 1.0)


func test_default_curve_loads_with_the_spec_numbers() -> void:
	assert_not_null(_curve)
	assert_almost_eq(_curve.health_per_minute, 0.12, 0.0001)
	assert_almost_eq(_curve.damage_per_minute, 0.06, 0.0001)
	assert_almost_eq(_curve.speed_per_minute, 0.02, 0.0001)
	assert_almost_eq(_curve.speed_cap, 0.25, 0.0001)
	assert_almost_eq(_curve.base_interval, 0.5, 0.0001)
	assert_almost_eq(_curve.interval_rate, 0.15, 0.0001)
	assert_almost_eq(_curve.min_interval, 0.12, 0.0001)
	assert_eq(_curve.base_max_alive, 150)
	assert_almost_eq(_curve.max_alive_per_minute, 20.0, 0.0001)
	assert_eq(_curve.max_alive_cap, 300)
	assert_almost_eq(_curve.elite_start_seconds, 120.0, 0.0001)
	assert_almost_eq(_curve.elite_per_minute, 0.02, 0.0001)
	assert_almost_eq(_curve.elite_cap, 0.2, 0.0001)
	assert_almost_eq(_curve.boss_health_per_extra, 0.5, 0.0001)
	assert_almost_eq(_curve.boss_damage_per_extra, 0.2, 0.0001)


func test_boss_interval_is_300_seconds() -> void:
	assert_almost_eq(_curve.boss_interval_seconds, 300.0, 0.0001)


func test_run_clock_follows_game_time_and_freezes_with_it() -> void:
	GameTime.reset()
	assert_lt(RunClock.seconds(), 0.2)
	await wait_seconds(0.15)
	var running := RunClock.seconds()
	assert_gt(running, 0.1)
	GameTime.freeze()
	var frozen := RunClock.seconds()
	await wait_seconds(0.15)
	assert_eq(RunClock.seconds(), frozen)
	GameTime.unfreeze()
	await wait_seconds(0.12)
	assert_gt(RunClock.seconds(), frozen + 0.05)
	GameTime.reset()
	assert_lt(RunClock.seconds(), 0.2)
