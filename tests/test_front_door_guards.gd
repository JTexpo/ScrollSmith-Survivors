extends GutTest
## Guards the Sprint 15a rules no single feature test can: no autoload, the settings screen and store stay inside the front-door code,
## the home screen never builds the run scene itself, every new screen takes touches, and everything that must work while paused keeps
## running when the tree is paused.

const ALLOWED := [
	"res://scripts/settings/",
	"res://scripts/ui/settings_screen.gd",
	"res://scripts/ui/pause_menu.gd",
	"res://scripts/home/",
	"res://scripts/main/main.gd",
	"res://scripts/audio/sound_board.gd",
	"res://scripts/ui/perf_overlay.gd",
]
const WORDS := ["SettingsScreen", "SettingsStore", "SettingsEvents"]
const TOUCH_SCREENS := [
	"res://scripts/home/home_screen.gd",
	"res://scripts/ui/settings_screen.gd",
	"res://scripts/ui/confirm_dialog.gd",
	"res://scripts/ui/pause_menu.gd",
	"res://scripts/ui/pause_button.gd",
]
const ALWAYS_SCENES := [
	"res://scenes/ui/pause_menu.tscn",
	"res://scenes/ui/settings_screen.tscn",
	"res://scenes/ui/confirm_dialog.tscn",
	"res://scenes/ui/inventory_panel.tscn",
	"res://scenes/ui/inventory_button.tscn",
]


func _files(dir: String, extension: String, found: Array[String] = []) -> Array[String]:
	for file in DirAccess.get_files_at(dir):
		if String(file).ends_with(extension):
			found.append("%s/%s" % [dir, file])
	for folder in DirAccess.get_directories_at(dir):
		_files("%s/%s" % [dir, folder], extension, found)
	return found


func _code(path: String) -> String:
	var lines := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			lines.append(line)
	return "\n".join(lines)


func _allowed(path: String) -> bool:
	for prefix in ALLOWED:
		if path.begins_with(prefix):
			return true
	return false


func test_the_project_has_no_autoload() -> void:
	var autoloads: Array[String] = []
	for property in ProjectSettings.get_property_list():
		if String(property["name"]).begins_with("autoload/"):
			autoloads.append(String(property["name"]))
	assert_eq(autoloads, [] as Array[String])


func test_no_script_outside_the_front_door_references_the_settings_screen_or_store() -> void:
	var offenders: Array[String] = []
	for path in _files("res://scripts", ".gd"):
		if _allowed(path):
			continue
		var code := _code(path)
		for word in WORDS:
			if code.contains(word):
				offenders.append("%s uses %s" % [path, word])
	assert_eq(offenders, [] as Array[String], "gameplay code stays unaware of the settings screen")


func test_the_home_screen_never_instantiates_the_run_scene_itself() -> void:
	var code := _code("res://scripts/home/home_screen.gd")
	assert_false(code.contains("main.tscn"), "it never names the run scene")
	assert_false(code.contains("Main.new") or code.contains("preload(Scenes.RUN") or code.contains("load(Scenes.RUN"), "it only passes the path to SceneSwitcher")
	assert_true(code.contains("SceneSwitcher.change_to"))


func test_every_new_screen_handles_touch() -> void:
	for path in TOUCH_SCREENS:
		var code := _code(path)
		assert_true(code.contains("InputEventScreenTouch") or code.contains("TouchBridge"), "%s has no touch path" % path)


func test_every_screen_that_must_work_paused_is_always() -> void:
	for path in ALWAYS_SCENES:
		var node := (load(path) as PackedScene).instantiate()
		add_child_autofree(node)
		assert_eq(node.process_mode, Node.PROCESS_MODE_ALWAYS, path)
