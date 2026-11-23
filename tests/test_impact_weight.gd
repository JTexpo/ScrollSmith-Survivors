extends GutTest


func _spell(wait: float, damage: float) -> SpellData:
	var spell := SpellData.new()
	spell.cast_interval = wait
	spell.damage = damage
	return spell


func test_a_missing_spell_is_zero() -> void:
	assert_eq(ImpactWeight.of(null), 0.0)


func test_the_weight_is_between_zero_and_one() -> void:
	for wait in [0.0, 0.1, 0.3, 0.9, 1.5, 3.0, 99.0]:
		for damage in [0.0, 6.0, 20.0, 40.0, 500.0]:
			assert_between(ImpactWeight.of(_spell(wait, damage)), 0.0, 1.0, "%s %s" % [wait, damage])
	assert_eq(ImpactWeight.of(_spell(99.0, 500.0)), 1.0)
	assert_eq(ImpactWeight.of(_spell(0.0, 0.0)), 0.0)


func test_a_longer_wait_is_heavier() -> void:
	assert_gt(ImpactWeight.of(_spell(1.2, 10.0)), ImpactWeight.of(_spell(0.4, 10.0)))


func test_a_bigger_hit_is_heavier() -> void:
	assert_gt(ImpactWeight.of(_spell(0.5, 30.0)), ImpactWeight.of(_spell(0.5, 8.0)))


func test_a_slow_big_hit_is_heavier_than_a_fast_small_one() -> void:
	assert_gt(ImpactWeight.of(_spell(1.4, 35.0)), ImpactWeight.of(_spell(0.3, 6.0)) + 0.5)


func test_the_starting_spells_spread_out() -> void:
	var fire := ImpactWeight.of(load("res://resources/spells/fire_missile.tres") as SpellData)
	var wave := ImpactWeight.of(load("res://resources/spells/sea_wave.tres") as SpellData)
	assert_lt(fire, wave)


func test_a_custom_config_changes_the_weight() -> void:
	var spell := _spell(0.9, 20.0)
	var wide := ImpactConfig.new()
	var narrow := ImpactConfig.new()
	narrow.wait_max = 1.0
	narrow.damage_max = 25.0
	assert_gt(ImpactWeight.of(spell, narrow), ImpactWeight.of(spell, wide))


func test_the_wait_share_decides_which_counts_more() -> void:
	var config := ImpactConfig.new()
	config.wait_share = 1.0
	assert_eq(ImpactWeight.of(_spell(1.5, 6.0), config), 1.0)
	assert_eq(ImpactWeight.of(_spell(0.3, 40.0), config), 0.0)
	config.wait_share = 0.0
	assert_eq(ImpactWeight.of(_spell(0.3, 40.0), config), 1.0)


func test_impact_events_announce_a_hit() -> void:
	var heard := []
	var listen := func(at: Vector2, weight: float, element: StringName) -> void: heard.append([at, weight, element])
	ImpactEvents.bus.hit.connect(listen)
	ImpactEvents.bus.hit.emit(Vector2(1, 2), 0.5, &"fire")
	ImpactEvents.bus.hit.disconnect(listen)
	assert_eq(heard, [[Vector2(1, 2), 0.5, &"fire"]])


func test_a_damage_multiplier_makes_a_hit_heavier() -> void:
	var spell := _spell(0.5, 10.0)
	assert_gt(ImpactWeight.of(spell, null, 3.0), ImpactWeight.of(spell, null, 1.0), "a double-damage roll or a robe's bonus is a harder hit")
	assert_eq(ImpactWeight.of(spell, null, 1.0), ImpactWeight.of(spell))


func test_a_ticking_zone_is_light_because_it_hits_every_tick() -> void:
	var zone := load("res://resources/spells/land_area.tres") as SpellData
	assert_eq(zone.area_data.tick_interval, 0.5, "the Land spell is a Zone that ticks twice a second")
	assert_lt(ImpactWeight.of(zone), ImpactConfig.default_config().shake_from, "a Zone tick must not shake the screen")
