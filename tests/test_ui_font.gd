extends GutTest

var _saved_plain: String
var _saved_outlined: String


func before_each() -> void:
	_saved_plain = UiFont.plain_path
	_saved_outlined = UiFont.outlined_path


func after_each() -> void:
	UiFont.plain_path = _saved_plain
	UiFont.outlined_path = _saved_outlined


func _source() -> FontSource:
	return FontSource.parse(FileAccess.get_file_as_string("res://art/fonts/ui.pixelfont"))


func test_the_font_source_has_no_errors() -> void:
	assert_eq(_source().errors.size(), 0, str(_source().errors))


func test_every_printable_ascii_character_has_a_glyph_in_both_builds() -> void:
	for font in [UiFont.plain(), UiFont.outlined()]:
		for code in range(32, 127):
			assert_true((font as Font).has_char(code), "no glyph for %d" % code)


func test_a_string_measures_the_sum_of_its_advances() -> void:
	var source := _source()
	var advance: int = source.glyphs[ord("H")]["advance"]
	for font in [UiFont.plain(), UiFont.outlined()]:
		var width := (font as Font).get_string_size("HHHH", HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE).x
		assert_eq(width, 4.0 * advance)


func test_both_builds_measure_every_string_alike() -> void:
	for text in ["The quick brown fox", "Gold 120", "Lv 4 MAX", "50%", "Fire Cone x2"]:
		var plain := UiFont.plain().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE)
		var outlined := UiFont.outlined().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.SIZE)
		assert_eq(plain, outlined, text)


func test_the_size_is_the_line_height() -> void:
	assert_eq(UiFont.SIZE, _source().line_height())


func test_the_font_falls_back_when_the_file_is_missing() -> void:
	UiFont.plain_path = "res://assets/fonts/no_such_font.fnt"
	UiFont.outlined_path = "res://assets/fonts/no_such_font.fnt"
	assert_eq(UiFont.plain(), ThemeDB.fallback_font)
	assert_eq(UiFont.outlined(), ThemeDB.fallback_font)
