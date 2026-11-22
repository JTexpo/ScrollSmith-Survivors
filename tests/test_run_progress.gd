extends GutTest

const K := LevelReward.Kind

var _root: Node2D
var _player: Player
var _profile: PlayerProfile
var _track: LevelTrack
var _progress: RunProgress


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_track = LevelTrack.default_track()
	_profile = PlayerProfile.new()
	_progress = _player.progress
	_progress.bind(_player, _profile, _track)


func _speed() -> float:
	return (_player.get_node("MoveComponent") as MoveComponent).speed


func test_add_xp_below_threshold_changes_no_level() -> void:
	watch_signals(_progress)
	_progress.add_xp(29)
	assert_eq(_progress.level(), 1)
	assert_signal_not_emitted(_progress, "leveled_up")
	assert_signal_emitted_with_parameters(_progress, "xp_changed", [29, 1])


func test_crossing_a_threshold_emits_leveled_up_with_its_reward() -> void:
	watch_signals(_progress)
	_progress.add_xp(30)
	assert_eq(_progress.level(), 2)
	assert_signal_emit_count(_progress, "leveled_up", 1)
	var params = get_signal_parameters(_progress, "leveled_up")
	assert_eq(params[0], 2)
	assert_eq((params[1] as LevelReward).kind, K.SPEED)
	assert_almost_eq(_speed(), 97.2, 0.001)


func test_one_big_gain_applies_every_reward_once_in_order() -> void:
	var levels: Array[int] = []
	_progress.leveled_up.connect(func(level: int, _reward: LevelReward) -> void: levels.append(level))
	_progress.add_xp(3990)
	assert_eq(levels.size(), 19)
	for i in 19:
		assert_eq(levels[i], i + 2)
	assert_eq(_player.loadout.unlocked_slots, 5)
	assert_almost_eq(_speed(), 118.8, 0.001)
	assert_almost_eq(_player.health.max_health, 180.0, 0.001)
	assert_almost_eq(_player.loadout.mana_bonus, 0.3, 0.0001)


func test_xp_past_the_last_level_keeps_counting_but_levels_nothing() -> void:
	_progress.add_xp(4000)
	watch_signals(_progress)
	_progress.add_xp(10)
	assert_signal_not_emitted(_progress, "leveled_up")
	assert_eq(_profile.total_xp, 4010)
	assert_eq(_progress.level(), 20)


