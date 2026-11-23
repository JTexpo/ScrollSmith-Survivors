extends GutTest

const TEXT := """
# a tiny tune
tempo 120
loop
channel pulse25 0.5
C4 . E4 - | G4 . . -
channel triangle 0.6
C2 . . . G2 . . .
"""


func test_a_channel_and_its_cells_parse() -> void:
	var source := TuneSource.parse(TEXT)
	assert_eq(source.errors.size(), 0, str(source.errors))
	assert_eq(source.channels.size(), 2)
	assert_eq(source.channels[0]["wave"], &"pulse25")
	assert_eq(source.channels[0]["volume"], 0.5)
	assert_eq(source.channels[1]["wave"], &"triangle")
	assert_eq((source.channels[0]["cells"] as PackedStringArray).size(), 8)


func test_bar_lines_are_ignored_and_cells_split_on_spaces() -> void:
	var cells: PackedStringArray = TuneSource.parse(TEXT).channels[0]["cells"]
	assert_eq(cells[0], "C4")
	assert_eq(cells[4], "G4")
	assert_false(cells.has("|"))


func test_note_names_map_to_frequencies() -> void:
	assert_almost_eq(TuneSource.note_hz("A4"), 440.0, 0.01)
	assert_almost_eq(TuneSource.note_hz("A5"), 880.0, 0.01)
	assert_almost_eq(TuneSource.note_hz("C4"), 261.63, 0.05)
	assert_almost_eq(TuneSource.note_hz("C#4"), TuneSource.note_hz("Db4"), 0.001)
	assert_gt(TuneSource.note_hz("C#4"), TuneSource.note_hz("C4"))


func test_rests_and_holds_have_no_frequency() -> void:
	assert_eq(TuneSource.note_hz("-"), 0.0)
	assert_eq(TuneSource.note_hz("."), 0.0)
	assert_eq(TuneSource.note_hz("x"), 0.0)


func test_channels_of_different_lengths_are_an_error() -> void:
	assert_gt(TuneSource.parse("tempo 120\nchannel pulse50 0.5\nC4 D4\nchannel triangle 0.5\nC2").errors.size(), 0)


func test_a_bad_note_name_is_an_error() -> void:
	assert_gt(TuneSource.parse("tempo 120\nchannel pulse50 0.5\nC4 H4").errors.size(), 0)
	assert_gt(TuneSource.parse("tempo 120\nchannel pulse50 0.5\nC4 Q").errors.size(), 0)


func test_tempo_must_be_positive() -> void:
	assert_gt(TuneSource.parse("tempo 0\nchannel pulse50 0.5\nC4").errors.size(), 0)
	assert_gt(TuneSource.parse("channel pulse50 0.5\nC4").errors.size(), 0, "a tune needs a tempo")


func test_duration_follows_tempo_and_steps() -> void:
	var source := TuneSource.parse("tempo 120\nchannel pulse50 0.5\nC4 . . . D4 . . . E4 . . . F4 . . .")
	assert_eq(source.step_count(), 16)
	assert_almost_eq(source.duration(), 2.0, 0.0001)


func test_loop_and_hand_made_lines_are_read() -> void:
	assert_true(TuneSource.parse(TEXT).loops)
	assert_false(TuneSource.parse("tempo 120\nchannel pulse50 0.5\nC4").loops)
	assert_true(TuneSource.parse("hand_made\ntempo 120\nchannel pulse50 0.5\nC4").hand_made)


func test_a_cell_before_any_channel_is_an_error_and_a_tune_needs_a_channel() -> void:
	assert_gt(TuneSource.parse("tempo 120\nC4 D4").errors.size(), 0)
	assert_gt(TuneSource.parse("tempo 120").errors.size(), 0)


func test_a_noise_channel_takes_x_and_rests_only() -> void:
	assert_eq(TuneSource.parse("tempo 120\nchannel noise 0.3\nx - x -").errors.size(), 0)
	assert_gt(TuneSource.parse("tempo 120\nchannel noise 0.3\nC4 - x -").errors.size(), 0)
