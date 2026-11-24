extends GutTest

## Every Main in a test gets an empty save path, so no test reads or writes the player's real save,
## and a pick screen that does not pause the test runner.
func _new_main(save_path: String = "") -> Main:
	var main := load("res://scenes/main/main.tscn").instantiate() as Main
	main.save_path = save_path
	(main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	add_child_autofree(main)
	return main


func test_player_death_shows_death_screen_and_bar_tracks_health() -> void:
	var main := _new_main()
	var player := main.get_node("Player") as Player
	var death_screen := main.get_node("DeathScreen") as DeathScreen
	var bar := main.get_node("Hud/HealthBar") as HealthBar
	assert_false(death_screen.visible)
	assert_eq(bar.ratio, 1.0)
	(player.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(30.0, Vector2.ZERO)
	assert_eq(bar.ratio, 0.7)
	await wait_seconds(0.6)
	(player.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_true(death_screen.visible)


func test_spell_bar_is_bound_and_slot_presses_select() -> void:
	var main := _new_main()
	var player := main.get_node("Player") as Player
	var bar := main.get_node("Hud/SpellBar") as SpellBar
	assert_eq(bar.widgets.size(), 5)
	bar.slot_pressed.emit(1)
	assert_eq(player.loadout.selected_index, 0, "slot 2 is locked")
	player.loadout.unlock_next()
	player.loadout.equip(1, load("res://resources/spells/thunder_cone.tres") as SpellData)
	bar.slot_pressed.emit(1)
	assert_eq(player.loadout.selected_index, 1)


func test_debug_key_refills_drained_mana() -> void:
	var main := _new_main()
	var player := main.get_node("Player") as Player
	player.loadout.selected().current_mana = 0.0
	var event := InputEventAction.new()
	event.action = &"debug_restore_mana"
	event.pressed = true
	main._unhandled_input(event)
	assert_eq(player.loadout.selected().current_mana, player.loadout.selected().data.max_mana)


func test_dead_player_cannot_change_spell_by_tapping_the_bar() -> void:
	var main := _new_main()
	var player := main.get_node("Player") as Player
	var bar := main.get_node("Hud/SpellBar") as SpellBar
	player.loadout.unlock_next()
	player.loadout.equip(1, load("res://resources/spells/thunder_cone.tres") as SpellData)
	(player.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = bar.widgets[1].get_global_rect().get_center()
	bar.widgets[1]._input(touch)
	assert_eq(player.loadout.selected_index, 0)
	assert_false(bar.visible)


func test_main_has_a_bound_target_reticle() -> void:
	var main := _new_main()
	var reticle := main.get_node("TargetReticle") as TargetReticle
	assert_not_null(reticle)
	reticle._process(0.0)
	assert_false(reticle.visible)


func test_enemy_hits_show_damage_numbers_but_player_hits_do_not() -> void:
	var main := _new_main()
	var numbers := main.get_node("DamageNumbers") as DamageNumbers
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var enemy := spawner.spawn_at(Vector2(100, 100))
	(enemy.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(10.0, Vector2.ZERO, 0.0, SpellData.Element.FIRE)
	assert_eq(numbers.active_count(), 1)
	var player := main.get_node("Player") as Player
	(player.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(10.0, Vector2.ZERO)
	assert_eq(numbers.active_count(), 1)


func test_killing_an_enemy_can_drop_a_scroll() -> void:
	var main := _new_main()
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var enemy := spawner.spawn_at(Vector2(100, 100))
	enemy.data = enemy.data.duplicate() as EnemyData
	enemy.data.drop_table = enemy.data.drop_table.duplicate() as DropTable
	enemy.data.drop_table.drop_chance = 1.0
	(enemy.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	var found := 0
	for pickup in get_tree().get_nodes_in_group(&"scroll_pickups"):
		if main.is_ancestor_of(pickup):
			found += 1
	assert_eq(found, 1)


func _main() -> Main:
	var main := _new_main()
	return main


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_collecting_a_scroll_shows_the_toast_and_updates_the_button() -> void:
	var main := _main()
	var player := main.get_node("Player") as Player
	var pickup := (load("res://scenes/scrolls/scroll_pickup.tscn") as PackedScene).instantiate() as ScrollPickup
	main.add_child(pickup)
	pickup.setup(load("res://resources/scrolls/base/fire.tres") as ScrollData)
	pickup.global_position = player.global_position
	await wait_physics_frames(4)
	assert_true((main.get_node("Hud/ScrollToast") as ScrollToast).is_showing())
	assert_eq((main.get_node("Hud/ScrollToast") as ScrollToast).text, "+ Fire Scroll")
	assert_eq((main.get_node("Hud/InventoryButton") as InventoryButton).total, 1)


func test_toggle_action_opens_the_panel_and_a_dead_player_cannot() -> void:
	var main := _main()
	var panel := main.get_node("Hud/InventoryPanel") as InventoryPanel
	main._unhandled_input(_action(&"toggle_inventory"))
	assert_true(panel.is_open())
	main._unhandled_input(_action(&"toggle_inventory"))
	assert_false(panel.is_open())
	(main.get_node("Player/HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	main._unhandled_input(_action(&"toggle_inventory"))
	assert_false(panel.is_open())


func test_the_button_toggles_the_panel() -> void:
	var main := _main()
	var panel := main.get_node("Hud/InventoryPanel") as InventoryPanel
	(main.get_node("Hud/InventoryButton") as InventoryButton).pressed.emit()
	assert_true(panel.is_open())


func test_debug_key_gives_three_of_every_scroll() -> void:
	var main := _main()
	var player := main.get_node("Player") as Player
	main._unhandled_input(_action(&"debug_give_scrolls"))
	assert_eq(main.debug_scrolls.size(), 15)
	assert_eq(player.inventory.total_count(), 45)
	for scroll in main.debug_scrolls:
		assert_eq(player.inventory.count(scroll), 3)


func test_player_death_closes_the_panel() -> void:
	var main := _main()
	var panel := main.get_node("Hud/InventoryPanel") as InventoryPanel
	panel.set_open(true)
	(main.get_node("Player/HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_false(panel.is_open())


func test_player_death_hides_the_inventory_button_so_restart_taps_get_through() -> void:
	var main := _main()
	var button := main.get_node("Hud/InventoryButton") as InventoryButton
	assert_true(button.visible)
	(main.get_node("Player/HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_false(button.visible)
	watch_signals(button)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(button.global_position + button.size / 2.0)
	button._input(touch)
	assert_signal_not_emitted(button, "pressed")


func test_main_has_three_lecterns_off_screen_from_the_start() -> void:
	var main := _new_main()
	var player := main.get_node("Player") as Player
	var lecterns := get_tree().get_nodes_in_group(&"lecterns").filter(func(node): return main.is_ancestor_of(node))
	assert_eq(lecterns.size(), 3)
	for lectern in lecterns:
		assert_gt(lectern.global_position.distance_to(player.global_position), 135.0)


func test_interact_button_follows_the_interaction_target() -> void:
	var main := _new_main()
	var player := main.get_node("Player") as Player
	var button := main.get_node("Hud/InteractButton") as InteractButton
	button.require_touchscreen = false
	assert_false(button.visible)
	var lectern := (load("res://scenes/interactables/lectern.tscn") as PackedScene).instantiate() as Lectern
	main.add_child(lectern)
	lectern.global_position = player.global_position + Vector2(10, 0)
	await wait_physics_frames(4)
	assert_true(button.visible)
	lectern.global_position += Vector2(500, 0)
	await wait_physics_frames(4)
	assert_false(button.visible)


func _open_main() -> Array:
	var main := _new_main()
	var screen := main.get_node("CraftingScreen") as CraftingScreen
	screen.pause_tree = false
	var lecterns := get_tree().get_nodes_in_group(&"lecterns").filter(func(node): return main.is_ancestor_of(node))
	return [main, screen, lecterns[0], main.get_node("Player")]


func test_interacting_with_a_lectern_opens_the_crafting_screen() -> void:
	var parts := _open_main()
	var screen := parts[1] as CraftingScreen
	(parts[2] as Lectern).interact(parts[3])
	assert_true(screen.is_open())
	screen.cancel()


func test_dead_player_cannot_open_the_screen() -> void:
	var parts := _open_main()
	var screen := parts[1] as CraftingScreen
	((parts[3] as Player).get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	(parts[2] as Lectern).interact(parts[3])
	assert_false(screen.is_open())


func test_closing_the_screen_blocks_casting_until_release() -> void:
	var parts := _open_main()
	var main := parts[0] as Main
	var screen := parts[1] as CraftingScreen
	var player := parts[3] as Player
	(parts[2] as Lectern).interact(player)
	screen.cancel()
	Input.action_press(&"cast")
	await wait_physics_frames(6)
	var fire := player.loadout.slots[0] as SpellInstance
	var untouched := fire.current_mana == fire.data.max_mana
	Input.action_release(&"cast")
	assert_true(untouched, "the held click must not fire after the screen closes")
	assert_not_null(main)


func test_full_craft_through_main() -> void:
	var parts := _open_main()
	var main := parts[0] as Main
	var screen := parts[1] as CraftingScreen
	var player := parts[3] as Player
	var event := InputEventAction.new()
	event.action = &"debug_give_scrolls"
	event.pressed = true
	main._unhandled_input(event)
	(parts[2] as Lectern).interact(player)
	var thunder := load("res://resources/scrolls/base/thunder.tres") as ScrollData
	screen.choose_base(thunder)
	screen.choose_area(load("res://resources/scrolls/area/missile.tres") as ScrollData)
	screen.confirm()
	assert_eq(player.loadout.slots[0].data.id, &"thunder_missile_normal")
	assert_eq(player.inventory.count(thunder), 2)
	var bar := main.get_node("Hud/SpellBar") as SpellBar
	assert_eq(bar.widgets[0].element_color, thunder.color)
	assert_false(screen.is_open())


func test_full_buffed_craft_through_main() -> void:
	var parts := _open_main()
	var main := parts[0] as Main
	var screen := parts[1] as CraftingScreen
	var player := parts[3] as Player
	var event := InputEventAction.new()
	event.action = &"debug_give_scrolls"
	event.pressed = true
	main._unhandled_input(event)
	(parts[2] as Lectern).interact(player)
	var damage := load("res://resources/scrolls/buff/damage.tres") as ScrollData
	screen.choose_base(load("res://resources/scrolls/base/thunder.tres") as ScrollData)
	screen.choose_area(load("res://resources/scrolls/area/missile.tres") as ScrollData)
	assert_true(screen.add_buff(damage))
	assert_true(screen.add_buff(damage))
	screen.confirm()
	var spell := (player.loadout.slots[0] as SpellInstance).data
	assert_eq(spell.buff_stacks[&"buff_damage"], 2)
	assert_eq(player.inventory.count(damage), 1)
	var bar := main.get_node("Hud/SpellBar") as SpellBar
	assert_eq(bar.widgets[0].element_color, spell.color)
	assert_false(screen.is_open())


func test_tapping_the_death_screen_restarts_through_the_real_input_pipeline() -> void:
	# Real touches go through the viewport (controls first, then unhandled input), not straight to
	# DeathScreen.handle_event. The root cause of the phone bug was a screen-sized ColorRect that
	# swallowed taps (see test_world_input.gd), which only a real-window check can show, because in
	# headless mode pointer events never reach _unhandled_input at all. This test therefore guards
	# the second layer: the death screen listens in _input, which runs before any control.
	var main := _new_main()
	var death_screen := main.get_node("DeathScreen") as DeathScreen
	death_screen.input_delay_msec = 0
	death_screen.restart_scene_path = "res://this_scene_does_not_exist.tscn"
	var player := main.get_node("Player") as Player
	(player.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(1000.0, Vector2.ZERO)
	assert_true(death_screen.visible)
	await wait_process_frames(2)
	watch_signals(death_screen)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(get_window().size) / 2.0
	Input.parse_input_event(touch)
	await wait_process_frames(2)
	assert_signal_emit_count(death_screen, "restart_requested", 1, "a tap on the death screen must restart")


func test_the_pause_menu_and_button_exist_and_the_button_hides_on_death() -> void:
	var main := _main()
	assert_not_null(main.get_node_or_null("PauseMenu"))
	var button := main.get_node("Hud/PauseButton") as PauseButton
	assert_true(button.visible)
	(main.get_node("Player") as Player).health.take_damage(1.0e9)
	assert_false(button.visible, "a hidden button lets the restart tap through")


func test_pausing_stops_the_run_clock_and_resuming_continues_it() -> void:
	var main := _main()
	var menu := main.get_node("PauseMenu") as PauseMenu
	menu.open()
	var frozen := RunClock.seconds()
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_almost_eq(RunClock.seconds(), frozen, 0.02, "the run clock stands still while paused")
	menu.close()
	await get_tree().create_timer(0.3).timeout
	assert_gt(RunClock.seconds(), frozen + 0.2, "and continues afterwards")


func test_the_pause_menu_is_available_only_while_alive_and_nothing_else_is_open() -> void:
	var main := _main()
	var menu := main.get_node("PauseMenu") as PauseMenu
	assert_true(menu.available.call())
	(main.get_node("Hud/InventoryPanel") as InventoryPanel).set_open(true)
	assert_false(menu.available.call(), "the inventory is open")
	(main.get_node("Hud/InventoryPanel") as InventoryPanel).set_open(false)
	(main.get_node("Player") as Player).health.take_damage(1.0e9)
	assert_false(menu.available.call(), "dead")


func test_dying_with_the_inventory_open_closes_it_and_unpauses() -> void:
	var main := _main()
	var panel := main.get_node("Hud/InventoryPanel") as InventoryPanel
	panel.set_open(true)
	assert_true(get_tree().paused)
	(main.get_node("Player") as Player).health.take_damage(1.0e9)
	assert_false(panel.is_open())
	assert_false(get_tree().paused)


func after_each() -> void:
	get_tree().paused = false
	GameTime.unfreeze()


func test_a_run_with_its_own_save_path_leaves_the_static_settings_alone() -> void:
	GameSettings.music_volume = 0.123
	var main := _new_main()
	assert_not_null(main)
	assert_almost_eq(GameSettings.music_volume, 0.123, 0.0001, "no real settings file was read")
	GameSettings.reset()
