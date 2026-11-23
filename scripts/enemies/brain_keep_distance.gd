class_name BrainKeepDistance
extends EnemyBrain
## Ranged enemies: approach until about `preferred_distance` from the player, back off when closer, and fire
## an EnemyProjectile every `shoot_interval` seconds (the first after half an interval) while the player is
## within the projectile's range. The projectile's damage follows the enemy's difficulty scale.

const PROJECTILE_SCENE := preload("res://scenes/enemies/enemy_projectile.tscn")
## The band around the preferred distance where it just stands still.
const HOLD_MARGIN := 8.0

var _timer: float = 0.0
var _started: bool = false


func step(enemy: Enemy, delta: float) -> Vector2:
	var player := enemy.target_player()
	if player == null:
		return Vector2.ZERO
	var behavior := enemy.data.behavior
	if not _started:
		_started = true
		_timer = behavior.shoot_interval * 0.5
	var to_player := player.global_position - enemy.global_position
	var distance := to_player.length()
	# A wall in the way means no shot lands and no standing still helps: go round it to get a line of sight.
	var clear := enemy.has_clear_line_to(player)
	_timer -= delta
	if _timer <= 0.0 and distance <= behavior.projectile_range and clear:
		_timer = behavior.shoot_interval
		var aim := to_player.normalized() if distance > 0.0 else Vector2.RIGHT
		EnemyProjectile.fire(
			enemy.get_parent(),
			PROJECTILE_SCENE,
			enemy.global_position,
			aim,
			behavior.projectile_speed,
			behavior.projectile_damage * enemy.damage_multiplier(),
			behavior.projectile_range,
		)
	if distance > behavior.preferred_distance + HOLD_MARGIN or not clear:
		return enemy.direction_to_target() * enemy.speed
	if distance < behavior.preferred_distance - HOLD_MARGIN and distance > 0.0:
		return -to_player.normalized() * enemy.speed
	return Vector2.ZERO
