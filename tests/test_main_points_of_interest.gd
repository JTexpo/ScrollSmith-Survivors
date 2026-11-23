extends GutTest

const ROOT := "res://.godot/save_tests"

var _dir: String
var _main: Main
var _player: Player


func before_each() -> void:
	_dir = "%s/poi_%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func after_each() -> void:
	get_tree().paused = false
	var absolute := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func _start(save_path: String = "") -> void:
	_main = load("res://scenes/main/main.tscn").instantiate() as Main
	_main.save_path = save_path
	(_main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	var merchant_screen := _main.get_node("MerchantScreen") as MerchantScreen
	merchant_screen.pause_tree = false
	merchant_screen.input_guard_msec = 0
	add_child_autofree(_main)
	_main._rng.seed = 11
	_player = _main.get_node("Player") as Player


func _point(file: String, at: Vector2 = Vector2(400, 300)) -> PointOfInterest:
	var point := (load("res://scenes/interactables/%s.tscn" % file) as PackedScene).instantiate() as PointOfInterest
	_main.add_child(point)
	point.global_position = at
	_main.connect_point_of_interest(point)
	return point


func _toast() -> String:
	return (_main.get_node("Hud/LevelToast") as LevelToast).text


func _pickups() -> Array:
	return get_tree().get_nodes_in_group(&"scroll_pickups").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())


func _drain_mana() -> void:
	for spell in _player.loadout.slots:
		if spell != null:
			spell.current_mana = 0.0


func test_using_a_health_shrine_heals_and_starts_its_timer_and_a_second_use_is_refused() -> void:
	_start()
	var shrine := _point("health_shrine")
	_player.health.take_damage(60.0)
	var hurt := _player.health.current_health
	shrine.interact(_player)
	assert_almost_eq(_player.health.current_health, hurt + 0.5 * _player.health.max_health, 0.01)
	assert_false(shrine.is_ready())
	assert_eq(shrine.cooldown_left, 180.0)
	assert_string_contains(_toast(), "Healed 50%")
	_player.health.take_damage(20.0)
	var after := _player.health.current_health
	shrine.interact(_player)
	assert_eq(_player.health.current_health, after, "the second use changed nothing")
	assert_string_contains(_toast(), PointOfInterestSystem.REASON_REFRESHING)
	assert_eq(shrine.cooldown_left, 180.0, "and did not restart the timer")


func test_a_health_shrine_at_full_health_is_refused_and_not_consumed() -> void:
	_start()
	var shrine := _point("health_shrine")
	shrine.interact(_player)
	assert_string_contains(_toast(), PointOfInterestSystem.REASON_FULL_HEALTH)
	assert_true(shrine.is_ready())
	assert_eq(shrine.cooldown_left, 0.0)


func test_a_mana_shrine_restores_and_a_full_one_is_refused() -> void:
	_start()
	var shrine := _point("mana_shrine")
	shrine.interact(_player)
	assert_string_contains(_toast(), PointOfInterestSystem.REASON_FULL_MANA)
	assert_true(shrine.is_ready())
	_drain_mana()
	shrine.interact(_player)
	assert_false(shrine.is_ready())
	for spell in _player.loadout.slots:
		if spell != null:
			assert_almost_eq(spell.current_mana, 0.5 * spell.max_mana(), 0.01)


func test_a_chest_adds_gold_once_places_a_scroll_beside_it_and_starts_its_timer() -> void:
	_start()
	var chest := _point("treasure_chest", Vector2(400, 300))
	var gold_before: int = _main.profile.gold
	chest.interact(_player)
	var gained: int = _main.profile.gold - gold_before
	assert_between(gained, 20, 40)
	var pickups := _pickups()
	assert_eq(pickups.size(), 1)
	assert_lte((pickups[0] as Node2D).global_position.distance_to(chest.global_position), 25.0)
	assert_false(chest.is_ready())
	chest.interact(_player)
	assert_eq(_main.profile.gold - gold_before, gained, "no second payment")
	assert_eq(_pickups().size(), 1, "and no second scroll")


func test_a_rare_scroll_spot_places_a_rare_scroll_and_no_gold() -> void:
	_start()
	var spot := _point("rare_scroll_spot")
	var gold_before: int = _main.profile.gold
	spot.interact(_player)
	assert_eq(_main.profile.gold, gold_before)
	var pickups := _pickups()
	assert_eq(pickups.size(), 1)
	assert_eq((pickups[0] as ScrollPickup).scroll.rarity, ScrollData.Rarity.RARE)


func test_the_chest_is_ready_again_after_its_refresh_time() -> void:
	_start()
	var chest := _point("treasure_chest")
	chest.interact(_player)
	var gold_after_first: int = _main.profile.gold
	chest._process(chest.data.refresh_seconds)
	assert_true(chest.is_ready())
	chest.interact(_player)
	assert_gt(_main.profile.gold, gold_after_first)
	assert_eq(_pickups().size(), 2)


func test_the_merchant_opens_its_screen_and_a_purchase_is_saved() -> void:
	var path := "%s/save.json" % _dir
	_start(path)
	var merchant := _point("merchant")
	_main.profile.add_gold(1000)
	var screen := _main.get_node("MerchantScreen") as MerchantScreen
	merchant.interact(_player)
	assert_true(screen.is_open())
	screen.activate(&"potion_health")
	var price := ShopSystem.potion_price(PotionCatalog.default_catalog().find(&"potion_health"), merchant.data.price_multiplier)
	var reloaded := SaveGame.load_profile(path)
	assert_eq(reloaded.potion_count(&"potion_health"), 1, "the sale was written to the save at once")
	assert_eq(reloaded.gold, 1000 - price)
	assert_eq(_player.belt.count(&"potion_health"), 1, "and the potion belt shows it")
	screen.close()


func test_a_dead_player_cannot_use_a_point() -> void:
	_start()
	var shrine := _point("health_shrine")
	var merchant := _point("merchant", Vector2(500, 300))
	_player.health.take_damage(1.0e9)
	assert_true(_player.health.is_dead())
	shrine.interact(_player)
	merchant.interact(_player)
	assert_true(shrine.is_ready())
	assert_false((_main.get_node("MerchantScreen") as MerchantScreen).is_open())


func test_the_timer_does_not_run_while_the_game_is_paused_after_a_use() -> void:
	_start()
	var shrine := _point("health_shrine")
	_player.health.take_damage(50.0)
	shrine.interact(_player)
	get_tree().paused = true
	await wait_physics_frames(6)
	assert_eq(shrine.cooldown_left, 180.0)
	get_tree().paused = false


func test_a_scroll_dropped_by_a_point_survives_until_the_pickup_cap_is_really_exceeded() -> void:
	_start()
	_main.get_node("ScrollDropper").max_pickups = 2
	var first := _point("treasure_chest", Vector2(300, 300))
	var second := _point("treasure_chest", Vector2(500, 300))
	var third := _point("treasure_chest", Vector2(700, 300))
	first.interact(_player)
	var first_pickup := _pickups()[0] as ScrollPickup
	second.interact(_player)
	assert_eq(_pickups().size(), 2)
	assert_false(first_pickup.is_queued_for_deletion(), "room for two: the first stays")
	third.interact(_player)
	assert_eq(_pickups().size(), 2, "past the cap the oldest goes, as for every drop")
	assert_true(first_pickup.is_queued_for_deletion())
