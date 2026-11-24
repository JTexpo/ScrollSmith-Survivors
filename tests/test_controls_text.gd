extends GutTest


func test_every_listed_action_exists_in_the_input_map() -> void:
	for entry in ControlsText.ENTRIES:
		for action in entry[1]:
			assert_true(InputMap.has_action(action), str(action))


func test_lines_show_the_keys_from_the_input_map() -> void:
	var lines := ControlsText.lines()
	var interact_key := ""
	for event in InputMap.action_get_events(&"interact"):
		if event is InputEventKey:
			interact_key = (event as InputEventKey).as_text_physical_keycode()
	assert_ne(interact_key, "")
	var found := false
	for line in lines:
		if line.begins_with("Interact") and line.contains(interact_key):
			found = true
	assert_true(found, "the Interact line names its real key")


func test_lines_are_ascii_and_mention_touch() -> void:
	var text := "\n".join(ControlsText.lines())
	for i in text.length():
		var code := text.unicode_at(i)
		assert_true(code == 10 or (code >= 32 and code <= 126), "ASCII only at %d" % i)
	assert_string_contains(text.to_lower(), "touch")


func test_key_for_returns_the_first_key_text_and_empty_for_a_missing_action() -> void:
	var expected := ""
	for event in InputMap.action_get_events(&"interact"):
		if event is InputEventKey:
			expected = (event as InputEventKey).as_text_physical_keycode()
			break
	assert_ne(expected, "")
	assert_eq(ControlsText.key_for(&"interact"), expected)
	assert_eq(ControlsText.key_for(&"no_such_action"), "")


func test_keys_for_joins_the_keys_of_several_actions() -> void:
	var text := ControlsText.keys_for([&"move_up", &"move_left"])
	assert_string_contains(text, ControlsText.key_for(&"move_up"))
	assert_string_contains(text, ControlsText.key_for(&"move_left"))
