class_name EnemyProjectile
extends Node2D
## A small shot fired by a Ranged enemy or a boss, drawn by its sprite. Its hit is a passive HitboxComponent on
## the enemy hitbox layer, so the player's hurtbox finds it like any enemy hit. It flies straight, frees
## itself at its range or after its one hit, and passes through enemies and spells. A hit the player
## refuses (the invulnerability window) does not spend it. At most MAX_ALIVE exist: a new shot frees the
## oldest.

const MAX_ALIVE := 60

@onready var hitbox: HitboxComponent = $Hitbox
@onready var _body: ColorRect = $Body
@onready var _orb: BodyView = $Orb

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _remaining: float = 0.0
## The map's obstacles, found once at `_ready`. Null means there are none.
var _obstacle_map: ObstacleMap


## Adds a shot to `parent` and launches it. Frees the oldest live shot first when the cap is reached.
static func fire(
	parent: Node,
	scene: PackedScene,
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	max_range: float,
	element_id: StringName = &"",
) -> EnemyProjectile:
	var live := parent.get_tree().get_nodes_in_group(&"enemy_projectiles").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
	while live.size() >= MAX_ALIVE:
		live.pop_front().queue_free()
	var projectile := scene.instantiate() as EnemyProjectile
	parent.add_child(projectile)
	projectile.show_element(element_id)
	projectile.launch(origin, direction, speed, damage, max_range)
	EnemyAttackEvents.bus.shot_fired.emit(origin)
	return projectile


func _ready() -> void:
	z_index = WarningMark.ATTACK_Z
	add_to_group(&"enemy_projectiles")
	_obstacle_map = get_tree().get_first_node_in_group(&"obstacle_map") as ObstacleMap
	hitbox.hit_landed.connect(_on_hit_landed)


func _physics_process(delta: float) -> void:
	var step := _speed * delta
	var from := position
	position += _direction * step
	# A shot that crosses an obstacle is spent before its hit can land.
	if _obstacle_map != null and _obstacle_map.blocks_segment(from, position):
		queue_free()
		return
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


## Shows the shot as an outlined orb in its shooter's element colours (plain grey for none or an unknown element). With no art
## the old square stays.
func show_element(element_id: StringName) -> void:
	var has_orb := _orb.set_look(&"fx_enemy_orb", element_id if element_id != &"" else &"none")
	_orb.visible = has_orb
	_body.visible = not has_orb
	if has_orb:
		_orb.play(&"fly")


func _on_hit_landed(_target: HurtboxComponent) -> void:
	queue_free()
