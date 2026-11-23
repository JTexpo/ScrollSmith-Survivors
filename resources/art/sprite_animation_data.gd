class_name SpriteAnimationData
extends Resource
## One animation of a sprite sheet: a range of frames, how fast it plays and whether it loops.

@export var name: StringName
@export var first_frame: int = 0
@export var last_frame: int = 0
@export var fps: float = 8.0
@export var loop: bool = true
