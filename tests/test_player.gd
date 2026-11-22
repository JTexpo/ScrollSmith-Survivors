extends GutTest

var _root: Node2D
var _player: Player


func before_each() -> void:
	# Projectiles land in the player's parent, so give each test its own.
	_root = Node2D.new()
	add_child_autofree(_root)
	_player = load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(_player)


func after_each() -> void:
	Input.action_release(&"move_right")


func _hurtbox() -> HurtboxComponent:
	return _player.get_node("HurtboxComponent") as HurtboxComponent


func test_hit_reduces_health_and_flashes_and_knocks_back() -> void:
	_hurtbox().receive_hit(10.0, Vector2(-10, 0), 100.0)
	assert_eq(_player.health.current_health, 90.0)
	assert_true((_player.get_node("HitFlashComponent") as HitFlashComponent).is_flashing)
	assert_gt((_player.get_node("KnockbackComponent") as KnockbackComponent).velocity.x, 0.0)


func test_second_hit_inside_window_ignored() -> void:
	_hurtbox().receive_hit(10.0, Vector2.ZERO)
	assert_false(_hurtbox().receive_hit(10.0, Vector2.ZERO))
	assert_eq(_player.health.current_health, 90.0)


func test_many_hits_same_frame_deal_damage_once() -> void:
	for i in 10:
		_hurtbox().receive_hit(10.0, Vector2.ZERO)
	assert_eq(_player.health.current_health, 90.0)


func test_death_emits_once_leaves_group_and_stops_movement() -> void:
	watch_signals(_player)
	_hurtbox().receive_hit(1000.0, Vector2.ZERO)
	_hurtbox().receive_hit(1000.0, Vector2.ZERO)
	assert_signal_emit_count(_player, "died", 1)
	assert_false(_player.is_in_group(&"player"))
	var start := _player.global_position
	Input.action_press(&"move_right")
	await wait_physics_frames(3)
	assert_eq(_player.global_position, start)


func test_knockback_moves_player_away_from_source() -> void:
	var start := _player.global_position
	_hurtbox().receive_hit(1.0, start + Vector2(-10, 0), 100.0)
	await wait_physics_frames(3)
	assert_gt(_player.global_position.x, start.x)


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _projectile_count() -> int:
	var count := 0
	for child in _root.get_children():
		if child is MissileArea and not child.is_queued_for_deletion():
			count += 1
	return count


func test_alive_player_casts_and_spends_mana_from_the_selected_spell() -> void:
	Input.action_press(&"cast")
	await wait_physics_frames(4)
	Input.action_release(&"cast")
	assert_gt(_projectile_count(), 0)
	var fire := _player.loadout.slots[0] as SpellInstance
	assert_lt(fire.current_mana, fire.data.max_mana)


func _unlock_and_equip(index: int) -> void:
	while not _player.loadout.is_unlocked(index):
		_player.loadout.unlock_next()
	_player.loadout.equip(index, load("res://resources/spells/thunder_cone.tres") as SpellData)


func test_slot_keys_ignore_locked_slots_and_select_unlocked_ones() -> void:
	_player._unhandled_input(_action_event(&"spell_slot_2"))
	assert_eq(_player.loadout.selected_index, 0, "slot 2 is locked")
	_player._unhandled_input(_action_event(&"spell_slot_5"))
	assert_eq(_player.loadout.selected_index, 0, "slot 5 is locked")
	_unlock_and_equip(1)
	_player._unhandled_input(_action_event(&"spell_slot_2"))
	assert_eq(_player.loadout.selected_index, 1)


func test_shoulder_actions_cycle_spells() -> void:
	_unlock_and_equip(1)
	_player._unhandled_input(_action_event(&"spell_next"))
	assert_eq(_player.loadout.selected_index, 1)
	_player._unhandled_input(_action_event(&"spell_prev"))
	assert_eq(_player.loadout.selected_index, 0)


func test_shoulder_actions_do_nothing_with_one_spell() -> void:
	_player._unhandled_input(_action_event(&"spell_next"))
	_player._unhandled_input(_action_event(&"spell_prev"))
	assert_eq(_player.loadout.selected_index, 0)


