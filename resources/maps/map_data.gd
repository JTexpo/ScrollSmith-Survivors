class_name MapData
extends Resource
## Everything that makes one map different from another. `GameMap` builds the world from it.

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


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, size)


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
	return found
