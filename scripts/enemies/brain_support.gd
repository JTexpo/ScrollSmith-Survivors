class_name BrainSupport
extends EnemyBrain
## Support enemies: chase like any enemy, and every quarter second heal every other living enemy within
## `support_radius` by `heal_per_second` worth of health. It never heals itself.

const HEAL_STEP := 0.25

var _timer: float = 0.0


func step(enemy: Enemy, delta: float) -> Vector2:
	_timer += delta
	while _timer >= HEAL_STEP:
		_timer -= HEAL_STEP
		_heal_nearby(enemy)
	return enemy.direction_to_target() * enemy.speed


func _heal_nearby(enemy: Enemy) -> void:
	var behavior := enemy.data.behavior
	var amount := behavior.heal_per_second * HEAL_STEP
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other == null or other == enemy or other.is_dead():
			continue
		if other.global_position.distance_to(enemy.global_position) <= behavior.support_radius:
			other.heal(amount)
