class_name GameMap
extends Node2D
## Builds the world from a `MapData`: the floor, the walls around it, the decorations and every
## placed scene. It holds no gameplay rules, so a new map is a new `MapData` and no new code.

## How thick each boundary wall is, just outside the map's edge.
const WALL_THICKNESS := 20.0
## How far the border colour reaches past the map's edge.
const BORDER_MARGIN := 32.0

@export var map_data: MapData


func _ready() -> void:
	if map_data == null:
		return
	for problem in map_data.problems():
		push_error("Map '%s': %s" % [map_data.id, problem])
	for problem in ObstacleGrid.reachability_problems(map_data):
		push_error("Map '%s': %s" % [map_data.id, problem])
	var border_rect := Rect2(-Vector2(BORDER_MARGIN, BORDER_MARGIN), map_data.size + Vector2(BORDER_MARGIN, BORDER_MARGIN) * 2.0)
	_add_rect(&"Border", border_rect, map_data.border_color)
	_add_rect(&"Floor", map_data.bounds(), map_data.floor_color)
	# The floor art goes over the flat colours, which stay as the fallback. A zone's own tint comes after the map's art, so
	# a zone with no style still shows its colour, and a zone's art comes after its tint.
	var base_art := Node2D.new()
	base_art.name = &"BaseArt"
	add_child(base_art)
	_add_patch(base_art, border_rect, map_data.border_style, false)
	_add_patch(base_art, map_data.bounds(), map_data.floor_style, false)
	var zones := Node2D.new()
	zones.name = &"Zones"
	add_child(zones)
	var tints := {}
	for zone in map_data.zones:
		if zone != null:
			var floor_rect := _make_rect(zone.area, zone.floor_color)
			floor_rect.name = StringName("Zone_%s" % zone.display_name)
			zones.add_child(floor_rect)
			tints[zone] = floor_rect
	var zone_art := Node2D.new()
	zone_art.name = &"ZoneArt"
	add_child(zone_art)
	for zone in map_data.zones:
		if zone != null and _add_patch(zone_art, zone.area, zone.floor_style, true):
			# The art has a ragged edge, so a hard-edged flat tint under it must not show through the gaps.
			(tints[zone] as ColorRect).visible = false
	var decor := MapDecorLayer.new()
	decor.name = &"Decor"
	add_child(decor)
	var items := MapDecor.scatter(map_data)
	for i in map_data.zones.size():
		items.append_array(MapDecor.scatter_zone(map_data, i))
	decor.set_decor(items)
	_put_floor_layers_under_the_shadows()
	var obstacles := ObstacleLayer.new()
	obstacles.name = &"Obstacles"
	add_child(obstacles)
	obstacles.set_obstacles(map_data.solid_shapes())
	_build_walls()
	_build_obstacle_bodies()
	var placements := Node2D.new()
	placements.name = &"Placements"
	add_child(placements)
	for placement in map_data.placements:
		if placement == null or placement.scene == null:
			continue
		var placed := placement.scene.instantiate() as Node2D
		placed.position = placement.position
		placements.add_child(placed)
	var obstacle_map := ObstacleMap.new()
	obstacle_map.name = &"ObstacleMap"
	add_child(obstacle_map)
	obstacle_map.setup(map_data)
	var overlay := MapDebugOverlay.new()
	overlay.name = &"Debug"
	overlay.visible = false
	add_child(overlay)
	overlay.setup(map_data)
	overlay.bind(obstacle_map)


## DEBUG: shows or hides the layout overlay (F7).
func toggle_debug() -> void:
	var overlay := get_node_or_null("Debug") as Node2D
	if overlay != null:
		overlay.visible = not overlay.visible


## The map's rectangle, or an empty one when there is no data.
func bounds() -> Rect2:
	return map_data.bounds() if map_data != null else Rect2()


func player_start() -> Vector2:
	return map_data.player_start if map_data != null else Vector2.ZERO


## The floor, its art and the decorations draw just below the shadows (`BodyView.SHADOW_Z`), and the walls and everything that
## stands on the world stay at depth 0 above them. All shadows share one depth, so they draw together and batch.
func _put_floor_layers_under_the_shadows() -> void:
	for layer_name in [&"Border", &"Floor", &"BaseArt", &"Zones", &"ZoneArt", &"Decor"]:
		(get_node(NodePath(layer_name)) as CanvasItem).z_index = BodyView.SHADOW_Z - 1


## A tiled floor over `rect` when `style` has art (true), nothing otherwise (false). A soft patch has a ragged edge,
## seeded from its rectangle so the same map always looks the same.
func _add_patch(parent: Node, rect: Rect2, style: StringName, soft: bool) -> bool:
	var set_data := WorldArt.floor_set(style)
	if set_data == null:
		return false
	var patch := FloorPatch.new()
	patch.name = StringName("Patch_%s" % style)
	parent.add_child(patch)
	patch.setup(rect, set_data, soft, hash([rect.position, rect.size]))
	return true


func _add_rect(node_name: StringName, rect: Rect2, color: Color) -> void:
	var node := _make_rect(rect, color)
	node.name = node_name
	add_child(node)


## A floor-coloured rectangle that never catches a touch.
func _make_rect(rect: Rect2, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	node.color = color
	return node


## Four walls just outside the edges. The top and bottom ones run past both sides, so the corners are closed.
func _build_walls() -> void:
	var walls := Node2D.new()
	walls.name = &"Walls"
	add_child(walls)
	var size := map_data.size
	var wide := Vector2(size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS)
	var tall := Vector2(WALL_THICKNESS, size.y)
	_add_wall(walls, Vector2(size.x / 2.0, -WALL_THICKNESS / 2.0), wide)
	_add_wall(walls, Vector2(size.x / 2.0, size.y + WALL_THICKNESS / 2.0), wide)
	_add_wall(walls, Vector2(-WALL_THICKNESS / 2.0, size.y / 2.0), tall)
	_add_wall(walls, Vector2(size.x + WALL_THICKNESS / 2.0, size.y / 2.0), tall)


func _add_wall(parent: Node, center: Vector2, wall_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape2D.new()
	shape.name = &"CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = wall_size
	shape.shape = rectangle
	body.add_child(shape)
	parent.add_child(body)


## One static body per obstacle on the world layer, so the player's physics collide with the same exact
## shapes the grid and the shape tests are built from.
func _build_obstacle_bodies() -> void:
	var bodies := Node2D.new()
	bodies.name = &"ObstacleBodies"
	add_child(bodies)
	for obstacle in map_data.solid_shapes():
		if obstacle == null or not obstacle.is_valid():
			continue
		var body := StaticBody2D.new()
		body.collision_layer = PhysicsLayers.WORLD
		body.collision_mask = 0
		body.position = obstacle.position
		var shape := CollisionShape2D.new()
		shape.name = &"CollisionShape2D"
		if obstacle.kind == MapObstacle.Kind.CIRCLE:
			var circle := CircleShape2D.new()
			circle.radius = obstacle.radius
			shape.shape = circle
		else:
			var rectangle := RectangleShape2D.new()
			rectangle.size = obstacle.size
			shape.shape = rectangle
		body.add_child(shape)
		bodies.add_child(body)
