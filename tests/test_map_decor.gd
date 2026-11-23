extends GutTest

const LECTERN := "res://scenes/interactables/lectern.tscn"


func _map(seed_value: int = 3) -> MapData:
	var map := MapData.new()
	map.id = &"test"
	map.size = Vector2(400, 300)
	map.player_start = Vector2(200, 150)
	var placement := MapPlacement.new()
	placement.scene = load(LECTERN)
	placement.position = Vector2(50, 50)
	map.placements = [placement] as Array[MapPlacement]
	map.decoration_count = 50
	map.decoration_seed = seed_value
	map.decoration_colors = PackedColorArray([Color(0.2, 0.3, 0.2), Color(0.1, 0.2, 0.1)])
	map.decoration_size = Vector2(2, 4)
	return map


func test_the_same_seed_gives_the_same_scatter() -> void:
	assert_eq(MapDecor.scatter(_map(3)), MapDecor.scatter(_map(3)))


func test_a_different_seed_gives_a_different_scatter() -> void:
	assert_ne(MapDecor.scatter(_map(3)), MapDecor.scatter(_map(4)))


func test_it_returns_items_but_never_more_than_the_count() -> void:
	var items := MapDecor.scatter(_map())
	assert_gt(items.size(), 0)
	assert_lte(items.size(), 50)


func test_every_rect_is_inside_the_map() -> void:
	var map := _map()
	for item in MapDecor.scatter(map):
		assert_true(map.bounds().encloses(item["rect"]), str(item["rect"]))


func test_nothing_sits_near_the_player_start_or_a_placement() -> void:
	var map := _map()
	for item in MapDecor.scatter(map):
		var center: Vector2 = (item["rect"] as Rect2).get_center()
		assert_gte(center.distance_to(map.player_start), MapDecor.CLEAR_RADIUS)
		assert_gte(center.distance_to(Vector2(50, 50)), MapDecor.CLEAR_RADIUS)


func test_colors_come_from_the_map() -> void:
	var map := _map()
	for item in MapDecor.scatter(map):
		assert_true(map.decoration_colors.has(item["color"]))


func test_zero_count_or_no_colors_gives_nothing() -> void:
	var none := _map()
	none.decoration_count = 0
	assert_eq(MapDecor.scatter(none).size(), 0)
	var plain := _map()
	plain.decoration_colors = PackedColorArray()
	assert_eq(MapDecor.scatter(plain).size(), 0)


func test_an_impossible_map_ends_with_fewer_items() -> void:
	var map := _map()
	map.size = Vector2(30, 30)
	map.player_start = Vector2(15, 15)
	map.decoration_count = 1000
	assert_lt(MapDecor.scatter(map).size(), 1000)


func test_layer_holds_the_items_it_is_given() -> void:
	var layer := MapDecorLayer.new()
	add_child_autofree(layer)
	var items: Array[Dictionary] = [
		{"rect": Rect2(0, 0, 2, 2), "color": Color.RED},
		{"rect": Rect2(5, 5, 2, 2), "color": Color.RED},
		{"rect": Rect2(9, 9, 2, 2), "color": Color.RED},
	]
	layer.set_decor(items)
	assert_eq(layer.item_count(), 3)


func _zone(area: Rect2, count: int = 30, colors: PackedColorArray = PackedColorArray([Color(0.5, 0.2, 0.2), Color(0.4, 0.1, 0.1)])) -> MapZone:
	var zone := MapZone.new()
	zone.area = area
	zone.display_name = "Test"
	zone.decoration_count = count
	zone.decoration_colors = colors
	return zone


func test_scatter_never_puts_a_decoration_on_a_solid_shape() -> void:
	var map := _map()
	map.decoration_count = 300
	var wall := MapObstacle.new()
	wall.kind = MapObstacle.Kind.RECT
	wall.position = Vector2(300, 220)
	wall.size = Vector2(120, 60)
	map.obstacles = [wall] as Array[MapObstacle]
	var maze := MapMaze.new()
	maze.area = Rect2(40, 30, 160, 80)
	maze.maze_seed = 2
	map.mazes = [maze] as Array[MapMaze]
	var shapes := map.solid_shapes()
	var items := MapDecor.scatter(map)
	assert_gt(items.size(), 20)
	for item in items:
		for shape in shapes:
			assert_false(shape.contains((item["rect"] as Rect2).get_center(), 2.0), "decoration on a shape at %s" % item["rect"])


func test_zone_decorations_stay_inside_their_zone_and_are_deterministic() -> void:
	var map := _map()
	var area := Rect2(220, 20, 160, 120)
	map.zones = [_zone(area)] as Array[MapZone]
	var first := MapDecor.scatter_zone(map, 0)
	assert_gt(first.size(), 5)
	for item in first:
		assert_true(area.encloses(item["rect"]), str(item["rect"]))
	assert_eq(first, MapDecor.scatter_zone(map, 0))


func test_zone_decorations_use_the_zone_colors_and_count() -> void:
	var map := _map()
	var colors := PackedColorArray([Color(0.5, 0.2, 0.2), Color(0.4, 0.1, 0.1)])
	map.zones = [_zone(Rect2(220, 20, 160, 120), 12, colors)] as Array[MapZone]
	var items := MapDecor.scatter_zone(map, 0)
	assert_lte(items.size(), 12)
	for item in items:
		assert_true(colors.has(item["color"]))


func test_a_zone_with_no_colors_or_count_gives_nothing() -> void:
	var map := _map()
	map.zones = [_zone(Rect2(220, 20, 160, 120), 0), _zone(Rect2(220, 20, 160, 120), 30, PackedColorArray())] as Array[MapZone]
	assert_eq(MapDecor.scatter_zone(map, 0).size(), 0)
	assert_eq(MapDecor.scatter_zone(map, 1).size(), 0)
	assert_eq(MapDecor.scatter_zone(map, 5).size(), 0, "an index out of range gives nothing")
