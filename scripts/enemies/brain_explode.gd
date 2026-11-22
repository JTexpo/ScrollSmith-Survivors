class_name BrainExplode
extends EnemyBrain
## Exploders: chase, and once within `trigger_distance` stop and light a fuse. A BlastZone with the fuse time
## warns and then blasts, and the enemy dies in its own blast without giving rewards. If the player kills it
## during the fuse the blast is cancelled and it pays its normal rewards.

const BLAST_SCENE := preload("res://scenes/enemies/blast_zone.tscn")
const FUSE_TINT := Color(1.0, 0.45, 0.35)

var _fusing: bool = false
var _zone: BlastZone


func step(enemy: Enemy, _delta: float) -> Vector2:
	if _fusing:
		return Vector2.ZERO
	var player := enemy.target_player()
	if player == null:
		return Vector2.ZERO
	var behavior := enemy.data.behavior
	if player.global_position.distance_to(enemy.global_position) <= behavior.trigger_distance:
		_start_fuse(enemy, behavior)
		return Vector2.ZERO
	return enemy.direction_to_target() * enemy.speed


func _start_fuse(enemy: Enemy, behavior: EnemyBehaviorData) -> void:
	_fusing = true
	enemy.modulate = FUSE_TINT
	_zone = BlastZone.place(
		enemy.get_parent(),
		BLAST_SCENE,
		enemy.global_position,
		behavior.blast_radius,
		behavior.blast_damage * enemy.damage_multiplier(),
		behavior.fuse_time,
	)
	_zone.detonated.connect(enemy.explode_and_die)
	enemy.died.connect(_on_enemy_died)


func _on_enemy_died(_enemy: Enemy) -> void:
	if is_instance_valid(_zone) and not _zone.is_detonated():
		_zone.cancel()
