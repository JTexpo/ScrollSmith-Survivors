extends GutTest
## Every game event that should make a sound, checked through the board's `requested` signal (which fires even while locked,
## so no audio is needed). Each test is one route.

const SPELLS := {
	&"cast_fire": "res://resources/spells/fire_missile.tres",
	&"cast_thunder": "res://resources/spells/thunder_cone.tres",
	&"cast_land": "res://resources/spells/land_area.tres",
	&"cast_sea": "res://resources/spells/sea_line.tres",
}

var _main: Main
var _board: SoundBoard
var _player: Player
var _spawner: EnemySpawner
var _heard: Array[StringName] = []


func before_each() -> void:
	_main = load("res://scenes/main/main.tscn").instantiate() as Main
	_main.save_path = ""
	for screen in ["BuffPickScreen", "CraftingScreen", "MerchantScreen"]:
		_main.get_node(screen).pause_tree = false
	add_child_autofree(_main)
	_board = _main.get_node("SoundBoard") as SoundBoard
	_player = _main.get_node("Player") as Player
	_spawner = _main.get_node("EnemySpawner") as EnemySpawner
	_heard = []
	_board.requested.connect(func(id: StringName) -> void: _heard.append(id))


func after_each() -> void:
	get_tree().paused = false
	GameTime.unfreeze()
	_board.set_muted(false)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), 0.0)


