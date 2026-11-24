extends GutTest


func test_resolution_settings() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 480)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 270)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer")
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)


func test_the_game_starts_on_the_home_screen() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), Scenes.HOME)
	var scene := load(Scenes.HOME) as PackedScene
	assert_not_null(scene)
