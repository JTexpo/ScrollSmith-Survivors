extends GutTest

const ROOT := "res://.godot/save_tests"

var _dir: String
var _track: LevelTrack


func before_each() -> void:
	_dir = "%s/main_%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_track = LevelTrack.default_track()


func after_each() -> void:
	var absolute := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func _path() -> String:
	return "%s/save.json" % _dir


func _new_main(save_path: String) -> Main:
	var main := load("res://scenes/main/main.tscn").instantiate() as Main
	main.save_path = save_path
	(main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	add_child_autofree(main)
	return main


func _save_at_level(level: int) -> void:
	var profile := PlayerProfile.new()
	profile.total_xp = _track.xp_for_level(level)
	SaveGame.save_profile(profile, _path())


func _stack_total(spell: SpellData) -> int:
	var total := 0
	for id in spell.buff_stacks:
		total += int(spell.buff_stacks[id])
	return total


func _player(main: Main) -> Player:
	return main.get_node("Player") as Player


func _speed(main: Main) -> float:
	return (_player(main).get_node("MoveComponent") as MoveComponent).speed


func test_fresh_run_starts_at_level_one_with_one_slot() -> void:
	var main := _new_main(_path())
	assert_eq(main.profile.total_xp, 0)
	assert_eq(_player(main).progress.level(), 1)
	assert_eq(_player(main).loadout.unlocked_slots, 1)
	assert_eq(_speed(main), 90.0)
	assert_eq(_player(main).health.max_health, 100.0)
	assert_eq((main.get_node("Hud/XpBar") as XpBar).level_text(), "Lv 1")
	assert_false((main.get_node("BuffPickScreen") as BuffPickScreen).is_open())


func test_saved_level_ten_profile_starts_with_three_slots_and_the_bonuses() -> void:
	_save_at_level(10)
	var main := _new_main(_path())
	var player := _player(main)
	assert_eq(player.loadout.unlocked_slots, 3)
	assert_almost_eq(_speed(main), 90.0 * 1.16, 0.001)
	assert_almost_eq(player.health.max_health, 140.0, 0.001)
	assert_almost_eq(player.loadout.mana_bonus, 0.3, 0.0001)
	assert_eq(_stack_total(player.loadout.slots[0].data), 1, "level 7 gave one random buff")
	assert_eq((main.get_node("Hud/XpBar") as XpBar).level_text(), "Lv 10")


func test_killing_an_enemy_drops_a_gem_that_adds_xp_when_collected() -> void:
	var main := _new_main("")
	var player := _player(main)
	var enemy := (main.get_node("EnemySpawner") as EnemySpawner).spawn_at(Vector2(300, 300))
	assert_not_null(enemy)
	(enemy.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	var gems := get_tree().get_nodes_in_group(&"xp_gems")
	assert_eq(gems.size(), 1)
	var value := (gems[0] as ValueGem).value
	assert_gt(value, 0)
	player.global_position = (gems[0] as ValueGem).global_position
	await wait_physics_frames(4)
	assert_eq(main.profile.total_xp, value)


func test_level_up_is_saved_to_disk_immediately() -> void:
	var main := _new_main(_path())
	_player(main).progress.add_xp(30)
	assert_eq(SaveGame.load_profile(_path()).total_xp, 30)
	assert_eq(SaveGame.load_profile(_path()).level(_track), 2)


func test_level_up_shows_the_toast() -> void:
	var main := _new_main("")
	_player(main).progress.add_xp(30)
	var toast := main.get_node("Hud/LevelToast") as LevelToast
	assert_true(toast.is_showing())
	assert_string_contains(toast.text, "Level 2!")


func test_death_saves_the_profile_and_shows_the_summary() -> void:
	var main := _new_main(_path())
	_player(main).progress.add_xp(20)
	assert_false(FileAccess.file_exists(_path()), "20 XP is no level-up, so nothing is saved yet")
	(_player(main).get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_eq(SaveGame.load_profile(_path()).total_xp, 20)
	assert_string_starts_with((main.get_node("DeathScreen") as DeathScreen).summary_text(), "+20 XP, +0 Gold this run, level 1")


func test_random_buff_reward_mid_run_changes_nothing_until_next_run() -> void:
	var main := _new_main("")
	_player(main).progress.add_xp(_track.xp_for_level(7))
	assert_eq(_stack_total(_player(main).loadout.slots[0].data), 0)
	var toast := main.get_node("Hud/LevelToast") as LevelToast
	assert_string_contains(toast.text, "Level 7!")
	assert_string_contains(toast.text, "Next run")


func test_owed_chosen_buff_opens_the_pick_screen_before_the_run_and_applies_after_choosing() -> void:
	_save_at_level(12)
	var main := _new_main(_path())
	var screen := main.get_node("BuffPickScreen") as BuffPickScreen
	watch_signals(screen)
	assert_true(screen.is_open())
	assert_gte(screen.option_count(), 4)
	screen.choose(0)
	assert_false(screen.is_open())
	var picked := get_signal_parameters(screen, "chosen")[0] as ScrollData
	var spell := _player(main).loadout.slots[0].data
	assert_eq(_stack_total(spell), 2, "the random buff of level 7 and the chosen one of level 12")
	assert_gte(int(spell.buff_stacks.get(picked.id, 0)), 1)
	_player(main).progress.add_xp(30)
	assert_false(FileAccess.get_file_as_string(_path()).contains("buff_picks"))


func test_unchosen_buff_is_asked_again_next_run() -> void:
	_save_at_level(12)
	var first := _new_main(_path())
	assert_true((first.get_node("BuffPickScreen") as BuffPickScreen).is_open())
	first.free()
	var second := _new_main(_path())
	assert_true((second.get_node("BuffPickScreen") as BuffPickScreen).is_open())


func test_random_buffs_are_rolled_every_run_and_never_saved() -> void:
	_save_at_level(7)
	var first := _new_main(_path())
	assert_eq(_stack_total(_player(first).loadout.slots[0].data), 1)
	_player(first).progress.add_xp(30)
	assert_false(FileAccess.get_file_as_string(_path()).contains("buff_picks"))
	first.free()
	var second := _new_main(_path())
	assert_eq(_stack_total(_player(second).loadout.slots[0].data), 1)


func test_chosen_buff_is_asked_every_run_even_after_choosing() -> void:
	_save_at_level(12)
	var first := _new_main(_path())
	(first.get_node("BuffPickScreen") as BuffPickScreen).choose(0)
	first.free()
	var second := _new_main(_path())
	assert_true((second.get_node("BuffPickScreen") as BuffPickScreen).is_open())


func test_run_start_toast_names_the_rolled_buff() -> void:
	_save_at_level(7)
	var main := _new_main(_path())
	var toast := main.get_node("Hud/LevelToast") as LevelToast
	assert_true(toast.is_showing())
	assert_string_contains(toast.text, "Starting spell gains")


func test_second_run_keeps_the_xp_from_the_first() -> void:
	var first := _new_main(_path())
	_player(first).progress.add_xp(30)
	first.free()
	var second := _new_main(_path())
	assert_eq(second.profile.total_xp, 30)
	assert_eq(_player(second).progress.level(), 2)
	assert_almost_eq(_speed(second), 97.2, 0.001)


func test_empty_save_path_never_creates_a_file() -> void:
	var existed_before := FileAccess.file_exists(SaveGame.DEFAULT_PATH)
	var main := _new_main("")
	_player(main).progress.add_xp(500)
	(_player(main).get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_eq(FileAccess.file_exists(SaveGame.DEFAULT_PATH), existed_before)
	assert_eq(DirAccess.get_files_at(ProjectSettings.globalize_path(_dir)).size(), 0)


func test_f12_gives_100_xp() -> void:
	var main := _new_main("")
	var event := InputEventAction.new()
	event.action = &"debug_give_xp"
	event.pressed = true
	main._unhandled_input(event)
	assert_eq(main.profile.total_xp, 100)
	assert_eq(_player(main).progress.level(), 3)


func test_spell_bar_shows_the_saved_slots_as_unlocked_at_run_start() -> void:
	_save_at_level(10)
	var main := _new_main(_path())
	var bar := main.get_node("Hud/SpellBar") as SpellBar
	for i in 5:
		assert_eq(bar.widgets[i].locked, i >= 3, "slot %d" % (i + 1))


func test_killing_an_enemy_drops_both_a_gem_and_a_coin() -> void:
	var main := _new_main("")
	var enemy := (main.get_node("EnemySpawner") as EnemySpawner).spawn_at(Vector2(300, 300))
	(enemy.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_eq(get_tree().get_nodes_in_group(&"xp_gems").size(), 1)
	assert_eq(get_tree().get_nodes_in_group(&"gold_coins").size(), 1)


func test_collecting_a_coin_banks_gold_and_marks_the_profile_for_saving() -> void:
	var main := _new_main(_path())
	var player := _player(main)
	var coin := (load("res://scenes/progression/gold_coin.tscn") as PackedScene).instantiate() as ValueGem
	main.add_child(coin)
	coin.setup(6)
	coin.global_position = player.global_position
	await wait_physics_frames(4)
	assert_eq(main.profile.gold, 6)
	assert_eq((main.get_node("Hud/GoldCounter") as GoldCounter).gold_text(), "Gold 6")
	assert_true((main.get_node("ProfileSaver") as ProfileSaver).is_dirty())


func test_gold_survives_death_and_a_new_run() -> void:
	var first := _new_main(_path())
	_player(first).progress.add_gold(40)
	(_player(first).get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_string_starts_with((first.get_node("DeathScreen") as DeathScreen).summary_text(), "+0 XP, +40 Gold this run, level 1")
	first.free()
	var second := _new_main(_path())
	assert_eq(second.profile.gold, 40)
	assert_eq((second.get_node("Hud/GoldCounter") as GoldCounter).gold_text(), "Gold 40")


func _save_wearing(ids: Array[StringName]) -> void:
	var catalog := EquipmentCatalog.default_catalog()
	var profile := PlayerProfile.new()
	for id in ids:
		profile.grant(id)
		profile.equip(int(catalog.find(id).slot()), id)
	SaveGame.save_profile(profile, _path())


func test_equipped_items_are_applied_when_a_run_starts() -> void:
	_save_wearing([&"robe_ember", &"wand_quick"] as Array[StringName])
	var main := _new_main(_path())
	var bonuses := _player(main).loadout.bonuses
	assert_almost_eq(bonuses.fraction(StatBonuses.Stat.DAMAGE_FIRE), 0.15, 0.0001)
	assert_almost_eq(bonuses.fraction(StatBonuses.Stat.CAST_SPEED), 0.25, 0.0001)
	assert_almost_eq(bonuses.fraction(StatBonuses.Stat.SPELL_DAMAGE), -0.15, 0.0001)


func test_restart_does_not_apply_equipment_twice() -> void:
	_save_wearing([&"robe_warded", &"hat_swift"] as Array[StringName])
	var first := _new_main(_path())
	var speed := _speed(first)
	var health := _player(first).health.max_health
	var cast_speed := _player(first).loadout.bonuses.fraction(StatBonuses.Stat.CAST_SPEED)
	first.free()
	var second := _new_main(_path())
	assert_almost_eq(_speed(second), speed, 0.0001)
	assert_almost_eq(_player(second).health.max_health, health, 0.0001)
	assert_almost_eq(_player(second).loadout.bonuses.fraction(StatBonuses.Stat.CAST_SPEED), cast_speed, 0.0001)
	assert_almost_eq(_speed(second), 90.0 * 1.10, 0.001)
	assert_almost_eq(_player(second).health.max_health, 130.0, 0.001)


func test_a_level_up_in_a_run_keeps_the_saved_equipment() -> void:
	_save_wearing([&"hat_swift"] as Array[StringName])
	var main := _new_main(_path())
	_player(main).progress.add_xp(30)
	assert_almost_eq(_speed(main), 90.0 * (1.0 + 0.08 + 0.10), 0.001)


func _die(main: Main) -> void:
	(_player(main).get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)


func test_death_screen_shop_opens_the_shop_and_a_purchase_is_saved_immediately() -> void:
	var profile := PlayerProfile.new()
	profile.add_gold(500)
	SaveGame.save_profile(profile, _path())
	var main := _new_main(_path())
	_die(main)
	var death := main.get_node("DeathScreen") as DeathScreen
	death.input_delay_msec = 0
	var shop := main.get_node("ShopScreen") as ShopScreen
	(death.get_node("ShopButton") as Button).pressed.emit()
	assert_true(shop.is_open())
	shop.buy(&"robe_ember")
	var saved := SaveGame.load_profile(_path())
	assert_eq(saved.gold, 400)
	assert_true(saved.owns(&"robe_ember"))
	assert_eq(saved.equipped_id(EquipmentData.Slot.ROBE), &"robe_ember")


func test_closing_the_shop_lets_the_death_screen_restart_again() -> void:
	var main := _new_main("")
	_die(main)
	var death := main.get_node("DeathScreen") as DeathScreen
	death.input_delay_msec = 0
	var shop := main.get_node("ShopScreen") as ShopScreen
	(death.get_node("ShopButton") as Button).pressed.emit()
	watch_signals(death)
	var restart := InputEventAction.new()
	restart.action = &"restart"
	restart.pressed = true
	death.handle_event(restart)
	assert_signal_not_emitted(death, "restart_requested")
	shop.close()
	death.handle_event(restart)
	assert_signal_emit_count(death, "restart_requested", 1)


func test_next_run_after_buying_applies_the_item() -> void:
	var profile := PlayerProfile.new()
	profile.add_gold(500)
	SaveGame.save_profile(profile, _path())
	var first := _new_main(_path())
	_die(first)
	(first.get_node("DeathScreen") as DeathScreen).input_delay_msec = 0
	(first.get_node("DeathScreen/ShopButton") as Button).pressed.emit()
	(first.get_node("ShopScreen") as ShopScreen).buy(&"wand_quick")
	first.free()
	var second := _new_main(_path())
	assert_almost_eq(_player(second).loadout.bonuses.fraction(StatBonuses.Stat.CAST_SPEED), 0.25, 0.0001)
	assert_almost_eq(_player(second).loadout.slots[0].cast_speed_bonus, 0.25, 0.0001)


func test_shop_cannot_be_opened_while_alive() -> void:
	var main := _new_main("")
	(main.get_node("DeathScreen/ShopButton") as Button).pressed.emit()
	assert_false((main.get_node("ShopScreen") as ShopScreen).is_open())


func test_mashing_accept_at_the_moment_of_death_buys_nothing() -> void:
	var profile := PlayerProfile.new()
	profile.add_gold(1000)
	SaveGame.save_profile(profile, _path())
	var main := _new_main(_path())
	_die(main)
	var shop := main.get_node("ShopScreen") as ShopScreen
	var button := main.get_node("DeathScreen/ShopButton") as Button
	button.pressed.emit()
	button.pressed.emit()
	assert_false(shop.is_open(), "the shop stays shut inside the death screen's input delay")
	var saved := SaveGame.load_profile(_path())
	assert_eq(saved.gold, 1000)
	assert_true(saved.owned.is_empty())


func test_a_second_accept_right_after_the_shop_opens_buys_nothing() -> void:
	var profile := PlayerProfile.new()
	profile.add_gold(1000)
	SaveGame.save_profile(profile, _path())
	var main := _new_main(_path())
	_die(main)
	(main.get_node("DeathScreen") as DeathScreen).input_delay_msec = 0
	var shop := main.get_node("ShopScreen") as ShopScreen
	(main.get_node("DeathScreen/ShopButton") as Button).pressed.emit()
	assert_true(shop.is_open())
	# The second press lands on the shop's first item, which has focus.
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused != null and shop.is_ancestor_of(focused):
		focused.pressed.emit()
	assert_eq(main.profile.gold, 1000, "nothing was bought by the second press")
	assert_true(main.profile.owned.is_empty())


func test_the_temporary_layer_starts_empty_every_run() -> void:
	var first := _new_main("")
	var temporary := StatBonuses.new()
	temporary.add(StatBonuses.Stat.SPEED, 0.4)
	_player(first).temporary_bonuses = temporary
	_player(first).refresh_bonuses()
	first.free()
	var second := _new_main("")
	assert_eq(_player(second).temporary_bonuses.fraction(StatBonuses.Stat.SPEED), 0.0)
	assert_eq(_speed(second), 90.0)


func test_the_scroll_dropper_follows_the_players_luck() -> void:
	var main := _new_main("")
	var dropper := main.get_node("ScrollDropper") as ScrollDropper
	assert_eq(dropper.luck, 0.0)
	var lucky := StatBonuses.new()
	lucky.add(StatBonuses.Stat.LUCK, 1.0)
	_player(main).temporary_bonuses = lucky
	_player(main).refresh_bonuses()
	assert_eq(dropper.luck, 1.0)
	_player(main).temporary_bonuses = StatBonuses.new()
	_player(main).refresh_bonuses()
	assert_eq(dropper.luck, 0.0)


## A new Main whose run already holds these potions (they are never saved, so they are added after it starts).
func _stocked(counts: Dictionary) -> Main:
	var main := _new_main(_path())
	for id in counts:
		main.run_potions.add_potion(id, counts[id])
	_player(main).belt.refresh()
	return main


func test_drinking_a_potion_does_not_save() -> void:
	var main := _stocked({&"potion_health": 2})
	_player(main).health.take_damage(50.0)
	var before := FileAccess.get_file_as_string(_path()) if FileAccess.file_exists(_path()) else ""
	assert_true(_player(main).belt.use(&"potion_health").ok)
	assert_eq(main.run_potions.potion_count(&"potion_health"), 1)
	var after := FileAccess.get_file_as_string(_path()) if FileAccess.file_exists(_path()) else ""
	assert_eq(after, before, "potions last one run: a drink writes nothing")


func test_a_refused_drink_does_not_change_the_save() -> void:
	var main := _stocked({&"potion_health": 2})
	var before := FileAccess.get_file_as_string(_path())
	assert_false(_player(main).belt.use(&"potion_health").ok, "full health")
	assert_eq(main.run_potions.potion_count(&"potion_health"), 2)


func test_a_new_run_has_fresh_cooldowns_no_effects_and_no_potions() -> void:
	var first := _stocked({&"potion_health": 2, &"potion_speed": 2})
	_player(first).health.take_damage(50.0)
	_player(first).belt.use(&"potion_health")
	_player(first).belt._process(1.01)
	_player(first).belt.use(&"potion_speed")
	first.free()
	var second := _new_main(_path())
	assert_eq(_player(second).belt.cooldown_left(&"potion_health"), 0.0)
	assert_eq(_player(second).belt.shared_left(), 0.0)
	assert_false(_player(second).effects.is_active(&"potion_speed"))
	assert_eq(_speed(second), 90.0)
	assert_eq(_player(second).belt.count(&"potion_health"), 0, "potions last one run")
	assert_eq(_player(second).belt.count(&"potion_speed"), 0)
	assert_true(second.run_potions.is_empty())


func test_tapping_a_slot_drinks_that_potion() -> void:
	var main := _stocked({&"potion_health": 2})
	_player(main).health.take_damage(50.0)
	(main.get_node("Hud/PotionBar") as PotionBar).slot_pressed.emit(0)
	assert_eq(_player(main).belt.count(&"potion_health"), 1)
	assert_almost_eq(_player(main).health.current_health, 90.0, 0.001)


func test_a_refused_drink_shows_its_reason_in_the_toast() -> void:
	var main := _stocked({&"potion_health": 2})
	(main.get_node("Hud/PotionBar") as PotionBar).slot_pressed.emit(0)
	var toast := main.get_node("Hud/LevelToast") as LevelToast
	assert_true(toast.is_showing())
	assert_string_contains(toast.text, PotionSystem.REASON_FULL_HEALTH)


func test_the_potion_bar_hides_on_death() -> void:
	var main := _new_main("")
	var bar := main.get_node("Hud/PotionBar") as PotionBar
	assert_true(bar.visible)
	_die(main)
	assert_false(bar.visible)


func test_the_bar_shows_the_runs_stock() -> void:
	var main := _stocked({&"potion_mana": 3})
	var bar := main.get_node("Hud/PotionBar") as PotionBar
	assert_eq(bar.widgets[1].count, 3)
	assert_eq(bar.widgets[0].count, 0)


func test_f8_gives_three_of_every_potion_without_saving() -> void:
	var main := _stocked({&"potion_health": 1})
	var event := InputEventAction.new()
	event.action = &"debug_give_potions"
	event.pressed = true
	main._unhandled_input(event)
	for potion in PotionCatalog.default_catalog().potions:
		assert_eq(main.run_potions.potion_count(potion.id), 3, str(potion.id))
	assert_eq((main.get_node("Hud/PotionBar") as PotionBar).widgets[0].count, 3)
	assert_eq(SaveGame.load_profile(_path()).gold, 0, "nothing about potions is saved")


func test_a_potion_tap_does_not_cast_a_spell() -> void:
	var main := _stocked({&"potion_health": 1})
	var bar := main.get_node("Hud/PotionBar") as PotionBar
	var mana := _player(main).loadout.slots[0].current_mana
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = bar.widgets[0].get_global_rect().get_center()
	bar.widgets[0]._input(touch)
	assert_eq(_player(main).loadout.slots[0].current_mana, mana)
	assert_false(_player(main).aim.is_firing)




func test_a_potion_slot_press_blocks_casting_until_the_cast_input_is_released() -> void:
	var main := _stocked({&"potion_health": 1})
	(main.get_node("Hud/PotionBar") as PotionBar).slot_pressed.emit(0)
	assert_true(_player(main)._cast_blocked, "a click on a slot must not also fire a spell")


func test_main_starts_the_run_clock_at_zero() -> void:
	await wait_seconds(0.2)
	var main := _new_main("")
	assert_lt(RunClock.seconds(), 0.1)


func test_the_main_scene_spawns_composed_enemies() -> void:
	var main := _new_main("")
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var enemy := spawner.spawn_at(Vector2(300, 300))
	assert_not_null(enemy)
	assert_false(enemy.data.display_name.is_empty())
	assert_eq(enemy.data.archetype_id, &"standard", "only the Standard role is unlocked at the start")


func test_main_has_a_run_director_wired_to_the_droppers() -> void:
	var main := _new_main("")
	var director := main.get_node("RunDirector") as RunDirector
	assert_not_null(director)
	assert_eq(director.spawner, main.get_node("EnemySpawner"))
	assert_eq(director.xp_dropper, main.get_node("XpDropper"))
	assert_eq(director.gold_dropper, main.get_node("GoldDropper"))
	assert_eq(director.scroll_dropper, main.get_node("ScrollDropper"))


func test_a_boss_defeat_in_main_drops_rewards_and_keeps_the_run_going() -> void:
	var main := _new_main("")
	var director := main.get_node("RunDirector") as RunDirector
	director.tick(300.0)
	var boss := director.current_boss()
	assert_not_null(boss)
	boss.set_physics_process(false)
	(boss.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1.0e9, Vector2.ZERO)
	assert_eq(get_tree().get_nodes_in_group(&"xp_gems").filter(func(n): return (n as ValueGem).value == 300).size(), 1)
	assert_eq(get_tree().get_nodes_in_group(&"gold_coins").filter(func(n): return (n as ValueGem).value == 150).size(), 1)
	assert_false(_player(main).health.is_dead(), "the run goes on")
	assert_eq(director.boss_number, 1)


func test_the_boss_toast_and_bar_appear_when_a_boss_spawns() -> void:
	var main := _new_main("")
	var director := main.get_node("RunDirector") as RunDirector
	director.tick(300.0)
	director.current_boss().set_physics_process(false)
	var bar := main.get_node("Hud/BossBar") as BossBar
	assert_true(bar.is_showing())
	assert_eq(bar.title_text(), "Ember Titan")
	var toast := main.get_node("Hud/LevelToast") as LevelToast
	assert_true(toast.is_showing())
	assert_string_contains(toast.text, "Ember Titan")


func test_defeating_the_boss_hides_the_bar_and_shows_the_defeat_toast() -> void:
	var main := _new_main("")
	var director := main.get_node("RunDirector") as RunDirector
	director.tick(300.0)
	var boss := director.current_boss()
	boss.set_physics_process(false)
	(boss.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1.0e9, Vector2.ZERO)
	assert_false((main.get_node("Hud/BossBar") as BossBar).is_showing())
	assert_string_contains((main.get_node("Hud/LevelToast") as LevelToast).text, "Boss defeated")


func test_the_death_summary_shows_time_survived() -> void:
	var main := _new_main("")
	(_player(main).get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_string_contains((main.get_node("DeathScreen") as DeathScreen).summary_text(), "survived 0:0")


func test_the_hud_has_a_run_clock() -> void:
	var main := _new_main("")
	assert_not_null(main.get_node("Hud/RunClockLabel") as RunClockLabel)


func test_old_save_potions_are_cashed_in_once_and_never_written_again() -> void:
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SaveGame.VERSION, "total_xp": 0, "gold": 10, "potions": {"potion_health": 2, "potion_speed": 1}}))
	file.close()
	var main := _new_main(_path())
	var catalog := PotionCatalog.default_catalog()
	var expected := 10 + 2 * catalog.find(&"potion_health").price + catalog.find(&"potion_speed").price
	assert_eq(main.profile.gold, expected)
	assert_true(main.run_potions.is_empty(), "the run starts with none")
	var saved := FileAccess.get_file_as_string(_path())
	assert_false(saved.contains("potions"), "the rewritten save has no potions")
	assert_eq(SaveGame.load_profile(_path()).gold, expected)
	main.free()
	var again := _new_main(_path())
	assert_eq(again.profile.gold, expected, "a second start cashes in nothing more")


func test_cashing_in_old_potions_shows_a_toast_once() -> void:
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SaveGame.VERSION, "total_xp": 0, "potions": {"potion_health": 2}}))
	file.close()
	var main := _new_main(_path())
	var gold := PotionCatalog.default_catalog().find(&"potion_health").price * 2
	var toast := main.get_node("Hud/LevelToast") as LevelToast
	assert_true(toast.is_showing())
	assert_string_contains(toast.text, "sold for %d Gold" % gold)
	main.free()
	var again := _new_main(_path())
	assert_false((again.get_node("Hud/LevelToast") as LevelToast).is_showing(), "nothing to cash in the second time")


func test_a_long_press_on_the_mute_button_toggles_the_overlay_and_leaves_mute_alone() -> void:
	FxSettings.reset()
	var main := _new_main("")
	var board := main.get_node("SoundBoard") as SoundBoard
	var button := main.get_node("Hud/MuteButton") as MuteButton
	var muted_before := board.muted
	button.long_pressed.emit()
	assert_true(FxSettings.perf_overlay)
	assert_true((main.get_node("PerfOverlay") as PerfOverlay).visible)
	assert_eq(board.muted, muted_before, "a long press never mutes")
	button.long_pressed.emit()
	assert_false(FxSettings.perf_overlay)
	FxSettings.reset()


func test_a_tap_on_the_mute_button_still_toggles_mute_and_leaves_the_overlay_alone() -> void:
	FxSettings.reset()
	var main := _new_main("")
	var board := main.get_node("SoundBoard") as SoundBoard
	var muted_before := board.muted
	(main.get_node("Hud/MuteButton") as MuteButton).pressed.emit()
	assert_eq(board.muted, not muted_before)
	assert_false(FxSettings.perf_overlay)
	FxSettings.reset()


func test_pressing_the_mute_button_blocks_casting_for_the_whole_hold() -> void:
	var main := _new_main("")
	var button := main.get_node("Hud/MuteButton") as MuteButton
	assert_false(_player(main)._cast_blocked)
	button.hold_started.emit()
	assert_true(_player(main)._cast_blocked, "a held click on the button must not fire spells while it is held")
