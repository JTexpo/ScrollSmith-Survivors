extends GutTest

var _track: LevelTrack


func before_each() -> void:
	_track = LevelTrack.default_track()


func test_fresh_profile_is_level_one_with_no_xp() -> void:
	var profile := PlayerProfile.new()
	assert_eq(profile.total_xp, 0)
	assert_eq(profile.level(_track), 1)


func test_add_xp_ignores_zero_and_negative() -> void:
	var profile := PlayerProfile.new()
	profile.add_xp(10)
	profile.add_xp(0)
	profile.add_xp(-4)
	assert_eq(profile.total_xp, 10)
	profile.add_xp(20)
	assert_eq(profile.level(_track), 2)


func test_xp_round_trips_through_a_dictionary() -> void:
	var profile := PlayerProfile.new()
	profile.add_xp(1234)
	var restored := PlayerProfile.from_dict(profile.to_dict())
	assert_not_null(restored)
	assert_eq(restored.total_xp, 1234)


func test_old_save_with_buff_picks_still_loads_and_the_field_is_dropped() -> void:
	var old := {"version": SaveGame.VERSION, "total_xp": 40, "buff_picks": {"7": "buff_damage"}}
	var profile := PlayerProfile.from_dict(old)
	assert_not_null(profile)
	assert_eq(profile.total_xp, 40)
	assert_false(profile.to_dict().has("buff_picks"))


func test_from_dict_does_not_require_buff_picks() -> void:
	assert_not_null(PlayerProfile.from_dict({"version": SaveGame.VERSION, "total_xp": 5}))


func test_from_dict_accepts_what_json_produces() -> void:
	var parsed = JSON.parse_string(JSON.stringify(PlayerProfile.new().to_dict()))
	assert_not_null(PlayerProfile.from_dict(parsed))
	var with_xp := {"version": 1.0, "total_xp": 55.0}
	assert_eq(PlayerProfile.from_dict(with_xp).total_xp, 55)


func test_from_dict_rejects_bad_shapes() -> void:
	var good := {"version": SaveGame.VERSION, "total_xp": 5}
	assert_not_null(PlayerProfile.from_dict(good))
	var cases := {
		"missing total_xp": {"version": SaveGame.VERSION},
		"missing version": {"total_xp": 5},
		"string total_xp": {"version": SaveGame.VERSION, "total_xp": "5"},
		"fractional total_xp": {"version": SaveGame.VERSION, "total_xp": 5.5},
		"negative total_xp": {"version": SaveGame.VERSION, "total_xp": -5},
		"wrong version": {"version": SaveGame.VERSION + 1, "total_xp": 5},
	}
	for name in cases:
		assert_null(PlayerProfile.from_dict(cases[name]), name)


func test_stat_bonuses_for_level() -> void:
	var level_one := StatBonuses.for_level(_track, 1)
	assert_eq(level_one.multiplier(StatBonuses.Stat.SPEED), 1.0)
	assert_eq(level_one.multiplier(StatBonuses.Stat.HEALTH), 1.0)
	assert_eq(level_one.multiplier(StatBonuses.Stat.SPELL_MANA), 1.0)
	var level_five := StatBonuses.for_level(_track, 5)
	assert_almost_eq(level_five.multiplier(StatBonuses.Stat.SPEED), 1.08, 0.0001)
	assert_almost_eq(level_five.multiplier(StatBonuses.Stat.HEALTH), 1.2, 0.0001)
	assert_almost_eq(level_five.multiplier(StatBonuses.Stat.SPELL_MANA), 1.15, 0.0001)
	var level_twenty := StatBonuses.for_level(_track, 20)
	assert_almost_eq(level_twenty.multiplier(StatBonuses.Stat.SPEED), 1.32, 0.0001)
	assert_almost_eq(level_twenty.multiplier(StatBonuses.Stat.HEALTH), 1.8, 0.0001)
	assert_almost_eq(level_twenty.multiplier(StatBonuses.Stat.SPELL_MANA), 1.3, 0.0001)
	assert_almost_eq(level_twenty.fraction(StatBonuses.Stat.SPEED), 0.32, 0.0001)


func test_fresh_profile_has_no_gold_or_items() -> void:
	var profile := PlayerProfile.new()
	assert_eq(profile.gold, 0)
	assert_true(profile.owned.is_empty())
	assert_true(profile.equipped.is_empty())
	assert_eq(profile.equipped_id(0), &"")


func test_add_gold_ignores_zero_and_negative_and_clamps() -> void:
	var profile := PlayerProfile.new()
	profile.add_gold(10)
	profile.add_gold(0)
	profile.add_gold(-3)
	assert_eq(profile.gold, 10)
	profile.add_gold(PlayerProfile.MAX_VALUE * 4)
	assert_eq(profile.gold, PlayerProfile.MAX_VALUE)
	profile.add_gold(1)
	assert_eq(profile.gold, PlayerProfile.MAX_VALUE)


