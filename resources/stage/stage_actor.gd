class_name StageActor
extends Resource
## Something that stands on a stage: a sprite, where it starts each loop and the animation it plays then.

@export var id: StringName
@export var sprite: StringName
@export var variant: StringName = &"base"
@export var start: Vector2 = Vector2.ZERO
## +1 faces right, -1 faces left (every sprite is drawn facing right).
@export var facing: float = 1.0
@export var shadow: bool = true
## Draws the wizard with the equipped look instead of `sprite` (the layers the run uses).
@export var wizard: bool = false
@export var visible_at_start: bool = true
## The animation it plays at the start of each loop and returns to after a walk.
@export var animation: StringName = &"idle"
