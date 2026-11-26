class_name IconBuilder
extends RefCounted
## Builds the game icon: the first frame of `app_icon.sprite` scaled by exactly 8, nearest-neighbour (no smoothing, so it stays crisp). It is
## the one place the art is scaled, because a browser tab and an itch.io page need a normal image size. Build-time only.

const SCALE := 8
const SOURCE_NAME := "app_icon"


static func build(source: SpriteSource, palette: ArtPalette) -> Image:
	var sheet := ArtBuilder.build_sheet(source, palette, &"base")
	var size := source.frame_size
	var image := Image.create(size.x * SCALE, size.y * SCALE, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var color := sheet.get_pixel(x, y)
			if color.a > 0.0:
				image.fill_rect(Rect2i(x * SCALE, y * SCALE, SCALE, SCALE), color)
	return image


## Reads the icon source and writes the PNG. Returns the problems found (none on success).
static func write(source_dir: String, palette_path: String, out_path: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var palette := ArtPalette.parse(FileAccess.get_file_as_string(palette_path))
	for error in palette.errors:
		problems.append("%s: %s" % [palette_path, error])
	var source_path := "%s/%s.sprite" % [source_dir, SOURCE_NAME]
	var source := SpriteSource.parse(FileAccess.get_file_as_string(source_path), palette)
	for error in source.errors:
		problems.append("%s: %s" % [source_path, error])
	if not problems.is_empty():
		return problems
	var error := build(source, palette).save_png(ProjectSettings.globalize_path(out_path))
	if error != OK:
		problems.append("%s: cannot write (%s)" % [out_path, error_string(error)])
	return problems
