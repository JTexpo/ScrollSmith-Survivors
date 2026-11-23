class_name SpriteSource
extends RefCounted
## One sprite read from a `.sprite` text file: `size <w> <h>`, `anim <name> <first> <last> <fps> <loop|once>` lines, then
## each frame as the line `frame` followed by `h` rows of exactly `w` letters (`.` transparent, a palette letter, or a ramp
## slot 1 to 5). `#` starts a comment. A line `hand_drawn` says the sheets were drawn by hand: the tool then keeps them
## and only writes the animation data and silhouette (the grid is a placeholder). A line `tile` marks a full-bleed
## repeating tile (no transparent pixel, no 1 px margin, no silhouette), and `slice <left> <top> <right> <bottom>` gives a
## 9-slice margins in pixels, for walls (on a `tile`) and for panels and buttons (alone, so their corners may be transparent). Mistakes are collected in `errors`,
## never thrown.

var errors := PackedStringArray()
## True when the sheets were replaced by hand and the tool must not rebuild them.
var hand_drawn := false
## The variants this sprite is built in (a `variants <id> <id> ..` line). Empty means the five element variants.
var variants: Array[StringName] = []
## True for a full-bleed repeating tile (a floor or a wall).
var tile := false
## The 9-slice margins (left, top, right, bottom) of a tile, zero when it has none.
var slice := Vector4i.ZERO
var frame_size := Vector2i.ZERO
## Each: {"name": StringName, "first": int, "last": int, "fps": float, "loop": bool}.
var animations: Array[Dictionary] = []
## The rows of each frame.
var frames: Array[PackedStringArray] = []


static func parse(text: String, palette: ArtPalette) -> SpriteSource:
	var source := SpriteSource.new()
	var number := 0
	for raw in text.split("\n"):
		number += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line == "hand_drawn":
			source.hand_drawn = true
		elif line.begins_with("variants "):
			for id in line.replace("\t", " ").split(" ", false).slice(1):
				source.variants.append(StringName(id))
		elif line == "tile":
			source.tile = true
		elif line.begins_with("slice "):
			source._read_slice(number, line)
		elif line.begins_with("size "):
			source._read_size(number, line)
		elif line.begins_with("anim "):
			source._read_animation(number, line)
		elif line == "frame":
			source.frames.append(PackedStringArray())
		elif source.frames.is_empty():
			source.errors.append("line %d: a row before any 'frame'" % number)
		else:
			var rows := PackedStringArray(source.frames[source.frames.size() - 1])
			rows.append(line)
			source.frames[source.frames.size() - 1] = rows
	source._validate(palette)
	return source


## True for a surface: a tile, or a sliced sprite (a panel or button whose corners may be transparent). A surface skips the
## 1 px margin rule and has no silhouette.
func is_surface() -> bool:
	return tile or slice != Vector4i.ZERO


## True when any pixel uses a ramp slot (1 to 5), so the sprite is built once per element variant.
func uses_ramp() -> bool:
	for rows in frames:
		for row in rows:
			for letter in ArtPalette.RAMP_LETTERS:
				if row.contains(letter):
					return true
	return false


## The variants to build: for a ramp sprite the ones its `variants` line names, otherwise the element variants the
## palette has, and just `base` for a sprite with no ramp slot.
func variants_needed(palette: ArtPalette) -> Array[StringName]:
	var needed: Array[StringName] = []
	if uses_ramp():
		if not variants.is_empty():
			needed.append_array(variants)
		else:
			for id in ArtPalette.ELEMENT_VARIANTS:
				if palette.variants.has(id):
					needed.append(id)
	else:
		needed.append(&"base")
	return needed


func _read_size(number: int, line: String) -> void:
	var parts := line.replace("\t", " ").split(" ", false)
	if parts.size() != 3 or not parts[1].is_valid_int() or not parts[2].is_valid_int() or int(parts[1]) <= 0 or int(parts[2]) <= 0:
		errors.append("line %d: expected 'size <width> <height>' with positive numbers" % number)
		return
	frame_size = Vector2i(int(parts[1]), int(parts[2]))


func _read_slice(number: int, line: String) -> void:
	var parts := line.replace("\t", " ").split(" ", false)
	if parts.size() != 5:
		errors.append("line %d: expected 'slice <left> <top> <right> <bottom>'" % number)
		return
	for i in range(1, 5):
		if not parts[i].is_valid_int() or int(parts[i]) < 0:
			errors.append("line %d: a slice margin must be a whole number, zero or more" % number)
			return
	slice = Vector4i(int(parts[1]), int(parts[2]), int(parts[3]), int(parts[4]))


func _read_animation(number: int, line: String) -> void:
	var parts := line.replace("\t", " ").split(" ", false)
	if parts.size() != 6 or not parts[2].is_valid_int() or not parts[3].is_valid_int() or not parts[4].is_valid_float():
		errors.append("line %d: expected 'anim <name> <first> <last> <fps> <loop|once>'" % number)
		return
	if parts[5] != "loop" and parts[5] != "once":
		errors.append("line %d: the animation mode must be 'loop' or 'once', not '%s'" % [number, parts[5]])
		return
	animations.append({"name": StringName(parts[1]), "first": int(parts[2]), "last": int(parts[3]), "fps": float(parts[4]), "loop": parts[5] == "loop"})


func _validate(palette: ArtPalette) -> void:
	if frame_size == Vector2i.ZERO:
		errors.append("missing a valid 'size' line")
	for id in variants:
		if not palette.variants.has(id):
			errors.append("'variants' names '%s', which the palette does not have" % id)
	if slice != Vector4i.ZERO and frame_size != Vector2i.ZERO and (slice.x + slice.z >= frame_size.x or slice.y + slice.w >= frame_size.y):
		errors.append("the slice margins leave no middle in a %dx%d sprite" % [frame_size.x, frame_size.y])
	if frames.is_empty():
		errors.append("no frames")
	elif frame_size != Vector2i.ZERO:
		for f in frames.size():
			var rows := frames[f]
			if rows.size() != frame_size.y:
				errors.append("frame %d has %d rows, expected %d" % [f, rows.size(), frame_size.y])
				continue
			for r in rows.size():
				if rows[r].length() != frame_size.x:
					errors.append("frame %d row %d is %d wide, expected %d" % [f, r, rows[r].length(), frame_size.x])
					continue
				if tile and rows[r].contains(ArtPalette.TRANSPARENT_LETTER):
					errors.append("frame %d row %d: a tile is full-bleed, it cannot have a transparent pixel" % [f, r])
				for letter in rows[r]:
					if letter != ArtPalette.TRANSPARENT_LETTER and not palette.has_letter(letter):
						errors.append("frame %d row %d uses the unknown letter '%s'" % [f, r, letter])
	var names := {}
	for animation in animations:
		if names.has(animation["name"]):
			errors.append("the animation '%s' is defined twice" % animation["name"])
		names[animation["name"]] = true
		if animation["first"] < 0 or animation["last"] < animation["first"] or animation["last"] >= frames.size():
			errors.append("the animation '%s' (frames %d to %d) is outside the %d frames" % [animation["name"], animation["first"], animation["last"], frames.size()])
