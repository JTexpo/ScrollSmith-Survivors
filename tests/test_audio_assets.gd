extends GutTest
## Guards the audio pipeline: every recipe and tune parses, every committed WAV is exactly what the builder renders (so none is
## stale), none is silent or clips, loops loop, the total stays small, and nothing is left over.

const SOURCE_DIR := "res://audio"
const OUT_DIR := "res://assets/audio"
const TEMP := "res://.godot/audio_tests"
const MAX_BYTES := 3 * 1024 * 1024


func after_each() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEMP))


func _remove_tree(absolute: String) -> void:
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	for folder in DirAccess.get_directories_at(absolute):
		_remove_tree("%s/%s" % [absolute, folder])
	DirAccess.remove_absolute(absolute)


## [{"id": StringName, "kind": "sfx" or "tune", "path": String}], sorted by id.
func _sources() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for file in DirAccess.get_files_at(SOURCE_DIR + "/sounds"):
		if String(file).ends_with(".sfx"):
			found.append({"id": StringName(String(file).get_basename()), "kind": "sfx", "path": "%s/sounds/%s" % [SOURCE_DIR, file]})
	for file in DirAccess.get_files_at(SOURCE_DIR + "/music"):
		if String(file).ends_with(".tune"):
			found.append({"id": StringName(String(file).get_basename()), "kind": "tune", "path": "%s/music/%s" % [SOURCE_DIR, file]})
	found.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	return found


func _samples_of(wav: PackedByteArray) -> PackedFloat32Array:
	var size := wav.decode_u32(40) / 2
	var samples := PackedFloat32Array()
	samples.resize(size)
	for i in size:
		samples[i] = float(wav.decode_s16(44 + i * 2)) / 32767.0
	return samples


func _expected_wav(entry: Dictionary) -> PackedByteArray:
	var text := FileAccess.get_file_as_string(entry["path"])
	if entry["kind"] == "sfx":
		return WavWriter.encode(AudioBuilder.render_sfx(SfxSource.parse(text)), AudioBuilder.RATE)
	var tune := TuneSource.parse(text)
	return WavWriter.encode(AudioBuilder.render_tune(tune), AudioBuilder.RATE, tune.loops)


func _is_hand_made(entry: Dictionary) -> bool:
	var text := FileAccess.get_file_as_string(entry["path"])
	return SfxSource.parse(text).hand_made if entry["kind"] == "sfx" else TuneSource.parse(text).hand_made


func test_there_are_sources() -> void:
	assert_gt(_sources().size(), 0)


func test_every_source_parses_with_no_errors() -> void:
	for entry in _sources():
		var text := FileAccess.get_file_as_string(entry["path"])
		var errors := SfxSource.parse(text).errors if entry["kind"] == "sfx" else TuneSource.parse(text).errors
		assert_eq(errors.size(), 0, "%s: %s" % [entry["id"], str(errors)])


func test_every_source_has_a_wav() -> void:
	for entry in _sources():
		assert_true(FileAccess.file_exists("%s/%s.wav" % [OUT_DIR, entry["id"]]), "missing %s.wav: run the art tool" % entry["id"])


func test_each_committed_wav_equals_what_the_tool_renders() -> void:
	for entry in _sources():
		if _is_hand_made(entry):
			continue
		var committed := FileAccess.get_file_as_bytes("%s/%s.wav" % [OUT_DIR, entry["id"]])
		assert_true(committed == _expected_wav(entry), "%s.wav is stale: run the art tool" % entry["id"])


func test_no_wav_belongs_to_nothing() -> void:
	var wanted := {}
	for entry in _sources():
		wanted["%s.wav" % entry["id"]] = true
	for file in DirAccess.get_files_at(OUT_DIR):
		if String(file).ends_with(".wav"):
			assert_true(wanted.has(String(file)), "%s has no source: delete it, because the game would still load it" % file)


func test_the_committed_audio_is_under_three_megabytes() -> void:
	var total := 0
	for file in DirAccess.get_files_at(OUT_DIR):
		if String(file).ends_with(".wav"):
			total += FileAccess.get_file_as_bytes("%s/%s" % [OUT_DIR, file]).size()
	assert_lt(total, MAX_BYTES, "the committed audio is %d bytes" % total)


func test_no_sound_is_silent_and_none_clips_much() -> void:
	for entry in _sources():
		var samples := _samples_of(FileAccess.get_file_as_bytes("%s/%s.wav" % [OUT_DIR, entry["id"]]))
		var peak := 0.0
		var clipped := 0
		for sample in samples:
			peak = maxf(peak, absf(sample))
			if absf(sample) >= 0.999:
				clipped += 1
		assert_gt(peak, 0.05, "%s is silent" % entry["id"])
		assert_lt(float(clipped) / float(samples.size()), 0.02, "%s clips" % entry["id"])


func test_tunes_that_loop_carry_a_loop_chunk_and_sounds_do_not() -> void:
	for entry in _sources():
		var wav := FileAccess.get_file_as_bytes("%s/%s.wav" % [OUT_DIR, entry["id"]])
		var data_end := 44 + wav.decode_u32(40)
		var has_loop := wav.size() > data_end and wav.slice(data_end, data_end + 4).get_string_from_ascii() == "smpl"
		var should_loop: bool = entry["kind"] == "tune" and TuneSource.parse(FileAccess.get_file_as_string(entry["path"])).loops
		assert_eq(has_loop, should_loop, str(entry["id"]))


