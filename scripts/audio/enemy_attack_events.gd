class_name EnemyAttackEvents
extends RefCounted
## Announces enemy shots and blast zones, which have no long-lived node to connect to. One shared emitter (not an autoload):
## the shot and the blast zone say what happened, and the sound board listens. Nothing else changes.

static var bus: EnemyAttackEvents = EnemyAttackEvents.new()

@warning_ignore("unused_signal")
signal shot_fired(position: Vector2)
@warning_ignore("unused_signal")
signal blast_warned(position: Vector2, radius: float)
@warning_ignore("unused_signal")
signal blast_detonated(position: Vector2)
