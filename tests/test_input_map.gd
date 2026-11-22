extends GutTest

const ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"interact", &"pause", &"cast",
	&"spell_slot_1", &"spell_slot_2", &"spell_slot_3", &"spell_slot_4", &"spell_slot_5",
	&"aim_up", &"aim_down", &"aim_left", &"aim_right", &"restart",
	&"spell_prev", &"spell_next", &"debug_restore_mana",
	&"toggle_inventory", &"debug_give_scrolls", &"debug_give_xp",
	&"potion_1", &"potion_2", &"potion_3", &"potion_4", &"potion_5", &"potion_6",
	&"potion_prev", &"potion_next", &"potion_use", &"debug_give_potions",
]
const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]


func _has_event(action: StringName, type: Variant) -> bool:
	for event in InputMap.action_get_events(action):
		if is_instance_of(event, type):
			return true
	return false


func test_all_actions_exist() -> void:
	for action in ACTIONS:
		assert_true(InputMap.has_action(action), "missing action %s" % action)


func test_movement_has_keyboard_and_joypad_events() -> void:
	for action in MOVE_ACTIONS:
		assert_true(_has_event(action, InputEventKey), "%s has no key" % action)
		var joypad := _has_event(action, InputEventJoypadMotion) or _has_event(action, InputEventJoypadButton)
		assert_true(joypad, "%s has no joypad event" % action)


func test_cast_is_left_mouse_button() -> void:
	var found := false
	for event in InputMap.action_get_events(&"cast"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			found = true
	assert_true(found)


func test_all_events_match_any_device() -> void:
	for action in ACTIONS:
		for event in InputMap.action_get_events(action):
			assert_eq(event.device, -1, "%s event is pinned to device %d" % [action, event.device])


func test_touch_does_not_emulate_mouse() -> void:
	assert_eq(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), false)


func test_spell_cycling_is_on_the_controller_shoulders() -> void:
	for action in [&"spell_prev", &"spell_next"]:
		assert_true(_has_event(action, InputEventJoypadButton), "%s has no joypad button" % action)


func test_debug_restore_mana_is_a_key() -> void:
	assert_true(_has_event(&"debug_restore_mana", InputEventKey))


func test_toggle_inventory_has_key_and_joypad() -> void:
	assert_true(_has_event(&"toggle_inventory", InputEventKey))
	assert_true(_has_event(&"toggle_inventory", InputEventJoypadButton))


func test_debug_give_scrolls_is_a_key() -> void:
	assert_true(_has_event(&"debug_give_scrolls", InputEventKey))


func test_debug_give_xp_is_a_key() -> void:
	assert_true(_has_event(&"debug_give_xp", InputEventKey))


func test_potion_slots_are_keys_z_x_c_v_b_n() -> void:
	var expected := {&"potion_1": KEY_Z, &"potion_2": KEY_X, &"potion_3": KEY_C, &"potion_4": KEY_V, &"potion_5": KEY_B, &"potion_6": KEY_N}
	for action in expected:
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == expected[action]:
				found = true
		assert_true(found, "%s is not on its key" % action)


func test_potion_selection_is_on_the_dpad() -> void:
	var expected := {&"potion_prev": JOY_BUTTON_DPAD_LEFT, &"potion_next": JOY_BUTTON_DPAD_RIGHT, &"potion_use": JOY_BUTTON_DPAD_UP}
	for action in expected:
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index == expected[action]:
				found = true
		assert_true(found, "%s is not on its D-pad button" % action)


func test_debug_give_potions_is_f8() -> void:
	var found := false
	for event in InputMap.action_get_events(&"debug_give_potions"):
		if event is InputEventKey and event.physical_keycode == KEY_F8:
			found = true
	assert_true(found)
