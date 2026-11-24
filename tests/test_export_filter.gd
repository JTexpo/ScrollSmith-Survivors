extends GutTest
## The web export leaves out sources and developer tools. These tests read `export_presets.cfg` and make sure nothing the
## game loads at run time sits behind an excluded pattern.

const NEW_PATTERNS := ["art/*", "audio/*", "tools/*", "scenes/world/fx_test.tscn", "scenes/world/sound_test.tscn", "scenes/world/stress_test.tscn", "scenes/world/test_arena.tscn"]
const SHIPPED_ROOTS := ["scripts", "scenes", "resources", "assets"]
## Build-time tools that read the sources and run only from the art tool and the tests, never in the game (checked: only
## tools/art/art_builder.gd and tests use ThemeBuilder).
const BUILD_TIME_ONLY := ["res://scripts/art/theme_builder.gd"]
const TEXT_EXTENSIONS := ["gd", "tscn", "tres", "cfg", "godot"]


func _patterns() -> PackedStringArray:
	var config := ConfigFile.new()
	assert_eq(config.load("res://export_presets.cfg"), OK)
	var patterns := PackedStringArray()
	for section in config.get_sections():
		if section.ends_with(".options"):
			continue
		if String(config.get_value(section, "platform", "")) != "Web":
			continue
		for pattern in String(config.get_value(section, "exclude_filter", "")).split(",", false):
			patterns.append(pattern.strip_edges())
	return patterns


func _matches(pattern: String, relative: String) -> bool:
	if pattern.ends_with("/*"):
		return relative.begins_with(pattern.trim_suffix("*"))
	return relative == pattern


func _excluded(patterns: PackedStringArray, relative: String) -> bool:
	for pattern in patterns:
		if _matches(pattern, relative):
			return true
	return false


func _files_under(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		found.append("%s/%s" % [folder, file])
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_files_under("%s/%s" % [folder, sub]))
	return found


## The editor plugin list names GUT, which an export never loads.
func _without_editor_plugins(text: String) -> String:
	var kept := PackedStringArray()
	for line in text.split("\n"):
		if not line.begins_with("enabled="):
			kept.append(line)
	return "\n".join(kept)


## A comment that says how to run a tool names its scene without loading it.
func _without_comments(text: String) -> String:
	var kept := PackedStringArray()
	for line in text.split("\n"):
		if not line.strip_edges().begins_with("#"):
			kept.append(line)
	return "\n".join(kept)


func test_the_filter_excludes_sources_and_dev_scenes() -> void:
	var patterns := _patterns()
	assert_gt(patterns.size(), 0, "the Web preset has an exclude filter")
	for pattern in NEW_PATTERNS:
		assert_true(patterns.has(pattern), "exclude_filter lacks %s" % pattern)


func test_nothing_that_ships_names_an_excluded_path() -> void:
	var patterns := _patterns()
	var checked := 0
	var files := PackedStringArray(["res://project.godot"])
	for root in SHIPPED_ROOTS:
		files.append_array(_files_under("res://%s" % root))
	for file in files:
		var relative := file.trim_prefix("res://")
		if _excluded(patterns, relative) or BUILD_TIME_ONLY.has(file) or not TEXT_EXTENSIONS.has(file.get_extension()):
			continue
		checked += 1
		var text := FileAccess.get_file_as_string(file)
		if file.get_file() == "project.godot":
			text = _without_editor_plugins(text)
		elif file.get_extension() == "gd":
			text = _without_comments(text)
		for pattern in patterns:
			var prefix := "res://" + (pattern.trim_suffix("*") if pattern.ends_with("/*") else pattern)
			assert_false(text.contains(prefix), "%s names %s, which the web export leaves out" % [file, prefix])
	assert_gt(checked, 100, "the walk found the shipped files")


func test_the_entry_points_are_not_excluded() -> void:
	var patterns := _patterns()
	var must_ship := PackedStringArray(["scenes/home/home.tscn", "scenes/main/main.tscn", "scenes/main/main_forest.tscn", "scenes/main/main_maze.tscn", "scenes/world/game_map.tscn", "project.godot"])
	must_ship.append_array(_files_under("res://resources"))
	for file in must_ship:
		var relative := file.trim_prefix("res://")
		assert_false(_excluded(patterns, relative), "%s must ship" % relative)
