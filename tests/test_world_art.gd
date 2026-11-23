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


func test_every_floor_style_in_first_map_has_art() -> void:
	SpriteLibrary.root = "res://assets/sprites"
	var map := load("res://resources/maps/first_map.tres") as MapData
	var styles: Array[StringName] = [map.floor_style, map.border_style]
	for zone in map.zones:
		styles.append(zone.floor_style)
	for style in styles:
		assert_ne(style, &"", "every region of the first map names a floor")
		assert_not_null(WorldArt.floor_set(style), "tile_%s has art" % style)
		assert_true(WorldArt.floor_set(style).tile, "tile_%s is a tile" % style)


func test_nine_slice_parts_cover_the_destination_exactly_once() -> void:
	for dest in [Rect2(10, 20, 560, 16), Rect2(0, 0, 16, 280), Rect2(5, 5, 96, 96), Rect2(0, 0, 16, 16), Rect2(0, 0, 6, 40)]:
		var parts := NineSlice.parts(Vector2(16, 16), Vector4i(4, 4, 4, 4), dest)
		assert_eq(parts.size(), 9)
		var area := 0.0
		for part in parts:
			var piece := part["dest"] as Rect2
			assert_true(dest.encloses(piece), "%s stays inside %s" % [piece, dest])
			area += piece.get_area()
			for other in parts:
				if other != part:
					assert_false(piece.intersects(other["dest"] as Rect2), "no overlap")
		assert_almost_eq(area, dest.get_area(), 0.01, "the nine parts fill %s" % dest)


func test_nine_slice_corners_are_drawn_one_to_one_and_there_is_one_centre() -> void:
	var parts := NineSlice.parts(Vector2(16, 16), Vector4i(4, 4, 4, 4), Rect2(0, 0, 100, 16))
	var centres := 0
	var corners := 0
	for part in parts:
		match part["kind"]:
			"centre":
				centres += 1
			"corner":
				corners += 1
				assert_eq((part["src"] as Rect2).size, (part["dest"] as Rect2).size, "a corner is never stretched")
	assert_eq(centres, 1)
	assert_eq(corners, 4)


func test_every_wall_set_has_slice_margins_that_fit_a_16_pixel_wall() -> void:
	SpriteLibrary.root = "res://assets/sprites"
	for material in [&"hedge", &"brick", &"stone"]:
		var set_data := WorldArt.wall_set(material)
		assert_not_null(set_data, "wall_%s has art" % material)
		assert_true(set_data.tile, "wall_%s is a tile" % material)
		assert_eq(set_data.frame_size, Vector2i(16, 16))
		assert_lt(set_data.slice.x + set_data.slice.z, 16)
		assert_lt(set_data.slice.y + set_data.slice.w, 16)
		assert_gt(set_data.slice.y + set_data.slice.w, 0, "a wall has an edge")


func test_every_obstacle_and_maze_material_in_first_map_has_art() -> void:
	SpriteLibrary.root = "res://assets/sprites"
	var map := load("res://resources/maps/first_map.tres") as MapData
	for maze in map.mazes:
		assert_not_null(WorldArt.wall_set(maze.material), "maze material %s" % maze.material)
	for obstacle in map.obstacles:
		assert_ne(obstacle.material, &"", "every authored obstacle names a material")
		if obstacle.kind == MapObstacle.Kind.CIRCLE:
			assert_not_null(WorldArt.post_set(obstacle.material), "post_%s" % obstacle.material)
			assert_lte(absf(obstacle.radius - 21.0), 4.0, "a post's drawing is within 4 px of its collision")
		else:
			assert_not_null(WorldArt.wall_set(obstacle.material), "wall_%s" % obstacle.material)


func test_every_decoration_style_in_first_map_has_art() -> void:
	SpriteLibrary.root = "res://assets/sprites"
	var map := load("res://resources/maps/first_map.tres") as MapData
	var styles := {}
	for style in map.decoration_styles:
		styles[style] = true
	for zone in map.zones:
		for style in zone.decoration_styles:
			styles[style] = true
	assert_gt(styles.size(), 0, "the first map names decoration styles")
	for style in styles:
		var set_data := WorldArt.decor_set(StringName(style))
		assert_not_null(set_data, "decor_%s has art" % style)
		assert_gte(set_data.frame_count(), 2, "decor_%s has variants" % style)
		assert_lte(set_data.frame_size.x, 16)
		assert_lte(set_data.frame_size.y, 16)

