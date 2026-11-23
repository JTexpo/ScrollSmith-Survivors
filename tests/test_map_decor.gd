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


func test_the_layer_splits_its_drawing_into_chunks_and_keeps_the_count() -> void:
	var layer := MapDecorLayer.new()
	add_child_autofree(layer)
	var items: Array[Dictionary] = []
	var keys := {}
	for i in 40:
		var at := Vector2((i * 97) % 1500, (i * 61) % 900)
		items.append({"rect": Rect2(at, Vector2(3, 3)), "color": Color.RED})
		keys[Vector2i((at + Vector2(1.5, 1.5)) / MapDecorLayer.CHUNK_SIZE)] = true
	layer.set_decor(items)
	assert_eq(layer.item_count(), 40)
	assert_eq(layer.chunk_count(), keys.size())
	assert_gt(layer.chunk_count(), 1)
	layer.set_decor([] as Array[Dictionary])
	assert_eq(layer.item_count(), 0)
	await wait_frames(1)
	assert_eq(layer.chunk_count(), 0, "old chunks are gone")


func test_a_map_without_styles_scatters_exactly_as_before() -> void:
	# Captured from the scatter before styles existed (seed 3): the first three rects and the count.
	var items := MapDecor.scatter(_map(3))
	assert_eq(items.size(), 50)
	var expected := [Vector2(285.97, 101.1249), Vector2(311.542, 117.432), Vector2(275.9686, 283.9378)]
	var sizes := [2.998982, 2.610193, 2.954839]
	for i in 3:
		assert_almost_eq((items[i]["rect"] as Rect2).position.x, expected[i].x, 0.001)
		assert_almost_eq((items[i]["rect"] as Rect2).position.y, expected[i].y, 0.001)
		assert_almost_eq((items[i]["rect"] as Rect2).size.x, sizes[i], 0.001)
	for item in items:
		assert_eq(item["style"], &"", "no styles means an empty style")
		assert_eq(item["frame"], 0)


func _styled_map(seed_value: int = 3) -> MapData:
	var map := _map(seed_value)
	map.decoration_styles = PackedStringArray(["moss", "pebbles"])
	return map


func test_items_carry_a_style_from_the_list_and_a_frame() -> void:
	var seen := {}
	for item in MapDecor.scatter(_styled_map()):
		assert_true(item["style"] in [&"moss", &"pebbles"], str(item["style"]))
		assert_gte(item["frame"], 0)
		seen[item["style"]] = true
	assert_eq(seen.size(), 2, "both styles are used")


func test_the_same_seed_gives_the_same_styles() -> void:
	assert_eq(MapDecor.scatter(_styled_map(5)), MapDecor.scatter(_styled_map(5)))
	assert_ne(MapDecor.scatter(_styled_map(5)), MapDecor.scatter(_styled_map(6)))


func test_art_decorations_still_keep_clear_of_walls_the_start_and_placements() -> void:
	var map := _styled_map()
	var wall := MapObstacle.new()
	wall.kind = MapObstacle.Kind.RECT
	wall.position = Vector2(300, 200)
	wall.size = Vector2(100, 16)
	map.obstacles = [wall] as Array[MapObstacle]
	var items := MapDecor.scatter(map)
	assert_gt(items.size(), 0)
	for item in items:
		var centre := (item["rect"] as Rect2).get_center()
		assert_false(wall.contains(centre, MapDecor.SHAPE_MARGIN), "not on the wall")
		assert_gte(centre.distance_to(map.player_start), MapDecor.CLEAR_RADIUS)
		assert_gte(centre.distance_to(Vector2(50, 50)), MapDecor.CLEAR_RADIUS)


func test_a_zone_with_only_styles_still_scatters() -> void:
	var map := _map()
	var zone := MapZone.new()
	zone.area = Rect2(200, 100, 160, 120)
	zone.decoration_count = 20
	zone.decoration_styles = PackedStringArray(["cracks"])
	map.zones = [zone] as Array[MapZone]
	var items := MapDecor.scatter_zone(map, 0)
	assert_gt(items.size(), 0)
	for item in items:
		assert_eq(item["style"], &"cracks")
		assert_true(zone.area.encloses(item["rect"]))


## How many cells of a grid laid over the map hold no decoration.
func _empty_cells(map: MapData, items: Array[Dictionary], columns: int, rows: int) -> int:
	var cell := Vector2(map.size.x / columns, map.size.y / rows)
	var filled := {}
	for item in items:
		var centre := (item["rect"] as Rect2).get_center()
		filled[Vector2i(int(centre.x / cell.x), int(centre.y / cell.y))] = true
	return columns * rows - filled.size()


func test_styled_decorations_are_spread_evenly_not_in_clumps() -> void:
	var map := _styled_map(3)
	map.decoration_count = 60
	var items := MapDecor.scatter(map)
	assert_gte(items.size(), 55)
	# 48 cells, and the player start and the lectern keep about three of them clear on purpose. Random scatter of 60 items
	# leaves about 16 empty; an even spread leaves close to those three.
	assert_lte(_empty_cells(map, items, 8, 6), 8, "no big pockets of bare floor")


func test_even_spread_keeps_every_decoration_apart() -> void:
	var map := _styled_map(7)
	map.decoration_count = 60
	var items := MapDecor.scatter(map)
	var closest := INF
	for i in items.size():
		for j in range(i + 1, items.size()):
			closest = minf(closest, ((items[i]["rect"] as Rect2).get_center()).distance_to((items[j]["rect"] as Rect2).get_center()))
	assert_gt(closest, 10.0, "no two decorations sit almost on top of each other")


func test_the_maps_own_decorations_stay_off_zones_that_scatter_their_own() -> void:
	var map := _styled_map(3)
	map.decoration_count = 80
	var zone := MapZone.new()
	zone.area = Rect2(200, 100, 160, 140)
	zone.floor_style = &"ruin"
	zone.decoration_count = 15
	zone.decoration_styles = PackedStringArray(["pebbles"])
	map.zones = [zone] as Array[MapZone]
	var own := MapDecor.scatter(map)
	assert_gt(own.size(), 0)
	for item in own:
		assert_false(zone.area.has_point((item["rect"] as Rect2).get_center()), "the map's items leave the zone's area to the zone")
	var theirs := MapDecor.scatter_zone(map, 0)
	assert_gt(theirs.size(), 0)
	for item in theirs:
		assert_true(zone.area.encloses(item["rect"]))


func test_a_zone_without_a_floor_style_does_not_claim_its_area() -> void:
	var map := _styled_map(3)
	map.decoration_count = 80
	var zone := MapZone.new()
	zone.area = Rect2(200, 100, 160, 140)
	map.zones = [zone] as Array[MapZone]
	var inside := 0
	for item in MapDecor.scatter(map):
		if zone.area.has_point((item["rect"] as Rect2).get_center()):
			inside += 1
	assert_gt(inside, 0, "a zone with no floor art leaves its area to the map's own scatter")