func test_dead_player_ignores_slot_input_and_casts_nothing() -> void:
	_hurtbox().receive_hit(1000.0, Vector2.ZERO)
	_player._unhandled_input(_action_event(&"spell_slot_2"))
	assert_eq(_player.loadout.selected_index, 0)
	Input.action_press(&"cast")
	await wait_physics_frames(4)
	Input.action_release(&"cast")
	assert_eq(_projectile_count(), 0)


func test_depleted_spell_does_nothing_and_does_not_switch() -> void:
	_player.loadout.selected().current_mana = 0.0
	Input.action_press(&"cast")
	await wait_physics_frames(4)
	Input.action_release(&"cast")
	assert_eq(_projectile_count(), 0)
	assert_eq(_player.loadout.selected_index, 0)


func test_player_exposes_its_aim_component() -> void:
	assert_true(_player.aim is AimComponent)
	assert_eq(_player.aim, _player.get_node("AimComponent"))


func test_player_starts_with_only_fire_missile_and_four_locked_slots() -> void:
	var loadout := _player.loadout
	assert_eq(loadout.slots[0].data.id, &"fire_missile")
	assert_eq(loadout.slots[0].data.max_mana, 1000.0)
	assert_eq(loadout.slots[0].current_mana, 1000.0)
	assert_eq(loadout.unlocked_slots, 1)
	for i in range(1, 5):
		assert_null(loadout.slots[i], "slot %d" % i)
		assert_false(loadout.is_unlocked(i), "slot %d" % i)


func test_player_has_a_scroll_inventory() -> void:
	assert_true(_player.inventory is ScrollInventory)
	assert_eq(_player.inventory, _player.get_node("ScrollInventory"))


func test_player_has_a_pickup_collector() -> void:
	assert_true(_player.collector is PickupCollector)
	assert_eq(_player.collector.inventory, _player.inventory)
	assert_eq(_player.collector.collision_mask, PhysicsLayers.PICKUP)


func test_no_cast_until_the_cast_input_is_released_after_resume() -> void:
	_player.require_cast_release()
	Input.action_press(&"cast")
	await wait_physics_frames(6)
	assert_eq(_projectile_count(), 0, "the held click must not fire")
	var fire := _player.loadout.slots[0] as SpellInstance
	assert_eq(fire.current_mana, fire.data.max_mana)
	Input.action_release(&"cast")
	await wait_physics_frames(3)
	Input.action_press(&"cast")
	await wait_physics_frames(4)
	Input.action_release(&"cast")
	assert_gt(_projectile_count(), 0, "after a release it casts again")


func test_player_has_an_interaction_component() -> void:
	assert_true(_player.interaction is InteractionComponent)
	assert_eq(_player.interaction.health, _player.health)
	assert_eq(_player.interaction.collision_mask, PhysicsLayers.INTERACTABLE)


func test_interact_action_uses_the_nearest_lectern() -> void:
	var lectern := (load("res://scenes/interactables/lectern.tscn") as PackedScene).instantiate() as Lectern
	_root.add_child(lectern)
	lectern.global_position = _player.global_position + Vector2(10, 0)
	await wait_physics_frames(4)
	watch_signals(lectern)
	_player._unhandled_input(_action_event(&"interact"))
	assert_signal_emit_count(lectern, "interacted", 1)


func _bonuses(level: int) -> StatBonuses:
	return StatBonuses.for_level(LevelTrack.default_track(), level)


func test_apply_stat_bonuses_scales_from_the_base_values() -> void:
	_player.apply_stat_bonuses(_bonuses(20))
	assert_almost_eq((_player.get_node("MoveComponent") as MoveComponent).speed, 118.8, 0.001)
	assert_almost_eq(_player.health.max_health, 180.0, 0.001)
	assert_almost_eq(_player.health.current_health, 180.0, 0.001)
	assert_almost_eq(_player.loadout.mana_bonus, 0.3, 0.0001)


func test_apply_twice_is_the_same_as_once() -> void:
	_player.apply_stat_bonuses(_bonuses(20))
	_player.apply_stat_bonuses(_bonuses(20))
	assert_almost_eq((_player.get_node("MoveComponent") as MoveComponent).speed, 118.8, 0.001)
	assert_almost_eq(_player.health.max_health, 180.0, 0.001)
	_player.apply_stat_bonuses(_bonuses(20), true)
	assert_almost_eq(_player.health.max_health, 180.0, 0.001)
	assert_almost_eq(_player.health.current_health, 180.0, 0.001)


