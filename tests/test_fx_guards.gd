extends GutTest
## Guards the Sprint 13f rules that no single feature test can: gameplay code stays unaware of the screen effects (it only announces),
## the project has no autoload, no effect scales or rotates anything (one pixel size), effects freeze or hide while paused, the comfort
## limits are fixed in the config, and a crowd fight at the stress rate keeps the particle pool, the shakes and the flashes bounded.

## Scripts allowed to name the effect nodes. Everything else may only mention `ImpactEvents` (the announcement).
const ALLOWED := [
	"res://scripts/fx/",
	"res://scripts/main/main.gd",
	"res://scripts/audio/sound_board.gd",
	"res://scripts/world/fx_test.gd",
	"res://scripts/dev/stress_test.gd",
]
const EFFECT_WORDS := ["FxDirector", "BurstLayer", "CameraShake", "ScreenFlash", "LowHealthWarning", "HitIndicator"]


func before_each() -> void:
	FxSettings.reset()


func after_each() -> void:
	FxSettings.reset()


func _files(dir: String, extension: String, found: Array[String] = []) -> Array[String]:
	for file in DirAccess.get_files_at(dir):
		if String(file).ends_with(extension):
			found.append("%s/%s" % [dir, file])
	for folder in DirAccess.get_directories_at(dir):
		_files("%s/%s" % [dir, folder], extension, found)
	return found


func _is_allowed(path: String) -> bool:
	for prefix in ALLOWED:
		if path.begins_with(prefix):
			return true
	return false


func _code(path: String) -> String:
	var lines := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			lines.append(line)
	return "\n".join(lines)


func test_no_script_outside_the_effects_code_references_the_director_burst_layer_shake_or_flash() -> void:
	var offenders: Array[String] = []
	for path in _files("res://scripts", ".gd"):
		if _is_allowed(path):
			continue
		var code := _code(path)
		for word in EFFECT_WORDS:
			if code.contains(word):
				offenders.append("%s uses %s" % [path, word])
	assert_eq(offenders, [] as Array[String], "gameplay code announces events; only the effects code draws them")


func test_the_project_has_no_autoload() -> void:
	var autoloads: Array[String] = []
	for property in ProjectSettings.get_property_list():
		if String(property["name"]).begins_with("autoload/"):
			autoloads.append(String(property["name"]))
	assert_eq(autoloads, [] as Array[String], "the project avoids autoloads; the director lives in main.tscn")


func test_no_effect_scene_scales_or_rotates_a_node() -> void:
	var offenders: Array[String] = []
	for path in _files("res://scenes/fx", ".tscn"):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.begins_with("scale =") or line.begins_with("rotation") or line.begins_with("skew"):
				offenders.append("%s: %s" % [path, line])
	assert_eq(offenders, [] as Array[String], "the game has one pixel size")


func test_no_effect_script_sets_scale_or_rotation() -> void:
	var offenders: Array[String] = []
	for path in _files("res://scripts/fx", ".gd"):
		for line in _code(path).split("\n"):
			if line.contains(".scale =") or line.contains(".rotation =") or line.contains("rotate(") or line.contains(".rotation_degrees"):
				offenders.append("%s: %s" % [path, line.strip_edges()])
	assert_eq(offenders, [] as Array[String], "effects are flipped and offset, never scaled or rotated")


func test_every_effect_is_pausable_or_hides_when_paused() -> void:
	for node in [BurstLayer.new(), CameraShake.new(), ScreenFlash.new(), FxDirector.new(), HitIndicator.new()]:
		assert_ne(node.process_mode, Node.PROCESS_MODE_ALWAYS, "%s freezes with the game" % node.get_class())
		node.free()
	var warning := LowHealthWarning.new()
	add_child_autofree(warning)
	var health := HealthComponent.new()
	health.max_health = 100.0
	add_child_autofree(health)
	warning.bind(health)
	health.take_damage(80.0)
	warning.advance(0.1)
	assert_gt(warning.frame_alpha(), 0.0, "the frame shows at 20% health")
	get_tree().paused = true
	warning.advance(0.1)
	var hidden := warning.frame_alpha()
	get_tree().paused = false
	assert_eq(hidden, 0.0, "the frame hides behind a pause screen")


func test_the_comfort_limits_are_in_the_config() -> void:
	var config := ImpactConfig.default_config()
	assert_lte(config.shake_max_px, 4.0, "shake is at most 4 px")
	assert_lte(config.flash_max_alpha, 0.12, "a flash is at most 12% opaque")
	assert_gte(config.flash_gap_msec, 334, "no more than three flashes in any second")
	assert_lte(config.warn_max_alpha, 0.4, "the frame is at most 40% opaque")
	assert_lte(config.warn_rate_high, 2.0, "nothing pulses faster than 2 Hz")
	assert_gte(config.shake_gap_msec, 80)


func test_the_stress_rate_of_hits_keeps_the_pool_flat() -> void:
	var now := 0
	var burst := BurstLayer.new()
	add_child_autofree(burst)
	var camera := Camera2D.new()
	add_child_autofree(camera)
	var shake := CameraShake.new()
	shake.clock = func() -> int: return now
	add_child_autofree(shake)
	shake.bind(camera)
	var flash := ScreenFlash.new()
	flash.clock = func() -> int: return now
	add_child_autofree(flash)
	var director := FxDirector.new()
	add_child_autofree(director)
	director.setup(burst, shake, flash)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var seconds := 5
	var most := 0
	for tick in seconds * 60:
		now += 16
		director.begin_frame()
		for i in 5:
			ImpactEvents.bus.hit.emit(Vector2(rng.randf() * 400.0, rng.randf() * 300.0), rng.randf(), [&"fire", &"thunder", &"land", &"sea"][rng.randi() % 4])
		burst.call("_process", 0.016)
		shake.advance(0.016)
		flash.advance(0.016)
		most = maxi(most, burst.active_count())
	var duration_msec := seconds * 60 * 16
	assert_lte(most, BurstLayer.CAPACITY, "the pool never passes its cap")
	assert_lte(shake.shakes_made(), duration_msec / 80 + 1, "at most one shake per 80 ms")
	assert_lte(flash.flashes_made(), duration_msec / 334 + 1, "at most one flash per 334 ms")
