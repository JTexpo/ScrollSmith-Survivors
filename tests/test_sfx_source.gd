extends GutTest

const TEXT := """
# a blip
length 0.3
voice pulse25 440 880 0.8 0.01 0.2
voice noise 0 0 0.3 0 0.05 vibrato 6 0.5 delay 0.1
"""


func test_a_voice_line_parses_every_field() -> void:
	var source := SfxSource.parse(TEXT)
	assert_eq(source.errors.size(), 0, str(source.errors))
	assert_almost_eq(source.length, 0.3, 0.0001)
	assert_eq(source.voices.size(), 2)
	var first := source.voices[0]
	assert_eq(first["wave"], &"pulse25")
	assert_eq(first["start_hz"], 440.0)
	assert_eq(first["end_hz"], 880.0)
	assert_eq(first["volume"], 0.8)
	assert_eq(first["attack"], 0.01)
	assert_eq(first["decay"], 0.2)
	assert_eq(first["vibrato_hz"], 0.0)
	assert_eq(first["delay"], 0.0)


func test_vibrato_and_delay_are_optional_and_parse() -> void:
	var second := SfxSource.parse(TEXT).voices[1]
	assert_eq(second["vibrato_hz"], 6.0)
	assert_eq(second["vibrato_depth"], 0.5)
	assert_eq(second["delay"], 0.1)


func test_an_unknown_wave_is_an_error() -> void:
	assert_gt(SfxSource.parse("length 0.2\nvoice sine 440 440 1 0 0.1").errors.size(), 0)


func test_a_negative_or_missing_number_is_an_error() -> void:
	assert_gt(SfxSource.parse("length 0.2\nvoice pulse50 440 440 -1 0 0.1").errors.size(), 0)
	assert_gt(SfxSource.parse("length 0.2\nvoice pulse50 440 440 1 0").errors.size(), 0)
	assert_gt(SfxSource.parse("length 0.2\nvoice pulse50 0 440 1 0 0.1").errors.size(), 0, "a tonal voice needs a pitch")
	assert_gt(SfxSource.parse("length -1\nvoice pulse50 440 440 1 0 0.1").errors.size(), 0)
	assert_gt(SfxSource.parse("length 0.2\nvoice pulse50 440 440 1 0 0").errors.size(), 0, "a voice must last")


func test_a_recipe_with_no_voice_is_an_error() -> void:
	assert_gt(SfxSource.parse("length 0.2").errors.size(), 0)
	assert_gt(SfxSource.parse("voice pulse50 440 440 1 0 0.1").errors.size(), 0, "a recipe needs a length")


func test_hand_made_marks_the_source() -> void:
	assert_true(SfxSource.parse("hand_made\nlength 0.2\nvoice pulse50 440 440 1 0 0.1").hand_made)
	assert_false(SfxSource.parse(TEXT).hand_made)


func test_comments_and_blank_lines_are_ignored() -> void:
	var source := SfxSource.parse("\n# nothing\n\nlength 0.2\n\nvoice triangle 220 220 1 0 0.1 # trailing\n")
	assert_eq(source.errors.size(), 0, str(source.errors))
	assert_eq(source.voices.size(), 1)