func test_heal_difference_adds_the_gain_to_current_health() -> void:
	_player.health.take_damage(30.0)
	_player.apply_stat_bonuses(_bonuses(3), true)
	assert_almost_eq(_player.health.max_health, 120.0, 0.001)
	assert_almost_eq(_player.health.current_health, 90.0, 0.001)


func test_without_heal_difference_current_becomes_max() -> void:
	_player.health.take_damage(30.0)
	_player.apply_stat_bonuses(_bonuses(3), false)
	assert_almost_eq(_player.health.current_health, 120.0, 0.001)


func test_fresh_bonuses_change_nothing() -> void:
	_player.apply_stat_bonuses(_bonuses(1))
	assert_eq((_player.get_node("MoveComponent") as MoveComponent).speed, 90.0)
	assert_eq(_player.health.max_health, 100.0)
	assert_eq(_player.loadout.mana_bonus, 0.0)


func test_apply_stat_bonuses_reaches_the_loadout_cast_stats() -> void:
	var bonuses := StatBonuses.new()
	bonuses.add(StatBonuses.Stat.CAST_SPEED, 0.25)
	bonuses.add(StatBonuses.Stat.DAMAGE_FIRE, 0.15)
	_player.apply_stat_bonuses(bonuses)
	assert_almost_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.CAST_SPEED), 0.25, 0.0001)
	assert_almost_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.DAMAGE_FIRE), 0.15, 0.0001)
	assert_almost_eq(_player.loadout.slots[0].cast_speed_bonus, 0.25, 0.0001)


func _layer(stat: StatBonuses.Stat, amount: float) -> StatBonuses:
	var layer := StatBonuses.new()
	layer.add(stat, amount)
	return layer


func test_refresh_bonuses_adds_the_three_layers() -> void:
	_player.level_bonuses = _layer(StatBonuses.Stat.SPEED, 0.08)
	_player.equipment_bonuses = _layer(StatBonuses.Stat.SPEED, 0.10)
	_player.temporary_bonuses = _layer(StatBonuses.Stat.SPEED, 0.40)
	_player.refresh_bonuses()
	assert_almost_eq((_player.get_node("MoveComponent") as MoveComponent).speed, 90.0 * 1.58, 0.001)


func test_refresh_bonuses_with_empty_layers_changes_nothing() -> void:
	_player.refresh_bonuses()
	assert_eq((_player.get_node("MoveComponent") as MoveComponent).speed, 90.0)
	assert_eq(_player.health.max_health, 100.0)
	assert_eq(_player.loadout.bonuses.fraction(StatBonuses.Stat.CAST_SPEED), 0.0)


func test_layers_can_be_set_in_any_order_with_the_same_result() -> void:
	var other := load("res://scenes/player/player.tscn").instantiate() as Player
	_root.add_child(other)
	_player.level_bonuses = _layer(StatBonuses.Stat.HEALTH, 0.2)
	_player.equipment_bonuses = _layer(StatBonuses.Stat.SPEED, 0.1)
	_player.temporary_bonuses = _layer(StatBonuses.Stat.CAST_SPEED, 0.25)
	_player.refresh_bonuses()
	other.temporary_bonuses = _layer(StatBonuses.Stat.CAST_SPEED, 0.25)
	other.equipment_bonuses = _layer(StatBonuses.Stat.SPEED, 0.1)
	other.level_bonuses = _layer(StatBonuses.Stat.HEALTH, 0.2)
	other.refresh_bonuses()
	assert_eq((other.get_node("MoveComponent") as MoveComponent).speed, (_player.get_node("MoveComponent") as MoveComponent).speed)
	assert_eq(other.health.max_health, _player.health.max_health)
	assert_eq(other.loadout.bonuses.fraction(StatBonuses.Stat.CAST_SPEED), _player.loadout.bonuses.fraction(StatBonuses.Stat.CAST_SPEED))


