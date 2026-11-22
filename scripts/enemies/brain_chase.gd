class_name BrainChase
extends EnemyBrain
## The plain behaviour: walk at the player (plus the horde-spreading offset). Standard, Swarmer, Chaser and
## Tank enemies all use it and differ only in their numbers.


func step(enemy: Enemy, _delta: float) -> Vector2:
	return enemy.direction_to_target() * enemy.speed
