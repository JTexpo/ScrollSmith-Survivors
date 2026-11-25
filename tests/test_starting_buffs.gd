extends GutTest

const ScrollHelpers := preload("res://tests/helpers/scroll_helpers.gd")

const K := LevelReward.Kind

var _track: LevelTrack
var _buffs: RunBuffs


func before_each() -> void:
	_track = LevelTrack.default_track()
	_buffs = RunBuffs.new()


func _reward(kind: LevelReward.Kind, spell_index: int) -> LevelReward:
	var reward := LevelReward.new()
	reward.kind = kind
	reward.spell_index = spell_index
	return reward


func _custom_track(pool: Array[ScrollData], rewards: Array[LevelReward]) -> LevelTrack:
	var track := LevelTrack.new()
	track.buff_pool = pool
	track.rewards = rewards
	return track


func test_unresolved_levels_list_reached_rewards_without_picks() -> void:
	_buffs.set_pick(7, &"buff_damage")
	assert_eq(StartingBuffs.unresolved_levels(_buffs, _track, 12, K.CHOSEN_BUFF), [12] as Array[int])
	assert_eq(StartingBuffs.unresolved_levels(_buffs, _track, 12, K.RANDOM_BUFF), [] as Array[int])
	assert_eq(StartingBuffs.unresolved_levels(_buffs, _track, 6, K.RANDOM_BUFF), [] as Array[int])
	assert_eq(StartingBuffs.unresolved_levels(_buffs, _track, 19, K.CHOSEN_BUFF), [12, 19] as Array[int])
	assert_eq(StartingBuffs.unresolved_levels(_buffs, _track, 99, K.RANDOM_BUFF), [17] as Array[int])


func test_roll_random_rolls_once_and_stores_the_pick() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var rolled := StartingBuffs.roll_random(_buffs, _track, 17, rng)
	assert_eq(rolled, [7, 17] as Array[int])
	assert_ne(_buffs.pick(7), &"")
	assert_ne(_buffs.pick(17), &"")
	assert_eq(StartingBuffs.roll_random(_buffs, _track, 17, rng), [] as Array[int])
	assert_eq(StartingBuffs.roll_random(_buffs, _track, 6, rng), [] as Array[int])


func test_roll_random_picks_only_from_the_pool() -> void:
	var ids: Array[StringName] = []
	for scroll in _track.buff_pool:
		ids.append(scroll.id)
	for seed_value in 20:
		var run_buffs := RunBuffs.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		StartingBuffs.roll_random(run_buffs, _track, 17, rng)
		assert_true(ids.has(run_buffs.pick(7)))
		assert_true(ids.has(run_buffs.pick(17)))


func test_roll_random_with_a_seeded_rng_is_deterministic() -> void:
	var first := RunBuffs.new()
	var second := RunBuffs.new()
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	StartingBuffs.roll_random(first, _track, 17, rng_a)
	StartingBuffs.roll_random(second, _track, 17, rng_b)
	assert_eq(first.pick(7), second.pick(7))
	assert_eq(first.pick(17), second.pick(17))


func test_options_exclude_buffs_at_their_stack_cap() -> void:
	var capped := ScrollHelpers.buff_scroll("ignore_resistance")
	assert_eq(capped.buff.max_stacks, 1)
	_buffs.set_pick(7, capped.id)
	var first_spell := StartingBuffs.options_for(_buffs, _track, 12)
	assert_eq(first_spell.size(), 4)
	assert_false(first_spell.has(capped))
	var second_spell := StartingBuffs.options_for(_buffs, _track, 19)
	assert_eq(second_spell.size(), 5)
	assert_true(second_spell.has(capped))


func test_uncapped_buffs_stay_available_after_being_picked() -> void:
	var damage := ScrollHelpers.buff_scroll("damage")
	_buffs.set_pick(7, damage.id)
	assert_true(StartingBuffs.options_for(_buffs, _track, 12).has(damage))


func test_options_for_a_level_with_no_buff_reward_is_empty() -> void:
	assert_true(StartingBuffs.options_for(_buffs, _track, 5).is_empty())
	assert_true(StartingBuffs.options_for(_buffs, _track, 1).is_empty())
	assert_true(StartingBuffs.options_for(_buffs, _track, 40).is_empty())


func test_no_options_leaves_the_reward_unresolved_without_error() -> void:
	var capped := ScrollHelpers.buff_scroll("ignore_resistance")
	var track := _custom_track([capped] as Array[ScrollData], [_reward(K.RANDOM_BUFF, 0), _reward(K.RANDOM_BUFF, 0)] as Array[LevelReward])
	var rng := RandomNumberGenerator.new()
	var rolled := StartingBuffs.roll_random(_buffs, track, 3, rng)
	assert_eq(rolled, [2] as Array[int])
	assert_eq(_buffs.pick(2), capped.id)
	assert_eq(_buffs.pick(3), &"")
	assert_true(StartingBuffs.options_for(_buffs, track, 3).is_empty())
	assert_eq(StartingBuffs.unresolved_levels(_buffs, track, 3, K.RANDOM_BUFF), [3] as Array[int])


func test_buffs_for_spell_separates_the_two_spells() -> void:
	_buffs.set_pick(7, &"buff_damage")
	_buffs.set_pick(12, &"buff_max_mana")
	_buffs.set_pick(17, &"buff_duplicate_area")
	var first := StartingBuffs.buffs_for_spell(_buffs, _track, 20, 0)
	var second := StartingBuffs.buffs_for_spell(_buffs, _track, 20, 1)
	assert_eq(first.size(), 2)
	assert_eq(first[0].id, &"buff_damage")
	assert_eq(first[1].id, &"buff_max_mana")
	assert_eq(second.size(), 1)
	assert_eq(second[0].id, &"buff_duplicate_area")


func test_buffs_for_spell_only_counts_rewards_reached() -> void:
	_buffs.set_pick(7, &"buff_damage")
	_buffs.set_pick(12, &"buff_max_mana")
	assert_eq(StartingBuffs.buffs_for_spell(_buffs, _track, 11, 0).size(), 1)
	assert_eq(StartingBuffs.buffs_for_spell(_buffs, _track, 6, 0).size(), 0)


func test_unknown_buff_ids_are_skipped() -> void:
	_buffs.set_pick(7, &"buff_that_was_removed")
	_buffs.set_pick(12, &"buff_damage")
	var buffs := StartingBuffs.buffs_for_spell(_buffs, _track, 12, 0)
	assert_eq(buffs.size(), 1)
	assert_eq(buffs[0].id, &"buff_damage")