func test_changing_one_layer_leaves_the_others() -> void:
	_player.level_bonuses = _layer(StatBonuses.Stat.SPEED, 0.08)
	_player.equipment_bonuses = _layer(StatBonuses.Stat.SPEED, 0.10)
	_player.refresh_bonuses()
	var before := (_player.get_node("MoveComponent") as MoveComponent).speed
	_player.temporary_bonuses = _layer(StatBonuses.Stat.SPEED, 0.40)
	_player.refresh_bonuses()
	assert_gt((_player.get_node("MoveComponent") as MoveComponent).speed, before)
	_player.temporary_bonuses = StatBonuses.new()
	_player.refresh_bonuses()
	assert_eq((_player.get_node("MoveComponent") as MoveComponent).speed, before)
	assert_almost_eq(before, 90.0 * 1.18, 0.001)


func test_refresh_bonuses_emits_bonuses_changed_with_the_total() -> void:
	_player.level_bonuses = _layer(StatBonuses.Stat.SPEED, 0.08)
	_player.temporary_bonuses = _layer(StatBonuses.Stat.CAST_SPEED, 0.25)
	watch_signals(_player)
	_player.refresh_bonuses()
	assert_signal_emit_count(_player, "bonuses_changed", 1)
	var total := get_signal_parameters(_player, "bonuses_changed")[0] as StatBonuses
	assert_almost_eq(total.fraction(StatBonuses.Stat.SPEED), 0.08, 0.0001)
	assert_almost_eq(total.fraction(StatBonuses.Stat.CAST_SPEED), 0.25, 0.0001)


func test_refresh_twice_equals_once() -> void:
	_player.level_bonuses = _layer(StatBonuses.Stat.HEALTH, 0.2)
	_player.equipment_bonuses = _layer(StatBonuses.Stat.SPEED, 0.1)
	_player.refresh_bonuses()
	var speed := (_player.get_node("MoveComponent") as MoveComponent).speed
	var health := _player.health.max_health
	_player.refresh_bonuses()
	_player.refresh_bonuses(true)
	assert_eq((_player.get_node("MoveComponent") as MoveComponent).speed, speed)
	assert_eq(_player.health.max_health, health)
	assert_eq(_player.health.current_health, health)


func test_refresh_with_heal_difference_heals_by_the_gain() -> void:
	_player.health.take_damage(30.0)
	_player.level_bonuses = _layer(StatBonuses.Stat.HEALTH, 0.2)
	_player.refresh_bonuses(true)
	assert_almost_eq(_player.health.max_health, 120.0, 0.001)
	assert_almost_eq(_player.health.current_health, 90.0, 0.001)


func _potion_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _stocked_belt() -> PotionBelt:
	var profile := PlayerProfile.new()
	for potion in PotionCatalog.default_catalog().potions:
		profile.add_potion(potion.id, 3)
	_player.belt.bind(_player, profile, PotionCatalog.default_catalog())
	return _player.belt


func test_potion_key_actions_drink_the_matching_potion() -> void:
	var belt := _stocked_belt()
	_player._unhandled_input(_potion_event(&"potion_3"))
	assert_true(_player.effects.is_active(&"potion_speed"))
	assert_eq(belt.count(&"potion_speed"), 2)
	belt._process(1.1)
	_player.health.take_damage(50.0)
	_player._unhandled_input(_potion_event(&"potion_1"))
	assert_eq(belt.count(&"potion_health"), 2)
	assert_almost_eq(_player.health.current_health, 90.0, 0.001)


func test_controller_actions_select_and_use() -> void:
	var belt := _stocked_belt()
	_player._unhandled_input(_potion_event(&"potion_next"))
	_player._unhandled_input(_potion_event(&"potion_next"))
	assert_eq(belt.selected_index, 2)
	_player._unhandled_input(_potion_event(&"potion_use"))
	assert_true(_player.effects.is_active(&"potion_speed"))
	_player._unhandled_input(_potion_event(&"potion_prev"))
	assert_eq(belt.selected_index, 1)


func test_a_dead_player_cannot_drink() -> void:
	var belt := _stocked_belt()
	_player.health.take_damage(1000.0)
	_player._unhandled_input(_potion_event(&"potion_3"))
	_player._unhandled_input(_potion_event(&"potion_next"))
	assert_eq(belt.count(&"potion_speed"), 3)
	assert_eq(belt.selected_index, 0)