func test_zero_negative_and_dead_player_gain_nothing() -> void:
	_progress.add_xp(0)
	_progress.add_xp(-10)
	assert_eq(_profile.total_xp, 0)
	(_player.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	_progress.add_xp(500)
	assert_eq(_profile.total_xp, 0)
	assert_eq(_progress.run_xp, 0)


func test_slot_reward_unlocks_the_next_slot_only_once() -> void:
	_progress.add_xp(239)
	assert_eq(_player.loadout.unlocked_slots, 1)
	_progress.add_xp(1)
	assert_eq(_player.loadout.unlocked_slots, 2)
	_progress.add_xp(1)
	assert_eq(_player.loadout.unlocked_slots, 2)


func test_health_reward_heals_by_the_amount_it_adds() -> void:
	_progress.add_xp(30)
	_player.health.take_damage(30.0)
	_progress.add_xp(50)
	assert_almost_eq(_player.health.max_health, 120.0, 0.001)
	assert_almost_eq(_player.health.current_health, 90.0, 0.001)


func test_mana_reward_adds_mana_to_the_equipped_spell() -> void:
	var spell := _player.loadout.slots[0]
	var pool := spell.data.max_mana
	_progress.add_xp(150)
	assert_almost_eq(spell.max_mana(), pool * 1.15, 0.001)
	assert_almost_eq(spell.current_mana, pool * 1.15, 0.001)


func test_chosen_buff_and_second_spell_levels_change_no_stats() -> void:
	_progress.add_xp(_track.xp_for_level(13))
	var speed := _speed()
	var max_health := _player.health.max_health
	var bonus := _player.loadout.mana_bonus
	var slots := _player.loadout.unlocked_slots
	_progress.add_xp(_track.xp_for_level(14) - _track.xp_for_level(13))
	assert_eq(_progress.level(), 14)
	assert_eq(_speed(), speed)
	assert_eq(_player.health.max_health, max_health)
	assert_eq(_player.loadout.mana_bonus, bonus)
	assert_eq(_player.loadout.unlocked_slots, slots)
	assert_null(_player.loadout.slots[1])


func test_run_xp_counts_only_this_run() -> void:
	_profile.add_xp(100)
	_progress.add_xp(20)
	assert_eq(_progress.run_xp, 20)
	assert_eq(_profile.total_xp, 120)


func test_random_buff_level_changes_nothing_mid_run() -> void:
	_progress.add_xp(_track.xp_for_level(6))
	var speed := _speed()
	var slots := _player.loadout.unlocked_slots
	var data := _player.loadout.slots[0].data
	_progress.add_xp(_track.xp_for_level(7) - _track.xp_for_level(6))
	assert_eq(_progress.level(), 7)
	assert_eq(_speed(), speed)
	assert_eq(_player.loadout.unlocked_slots, slots)
	assert_eq(_player.loadout.slots[0].data, data)
	assert_true(data.buff_stacks.is_empty())

func test_add_gold_banks_it_in_the_profile_and_this_run() -> void:
	_progress.add_gold(7)
	_progress.add_gold(5)
	assert_eq(_profile.gold, 12)
	assert_eq(_progress.run_gold, 12)


func test_gold_from_an_earlier_run_is_kept_but_not_counted_as_this_run() -> void:
	_profile.add_gold(100)
	_progress.add_gold(3)
	assert_eq(_profile.gold, 103)
	assert_eq(_progress.run_gold, 3)


func test_zero_negative_and_dead_player_bank_no_gold() -> void:
	_progress.add_gold(0)
	_progress.add_gold(-5)
	assert_eq(_profile.gold, 0)
	(_player.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	_progress.add_gold(50)
	assert_eq(_profile.gold, 0)
	assert_eq(_progress.run_gold, 0)


func test_gold_changed_reports_the_total() -> void:
	_profile.add_gold(10)
	watch_signals(_progress)
	_progress.add_gold(4)
	assert_signal_emitted_with_parameters(_progress, "gold_changed", [14])


func _wear(id: StringName) -> void:
	var catalog := EquipmentCatalog.default_catalog()
	_profile.grant(id)
	_profile.equip(int(catalog.find(id).slot()), id)
	_player.equipment_bonuses = ShopSystem.bonuses(_profile, catalog)


func test_level_up_keeps_the_equipment_bonuses() -> void:
	_wear(&"hat_swift")
	_progress.add_xp(30)
	assert_almost_eq(_speed(), 90.0 * (1.0 + 0.08 + 0.10), 0.001)


func test_equipment_never_applies_twice_across_several_level_ups() -> void:
	_wear(&"hat_swift")
	_progress.add_xp(_track.xp_for_level(11))
	assert_almost_eq(_speed(), 90.0 * (1.0 + 0.24 + 0.10), 0.001)
	_progress.add_xp(1)
	assert_almost_eq(_speed(), 90.0 * (1.0 + 0.24 + 0.10), 0.001)


func test_health_level_up_with_equipment_heals_by_the_gain() -> void:
	_wear(&"hat_hardy")
	_player.health.take_damage(30.0)
	_progress.add_xp(_track.xp_for_level(3))
	assert_almost_eq(_player.health.max_health, 100.0 * (1.0 + 0.20 + 0.20), 0.001)
	assert_almost_eq(_player.health.current_health, 70.0 + 40.0, 0.001)


func test_equipment_damage_bonus_survives_a_mana_level_up() -> void:
	_wear(&"robe_ember")
	_progress.add_xp(_track.xp_for_level(4))
	assert_almost_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.DAMAGE_FIRE), 0.15, 0.0001)
	assert_almost_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.SPELL_MANA), 0.15, 0.0001)


func test_a_level_up_sets_only_the_level_layer() -> void:
	_wear(&"hat_swift")
	var temporary := StatBonuses.new()
	temporary.add(StatBonuses.Stat.CAST_SPEED, 0.25)
	_player.temporary_bonuses = temporary
	_progress.add_xp(30)
	assert_almost_eq(_player.level_bonuses.fraction(StatBonuses.Stat.SPEED), 0.08, 0.0001)
	assert_almost_eq(_player.equipment_bonuses.fraction(StatBonuses.Stat.SPEED), 0.10, 0.0001)
	assert_almost_eq(_player.temporary_bonuses.fraction(StatBonuses.Stat.CAST_SPEED), 0.25, 0.0001)
	assert_almost_eq(_speed(), 90.0 * 1.18, 0.001)
	assert_almost_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.CAST_SPEED), 0.25, 0.0001)
