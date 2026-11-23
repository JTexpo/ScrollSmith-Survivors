extends GutTest

const THEME_PATH := "res://resources/ui/game_theme.tres"
const VARIATIONS := {
	&"PanelDark": &"Panel",
	&"PanelSlot": &"Panel",
	&"PanelSlotSelected": &"Panel",
	&"ButtonRed": &"Button",
	&"ButtonGreen": &"Button",
	&"ButtonYellow": &"Button",
	&"HudLabel": &"Label",
	&"HudToast": &"Label",
	&"HudGold": &"Label",
	&"Heading": &"Label",
	&"Muted": &"Label",
	&"Warning": &"Label",
	&"BarHp": &"ProgressBar",
	&"BarXp": &"ProgressBar",
	&"BarBoss": &"ProgressBar",
}
const TEMP := "res://.godot/theme_tests"

var _theme: Theme


func before_each() -> void:
	_theme = load(THEME_PATH) as Theme


func after_each() -> void:
	var absolute := ProjectSettings.globalize_path(TEMP)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	for folder in DirAccess.get_directories_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, folder])
	DirAccess.remove_absolute(absolute)


func test_the_theme_loads() -> void:
	assert_not_null(_theme)


func test_every_pinned_variation_exists_on_its_base_type() -> void:
	for variation in VARIATIONS:
		assert_eq(_theme.get_type_variation_base(variation), VARIATIONS[variation], str(variation))


func test_the_pinned_variations_carry_their_looks() -> void:
	for name_of in [&"ButtonRed", &"ButtonGreen", &"ButtonYellow"]:
		for style in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			assert_true(_theme.has_stylebox(style, name_of), "%s has %s" % [name_of, style])
	for name_of in [&"PanelDark", &"PanelSlot", &"PanelSlotSelected"]:
		assert_true(_theme.has_stylebox(&"panel", name_of), String(name_of))
	for name_of in [&"BarHp", &"BarXp", &"BarBoss"]:
		assert_true(_theme.has_stylebox(&"background", name_of), String(name_of))
		assert_true(_theme.has_stylebox(&"fill", name_of), String(name_of))
	assert_eq(_theme.get_font(&"font", &"HudLabel").resource_path, UiFont.outlined_path)
	assert_eq(_theme.get_font(&"font", &"HudGold").resource_path, UiFont.outlined_path)
	assert_eq(_theme.get_font(&"font", &"HudToast").resource_path, UiFont.outlined_path)
	assert_true(_theme.has_stylebox(&"normal", &"HudToast"), "the toast pill")


func test_every_stylebox_tiles_and_never_stretches() -> void:
	var count := 0
	for type in _theme.get_type_list():
		for style_name in _theme.get_stylebox_list(type):
			var style := _theme.get_stylebox(style_name, type)
			var textured := style as StyleBoxTexture
			if textured != null:
				count += 1
				assert_eq(textured.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE, "%s/%s" % [type, style_name])
				assert_eq(textured.axis_stretch_vertical, StyleBoxTexture.AXIS_STRETCH_MODE_TILE, "%s/%s" % [type, style_name])
	assert_gt(count, 10)


func test_every_region_is_inside_its_sheet() -> void:
	for type in _theme.get_type_list():
		for style_name in _theme.get_stylebox_list(type):
			var style := _theme.get_stylebox(style_name, type)
			var textured := style as StyleBoxTexture
			if textured != null:
				var sheet := textured.texture.get_size()
				var region: Rect2 = textured.region_rect
				assert_gte(region.position.x, 0.0)
				assert_lte(region.end.x, sheet.x, "%s/%s" % [type, style_name])
				assert_lte(region.end.y, sheet.y, "%s/%s" % [type, style_name])
				assert_gt(region.size.x, 0.0)


func test_the_default_font_and_size_are_the_ui_fonts() -> void:
	assert_eq(_theme.default_font.resource_path, UiFont.plain_path)
	assert_eq(_theme.default_font_size, UiFont.SIZE)


func test_every_theme_color_is_a_palette_color() -> void:
	var palette := ArtPalette.parse(FileAccess.get_file_as_string("res://art/palette.txt"))
	var allowed := {}
	for letter in palette.colors:
		allowed[(palette.colors[letter] as Color).to_html(true)] = true
	for type in _theme.get_type_list():
		for color_name in _theme.get_color_list(type):
			var color := _theme.get_color(color_name, type)
			assert_true(allowed.has(color.to_html(true)), "%s/%s %s is not a palette colour" % [type, color_name, color.to_html()])


func test_theme_text_is_deterministic() -> void:
	assert_eq(ThemeBuilder.theme_text(), ThemeBuilder.theme_text())


func test_text_with_an_empty_library_has_no_styleboxes_and_loads() -> void:
	var empty := ProjectSettings.globalize_path(TEMP + "/empty")
	DirAccess.make_dir_recursive_absolute(empty)
	var text := ThemeBuilder.theme_text(TEMP + "/empty", TEMP + "/empty")
	assert_false(text.contains("StyleBoxTexture"))
	var file := FileAccess.open(TEMP + "/empty_theme.tres", FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var loaded := ResourceLoader.load(TEMP + "/empty_theme.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	assert_not_null(loaded, "a theme with no sprites still loads")
	assert_true(loaded.has_color(&"font_color", &"Label"), "text colours do not depend on art")


func test_the_project_uses_the_game_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom"), THEME_PATH)
