extends GutTest

const TEXT := """
ascent 2
descent 1
glyph 65 4
###.
#.#.
###.
glyph 32 3
.
.
.
"""

var _source: FontSource


func before_each() -> void:
	_source = FontSource.parse(TEXT)


func _white(image: Image, x: int, y: int) -> bool:
	return image.get_pixel(x, y) == Color.WHITE


func test_the_plain_sheet_is_the_ink_in_white() -> void:
	var sheet := FontBuilder.build_sheet(_source, false)
	assert_eq(sheet.get_height(), 3)
	var ink := 0
	for y in sheet.get_height():
		for x in sheet.get_width():
			if sheet.get_pixel(x, y).a > 0.0:
				assert_true(_white(sheet, x, y), "plain ink is white")
				ink += 1
	assert_eq(ink, 8)


func test_the_outlined_sheet_is_the_plain_ink_plus_a_one_pixel_outline() -> void:
	var plain := FontBuilder.build_sheet(_source, false)
	var outlined := FontBuilder.build_sheet(_source, true)
	assert_eq(outlined.get_height(), plain.get_height() + 2)
	var ink := 0
	var edge := 0
	for y in outlined.get_height():
		for x in outlined.get_width():
			var pixel := outlined.get_pixel(x, y)
			if pixel == Color.WHITE:
				ink += 1
			elif pixel.a > 0.0:
				assert_eq(pixel, FontBuilder.OUTLINE_COLOR)
				edge += 1
	assert_eq(ink, 8, "the same ink")
	assert_gt(edge, 0)
	# Every outline pixel touches an ink pixel on one of its eight sides.
	for y in outlined.get_height():
		for x in outlined.get_width():
			if outlined.get_pixel(x, y) == FontBuilder.OUTLINE_COLOR:
				var touches := false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < outlined.get_width() and ny < outlined.get_height() and _white(outlined, nx, ny):
							touches = true
				assert_true(touches, "outline pixel %d,%d touches ink" % [x, y])


func _chars(text: String) -> Dictionary:
	var found := {}
	for line in text.split("\n"):
		if line.begins_with("char id="):
			var fields := {}
			for part in line.split(" ", false):
				var pair := part.split("=")
				if pair.size() == 2:
					fields[pair[0]] = int(pair[1])
			found[fields["id"]] = fields
	return found


func test_both_builds_have_the_same_advances_and_line_height() -> void:
	var plain_text := FontBuilder.fnt_text(_source, "x.png", false)
	var outlined_text := FontBuilder.fnt_text(_source, "x.png", true)
	var plain := _chars(plain_text)
	var outlined := _chars(outlined_text)
	assert_eq(plain.keys(), outlined.keys())
	for id in plain:
		assert_eq(plain[id]["xadvance"], outlined[id]["xadvance"])
	assert_true(plain_text.contains("lineHeight=%d" % _source.line_height()))
	assert_true(outlined_text.contains("lineHeight=%d" % _source.line_height()))


func test_the_outlined_ink_sits_where_the_plain_ink_sits() -> void:
	var plain: Dictionary = _chars(FontBuilder.fnt_text(_source, "x.png", false))[65]
	var outlined: Dictionary = _chars(FontBuilder.fnt_text(_source, "x.png", true))[65]
	assert_eq(outlined["xoffset"], plain["xoffset"] - 1)
	assert_eq(outlined["yoffset"], plain["yoffset"] - 1)
	assert_eq(outlined["width"], plain["width"] + 2)
	assert_eq(outlined["height"], plain["height"] + 2)


func test_fnt_text_lists_one_char_line_per_glyph() -> void:
	var text := FontBuilder.fnt_text(_source, "x.png", false)
	assert_eq(_chars(text).size(), 2)
	assert_true(text.contains("chars count=2"))
	assert_true(text.contains("file=\"x.png\""))


func test_glyph_cells_do_not_overlap_on_the_sheet() -> void:
	for outlined in [false, true]:
		var cells := _chars(FontBuilder.fnt_text(_source, "x.png", outlined))
		var spans: Array = []
		for id in cells:
			spans.append(Vector2i(cells[id]["x"], cells[id]["x"] + cells[id]["width"]))
		spans.sort_custom(func(a, b): return a.x < b.x)
		for i in range(1, spans.size()):
			assert_gte(spans[i].x, spans[i - 1].y, "cells overlap")
