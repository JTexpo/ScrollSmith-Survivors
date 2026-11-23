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


func test_an_invalid_map_is_reported_when_it_loads() -> void:
	var data := _data()
	data.player_start = Vector2(5000, 5000)
	_map_node(data)
	assert_push_error("player start")


func _obstacle_data() -> MapData:
	var data := _data()
	var rect := MapObstacle.new()
	rect.kind = MapObstacle.Kind.RECT
	rect.position = Vector2(300, 60)
	rect.size = Vector2(40, 20)
	var circle := MapObstacle.new()
	circle.kind = MapObstacle.Kind.CIRCLE
	circle.position = Vector2(300, 240)
	circle.radius = 15.0
	data.obstacles = [rect, circle] as Array[MapObstacle]
	return data


func test_each_obstacle_is_drawn_and_has_a_wall_body() -> void:
	var node := _map_node(_obstacle_data())
	assert_eq((node.get_node("Obstacles") as ObstacleLayer).item_count(), 2)
	var bodies := node.get_node("ObstacleBodies")
	assert_eq(bodies.get_child_count(), 2)
	for body in bodies.get_children():
		assert_eq((body as StaticBody2D).collision_layer, PhysicsLayers.WORLD)
		assert_eq((body as StaticBody2D).collision_mask, 0)
	var rect_shape := (bodies.get_child(0).get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	assert_eq(rect_shape.size, Vector2(40, 20))
	assert_eq(bodies.get_child(0).position, Vector2(300, 60))
	var circle_shape := (bodies.get_child(1).get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	assert_eq(circle_shape.radius, 15.0)


func test_it_builds_an_obstacle_map() -> void:
	var node := _map_node(_obstacle_data())
	var obstacle_map := node.get_node("ObstacleMap") as ObstacleMap
	assert_true(obstacle_map.is_in_group(&"obstacle_map"))
	assert_true(obstacle_map.is_blocked(Vector2(300, 60)))
	assert_false(obstacle_map.is_blocked(Vector2(40, 280)))


func test_a_body_pushed_at_an_obstacle_is_stopped() -> void:
	_map_node(_obstacle_data())
	var body := CharacterBody2D.new()
	body.collision_mask = PhysicsLayers.WORLD
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	body.add_child(shape)
	add_child_autofree(body)
	body.position = Vector2(250, 60)
	await wait_physics_frames(3)
	body.move_and_collide(Vector2(100, 0))
	assert_lte(body.position.x, 276.1)


func test_an_unreachable_placement_is_reported_when_it_loads() -> void:
	var data := _data()
	data.size = Vector2(320, 160)
	data.player_start = Vector2(8, 8)
	data.body_clearance = 0.0
	data.placements[0].position = Vector2(160, 80)
	var walls: Array[MapObstacle] = []
	for spec in [[Vector2(160, 40), Vector2(96, 8)], [Vector2(160, 120), Vector2(96, 8)], [Vector2(120, 80), Vector2(8, 96)], [Vector2(200, 80), Vector2(8, 96)]]:
		var wall := MapObstacle.new()
		wall.kind = MapObstacle.Kind.RECT
		wall.position = spec[0]
		wall.size = spec[1]
		walls.append(wall)
	data.obstacles = walls
	_map_node(data)
	assert_push_error("not reachable")


func _maze_only_data() -> MapData:
	var data := _data()
	data.size = Vector2(700, 420)
	data.player_start = Vector2(8, 8)
	data.placements = [] as Array[MapPlacement]
	var maze := MapMaze.new()
	maze.area = Rect2(100, 52, 480, 320)
	maze.maze_seed = 3
	data.mazes = [maze] as Array[MapMaze]
	return data


func test_a_maze_is_drawn_and_has_wall_bodies() -> void:
	var data := _maze_only_data()
	var node := _map_node(data)
	var walls := data.mazes[0].shapes().size()
	assert_gt(walls, 10)
	assert_eq((node.get_node("Obstacles") as ObstacleLayer).item_count(), walls)
	assert_eq(node.get_node("ObstacleBodies").get_child_count(), walls)


func _zoned_data() -> MapData:
	var data := _data()
	var first := MapZone.new()
	first.area = Rect2(0, 0, 200, 150)
	first.floor_color = Color(0.5, 0.2, 0.2)
	first.decoration_count = 15
	first.decoration_colors = PackedColorArray([Color(0.6, 0.3, 0.3)])
	var second := MapZone.new()
	second.area = Rect2(200, 150, 200, 150)
	second.floor_color = Color(0.2, 0.2, 0.5)
	data.zones = [first, second] as Array[MapZone]
	return data


func test_each_zone_has_a_floor_under_the_decorations() -> void:
	var data := _zoned_data()
	var node := _map_node(data)
	var zones := node.get_node("Zones")
	assert_eq(zones.get_child_count(), 2)
	for i in 2:
		var floor_rect := zones.get_child(i) as ColorRect
		assert_eq(Rect2(floor_rect.position, floor_rect.size), data.zones[i].area)
		assert_eq(floor_rect.color, data.zones[i].floor_color)
		assert_eq(floor_rect.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_lt(node.get_node("Floor").get_index(), zones.get_index())
	assert_lt(zones.get_index(), node.get_node("Decor").get_index())


func test_the_decor_layer_holds_global_and_zone_items() -> void:
	var data := _zoned_data()
	var node := _map_node(data)
	var expected := MapDecor.scatter(data).size() + MapDecor.scatter_zone(data, 0).size() + MapDecor.scatter_zone(data, 1).size()
	assert_eq((node.get_node("Decor") as MapDecorLayer).item_count(), expected)


func test_the_obstacle_layer_is_split_into_chunks_and_keeps_the_count() -> void:
	var layer := ObstacleLayer.new()
	add_child_autofree(layer)
	var shapes: Array[MapObstacle] = []
	var keys := {}
	for i in 12:
		var shape := MapObstacle.new()
		shape.kind = MapObstacle.Kind.RECT
		shape.position = Vector2(100 + i * 150, 80 + (i % 3) * 300)
		shape.size = Vector2(20, 20)
		shapes.append(shape)
		keys[Vector2i(shape.position / ObstacleLayer.CHUNK_SIZE)] = true
	layer.set_obstacles(shapes)
	assert_eq(layer.item_count(), 12)
	assert_eq(layer.chunk_count(), keys.size())
	assert_gt(layer.chunk_count(), 1)


const ART_ROOT := "res://.godot/art_tests"

var _art_dir: String


func _tile_art(file: String) -> void:
	if _art_dir == "":
		_art_dir = "%s/g_%s" % [ART_ROOT, str(randi())]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_art_dir))
		SpriteLibrary.root = _art_dir
	var set_data := SpriteSetData.new()
	set_data.sheet = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	set_data.frame_size = Vector2i(16, 16)
	set_data.tile = true
	assert_eq(ResourceSaver.save(set_data, "%s/%s" % [_art_dir, file]), OK)


func after_each() -> void:
	if _art_dir != "":
		SpriteLibrary.root = "res://assets/sprites"
		var absolute := ProjectSettings.globalize_path(_art_dir)
		for file in DirAccess.get_files_at(absolute):
			DirAccess.remove_absolute("%s/%s" % [absolute, file])
		DirAccess.remove_absolute(absolute)
		_art_dir = ""


func _styled_data() -> MapData:
	var data := _zoned_data()
	data.floor_style = &"grass"
	data.border_style = &"border"
	data.zones[0].floor_style = &"path"
	return data


func test_floor_styles_add_patches_in_draw_order() -> void:
	_tile_art("tile_grass_base.tres")
	_tile_art("tile_border_base.tres")
	_tile_art("tile_path_base.tres")
	var data := _styled_data()
	var node := _map_node(data)
	var base := node.get_node("BaseArt")
	assert_eq(base.get_child_count(), 2, "the border and the map")
	assert_eq((base.get_child(0) as FloorPatch).area, Rect2(-Vector2(GameMap.BORDER_MARGIN, GameMap.BORDER_MARGIN), data.size + Vector2(GameMap.BORDER_MARGIN, GameMap.BORDER_MARGIN) * 2.0))
	assert_eq((base.get_child(1) as FloorPatch).area, data.bounds())
	var zone_art := node.get_node("ZoneArt")
	assert_eq(zone_art.get_child_count(), 1, "only the zone with a style")
	assert_eq((zone_art.get_child(0) as FloorPatch).area, data.zones[0].area)
	assert_lt(node.get_node("Floor").get_index(), base.get_index())
	assert_lt(base.get_index(), node.get_node("Zones").get_index())
	assert_lt(node.get_node("Zones").get_index(), zone_art.get_index())
	assert_lt(zone_art.get_index(), node.get_node("Decor").get_index())


func test_a_missing_style_adds_no_patch_and_keeps_the_colour() -> void:
	var data := _styled_data()
	data.floor_style = &"no_such_floor"
	data.border_style = &"no_such_border"
	data.zones[0].floor_style = &"no_such_zone_floor"
	var node := _map_node(data)
	assert_eq(node.get_node("BaseArt").get_child_count(), 0)
	assert_eq(node.get_node("ZoneArt").get_child_count(), 0)
	assert_eq((node.get_node("Floor") as ColorRect).color, data.floor_color)
	assert_eq((node.get_node("Zones").get_child(0) as ColorRect).color, data.zones[0].floor_color)


func test_floor_patches_never_catch_touches() -> void:
	_tile_art("tile_grass_base.tres")
	_tile_art("tile_path_base.tres")
	var data := _styled_data()
	var node := _map_node(data)
	var patches: Array[Node] = node.get_node("BaseArt").get_children() + node.get_node("ZoneArt").get_children()
	assert_gt(patches.size(), 0)
	for patch in patches:
		assert_true(patch is Node2D and not patch is Control, "%s is a drawing, not a Control" % patch.name)


func _wall_art(file: String, tile: bool = true) -> void:
	_tile_art(file)
	var set_data := load("%s/%s" % [_art_dir, file]) as SpriteSetData
	set_data.slice = Vector4i(4, 4, 4, 4) if tile else Vector4i.ZERO
	assert_eq(ResourceSaver.save(set_data, "%s/%s" % [_art_dir, file]), OK)


func _art_obstacle(kind: MapObstacle.Kind, at: Vector2, material: StringName) -> MapObstacle:
	var obstacle := MapObstacle.new()
	obstacle.kind = kind
	obstacle.position = at
	obstacle.size = Vector2(160, 16)
	obstacle.radius = 20.0
	obstacle.material = material
	return obstacle


func _art_obstacle_data(material: StringName) -> MapData:
	var data := _data()
	data.obstacles = [_art_obstacle(MapObstacle.Kind.RECT, Vector2(150, 200), material), _art_obstacle(MapObstacle.Kind.CIRCLE, Vector2(300, 100), material)] as Array[MapObstacle]
	return data


func test_obstacle_art_never_changes_the_shapes_bodies_or_blocking() -> void:
	var plain := _map_node(_art_obstacle_data(&""))
	_wall_art("wall_hedge_base.tres")
	_wall_art("post_hedge_base.tres", false)
	var styled := _map_node(_art_obstacle_data(&"hedge"))
	assert_eq((styled.get_node("Obstacles") as ObstacleLayer).item_count(), (plain.get_node("Obstacles") as ObstacleLayer).item_count())
	assert_eq(styled.get_node("ObstacleBodies").get_child_count(), plain.get_node("ObstacleBodies").get_child_count())
	for i in styled.get_node("ObstacleBodies").get_child_count():
		var a := styled.get_node("ObstacleBodies").get_child(i) as StaticBody2D
		var b := plain.get_node("ObstacleBodies").get_child(i) as StaticBody2D
		assert_eq(a.position, b.position)
		assert_eq((a.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect(), (b.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect())
	var plain_map := plain.get_node("ObstacleMap") as ObstacleMap
	var styled_map := styled.get_node("ObstacleMap") as ObstacleMap
	for point in [Vector2(150, 200), Vector2(300, 100), Vector2(50, 50), Vector2(150, 230)]:
		assert_eq(styled_map.is_blocked(point), plain_map.is_blocked(point), "%s" % point)


func test_a_wall_with_art_is_drawn_as_art_and_one_without_keeps_the_flat_colour() -> void:
	_wall_art("wall_hedge_base.tres")
	_wall_art("post_hedge_base.tres", false)
	var chunks := (_map_node(_art_obstacle_data(&"hedge")).get_node("Obstacles") as ObstacleLayer)
	var with_art := 0
	for chunk in chunks.chunks():
		with_art += chunk.art_obstacle_count()
	assert_eq(with_art, 2, "the wall and the post use their art")
	for material in [&"", &"no_such_material"]:
		var flat := (_map_node(_art_obstacle_data(material)).get_node("Obstacles") as ObstacleLayer)
		var count := 0
		for chunk in flat.chunks():
			count += chunk.art_obstacle_count()
		assert_eq(count, 0, "no art for '%s' keeps the flat fill" % material)


func test_draw_chunks_with_art_still_split_the_layer() -> void:
	_wall_art("wall_hedge_base.tres")
	var data := _art_obstacle_data(&"hedge")
	data.obstacles[0].position = Vector2(250, 220)
	data.obstacles[1].position = Vector2(900, 700)
	data.size = Vector2(1200, 900)
	var layer := _map_node(data).get_node("Obstacles") as ObstacleLayer
	assert_gt(layer.chunk_count(), 1, "far apart obstacles are in different chunks")


func _decor_art(file: String, frames: int) -> void:
	_tile_art(file)
	var set_data := load("%s/%s" % [_art_dir, file]) as SpriteSetData
	set_data.tile = false
	set_data.frame_size = Vector2i(8, 8)
	set_data.sheet = ImageTexture.create_from_image(Image.create(8 * frames, 8, false, Image.FORMAT_RGBA8))
	assert_eq(ResourceSaver.save(set_data, "%s/%s" % [_art_dir, file]), OK)


func _decor_art_count(node: GameMap) -> int:
	var count := 0
	for chunk in (node.get_node("Decor") as MapDecorLayer).get_children():
		count += (chunk as DrawChunk).art_decor_count()
	return count


func test_decor_with_art_is_drawn_as_art_and_item_counts_do_not_change() -> void:
	var data := _data()
	data.decoration_styles = PackedStringArray(["moss"])
	var plain := _map_node(_data())
	_decor_art("decor_moss_base.tres", 3)
	var styled := _map_node(data)
	assert_eq((styled.get_node("Decor") as MapDecorLayer).item_count(), (styled.get_node("Decor") as MapDecorLayer).item_count())
	assert_gt(_decor_art_count(styled), 0)
	assert_eq(_decor_art_count(styled), (styled.get_node("Decor") as MapDecorLayer).item_count(), "every item has art")
	assert_eq(_decor_art_count(plain), 0, "a map with no styles keeps its coloured squares")


func test_decor_with_a_missing_style_keeps_its_coloured_squares() -> void:
	var data := _data()
	data.decoration_styles = PackedStringArray(["no_such_decoration"])
	var node := _map_node(data)
	assert_gt((node.get_node("Decor") as MapDecorLayer).item_count(), 0)
	assert_eq(_decor_art_count(node), 0)


func test_a_zone_with_floor_art_hides_its_flat_tint_and_one_without_keeps_it() -> void:
	_tile_art("tile_path_base.tres")
	var data := _zoned_data()
	data.zones[0].floor_style = &"path"
	var node := _map_node(data)
	var zones := node.get_node("Zones")
	assert_false((zones.get_child(0) as ColorRect).visible, "the art covers it, so a hard-edged tint must not show through the ragged edge")
	assert_true((zones.get_child(1) as ColorRect).visible, "a zone with no art keeps its tint")
	assert_eq((zones.get_child(0) as ColorRect).color, data.zones[0].floor_color, "the node and its colour stay")


func test_zone_patches_are_soft_and_the_base_patches_are_hard() -> void:
	_tile_art("tile_grass_base.tres")
	_tile_art("tile_border_base.tres")
	_tile_art("tile_path_base.tres")
	var node := _map_node(_styled_data())
	for patch in node.get_node("BaseArt").get_children():
		assert_eq((patch as FloorPatch).omitted_cells().size(), 0, "%s is hard-edged" % patch.name)
	var zone_patch := node.get_node("ZoneArt").get_child(0) as FloorPatch
	assert_gt(zone_patch.omitted_cells().size(), 0, "the zone's edge is ragged")


func test_wall_centres_are_drawn_after_every_border_even_across_chunks() -> void:
	_wall_art("wall_hedge_base.tres")
	var data := _data()
	data.size = Vector2(1200, 900)
	# A long wall and a short one that crosses it, with their centres in different 512 px chunks.
	var long_wall := _art_obstacle(MapObstacle.Kind.RECT, Vector2(400, 400), &"hedge")
	long_wall.size = Vector2(700, 16)
	var crossing := _art_obstacle(MapObstacle.Kind.RECT, Vector2(600, 400), &"hedge")
	crossing.size = Vector2(16, 200)
	data.obstacles = [long_wall, crossing] as Array[MapObstacle]
	var layer := _map_node(data).get_node("Obstacles") as ObstacleLayer
	assert_gt(layer.chunk_count(), 1, "the two walls are in different chunks")
	var centres := layer.get_node("Centres")
	assert_gt(centres.get_child_count(), 0)
	for chunk in layer.chunks():
		assert_false(chunk.centres_only)
		assert_lt(chunk.get_index(), centres.get_index(), "every border chunk draws before the centres")
	for chunk in centres.get_children():
		assert_true((chunk as DrawChunk).centres_only)


func test_the_floor_layers_draw_below_the_shadows_and_the_walls_above_them() -> void:
	var node := _map_node(_data())
	for layer in ["Border", "Floor", "BaseArt", "Zones", "ZoneArt", "Decor"]:
		assert_lt((node.get_node(layer) as CanvasItem).z_index, BodyView.SHADOW_Z, "%s is under the shadows" % layer)
		assert_true((node.get_node(layer) as CanvasItem).z_as_relative)
	assert_eq((node.get_node("Obstacles") as CanvasItem).z_index, 0, "walls and trees are over the shadows")

