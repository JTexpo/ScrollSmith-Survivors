extends GutTest

var _root: Node2D
var _player: Player
var _profile: RunPotions
var _catalog: PotionCatalog
var _belt: PotionBelt


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)
	_profile = RunPotions.new()
	_catalog = PotionCatalog.default_catalog()
	_belt = _player.belt
	_belt.bind(_player, _profile, _catalog)


func _hurt(amount: float = 50.0) -> void:
	_player.health.take_damage(amount)


func test_use_consumes_exactly_one_and_starts_the_cooldowns() -> void:
	_profile.add_potion(&"potion_health", 3)
	_hurt(90.0)
	var result := _belt.use(&"potion_health")
	assert_true(result.ok)
	assert_eq(result.potion.id, &"potion_health")
	assert_eq(_profile.potion_count(&"potion_health"), 2)
	assert_almost_eq(_belt.cooldown_left(&"potion_health"), 10.0, 0.0001)
	assert_almost_eq(_belt.shared_left(), PotionBelt.SHARED_COOLDOWN, 0.0001)
	assert_almost_eq(_player.health.current_health, 50.0, 0.001)


func test_a_refused_use_consumes_nothing_and_starts_no_cooldown() -> void:
	_profile.add_potion(&"potion_health", 2)
	_profile.add_potion(&"potion_mana", 2)
	var cases := {
		"full health": &"potion_health",
		"full mana": &"potion_mana",
		"none left": &"potion_speed",
		"unknown": &"nothing",
	}
	for name in cases:
		watch_signals(_belt)
		var result := _belt.use(cases[name])
		assert_false(result.ok, name)
		assert_false(result.reason.is_empty(), name)
		assert_signal_emitted_with_parameters(_belt, "refused", [result.reason])
		assert_signal_not_emitted(_belt, "used")
	assert_eq(_profile.potion_count(&"potion_health"), 2)
	assert_eq(_profile.potion_count(&"potion_mana"), 2)
	assert_eq(_belt.cooldown_left(&"potion_health"), 0.0)
	assert_eq(_belt.shared_left(), 0.0)


func test_a_dead_player_refuses_and_keeps_the_potion() -> void:
	_profile.add_potion(&"potion_health")
	_player.health.take_damage(1000.0)
	var result := _belt.use(&"potion_health")
	assert_false(result.ok)
	assert_eq(result.reason, PotionSystem.REASON_DEAD)
	assert_eq(_profile.potion_count(&"potion_health"), 1)


func test_use_emits_used_and_changed() -> void:
	_profile.add_potion(&"potion_health")
	_hurt()
	watch_signals(_belt)
	_belt.use(&"potion_health")
	assert_signal_emit_count(_belt, "used", 1)
	assert_signal_emit_count(_belt, "changed", 1)
	assert_signal_not_emitted(_belt, "refused")


func test_cooldown_ticks_down_and_allows_a_second_drink() -> void:
	_profile.add_potion(&"potion_health", 2)
	_hurt(90.0)
	_belt.use(&"potion_health")
	_hurt(30.0)
	assert_false(_belt.use(&"potion_health").ok, "still cooling down")
	_belt._process(10.01)
	assert_eq(_belt.cooldown_left(&"potion_health"), 0.0)
	assert_true(_belt.use(&"potion_health").ok)
	assert_eq(_profile.potion_count(&"potion_health"), 0)


func test_shared_cooldown_blocks_a_different_potion_for_one_second() -> void:
	_profile.add_potion(&"potion_health")
	_profile.add_potion(&"potion_speed")
	_hurt()
	_belt.use(&"potion_health")
	var blocked := _belt.use(&"potion_speed")
	assert_false(blocked.ok)
	assert_eq(blocked.reason, PotionSystem.REASON_SHARED)
	assert_eq(_profile.potion_count(&"potion_speed"), 1)
	_belt._process(1.01)
	assert_true(_belt.use(&"potion_speed").ok)


