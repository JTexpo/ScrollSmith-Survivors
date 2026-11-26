class_name StageScenery
extends Resource
## A piece of scenery standing on a stage (a tree, a bush): a sprite with no shadow and no animation of its own. `position` is the point it
## STANDS on (its base), which is also what depth is sorted by.

@export var sprite: StringName
@export var variant: StringName = &"base"
@export var position: Vector2 = Vector2.ZERO
## Drawn on a layer behind every actor (a bush), instead of depth-sorted with them (a tree an enemy can walk behind).
@export var background: bool = false
