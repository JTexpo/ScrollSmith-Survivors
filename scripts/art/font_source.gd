class_name FontSource
extends RefCounted
## One pixel font read from a `.pixelfont` text file: `ascent <n>` and `descent <n>` (rows above and below the baseline), then
## one block per character, `glyph <code> <advance>` followed by `ascent + descent` rows of `#` (ink) and `.` (clear), all
## the same width. `<advance>` is the pen step to the next character, so it holds the 1 px gap between letters. A line that
## starts with `# ` (a hash and a space) is a comment; a row never has a space, so a row of one `#` is still a row.
## Mistakes are collected in `errors`, never thrown.

var errors := PackedStringArray()
var ascent: int = -1
var descent: int = -1
## Character code (int) to {"advance": int, "rows": PackedStringArray}.
var glyphs: Dictionary = {}

var _code: int = -1
var _advance: int = 0
var _rows := PackedStringArray()


static func parse(text: String) -> FontSource:
	var source := FontSource.new()
	var number := 0
	for raw in text.split("\n"):
		number += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("# "):
			continue
		if line.begins_with("ascent "):
			source.ascent = _whole(line, 1)
		elif line.begins_with("descent "):
			source.descent = _whole(line, 1)
		elif line.begins_with("glyph "):
			source._finish_glyph()
			source._start_glyph(number, line)
		elif source._code < 0:
			source.errors.append("line %d: a row before any 'glyph'" % number)
		else:
			source._rows.append(line)
	source._finish_glyph()
	if source.ascent < 0:
		source.errors.append("missing a valid 'ascent' line")
	if source.descent < 0:
		source.errors.append("missing a valid 'descent' line")
	return source


## Rows of ink and clear pixels in one glyph block.
func height() -> int:
	return ascent + descent


## The step from one line to the next: the glyph rows plus one row of leading.
func line_height() -> int:
	return height() + 1


static func _whole(line: String, index: int) -> int:
	var parts := line.replace("\t", " ").split(" ", false)
	if parts.size() <= index or not parts[index].is_valid_int() or int(parts[index]) < 0:
		return -1
	return int(parts[index])


func _start_glyph(number: int, line: String) -> void:
	var parts := line.replace("\t", " ").split(" ", false)
	if parts.size() != 3 or not parts[1].is_valid_int() or not parts[2].is_valid_int() or int(parts[2]) < 0:
		errors.append("line %d: expected 'glyph <code> <advance>'" % number)
		_code = -2
		return
	_code = int(parts[1])
	_advance = int(parts[2])
	_rows = PackedStringArray()
	if glyphs.has(_code):
		errors.append("line %d: the glyph %d is defined twice" % [number, _code])


func _finish_glyph() -> void:
	if _code == -1:
		return
	if _code >= 0 and ascent >= 0 and descent >= 0:
		if _rows.size() != height():
			errors.append("glyph %d has %d rows, expected %d" % [_code, _rows.size(), height()])
		else:
			var width := _rows[0].length()
			for row in _rows:
				if row.length() != width:
					errors.append("glyph %d: its rows are not all %d wide" % [_code, width])
					break
				for letter in row:
					if letter != "#" and letter != ".":
						errors.append("glyph %d: a row may only hold '#' and '.', not '%s'" % [_code, letter])
						break
	if _code >= 0 and not glyphs.has(_code):
		glyphs[_code] = {"advance": _advance, "rows": _rows}
	_code = -1
	_rows = PackedStringArray()