func _enemy(archetype: StringName = &"standard", element: StringName = &"none") -> Enemy:
	var composer := EnemyComposer.new()
	var data := composer.compose(
		load("res://resources/enemies/archetypes/%s.tres" % archetype) as EnemyArchetype,
		load("res://resources/enemies/elements/%s.tres" % element) as EnemyElement)
	var enemy := (load("res://scenes/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.setup(data, Rect2(0, 0, 960, 540), RandomNumberGenerator.new())
	_main.add_child(enemy)
	return enemy


func test_a_cast_plays_the_cast_sound_of_the_spells_element() -> void:
	for id in SPELLS:
		_player.loadout.equip(0, load(SPELLS[id]) as SpellData)
		_heard.clear()
		_player.loadout.cast_fired.emit(0)
		assert_true(_heard.has(id), "%s for %s" % [id, SPELLS[id]])


func test_a_spell_hit_sounds_like_its_own_element() -> void:
	ImpactEvents.bus.hit.emit(Vector2.ZERO, 0.4, &"thunder")
	assert_eq(_heard, [&"hit_thunder"] as Array[StringName])


func test_a_damaged_enemy_alone_adds_no_base_hit_sound() -> void:
	_spawner.enemy_damaged.emit(Vector2.ZERO, 5.0, ElementTable.Effect.NEUTRAL)
	assert_eq(_heard.size(), 0, "the base hit sound comes from the spell's own hit event, so it has the right element and weight")


func test_a_vulnerable_hit_adds_the_strong_accent() -> void:
	_spawner.enemy_damaged.emit(Vector2.ZERO, 5.0, ElementTable.Effect.VULNERABLE)
	assert_true(_heard.has(&"hit_strong"))
	assert_false(_heard.has(&"hit_resisted"))


func test_a_resisted_hit_adds_the_soft_one() -> void:
	_spawner.enemy_damaged.emit(Vector2.ZERO, 5.0, ElementTable.Effect.RESISTED)
	assert_true(_heard.has(&"hit_resisted"))
	assert_false(_heard.has(&"hit_strong"))


func test_a_big_enemy_dies_with_the_big_sound_and_a_small_one_with_the_small_sound() -> void:
	_spawner.enemy_died.emit(_enemy(&"tank"))
	assert_eq(_heard, [&"enemy_die_big"] as Array[StringName])
	_heard.clear()
	_spawner.enemy_died.emit(_enemy(&"standard"))
	assert_eq(_heard, [&"enemy_die"] as Array[StringName])


func test_an_elite_dies_with_the_elite_sound() -> void:
	var elite := _enemy(&"standard")
	elite.make_elite(EliteModifier.default_modifier())
	_spawner.enemy_died.emit(elite)
	assert_eq(_heard, [&"enemy_die_elite"] as Array[StringName])


func test_player_hurt_and_death() -> void:
	_player.hurtbox.hit_received.emit(5.0, Vector2.ZERO, 0.0, ElementTable.Effect.NEUTRAL)
	assert_true(_heard.has(&"player_hurt"))
	_heard.clear()
	_player.died.emit()
	assert_true(_heard.has(&"player_die"))


func test_the_three_pickups() -> void:
	_player.collector.collected.emit(load("res://resources/scrolls/base/fire.tres") as ScrollData)
	_player.collector.xp_collected.emit(5)
	_player.collector.gold_collected.emit(5)
	assert_eq(_heard, [&"pickup_scroll", &"pickup_xp", &"pickup_gold"] as Array[StringName])


func test_potion_used_and_refused() -> void:
	_player.belt.used.emit(PotionCatalog.default_catalog().potions[0])
	_player.belt.refused.emit("Full health.")
	assert_eq(_heard, [&"potion_drink", &"potion_refused"] as Array[StringName])


func test_level_up() -> void:
	_player.progress.leveled_up.emit(2, LevelTrack.default_track().reward_for_level(2))
	assert_true(_heard.has(&"level_up"))


func _boss() -> Boss:
	var phase := BossPhase.new()
	phase.health_threshold = 1.0
	phase.attacks = [] as Array[BossAttack]
	var data := BossData.new()
	data.id = &"test_boss"
	data.max_health = 100.0
	data.phases = [phase] as Array[BossPhase]
	var boss := (load("res://scenes/enemies/boss.tscn") as PackedScene).instantiate() as Boss
	boss.setup(data, 1, null, Rect2(0, 0, 960, 540), RandomNumberGenerator.new())
	_main.add_child(boss)
	boss.set_physics_process(false)
	return boss


func test_a_boss_spawn_starts_the_boss_music_and_its_defeat_ends_it() -> void:
	var director := _main.get_node("RunDirector") as RunDirector
	_board._input(_key())
	director.boss_spawned.emit(_boss(), 1)
	assert_true(_heard.has(&"boss_spawn"))
	assert_eq(_board.music_state(), &"boss")
	director.boss_defeated.emit(1)
	assert_true(_heard.has(&"boss_die"))
	assert_eq(_board.music_state(), &"run")


func _key() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_A
	return event


func test_boss_attack_sounds_follow_the_attack_kind() -> void:
	var director := _main.get_node("RunDirector") as RunDirector
	var boss := _boss()
	director.boss_spawned.emit(boss, 1)
	_heard.clear()
	for entry in [[BossAttack.Kind.SLAM, &"boss_slam"], [BossAttack.Kind.CHARGE, &"boss_charge"], [BossAttack.Kind.BURST, &"boss_burst"]]:
		var attack := BossAttack.new()
		attack.kind = entry[0]
		boss.attack_started.emit(attack)
		assert_true(_heard.has(entry[1]), str(entry[1]))
	var summon := BossAttack.new()
	summon.kind = BossAttack.Kind.SUMMON
	_heard.clear()
	boss.attack_started.emit(summon)
	assert_eq(_heard.size(), 0, "a summon has no sound of its own")


func test_enemy_shots_and_blast_zones_through_the_event_bus() -> void:
	EnemyAttackEvents.bus.shot_fired.emit(Vector2.ZERO)
	EnemyAttackEvents.bus.blast_warned.emit(Vector2.ZERO, 40.0)
	EnemyAttackEvents.bus.blast_detonated.emit(Vector2.ZERO)
	assert_eq(_heard, [&"enemy_shot", &"blast_warn", &"blast_boom"] as Array[StringName])


func test_the_lectern_opens() -> void:
	var lecterns := get_tree().get_nodes_in_group(&"lecterns").filter(func(l): return _main.is_ancestor_of(l))
	assert_gt(lecterns.size(), 0)
	(lecterns[0] as Node).interacted.emit(_player)
	assert_true(_heard.has(&"lectern_open"))


func test_each_point_of_interest_kind_has_its_sound_and_a_refusal_has_none() -> void:
	for entry in [[PointOfInterestData.Kind.HEAL, &"shrine_heal"], [PointOfInterestData.Kind.RESTORE_MANA, &"shrine_mana"], [PointOfInterestData.Kind.LOOT, &"chest_open"], [PointOfInterestData.Kind.MERCHANT, &"merchant_open"]]:
		_heard.clear()
		_main.point_effect_applied.emit(entry[0])
		assert_eq(_heard, [entry[1]] as Array[StringName], str(entry[1]))
	var shrines := get_tree().get_nodes_in_group(&"points_of_interest").filter(func(p): return _main.is_ancestor_of(p) and p.data.kind == PointOfInterestData.Kind.HEAL)
	assert_gt(shrines.size(), 0)
	_heard.clear()
	(shrines[0] as PointOfInterest).used.emit(shrines[0], _player)
	assert_eq(_heard.size(), 0, "a Health Shrine used at full health is refused and silent")


func test_crafting_confirm_and_refusal() -> void:
	var crafting := _main.get_node("CraftingScreen") as CraftingScreen
	crafting.crafted.emit()
	crafting.refused.emit("nope")
	assert_eq(_heard, [&"craft_confirm", &"craft_fail"] as Array[StringName])


func test_shop_buy_equip_and_refusal() -> void:
	var shop := _main.get_node("ShopScreen") as ShopScreen
	shop.last_action = &"buy"
	shop.changed.emit()
	shop.last_action = &"equip"
	shop.changed.emit()
	shop.refused.emit("nope")
	assert_eq(_heard, [&"shop_buy", &"shop_equip", &"shop_fail"] as Array[StringName])


func test_merchant_buy_and_refusal() -> void:
	var merchant := _main.get_node("MerchantScreen") as MerchantScreen
	merchant.changed.emit()
	merchant.refused.emit("nope")
	assert_eq(_heard, [&"shop_buy", &"shop_fail"] as Array[StringName])


func test_footsteps_only_while_moving_and_alive() -> void:
	_player.velocity = Vector2.ZERO
	_board._process(0.5)
	assert_false(_heard.has(&"step"))
	_player.velocity = Vector2(80, 0)
	_board._process(0.5)
	assert_true(_heard.has(&"step"))
	_heard.clear()
	_board._process(0.05)
	assert_false(_heard.has(&"step"), "one step per interval, not one per frame")
	_player.health.take_damage(1.0e9)
	_heard.clear()
	_board._process(1.0)
	assert_false(_heard.has(&"step"))


func test_buttons_click_back_and_hover_including_ones_added_later() -> void:
	var plain := UiKit.button("Go")
	_main.add_child(plain)
	var stop := UiKit.button("Cancel", &"ButtonRed")
	_main.add_child(stop)
	plain.pressed.emit()
	stop.pressed.emit()
	plain.focus_entered.emit()
	assert_eq(_heard, [&"ui_click", &"ui_back", &"ui_hover"] as Array[StringName])


func test_binding_twice_does_not_double_every_sound() -> void:
	_board.bind(_main)
	_spawner.enemy_died.emit(_enemy(&"standard"))
	assert_eq(_heard.count(&"enemy_die"), 1)


func test_pressing_mute_toggles_the_board_the_button_and_the_saved_profile() -> void:
	var button := _main.get_node("Hud/MuteButton") as MuteButton
	assert_false(_board.muted)
	button.pressed.emit()
	assert_true(_board.muted)
	assert_true(button.is_muted())
	assert_true(_main.profile.muted)
	var press := InputEventAction.new()
	press.action = &"mute"
	press.pressed = true
	_board._unhandled_input(press)
	assert_false(_board.muted)
	assert_false(button.is_muted())
	assert_false(_main.profile.muted)


func test_a_muted_profile_starts_the_game_muted() -> void:
	var folder := "res://.godot/save_tests/mute_%d" % randi()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var saved := PlayerProfile.new()
	saved.muted = true
	assert_true(SaveGame.save_profile(saved, folder + "/save.json"))
	var muted_main := load("res://scenes/main/main.tscn").instantiate() as Main
	muted_main.save_path = folder + "/save.json"
	for screen in ["BuffPickScreen", "CraftingScreen", "MerchantScreen"]:
		muted_main.get_node(screen).pause_tree = false
	add_child_autofree(muted_main)
	var board := muted_main.get_node("SoundBoard") as SoundBoard
	assert_true(board.muted)
	assert_true((muted_main.get_node("Hud/MuteButton") as MuteButton).is_muted())
	board.set_muted(false)
	AudioServer.set_bus_mute(0, false)
	var absolute := ProjectSettings.globalize_path(folder)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func test_an_achievement_unlock_plays_the_achievement_sound() -> void:
	var tracker := AchievementTracker.new()
	add_child_autofree(tracker)
	_board.bind_achievements(tracker)
	_heard.clear()
	tracker.unlocked.emit(AchievementData.new())
	assert_eq(_heard, [SoundId.ACHIEVEMENT] as Array[StringName])

