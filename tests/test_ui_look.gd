extends GutTest
## Guards the Sprint 13d look: every piece of UI text uses the theme's font and styles, and every character the game
## prints has a glyph. They scan the sources, so a screen added later is covered too.

const UI_SCRIPTS := "res://scripts/ui"
const UI_SCENES := "res://scenes/ui"


func _files(dir: String, extension: String, found: Array[String] = []) -> Array[String]:
	for file in DirAccess.get_files_at(dir):
		if String(file).ends_with(extension):
			found.append("%s/%s" % [dir, file])
	for folder in DirAccess.get_directories_at(dir):
		_files("%s/%s" % [dir, folder], extension, found)
	return found


## The code of a script without its comments, one entry per line.
func _code_lines(path: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if not line.begins_with("#"):
			lines.append(raw)
	return lines


func _string_literals(line: String) -> Array[String]:
	var found: Array[String] = []
	var regex := RegEx.new()
	regex.compile("\"((?:[^\"\\\\]|\\\\.)*)\"")
	for match in regex.search_all(line):
		found.append(match.get_string(1))
	return found


func _non_ascii(text: String) -> String:
	var bad := ""
	for i in text.length():
		var code := text.unicode_at(i)
		if code > 126 or (code < 32 and code != 10 and code != 9):
			bad += text[i]
	return bad


func test_no_ui_script_or_scene_sets_a_font_size() -> void:
	var offenders: Array[String] = []
	var paths := _files(UI_SCRIPTS, ".gd")
	paths.append_array(_files(UI_SCENES, ".tscn"))
	paths.append_array(_files("res://scenes/interactables", ".tscn"))
	for path in paths:
		var text := FileAccess.get_file_as_string(path)
		if text.contains("font_size") and path != "res://scripts/ui/ui_font.gd":
			offenders.append(path)
	assert_eq(offenders, [] as Array[String], "UI text takes its size from the theme (UiFont.SIZE)")


func test_no_ui_script_draws_with_the_fallback_font() -> void:
	var offenders: Array[String] = []
	for path in _files("res://scripts", ".gd"):
		if path == "res://scripts/ui/ui_font.gd":
			continue
		for line in _code_lines(path):
			if line.contains("ThemeDB.fallback_font"):
				offenders.append(path)
	assert_eq(offenders, [] as Array[String])


func test_no_ui_scene_or_script_styles_a_control_by_hand() -> void:
	var offenders: Array[String] = []
	for path in _files(UI_SCENES, ".tscn"):
		if FileAccess.get_file_as_string(path).contains("theme_override_styles"):
			offenders.append(path)
	for path in _files(UI_SCRIPTS, ".gd"):
		for line in _code_lines(path):
			if line.contains("add_theme_stylebox_override") or line.contains("add_theme_font_override") or line.contains("StyleBoxFlat.new"):
				offenders.append(path)
	assert_eq(offenders, [] as Array[String], "look comes from the theme and its variations")


func test_every_text_the_ui_shows_is_ascii() -> void:
	var offenders: Array[String] = []
	for path in _files(UI_SCRIPTS, ".gd") + _files("res://scripts/shop", ".gd") + _files("res://scripts/points_of_interest", ".gd") + _files("res://scripts/progression", ".gd") + _files("res://scripts/crafting", ".gd"):
		for line in _code_lines(path):
			for literal in _string_literals(line):
				if not _non_ascii(literal).is_empty():
					offenders.append("%s: %s" % [path, literal])
	for path in _files("res://scenes", ".tscn"):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.begins_with("text = ") and not _non_ascii(line).is_empty():
				offenders.append("%s: %s" % [path, line])
	for path in _files("res://resources", ".tres"):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if (line.begins_with("display_name") or line.begins_with("description") or line.begins_with("name = ")) and not _non_ascii(line).is_empty():
				offenders.append("%s: %s" % [path, line])
	assert_eq(offenders, [] as Array[String], "the pixel font has glyphs for ASCII 32 to 126 only")


func test_every_ascii_character_the_game_can_print_has_a_glyph() -> void:
	var font := UiFont.plain()
	for code in range(32, 127):
		assert_true(font.has_char(code), "glyph %d" % code)
	for text in ["Gold 120", "50%", "x2", "+1 copy, cost x2.0", "Lv 20 MAX", "survived 99:59", "(equipped)", "Press R or tap to restart"]:
		for i in text.length():
			assert_true(font.has_char(text.unicode_at(i)), "'%s' in '%s'" % [text[i], text])


func test_the_word_temp_appears_in_no_ui_text() -> void:
	var offenders: Array[String] = []
	for path in _files(UI_SCRIPTS, ".gd"):
		for line in _code_lines(path):
			for literal in _string_literals(line):
				if literal.to_upper().contains("TEMP"):
					offenders.append("%s: %s" % [path, literal])
	for path in _files(UI_SCENES, ".tscn"):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.begins_with("text = ") and line.to_upper().contains("TEMP"):
				offenders.append("%s: %s" % [path, line])
	assert_eq(offenders, [] as Array[String])


func test_no_ui_script_still_calls_itself_temporary() -> void:
	var offenders: Array[String] = []
	for path in _files(UI_SCRIPTS, ".gd"):
		if FileAccess.get_file_as_string(path).contains("TEMPORARY"):
			offenders.append(path)
	assert_eq(offenders, [] as Array[String], "the 13d look replaced every TEMPORARY piece")


func test_the_project_uses_the_game_theme_and_the_theme_uses_the_ui_fonts() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom"), "res://resources/ui/game_theme.tres")
	var theme := load("res://resources/ui/game_theme.tres") as Theme
	assert_eq(theme.default_font.resource_path, UiFont.plain_path)
	assert_eq(theme.default_font_size, UiFont.SIZE)


func _button_text(screen: Node, text: String) -> Button:
	for button in screen.find_children("*", "Button", true, false):
		if (button as Button).text == text:
			return button as Button
	return null


func test_main_action_buttons_are_big_enough_for_a_thumb() -> void:
	assert_gte(UiKit.ACTION_SIZE.x, 64.0)
	assert_gte(UiKit.ACTION_SIZE.y, 28.0)
	for entry in [["res://scenes/ui/shop_screen.tscn", "Close"], ["res://scenes/ui/merchant_screen.tscn", "Close"], ["res://scenes/ui/crafting_screen.tscn", "Confirm"], ["res://scenes/ui/crafting_screen.tscn", "Cancel"]]:
		var screen := (load(entry[0]) as PackedScene).instantiate()
		add_child_autofree(screen)
		var button := _button_text(screen, entry[1])
		assert_not_null(button, "%s %s" % [entry[0], entry[1]])
		assert_gte(button.custom_minimum_size.x, UiKit.ACTION_SIZE.x, "%s %s is wide enough" % [entry[0], entry[1]])
		assert_gte(button.custom_minimum_size.y, UiKit.ACTION_SIZE.y, "%s %s is tall enough" % [entry[0], entry[1]])
	var death := (load("res://scenes/ui/death_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(death)
	var shop_button := death.get_node("ShopButton") as Button
	assert_gte(shop_button.offset_right - shop_button.offset_left, UiKit.ACTION_SIZE.x)
	assert_gte(shop_button.offset_bottom - shop_button.offset_top, UiKit.ACTION_SIZE.y)


func test_hud_touch_targets_are_big_enough() -> void:
	assert_gte(InteractButton.SIZE.x, 64.0)
	assert_gte(InteractButton.SIZE.y, 28.0)
	assert_gte(InventoryButton.SIZE.x, 44.0)
	assert_gte(InventoryButton.SIZE.y, 28.0)
	assert_gte(SpellSlotWidget.SIZE.x, 34.0)
	assert_gte(SpellSlotWidget.SIZE.y, 24.0)
	assert_gte(PotionSlotWidget.SIZE.x, 30.0)
	assert_gte(PotionSlotWidget.SIZE.y, 22.0)

