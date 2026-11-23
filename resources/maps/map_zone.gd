class_name MapZone
extends Resource
## A region of the map with its own look: a floor tint and decorations. It has no gameplay effect (yet).

@export var area: Rect2 = Rect2()
@export var display_name: String = ""
@export var floor_color: Color = Color(0.16, 0.2, 0.17, 1)
@export var decoration_colors: PackedColorArray = PackedColorArray()
@export var decoration_count: int = 0
