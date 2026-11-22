extends GutTest

const LECTERN := "res://scenes/interactables/lectern.tscn"


func _data() -> MapData:
	var map := MapData.new()
	map.id = &"test"
	map.size = Vector2(400, 300)
	map.player_start = Vector2(200, 150)
	map.floor_color = Color(0.3, 0.4, 0.5)
	map.border_color = Color(0.1, 0.1, 0.1)
	var placement := MapPlacement.new()
	placement.scene = load(LECTERN)
	placement.position = Vector2(100, 100)
	map.placements = [placement] as Array[MapPlacement]
	map.decoration_count = 20
	map.decoration_seed = 5
	map.decoration_colors = PackedColorArray([Color(0.2, 0.3, 0.2)])
	return map


func _map_node(data: MapData) -> GameMap:
	var node := (load("res://scenes/world/game_map.tscn") as PackedScene).instantiate() as GameMap
	node.map_data = data
	add_child_autofree(node)
	return node


func _wall_rects(node: GameMap) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for wall in node.get_node("Walls").get_children():
		var shape := (wall.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
		rects.append(Rect2(wall.position - shape.size / 2.0, shape.size))
	return rects


func test_floor_covers_exactly_the_bounds() -> void:
	var node := _map_node(_data())
	var floor_rect := node.get_node("Floor") as ColorRect
	assert_eq(Rect2(floor_rect.position, floor_rect.size), Rect2(0, 0, 400, 300))
	assert_eq(floor_rect.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(floor_rect.color, Color(0.3, 0.4, 0.5))
	var border := node.get_node("Border") as ColorRect
	assert_eq(border.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(border.color, Color(0.1, 0.1, 0.1))
	assert_true(Rect2(border.position, border.size).encloses(Rect2(0, 0, 400, 300)))


func test_four_walls_on_the_world_layer() -> void:
	var walls := _map_node(_data()).get_node("Walls")
	assert_eq(walls.get_child_count(), 4)
	for wall in walls.get_children():
		assert_true(wall is StaticBody2D)
		assert_eq((wall as StaticBody2D).collision_layer, PhysicsLayers.WORLD)
		assert_eq((wall as StaticBody2D).collision_mask, 0)


func test_walls_enclose_the_map_including_the_corners() -> void:
	var rects := _wall_rects(_map_node(_data()))
	var outside: Array[Vector2] = [
		Vector2(-1, -1), Vector2(401, -1), Vector2(-1, 301), Vector2(401, 301),
		Vector2(200, -1), Vector2(200, 301), Vector2(-1, 150), Vector2(401, 150),
	]
	for point in outside:
		var covered := false
		for rect in rects:
			covered = covered or rect.has_point(point)
		assert_true(covered, "nothing blocks %s" % point)


func test_a_body_pushed_at_a_wall_is_stopped() -> void:
	_map_node(_data())
	var body := CharacterBody2D.new()
	body.collision_mask = PhysicsLayers.WORLD
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	body.add_child(shape)
	add_child_autofree(body)
	body.position = Vector2(6, 150)
	await wait_physics_frames(3)
	body.move_and_collide(Vector2(-50, 0))
	assert_gte(body.position.x, 3.9)


func test_each_placement_is_instanced_at_its_position() -> void:
	var placements := _map_node(_data()).get_node("Placements")
	assert_eq(placements.get_child_count(), 1)
	var placed := placements.get_child(0) as Node2D
	assert_eq(placed.position, Vector2(100, 100))
	assert_true(placed.is_in_group(&"lecterns"))


func test_decorations_are_scattered_from_the_data() -> void:
	var data := _data()
	var node := _map_node(data)
	assert_eq((node.get_node("Decor") as MapDecorLayer).item_count(), MapDecor.scatter(data).size())


func test_bounds_and_player_start_come_from_the_data() -> void:
	var node := _map_node(_data())
	assert_eq(node.bounds(), Rect2(0, 0, 400, 300))
	assert_eq(node.player_start(), Vector2(200, 150))


func test_without_map_data_it_builds_nothing() -> void:
	var node := _map_node(null)
	assert_null(node.get_node_or_null("Floor"))
	assert_eq(node.bounds(), Rect2())
	assert_eq(node.player_start(), Vector2.ZERO)
