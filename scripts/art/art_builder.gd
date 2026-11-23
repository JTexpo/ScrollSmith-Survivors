class_name ArtBuilder
extends RefCounted
## Turns sprite grids and the palette into PNG sheets and `SpriteSetData` resources. Pure and testable: the command-line
## tool (`tools/art/art_builder.gd`) only calls `build_all`. A sprite that uses ramp slots is built once per element
## variant, one that does not once as `base`, and every sprite also gets a white silhouette sheet for outlines.

## How many files the last `build_all` wrote.
static var files_written: int = 0


## All frames side by side, left to right, in one variant's colours.
static func build_sheet(source: SpriteSource, palette: ArtPalette, variant: StringName) -> Image:
	var size := source.frame_size
	var image := Image.create(size.x * source.frames.size(), size.y, false, Image.FORMAT_RGBA8)
	for f in source.frames.size():
		for y in size.y:
			var row := source.frames[f][y]
			for x in size.x:
				var color := palette.color_for(row[x], variant)
				if color.a > 0.0:
					image.set_pixel(f * size.x + x, y, color)
	return image


## White pixels on and within one pixel (all eight neighbours) of the sprite, in the same layout. A frame never
## borrows from the next, so each sprite keeps a 1 px margin of its own.
static func build_silhouette(source: SpriteSource) -> Image:
	var size := source.frame_size
	var image := Image.create(size.x * source.frames.size(), size.y, false, Image.FORMAT_RGBA8)
	for f in source.frames.size():
		for y in size.y:
			for x in size.x:
				if _near_shape(source.frames[f], x, y, size):
					image.set_pixel(f * size.x + x, y, Color.WHITE)
	return image


## The text of a `SpriteSetData` resource for a sheet at `png_path`.
static func set_text(png_path: String, source: SpriteSource) -> String:
	var lines := PackedStringArray()
	lines.append("[gd_resource type=\"Resource\" script_class=\"SpriteSetData\" load_steps=%d format=3]" % (4 + source.animations.size()))
	lines.append("")
	lines.append("[ext_resource type=\"Script\" path=\"res://resources/art/sprite_set_data.gd\" id=\"1\"]")
	lines.append("[ext_resource type=\"Script\" path=\"res://resources/art/sprite_animation_data.gd\" id=\"2\"]")
	lines.append("[ext_resource type=\"Texture2D\" path=\"%s\" id=\"3\"]" % png_path)
	lines.append("")
	var ids := PackedStringArray()
	for i in source.animations.size():
		var animation := source.animations[i]
		lines.append("[sub_resource type=\"Resource\" id=\"anim_%d\"]" % i)
		lines.append("script = ExtResource(\"2\")")
		lines.append("name = &\"%s\"" % animation["name"])
		lines.append("first_frame = %d" % animation["first"])
		lines.append("last_frame = %d" % animation["last"])
		lines.append("fps = %s" % str(float(animation["fps"])))
		lines.append("loop = %s" % ("true" if animation["loop"] else "false"))
		lines.append("")
		ids.append("SubResource(\"anim_%d\")" % i)
	lines.append("[resource]")
	lines.append("script = ExtResource(\"1\")")
	lines.append("sheet = ExtResource(\"3\")")
	lines.append("frame_size = Vector2i(%d, %d)" % [source.frame_size.x, source.frame_size.y])
	lines.append("animations = Array[ExtResource(\"2\")]([%s])" % ", ".join(ids))
	return "\n".join(lines) + "\n"


## Builds every `.sprite` in `source_dir` into `out_dir`. Returns the problems found (empty when all is well). A source
## with errors writes nothing for itself, and a bad palette writes nothing at all.
static func build_all(source_dir: String, palette_path: String, out_dir: String) -> PackedStringArray:
	files_written = 0
	var problems := PackedStringArray()
	var palette := ArtPalette.parse(FileAccess.get_file_as_string(palette_path))
	for error in palette.errors:
		problems.append("%s: %s" % [palette_path, error])
	if not problems.is_empty():
		return problems
	var files := Array(DirAccess.get_files_at(source_dir))
	files.sort()
	for file in files:
		if not String(file).ends_with(".sprite"):
			continue
		var source_path := "%s/%s" % [source_dir, file]
		var source := SpriteSource.parse(FileAccess.get_file_as_string(source_path), palette)
		if not source.errors.is_empty():
			for error in source.errors:
				problems.append("%s: %s" % [source_path, error])
			continue
		var sprite_name := String(file).get_basename()
		for variant in source.variants_needed(palette):
			_write(out_dir, sprite_name, String(variant), build_sheet(source, palette, variant), source)
		_write(out_dir, sprite_name, "silhouette", build_silhouette(source), source)
	return problems


static func _write(out_dir: String, sprite_name: String, variant: String, sheet: Image, source: SpriteSource) -> void:
	var png_path := "%s/%s_%s.png" % [out_dir, sprite_name, variant]
	sheet.save_png(png_path)
	var handle := FileAccess.open("%s/%s_%s.tres" % [out_dir, sprite_name, variant], FileAccess.WRITE)
	handle.store_string(set_text(png_path, source))
	handle.close()
	files_written += 2


static func _near_shape(rows: PackedStringArray, x: int, y: int, size: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var ny := y + dy
			if nx >= 0 and ny >= 0 and nx < size.x and ny < size.y and rows[ny][nx] != ArtPalette.TRANSPARENT_LETTER:
				return true
	return false
