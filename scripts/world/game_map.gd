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
	_add_rect(&"Border", Rect2(-Vector2(BORDER_MARGIN, BORDER_MARGIN), map_data.size + Vector2(BORDER_MARGIN, BORDER_MARGIN) * 2.0), map_data.border_color)
	_add_rect(&"Floor", map_data.bounds(), map_data.floor_color)
	var decor := MapDecorLayer.new()
	decor.name = &"Decor"
	add_child(decor)
	decor.set_decor(MapDecor.scatter(map_data))
	_build_walls()
	var placements := Node2D.new()
	placements.name = &"Placements"
	add_child(placements)
	for placement in map_data.placements:
		if placement == null or placement.scene == null:
			continue
		var placed := placement.scene.instantiate() as Node2D
		placed.position = placement.position
		placements.add_child(placed)
	var overlay := MapDebugOverlay.new()
	overlay.name = &"Debug"
	overlay.visible = false
	add_child(overlay)
	overlay.setup(map_data)


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


func _add_rect(node_name: StringName, rect: Rect2, color: Color) -> void:
	var node := ColorRect.new()
	node.name = node_name
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	node.color = color
	add_child(node)


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