func test_add_xp_clamps_at_the_limit() -> void:
	var profile := PlayerProfile.new()
	profile.add_xp(PlayerProfile.MAX_VALUE)
	profile.add_xp(5)
	assert_eq(profile.total_xp, PlayerProfile.MAX_VALUE)
	profile.add_xp(9223372036854775807)
	assert_eq(profile.total_xp, PlayerProfile.MAX_VALUE)


func test_spend_gold_succeeds_with_exactly_enough() -> void:
	var profile := PlayerProfile.new()
	profile.add_gold(100)
	assert_true(profile.spend_gold(100))
	assert_eq(profile.gold, 0)


func test_spend_gold_fails_with_one_too_few_and_changes_nothing() -> void:
	var profile := PlayerProfile.new()
	profile.add_gold(99)
	assert_false(profile.spend_gold(100))
	assert_eq(profile.gold, 99)


func test_spend_gold_rejects_zero_and_negative() -> void:
	var profile := PlayerProfile.new()
	profile.add_gold(50)
	assert_false(profile.spend_gold(0))
	assert_false(profile.spend_gold(-10))
	assert_eq(profile.gold, 50)


func test_grant_never_duplicates() -> void:
	var profile := PlayerProfile.new()
	profile.grant(&"robe_ember")
	profile.grant(&"robe_ember")
	assert_eq(profile.owned, [&"robe_ember"] as Array[StringName])
	assert_true(profile.owns(&"robe_ember"))
	assert_false(profile.owns(&"robe_tide"))


func test_equip_and_unequip_a_slot() -> void:
	var profile := PlayerProfile.new()
	profile.equip(1, &"wand_quick")
	assert_eq(profile.equipped_id(1), &"wand_quick")
	profile.equip(1, &"staff_oak")
	assert_eq(profile.equipped_id(1), &"staff_oak")
	profile.unequip(1)
	assert_eq(profile.equipped_id(1), &"")
	profile.unequip(1)


func test_gold_items_and_equipment_round_trip_through_a_dictionary() -> void:
	var profile := PlayerProfile.new()
	profile.add_xp(77)
	profile.add_gold(450)
	profile.grant(&"robe_ember")
	profile.grant(&"wand_quick")
	profile.equip(0, &"robe_ember")
	profile.equip(1, &"wand_quick")
	var parsed = JSON.parse_string(JSON.stringify(profile.to_dict()))
	var restored := PlayerProfile.from_dict(parsed)
	assert_not_null(restored)
	assert_eq(restored.total_xp, 77)
	assert_eq(restored.gold, 450)
	assert_eq(restored.owned, [&"robe_ember", &"wand_quick"] as Array[StringName])
	assert_eq(restored.equipped_id(0), &"robe_ember")
	assert_eq(restored.equipped_id(1), &"wand_quick")
	assert_eq(restored.equipped_id(2), &"")


func test_old_save_without_gold_owned_equipped_loads_with_defaults() -> void:
	var profile := PlayerProfile.from_dict({"version": SaveGame.VERSION, "total_xp": 12})
	assert_not_null(profile)
	assert_eq(profile.gold, 0)
	assert_true(profile.owned.is_empty())
	assert_true(profile.equipped.is_empty())


func test_equipped_item_that_is_not_owned_is_dropped_on_load() -> void:
	var data := {"version": SaveGame.VERSION, "total_xp": 0, "owned": ["robe_ember"],
		"equipped": {"0": "robe_ember", "1": "wand_quick"}}
	var profile := PlayerProfile.from_dict(data)
	assert_not_null(profile)
	assert_eq(profile.equipped_id(0), &"robe_ember")
	assert_eq(profile.equipped_id(1), &"")


func test_from_dict_rejects_bad_gold_owned_and_equipped_shapes() -> void:
	var base := {"version": SaveGame.VERSION, "total_xp": 5}
	var cases := {
		"string gold": {"gold": "5"},
		"fractional gold": {"gold": 5.5},
		"negative gold": {"gold": -1},
		"gold above 2^53": {"gold": 1.0e19},
		"owned not an array": {"owned": "robe_ember"},
		"owned entry not a string": {"owned": [3]},
		"equipped not a dictionary": {"equipped": []},
		"equipped key not a slot": {"equipped": {"7": "robe_ember"}},
		"equipped key not a number": {"equipped": {"robe": "robe_ember"}},
		"equipped value not a string": {"equipped": {"0": 4}},
		"total_xp above 2^53": {"total_xp": 1.0e19},
		"total_xp slightly fractional": {"total_xp": 30.000001},
		"version slightly off": {"version": 1.0000000001},
	}
	for name in cases:
		var data := base.duplicate()
		data.merge(cases[name], true)
		assert_null(PlayerProfile.from_dict(data), name)


