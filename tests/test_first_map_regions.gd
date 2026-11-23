extends GutTest

const LECTERN := "res://scenes/interactables/lectern.tscn"

var _map: MapData
var _grid: ObstacleGrid


func before_each() -> void:
	_map = load("res://resources/maps/first_map.tres") as MapData
	_grid = ObstacleGrid.build(_map)


func _zone(zone_name: String) -> MapZone:
	for zone in _map.zones:
		if zone.display_name == zone_name:
			return zone
	return null


func test_the_first_map_has_a_maze_and_distinct_zone_tints() -> void:
	assert_eq(_map.mazes.size(), 2)
	assert_gte(_map.zones.size(), 3)
	var tints := {}
	for zone in _map.zones:
		tints[zone.floor_color] = true
	assert_eq(tints.size(), _map.zones.size(), "every zone has its own tint")
	assert_not_null(_zone("Maze"))
	assert_not_null(_zone("Labyrinth"))
	assert_not_null(_zone("Island"))
	assert_not_null(_zone("Corridor"))


func test_the_lecterns_are_outside_the_maze_and_the_walled_island() -> void:
	var island := _zone("Island").area
	var lecterns := 0
	for placement in _map.placements:
		if placement.scene.resource_path == LECTERN:
			lecterns += 1
			for maze in _map.mazes:
				assert_false(maze.area.grow(24.0).has_point(placement.position), "Lectern at %s is in a maze" % placement.position)
			assert_false(island.has_point(placement.position), "Lectern at %s is on the island" % placement.position)
	assert_eq(lecterns, 3)


func test_the_maze_and_island_are_deterministic() -> void:
	var first := _map.solid_shapes()
	var again := (load("res://resources/maps/first_map.tres") as MapData).solid_shapes()
	assert_eq(first.size(), again.size())
	for i in first.size():
		assert_eq(first[i].position, again[i].position)
		assert_eq(first[i].size, again[i].size)


func test_the_maze_centre_and_the_island_interior_are_free_for_12d() -> void:
	for maze in _map.mazes:
		var maze_centre := maze.center_room_center()
		assert_false(_grid.is_blocked(maze_centre), "a maze's cleared centre")
		for offset in [Vector2(-40, 0), Vector2(40, 0), Vector2(0, -40), Vector2(0, 40)]:
			assert_false(_grid.is_blocked(maze_centre + offset))
	var island_centre := _zone("Island").area.get_center()
	assert_false(_grid.is_blocked(island_centre), "the island's interior")
	for offset in [Vector2(-40, 0), Vector2(40, 0), Vector2(0, -40), Vector2(0, 40)]:
		assert_false(_grid.is_blocked(island_centre + offset))


func test_the_map_has_many_narrow_runs() -> void:
	var lines := 0
	for along_rows in [true, false]:
		var line_count: int = _grid.rows if along_rows else _grid.columns
		var length: int = _grid.columns if along_rows else _grid.rows
		for line in line_count:
			var found := false
			var i := 0
			while i < length and not found:
				var cell := Vector2i(i, line) if along_rows else Vector2i(line, i)
				if _grid.is_blocked_cell(cell):
					i += 1
					continue
				var start := i
				while i < length and not _grid.is_blocked_cell(Vector2i(i, line) if along_rows else Vector2i(line, i)):
					i += 1
				if start > 0 and i < length and i - start <= 3:
					found = true
			if found:
				lines += 1
	assert_gte(lines, 60, "a maze and a corridor give many lines with a 2 to 3 cell bounded run")


func test_the_south_east_maze_is_the_half_turn_image_of_the_north_west_one() -> void:
	var first := _map.mazes[0]
	var second := _map.mazes[1]
	assert_false(first.rotated)
	assert_true(second.rotated)
	assert_eq(first.maze_seed, second.maze_seed)
	assert_eq(first.area.size, second.area.size)
	assert_eq(first.extra_openings, second.extra_openings)
	var turned := second.shapes()
	var mirrored := first.shapes()
	assert_eq(mirrored.size(), turned.size())
	for shape in mirrored:
		var image := _map.size - shape.position
		var found := false
		for other in turned:
			if other.position.distance_to(image) < 0.01 and other.size == shape.size:
				found = true
				break
		assert_true(found, "no mirrored wall for %s" % shape.position)


func test_the_first_map_has_no_scattered_decoration() -> void:
	assert_eq(MapDecor.scatter(_map).size(), 0, "the plaza's flowers, mushrooms and pebbles were removed (play feedback: distracting)")
	for i in _map.zones.size():
		assert_eq(MapDecor.scatter_zone(_map, i).size(), 0, "zone %d" % i)

