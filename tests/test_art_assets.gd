extends GutTest
## Guards the whole art pipeline: every sprite source parses, every committed sheet is exactly what the tool builds from
## its source (so no art is stale), every pixel is a palette colour, and every set loads. It loops over every source, so
## it covers each sprite added later.

const SOURCE_DIR := "res://art/sprites"
const PALETTE_PATH := "res://art/palette.txt"
const OUT_DIR := "res://assets/sprites"
const MAX_COLORS := 96
const UI_COLORS := ["#fff6e8", "#e9dcf2", "#3b2a5c", "#6b5a8c", "#ff6f8f", "#c9446a", "#6fd3ff", "#3a9fd6", "#e0483c", "#9e2a22", "#5fbf5a", "#348a3a", "#ffd24a", "#d99a1a"]


func _palette() -> ArtPalette:
	return ArtPalette.parse(FileAccess.get_file_as_string(PALETTE_PATH))


func _names() -> Array[String]:
	var names: Array[String] = []
	for file in DirAccess.get_files_at(SOURCE_DIR):
		if String(file).ends_with(".sprite"):
			names.append(String(file).get_basename())
	names.sort()
	return names


func _source(sprite_name: String) -> SpriteSource:
	return SpriteSource.parse(FileAccess.get_file_as_string("%s/%s.sprite" % [SOURCE_DIR, sprite_name]), _palette())


func _allowed_colors() -> Dictionary:
	var allowed := {}
	var palette := _palette()
	for letter in palette.colors:
		allowed[(palette.colors[letter] as Color).to_html(true)] = true
	for id in palette.variants:
		for color in palette.variants[id]:
			allowed[(color as Color).to_html(true)] = true
	return allowed


func _load_png(png_path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(png_path))
	image.convert(Image.FORMAT_RGBA8)
	return image


## The variants a source produces: every needed variant, plus the silhouette when it declares an outline (and is not a surface).
func _variants_for(source: SpriteSource, palette: ArtPalette) -> Array[String]:
	var variants: Array[String] = []
	if source.outline and not source.is_surface():
		variants.append("silhouette")
	for variant in source.variants_needed(palette):
		variants.append(String(variant))
	return variants


func test_the_palette_is_valid_small_and_has_an_outline_color() -> void:
	var palette := _palette()
	assert_eq(palette.errors.size(), 0, str(palette.errors))
	assert_lte(palette.distinct_color_count(), MAX_COLORS)
	assert_true(palette.colors.has("K"), "K is the dark outline")
	for id in [&"none", &"fire", &"thunder", &"land", &"sea", &"hardy", &"mana", &"swift", &"flicker", &"quick", &"oak", &"elder"]:
		assert_true(palette.variants.has(id), "variant %s" % id)


func test_the_palette_has_the_ui_colors() -> void:
	var allowed := _allowed_colors()
	for hex in UI_COLORS:
		assert_true(allowed.has(Color.html(hex).to_html(true)), "palette lacks %s" % hex)


func test_there_are_sprite_sources() -> void:
	assert_gt(_names().size(), 0)


func test_every_source_parses_with_no_errors() -> void:
	for sprite_name in _names():
		assert_eq(_source(sprite_name).errors.size(), 0, "%s: %s" % [sprite_name, str(_source(sprite_name).errors)])


func test_every_source_keeps_a_one_pixel_margin() -> void:
	for sprite_name in _names():
		var source := _source(sprite_name)
		if source.is_surface():
			continue
		for f in source.frames.size():
			var rows := source.frames[f]
			var last := source.frame_size.x - 1
			assert_eq(rows[0].replace(".", ""), "", "%s frame %d: the top row must be empty" % [sprite_name, f])
			assert_eq(rows[rows.size() - 1].replace(".", ""), "", "%s frame %d: the bottom row must be empty" % [sprite_name, f])
			for row in rows:
				assert_true(row[0] == "." and row[last] == ".", "%s frame %d: the side columns must be empty" % [sprite_name, f])


func test_every_tile_is_full_bleed_and_its_slice_fits() -> void:
	var tiles := 0
	for sprite_name in _names():
		var source := _source(sprite_name)
		if not source.tile:
			continue
		tiles += 1
		for rows in source.frames:
			for row in rows:
				assert_false(row.contains("."), "%s is a tile: no transparent pixel" % sprite_name)
		if source.slice != Vector4i.ZERO:
			assert_lt(source.slice.x + source.slice.z, source.frame_size.x, "%s slice fits the width" % sprite_name)
			assert_lt(source.slice.y + source.slice.w, source.frame_size.y, "%s slice fits the height" % sprite_name)
	assert_gt(tiles, 0, "the world has floor tiles")


