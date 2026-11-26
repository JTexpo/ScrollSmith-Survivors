extends GutTest
## The icon and the web page head. The icon is the one place the game's art is scaled (by exactly 8, nearest-neighbour), because a favicon
## and an itch.io page icon need a normal image size.

const ICON_SOURCE := "res://art/sprites/app_icon.sprite"
const PALETTE_PATH := "res://art/palette.txt"


func _preset_option(key: String) -> String:
	var config := ConfigFile.new()
	assert_eq(config.load("res://export_presets.cfg"), OK)
	for section in config.get_sections():
		if section.ends_with(".options"):
			var preset_section := section.trim_suffix(".options")
			if String(config.get_value(preset_section, "platform", "")) == "Web":
				return str(config.get_value(section, key, ""))
	return ""


func _icon_path() -> String:
	return String(ProjectSettings.get_setting("application/config/icon", ""))


func _load_png(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	return image


func _palette() -> ArtPalette:
	return ArtPalette.parse(FileAccess.get_file_as_string(PALETTE_PATH))


func test_the_project_icon_is_a_square_png_that_exists() -> void:
	var path := _icon_path()
	assert_true(path.ends_with(".png"), "config/icon is '%s'" % path)
	assert_true(FileAccess.file_exists(path))
	var image := _load_png(path)
	assert_eq(image.get_size(), Vector2i(256, 256))


func test_the_icon_equals_what_the_tool_builds() -> void:
	var palette := _palette()
	var source := SpriteSource.parse(FileAccess.get_file_as_string(ICON_SOURCE), palette)
	assert_true(source.errors.is_empty())
	var built := IconBuilder.build(source, palette)
	assert_true(_load_png(_icon_path()).get_data() == built.get_data(), "the icon is stale: run the art tool")


func test_the_icon_is_the_sprite_scaled_by_exactly_eight_with_no_new_colours() -> void:
	var palette := _palette()
	var source := SpriteSource.parse(FileAccess.get_file_as_string(ICON_SOURCE), palette)
	assert_eq(source.frame_size, Vector2i(32, 32))
	var sheet := ArtBuilder.build_sheet(source, palette, &"base")
	var icon := _load_png(_icon_path())
	for y in 32:
		for x in 32:
			var expected := sheet.get_pixel(x, y)
			for dy in 8:
				for dx in 8:
					if icon.get_pixel(x * 8 + dx, y * 8 + dy) != expected:
						fail_test("pixel %d,%d is not one solid 8 by 8 block of the sprite's colour" % [x, y])
						return
	pass_test("every 8 by 8 block is one colour of the sprite")


func test_the_web_preset_uses_the_project_icon() -> void:
	assert_eq(_preset_option("html/export_icon"), "true")


func test_the_head_include_has_the_page_tags() -> void:
	var head := _preset_option("html/head_include")
	for needle in ['<meta name="description"', '<meta name="theme-color"', 'property="og:title"', 'property="og:description"', 'property="og:type"']:
		assert_true(needle in head, needle)
	assert_false("<title" in head)
	assert_false("og:url" in head)
	assert_false("og:image" in head)
	for i in head.length():
		assert_lt(head.unicode_at(i), 128)


func test_the_docs_use_the_current_pages_address() -> void:
	for path in ["res://CLAUDE.md", "res://docs/release-planning/release-checklist.md", "res://docs/release-planning/itchio-notes.md"]:
		assert_false("jtexpo.github.io/GODOT-SpellCraft-Survivors" in FileAccess.get_file_as_string(path), path)
	assert_true("https://jtexpo.github.io/ScrollSmith-Survivors/" in FileAccess.get_file_as_string("res://CLAUDE.md"))
