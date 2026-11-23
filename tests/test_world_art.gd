extends GutTest
## The names the map data uses for its art, and the sprites they find. The temp folder lives under res://.godot/art_tests/
## and is removed after each test.

const ROOT := "res://.godot/art_tests"

var _dir: String


func before_each() -> void:
	_dir = "%s/w_%s" % [ROOT, str(randi())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	SpriteLibrary.root = _dir


func after_each() -> void:
	SpriteLibrary.root = "res://assets/sprites"
	var absolute := ProjectSettings.globalize_path(_dir)
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)


func _save(file: String, side: int) -> void:
	var set_data := SpriteSetData.new()
	set_data.frame_size = Vector2i(side, side)
	assert_eq(ResourceSaver.save(set_data, "%s/%s" % [_dir, file]), OK)


func test_an_empty_or_unknown_name_gives_null_for_every_kind() -> void:
	for art_name in [&"", &"nothing_like_this"]:
		assert_null(WorldArt.floor_set(art_name), "floor %s" % art_name)
		assert_null(WorldArt.wall_set(art_name), "wall %s" % art_name)
		assert_null(WorldArt.post_set(art_name), "post %s" % art_name)
		assert_null(WorldArt.decor_set(art_name), "decor %s" % art_name)


func test_a_name_finds_its_set_by_the_naming_rule() -> void:
	_save("tile_grass_base.tres", 3)
	_save("wall_hedge_base.tres", 4)
	_save("post_marble_base.tres", 5)
	_save("decor_moss_base.tres", 6)
	assert_eq(WorldArt.floor_set(&"grass").frame_size, Vector2i(3, 3))
	assert_eq(WorldArt.wall_set(&"hedge").frame_size, Vector2i(4, 4))
	assert_eq(WorldArt.post_set(&"marble").frame_size, Vector2i(5, 5))
	assert_eq(WorldArt.decor_set(&"moss").frame_size, Vector2i(6, 6))
	assert_null(WorldArt.wall_set(&"grass"), "a floor is not a wall")