func test_fresh_profile_has_no_legacy_potions() -> void:
	assert_true(PlayerProfile.new().legacy_potions.is_empty())


func test_the_profile_writes_no_potions() -> void:
	var profile := PlayerProfile.new()
	profile.legacy_potions[&"potion_health"] = 3
	assert_false(profile.to_dict().has("potions"), "potions last one run and are never saved")


func test_an_old_save_with_potions_loads_them_as_legacy() -> void:
	var loaded := PlayerProfile.from_dict({"version": SaveGame.VERSION, "total_xp": 0, "potions": {"potion_health": 3, "potion_luck": 7, "potion_mana": 0}})
	assert_not_null(loaded)
	assert_eq(loaded.legacy_potions, {&"potion_health": 3, &"potion_luck": 7}, "zero counts are dropped")


func test_old_save_without_potions_loads_empty() -> void:
	var profile := PlayerProfile.from_dict({"version": SaveGame.VERSION, "total_xp": 8})
	assert_not_null(profile)
	assert_true(profile.legacy_potions.is_empty())


func test_from_dict_rejects_bad_potion_fields() -> void:
	var base := {"version": SaveGame.VERSION, "total_xp": 5}
	var cases := {
		"not a dictionary": {"potions": []},
		"string count": {"potions": {"potion_health": "3"}},
		"fractional count": {"potions": {"potion_health": 1.5}},
		"negative count": {"potions": {"potion_health": -1}},
		"count of 100": {"potions": {"potion_health": 100}},
		"huge count": {"potions": {"potion_health": 1.0e19}},
		"null count": {"potions": {"potion_health": null}},
		"null potions": {"potions": null},
	}
	for name in cases:
		var data := base.duplicate()
		data.merge(cases[name], true)
		assert_null(PlayerProfile.from_dict(data), name)


func test_muted_round_trips_and_a_fresh_profile_is_not_muted() -> void:
	assert_false(PlayerProfile.new().muted)
	var profile := PlayerProfile.new()
	profile.muted = true
	var restored := PlayerProfile.from_dict(profile.to_dict())
	assert_not_null(restored)
	assert_true(restored.muted)


func test_a_save_without_the_muted_field_loads_as_not_muted_and_it_is_only_written_when_true() -> void:
	var data := PlayerProfile.new().to_dict()
	assert_false(data.has("muted"), "an unmuted profile writes nothing new, so old saves and files are unchanged")
	var restored := PlayerProfile.from_dict(data)
	assert_not_null(restored)
	assert_false(restored.muted)


func test_a_wrongly_typed_muted_field_is_ignored_not_fatal() -> void:
	var data := PlayerProfile.new().to_dict()
	data["muted"] = "yes"
	var restored := PlayerProfile.from_dict(data)
	assert_not_null(restored, "the rest of the save still loads")
	assert_false(restored.muted)


func test_bests_round_trip_through_a_dictionary() -> void:
	var profile := PlayerProfile.new()
	profile.best_seconds = 301
	profile.best_enemies = 120
	profile.best_level = 9
	var parsed = JSON.parse_string(JSON.stringify(profile.to_dict()))
	var restored := PlayerProfile.from_dict(parsed)
	assert_not_null(restored)
	assert_eq(restored.best_seconds, 301)
	assert_eq(restored.best_enemies, 120)
	assert_eq(restored.best_level, 9)


func test_a_profile_with_no_bests_writes_no_bests_field() -> void:
	assert_false(PlayerProfile.new().to_dict().has("bests"), "an old reader and an old save are unaffected")


func test_an_old_save_without_bests_loads_with_zero_bests() -> void:
	var profile := PlayerProfile.from_dict({"version": SaveGame.VERSION, "total_xp": 8})
	assert_not_null(profile)
	assert_eq(profile.best_seconds, 0)
	assert_eq(profile.best_enemies, 0)
	assert_eq(profile.best_level, 0)


func test_a_bad_bests_value_is_a_bad_save() -> void:
	var base := {"version": SaveGame.VERSION, "total_xp": 5}
	var cases := {
		"not a dictionary": {"bests": []},
		"null": {"bests": null},
		"string": {"bests": {"seconds": "9"}},
		"negative": {"bests": {"enemies": -1}},
		"fractional": {"bests": {"level": 2.5}},
	}
	for name in cases:
		var data := base.duplicate()
		data.merge(cases[name], true)
		assert_null(PlayerProfile.from_dict(data), name)


func test_a_partial_bests_dictionary_defaults_the_missing_keys() -> void:
	var profile := PlayerProfile.from_dict({"version": SaveGame.VERSION, "total_xp": 0, "bests": {"enemies": 12}})
	assert_not_null(profile)
	assert_eq(profile.best_enemies, 12)
	assert_eq(profile.best_seconds, 0)
	assert_eq(profile.best_level, 0)