func test_each_type_has_its_own_cooldown() -> void:
	_profile.add_potion(&"potion_health")
	_profile.add_potion(&"potion_speed")
	_hurt()
	_belt.use(&"potion_health")
	_belt._process(1.01)
	assert_gt(_belt.cooldown_left(&"potion_health"), 0.0)
	assert_eq(_belt.cooldown_left(&"potion_speed"), 0.0)
	assert_true(_belt.use(&"potion_speed").ok)


func test_mashing_burns_only_one_potion() -> void:
	_profile.add_potion(&"potion_health", 3)
	_hurt(90.0)
	for i in 10:
		_belt.use(&"potion_health")
	assert_eq(_profile.potion_count(&"potion_health"), 2)


func test_a_timed_potion_cannot_be_drunk_twice_while_running() -> void:
	_profile.add_potion(&"potion_speed", 2)
	assert_true(_belt.use(&"potion_speed").ok)
	_belt._process(2.0)
	var again := _belt.use(&"potion_speed")
	assert_false(again.ok)
	assert_eq(_profile.potion_count(&"potion_speed"), 1)


func test_cooldowns_use_a_pausable_process_mode() -> void:
	var holder := Node.new()
	holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child_autofree(holder)
	var belt := PotionBelt.new()
	holder.add_child(belt)
	get_tree().paused = true
	var processes_while_paused := belt.can_process()
	get_tree().paused = false
	assert_false(processes_while_paused)
	assert_true(belt.can_process())


func test_cooldown_ratio_goes_from_one_to_zero() -> void:
	_profile.add_potion(&"potion_health")
	_hurt()
	_belt.use(&"potion_health")
	assert_almost_eq(_belt.cooldown_ratio(&"potion_health"), 1.0, 0.0001)
	_belt._process(5.0)
	assert_almost_eq(_belt.cooldown_ratio(&"potion_health"), 0.5, 0.0001)
	_belt._process(5.1)
	assert_eq(_belt.cooldown_ratio(&"potion_health"), 0.0)
	assert_eq(_belt.cooldown_ratio(&"nothing"), 0.0)


func test_changed_is_emitted_when_a_cooldown_ends() -> void:
	_profile.add_potion(&"potion_health")
	_hurt()
	_belt.use(&"potion_health")
	watch_signals(_belt)
	_belt._process(10.1)
	assert_signal_emitted(_belt, "changed")


func test_select_wraps_through_the_catalog_and_use_selected_drinks_it() -> void:
	assert_eq(_belt.selected_index, 0)
	_belt.select(-1)
	assert_eq(_belt.selected_index, 5)
	_belt.select(1)
	assert_eq(_belt.selected_index, 0)
	_profile.add_potion(&"potion_health")
	_hurt()
	assert_true(_belt.use_selected().ok)
	assert_eq(_profile.potion_count(&"potion_health"), 0)
	_belt.select(2)
	assert_eq(_belt.selected_index, 2)
	_profile.add_potion(&"potion_speed")
	_belt._process(2.0)
	assert_true(_belt.use_selected().ok)


func test_a_potion_id_missing_from_the_catalog_is_refused_and_skipped() -> void:
	_profile.add_potion(&"potion_removed", 3)
	var result := _belt.use(&"potion_removed")
	assert_false(result.ok)
	assert_eq(result.reason, PotionSystem.REASON_UNKNOWN)
	assert_eq(_profile.potion_count(&"potion_removed"), 3)


func test_count_follows_the_profile() -> void:
	assert_eq(_belt.count(&"potion_luck"), 0)
	_profile.add_potion(&"potion_luck", 3)
	assert_eq(_belt.count(&"potion_luck"), 3)


func test_use_slot_drinks_the_potion_at_that_place_in_the_bar() -> void:
	_profile.add_potion(&"potion_speed")
	assert_true(_belt.use_slot(2).ok)
	assert_eq(_profile.potion_count(&"potion_speed"), 0)


func test_use_slot_out_of_range_is_refused_without_error() -> void:
	assert_false(_belt.use_slot(-1).ok)
	assert_false(_belt.use_slot(6).ok)
	assert_false(_belt.use_slot(99).ok)


func test_refresh_emits_changed() -> void:
	watch_signals(_belt)
	_belt.refresh()
	assert_signal_emit_count(_belt, "changed", 1)