func test_every_sliced_sprite_has_a_middle_that_tiles() -> void:
	for sprite_name in _names():
		var source := _source(sprite_name)
		if source.slice == Vector4i.ZERO or source.tile:
			continue  # a wall tile repeats a pattern in its middle on purpose
		var width := source.frame_size.x
		var height := source.frame_size.y
		for f in source.frames.size():
			var rows := source.frames[f]
			# Tiling the middle columns sideways shows no seam when every row is one colour across them.
			for y in height:
				var first := rows[y][source.slice.x]
				for x in range(source.slice.x, width - source.slice.z):
					assert_eq(rows[y][x], first, "%s frame %d row %d: the tiled middle must be one colour per row" % [sprite_name, f, y])
			# Tiling the middle rows downwards shows no seam when every column is one colour across them.
			if source.slice.y + source.slice.w > 0:
				for x in width:
					var top := rows[source.slice.y][x]
					for y in range(source.slice.y, height - source.slice.w):
						assert_eq(rows[y][x], top, "%s frame %d column %d: the tiled middle must be one colour per column" % [sprite_name, f, x])


func test_the_committed_sheets_exist_for_every_variant_and_the_silhouette() -> void:
	var palette := _palette()
	for sprite_name in _names():
		var source := _source(sprite_name)
		var wanted := _variants_for(source, palette)
		for variant in wanted:
			for extension in ["png", "tres"]:
				var file_path := "%s/%s_%s.%s" % [OUT_DIR, sprite_name, variant, extension]
				assert_true(FileAccess.file_exists(file_path), "missing %s" % file_path)


func test_each_committed_png_equals_what_the_tool_builds() -> void:
	var palette := _palette()
	for sprite_name in _names():
		var source := _source(sprite_name)
		if source.hand_drawn:
			_check_hand_drawn(sprite_name, source, palette)
			continue
		for variant in source.variants_needed(palette):
			var png_path := "%s/%s_%s.png" % [OUT_DIR, sprite_name, variant]
			var built := ArtBuilder.build_sheet(source, palette, variant)
			var committed := _load_png(png_path)
			assert_eq(committed.get_size(), built.get_size(), "%s size" % png_path)
			assert_true(committed.get_data() == built.get_data(), "%s is stale: run the art tool" % png_path)
		if source.is_surface() or not source.outline:
			continue
		var silhouette_path := "%s/%s_silhouette.png" % [OUT_DIR, sprite_name]
		assert_true(_load_png(silhouette_path).get_data() == ArtBuilder.build_silhouette(source).get_data(), "%s is stale" % silhouette_path)


func test_every_pixel_is_a_palette_color_or_transparent() -> void:
	var allowed := _allowed_colors()
	for sprite_name in _names():
		var palette := _palette()
		if _source(sprite_name).hand_drawn:
			continue
		for variant in _source(sprite_name).variants_needed(palette):
			var image := _load_png("%s/%s_%s.png" % [OUT_DIR, sprite_name, variant])
			for y in image.get_height():
				for x in image.get_width():
					var pixel := image.get_pixel(x, y)
					assert_true(pixel.a == 0.0 or allowed.has(pixel.to_html(true)), "%s_%s has an off-palette pixel %s at %d, %d" % [sprite_name, variant, pixel.to_html(true), x, y])


func test_each_set_loads_with_the_right_sheet_width_and_animation_ranges() -> void:
	var palette := _palette()
	for sprite_name in _names():
		var source := _source(sprite_name)
		var wanted := _variants_for(source, palette)
		for variant in wanted:
			var set_data := load("%s/%s_%s.tres" % [OUT_DIR, sprite_name, variant]) as SpriteSetData
			assert_not_null(set_data, "%s_%s loads" % [sprite_name, variant])
			assert_eq(set_data.frame_size, source.frame_size)
			assert_eq(set_data.frame_count(), source.frames.size(), "%s_%s sheet width" % [sprite_name, variant])
			assert_eq(set_data.animations.size(), source.animations.size())
			for animation in set_data.animations:
				assert_between(animation.first_frame, 0, set_data.frame_count() - 1)
				assert_between(animation.last_frame, animation.first_frame, set_data.frame_count() - 1)


## A hand-drawn sprite's sheets are the user's: only their size and the silhouette made from them are checked.
func _check_hand_drawn(sprite_name: String, source: SpriteSource, palette: ArtPalette) -> void:
	var variants := source.variants_needed(palette)
	for variant in variants:
		var png_path := "%s/%s_%s.png" % [OUT_DIR, sprite_name, variant]
		assert_eq(_load_png(png_path).get_size(), Vector2i(source.frame_size.x * source.frames.size(), source.frame_size.y), "%s size" % png_path)
	if source.is_surface() or not source.outline:
		return
	var silhouette_path := "%s/%s_silhouette.png" % [OUT_DIR, sprite_name]
	var expected := ArtBuilder.silhouette_of(_load_png("%s/%s_%s.png" % [OUT_DIR, sprite_name, variants[0]]), source.frame_size)
	assert_true(_load_png(silhouette_path).get_data() == expected.get_data(), "%s is stale: run the art tool" % silhouette_path)


