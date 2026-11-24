extends GutTest
## The debug cheat keys (F7 map overlay, F8 potions, F9 mana, F10 scrolls, F12 XP) were removed in the spring cleaning: they worked on the live web build
## and F12's XP was saved to the player's profile. Only the F3 performance overlay (a tester tool) remains.


func _new_main() -> Main:
	var main := load("res://scenes/main/main.tscn").instantiate() as Main
	main.save_path = ""
	(main.get_node("BuffPickScreen") as BuffPickScreen).pause_tree = false
	add_child_autofree(main)
	return main


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	return event


func test_the_input_map_has_no_debug_action_but_the_performance_overlay() -> void:
	for action in InputMap.get_actions():
		if String(action).begins_with("debug_"):
			assert_eq(action, &"debug_perf_overlay", "%s is a leftover cheat or debug action" % action)


func test_main_has_no_cheat_export() -> void:
	var main := _new_main()
	for property in main.get_property_list():
		assert_ne(property["name"], "debug_scrolls", "the scroll cheat export is gone")


func test_a_cheat_key_press_changes_nothing() -> void:
	var main := _new_main()
	var player := main.get_node("Player") as Player
	player.loadout.selected().current_mana = 0.0
	for keycode in [KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F12]:
		main._unhandled_input(_key(keycode))
	assert_eq(player.inventory.total_count(), 0, "no scrolls appeared")
	assert_eq(player.progress.run_xp, 0, "no XP appeared")
	assert_true(main.run_potions.is_empty(), "no potions appeared")
	assert_eq(player.loadout.selected().current_mana, 0.0, "mana was not refilled")
	assert_null((main.get_node("GameMap") as GameMap).get_node_or_null("Debug"), "no hidden debug overlay exists")


func test_the_performance_overlay_key_still_works() -> void:
	var before := FxSettings.perf_overlay
	var main := _new_main()
	var action := InputEventAction.new()
	action.action = &"debug_perf_overlay"
	action.pressed = true
	main._unhandled_input(action)
	assert_eq(FxSettings.perf_overlay, not before, "F3 toggles the performance overlay")
	main._unhandled_input(action)
	FxSettings.perf_overlay = before
