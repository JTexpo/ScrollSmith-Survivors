extends GutTest

const K := LevelReward.Kind

var _track: LevelTrack


func before_each() -> void:
	_track = LevelTrack.default_track()


func test_curve_matches_the_spec() -> void:
	assert_eq(_track.max_level(), 20)
	assert_eq(_track.xp_for_level(0), 0)
	assert_eq(_track.xp_for_level(1), 0)
	assert_eq(_track.xp_for_level(2), 30)
	assert_eq(_track.xp_for_level(3), 80)
	assert_eq(_track.xp_for_level(4), 150)
	assert_eq(_track.xp_for_level(20), 3990)
	assert_eq(_track.xp_for_level(99), 3990)


func test_level_for_xp_boundaries() -> void:
	assert_eq(_track.level_for_xp(-5), 1)
	assert_eq(_track.level_for_xp(0), 1)
	assert_eq(_track.level_for_xp(29), 1)
	assert_eq(_track.level_for_xp(30), 2)
	assert_eq(_track.level_for_xp(79), 2)
	assert_eq(_track.level_for_xp(80), 3)
	assert_eq(_track.level_for_xp(3989), 19)
	assert_eq(_track.level_for_xp(3990), 20)
	assert_eq(_track.level_for_xp(1000000), 20)


func test_progress_and_xp_to_next() -> void:
	assert_eq(_track.progress(0), 0.0)
	assert_almost_eq(_track.progress(55), 0.5, 0.0001)
	assert_eq(_track.xp_into_level(55), 25)
	assert_eq(_track.xp_to_next(55), 25)
	assert_eq(_track.progress(3990), 1.0)
	assert_eq(_track.progress(5000), 1.0)
	assert_eq(_track.xp_to_next(5000), 0)


func test_rewards_table_matches_the_spec() -> void:
	var expected := {
		2: [K.SPEED, 0.08, 0], 3: [K.HEALTH, 0.20, 0], 4: [K.MANA, 0.15, 0], 5: [K.SLOT, 0.0, 0],
		6: [K.SPEED, 0.08, 0], 7: [K.RANDOM_BUFF, 0.0, 0], 8: [K.HEALTH, 0.20, 0],
		9: [K.MANA, 0.15, 0], 10: [K.SLOT, 0.0, 0], 11: [K.SPEED, 0.08, 0],
		12: [K.CHOSEN_BUFF, 0.0, 0], 13: [K.HEALTH, 0.20, 0], 14: [K.SECOND_SPELL, 0.0, 0],
		15: [K.SLOT, 0.0, 0], 16: [K.SPEED, 0.08, 0], 17: [K.RANDOM_BUFF, 0.0, 1],
		18: [K.HEALTH, 0.20, 0], 19: [K.CHOSEN_BUFF, 0.0, 1], 20: [K.SLOT, 0.0, 0],
	}
	assert_eq(_track.rewards.size(), 19)
	for level in expected:
		var reward := _track.reward_for_level(level)
		assert_not_null(reward, "level %d" % level)
		assert_eq(reward.kind, expected[level][0], "kind at level %d" % level)
		assert_almost_eq(reward.amount, expected[level][1], 0.0001, "amount at level %d" % level)
		assert_eq(reward.spell_index, expected[level][2], "spell at level %d" % level)
		assert_false(reward.description.is_empty(), "description at level %d" % level)
	assert_null(_track.reward_for_level(1))
	assert_null(_track.reward_for_level(21))
	assert_null(_track.reward_for_level(0))


func test_slot_count_per_level() -> void:
	for level in range(1, 5):
		assert_eq(_track.slot_count(level), 1)
	assert_eq(_track.slot_count(5), 2)
	assert_eq(_track.slot_count(9), 2)
	assert_eq(_track.slot_count(10), 3)
	assert_eq(_track.slot_count(15), 4)
	assert_eq(_track.slot_count(20), 5)


func test_stat_sums() -> void:
	assert_almost_eq(_track.stat_sum(K.SPEED, 20), 0.32, 0.0001)
	assert_almost_eq(_track.stat_sum(K.HEALTH, 20), 0.80, 0.0001)
	assert_almost_eq(_track.stat_sum(K.MANA, 20), 0.30, 0.0001)
	assert_eq(_track.stat_sum(K.SPEED, 1), 0.0)
	assert_eq(_track.stat_sum(K.HEALTH, 1), 0.0)
	assert_eq(_track.stat_sum(K.MANA, 1), 0.0)


func test_buff_pool_has_five_buffs_and_no_additional_base() -> void:
	assert_eq(_track.buff_pool.size(), 5)
	for scroll in _track.buff_pool:
		assert_eq(scroll.category, ScrollData.Category.BUFF)
		assert_not_null(scroll.buff)
		assert_eq(scroll.buff.extra_bases, 0)


func test_second_spell_is_sea_cone_with_a_generous_pool() -> void:
	var reward := _track.reward_for_level(14)
	assert_not_null(reward.spell)
	assert_eq(reward.spell.display_name, "Sea Cone")
	assert_eq(reward.spell.max_mana, 1000.0)


func test_sea_cone_matches_the_builder_except_the_pool() -> void:
	var rules := CraftingRules.default_rules()
	var sea := load("res://resources/scrolls/base/sea.tres") as ScrollData
	var cone := load("res://resources/scrolls/area/cone.tres") as ScrollData
	var built := SpellBuilder.build([sea], cone, rules.option(rules.normal_index()))
	var starting := load("res://resources/spells/sea_cone.tres") as SpellData
	assert_eq(starting.id, &"sea_cone")
	assert_eq(starting.damage, built.damage)
	assert_eq(starting.cast_interval, built.cast_interval)
	assert_eq(starting.mana_cost, built.mana_cost)
	assert_eq(starting.projectile_speed, built.projectile_speed)
	assert_eq(starting.knockback, built.knockback)
	assert_eq(starting.max_hits, built.max_hits)
	assert_eq(starting.elements, built.elements)
	assert_eq(starting.color, built.color)
	assert_eq(starting.area_type(), built.area_type())


func test_every_archetype_has_xp_and_gold_rewards() -> void:
	var expected := {
		"standard": [5, 1], "swarmer": [2, 1], "chaser": [5, 1], "tank": [12, 3],
		"ranged": [7, 2], "exploder": [6, 1], "support": [8, 2],
	}
	for name in expected:
		var archetype := load("res://resources/enemies/archetypes/%s.tres" % name) as EnemyArchetype
		assert_eq(archetype.xp_reward, expected[name][0], "%s xp" % name)
		assert_eq(archetype.gold_reward, expected[name][1], "%s gold" % name)
