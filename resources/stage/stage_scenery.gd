class_name StageScenery
extends Resource
## A piece of scenery standing on a stage (a tree, a bush): a sprite at a position, with no shadow and no animation of its own.

@export var sprite: StringName
@export var variant: StringName = &"base"
@export var position: Vector2 = Vector2.ZERO
