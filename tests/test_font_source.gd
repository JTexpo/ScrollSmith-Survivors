extends GutTest

const TEXT := """
# a tiny font
ascent 2
descent 1
glyph 65 4
###.
#.#.
###.
glyph 105 2
#
.
#
"""


func test_a_glyph_block_parses_its_rows_and_advance() -> void:
	var source := FontSource.parse(TEXT)
	assert_eq(source.errors.size(), 0, str(source.errors))
	assert_eq(source.ascent, 2)
	assert_eq(source.descent, 1)
	assert_eq(source.glyphs.size(), 2)
	assert_eq(source.glyphs[65]["advance"], 4)
	assert_eq((source.glyphs[65]["rows"] as PackedStringArray).size(), 3)
	assert_eq(source.glyphs[105]["rows"][2], "#")


func test_height_and_line_height_follow_ascent_and_descent() -> void:
	var source := FontSource.parse(TEXT)
	assert_eq(source.height(), 3)
	assert_eq(source.line_height(), 4)


func test_a_glyph_with_the_wrong_row_count_is_an_error() -> void:
	var source := FontSource.parse("ascent 2\ndescent 1\nglyph 65 4\n###.\n#.#.\n")
	assert_gt(source.errors.size(), 0)


func test_a_row_with_a_character_other_than_hash_or_dot_is_an_error() -> void:
	var source := FontSource.parse("ascent 1\ndescent 0\nglyph 65 3\n#x#\n")
	assert_gt(source.errors.size(), 0)


func test_a_duplicate_glyph_code_is_an_error() -> void:
	var source := FontSource.parse("ascent 1\ndescent 0\nglyph 65 3\n#\nglyph 65 3\n#\n")
	assert_gt(source.errors.size(), 0)


func test_rows_of_one_glyph_must_share_a_width() -> void:
	var source := FontSource.parse("ascent 2\ndescent 0\nglyph 65 4\n##\n#\n")
	assert_gt(source.errors.size(), 0)


func test_a_missing_ascent_or_descent_is_an_error() -> void:
	assert_gt(FontSource.parse("glyph 65 3\n#\n").errors.size(), 0)
