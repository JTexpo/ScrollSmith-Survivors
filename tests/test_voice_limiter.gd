extends GutTest

const P := SoundData.Priority


func _data(id: StringName, max_voices: int = 4, gap: int = 0, priority: SoundData.Priority = P.NORMAL) -> SoundData:
	var data := SoundData.new()
	data.id = id
	data.max_voices = max_voices
	data.min_gap_msec = gap
	data.priority = priority
	return data


func _start(limiter: VoiceLimiter, data: SoundData, now: int) -> int:
	var index := limiter.request(data, now)
	if index >= 0:
		limiter.started(index, data, now)
	return index


func test_a_free_pool_lets_a_sound_through() -> void:
	var limiter := VoiceLimiter.new(4)
	assert_eq(_start(limiter, _data(&"a"), 0), 0)
	assert_eq(limiter.playing_count(), 1)


func test_the_gap_blocks_a_sound_that_is_too_soon() -> void:
	var limiter := VoiceLimiter.new(4)
	var data := _data(&"a", 4, 100)
	assert_gte(_start(limiter, data, 0), 0)
	assert_eq(_start(limiter, data, 50), -1)
	assert_gte(_start(limiter, data, 100), 0)


func test_max_voices_of_one_sound_blocks_the_next() -> void:
	var limiter := VoiceLimiter.new(8)
	var data := _data(&"a", 2)
	assert_gte(_start(limiter, data, 0), 0)
	assert_gte(_start(limiter, data, 1), 0)
	assert_eq(_start(limiter, data, 2), -1)
	assert_eq(limiter.playing_count_of(&"a"), 2)


func test_a_full_pool_drops_a_low_sound() -> void:
	var limiter := VoiceLimiter.new(2)
	_start(limiter, _data(&"a"), 0)
	_start(limiter, _data(&"b"), 1)
	assert_eq(_start(limiter, _data(&"c", 4, 0, P.LOW), 2), -1)


func test_a_full_pool_makes_a_normal_sound_wait() -> void:
	var limiter := VoiceLimiter.new(2)
	_start(limiter, _data(&"a"), 0)
	_start(limiter, _data(&"b"), 1)
	assert_eq(_start(limiter, _data(&"c"), 2), -1)


func test_a_high_sound_steals_the_oldest_low_voice_first_then_the_oldest() -> void:
	var limiter := VoiceLimiter.new(3)
	var first := _start(limiter, _data(&"normal_old"), 0)
	var low_old := _start(limiter, _data(&"low_old", 4, 0, P.LOW), 1)
	_start(limiter, _data(&"low_new", 4, 0, P.LOW), 2)
	var stolen := limiter.request(_data(&"boss", 1, 0, P.HIGH), 3)
	assert_eq(stolen, low_old, "the oldest low voice goes first, not the older normal one")
	assert_ne(stolen, first)
	var all_normal := VoiceLimiter.new(2)
	var oldest := _start(all_normal, _data(&"x"), 0)
	_start(all_normal, _data(&"y"), 1)
	assert_eq(all_normal.request(_data(&"boss", 1, 0, P.HIGH), 2), oldest, "with no low voice, the oldest voice goes")


func test_finished_voices_become_free() -> void:
	var limiter := VoiceLimiter.new(1)
	var index := _start(limiter, _data(&"a"), 0)
	assert_eq(_start(limiter, _data(&"b"), 1), -1)
	limiter.finished(index)
	assert_eq(limiter.playing_count(), 0)
	assert_eq(_start(limiter, _data(&"b"), 2), 0)


func test_the_busy_fight_rate_never_exceeds_the_caps() -> void:
	var limiter := VoiceLimiter.new(12)
	var die := _data(&"enemy_die", 3, 60, P.LOW)
	var ends: Dictionary = {}
	var starts: Array[int] = []
	var now := 0
	while now <= 1000:
		for index in ends.keys():
			if ends[index] <= now:
				limiter.finished(index)
				ends.erase(index)
		var index := _start(limiter, die, now)
		if index >= 0:
			ends[index] = now + 150
			starts.append(now)
		assert_lte(limiter.playing_count_of(&"enemy_die"), 3)
		now += 16
	for i in range(1, starts.size()):
		assert_gte(starts[i] - starts[i - 1], 60, "never faster than the gap")
	assert_lte(starts.size(), 1000 / 60 + 2)
	assert_gt(starts.size(), 5, "some still get through")


func test_a_blast_warning_always_gets_through_a_pool_full_of_hits() -> void:
	var limiter := VoiceLimiter.new(12)
	var now := 0
	for id in [&"hit_a", &"hit_b", &"hit_c", &"hit_d"]:
		var data := _data(id, 3, 0, P.LOW)
		for i in 3:
			assert_gte(_start(limiter, data, now), 0)
			now += 1
	assert_eq(limiter.playing_count(), 12)
	assert_gte(limiter.request(_data(&"blast_warn", 2, 120, P.HIGH), now), 0, "the warning steals a hit's voice")
