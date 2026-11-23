extends GutTest


func test_the_default_config_loads_with_the_pinned_numbers() -> void:
	var config := ImpactConfig.default_config()
	assert_not_null(config)
	assert_eq(config.wait_min, 0.3)
	assert_eq(config.wait_max, 1.5)
	assert_eq(config.damage_min, 6.0)
	assert_eq(config.damage_max, 40.0)
	assert_eq(config.wait_share, 0.6)
	assert_eq(config.shake_from, 0.35)
	assert_eq(config.flash_from, 0.5)
	assert_eq(config.shake_max_px, 4.0)
	assert_eq(config.flash_max_alpha, 0.12)
	assert_eq(config.flash_seconds, 0.08)
	assert_eq(config.shake_gap_msec, 80)
	assert_eq(config.flash_gap_msec, 330)
	assert_eq(config.particles_light, 3)
	assert_eq(config.particles_heavy, 24)
	assert_eq(config.sound_pitch_drop, 0.25)
	assert_eq(config.sound_volume_up_db, 4.0)
	assert_eq(config.health_beat_from, 0.5)
	assert_eq(config.health_warn_from, 0.3)
	assert_eq(config.warn_max_alpha, 0.4)
	assert_eq(config.warn_rate_low, 0.8)
	assert_eq(config.warn_rate_high, 2.0)
	assert_eq(config.beat_rate_slow, 0.5)


func test_the_comfort_limits_hold() -> void:
	var config := ImpactConfig.default_config()
	assert_lte(config.shake_max_px, 4.0)
	assert_lte(config.flash_max_alpha, 0.12)
	assert_lte(config.warn_max_alpha, 0.4)
	assert_lte(config.warn_rate_high, 2.0)
	assert_gte(config.flash_gap_msec, 330, "no more than about three flashes a second")
	assert_lt(config.health_warn_from, config.health_beat_from)


func test_fx_settings_default_to_one_and_reset() -> void:
	FxSettings.reset()
	assert_eq(FxSettings.shake_scale, 1.0)
	assert_eq(FxSettings.flash_scale, 1.0)
	FxSettings.shake_scale = 0.0
	FxSettings.flash_scale = 0.5
	FxSettings.reset()
	assert_eq(FxSettings.shake_scale, 1.0)
	assert_eq(FxSettings.flash_scale, 1.0)
