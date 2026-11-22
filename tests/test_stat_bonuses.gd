extends GutTest

const S := StatBonuses.Stat


func test_damage_stat_maps_the_four_elements() -> void:
	assert_eq(StatBonuses.damage_stat(SpellData.Element.FIRE), S.DAMAGE_FIRE)
	assert_eq(StatBonuses.damage_stat(SpellData.Element.THUNDER), S.DAMAGE_THUNDER)
	assert_eq(StatBonuses.damage_stat(SpellData.Element.LAND), S.DAMAGE_LAND)
	assert_eq(StatBonuses.damage_stat(SpellData.Element.SEA), S.DAMAGE_SEA)


func test_damage_stat_is_minus_one_for_none_and_unknown() -> void:
	assert_eq(StatBonuses.damage_stat(SpellData.NO_ELEMENT), -1)
	assert_eq(StatBonuses.damage_stat(99), -1)


func test_new_stats_default_to_zero() -> void:
	var bonuses := StatBonuses.new()
	for stat in [S.DAMAGE_FIRE, S.DAMAGE_THUNDER, S.DAMAGE_LAND, S.DAMAGE_SEA, S.SPELL_DAMAGE,
			S.CAST_SPEED, S.CAST_TWICE_CHANCE, S.DOUBLE_DAMAGE_CHANCE]:
		assert_eq(bonuses.fraction(stat), 0.0)
		assert_eq(bonuses.multiplier(stat), 1.0)


func test_enum_order_keeps_the_sprint_8_values() -> void:
	assert_eq(S.SPEED, 0)
	assert_eq(S.HEALTH, 1)
	assert_eq(S.SPELL_MANA, 2)
	assert_eq(S.DOUBLE_DAMAGE_CHANCE, 10)


func test_combined_adds_every_stat_and_changes_neither_input() -> void:
	var first := StatBonuses.new()
	first.add(S.SPEED, 0.08)
	first.add(S.DAMAGE_FIRE, 0.1)
	var second := StatBonuses.new()
	second.add(S.SPEED, 0.10)
	second.add(S.CAST_SPEED, 0.25)
	var both := StatBonuses.combined(first, second)
	assert_almost_eq(both.fraction(S.SPEED), 0.18, 0.0001)
	assert_almost_eq(both.fraction(S.DAMAGE_FIRE), 0.1, 0.0001)
	assert_almost_eq(both.fraction(S.CAST_SPEED), 0.25, 0.0001)
	assert_almost_eq(first.fraction(S.SPEED), 0.08, 0.0001)
	assert_eq(first.fraction(S.CAST_SPEED), 0.0)
	assert_almost_eq(second.fraction(S.SPEED), 0.10, 0.0001)
	assert_eq(second.fraction(S.DAMAGE_FIRE), 0.0)


func test_add_all_adds_into_this_object() -> void:
	var target := StatBonuses.new()
	target.add(S.HEALTH, 0.2)
	var other := StatBonuses.new()
	other.add(S.HEALTH, 0.3)
	other.add(S.SPELL_DAMAGE, -0.15)
	target.add_all(other)
	assert_almost_eq(target.fraction(S.HEALTH), 0.5, 0.0001)
	assert_almost_eq(target.fraction(S.SPELL_DAMAGE), -0.15, 0.0001)
	assert_almost_eq(other.fraction(S.HEALTH), 0.3, 0.0001)


func test_combined_with_empty_bonuses_is_a_copy() -> void:
	var first := StatBonuses.new()
	first.add(S.SPEED, 0.32)
	var copy := StatBonuses.combined(first, StatBonuses.new())
	assert_almost_eq(copy.fraction(S.SPEED), 0.32, 0.0001)


func test_luck_is_the_last_stat_and_defaults_to_zero() -> void:
	assert_eq(S.LUCK, 11)
	assert_eq(S.DOUBLE_DAMAGE_CHANCE, 10)
	assert_eq(StatBonuses.new().fraction(S.LUCK), 0.0)
	assert_eq(StatBonuses.new().multiplier(S.LUCK), 1.0)
