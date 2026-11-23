class_name MazeEntrance
extends Resource
## A gap in a maze's outer wall: the boundary cell and which of its sides is opened.

enum Edge { NORTH, EAST, SOUTH, WEST }

@export var cell: Vector2i = Vector2i.ZERO
@export var side: Edge = Edge.NORTH