func _wanted_files() -> Dictionary:
	var wanted := {}
	var palette := _palette()
	for sprite_name in _names():
		var variants := _variants_for(_source(sprite_name), palette)
		for variant in variants:
			for extension in ["png", "tres"]:
				wanted["%s_%s.%s" % [sprite_name, variant, extension]] = true
	return wanted


func test_each_committed_set_equals_what_the_tool_writes() -> void:
	var palette := _palette()
	for sprite_name in _names():
		var source := _source(sprite_name)
		var variants := _variants_for(source, palette)
		for variant in variants:
			var png_path := "%s/%s_%s.png" % [OUT_DIR, sprite_name, variant]
			var set_path := "%s/%s_%s.tres" % [OUT_DIR, sprite_name, variant]
			assert_eq(FileAccess.get_file_as_string(set_path), ArtBuilder.set_text(png_path, source), "%s has stale animation data: run the art tool" % set_path)


func test_each_committed_font_equals_what_the_tool_builds() -> void:
	var source := FontSource.parse(FileAccess.get_file_as_string("res://art/fonts/ui.pixelfont"))
	assert_eq(source.errors.size(), 0, str(source.errors))
	for outlined in [false, true]:
		var build := "outlined" if outlined else "plain"
		var png_path := "res://assets/fonts/ui_%s.png" % build
		var fnt_path := "res://assets/fonts/ui_%s.fnt" % build
		assert_true(_load_png(png_path).get_data() == FontBuilder.build_sheet(source, outlined).get_data(), "%s is stale: run the art tool" % png_path)
		assert_eq(FileAccess.get_file_as_string(fnt_path), FontBuilder.fnt_text(source, "ui_%s.png" % build, outlined), "%s is stale: run the art tool" % fnt_path)


func test_the_committed_theme_equals_what_the_tool_writes() -> void:
	assert_eq(FileAccess.get_file_as_string("res://resources/ui/game_theme.tres"), ThemeBuilder.theme_text(), "game_theme.tres is stale: run the art tool")


func test_the_font_outline_is_the_palette_outline_color() -> void:
	assert_eq(FontBuilder.OUTLINE_COLOR, _palette().colors["K"])


func test_no_output_belongs_to_nothing() -> void:
	var wanted := _wanted_files()
	for file in DirAccess.get_files_at(OUT_DIR):
		var file_name := String(file)
		if file_name.ends_with(".png") or file_name.ends_with(".tres"):
			assert_true(wanted.has(file_name), "%s has no source or variant any more: delete it, because the game would still load it" % file_name)


func test_every_enemy_sprite_declares_an_outline() -> void:
	var count := 0
	for sprite_name in _names():
		if sprite_name.begins_with("enemy_"):
			count += 1
			assert_true(_source(sprite_name).outline, "%s needs an `outline` line: an elite shows its silhouette" % sprite_name)
	assert_eq(count, 21, "seven plain, four forest, three ruins and seven maze enemies")


func test_only_sprites_that_declare_an_outline_have_a_silhouette_sheet() -> void:
	for sprite_name in _names():
		if _source(sprite_name).outline:
			continue
		for extension in ["png", "tres"]:
			assert_false(FileAccess.file_exists("%s/%s_silhouette.%s" % [OUT_DIR, sprite_name, extension]), "%s has no outline line, so it gets no silhouette.%s" % [sprite_name, extension])


func test_an_outline_sprite_builds_its_silhouette() -> void:
	var folder := "res://.godot/art_tests/outline_%s" % str(randi())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder + "/sources"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder + "/out"))
	var handle := FileAccess.open(folder + "/sources/thing.sprite", FileAccess.WRITE)
	handle.store_string("outline\nsize 3 3\nanim a 0 0 1 loop\nframe\n...\n.K.\n...\n")
	handle.close()
	var palette_handle := FileAccess.open(folder + "/palette.txt", FileAccess.WRITE)
	palette_handle.store_string(FileAccess.get_file_as_string(PALETTE_PATH))
	palette_handle.close()
	var problems := ArtBuilder.build_all(folder + "/sources", folder + "/palette.txt", folder + "/out")
	assert_eq(problems.size(), 0, str(problems))
	assert_true(FileAccess.file_exists(folder + "/out/thing_silhouette.png"))
	for sub in ["/sources", "/out"]:
		var absolute := ProjectSettings.globalize_path(folder + sub)
		for file in DirAccess.get_files_at(absolute):
			DirAccess.remove_absolute("%s/%s" % [absolute, file])
		DirAccess.remove_absolute(absolute)
	var top := ProjectSettings.globalize_path(folder)
	for file in DirAccess.get_files_at(top):
		DirAccess.remove_absolute("%s/%s" % [top, file])
	DirAccess.remove_absolute(top)
