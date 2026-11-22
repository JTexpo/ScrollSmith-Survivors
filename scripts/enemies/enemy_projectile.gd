class_name EnemyProjectile
extends Node2D
## TEMPORARY look: a small shot fired by a Ranged enemy or a boss. Its hit is a passive HitboxComponent on
## the enemy hitbox layer, so the player's hurtbox finds it like any enemy hit. It flies straight, frees
## itself at its range or after its one hit, and passes through enemies and spells. A hit the player
## refuses (the invulnerability window) does not spend it. At most MAX_ALIVE exist: a new shot frees the
## oldest.

const MAX_ALIVE := 60

@onready var hitbox: HitboxComponent = $Hitbox

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _remaining: float = 0.0


## Adds a shot to `parent` and launches it. Frees the oldest live shot first when the cap is reached.
static func fire(
	parent: Node,
	scene: PackedScene,
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	max_range: float,
) -> EnemyProjectile:
	var live := parent.get_tree().get_nodes_in_group(&"enemy_projectiles").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
	while live.size() >= MAX_ALIVE:
		live.pop_front().queue_free()
	var projectile := scene.instantiate() as EnemyProjectile
	parent.add_child(projectile)
	projectile.launch(origin, direction, speed, damage, max_range)
	return projectile


func _ready() -> void:
	add_to_group(&"enemy_projectiles")
	hitbox.hit_landed.connect(_on_hit_landed)


func _physics_process(delta: float) -> void:
	var step := _speed * delta
	position += _direction * step
	_remaining -= step
	if _remaining <= 0.0:
		queue_free()


func launch(origin: Vector2, direction: Vector2, speed: float, damage: float, max_range: float) -> void:
	global_position = origin
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_speed = speed
	_remaining = max_range
	hitbox.damage = damage
	hitbox.one_shot = true


func _on_hit_landed(_target: HurtboxComponent) -> void:
	queue_free()
