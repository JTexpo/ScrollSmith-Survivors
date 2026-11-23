class_name MapData
extends Resource
## Everything that makes one map different from another. `GameMap` builds the world from it.

const OBSTACLE_CLEARANCE := 24.0

@export var id: StringName
@export var display_name: String = ""
@export var size: Vector2 = Vector2(1920, 1080)
@export var floor_color: Color = Color(0.16, 0.2, 0.17, 1)
@export var border_color: Color = Color(0.08, 0.1, 0.09, 1)
@export var player_start: Vector2 = Vector2(960, 540)
## Null keeps the spawn config the scene already has.
@export var spawn_config: SpawnConfig
@export var placements: Array[MapPlacement] = []
@export var decoration_count: int = 0
@export var decoration_seed: int = 0
@export var decoration_colors: PackedColorArray = PackedColorArray()
## Smallest and largest side of a decoration, in pixels.
@export var decoration_size: Vector2 = Vector2(2, 5)
## Solid shapes that block movement and enemy projectiles.
@export var obstacles: Array[MapObstacle] = []
## Side of one navigation grid cell, in pixels.
@export var nav_cell_size: float = 16.0
## How far an obstacle is grown for the grid, so an enemy's body never touches it.
@export var body_clearance: float = 8.0
## How close a body may come to a wall and still have a clear line along it. A little under half the width of a body
## (the player and a plain enemy are 12 px wide), so a body pressed flat against a wall is not called blocked by a
## rounding error.
@export var body_radius: float = 5.0
## Mazes generated from data. Their walls count as obstacles through `solid_shapes()`.
@export var mazes: Array[MapMaze] = []
## Regions with their own floor tint and decorations.
@export var zones: Array[MapZone] = []


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, size)


## Every solid shape of the map: the authored obstacles, then each maze's walls. Built fresh on each call, so
## callers keep the result. This is the one list the grid, the walls, the shape tests and the overlay read.
func solid_shapes() -> Array[MapObstacle]:
	var shapes: Array[MapObstacle] = []
	shapes.append_array(obstacles)
	for maze in mazes:
		if maze != null:
			shapes.append_array(maze.shapes())
	return shapes


## One line per fault. Empty means the map can be built.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if id == &"":
		found.append("the map has no id")
	if size.x <= 0.0 or size.y <= 0.0:
		found.append("the size %s is not positive" % size)
		return found
	var area := bounds()
	if not area.has_point(player_start):
		found.append("the player start %s is outside the map" % player_start)
	for i in placements.size():
		var placement := placements[i]
		if placement == null or placement.scene == null:
			found.append("placement %d has no scene" % i)
		elif not area.has_point(placement.position):
			found.append("placement %d at %s is outside the map" % [i, placement.position])
	# A maze with its own problems is reported once and its walls are not checked, so one fault is one line.
	var checked: Array[MapObstacle] = []
	checked.append_array(obstacles)
	for i in mazes.size():
		if mazes[i] == null:
			found.append("maze %d is empty" % i)
			continue
		var maze_problems := mazes[i].problems(area)
		for line in maze_problems:
			found.append("maze %d: %s" % [i, line])
		if maze_problems.is_empty():
			checked.append_array(mazes[i].shapes())
	for i in zones.size():
		if zones[i] == null or zones[i].area.size.x <= 0.0 or zones[i].area.size.y <= 0.0:
			found.append("zone %d has no area" % i)
		elif not area.encloses(zones[i].area):
			found.append("zone %d at %s is not inside the map" % [i, zones[i].area])
	for i in checked.size():
		var obstacle := checked[i]
		if obstacle == null or not obstacle.is_valid():
			found.append("obstacle %d has no usable size" % i)
			continue
		if not area.encloses(obstacle.bounds()):
			found.append("obstacle %d at %s is not fully inside the map" % [i, obstacle.position])
		if obstacle.contains(player_start, OBSTACLE_CLEARANCE):
			found.append("obstacle %d is on or too close to the player start" % i)
		for j in placements.size():
			if placements[j] != null and obstacle.contains(placements[j].position, OBSTACLE_CLEARANCE):
				found.append("obstacle %d is on or too close to placement %d" % [i, j])
	return found
