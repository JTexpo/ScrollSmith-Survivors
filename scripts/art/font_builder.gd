class_name FontBuilder
extends RefCounted
## Turns a `FontSource` into BMFont sheets Godot imports as a bitmap font. Two builds of one grid: the plain one (white
## ink) and the outlined one (the same ink with a 1 px dark outline). Their advances and line height are identical, because
## the outline sits in the 1 px gap between letters and in the row above and below, so text never reflows between them.

## The outline colour: the palette's dark outline `K`.
const OUTLINE_COLOR := Color("1b1226")
const INK_COLOR := Color.WHITE
## Clear pixels between neighbouring glyph cells on the sheet.
const CELL_GAP := 1
## The top margin of a line, which the outline of the first row grows into.
const TOP_MARGIN := 1

## How many files the last `build_all` wrote.
static var files_written: int = 0


## Every glyph side by side, in code order.
static func build_sheet(source: FontSource, outlined: bool) -> Image:
	var cells := _cells(source, outlined)
	var margin := 1 if outlined else 0
	var image := Image.create(_sheet_width(cells), source.height() + 2 * margin, false, Image.FORMAT_RGBA8)
	for cell in cells:
		var rows: PackedStringArray = source.glyphs[cell["code"]]["rows"]
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "#":
					image.set_pixel(cell["x"] + margin + x, margin + y, INK_COLOR)
		if outlined:
			_outline(image, cell["x"], cell["width"])
	return image


## The BMFont text for the sheet saved as `png_name`.
static func fnt_text(source: FontSource, png_name: String, outlined: bool) -> String:
	var cells := _cells(source, outlined)
	var margin := 1 if outlined else 0
	var lines := PackedStringArray()
	lines.append("info face=\"ui\" size=%d bold=0 italic=0 charset=\"\" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=%d,0 outline=0" % [source.line_height(), CELL_GAP])
	lines.append("common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0" % [source.line_height(), TOP_MARGIN + source.ascent, _sheet_width(cells), source.height() + 2 * margin])
	lines.append("page id=0 file=\"%s\"" % png_name)
	lines.append("chars count=%d" % cells.size())
	for cell in cells:
		var advance: int = source.glyphs[cell["code"]]["advance"]
		lines.append("char id=%d x=%d y=0 width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15" % [
			cell["code"], cell["x"], cell["width"], source.height() + 2 * margin, -margin, TOP_MARGIN - margin, advance])
	return "\n".join(lines) + "\n"


## Builds every `.pixelfont` in `source_dir` into `out_dir` as `<name>_plain` and `<name>_outlined` (a `.png` and a `.fnt`).
## Returns the problems found.
static func build_all(source_dir: String, out_dir: String) -> PackedStringArray:
	files_written = 0
	var problems := PackedStringArray()
	var files := Array(DirAccess.get_files_at(source_dir))
	files.sort()
	for file in files:
		if not String(file).ends_with(".pixelfont"):
			continue
		var path := "%s/%s" % [source_dir, file]
		var source := FontSource.parse(FileAccess.get_file_as_string(path))
		if not source.errors.is_empty():
			for error in source.errors:
				problems.append("%s: %s" % [path, error])
			continue
		var base := String(file).get_basename()
		for outlined in [false, true]:
			var build := "%s_%s" % [base, "outlined" if outlined else "plain"]
			build_sheet(source, outlined).save_png("%s/%s.png" % [out_dir, build])
			var handle := FileAccess.open("%s/%s.fnt" % [out_dir, build], FileAccess.WRITE)
			handle.store_string(fnt_text(source, "%s.png" % build, outlined))
			handle.close()
			files_written += 2
	return problems


## Each glyph's code, left edge on the sheet and cell width, in code order.
static func _cells(source: FontSource, outlined: bool) -> Array[Dictionary]:
	var codes := source.glyphs.keys()
	codes.sort()
	var cells: Array[Dictionary] = []
	var x := 0
	for code in codes:
		var width: int = (source.glyphs[code]["rows"] as PackedStringArray)[0].length() + (2 if outlined else 0)
		cells.append({"code": code, "x": x, "width": width})
		x += width + CELL_GAP
	return cells


static func _sheet_width(cells: Array[Dictionary]) -> int:
	if cells.is_empty():
		return 1
	var last := cells[cells.size() - 1]
	return last["x"] + last["width"]


## Outline colour on every clear pixel within one pixel (all eight sides) of ink, inside one glyph cell.
static func _outline(image: Image, left: int, width: int) -> void:
	var marks: Array[Vector2i] = []
	for y in image.get_height():
		for x in range(left, left + width):
			if image.get_pixel(x, y).a > 0.0:
				continue
			if _touches_ink(image, left, width, x, y):
				marks.append(Vector2i(x, y))
	for mark in marks:
		image.set_pixelv(mark, OUTLINE_COLOR)


static func _touches_ink(image: Image, left: int, width: int, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var ny := y + dy
			if nx >= left and nx < left + width and ny >= 0 and ny < image.get_height() and image.get_pixel(nx, ny) == INK_COLOR:
				return true
	return false
