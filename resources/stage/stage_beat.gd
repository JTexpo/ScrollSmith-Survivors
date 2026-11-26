class_name StageBeat
extends Resource
## One timed step of a stage script. `time` is seconds into the loop. WALK_TO moves `actor` to `to` over `duration` (playing
## `animation`, default `move`, and facing the way it goes); PLAY plays `animation`; FACE turns it (`facing`); SHOW and HIDE toggle it;
## SHOOT sends an orb of the `effect` sprite from `actor` to `to` over `duration`; BURST puts a spark of the `effect` sprite at `to`
## (it needs no actor); STOP cancels the actor's walk where it stands and returns it to its own animation.

enum Action { WALK_TO, PLAY, FACE, SHOW, HIDE, SHOOT, BURST, STOP }

@export var time: float = 0.0
@export var actor: StringName
@export var action: Action = Action.PLAY
@export var to: Vector2 = Vector2.ZERO
@export var duration: float = 0.0
@export var animation: StringName
@export var effect: StringName
@export var facing: float = 1.0