func test_hand_made_sources_are_not_rebuilt_and_need_their_wav() -> void:
	var base := ProjectSettings.globalize_path(TEMP + "/hm")
	DirAccess.make_dir_recursive_absolute(base + "/src/sounds")
	DirAccess.make_dir_recursive_absolute(base + "/src/music")
	DirAccess.make_dir_recursive_absolute(base + "/out")
	var recipe := FileAccess.open(TEMP + "/hm/src/sounds/mine.sfx", FileAccess.WRITE)
	recipe.store_string("hand_made\nlength 0.1\nvoice pulse50 440 440 1 0 0.05\n")
	recipe.close()
	var problems := AudioBuilder.build_all(TEMP + "/hm/src", TEMP + "/hm/out")
	assert_eq(problems.size(), 1, "a hand_made recipe without its WAV is reported: %s" % str(problems))
	var wav := FileAccess.open(TEMP + "/hm/out/mine.wav", FileAccess.WRITE)
	wav.store_buffer(PackedByteArray([1, 2, 3, 4]))
	wav.close()
	problems = AudioBuilder.build_all(TEMP + "/hm/src", TEMP + "/hm/out")
	assert_eq(problems.size(), 0, str(problems))
	assert_true(FileAccess.get_file_as_bytes(TEMP + "/hm/out/mine.wav") == PackedByteArray([1, 2, 3, 4]), "the drawn file is left alone")


func test_build_all_writes_a_wav_per_source_and_reports_a_bad_one() -> void:
	var base := ProjectSettings.globalize_path(TEMP + "/b")
	DirAccess.make_dir_recursive_absolute(base + "/src/sounds")
	DirAccess.make_dir_recursive_absolute(base + "/src/music")
	DirAccess.make_dir_recursive_absolute(base + "/out")
	var good := FileAccess.open(TEMP + "/b/src/sounds/good.sfx", FileAccess.WRITE)
	good.store_string("length 0.1\nvoice pulse50 440 440 1 0.001 0.05\n")
	good.close()
	var bad := FileAccess.open(TEMP + "/b/src/sounds/bad.sfx", FileAccess.WRITE)
	bad.store_string("length 0.1\nvoice banana 440 440 1 0 0.05\n")
	bad.close()
	var tune := FileAccess.open(TEMP + "/b/src/music/loopy.tune", FileAccess.WRITE)
	tune.store_string("tempo 120\nloop\nchannel pulse50 0.5\nC4 . . .\n")
	tune.close()
	var problems := AudioBuilder.build_all(TEMP + "/b/src", TEMP + "/b/out")
	assert_gte(problems.size(), 1, str(problems))
	for problem in problems:
		assert_string_contains(problem, "bad.sfx")
	assert_true(FileAccess.file_exists(TEMP + "/b/out/good.wav"))
	assert_true(FileAccess.file_exists(TEMP + "/b/out/loopy.wav"))
	assert_false(FileAccess.file_exists(TEMP + "/b/out/bad.wav"), "a bad source writes nothing")


func _seconds(id: StringName) -> float:
	return float(_samples_of(FileAccess.get_file_as_bytes("%s/%s.wav" % [OUT_DIR, id])).size()) / float(AudioBuilder.RATE)


func test_every_sound_is_short() -> void:
	for entry in _sources():
		if entry["kind"] != "sfx":
			continue
		var limit := 2.5 if entry["id"] in [&"level_up", &"player_die", &"boss_spawn", &"boss_die"] else 1.5
		assert_lt(_seconds(entry["id"]), limit, str(entry["id"]))


func test_the_busy_sounds_are_very_short() -> void:
	for id in [&"hit_fire", &"hit_thunder", &"hit_land", &"hit_sea", &"hit_strong", &"hit_resisted", &"enemy_die", &"step", &"pickup_xp", &"ui_click", &"ui_hover"]:
		assert_lt(_seconds(id), 0.35, str(id))


func _tune(id: StringName) -> TuneSource:
	return TuneSource.parse(FileAccess.get_file_as_string("%s/music/%s.tune" % [SOURCE_DIR, id]))


func test_the_music_tunes_loop() -> void:
	for id in [&"music_run", &"music_boss"]:
		assert_true(_tune(id).loops, str(id))
		var wav := FileAccess.get_file_as_bytes("%s/%s.wav" % [OUT_DIR, id])
		assert_eq(wav.slice(44 + wav.decode_u32(40), 48 + wav.decode_u32(40)).get_string_from_ascii(), "smpl", "%s carries a loop chunk" % id)


func test_the_run_loop_is_between_20_and_45_seconds() -> void:
	assert_between(_tune(&"music_run").duration(), 20.0, 45.0)
	assert_between(_tune(&"music_boss").duration(), 15.0, 45.0)


func test_the_boss_loop_is_faster_than_the_run_loop() -> void:
	assert_gt(_tune(&"music_boss").tempo, _tune(&"music_run").tempo + 15.0)


func test_each_loop_has_at_least_four_voices_of_chiptune() -> void:
	for id in [&"music_run", &"music_boss"]:
		var waves := {}
		for channel in _tune(id).channels:
			waves[channel["wave"]] = true
		assert_gte(_tune(id).channels.size(), 4, "%s has melody, arpeggio, bass and drums" % id)
		assert_true(waves.has(&"triangle") and waves.has(&"noise"), "%s has a bass and drums" % id)


func test_no_voice_outlasts_its_recipes_length() -> void:
	for entry in _sources():
		if entry["kind"] != "sfx":
			continue
		var source := SfxSource.parse(FileAccess.get_file_as_string(entry["path"]))
		for voice in source.voices:
			var ends: float = float(voice["delay"]) + float(voice["attack"]) + float(voice["decay"])
			assert_lte(ends, source.length + 0.001, "%s: a voice ends at %.3f s but the recipe is %.3f s, so it would be cut off with a click" % [entry["id"], ends, source.length])
