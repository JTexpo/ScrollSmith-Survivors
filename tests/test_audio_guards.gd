extends GutTest
## Guards the Sprint 13e rules that no single feature test can: gameplay code stays unaware of audio, the project has no new
## autoload, every sound the game defines is used, and a crowd fight keeps the voice pool flat while important sounds still play.

## Scripts allowed to touch the sound board or the audio server.
const ALLOWED := [
	"res://scripts/audio/",
	"res://scripts/main/main.gd",
	"res://scripts/world/sound_test.gd",
	"res://scripts/dev/stress_test.gd",
]
const AUDIO_WORDS := ["SoundBoard", "AudioStreamPlayer", "AudioServer", "SoundLibrary"]
## Sounds that are deliberately not used yet, with the reason. Empty: every sound has a route.
const SPARE := {}


func _scripts(dir: String, found: Array[String] = []) -> Array[String]:
	for file in DirAccess.get_files_at(dir):
		if String(file).ends_with(".gd"):
			found.append("%s/%s" % [dir, file])
	for folder in DirAccess.get_directories_at(dir):
		_scripts("%s/%s" % [dir, folder], found)
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


func test_no_script_outside_the_audio_code_references_the_sound_board_or_an_audio_player() -> void:
	var offenders: Array[String] = []
	for path in _scripts("res://scripts"):
		if _is_allowed(path):
			continue
		var code := _code(path)
		for word in AUDIO_WORDS:
			if code.contains(word):
				offenders.append("%s uses %s" % [path, word])
	assert_eq(offenders, [] as Array[String], "gameplay code announces events; only the board plays sounds")


func test_the_project_has_no_autoload() -> void:
	var autoloads: Array[String] = []
	for property in ProjectSettings.get_property_list():
		if String(property["name"]).begins_with("autoload/"):
			autoloads.append(String(property["name"]))
	assert_eq(autoloads, [] as Array[String], "the project avoids autoloads; the board lives in main.tscn")


func test_every_sound_id_is_used_by_a_route_or_listed_as_spare() -> void:
	var source := _code("res://scripts/audio/sound_board.gd")
	var constants := (load("res://scripts/audio/sound_id.gd") as GDScript).get_script_constant_map()
	for key in constants:
		if not constants[key] is StringName:
			continue
		var id := String(constants[key])
		if SPARE.has(id):
			continue
		var by_name := source.contains("SoundId.%s" % String(key))
		var by_family := (id.begins_with("cast_") and source.contains("\"cast_\"")) or (id.begins_with("hit_") and id != "hit_strong" and id != "hit_resisted" and source.contains("\"hit_\""))
		assert_true(by_name or by_family, "%s has no route in the sound board" % id)


func test_the_stress_rate_of_events_keeps_the_pool_flat_and_important_sounds_still_play() -> void:
	var now := 0
	var board := load("res://scenes/audio/sound_board.tscn").instantiate() as SoundBoard
	board.clock = func() -> int: return now
	add_child_autofree(board)
	board.unlock()
	var children := board.get_child_count()
	for tick in 300:
		now += 16
		for i in 5:
			board.play(SoundId.HIT_FIRE)
			board.play(SoundId.ENEMY_DIE)
			board.play(SoundId.PICKUP_XP)
		assert_lte(board.voices_in_use(), SoundBoard.VOICES)
	assert_eq(board.get_child_count(), children, "the pool never grows")
	assert_gt(board.calls_dropped(), 1000, "a crowd is meant to be refused almost everywhere")
	var before := board.plays_started()
	now += 500
	board.play(SoundId.BLAST_WARN)
	assert_eq(board.plays_started(), before + 1, "a blast warning still gets a voice in the middle of a crowd")
	now += 500
	board.play(SoundId.LEVEL_UP)
	assert_eq(board.plays_started(), before + 2, "so does a level-up")
	board.stop_all()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), 0.0)
