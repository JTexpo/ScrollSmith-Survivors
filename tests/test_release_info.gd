extends GutTest
## The version, the copyright line and the licence file a public release needs.


func test_the_project_has_a_valid_version() -> void:
	assert_true(GameVersion.is_valid(GameVersion.current()), "version is '%s'" % GameVersion.current())


func test_is_valid_accepts_and_rejects() -> void:
	for good in ["1.0.0", "0.12.3"]:
		assert_true(GameVersion.is_valid(good), good)
	for bad in ["", "1.0", "1.0.0.0", "v1.0.0", "1.0.x", "1.0.0-beta"]:
		assert_false(GameVersion.is_valid(bad), "'%s'" % bad)


func test_credits_show_the_version_and_the_rights_line() -> void:
	var lines := CreditsText.lines()
	assert_true(lines.has("Version %s" % GameVersion.current()))
	assert_true(lines.has("Copyright 2026 JTexpo. All rights reserved."))


func test_credits_fit_the_page_and_are_ascii() -> void:
	var lines := CreditsText.lines()
	assert_lte(lines.size(), 14)
	for line in lines:
		for i in line.length():
			assert_lt(line.unicode_at(i), 128, "'%s' has a character the font cannot draw" % line)


func test_credits_point_at_the_licences_file() -> void:
	assert_true(CreditsText.lines().any(func(l: String) -> bool: return "licences.txt" in l))


func test_credits_name_the_engine_licence() -> void:
	assert_true(CreditsText.lines().any(func(l: String) -> bool: return "Godot" in l and "MIT" in l))


func test_a_license_file_states_all_rights_reserved_and_names_gut() -> void:
	var text := FileAccess.get_file_as_string("res://LICENSE")
	assert_true("All rights reserved" in text)
	assert_true("addons/gut" in text)
