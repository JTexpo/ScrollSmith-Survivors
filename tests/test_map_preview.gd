extends GutTest
## Sprint 16a: the schematic on a map card: the floor colour, every solid shape as a filled rectangle or circle and each placement as a dot,
## 128 by 72 px. It is a diagram drawn from the map's own data, never art, and never changes the map.

var _preview: MapPreview


func before_each() -> void:
	_preview = MapPreview.new()
	add_child_autofree(_preview)


func _map() -> MapData:
	var map := MapData.new()
	map.id = &"test"
	map.size = Vector2(1920, 1080)
	map.player_start = Vector2(960, 540)
	return map


func test_it_is_128_by_72_and_ignores_the_mouse() -> void:
	assert_eq(MapPreview.PREVIEW_SIZE, Vector2(128, 72))
	assert_eq(_preview.custom_minimum_size, MapPreview.PREVIEW_SIZE)
	assert_eq(_preview.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_scale_comes_from_the_map_size() -> void:
	_preview.set_map(_map())
	assert_almost_eq(_preview.scale_factor(), 128.0 / 1920.0, 0.00001)
	var narrow := _map()
	narrow.size = Vector2(960, 540)
	_preview.set_map(narrow)
	assert_almost_eq(_preview.scale_factor(), 128.0 / 960.0, 0.00001)


func test_item_count_is_shapes_plus_placements() -> void:
	var forest := load("res://resources/maps/forest_map.tres") as MapData
	_preview.set_map(forest)
	assert_eq(_preview.item_count(), forest.solid_shapes().size() + forest.placements.size())


func test_a_forest_preview_counts_its_placements() -> void:
	var forest := load("res://resources/maps/forest_map.tres") as MapData
	_preview.set_map(forest)
	assert_eq(_preview.dot_count(), 9)


func test_an_empty_map_still_draws_the_floor() -> void:
	_preview.set_map(_map())
	assert_eq(_preview.item_count(), 0)
	_preview.queue_redraw()
	await wait_process_frames(2)
	assert_true(_preview.has_floor())


func test_a_null_map_draws_nothing_and_does_not_crash() -> void:
	_preview.set_map(null)
	_preview.queue_redraw()
	await wait_process_frames(2)
	assert_eq(_preview.item_count(), 0)
	assert_false(_preview.has_floor())


func test_it_does_not_mutate_the_map() -> void:
	var maze := load("res://resources/maps/maze_map.tres") as MapData
	var shapes := maze.solid_shapes().size()
	var placements := maze.placements.size()
	_preview.set_map(maze)
	_preview.queue_redraw()
	await wait_process_frames(2)
	assert_eq(maze.solid_shapes().size(), shapes)
	assert_eq(maze.placements.size(), placements)
