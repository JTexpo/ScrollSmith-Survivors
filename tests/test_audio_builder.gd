extends GutTest


func _render(text: String) -> PackedFloat32Array:
	var source := SfxSource.parse(text)
	assert_eq(source.errors.size(), 0, str(source.errors))
	return AudioBuilder.render_sfx(source)


func _top(samples: PackedFloat32Array) -> float:
	var best := -INF
	for sample in samples:
		best = maxf(best, sample)
	return best


func _bottom(samples: PackedFloat32Array) -> float:
	var worst := INF
	for sample in samples:
		worst = minf(worst, sample)
	return worst


func _crossings(samples: PackedFloat32Array, from: int, to: int) -> int:
	var count := 0
	for i in range(from + 1, to):
		if (samples[i] >= 0.0) != (samples[i - 1] >= 0.0):
			count += 1
	return count


func test_the_render_is_length_times_rate_samples() -> void:
	assert_eq(_render("length 0.25\nvoice pulse50 440 440 1 0.01 0.1").size(), roundi(0.25 * AudioBuilder.RATE))


func test_every_sample_is_between_minus_one_and_one_even_with_many_loud_voices() -> void:
	var text := "length 0.2\n"
	for i in 8:
		text += "voice pulse50 %d %d 1 0.001 0.15\n" % [220 + i * 50, 220 + i * 50]
	for sample in _render(text):
		assert_between(sample, -1.0, 1.0)


func test_the_same_recipe_renders_the_same_samples_twice() -> void:
	var text := "length 0.3\nvoice noise 0 0 0.6 0.01 0.2\nvoice saw 300 900 0.5 0.01 0.2 vibrato 5 0.3\n"
	assert_true(_render(text) == _render(text))


func test_a_square_voice_swings_both_ways_and_a_silent_volume_is_silent() -> void:
	var loud := _render("length 0.1\nvoice pulse50 440 440 0.8 0.001 0.09")
	assert_gt(_top(loud), 0.3)
	assert_lt(_bottom(loud), -0.3)
	var quiet := _render("length 0.1\nvoice pulse50 440 440 0 0.001 0.09")
	assert_eq(_top(quiet), 0.0)
	assert_eq(_bottom(quiet), 0.0)


func test_a_delayed_voice_is_silent_until_its_delay() -> void:
	var samples := _render("length 0.4\nvoice pulse50 440 440 1 0.001 0.1 delay 0.2")
	for i in roundi(0.19 * AudioBuilder.RATE):
		assert_eq(samples[i], 0.0)
	var later := 0.0
	for i in range(roundi(0.2 * AudioBuilder.RATE), samples.size()):
		later = maxf(later, absf(samples[i]))
	assert_gt(later, 0.1)


func test_pitch_slides_from_start_to_end() -> void:
	var samples := _render("length 0.5\nvoice pulse50 200 1600 1 0.001 0.499")
	var tenth := samples.size() / 10
	assert_gt(_crossings(samples, samples.size() - tenth, samples.size()), _crossings(samples, 0, tenth) * 3)


func test_the_envelope_starts_and_ends_at_zero() -> void:
	var samples := _render("length 0.2\nvoice pulse50 440 440 1 0.02 0.15")
	assert_eq(samples[0], 0.0)
	var end := roundi(0.17 * AudioBuilder.RATE)
	assert_lt(absf(samples[end - 1]), 0.02)


func test_the_triangle_is_smoother_than_the_pulse() -> void:
	var triangle := _render("length 0.1\nvoice triangle 440 440 1 0.001 0.09")
	var pulse := _render("length 0.1\nvoice pulse50 440 440 1 0.001 0.09")
	var triangle_step := 0.0
	var pulse_step := 0.0
	for i in range(1, triangle.size()):
		triangle_step += absf(triangle[i] - triangle[i - 1])
		pulse_step += absf(pulse[i] - pulse[i - 1])
	assert_lt(triangle_step, pulse_step)


func _u32(bytes: PackedByteArray, at: int) -> int:
	return bytes.decode_u32(at)


func test_the_wav_has_a_riff_header_the_right_size_and_rate() -> void:
	var samples := PackedFloat32Array([0.0, 0.5, -0.5, 1.0])
	var wav := WavWriter.encode(samples, 22050)
	assert_eq(wav.slice(0, 4).get_string_from_ascii(), "RIFF")
	assert_eq(wav.slice(8, 12).get_string_from_ascii(), "WAVE")
	assert_eq(wav.slice(12, 16).get_string_from_ascii(), "fmt ")
	assert_eq(wav.decode_u16(20), 1, "PCM")
	assert_eq(wav.decode_u16(22), 1, "mono")
	assert_eq(_u32(wav, 24), 22050)
	assert_eq(wav.decode_u16(34), 16)
	assert_eq(wav.slice(36, 40).get_string_from_ascii(), "data")
	assert_eq(_u32(wav, 40), 8)
	assert_eq(_u32(wav, 4), wav.size() - 8)
	assert_eq(wav.decode_s16(44 + 2), 16384)
	assert_eq(wav.decode_s16(44 + 6), 32767)


func test_a_loop_wav_has_a_smpl_chunk_covering_the_whole_sample_and_a_one_shot_has_none() -> void:
	var samples := PackedFloat32Array()
	samples.resize(100)
	var one_shot := WavWriter.encode(samples, 22050)
	assert_eq(one_shot.size(), 44 + 200)
	var looped := WavWriter.encode(samples, 22050, true)
	assert_eq(looped.slice(244, 248).get_string_from_ascii(), "smpl")
	assert_eq(_u32(looped, 4), looped.size() - 8)
	var loop_start := 244 + 8 + 36
	assert_eq(_u32(looped, 244 + 8 + 28), 1, "one loop")
	assert_eq(_u32(looped, loop_start + 8), 0, "from the first sample")
	assert_eq(_u32(looped, loop_start + 12), 99, "to the last")
