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
